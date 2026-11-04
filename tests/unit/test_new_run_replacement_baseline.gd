extends "res://addons/gut/test.gd"

const PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SIGNALS := ["save_relevant_state_changed", "day_changed", "money_changed", "daily_state_reset"]

var _scene_fixture: RefCounted
var _scope := preload("res://tests/support/SceneValidationScope.gd").new()

func before_each() -> void:
	_scope.install(true)
	_scene_fixture = preload("res://tests/support/SceneRunSaveFixture.gd").new()
	var setup: Dictionary = _scene_fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))

func after_each() -> void:
	_scene_fixture.close()
	_scope.restore()

func _owner() -> Node:
	var owner: Node = _scene_fixture.game
	owner.reset_game()
	watch_signals(owner)
	return owner

# Explicit structural identity fixture. Actual issuer durability belongs to the
# New Run integration suites; this suite proves the installed GameState read contract.
func _receipt() -> Dictionary:
	return {"receipt_id": "issuer_receipt.replacement-fixture", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "token": "causal-replacement-fixture", "numeric_value": null}

func _snapshot() -> Dictionary:
	return _scene_fixture.snapshot.duplicate(true)

func _quiet_baseline(owner: Node) -> Dictionary:
	var before: Dictionary = owner.capture_restore_state()
	var counts := {}
	for signal_name: String in SIGNALS:
		counts[signal_name] = get_signal_emit_count(owner, signal_name)
	var result: Dictionary = owner.get_new_run_replacement_baseline()
	assert_eq(owner.capture_restore_state(), before)
	for signal_name: String in SIGNALS:
		assert_eq(get_signal_emit_count(owner, signal_name), counts[signal_name])
	return result

func test_reset_and_detached_preparation_have_no_live_continuation() -> void:
	var owner := _owner()
	var before := _quiet_baseline(owner)
	assert_true(before.get("ok", false))
	assert_false(before.value.present)
	assert_eq(before.value.revision.length(), 64)
	var prepared: Dictionary = owner.prepare_new_run_snapshot_input("run-replacement-fixture", "branch-replacement-fixture", 0,
		"causal-replacement-fixture", _receipt(), true)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(_quiet_baseline(owner), before)
	assert_eq(PARTICIPANT.new(owner).get_new_run_replacement_baseline(), before)

func test_valid_install_publishes_only_presence_and_full_backup_hash() -> void:
	var owner := _owner()
	var absent := _quiet_baseline(owner)
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot()}).get("ok", false))
	var installed := _quiet_baseline(owner)
	assert_true(installed.value.present)
	assert_ne(installed.value.revision, absent.value.revision)
	assert_eq(installed.value.size(), 2)
	var backup: Dictionary = owner.capture_restore_state().value.backup
	assert_eq(installed.value.revision, str(WRITER.stringify(backup).value).sha256_text())
	assert_eq(PARTICIPANT.new(owner).get_new_run_replacement_baseline(), installed)
	installed.value.present = false
	assert_true(_quiet_baseline(owner).value.present, "public result is detached")

func test_gameplay_changes_invalidate_the_same_installed_run_baseline() -> void:
	var owner := _owner()
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot()}).get("ok", false))
	var first := _quiet_baseline(owner)
	owner.money += 1
	var changed := _quiet_baseline(owner)
	assert_true(changed.value.present)
	assert_ne(changed.value.revision, first.value.revision)

func test_unhashable_owner_facts_refuse_without_partial_baseline_or_mutation() -> void:
	var owner := _owner()
	owner._narrative_variables["fixture.unsupported"] = Vector2(1, 2)
	assert_eq(_quiet_baseline(owner), {"ok": false, "code": &"new_run_replacement_unavailable"})
	assert_eq(PARTICIPANT.new(owner).get_new_run_replacement_baseline(),
		{"ok": false, "code": &"new_run_replacement_unavailable"})
	assert_false(PARTICIPANT.new(null).get_new_run_replacement_baseline().get("ok", true))

func test_raw_gameplay_load_does_not_install_a_live_continuation() -> void:
	var owner := _owner()
	assert_true(owner.apply_save_dict({"day": 3, "money": 17}).get("ok", false))
	assert_false(_quiet_baseline(owner).value.present)
