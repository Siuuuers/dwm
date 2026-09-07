extends "res://addons/gut/test.gd"

const GAME_STATE := preload("res://autoload/GameState.gd")
const PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ENDING_FIXTURE := preload("res://tests/support/DayResolutionReceiptFixtures.gd")
const SIGNALS := ["save_relevant_state_changed", "day_changed", "money_changed", "daily_state_reset"]

func _owner() -> Node:
	var owner: Node = autofree(GAME_STATE.new())
	owner.reset_game()
	watch_signals(owner)
	return owner

# Explicit structural identity fixture. Actual issuer durability belongs to the
# New Run integration suites; this suite proves the installed GameState read contract.
func _receipt() -> Dictionary:
	return {"receipt_id": "issuer_receipt.replacement-fixture", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "token": "causal-replacement-fixture", "numeric_value": null}

func _snapshot(owner: Node, run_id: String = "run-replacement-fixture") -> Dictionary:
	var prepared: Dictionary = owner.prepare_new_run_snapshot_input(run_id, "branch-replacement-fixture", 0,
		"causal-replacement-fixture", _receipt(), true)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return {}
	var built: Dictionary = SNAPSHOT.build(prepared.value.snapshot_input, {}, "main", null,
		{"ambience_context": {}, "ambience_context_id": "", "music_context": {}, "music_context_id": ""}, 1, 1)
	assert_true(built.get("ok", false), str(built))
	return built.value.snapshot if built.get("ok", false) else {}

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
	var prepared := _snapshot(owner)
	assert_false(prepared.is_empty())
	assert_eq(_quiet_baseline(owner), before)
	assert_eq(PARTICIPANT.new(owner).get_new_run_replacement_baseline(), before)

func test_valid_install_publishes_only_presence_and_full_backup_hash() -> void:
	var owner := _owner()
	var absent := _quiet_baseline(owner)
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot(owner)}).get("ok", false))
	var installed := _quiet_baseline(owner)
	assert_true(installed.value.present)
	assert_ne(installed.value.revision, absent.value.revision)
	assert_eq(installed.value.size(), 2)
	var backup: Dictionary = owner.capture_restore_state().value.backup
	assert_eq(installed.value.revision, str(WRITER.stringify(backup).value).sha256_text())
	assert_eq(PARTICIPANT.new(owner).get_new_run_replacement_baseline(), installed)
	installed.value.present = false
	assert_true(_quiet_baseline(owner).value.present, "public result is detached")

func test_gameplay_and_lifecycle_changes_invalidate_the_same_installed_run_baseline() -> void:
	var owner := _owner()
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot(owner)}).get("ok", false))
	var first := _quiet_baseline(owner)
	owner.money += 1
	var changed := _quiet_baseline(owner)
	assert_true(changed.value.present)
	assert_ne(changed.value.revision, first.value.revision)
	owner._lifecycle_set_playing_day(2)
	var next_day := _quiet_baseline(owner)
	assert_true(next_day.value.present)
	assert_ne(next_day.value.revision, changed.value.revision)

func test_ending_remains_present_until_real_terminal_transition() -> void:
	var owner := _owner()
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot(owner)}).get("ok", false))
	owner._lifecycle_set_playing_day(7)
	assert_true(owner._run_lifecycle.enter_ending(ENDING_FIXTURE.ending_plan()).get("ok", false))
	var ending := _quiet_baseline(owner)
	assert_true(ending.value.present)
	for stage: String in ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED"]:
		assert_true(owner._run_lifecycle.complete_ending_playback_stage("ending:" + stage,
			StringName(stage), ENDING_FIXTURE.playback_receipt(stage)).get("ok", false))
	assert_true(owner._complete_run().get("ok", false))
	var completed := _quiet_baseline(owner)
	assert_false(completed.value.present)
	assert_ne(completed.value.revision, ending.value.revision)
	assert_true(owner.get_run_configuration().get("ok", false), "completion retains captured Dark independently")

func test_rollback_restores_exact_presence_and_revision_then_reset_clears_presence() -> void:
	var owner := _owner()
	var empty_backup: Dictionary = owner.capture_restore_state().value
	var empty := _quiet_baseline(owner)
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot(owner)}).get("ok", false))
	var live_backup: Dictionary = owner.capture_restore_state().value
	var live := _quiet_baseline(owner)
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot(owner, "run-replacement-second")}).get("ok", false))
	assert_ne(_quiet_baseline(owner).value.revision, live.value.revision)
	assert_true(owner.rollback_restore_silent(live_backup).get("ok", false))
	assert_eq(_quiet_baseline(owner), live)
	assert_true(owner.rollback_restore_silent(empty_backup).get("ok", false))
	assert_eq(_quiet_baseline(owner), empty)
	assert_true(owner.apply_restore_silent({"snapshot": _snapshot(owner)}).get("ok", false))
	owner.reset_game()
	assert_false(_quiet_baseline(owner).value.present)

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
