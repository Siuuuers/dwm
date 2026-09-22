extends "res://addons/gut/test.gd"

const RECOVERY := preload("res://scripts/application/desktop/DesktopColdRecoveryPreparation.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
var _counter := 0

func _snapshot() -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	var source: Dictionary = parsed.value
	source["lifecycle"]["day"] = 2
	source["committed_schedule"]["day"] = 2
	source["schedule_view"]["day"] = 2
	source["gameplay"]["money"] = 777
	source["active_app_id"] = "shop"
	var checked: Dictionary = SNAPSHOT.validate(source)
	assert_true(checked.get("ok", false), str(checked))
	return checked.value.candidate if checked.get("ok", false) else {}

func _write_source(storage: Object, snapshot: Dictionary) -> Dictionary:
	var built: Dictionary = DOCUMENT.build(&"autosave", null, &"automatic",
		{"checkpoint_kind": "safe_marker", "snapshot": snapshot}, [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return {}
	var encoded: Dictionary = CANON.stringify(built.value)
	assert_true(storage.write_atomic("autosave.json", encoded.value + "\n",
		func(text: String) -> Dictionary:
			var raw: Dictionary = STRICT_JSON.parse_object(text)
			return DOCUMENT.validate(raw.value) if raw.get("ok", false) else raw).get("ok", false))
	return built.value

func _action(snapshot: Dictionary) -> Dictionary:
	var provenance := {"child_id": "fixture-action", "child_kind": "desktop_action", "ordinal": 0,
		"parent_receipt_id": "issuer_receipt.fixture-action", "schema_version": 1, "source_ids": ["fixture-source"]}
	var receipt := {"schema_version": 1, "action_id": "fixture-action", "action_id_provenance": provenance,
		"action_kind": "shop_purchase", "transaction_id": "fixture-transaction",
		"transaction_issuer_receipt": snapshot.lifecycle.causal_day_instance_issuer_receipt.duplicate(true),
		"source_commit_receipt_id": "fixture-source", "source_commit_receipt_provenance": provenance.duplicate(true),
		"condition_before": {"health": 6, "pressure": 3, "carried_sequela": false},
		"condition_after": {"health": 6, "pressure": 3, "carried_sequela": false},
		"unlock_receipt_ids": [], "commit_receipt_id": "fixture-action", "commit_receipt_provenance": provenance.duplicate(true)}
	for field: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "day"]:
		receipt[field] = snapshot.lifecycle[field]
	return receipt

func _write_pending(port: Object, snapshot: Dictionary) -> Dictionary:
	var state := CONSEQUENCE.new()
	var restored: Dictionary = state.prepare_restore(snapshot.desktop.consequence)
	assert_true(state.commit(restored.value.candidate).get("ok", false))
	var receipt := _action(snapshot)
	var handoff_receipt := receipt.duplicate(true)
	handoff_receipt["source_kind"] = receipt.action_kind
	# Exercise the production admission-ready transport shape. This helper suite restores
	# source owners only; the connected coordinator suite owns full action replay.
	var builder: RefCounted = preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd").new()
	var frozen: Dictionary = builder._build_admission_ready_payload("shop_purchase", receipt,
		{"source_checkpoint": RECOVERY.source_checkpoint_reference(snapshot)}, {},
		null, null, null, null, null, null, false, {}, {}, null, null)
	var payload: Dictionary = frozen["recovery_payload"]
	var handoff: Dictionary = state.prepare_action_handoff(handoff_receipt, 0, payload)
	assert_true(handoff.get("ok", false), str(handoff))
	if not handoff.get("ok", false): return {}
	assert_true(state.commit(handoff.value.candidate).get("ok", false))
	var sequence := {"receipt_id": "fixture-sequence", "receipt_provenance": {},
		"transaction_id": receipt.transaction_id, "transaction_issuer_receipt": receipt.transaction_issuer_receipt,
		"run_id": receipt.run_id, "branch_id": receipt.branch_id,
		"desktop_timeline_generation": receipt.desktop_timeline_generation,
		"causal_day_instance": receipt.causal_day_instance, "source_kind": "shop_purchase",
		"source_commit_receipt_id": receipt.source_commit_receipt_id,
		"source_commit_receipt_provenance": receipt.source_commit_receipt_provenance,
		"causal_sequence": 1, "run_revision": 1}
	var admitted: Dictionary = state.prepare_sequence_reservation({
		"transaction_id": receipt.transaction_id, "source_kind": "shop_purchase"}, sequence)
	assert_true(admitted.get("ok", false), str(admitted))
	if not admitted.get("ok", false): return {}
	var checkpoint: Dictionary = port.prepare_consequence_checkpoint({"kind": &"consequence_admission",
		"operation_ordinal": 2, "run_id": receipt.run_id, "source_ids": [receipt.transaction_id],
		"stage": "sequence_committed", "transaction_id": receipt.transaction_id}, admitted.value.candidate.state_after)
	assert_true(checkpoint.get("ok", false), str(checkpoint))
	if not checkpoint.get("ok", false): return {}
	assert_true(port.commit_consequence_checkpoint(checkpoint.value.candidate,
		checkpoint.value.checkpoint_receipt).get("ok", false))
	return checkpoint.value.candidate.document.stage_candidate

func _wired() -> Dictionary:
	_counter += 1
	var result: Dictionary = TemporaryStorage.create("desktop-cold-recovery".path_join(str(_counter)))
	assert_true(result.ok, result.get("message", ""))
	if not result.ok:
		return {}
	var root: String = result.value
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(root)
	var manager: Node = preload("res://autoload/SaveManager.gd").new()
	var game: Node = preload("res://autoload/GameState.gd").new()
	autofree(manager)
	autofree(game)
	var gate: RefCounted = preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(manager.initialize(storage).get("ok", false))
	assert_true(manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(game.configure_mutation_gate(gate).get("ok", false))
	var port: RefCounted = preload("res://scripts/application/run/SaveManagerCheckpointPort.gd").new(manager)
	assert_true(port.configure_fatal_latch(gate).get("ok", false))
	var board: RefCounted = preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	var consequence := CONSEQUENCE.new()
	var host: RefCounted = preload("res://scripts/domain/desktop/DesktopAppHostState.gd").new()
	var registry_result: Dictionary = preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd").load_current()
	assert_true(registry_result.get("ok", false), str(registry_result))
	var registry: Object = registry_result.value.registry
	var view: RefCounted = preload("res://scripts/application/schedule/ScheduleViewController.gd").new()
	assert_true(view.configure(registry, preload("res://scripts/domain/schedule/ScheduleRules.gd"),
		str(registry.fingerprint())).get("ok", false))
	manager._restore_participants = {
		"run": preload("res://scripts/application/restore/RunRestoreParticipant.gd").new(game),
		"desktop_consequence": preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd").new(consequence),
		"desktop_board": preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(board),
		"schedule_view": preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd").new(
			view, registry, RefCounted.new(), preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")),
	}
	assert_true(game.configure_desktop_snapshot_provider(func() -> Dictionary:
		return {"board": board.capture(), "consequence": consequence.capture().value.state}).get("ok", false))
	var helper := RECOVERY.new()
	assert_true(helper.configure(manager, port, game, host).get("ok", false))
	return {"manager": manager, "game": game, "gate": gate, "port": port, "storage": storage,
		"helper": helper, "view": view, "board": board, "consequence": consequence, "host": host}

func test_cold_day_two_installs_exact_owners_and_journal_without_activating_or_routing() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var snapshot := _snapshot()
	_write_source(wired.storage, snapshot)
	var pending := _write_pending(wired.port, snapshot)
	var before: Dictionary = wired.game.capture_live_session()
	assert_false(before.value.active)
	assert_false(wired.view.snapshot().get("ok", false), "the fresh process has no open Schedule day")
	var prepared: Dictionary = wired.helper.prepare_current_autosave()
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(prepared.value.kind, "install_source")
	assert_eq(wired.game.day, 1, "prepare performs no live mutation")
	assert_true(wired.helper.install_prepared().get("ok", false))
	assert_eq(wired.game.day, 2)
	assert_eq(wired.game.money, 777)
	assert_eq(wired.game.capture_live_session(), before, "source installation does not activate a session")
	assert_eq(wired.board.capture(), snapshot.desktop.board)
	# JSON reload erases StringName/typed-array representations from the prepared
	# candidate; require the complete durable value to remain byte-for-byte canonical.
	var installed_pending: Dictionary = CANON.stringify(wired.consequence.capture().value.state)
	var expected_pending: Dictionary = CANON.stringify(pending)
	assert_true(installed_pending.get("ok", false), str(installed_pending))
	assert_true(expected_pending.get("ok", false), str(expected_pending))
	assert_eq(installed_pending.get("value"), expected_pending.get("value"))
	assert_eq(wired.view.snapshot().value.view, snapshot.schedule_view)
	assert_eq(wired.host.capture_persistent_state().active_app_id, "shop")
	assert_eq(wired.manager._journal.get_current_bundle().value.bundle.snapshot, snapshot)
	assert_false(wired.gate.is_active())
	wired.game.money = 800
	assert_true(wired.helper.install_prepared().get("ok", false))
	assert_eq(wired.game.money, 800, "retry after installation never rewinds later source effects")
	var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
	var capture: Dictionary = wired.helper.capture_completed_checkpoint_inputs(snapshot.desktop.consequence)
	assert_true(capture.get("ok", false), str(capture))
	assert_eq(capture.value.checkpoint_inputs.route_id, "main")
	assert_eq(capture.value.checkpoint_inputs.snapshot_input.gameplay.money, 800)
	assert_eq(capture.value.checkpoint_inputs.snapshot_input.lifecycle.day, 2)
	assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))

func test_a_different_current_autosave_never_receives_an_older_sidecar() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var snapshot := _snapshot()
	_write_source(wired.storage, snapshot)
	_write_pending(wired.port, snapshot)
	snapshot["gameplay"]["money"] = 123
	_write_source(wired.storage, snapshot)
	var prepared: Dictionary = wired.helper.prepare_current_autosave()
	assert_false(prepared.get("ok", true))
	assert_eq(prepared.get("code"), &"cold_recovery_source_checkpoint_mismatch")
	assert_eq(wired.game.day, 1)
	assert_false(wired.game.capture_live_session().value.active)

func test_source_changes_after_preparation_refuse_before_any_owner_apply() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var snapshot := _snapshot()
	_write_source(wired.storage, snapshot)
	_write_pending(wired.port, snapshot)
	assert_true(wired.helper.prepare_current_autosave().get("ok", false))
	snapshot["gameplay"]["money"] = 456
	_write_source(wired.storage, snapshot)
	var applied: Dictionary = wired.helper.install_prepared()
	assert_false(applied.get("ok", true))
	assert_eq(applied.get("code"), &"cold_recovery_source_changed")
	assert_eq(wired.game.day, 1)
	assert_false(wired.gate.is_active())

func test_snapshot_hash_match_cannot_override_a_conflicting_action_identity() -> void:
	var snapshot := _snapshot()
	var action := _action(snapshot)
	action["branch_id"] = "other-branch"
	var pending := {"transaction_id": action.transaction_id, "recovery_payload": {
		"action_receipt": action, "action_candidate": {"source_checkpoint": RECOVERY.source_checkpoint_reference(snapshot)}}}
	var checked: Dictionary = RECOVERY.validate_source_binding(snapshot, {
		"pending": pending, "causal_day_instance": snapshot.lifecycle.causal_day_instance})
	assert_false(checked.get("ok", true))
	assert_eq(checked.get("code"), &"cold_recovery_source_identity_mismatch")

func _activate_session(wired: Dictionary, snapshot: Dictionary) -> void:
	var before: Dictionary = wired.game.capture_live_session().value
	var lease: Dictionary = wired.gate.acquire(&"new_run")
	assert_true(lease.get("ok", false), str(lease))
	assert_true(wired.game.apply_restore_silent({"snapshot": snapshot}).get("ok", false))
	var activated: Dictionary = wired.game.activate_live_session({
		"operation_id": "recovered-new-run", "expected_generation": before.generation,
		"owner_id": before.owner_id, "run_id": snapshot.lifecycle.run_id})
	assert_true(activated.get("ok", false), str(activated))
	assert_true(wired.gate.release(&"new_run", lease.value.token).get("ok", false))

func test_active_session_with_no_pending_action_requires_no_cold_recovery() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var snapshot := _snapshot()
	_write_source(wired.storage, snapshot)
	_activate_session(wired, snapshot)
	var before: Dictionary = wired.game.capture_live_session()
	wired.game.money = 888
	var prepared: Dictionary = wired.helper.prepare_current_autosave()
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(prepared.get("value", {}).get("kind"), "none")
	assert_true(wired.helper.finish_recovery().get("ok", false))
	assert_eq(wired.game.capture_live_session(), before)
	assert_eq(wired.game.money, 888, "no source is installed over the already recovered live run")
	assert_false(wired.helper.is_installed())
	assert_false(wired.gate.is_active())

func test_active_session_still_refuses_a_pending_desktop_action() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var snapshot := _snapshot()
	_write_source(wired.storage, snapshot)
	_write_pending(wired.port, snapshot)
	_activate_session(wired, snapshot)
	var before: Dictionary = wired.game.capture_live_session()
	wired.game.money = 888
	var prepared: Dictionary = wired.helper.prepare_current_autosave()
	assert_false(prepared.get("ok", true))
	assert_eq(prepared.get("code"), &"cold_recovery_requires_inactive_session")
	assert_eq(wired.game.capture_live_session(), before)
	assert_eq(wired.game.money, 888)
	assert_false(wired.helper.is_installed())
	assert_false(wired.gate.is_active())

func test_active_session_still_refuses_a_retained_prepared_source() -> void:
	var wired := _wired()
	if wired.is_empty():
		return
	var snapshot := _snapshot()
	_write_source(wired.storage, snapshot)
	_write_pending(wired.port, snapshot)
	assert_true(wired.helper.prepare_current_autosave().get("ok", false))
	var retained: Dictionary = wired.helper._prepared.duplicate(true)
	_activate_session(wired, snapshot)
	wired.game.money = 888
	var prepared: Dictionary = wired.helper.prepare_current_autosave()
	assert_false(prepared.get("ok", true))
	assert_eq(prepared.get("code"), &"cold_recovery_requires_inactive_session")
	var installed: Dictionary = wired.helper.install_prepared()
	assert_false(installed.get("ok", true))
	assert_eq(installed.get("code"), &"cold_recovery_requires_inactive_session")
	assert_eq(wired.helper._prepared, retained, "refusal retains the exact source for recovery")
	assert_eq(wired.game.money, 888)
	assert_false(wired.helper.is_installed())
	assert_false(wired.gate.is_active())
