extends "res://addons/gut/test.gd"

## Real Profile, issuer, journals, schemas and conditional JsonFileStorage; only
## physical localization/audio/route/narrative effects and file operations are doubles.
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
	var calls: Array = []
	var localization := Participant.new("localization", "localization_plan", calls)
	var audio := Participant.new("audio", "audio_plan", calls)
	var route := Participant.new("route", "route_plan", calls)
	var narrative := Participant.new("narrative", "narrative_plan", calls)
	assert_true(manager.configure_restore_participants({
		"run": preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(gs),
		"desktop_consequence": preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd").new(
			preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()),
		"desktop_board": preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(
			preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()),
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

func test_pair_is_durable_before_live_effects_and_only_pending_dark_is_consumed() -> void:
	var f := _fixture()
	var before: Dictionary = f.profile.get_profile_snapshot()
	f.localization.before_apply = func() -> void:
		var disk: Dictionary = f.saves.inspect_revision("autosave.json")
		assert_true(disk.get("ok", false))
		var save: Dictionary = READER.parse_object(disk.value.text).value
		assert_true(save.current_snapshot.snapshot.lifecycle.dark_mode)
		var persisted: Dictionary = READER.parse_object(f.profiles.inspect_revision("profile.json").value.text).value
		var expected := before.duplicate(true)
		expected["preferences"]["dark_mode"]["next_run_enabled"] = false
		assert_eq(persisted, expected)
		assert_true(f.gate.is_internal_owner_active(&"new_run"))
	var result: Dictionary = f.manager.start_new_run(_context())
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(f.calls.back(), "route:finalize")
	assert_false(f.gate.is_active())
	assert_true(f.gs.get_run_configuration().value.dark_mode)
	assert_eq(f.profile.get_profile_snapshot().controls_bindings, before.controls_bindings)
	assert_eq(f.profile.get_profile_snapshot().visited_line_ids, before.visited_line_ids)
	assert_eq(f.profile.get_profile_snapshot().migration_receipts, before.migration_receipts)

func test_predecision_failure_preserves_both_targets_and_has_no_live_effects() -> void:
	var f := _fixture()
	var before: Dictionary = f.ops.snapshot_persisted()
	f.localization.fail_prepare = true
	var result: Dictionary = f.manager.start_new_run(_context())
	assert_false(result.get("ok", true))
	assert_false(f.gate.is_active())
	assert_eq(f.calls, [])
	var after: Dictionary = f.ops.snapshot_persisted()
	assert_eq(after["pair/profile/profile.json"], before["pair/profile/profile.json"])
	assert_false(after.has("pair/saves/autosave.json"))
	assert_eq(f.manager._continuation_journal.list_incomplete().value, [])

func test_profile_write_failure_retains_decision_and_startup_settles_without_live_launch() -> void:
	var f := _fixture()
	var original: Dictionary = f.profile.get_profile_snapshot()
	f.ops.refuse_path = "pair/profile/profile.json.txn.json"
	var failed: Dictionary = f.manager.start_new_run(_context())
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	if not failed.has("transaction_id"): return
	var tx: String = failed.transaction_id
	var retained := _operation(f, tx)
	assert_eq(f.calls, [])
	assert_eq(f.profile.get_profile_snapshot(), original)
	assert_true(f.gate.is_active())
	assert_false(f.gs.get_run_configuration().get("ok", true))
	var reboot := _fixture(f.ops.snapshot_persisted(), false)
	assert_true(reboot.manager.reconcile_new_run_storage().get("ok", false))
	assert_eq(reboot.calls, [])
	assert_eq(reboot.profile.get_profile_snapshot(), {})
	assert_false(reboot.gate.is_active())
	assert_true(reboot.profile.initialize(reboot.profiles).get("ok", false))
	assert_false(reboot.profile.get_preference(&"preferences.dark_mode.next_run_enabled", true))
	var recovered: Dictionary = reboot.manager.retry_new_run(tx)
	assert_true(recovered.get("ok", false), str(recovered))
	if recovered.get("ok", false):
		assert_eq(recovered.value.run_id, retained.new_run_materials.allocation_candidate.run_id)
		assert_true(reboot.gs.get_run_configuration().value.dark_mode)
	assert_eq(_operation(reboot, tx).new_run_materials, retained.new_run_materials)

func test_partial_live_replay_uses_same_snapshot_with_fresh_route_token() -> void:
	var f := _fixture()
	f.narrative.fail_apply = true
	var failed: Dictionary = f.manager.start_new_run(_context())
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	if not failed.has("transaction_id"): return
	var tx: String = failed.transaction_id
	var retained := _operation(f, tx)
	assert_eq(retained.next_participant_index, 7)
	var files: Dictionary = f.ops.snapshot_persisted()
	f.narrative.fail_apply = false
	var recovered: Dictionary = f.manager.retry_new_run(tx)
	assert_true(recovered.get("ok", false), str(recovered))
	assert_eq(f.route.apply_count, 2)
	assert_eq(_operation(f, tx).new_run_materials, retained.new_run_materials)
	assert_eq(f.ops.snapshot_persisted()["pair/saves/autosave.json"], files["pair/saves/autosave.json"])
	assert_false(f.calls.has("route:rollback"))
	assert_eq(f.calls.back(), "route:finalize")

func test_foreign_autosave_bytes_and_pending_marker_refuse_without_reconciliation() -> void:
	for foreign_marker: bool in [false, true]:
		var f := _fixture()
		f.ops.refuse_path = "pair/saves/autosave.json.txn.json"
		var failed: Dictionary = f.manager.start_new_run(_context())
		assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
		if not failed.has("transaction_id"): continue
		if foreign_marker:
			_replace(f.ops, "pair/saves/autosave.json.txn.json", '{"operation":"delete"}')
		else:
			_replace(f.ops, "pair/saves/autosave.json", "foreign unchanged bytes")
		var before: Dictionary = f.ops.snapshot_persisted()
		var retry: Dictionary = f.manager.retry_new_run(failed.transaction_id)
		assert_eq(retry.get("code"), &"NEW_RUN_RECOVERY_PENDING")
		assert_eq(f.ops.snapshot_persisted(), before)
		assert_eq(f.calls, [])
		assert_true(f.gate.is_active())

func test_completed_retry_does_not_restore_old_targets_after_subsequent_changes() -> void:
	var f := _fixture()
	var done: Dictionary = f.manager.start_new_run(_context())
	assert_true(done.get("ok", false), str(done))
	if not done.get("ok", false): return
	_replace(f.ops, "pair/saves/autosave.json", "later owner output")
	var files: Dictionary = f.ops.snapshot_persisted()
	var calls: Array = f.calls.duplicate()
	var retried: Dictionary = f.manager.retry_new_run(done.value.transaction_id)
	assert_true(retried.get("ok", false), str(retried))
	assert_eq(f.ops.snapshot_persisted(), files)
	assert_eq(f.calls, calls)
	assert_false(f.gate.is_active())

func test_decision_and_autosave_write_cuts_retry_exact_same_retained_materials() -> void:
	for path: String in ["pair/saves/desktop-continuation-operations.json.txn.json",
			"pair/saves/autosave.json.txn.json"]:
		var f := _fixture()
		var before: Dictionary = f.profile.get_profile_snapshot()
		var original_profile: PackedByteArray = f.ops.snapshot_persisted()["pair/profile/profile.json"]
		f.ops.refuse_path = path
		var failed: Dictionary = f.manager.start_new_run(_context())
		assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
		if not failed.has("transaction_id"): continue
		var tx: String = failed.transaction_id
		assert_false(tx.is_empty())
		assert_true(f.gate.is_internal_owner_active(&"new_run"))
		assert_eq(f.calls, [])
		assert_eq(f.profile.get_profile_snapshot(), before)
		assert_eq(f.ops.snapshot_persisted()["pair/profile/profile.json"], original_profile)
		var retained: Dictionary
		if not f.manager._new_run_intent.is_empty():
			retained = f.manager._new_run_intent.duplicate(true)
		else:
			retained = _operation(f, tx)
		var before_blocked_start: Array = f.ops.operation_trace()
		var blocked_start: Dictionary = f.manager.start_new_run(_context())
		assert_eq(f.ops.operation_trace(), before_blocked_start, "pending Start does not rescan its journal")
		assert_eq(blocked_start.get("code"), &"NEW_RUN_RECOVERY_PENDING")
		assert_eq(blocked_start.get("transaction_id"), tx)
		var retried: Dictionary = f.manager.retry_new_run(tx)
		assert_true(retried.get("ok", false), str(retried))
		if not retried.get("ok", false): continue
		var completed := _operation(f, tx)
		assert_eq(completed.new_run_materials, retained.new_run_materials)
		assert_eq(completed.allocation_receipt, retained.new_run_materials.allocation_candidate)
		assert_eq(retried.value.run_id, retained.new_run_materials.allocation_candidate.run_id)
		assert_eq(f.saves.inspect_revision("autosave.json").value.text, retained.new_run_materials.autosave.outgoing_text)
		assert_eq(f.profiles.inspect_revision("profile.json").value.text, retained.new_run_materials.profile.outgoing_text)
		assert_eq(f.calls.back(), "route:finalize")
		assert_false(f.gate.is_active())

func test_busy_unrelated_gate_refuses_before_unloaded_journal_can_reconcile() -> void:
	var f := _fixture()
	_replace(f.ops, "pair/saves/desktop-continuation-operations.json.txn.json", '{"operation":"delete"}')
	assert_false(f.manager._continuation_journal._loaded, "fixture must exercise first journal loading")
	var lease: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_true(lease.get("ok", false))
	var files: Dictionary = f.ops.snapshot_persisted()
	var trace: Array = f.ops.operation_trace()
	var results := [f.manager.start_new_run(_context()), f.manager.retry_new_run("fixture.unread-transaction"),
		f.manager.reconcile_new_run_storage(), f.manager.reconcile_incomplete_continuations()]
	for result: Dictionary in results:
		assert_eq(result.get("code"), &"TRANSACTION_ACTIVE", str(result))
	assert_eq(f.ops.operation_trace(), trace, "busy gate refuses before any FileOps read or write")
	assert_eq(f.ops.snapshot_persisted(), files)
	assert_eq(f.calls, [])
	assert_eq(f.gate.get_active_owner(), &"causal_transaction")
	assert_true(f.gate.release(&"causal_transaction", lease.value.token).get("ok", false))
