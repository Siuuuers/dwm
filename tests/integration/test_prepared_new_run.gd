extends "res://addons/gut/test.gd"

## Prepared New Acc uses the real Profile, run owner, issuer, revision stores,
## schemas and durable New Run path. Only unrelated presentation effects are doubles.
const SAVE := preload("res://autoload/SaveManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const GS := preload("res://autoload/GameState.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const READER := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class TargetFaultOps extends "res://tests/support/FakeFileOps.gd":
	var refuse_path := ""
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if not refuse_path.is_empty() and path == refuse_path:
			refuse_path = ""
			return {"ok": false, "code": &"fixture_target_write_failure"}
		return super.write_bytes(path, bytes)

class Participant extends RefCounted:
	var id := ""
	var plan_key := ""
	var fail_apply := false
	var fail_prepare := false
	var calls: Array = []
	var apply_count := 0
	var before_apply: Callable
	func _init(name_value: String, key: String, log: Array) -> void:
		id = name_value
		plan_key = key
		calls = log
	func prepare(input: Dictionary) -> Dictionary:
		if fail_prepare: return {"ok": false, "code": &"fixture_prepare_failure"}
		return {"ok": true, "value": {plan_key: input.duplicate(true)}}
	func capture() -> Dictionary: return {"ok": true, "value": {}}
	func apply_silent(plan: Dictionary) -> Dictionary:
		calls.append(id + ":apply")
		apply_count += 1
		if before_apply.is_valid(): before_apply.call()
		if fail_apply: return {"ok": false, "code": &"fixture_apply_failure"}
		if id == "route": return {"ok": true, "value": {"route_ready_token": "fixture-route-" + str(apply_count)}}
		return {"ok": true, "value": {"applied": id, "plan": plan.duplicate(true)}}
	func rollback_silent(_backup: Dictionary) -> Dictionary:
		calls.append(id + ":rollback")
		return {"ok": true}
	func finalize() -> Dictionary:
		calls.append(id + ":finalize")
		return {"ok": true}

func _context() -> Dictionary:
	return {"route_id": "main", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}

func _fixture(seed: Dictionary = {}, initialize_profile: bool = true) -> Dictionary:
	var ops: RefCounted = TargetFaultOps.new(seed)
	var saves: RefCounted = STORAGE.new("pair/saves", ops)
	var profiles: RefCounted = STORAGE.new("pair/profile", ops)
	var gate: RefCounted = GATE.new()
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.configure_new_run_storage(profiles).get("ok", false))
	assert_true(profile.configure_mutation_gate(gate).get("ok", false))
	if initialize_profile:
		assert_true(profile.initialize(profiles).get("ok", false))
		if seed.is_empty():
			var data: Dictionary = profile.get_profile_snapshot()
			data["preferences"]["dark_mode"] = {"available": true, "next_run_enabled": true}
			data["preferences"]["reading"]["reveal_speed"] = "slow"
			data["visited_line_ids"] = ["fixture.retained-line"]
			assert_true(profile.commit_prepared_profile(data).get("ok", false))
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(STORAGE.new("pair/issuer", ops), NAMESPACE.new("6".repeat(64))).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(store).get("ok", false))
	var manager: Node = autofree(SAVE.new())
	assert_true(manager.initialize(saves).get("ok", false))
	assert_true(manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(manager.configure_identity_issuer(issuer).get("ok", false))
	assert_true(manager.configure_new_run_profile_owner(profile).get("ok", false))
	var gs: Node = autofree(GS.new())
	assert_true(gs.configure_mutation_gate(gate).get("ok", false))
	var calls: Array = []
	var localization := Participant.new("localization", "localization_plan", calls)
	var audio := Participant.new("audio", "audio_plan", calls)
	var route := Participant.new("route", "route_plan", calls)
	var narrative := Participant.new("narrative", "narrative_plan", calls)
	var schedule: Dictionary = preload("res://tests/support/ScheduleRestoreFixture.gd").create(issuer)
	assert_true(schedule.ok)
	assert_true(manager.configure_restore_participants({
		"run": preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(gs),
		"desktop_consequence": preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd").new(
			preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()),
		"desktop_board": preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(
			preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()),
		"schedule_view": schedule.value.participant,
		"profile": preload("res://scripts/application/restore/ProfileRestoreParticipant.gd").new(profile),
		"localization": localization, "audio": audio, "route": route, "narrative": narrative}).get("ok", false))
	return {"ops": ops, "saves": saves, "profiles": profiles, "gate": gate, "profile": profile,
		"manager": manager, "gs": gs, "calls": calls, "localization": localization,
		"audio": audio, "route": route, "narrative": narrative}

func _operation(fixture: Dictionary, transaction_id: String) -> Dictionary:
	var result: Dictionary = fixture.manager._continuation_journal.get_operation(transaction_id)
	assert_true(result.get("ok", false), str(result))
	return result.get("value", {})

func _replace(ops: RefCounted, path: String, text: String) -> void:
	assert_true(ops.write_bytes(path, text.to_utf8_buffer()).get("ok", false))
	assert_true(ops.flush_path(path).get("ok", false))

func test_prepare_is_pure_and_replaces_only_one_transient_token() -> void:
	var f := _fixture()
	var files_before: Dictionary = f.ops.snapshot_persisted()
	var live_before: Dictionary = f.gs.capture_restore_state()
	var first: Dictionary = f.manager.prepare_new_run_action(_context())
	assert_true(first.get("ok", false), str(first))
	assert_eq(first.value.keys().size(), 4)
	assert_false(first.value.requires_confirmation)
	assert_false(first.value.replaces_live)
	assert_false(first.value.replaces_autosave)
	assert_eq(f.ops.snapshot_persisted(), files_before)
	assert_eq(f.gs.capture_restore_state(), live_before)
	assert_false(f.gate.is_active())
	var second: Dictionary = f.manager.prepare_new_run_action(_context())
	assert_true(second.get("ok", false), str(second))
	assert_ne(second.value.token, first.value.token)
	assert_eq(f.manager.commit_prepared_new_run(first.value.token).get("code"),
		&"invalid_new_run_preparation")
	assert_eq(f.ops.snapshot_persisted(), files_before)
	assert_true(f.manager.cancel_prepared_new_run(second.value.token).get("ok", false))
	assert_eq(f.ops.snapshot_persisted(), files_before)


func test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes() -> void:
	var unreadable := _fixture({"pair/saves/autosave.json": PackedByteArray([0xff])})
	var occupied: Dictionary = unreadable.manager.prepare_new_run_action(_context())
	assert_true(occupied.get("ok", false), str(occupied))
	assert_true(occupied.value.replaces_autosave)
	assert_true(occupied.value.requires_confirmation)
	var empty := _fixture({"pair/saves/autosave.json": PackedByteArray()})
	var vacant: Dictionary = empty.manager.prepare_new_run_action(_context())
	assert_true(vacant.get("ok", false), str(vacant))
	assert_false(vacant.value.replaces_autosave)
	assert_false(vacant.value.requires_confirmation)


func test_cancel_requires_exact_token_and_performs_no_io() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	var before: Dictionary = f.ops.snapshot_persisted()
	assert_eq(f.manager.cancel_prepared_new_run("wrong").get("code"), &"invalid_new_run_preparation")
	assert_eq(f.ops.snapshot_persisted(), before)
	assert_true(f.manager.cancel_prepared_new_run(prepared.value.token).get("ok", false))
	assert_eq(f.ops.snapshot_persisted(), before)
	assert_eq(f.manager.cancel_prepared_new_run(prepared.value.token).get("code"),
		&"invalid_new_run_preparation")


func test_commit_consumes_token_when_profile_autosave_or_live_source_changes() -> void:
	var profile_case := _fixture()
	var prepared: Dictionary = profile_case.manager.prepare_new_run_action(_context())
	var changed: Dictionary = profile_case.profile.get_profile_snapshot()
	changed["preferences"]["reading"]["reveal_speed"] = "normal"
	assert_true(profile_case.profile.commit_prepared_profile(changed).get("ok", false))
	var files_after_external_change: Dictionary = profile_case.ops.snapshot_persisted()
	var stale: Dictionary = profile_case.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(stale.get("code"), &"NEW_RUN_PREPARATION_STALE", str(stale))
	assert_eq(profile_case.ops.snapshot_persisted(), files_after_external_change)
	assert_false(profile_case.gate.is_active())
	assert_eq(profile_case.manager.commit_prepared_new_run(prepared.value.token).get("code"),
		&"invalid_new_run_preparation")

	var save_case := _fixture()
	prepared = save_case.manager.prepare_new_run_action(_context())
	_replace(save_case.ops, "pair/saves/autosave.json", "foreign")
	files_after_external_change = save_case.ops.snapshot_persisted()
	stale = save_case.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(stale.get("code"), &"NEW_RUN_PREPARATION_STALE", str(stale))
	assert_eq(save_case.ops.snapshot_persisted(), files_after_external_change)
	assert_false(save_case.gate.is_active())

	var live_case := _fixture()
	prepared = live_case.manager.prepare_new_run_action(_context())
	live_case.gs.coins += 1
	files_after_external_change = live_case.ops.snapshot_persisted()
	stale = live_case.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(stale.get("code"), &"NEW_RUN_PREPARATION_STALE", str(stale))
	assert_eq(live_case.ops.snapshot_persisted(), files_after_external_change)
	assert_false(live_case.gate.is_active())


func test_prepare_reports_real_live_and_autosave_replacement() -> void:
	var f := _fixture()
	var started: Dictionary = f.manager.start_new_run(_context())
	assert_true(started.get("ok", false), str(started))
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(prepared.value.requires_confirmation)
	assert_true(prepared.value.replaces_live)
	assert_true(prepared.value.replaces_autosave)


func test_success_enters_existing_durable_new_run_with_frozen_dark() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	var retained: Dictionary = f.manager._prepared_new_run.duplicate(true)
	var result: Dictionary = f.manager.commit_prepared_new_run(prepared.value.token)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_true(f.gs.get_run_configuration().value.dark_mode)
	assert_false(f.profile.get_preference(&"preferences.dark_mode.next_run_enabled", true))
	assert_true(retained.profile.captured_dark)
	assert_eq(f.manager.commit_prepared_new_run(prepared.value.token).get("code"),
		&"invalid_new_run_preparation")
	assert_false(f.gate.is_active())


func test_predecision_failure_retains_same_token_for_exact_retry() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	var frozen: Dictionary = f.manager._prepared_new_run.duplicate(true)
	f.localization.fail_prepare = true
	var failed: Dictionary = f.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(failed.get("code"), &"fixture_prepare_failure", str(failed))
	assert_eq(f.manager._prepared_new_run, frozen)
	assert_false(f.gate.is_active())
	f.localization.fail_prepare = false
	var retried: Dictionary = f.manager.commit_prepared_new_run(prepared.value.token)
	assert_true(retried.get("ok", false), str(retried))
	assert_true(f.manager._prepared_new_run.is_empty())


func test_postdecision_failure_returns_transaction_and_never_replays_ui_token() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	f.ops.refuse_path = "pair/saves/autosave.json.txn.json"
	var failed: Dictionary = f.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	assert_false(str(failed.get("transaction_id", "")).is_empty())
	assert_true(f.manager._prepared_new_run.is_empty())
	assert_eq(f.manager.commit_prepared_new_run(prepared.value.token).get("code"),
		&"invalid_new_run_preparation")
	var recovered: Dictionary = f.manager.retry_new_run(str(failed.transaction_id))
	assert_true(recovered.get("ok", false), str(recovered))
	assert_false(f.gate.is_active())


func test_prepare_refuses_retained_recovery_without_journal_io() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	f.ops.refuse_path = "pair/saves/autosave.json.txn.json"
	var failed: Dictionary = f.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	var before: Dictionary = f.ops.snapshot_persisted()
	var refused: Dictionary = f.manager.prepare_new_run_action(_context())
	assert_eq(refused.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(refused))
	assert_eq(f.ops.snapshot_persisted(), before)


func test_fresh_prepare_defers_durable_pending_discovery_to_gated_commit() -> void:
	var original := _fixture()
	var prepared: Dictionary = original.manager.prepare_new_run_action(_context())
	original.ops.refuse_path = "pair/saves/autosave.json.txn.json"
	var pending: Dictionary = original.manager.commit_prepared_new_run(prepared.value.token)
	assert_eq(pending.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(pending))
	var reboot := _fixture(original.ops.snapshot_persisted())
	var draft: Dictionary = reboot.manager.prepare_new_run_action(_context())
	assert_true(draft.get("ok", false), str(draft))
	var refused: Dictionary = reboot.manager.commit_prepared_new_run(draft.value.token)
	assert_eq(refused.get("code"), &"continuation_recovery_required", str(refused))
	assert_false(reboot.gate.is_active())
	assert_false(reboot.manager._prepared_new_run.is_empty())
