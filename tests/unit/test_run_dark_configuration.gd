extends "res://addons/gut/test.gd"

const GAME_STATE := preload("res://autoload/GameState.gd")
const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const RUN_PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")

# Explicit structural identity fixture. Issuer allocation/durability is tested by
# the real New Run transaction suites, not claimed by these owner/schema tests.
func _receipt(token: String = "causal-dark-test") -> Dictionary:
	return {"receipt_id": "issuer_receipt.dark-test", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "token": token, "numeric_value": null}

func _game_state() -> Node:
	var owner: Node = GAME_STATE.new()
	autofree(owner)
	owner.reset_game()
	return owner

func _lifecycle(dark_mode: bool) -> RefCounted:
	var owner: RefCounted = LIFECYCLE.new()
	owner.reset("run-dark-test", "branch-dark-test", 0, "causal-dark-test",
		{"causal_day_instance_issuer_receipt": _receipt()}, dark_mode)
	return owner

func test_lifecycle_dark_is_required_boolean_and_failed_restore_is_atomic() -> void:
	for dark: bool in [false, true]:
		var owner := _lifecycle(dark)
		var before: Dictionary = owner.to_dict()
		assert_eq(before.dark_mode, dark)
		var copy: Dictionary = owner.prepare_restore(before)
		assert_true(copy.ok)
		assert_true(owner.commit_restore(copy.value.candidate).ok)
		for invalid: Variant in [null, 0, 1, 0.0, "false", {}, []]:
			var bad := before.duplicate(true)
			bad.dark_mode = invalid
			assert_false(owner.prepare_restore(bad).ok, str(invalid))
			assert_false(owner.commit_restore(bad).ok, str(invalid))
			assert_eq(owner.to_dict(), before)
		var missing := before.duplicate(true)
		missing.erase("dark_mode")
		assert_false(owner.prepare_restore(missing).ok)
		assert_eq(owner.to_dict(), before)

func test_new_run_preparation_is_strict_detached_and_does_not_install_configuration() -> void:
	var owner := _game_state()
	var participant: RefCounted = RUN_PARTICIPANT.new(owner)
	var before: Dictionary = owner.capture_restore_state()
	for invalid: Variant in [null, 0, 1, "true", {}, []]:
		assert_eq(participant.prepare_new_run("run-dark-test", "branch-dark-test", 0,
			"causal-dark-test", _receipt(), invalid).code, &"invalid_run_configuration")
		assert_eq(owner.prepare_new_run_snapshot_input("run-dark-test", "branch-dark-test", 0,
			"causal-dark-test", _receipt(), invalid).code, &"invalid_run_configuration")
	for dark: bool in [false, true]:
		var prepared: Dictionary = participant.prepare_new_run("run-dark-test", "branch-dark-test", 0,
			"causal-dark-test", _receipt(), dark)
		assert_true(prepared.ok)
		assert_eq(prepared.value.snapshot_input.lifecycle.dark_mode, dark)
		assert_false(owner.get_run_configuration().ok)
	assert_eq(owner.capture_restore_state(), before)

func test_identity_remap_and_ending_preserve_captured_dark() -> void:
	for dark: bool in [false, true]:
		var lifecycle := _lifecycle(dark)
		var remapped: Dictionary = lifecycle.prepare_continuation_remap("restore-test", {
			"run_id": "run-dark-test", "branch_id": "branch-restored", "desktop_timeline_generation": 1,
			"causal_day_instance": "causal-restored", "causal_day_instance_issuer_receipt": _receipt("causal-restored"),
			"allocation_receipt_id": "allocation-test", "remap_receipt_id": "remap-test",
			"remap_receipt_provenance": {}, "transaction_remap": {}}, {
			"branch_id": "branch-dark-test", "desktop_timeline_generation": 0,
			"causal_day_instance": "causal-dark-test", "causal_day_instance_issuer_receipt": _receipt()})
		assert_true(remapped.ok, str(remapped))
		if remapped.ok:
			assert_true(lifecycle.commit_continuation_remap(remapped.value.candidate).ok)
			assert_eq(lifecycle.to_dict().dark_mode, dark)
			assert_eq(lifecycle.to_dict().branch_id, "branch-restored")
		var day_seven: Dictionary = lifecycle.to_dict()
		day_seven.day = 7
		assert_true(lifecycle.commit_restore(day_seven).ok)
		assert_true(lifecycle.enter_ending({"ending_id": "ending.alone", "epilogue_ending_id": "",
			"source_day": 7, "playback_stage": "PRIMARY_PENDING", "playback_receipts": {}}).ok)
		assert_eq(lifecycle.to_dict().dark_mode, dark)

func test_raw_gameplay_load_does_not_create_a_captured_configuration() -> void:
	var owner := _game_state()
	assert_true(owner.apply_save_dict({"day": 3, "money": 17}).ok)
	assert_false(owner.get_run_configuration().ok)
	assert_eq(owner.day, 3)
	assert_false(owner.to_save_dict().has("dark_mode"))
	assert_false(owner.to_save_dict().has("opening_seen"))
	assert_false(owner.to_save_dict().has("tutorial_seen"))
