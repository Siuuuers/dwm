extends "res://addons/gut/test.gd"

# State-machine diagnostics only: fake materials bypass candidate admission here.
# Genuine allocation/Profile/Save/native evidence belongs to connected creation tests.
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const RESTORE_TEST := preload("res://tests/unit/test_scene_restore_journal.gd")

class StateMachineOnly:
	extends JOURNAL
	func _validate_kind_fields(operation: Dictionary, _kind: String) -> Dictionary:
		if operation.get("new_run_materials", {}).get("fixture") != "state-machine-only":
			return {"ok": false}
		if operation.has("new_run_targets"):
			return _validate_new_run_targets(operation["new_run_targets"], operation)
		return {"ok": true}

var storage: RESTORE_TEST.MemoryStorage
var loader: RESTORE_TEST.SourceLoader
var journal: StateMachineOnly

func before_each() -> void:
	storage = RESTORE_TEST.MemoryStorage.new()
	loader = RESTORE_TEST.SourceLoader.new()
	journal = StateMachineOnly.new()
	assert_true(journal.configure(storage, loader)["ok"])

func _request() -> Dictionary:
	var tx := "transaction_id." + "a".repeat(64)
	var context := {"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {"fixture": "actual-reading-is-tested-elsewhere"}, "route_id": "scene"}
	var allocation := {"fixture": "retained-allocation"}
	return {"allocation_candidate_fingerprint": WRITER.stringify(allocation)["value"].sha256_text(),
		"initial_context": context, "initial_context_sha256": WRITER.stringify(context)["value"].sha256_text(),
		"kind": "scene_new_run", "source_locator": null, "request_fingerprint": "b".repeat(64),
		"new_run_materials": {"fixture": "state-machine-only", "allocation_candidate": allocation,
			"autosave": {"outgoing_hash": "c".repeat(64)}, "profile": {"outgoing_hash": "d".repeat(64)}},
		"transaction_id": tx, "transaction_issuer_receipt": {"counter": 0, "namespace": "e".repeat(64),
			"numeric_value": null, "purpose": "transaction_id", "receipt_id": "issuer_receipt." + "f".repeat(64), "token": tx}}

func _intent() -> Dictionary:
	var prepared: Dictionary = journal.prepare_intent(_request())
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return {}
	var committed: Dictionary = journal.commit_intent(prepared["value"])
	assert_true(committed.get("ok", false), str(committed))
	return committed.get("value", {})

func _advance(operation: Dictionary, stage: String, allocation: Variant = null) -> Dictionary:
	return journal.advance({"transaction_id": operation["transaction_id"], "request_fingerprint": operation["request_fingerprint"],
		"expected_stage": operation["stage"], "next_stage": stage, "expected_next_participant_index": operation["next_participant_index"],
		"allocation_receipt": allocation, "participant_name": null, "participant_receipt": null, "failure": null})

func _allocated() -> Dictionary:
	var operation := _intent()
	if operation.is_empty(): return {}
	var result := _advance(operation, JOURNAL.STAGE_ALLOCATED, operation["new_run_materials"]["allocation_candidate"])
	assert_true(result.get("ok", false), str(result))
	return result.get("value", {})

func _applied() -> Dictionary:
	var operation := _allocated()
	if operation.is_empty(): return {}
	for target: String in JOURNAL.NEW_RUN_TARGET_ORDER:
		var recorded: Dictionary = journal.record_new_run_target(operation["transaction_id"], operation["request_fingerprint"],
			StringName(target), journal._expected_new_run_target_revision(operation, target))
		assert_true(recorded.get("ok", false), str(recorded))
		if not recorded.get("ok", false): return {}
		operation = recorded["value"]
	var result := _advance(operation, JOURNAL.STAGE_APPLYING)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return {}
	operation = result["value"]
	for name: String in JOURNAL.SCENE_PARTICIPANT_ORDER:
		result = journal.advance({"transaction_id": operation["transaction_id"], "request_fingerprint": operation["request_fingerprint"],
			"expected_stage": JOURNAL.STAGE_APPLYING, "next_stage": JOURNAL.STAGE_APPLYING,
			"expected_next_participant_index": operation["next_participant_index"], "allocation_receipt": null,
			"participant_name": name, "participant_receipt": {"applied": name}, "failure": null})
		assert_true(result.get("ok", false), str(result))
		if not result.get("ok", false): return {}
		operation = result["value"]
	result = _advance(operation, JOURNAL.STAGE_APPLIED)
	assert_true(result.get("ok", false), str(result))
	return result.get("value", {})

func test_creation_requires_retained_allocation_and_ordered_three_targets() -> void:
	var operation := _intent()
	if operation.is_empty(): return
	assert_false(_advance(operation, JOURNAL.STAGE_ALLOCATED, {"different": true})["ok"])
	operation = _advance(operation, JOURNAL.STAGE_ALLOCATED, operation["new_run_materials"]["allocation_candidate"])["value"]
	assert_false(_advance(operation, JOURNAL.STAGE_APPLYING)["ok"])
	assert_false(journal.record_new_run_target(operation["transaction_id"], operation["request_fingerprint"], &"profile", "d".repeat(64))["ok"])
	assert_true(journal.record_new_run_target(operation["transaction_id"], operation["request_fingerprint"], &"identity", operation["allocation_candidate_fingerprint"])["ok"])
	assert_false(_advance(operation, JOURNAL.STAGE_APPLYING)["ok"])
	assert_eq(journal.get_operation(operation["transaction_id"])["value"]["new_run_materials"], operation["new_run_materials"])

func test_completed_pending_creation_restarts_then_acknowledges_once() -> void:
	var operation := _applied()
	if operation.is_empty(): return
	assert_eq(operation["next_participant_index"], 8)
	assert_false(operation["participant_receipts"].has("schedule_view"))
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var restarted := StateMachineOnly.new()
	assert_true(restarted.configure(storage, loader)["ok"])
	var incomplete: Dictionary = restarted.list_incomplete()
	assert_true(incomplete["ok"])
	assert_eq(incomplete["value"][0]["activation_state"], "pending")
	assert_true(restarted.reconcile_startup(operation["transaction_id"], RESTORE_TEST.IssuerShapeOnly.new())["ok"])
	assert_eq(loader.calls, [])
	assert_true(restarted.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	var writes := storage.writes
	assert_true(restarted.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	assert_eq(storage.writes, writes)
	assert_eq(restarted.list_incomplete()["value"], [])

func test_uncertain_completion_physically_reloads_same_frozen_creation() -> void:
	var operation := _applied()
	if operation.is_empty(): return
	storage.promote_then_refuse = true
	assert_false(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var reloaded: Dictionary = journal.reload_operation_from_storage(operation["transaction_id"])
	assert_true(reloaded["ok"])
	assert_eq(reloaded["value"]["activation_state"], "pending")
	assert_eq(reloaded["value"]["new_run_materials"], operation["new_run_materials"])
	assert_eq(reloaded["value"]["new_run_targets"], operation["new_run_targets"])

func test_creation_schema_and_early_activation_are_closed() -> void:
	var operation := _intent()
	if operation.is_empty(): return
	assert_null(operation["activation_state"])
	assert_false(operation.has("selected_document"))
	assert_false(journal.acknowledge_scene_activation(operation["transaction_id"], operation["request_fingerprint"])["ok"])
	var physical: Dictionary = STRICT.parse_object(storage.text)["value"]
	assert_eq(physical["schema_version"], 5)
	physical["schema_version"] = 4
	storage.text = WRITER.stringify(physical)["value"]
	assert_false(journal.reload_operation_from_storage(operation["transaction_id"])["ok"])
	var actual := JOURNAL.new()
	assert_true(actual.configure(RESTORE_TEST.MemoryStorage.new(), loader)["ok"])
	assert_false(actual.prepare_intent(_request())["ok"], "real journal never admits these diagnostic materials")

func test_pending_creation_conflicts_with_pending_restore_and_blocks_other_intents() -> void:
	var operation := _applied()
	if operation.is_empty(): return
	assert_true(_advance(operation, JOURNAL.STAGE_COMPLETED)["ok"])
	var other := _request()
	other["transaction_id"] = "transaction_id." + "0".repeat(64)
	other["transaction_issuer_receipt"]["token"] = other["transaction_id"]
	assert_false(journal.prepare_intent(other)["ok"])
	# Inspect the common fence directly; retained Restore validation is covered by
	# its separate real journal tests. A different kind must not hide this conflict.
	var pending_restore := {"kind": "scene_restore", "stage": JOURNAL.STAGE_COMPLETED,
		"activation_state": "pending", "transaction_id": other["transaction_id"]}
	journal._document["operations"][other["transaction_id"]] = pending_restore
	assert_false(journal.list_incomplete()["ok"])

func test_creation_durable_intent_cannot_abort_or_accept_restore_members() -> void:
	var operation := _intent()
	if operation.is_empty(): return
	var aborted: Dictionary = journal.advance({"transaction_id": operation["transaction_id"], "request_fingerprint": operation["request_fingerprint"],
		"expected_stage": JOURNAL.STAGE_INTENT, "next_stage": JOURNAL.STAGE_ABORTED, "expected_next_participant_index": 0,
		"allocation_receipt": null, "participant_name": null, "participant_receipt": null,
		"failure": {"code": "source_unprovable", "message": "diagnostic", "details": {}}})
	assert_false(aborted["ok"])
	var changed := operation.duplicate(true)
	changed["selected_document"] = {}
	assert_false(journal.commit_intent(changed)["ok"])
	changed = operation.duplicate(true)
	changed["activation_state"] = "pending"
	assert_false(journal.commit_intent(changed)["ok"])
