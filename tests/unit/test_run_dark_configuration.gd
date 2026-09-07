extends "res://addons/gut/test.gd"

const GAME_STATE := preload("res://autoload/GameState.gd")
const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
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

func _snapshot(owner: Node, dark_mode: bool, run_id: String = "run-dark-test") -> Dictionary:
	var prepared: Dictionary = owner.prepare_new_run_snapshot_input(run_id, "branch-dark-test", 0,
		"causal-dark-test", _receipt(), dark_mode)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return {}
	prepared.value.snapshot_input["schedule_view"] = preload("res://scripts/domain/schedule/ScheduleViewState.gd").make_empty(1, "causal-dark-test").value.view
	var built: Dictionary = SNAPSHOT.build(prepared.value.snapshot_input, {}, "main", null,
		{"ambience_context": {}, "ambience_context_id": "", "music_context": {}, "music_context_id": ""}, 1, 1)
	assert_true(built.get("ok", false), str(built))
	return built.value.snapshot if built.get("ok", false) else {}

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

func test_v6_document_round_trip_and_retired_fields_are_rejected() -> void:
	var owner := _game_state()
	for dark: bool in [false, true]:
		var snapshot := _snapshot(owner, dark)
		if snapshot.is_empty(): continue
		assert_eq(snapshot.schema_version, 6)
		assert_eq(snapshot.lifecycle.dark_mode, dark)
		assert_false(snapshot.gameplay.has("opening_seen"))
		assert_false(snapshot.gameplay.has("tutorial_seen"))
		var document: Dictionary = DOCUMENT.build(&"autosave", null, &"day_start",
			{"checkpoint_kind": "day_start", "snapshot": snapshot}, [])
		assert_true(document.ok, str(document))
		if not document.ok: continue
		assert_eq(document.value.schema_version, 6)
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(document.value))
		var validated: Dictionary = DOCUMENT.validate(decoded)
		assert_true(validated.ok, str(validated))
		assert_eq(validated.value.candidate.current_snapshot.snapshot.lifecycle.dark_mode, dark)
		for invalid: Variant in [null, 0, 1, 0.0, "false"]:
			var bad := snapshot.duplicate(true)
			bad.lifecycle.dark_mode = invalid
			assert_false(SNAPSHOT.validate(bad).ok, str(invalid))
		var missing := snapshot.duplicate(true)
		missing.lifecycle.erase("dark_mode")
		assert_false(SNAPSHOT.validate(missing).ok)
		var old := snapshot.duplicate(true)
		old.schema_version = 4
		assert_false(SNAPSHOT.validate(old).ok)
		for retired: String in ["opening_seen", "tutorial_seen"]:
			var bad := snapshot.duplicate(true)
			bad.gameplay[retired] = false
			assert_false(SNAPSHOT.validate(bad).ok)

func test_installed_availability_and_dark_are_restored_with_full_rollback() -> void:
	var owner := _game_state()
	var empty_backup: Dictionary = owner.capture_restore_state().value
	assert_eq(owner.get_run_configuration(), {"ok": false, "code": &"run_configuration_unavailable"})
	var dark := _snapshot(owner, true)
	assert_true(owner.apply_restore_silent({"snapshot": dark}).ok)
	assert_eq(owner.get_run_configuration(), {"ok": true, "value": {"dark_mode": true}})
	var dark_backup: Dictionary = owner.capture_restore_state().value
	var standard := _snapshot(owner, false, "run-standard-test")
	assert_true(owner.apply_restore_silent({"snapshot": standard}).ok)
	assert_eq(owner.get_run_configuration().value.dark_mode, false)
	assert_true(owner.rollback_restore_silent(dark_backup).ok)
	assert_eq(owner.get_run_configuration().value.dark_mode, true)
	assert_true(owner.rollback_restore_silent(empty_backup).ok)
	assert_false(owner.get_run_configuration().ok)
	assert_true(owner.apply_restore_silent({"snapshot": dark}).ok)
	owner.reset_game()
	assert_false(owner.get_run_configuration().ok)

func test_invalid_install_and_missing_rollback_evidence_leave_configuration_unchanged() -> void:
	var owner := _game_state()
	var snapshot := _snapshot(owner, true)
	var invalid := snapshot.duplicate(true)
	invalid.lifecycle.dark_mode = "true"
	var initial: Dictionary = owner.capture_restore_state()
	assert_false(owner.apply_restore_silent({"snapshot": invalid}).ok)
	assert_eq(owner.capture_restore_state(), initial)
	assert_false(owner.get_run_configuration().ok)
	assert_true(owner.apply_restore_silent({"snapshot": snapshot}).ok)
	var installed: Dictionary = owner.capture_restore_state()
	var malformed: Dictionary = initial.value.duplicate(true)
	malformed.backup.erase("run_configuration_installed")
	assert_false(owner.rollback_restore_silent(malformed).ok)
	assert_eq(owner.capture_restore_state(), installed)
	var public: Dictionary = owner.get_run_configuration()
	public.value.dark_mode = false
	assert_eq(owner.get_run_configuration().value.dark_mode, true)
	assert_false(owner.capture_run_snapshot_input().has("run_configuration_installed"))

func test_day_changes_and_identity_remap_preserve_captured_dark() -> void:
	for dark: bool in [false, true]:
		var owner := _game_state()
		var snapshot := _snapshot(owner, dark)
		assert_true(owner.apply_restore_silent({"snapshot": snapshot}).ok)
		owner._lifecycle_set_playing_day(3)
		owner._lifecycle_advance_day()
		assert_eq(owner.day, 4)
		assert_eq(owner.get_run_configuration().value.dark_mode, dark)
		assert_eq(owner.capture_run_snapshot_input().lifecycle.dark_mode, dark)
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
