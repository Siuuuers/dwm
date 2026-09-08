extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/run/GameStateConditionHospitalPort.gd")
const STATE := preload("res://scripts/domain/run/ConditionHospitalState.gd")
const GAME := preload("res://autoload/GameState.gd")

class Identity extends RefCounted:
	func derive_child(request: Dictionary) -> Dictionary:
		var id := str(request.child_kind) + "." + str(request.ordinal)
		var provenance := {"schema_version": 1, "parent_receipt_id": request.parent_receipt_id,
			"child_kind": request.child_kind, "ordinal": request.ordinal,
			"source_ids": request.source_ids.duplicate(true), "child_id": id}
		return {"ok": true, "value": {"child_id": id, "provenance": provenance}}

class DayAdvance extends RefCounted:
	var commits := 0
	func prepare_advance(request: Dictionary) -> Dictionary:
		var receipt := {"target_day": int(request.source_day) + 1,
			"target_causal_day_instance": "causal.next",
			"target_causal_day_instance_issuer_receipt": {"receipt_id": "issuer.next", "purpose": "causal_day_instance",
				"namespace": "fixture", "counter": 2, "numeric_value": null, "token": "causal.next"}}
		return {"ok": true, "value": {"day_advance_identity_candidate": {"day_advance_identity_receipt": receipt}}}
	func commit_advance(candidate: Dictionary) -> Dictionary:
		commits += 1
		return {"ok": true, "value": candidate}

class View extends RefCounted:
	var value := {"day": 1, "causal_day_instance": "causal.source", "entries": [],
		"date_entry_seen": false, "pending_warning": null, "consumed_warning_receipts": {}, "condition_departure_receipts": {}}
	func snapshot() -> Dictionary: return {"ok": true, "value": {"view": value.duplicate(true)}}
	func install_restored_view(candidate: Dictionary) -> Dictionary:
		value = candidate.duplicate(true)
		return {"ok": true}

func _wired(real_issuer: Object = null, real_day: Object = null, source: Dictionary = {}) -> Dictionary:
	var game: Node = GAME.new()
	autofree(game)
	var issuer: Object = Identity.new() if real_issuer == null else real_issuer
	var root := {"receipt_id": "issuer.source", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "numeric_value": null, "token": "causal.source"}
	if not source.is_empty(): root = source.duplicate(true)
	game._run_lifecycle.reset("run", "branch", 0, str(root.token), {"causal_day_instance_issuer_receipt": root}, false)
	var state := STATE.new()
	assert_true(state.configure(game._run_lifecycle, issuer).get("ok", false))
	var view := View.new()
	var board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	var consequence := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()
	var empty: Dictionary = consequence.make_empty({"causal_day_instance": root.token, "causal_day_instance_issuer_receipt": root})
	consequence.commit(consequence.prepare_restore(empty.value.state).value.candidate)
	var day: Object = DayAdvance.new() if real_day == null else real_day
	var port := PORT.new()
	var capture := func(lifecycle: Dictionary) -> Dictionary:
		return {"snapshot_input": game.capture_run_snapshot_input(), "route_id": "hospital",
			"dialogic_checkpoint": {}, "active_app_id": "minesweeper", "audio_context": {}, "content_version": "fixture"}
	assert_true(port.configure(game, issuer, day, view, board, consequence, capture).get("ok", false))
	return {"game": game, "state": state, "port": port, "view": view, "board": board, "consequence": consequence, "day": day}

func test_day_prepare_freezes_recovery_without_mutating_gameplay_or_day() -> void:
	var wired := _wired()
	var game: Node = wired.game
	game.stats["pressure"] = 11
	game.stats["health"] = 0
	game.pending_hospital = true
	var before: Dictionary = game.capture_run_snapshot_input()
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	var plan := {"resolution_receipt": {"receipt_id": "hospital.resolution", "receipt_provenance": {}},
		"run_id": "run", "branch_id": "branch", "desktop_timeline_generation": 0, "source_day": 1,
		"causal_day_instance": lifecycle.causal_day_instance,
		"causal_day_instance_issuer_receipt": lifecycle.causal_day_instance_issuer_receipt}
	var prepared: Dictionary = wired.port._prepare_day(plan)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(game.capture_run_snapshot_input(), before)
	assert_eq(prepared.value.owner_candidate.gameplay.stats.health, 6)
	assert_eq(prepared.value.owner_candidate.gameplay.stats.pressure, 3)
	assert_false(prepared.value.owner_candidate.gameplay.pending_hospital)
	assert_eq(prepared.value.target_day, 2)
	assert_eq(prepared.value.owner_candidate.schedule_view.causal_day_instance, "causal.next")
	assert_eq(wired.day.commits, 1, "the shared identity commits before any target candidate is exposed")

func test_checkpoint_composition_uses_candidate_owners_and_keeps_live_state_unchanged() -> void:
	var wired := _wired()
	var game: Node = wired.game
	var before: Dictionary = game.capture_run_snapshot_input()
	var gameplay: Dictionary = before.gameplay.duplicate(true)
	gameplay["money"] = 777
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	var result: Dictionary = wired.port.compose_checkpoint_inputs(lifecycle, {"gameplay": gameplay})
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.value.checkpoint_inputs.snapshot_input.gameplay.money, 777)
	assert_eq(result.value.checkpoint_inputs.route_id, "main")
	assert_eq(result.value.checkpoint_inputs.dialogic_checkpoint, {})
	assert_eq(game.capture_run_snapshot_input(), before)

func test_ordinary_stage_publication_never_announces_a_day_advance() -> void:
	var wired := _wired()
	watch_signals(wired.game)
	assert_true(wired.port.publish_stage("present_hospital", null).get("ok", false))
	assert_signal_not_emitted(wired.game, "day_changed")

func test_real_root_day_advance_hashes_exact_identity_projection_and_replays_after_reload() -> void:
	var file_ops := FakeFileOps.new()
	var storage := JsonFileStorage.new("sandbox/condition-hospital-day", file_ops)
	var root := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd").new()
	var namespace_source := preload("res://tests/support/FakeDesktopNamespaceSource.gd").new("11".repeat(32))
	assert_true(root.configure(storage, namespace_source).get("ok", false))
	assert_true(root.load_or_create().get("ok", false))
	var source_result: Dictionary = root.issue(&"causal_day_instance")
	var transaction_result: Dictionary = root.issue(&"transaction_id")
	assert_true(source_result.get("ok", false), str(source_result))
	assert_true(transaction_result.get("ok", false), str(transaction_result))
	if not source_result.get("ok", false) or not transaction_result.get("ok", false): return
	var source: Dictionary = source_result.value.issuer_receipt
	var transaction: Dictionary = transaction_result.value.issuer_receipt
	var issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	assert_true(issuer.configure(root).get("ok", false))
	var day := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd").new()
	assert_true(day.configure(issuer).get("ok", false))
	var wired := _wired(issuer, day, source)
	var accepted: Dictionary = wired.state.prepare_accept({
		"action_receipt": {"receipt_id": "action.fixture", "transaction_id": transaction.token,
			"transaction_issuer_receipt": transaction},
		"condition_receipt": {"receipt_id": "condition.fixture"},
		"destination_record": {"key": "destination.fixture", "status": "pending",
			"payload": {"kind": "hospital_day", "accepted_unfulfilled_sources": []}}})
	assert_true(accepted.get("ok", false), str(accepted))
	if not accepted.get("ok", false): return
	assert_true(wired.state.commit(accepted.value.condition_hospital_candidate).get("ok", false))
	var plan: Dictionary = wired.game._run_lifecycle.to_dict().active_condition_hospital_plan
	var before_plan := plan.duplicate(true)
	var before_game: Dictionary = wired.game.capture_run_snapshot_input()
	var before_root: Dictionary = root.capture().value
	var prepared: Dictionary = wired.port._prepare_day(plan)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(plan, before_plan, "the full acceptance receipt remains unchanged")
	assert_eq(wired.game.capture_run_snapshot_input(), before_game, "identity persistence does not mutate live gameplay")
	var allocation: Dictionary = prepared.value.output.day_advance_identity_receipt
	var projection := {"receipt_id": plan.resolution_receipt.receipt_id,
		"provenance": plan.resolution_receipt.receipt_provenance}
	var canonical: Dictionary = preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(projection)
	assert_eq(allocation.source_resolution_receipt_sha256, str(canonical.value).sha256_text())
	assert_eq(allocation.target_day, 2)
	assert_true(issuer.verify_issued(allocation.target_causal_day_instance_issuer_receipt,
		&"causal_day_instance").get("ok", false))
	var committed_root: Dictionary = root.capture().value
	assert_eq(committed_root.next_counter, int(before_root.next_counter) + 1)
	assert_eq(committed_root.day_advance_allocation_receipts.size(), 1)
	# A fresh store verifies the serialized receipt/hash before any replay can occur.
	var fresh_root := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd").new()
	var fresh_ops := FakeFileOps.new(file_ops.snapshot_persisted())
	assert_true(fresh_root.configure(JsonFileStorage.new("sandbox/condition-hospital-day", fresh_ops),
		preload("res://tests/support/FakeDesktopNamespaceSource.gd").new("22".repeat(32))).get("ok", false))
	var loaded: Dictionary = fresh_root.load_or_create()
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	var fresh_issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	assert_true(fresh_issuer.configure(fresh_root).get("ok", false))
	var fresh_day := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd").new()
	assert_true(fresh_day.configure(fresh_issuer).get("ok", false))
	var fresh := _wired(fresh_issuer, fresh_day, source)
	var replay: Dictionary = fresh.port._prepare_day(plan)
	assert_true(replay.get("ok", false), str(replay))
	if not replay.get("ok", false): return
	assert_eq(replay.value.output.day_advance_identity_receipt, allocation)
	assert_eq(fresh_root.capture().value, committed_root, "retry never allocates a second target")
	var changed := plan.duplicate(true)
	changed.resolution_receipt.receipt_id += ".changed"
	assert_false(fresh.port._prepare_day(changed).get("ok", true), "changed receipt/provenance binding is rejected")
	assert_eq(fresh_root.capture().value, committed_root)