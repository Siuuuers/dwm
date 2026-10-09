extends "res://addons/gut/test.gd"

# Explicit journal state-machine diagnostics. The subclass bypasses ONLY Save9 admission;
# these tests do not claim actual Run9/Save9, filesystem, native or live-session proof.
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

class StateMachineOnly:
	extends JOURNAL
	func _validate_scene_source(operation: Dictionary) -> Dictionary:
		return {"ok": operation.get("selected_document") == {"fixture": "journal-transition-only"}}

class MemoryStorage:
	extends RefCounted
	var text := ""
	var writes := 0
	var refuse := false
	var promote_then_refuse := false
	func reconcile(_path: String, parser: Callable) -> Dictionary:
		if text.is_empty(): return {"ok": true, "exists": false}
		var parsed: Dictionary = parser.call(text)
		if not parsed.get("ok", false): return parsed
		return {"ok": true, "exists": true, "value": parsed["value"], "hash": text.sha256_text()}
	func write_atomic(_path: String, value: String, validator: Callable, _backup: bool) -> Dictionary:
		writes += 1
		if refuse: return {"ok": false, "code": &"diagnostic_refusal"}
		var valid: Dictionary = validator.call(value)
		if not valid.get("ok", false): return valid
		text = value
		if promote_then_refuse: return {"ok": false, "code": &"diagnostic_uncertain"}
		return {"ok": true}

class SourceLoader:
	extends RefCounted
	var calls: Array = []
	var context := {"diagnostic_selected": true}
	func load_context(_locator: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"overwritten_slot"}
	func load_restore_context(tx: String, locator: Dictionary) -> Dictionary:
		calls.append({"transaction_id": tx, "locator": locator.duplicate(true)})
		return {"ok": true, "value": {"context": context.duplicate(true),
			"context_sha256": WRITER.stringify(context)["value"].sha256_text()}}

class IssuerShapeOnly:
	extends RefCounted
	func verify_issued(_receipt: Dictionary, _purpose: StringName) -> Dictionary:
		return {"ok": true}

var storage: MemoryStorage
var loader: SourceLoader
var journal: StateMachineOnly

func before_each() -> void:
	storage = MemoryStorage.new()
	loader = SourceLoader.new()
	journal = StateMachineOnly.new()
	assert_true(journal.configure(storage, loader)["ok"])

func _request(suffix: String = "a", scene: bool = true) -> Dictionary:
	var tx := "transaction_id." + suffix.repeat(64)
	var request := {
		"allocation_candidate_fingerprint": "b".repeat(64),
		"initial_context": null, "initial_context_sha256": null,
		"kind": "scene_restore" if scene else "restore", "new_run_materials": null,
		"request_fingerprint": "c".repeat(64),
		"source_locator": {"bundle_id": "d".repeat(64), "checkpoint_id": "selected",
			"document_sha256": WRITER.stringify(loader.context)["value"].sha256_text(), "slot_id": "slot:1"},
		"transaction_id": tx,
		"transaction_issuer_receipt": {"counter": 0, "namespace": "e".repeat(64),
			"numeric_value": null, "purpose": "transaction_id",
			"receipt_id": "issuer_receipt." + "f".repeat(64), "token": tx},
	}
	if scene: request["selected_document"] = {"fixture": "journal-transition-only"}
	return request

func _intent(request: Dictionary) -> Dictionary:
	var prepared: Dictionary = journal.prepare_intent(request)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return {}
	var committed: Dictionary = journal.commit_intent(prepared["value"])
	assert_true(committed.get("ok", false), str(committed))
	return committed.get("value", {})

func _advance(operation: Dictionary, next_stage: String, receipt: Variant = null) -> Dictionary:
	return journal.advance({
		"transaction_id": operation["transaction_id"], "request_fingerprint": operation["request_fingerprint"],
		"expected_stage": operation["stage"], "next_stage": next_stage,
		"expected_next_participant_index": operation["next_participant_index"],
		"allocation_receipt": receipt, "participant_name": null, "participant_receipt": null, "failure": null})

func _applied(request: Dictionary) -> Dictionary:
	var operation := _intent(request)
	if operation.is_empty(): return {}
	var result := _advance(operation, JOURNAL.STAGE_ALLOCATED, {"diagnostic_allocation": true})
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return {}
	result = _advance(result["value"], JOURNAL.STAGE_APPLYING)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return {}
	operation = result["value"]
	for name: String in JOURNAL.SCENE_PARTICIPANT_ORDER:
		result = journal.advance({"transaction_id": operation["transaction_id"],
			"request_fingerprint": operation["request_fingerprint"], "expected_stage": JOURNAL.STAGE_APPLYING,
			"next_stage": JOURNAL.STAGE_APPLYING, "expected_next_participant_index": operation["next_participant_index"],
			"allocation_receipt": null, "participant_name": name, "participant_receipt": {"applied": name}, "failure": null})
		assert_true(result.get("ok", false), str(result))
		if not result.get("ok", false): return {}
		operation = result["value"]
	result = _advance(operation, JOURNAL.STAGE_APPLIED)
	assert_true(result.get("ok", false), str(result))
	return result.get("value", {})

func test_atomic_completed_pending_survives_fresh_journal_and_uses_retained_loader() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	var completed := _advance(operation, JOURNAL.STAGE_COMPLETED)
	assert_true(completed["ok"])
	var physical: Dictionary = STRICT.parse_object(storage.text)["value"]
	assert_eq(physical["schema_version"], 5)
	var saved: Dictionary = physical["operations"][operation["transaction_id"]]
	assert_eq(saved["stage"], JOURNAL.STAGE_COMPLETED)
	assert_eq(saved["activation_state"], "pending")
	assert_eq(saved["allocation_receipt"], operation["allocation_receipt"])
	var restarted := StateMachineOnly.new()
	assert_true(restarted.configure(storage, loader)["ok"])
	assert_eq(restarted.list_incomplete()["value"].size(), 1)
	assert_true(restarted.reconcile_startup(operation["transaction_id"], IssuerShapeOnly.new())["ok"])
	assert_eq(loader.calls.size(), 1)
	assert_eq(loader.calls[0]["transaction_id"], operation["transaction_id"])

func test_acknowledgement_is_durable_idempotent_and_not_historical_boot_replay() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var tx: String = operation["transaction_id"]
	assert_false(journal.acknowledge_scene_activation(tx, "0".repeat(64))["ok"])
	assert_true(journal.acknowledge_scene_activation(tx, operation["request_fingerprint"])["ok"])
	var writes_before := storage.writes
	assert_true(journal.acknowledge_scene_activation(tx, operation["request_fingerprint"])["ok"])
	assert_eq(storage.writes, writes_before)
	var restarted := StateMachineOnly.new()
	assert_true(restarted.configure(storage, loader)["ok"])
	assert_eq(restarted.list_incomplete()["value"], [])
	assert_true(restarted.reconcile_startup(tx, IssuerShapeOnly.new())["ok"])
	assert_eq(loader.calls, [])
	assert_eq(restarted.get_operation(tx)["value"]["activation_state"], "acknowledged")

func test_definite_and_uncertain_completion_write_require_physical_reconciliation() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	storage.refuse = true
	assert_false(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	assert_eq(journal.get_operation(operation["transaction_id"])["value"]["stage"], JOURNAL.STAGE_APPLIED)
	storage.refuse = false
	storage.promote_then_refuse = true
	assert_false(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var reloaded: Dictionary = journal.get_operation(operation["transaction_id"])["value"]
	assert_eq(reloaded["stage"], JOURNAL.STAGE_COMPLETED)
	assert_eq(reloaded["activation_state"], "pending")
	storage.promote_then_refuse = false
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	assert_eq(journal.get_operation(operation["transaction_id"])["value"]["allocation_receipt"], operation["allocation_receipt"])

func test_pending_fences_new_intent_and_ack_refusal_retains_pending() -> void:
	var other := _request("b")
	var prepared: Dictionary = journal.prepare_intent(other)
	assert_true(prepared["ok"])
	var operation := _applied(_request())
	if operation.is_empty(): return
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	assert_false(journal.prepare_intent(other)["ok"])
	assert_false(journal.commit_intent(prepared["value"])["ok"])
	storage.refuse = true
	assert_false(journal.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	assert_eq(journal.list_incomplete()["value"][0]["activation_state"], "pending")

func test_conflicting_pending_records_and_schema4_scene_smuggling_refuse() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var physical: Dictionary = STRICT.parse_object(storage.text)["value"]
	var first: Dictionary = physical["operations"][operation["transaction_id"]]
	var second := first.duplicate(true)
	second["transaction_id"] = _request("b")["transaction_id"]
	second["transaction_issuer_receipt"] = _request("b")["transaction_issuer_receipt"]
	physical["operations"][second["transaction_id"]] = second
	storage.text = WRITER.stringify(physical)["value"]
	var restarted := StateMachineOnly.new()
	assert_true(restarted.configure(storage, loader)["ok"])
	assert_false(restarted.list_incomplete()["ok"])
	physical["operations"].erase(second["transaction_id"])
	physical["schema_version"] = 4
	storage.text = WRITER.stringify(physical)["value"]
	restarted = StateMachineOnly.new()
	assert_true(restarted.configure(storage, loader)["ok"])
	assert_false(restarted.list_incomplete()["ok"])

func test_old_operation_members_and_canonical_bytes_survive_envelope_extension() -> void:
	var old := _intent(_request("b", false))
	assert_false(old.has("selected_document"))
	assert_false(old.has("activation_state"))
	assert_eq(STRICT.parse_object(storage.text)["value"]["schema_version"], 4)
	var before: String = WRITER.stringify(old)["value"]
	var scene := _intent(_request())
	assert_false(scene.is_empty())
	var physical: Dictionary = STRICT.parse_object(storage.text)["value"]
	assert_eq(physical["schema_version"], 5)
	assert_eq(WRITER.stringify(physical["operations"][old["transaction_id"]])["value"], before)

func test_actual_journal_refuses_primitive_only_save9_and_early_ack() -> void:
	var actual := JOURNAL.new()
	assert_true(actual.configure(MemoryStorage.new(), loader)["ok"])
	var request := _request()
	request["selected_document"] = {"schema_version": 9}
	assert_false(actual.prepare_intent(request)["ok"])
	var operation := _intent(_request())
	assert_false(journal.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])

func test_pending_diagnostic_retains_identity_and_requires_reverified_source() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	operation = _advance(operation, JOURNAL.STAGE_COMPLETED)["value"]
	var failure := {"code": "native_unavailable", "message": "diagnostic only", "details": {}}
	var recorded: Dictionary = journal.advance({"transaction_id": operation["transaction_id"],
		"request_fingerprint": operation["request_fingerprint"], "expected_stage": JOURNAL.STAGE_COMPLETED,
		"next_stage": JOURNAL.STAGE_COMPLETED, "expected_next_participant_index": 8,
		"allocation_receipt": null, "participant_name": null, "participant_receipt": null, "failure": failure})
	assert_true(recorded["ok"])
	assert_false(journal.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	loader.context = {"different": true}
	assert_false(journal.reconcile_startup(operation["transaction_id"], IssuerShapeOnly.new())["ok"])
	assert_eq(journal.get_operation(operation["transaction_id"])["value"]["failure"], failure)
	loader.context = {"diagnostic_selected": true}
	assert_true(journal.reconcile_startup(operation["transaction_id"], IssuerShapeOnly.new())["ok"])
	var recovered: Dictionary = journal.get_operation(operation["transaction_id"])["value"]
	assert_null(recovered["failure"])
	assert_eq(recovered["allocation_receipt"], operation["allocation_receipt"])
	assert_eq(recovered["activation_state"], "pending")

func test_ack_uncertain_write_reloads_without_second_activation_write() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	storage.promote_then_refuse = true
	assert_false(journal.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	storage.promote_then_refuse = false
	var writes_before := storage.writes
	assert_true(journal.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	assert_eq(storage.writes, writes_before)
	assert_eq(journal.list_incomplete()["value"], [])

func test_scene_member_and_activation_shape_are_exact() -> void:
	var request := _request()
	request["activation_state"] = "acknowledged"
	assert_false(journal.prepare_intent(request)["ok"])
	var prepared: Dictionary = journal.prepare_intent(_request())
	assert_true(prepared["ok"])
	var candidate: Dictionary = prepared["value"]
	candidate["activation_state"] = "pending"
	assert_false(journal.commit_intent(candidate)["ok"])
	candidate["activation_state"] = null
	candidate["participant_receipts"]["schedule_view"] = null
	assert_false(journal.commit_intent(candidate)["ok"])

func test_explicit_reload_observes_physical_change_and_revalidates() -> void:
	var operation := _applied(_request())
	if operation.is_empty(): return
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var physical: Dictionary = STRICT.parse_object(storage.text)["value"]
	physical["operations"][operation["transaction_id"]]["activation_state"] = "acknowledged"
	storage.text = WRITER.stringify(physical)["value"]
	assert_eq(journal.get_operation(operation["transaction_id"])["value"]["activation_state"], "pending")
	assert_eq(journal.reload_operation_from_storage(operation["transaction_id"])["value"]["activation_state"], "acknowledged")
	physical["operations"][operation["transaction_id"]]["activation_state"] = "forged"
	storage.text = WRITER.stringify(physical)["value"]
	assert_false(journal.reload_operation_from_storage(operation["transaction_id"])["ok"])

