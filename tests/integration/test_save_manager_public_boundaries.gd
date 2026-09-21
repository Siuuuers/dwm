extends "res://addons/gut/test.gd"

## Direct public SaveManager boundaries with real Profile/run/issuer/storage owners.
## Only unrelated presentation participants and deterministic I/O faults are doubles.
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
	var before_write: Callable
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if before_write.is_valid():
			var callback := before_write
			before_write = Callable()
			callback.call()
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
	var manager: Node = add_child_autofree(SAVE.new())
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


func _inputs(fixture: Dictionary) -> Dictionary:
	var inputs := _context()
	inputs["snapshot_input"] = fixture.gs.capture_run_snapshot_input()
	return inputs


func _replace(ops: RefCounted, path: String, text: String) -> void:
	assert_true(ops.write_bytes(path, text.to_utf8_buffer()).get("ok", false))
	assert_true(ops.flush_path(path).get("ok", false))


func _arm_busy_frame_probe(fixture: Dictionary, token: String) -> Dictionary:
	var observed := {"frame_seen": false, "owner": &"", "live": true, "reentry": {}}
	# Age only the private slice clock at the first write. The real production
	# process-frame boundary then runs deterministically, with no sleep or budget assertion.
	fixture.ops.before_write = func() -> void:
		fixture.manager._new_run_slice_started_us = Time.get_ticks_usec() - 8001
	get_tree().process_frame.connect(func() -> void:
		observed.frame_seen = true
		observed.owner = fixture.gate.get_active_owner()
		observed.live = fixture.gs.capture_live_session().value.active
		observed.reentry = await fixture.manager.commit_prepared_new_run_responsive(token),
		CONNECT_ONE_SHOT)
	return observed


func test_responsive_prepared_commit_yields_with_custody_and_publishes_one_live_run() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var published: Array = []
	f.manager.live_session_ready.connect(func() -> void: published.append(f.gs.capture_live_session().value))
	var observed := _arm_busy_frame_probe(f, prepared.value.token)
	var result: Dictionary = await f.manager.commit_prepared_new_run_responsive(prepared.value.token)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_true(observed.frame_seen, "responsive commit yields through the real process-frame seam")
	assert_eq(observed.owner, &"new_run", "exclusive custody survives the rendering boundary")
	assert_false(observed.live, "partial durable work never publishes an active session")
	assert_eq(observed.reentry.get("code"), &"new_run_busy", "reentrant commit cannot allocate another run")
	assert_false(f.manager._new_run_busy)
	assert_false(f.gate.is_active())
	assert_eq(published.size(), 1)
	assert_true(published[0].active)
	assert_eq(published[0].run_id, result.value.run_id)
	assert_true(f.gs.get_run_configuration().value.dark_mode)
	assert_false(f.profile.get_preference(&"preferences.dark_mode.next_run_enabled", true))
	var saved: Dictionary = READER.parse_object(f.saves.read_text("autosave.json").value)
	assert_true(saved.ok)
	assert_eq(saved.value.current_snapshot.snapshot.run_id, result.value.run_id)
	var durable: Dictionary = f.ops.snapshot_persisted()
	var generation: Dictionary = f.gs.capture_live_session().value
	assert_eq((await f.manager.commit_prepared_new_run_responsive(prepared.value.token)).get("code"),
		&"invalid_new_run_preparation")
	assert_eq(f.ops.snapshot_persisted(), durable)
	assert_eq(f.gs.capture_live_session().value, generation)
	assert_eq(published.size(), 1)


func test_responsive_retry_reuses_the_durable_decision_without_replaying_preparation() -> void:
	var f := _fixture()
	var prepared: Dictionary = f.manager.prepare_new_run_action(_context())
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var published: Array = []
	f.manager.live_session_ready.connect(func() -> void: published.append(f.gs.capture_live_session().value))
	f.ops.refuse_path = "pair/saves/autosave.json.txn.json"
	var failed: Dictionary = await f.manager.commit_prepared_new_run_responsive(prepared.value.token)
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	assert_false(str(failed.get("transaction_id", "")).is_empty(), "a durable failure returns its recovery identity")
	if str(failed.get("transaction_id", "")).is_empty(): return
	var transaction_id := str(failed.transaction_id)
	var pending: Dictionary = f.manager._continuation_journal.get_operation(transaction_id)
	assert_true(pending.ok)
	var frozen: Dictionary = pending.value.new_run_materials.duplicate(true)
	assert_false(f.gs.capture_live_session().value.active)
	assert_eq(published.size(), 0)
	assert_false(f.manager._new_run_busy)
	var before_refusal: Dictionary = f.ops.snapshot_persisted()
	assert_eq((await f.manager.retry_new_run_responsive("another-transaction")).get("code"),
		&"new_run_recovery_conflict")
	assert_eq(f.ops.snapshot_persisted(), before_refusal)
	var recovered: Dictionary = await f.manager.retry_new_run_responsive(transaction_id)
	assert_true(recovered.get("ok", false), str(recovered))
	if not recovered.get("ok", false): return
	var completed: Dictionary = f.manager._continuation_journal.get_operation(transaction_id)
	assert_eq(completed.value.new_run_materials, frozen, "retry consumes the same frozen profile/run pair")
	assert_eq(recovered.value.transaction_id, transaction_id)
	assert_eq(published.size(), 1)
	assert_false(f.manager._new_run_busy)
	assert_false(f.gate.is_active())
	var durable: Dictionary = f.ops.snapshot_persisted()
	var generation: Dictionary = f.gs.capture_live_session().value
	var repeated: Dictionary = await f.manager.retry_new_run_responsive(transaction_id)
	assert_true(repeated.get("ok", false), str(repeated))
	assert_eq(repeated.value.outcome, "already_terminal")
	assert_eq(f.ops.snapshot_persisted(), durable, "terminal replay writes no new decision")
	assert_eq(f.gs.capture_live_session().value, generation)
	assert_eq(published.size(), 1)
	assert_eq((await f.manager.commit_prepared_new_run_responsive(prepared.value.token)).get("code"),
		&"invalid_new_run_preparation")


func test_session_exit_checkpoint_requires_current_custody_and_preserves_live_session_on_failure() -> void:
	var f := _fixture()
	var started: Dictionary = f.manager.start_new_run(_context())
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	var handle: Dictionary = f.gs.capture_live_session().value
	var original_files: Dictionary = f.ops.snapshot_persisted()
	assert_eq(f.manager.save_session_exit_checkpoint(_inputs(f), handle).get("code"),
		&"session_abandonment_required")
	assert_eq(f.ops.snapshot_persisted(), original_files)
	var foreign: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_true(foreign.ok)
	assert_eq(f.manager.save_session_exit_checkpoint(_inputs(f), handle).get("code"),
		&"session_abandonment_required")
	assert_eq(f.ops.snapshot_persisted(), original_files)
	assert_true(f.gate.release(&"causal_transaction", foreign.value.token).ok)
	var lease: Dictionary = f.gate.acquire(&"session_abandonment")
	assert_true(lease.ok)
	var stale := handle.duplicate(true)
	stale["run_id"] = "different-run"
	assert_eq(f.manager.save_session_exit_checkpoint(_inputs(f), stale).get("code"), &"stale_live_session")
	stale = handle.duplicate(true)
	stale["active"] = false
	assert_eq(f.manager.save_session_exit_checkpoint(_inputs(f), stale).get("code"), &"stale_live_session")
	assert_eq(f.ops.snapshot_persisted(), original_files)
	var original_autosave: String = f.saves.read_text("autosave.json").value
	var completed: Array = []
	f.manager.save_completed.connect(func(receipt: Dictionary) -> void: completed.append(receipt.duplicate(true)))
	f.ops.refuse_path = "pair/saves/autosave.json.txn.json"
	var failed: Dictionary = f.manager.save_session_exit_checkpoint(_inputs(f), handle)
	assert_false(failed.get("ok", true), str(failed))
	assert_eq(f.gs.capture_live_session().value, handle, "save failure cannot retire the session")
	assert_eq(f.saves.read_text("autosave.json").value, original_autosave, "the last durable save remains readable")
	assert_eq(completed.size(), 0)
	assert_true(f.gate.is_lease_active(&"session_abandonment", lease.value.token))
	var result: Dictionary = f.manager.save_session_exit_checkpoint(_inputs(f), handle)
	assert_true(result.get("ok", false), str(result))
	if result.get("ok", false):
		assert_true(result.value.written)
		assert_eq(result.value.save_reason, "logout")
		assert_eq(completed.size(), 1)
		var saved: Dictionary = READER.parse_object(f.saves.read_text("autosave.json").value)
		assert_true(saved.ok)
		assert_eq(saved.value.save_reason, "logout")
		assert_eq(saved.value.current_snapshot.snapshot.run_id, handle.run_id)
		assert_eq(saved.value.current_snapshot.snapshot.gameplay, f.gs.capture_run_snapshot_input().gameplay)
	assert_eq(f.gs.capture_live_session().value, handle, "the exit coordinator, not this storage method, owns retirement")
	assert_true(f.gate.release(&"session_abandonment", lease.value.token).ok)


func test_load_context_reads_the_exact_retained_snapshot_without_mutation() -> void:
	var f := _fixture()
	var started: Dictionary = f.manager.start_new_run(_context())
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	var old: Dictionary = f.manager.get_latest_stable_checkpoint().value.bundle.snapshot.duplicate(true)
	f.gs.coins += 1
	var recorded: Dictionary = f.manager.record_stable_checkpoint(_inputs(f), &"scene_transition")
	assert_true(recorded.get("ok", false), str(recorded))
	if not recorded.get("ok", false): return
	var current: Dictionary = f.manager.get_latest_stable_checkpoint().value.bundle.snapshot.duplicate(true)
	assert_ne(current.checkpoint_id, old.checkpoint_id)
	assert_ne(current.gameplay.coins, old.gameplay.coins)
	assert_true(f.manager.save_latest_to_slot(1).ok)
	assert_true(f.manager.quick_save_latest().ok)
	assert_true(f.manager.autosave_latest().ok)
	var before_files: Dictionary = f.ops.snapshot_persisted()
	var before_run: Dictionary = f.gs.capture_restore_state()
	var before_profile: Dictionary = f.profile.get_profile_snapshot()
	var before_journal: Dictionary = f.manager._journal.capture_state()
	for locator: String in ["slot:1", "quick", "autosave"]:
		for expected: Dictionary in [old, current]:
			var read: Dictionary = f.manager.load_context({"slot_id": locator, "checkpoint_id": expected.checkpoint_id})
			assert_true(read.get("ok", false), str(read))
			if not read.get("ok", false): continue
			assert_eq(read.value.context, expected, "reads the requested retained bundle, not a route default or latest substitute")
			var canonical: Dictionary = WRITER.stringify(expected)
			assert_true(canonical.ok)
			assert_eq(read.value.context_sha256, str(canonical.value).sha256_text())
			read.value.context.gameplay.coins = -1234
			var again: Dictionary = f.manager.load_context({"slot_id": locator, "checkpoint_id": expected.checkpoint_id})
			assert_true(again.ok)
			assert_eq(again.value.context, expected, "returned context is detached")
	assert_eq(f.manager.load_context({"slot_id": "slot:1", "checkpoint_id": "absent"}).get("code"),
		&"source_bundle_not_found")
	assert_eq(f.manager.load_context({"slot_id": "slot:7", "checkpoint_id": old.checkpoint_id}).get("code"),
		&"save_absent")
	assert_eq(f.manager.load_context({"slot_id": "../autosave.json", "checkpoint_id": old.checkpoint_id}).get("code"),
		&"invalid_source_locator")
	assert_eq(f.ops.snapshot_persisted(), before_files)
	assert_eq(f.gs.capture_restore_state(), before_run)
	assert_eq(f.profile.get_profile_snapshot(), before_profile)
	assert_eq(f.manager._journal.capture_state(), before_journal)
	_replace(f.ops, "pair/saves/slot_2.json", "{invalid")
	var corrupt_bytes: Dictionary = f.ops.snapshot_persisted()
	assert_eq(f.manager.load_context({"slot_id": "slot:2", "checkpoint_id": old.checkpoint_id}).get("code"),
		&"corrupt_save_document")
	assert_eq(f.ops.snapshot_persisted(), corrupt_bytes, "corrupt source stays available for recovery")
	var unwired: Node = autofree(SAVE.new())
	assert_eq(unwired.load_context({"slot_id": "autosave", "checkpoint_id": old.checkpoint_id}).get("code"),
		&"not_initialized")
