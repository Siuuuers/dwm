class_name DesktopContinuationOperationJournal
extends RefCounted

## Durable New Run / selected Load continuation-operation journal (Plan 02 Task 1, dwm-p2r.16).
## External to every selectable snapshot: this uses its injected atomic storage and source-loader.
const JOURNAL_PATH := "desktop-continuation-operations.json"
const SCHEMA_VERSION := 1
const STAGE_INTENT := "intent_committed"
const STAGE_ALLOCATED := "identity_allocation_committed"
const STAGE_APPLYING := "participants_applying"
const STAGE_APPLIED := "participants_applied"
const STAGE_COMPLETED := "completed"
const STAGE_ABORTED := "aborted"

const OPERATION_KEYS: Array[String] = [
	"allocation_candidate_fingerprint",
	"allocation_receipt",
	"failure",
	"initial_context",
	"initial_context_sha256",
	"kind",
	"next_participant_index",
	"participant_receipts",
	"request_fingerprint",
	"source_locator",
	"stage",
	"transaction_id",
	"transaction_issuer_receipt",
]

const PREPARE_INTENT_KEYS: Array[String] = [
	"allocation_candidate_fingerprint",
	"initial_context",
	"initial_context_sha256",
	"kind",
	"request_fingerprint",
	"source_locator",
	"transaction_id",
	"transaction_issuer_receipt",
]

const ADVANCE_KEYS: Array[String] = [
	"allocation_receipt",
	"expected_next_participant_index",
	"expected_stage",
	"failure",
	"next_stage",
	"participant_name",
	"participant_receipt",
	"request_fingerprint",
	"transaction_id",
]

const PARTICIPANT_ORDER: Array[String] = [
	"run",
	"desktop_consequence",
	"desktop_board",
	"profile",
	"localization",
	"audio",
	"route",
	"narrative",
]

const STAGE_UNION: Array[String] = [
	STAGE_INTENT,
	STAGE_ALLOCATED,
	STAGE_APPLYING,
	STAGE_APPLIED,
	STAGE_COMPLETED,
	STAGE_ABORTED,
]

const KIND_UNION: Array[String] = ["new_run", "restore"]
const DOCUMENT_KEYS: Array[String] = ["operations", "schema_version"]

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _storage: Object = null
var _source_loader: Object = null
var _document: Dictionary = {}
var _loaded := false
var _schema_error: StringName = &"journal_schema_invalid"


func configure(storage: Object, source_loader: Object) -> Dictionary:
	if storage == null:
		return _failed(&"journal_storage_unbound", "configure requires a storage")
	if source_loader == null:
		return _failed(&"journal_source_loader_unbound", "configure requires a source loader")
	if _storage != null:
		if _storage == storage and _source_loader == source_loader:
			return {"ok": true}
		return _failed(&"journal_already_configured", "journal may not replace an existing configuration")
	_storage = storage
	_source_loader = source_loader
	_loaded = false
	_document = {}
	return {"ok": true}


func prepare_intent(request: Dictionary) -> Dictionary:
	var ready := _require_configured("prepare_intent")
	if not ready.get("ok", false):
		return ready

	var shape := _exact_keys(request, PREPARE_INTENT_KEYS)
	if not shape.get("ok", false):
		return shape

	var request_ok := _validate_intent_request(request)
	if not request_ok.get("ok", false):
		return request_ok

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded

	var txid := str(request["transaction_id"])
	var operations: Dictionary = _document.get("operations", {})
	if not operations.has(txid):
		return {"ok": true, "value": _intent_candidate(request)}

	var recorded: Dictionary = operations[txid]
	var expected: Dictionary = _intent_candidate_from_operation(recorded)
	if str(recorded.get("stage", "")) != STAGE_INTENT:
		return _failed(&"intent_transaction_occupied", txid)
	if _operation_equals(expected, _intent_candidate(request)):
		return {"ok": true, "value": expected}
	return _failed(&"intent_transaction_conflict", txid)


func commit_intent(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured("commit_intent")
	if not ready.get("ok", false):
		return ready

	var shape := _exact_keys(candidate, OPERATION_KEYS)
	if not shape.get("ok", false):
		return shape

	var valid := _validate_operation(candidate)
	if not valid.get("ok", false):
		return valid
	if str(candidate.get("stage", "")) != STAGE_INTENT:
		return _failed(&"intent_stage_invalid", str(candidate.get("stage", "")))

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded

	var txid := str(candidate["transaction_id"])
	var operations: Dictionary = _document.get("operations", {})
	if operations.has(txid):
		var recorded: Dictionary = operations[txid]
		if _operation_equals(recorded, candidate):
			return {"ok": true, "value": recorded.duplicate(true)}
		return _failed(&"continuation_transaction_conflict", txid)

	var next_document := _document.duplicate(true)
	next_document["operations"][txid] = candidate.duplicate(true)
	var written := _write(next_document)
	if not written.get("ok", false):
		return written
	_document = next_document
	return {"ok": true, "value": candidate.duplicate(true)}


func advance(request: Dictionary) -> Dictionary:
	var ready := _require_configured("advance")
	if not ready.get("ok", false):
		return ready

	var shape := _exact_keys(request, ADVANCE_KEYS)
	if not shape.get("ok", false):
		return shape

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded

	var txid := str(request["transaction_id"])
	var operations: Dictionary = _document.get("operations", {})
	if not operations.has(txid):
		return _failed(&"continuation_transaction_not_found", txid)
	var operation: Dictionary = operations[txid]
	if str(request["request_fingerprint"]) != str(operation.get("request_fingerprint", "")):
		return _failed(&"continuation_request_conflict", txid)

	var request_ok := _validate_advance_request(request, operation)
	if not request_ok.get("ok", false):
		return request_ok

	var next := _advance_one_step(operation, request)
	if not next.get("ok", false):
		var replay := _replay_for_advanced_transition(operation, request)
		if replay.get("ok", false):
			return {"ok": true, "value": operation.duplicate(true)}
		return next

	var progressed: Dictionary = next.get("value", {})
	if _operation_equals(progressed, operation):
		return {"ok": true, "value": operation.duplicate(true)}
	var next_document := _document.duplicate(true)
	next_document["operations"][txid] = progressed
	var written := _write(next_document)
	if not written.get("ok", false):
		return written
	_document["operations"][txid] = progressed
	return {"ok": true, "value": progressed.duplicate(true)}


func get_operation(transaction_id: String) -> Dictionary:
	var ready := _require_configured("get_operation")
	if not ready.get("ok", false):
		return ready
	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded
	if not _document.get("operations", {}).has(transaction_id):
		return _failed(&"continuation_transaction_not_found", transaction_id)
	return {"ok": true, "value": (_document["operations"][transaction_id] as Dictionary).duplicate(true)}


func list_incomplete() -> Dictionary:
	var ready := _require_configured("list_incomplete")
	if not ready.get("ok", false):
		return ready
	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded
	var listed: Array[Dictionary] = []
	for operation: Dictionary in (_document.get("operations", {}).values() as Array):
		var stage := str(operation.get("stage", ""))
		if stage == STAGE_COMPLETED or stage == STAGE_ABORTED:
			continue
		listed.append(operation.duplicate(true))
	return {"ok": true, "value": listed}


func reconcile_startup(transaction_id: String, issuer: Object) -> Dictionary:
	var ready := _require_configured("reconcile_startup")
	if not ready.get("ok", false):
		return ready

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded
	var operations: Dictionary = _document.get("operations", {})
	if not operations.has(transaction_id):
		return _failed(&"continuation_transaction_not_found", transaction_id)
	var operation: Dictionary = operations[transaction_id]

	var verified: Dictionary = issuer.call(
		&"verify_issued", operation.get("transaction_issuer_receipt"), &"transaction_id")
	if not verified.get("ok", false):
		return verified

	var stage := str(operation.get("stage", ""))
	if stage == STAGE_COMPLETED or stage == STAGE_ABORTED:
		return {"ok": true}
	if str(operation.get("kind", "")) == "new_run":
		var computed := _canonical_sha256(operation.get("initial_context"))
		if computed.is_empty():
			return _failed(&"continuation_context_hash_unhashable", tx_hash_reason(operation))
		if str(operation.get("initial_context_sha256", "")) != str(computed):
			return _failed(&"continuation_context_hash_mismatch", str(operation.get("transaction_id", "")))
	else:
		var locator: Variant = operation.get("source_locator")
		if typeof(locator) != TYPE_DICTIONARY:
			return _failed(&"operation_source_locator_invalid", str(operation.get("transaction_id", "")))
		var loaded_source: Dictionary = _source_loader.call(&"load_context", locator)
		if not loaded_source.get("ok", false):
			return loaded_source
		var payload: Dictionary = loaded_source.get("value", {})
		if not payload.has("context") or not payload.has("context_sha256"):
			return _failed(&"operation_source_payload_invalid", str(operation.get("transaction_id", "")))
		if str(payload.get("context_sha256", "")) != str(locator.get("document_sha256", "")):
			return _failed(&"continuation_source_hash_mismatch", str(operation.get("transaction_id", "")))

	if operation.get("failure", null) == null:
		return {"ok": true}
	var cleared_operation := operation.duplicate(true)
	cleared_operation["failure"] = null
	var next_document := _document.duplicate(true)
	next_document["operations"][transaction_id] = cleared_operation
	var written := _write(next_document)
	if not written.get("ok", false):
		return written
	_document = next_document
	return {"ok": true}


func _require_configured(method: String) -> Dictionary:
	if _storage == null or _source_loader == null:
		return _failed(&"journal_not_configured", "DesktopContinuationOperationJournal.%s before configure" % method)
	return {"ok": true}


func _load() -> Dictionary:
	if _loaded:
		return {"ok": true}

	var reconciled: Dictionary = _storage.call(&"reconcile", JOURNAL_PATH, Callable(self, "_parse_document"))
	if not reconciled.get("ok", false):
		return _storage_failure(reconciled)
	var document: Dictionary
	if not reconciled.get("exists", false):
		document = {"schema_version": SCHEMA_VERSION, "operations": {}}
	else:
		document = reconciled.get("value", {})
		var validated := _validate_document(document)
		if not validated.get("ok", false):
			return validated
	_document = document.duplicate(true)
	_loaded = true
	return {"ok": true}


func _write(document: Dictionary) -> Dictionary:
	var emitted := _CANONICAL_WRITER.stringify(document)
	if not emitted.get("ok", false):
		return _failed(&"journal_serialization_failed", str(emitted.get("message", "cannot serialize journal")))
	var parsed := _validate_document(document)
	if not parsed.get("ok", false):
		return parsed
	var write_result: Dictionary = _storage.call(
		&"write_atomic", JOURNAL_PATH, str(emitted["value"]), Callable(self, "_parse_document"), true
	)
	if not write_result.get("ok", false):
		return _storage_failure(write_result)
	return {"ok": true}


func _parse_document(text: String) -> Dictionary:
	return _STRICT_JSON.parse_object(text)


func _validate_document(document: Variant) -> Dictionary:
	if typeof(document) != TYPE_DICTIONARY:
		return _failed(_schema_error, "document is not a dictionary")
	var document_keys: Array = document.keys()
	document_keys.sort()
	if document_keys != DOCUMENT_KEYS:
		return _failed(_schema_error, "document has unexpected members: " + str(document_keys))
	if int(document.get("schema_version", -1)) != SCHEMA_VERSION:
		return _failed(_schema_error, "invalid schema_version")
	if typeof(document.get("operations", {})) != TYPE_DICTIONARY:
		return _failed(_schema_error, "operations is not a dictionary")
	for key: String in document["operations"]:
		if key.is_empty():
			return _failed(_schema_error, "transaction_id must be non-empty")
		var operation: Dictionary = document["operations"][key]
		if typeof(operation.get("transaction_id")) != TYPE_STRING:
			return _failed(_schema_error, "transaction_id must be a string for key " + str(key))
		if str(operation.get("transaction_id")) != key:
			return _failed(_schema_error, "transaction_id must match operations key")
		var validated := _validate_operation(operation)
		if not validated.get("ok", false):
			return validated
	return {"ok": true}


func _validate_operation(operation: Dictionary) -> Dictionary:
	var keys: Array = operation.keys()
	keys.sort()
	var expected := OPERATION_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _failed(_schema_error, "operation has unexpected members: " + str(keys))
	var stage := str(operation.get("stage", ""))
	if not STAGE_UNION.has(stage):
		return _failed(_schema_error, "invalid stage: " + stage)
	var kind := str(operation.get("kind", ""))
	if not KIND_UNION.has(kind):
		return _failed(_schema_error, "invalid kind: " + kind)
	if typeof(operation.get("transaction_issuer_receipt")) != TYPE_DICTIONARY:
		return _failed(_schema_error, "operation must contain transaction_issuer_receipt as dictionary")
	var next_index: Variant = operation.get("next_participant_index", -1)
	if typeof(next_index) != TYPE_INT:
		return _failed(_schema_error, "next_participant_index must be an integer")
	var index := int(next_index)
	if index < 0 or index > PARTICIPANT_ORDER.size():
		return _failed(_schema_error, "invalid participant index: " + str(index))
	var receipts_value: Variant = operation.get("participant_receipts", {})
	if typeof(receipts_value) != TYPE_DICTIONARY:
		return _failed(_schema_error, "participant_receipts must be a dictionary")
	var receipts: Dictionary = receipts_value
	var receipt_keys: Array = receipts.keys()
	receipt_keys.sort()
	var ordered := PARTICIPANT_ORDER.duplicate()
	ordered.sort()
	if receipt_keys != ordered:
		return _failed(_schema_error, "invalid participant_receipts members")
	for name in PARTICIPANT_ORDER:
		var receipt: Variant = receipts.get(name)
		if receipt != null and typeof(receipt) != TYPE_DICTIONARY:
			return _failed(_schema_error, "participant receipt must be null or a dictionary")
	return {"ok": true}


func _validate_intent_request(request: Dictionary) -> Dictionary:
	if typeof(request.get("transaction_id")) != TYPE_STRING or str(request["transaction_id"]).strip_edges().is_empty():
		return _failed(&"invalid_intent_request", "transaction_id must be non-empty")
	if typeof(request["request_fingerprint"]) != TYPE_STRING or str(request["request_fingerprint"]).is_empty():
		return _failed(&"invalid_intent_request", "request_fingerprint must be non-empty")
	if typeof(request["allocation_candidate_fingerprint"]) != TYPE_STRING \
			or str(request["allocation_candidate_fingerprint"]).is_empty():
		return _failed(&"invalid_intent_request", "allocation_candidate_fingerprint must be non-empty")
	if typeof(request["kind"]) != TYPE_STRING:
		return _failed(&"invalid_intent_request", "kind must be a string")
	var kind := str(request["kind"])
	if not KIND_UNION.has(kind):
		return _failed(&"invalid_intent_request", "kind must be new_run or restore")
	if kind == "new_run":
		if request.get("source_locator") != null:
			return _failed(&"invalid_intent_request", "new_run requires null source_locator")
		if typeof(request["initial_context"]) != TYPE_DICTIONARY:
			return _failed(&"invalid_intent_request", "new_run requires initial_context object")
		if typeof(request["initial_context_sha256"]) != TYPE_STRING:
			return _failed(&"invalid_intent_request", "new_run requires initial_context_sha256 string")
		var hashed := _canonical_sha256(request.get("initial_context"))
		if hashed.is_empty():
			return _failed(&"invalid_intent_request", "initial_context is not canonicalizable")
		if str(request["initial_context_sha256"]) != str(hashed):
			return _failed(&"continuation_context_hash_mismatch", str(request["transaction_id"]))
	else:
		if request.get("initial_context") != null:
			return _failed(&"invalid_intent_request", "restore requires null initial_context")
		if request.get("initial_context_sha256") != null:
			return _failed(&"invalid_intent_request", "restore requires null initial_context_sha256")
		if typeof(request.get("source_locator")) != TYPE_DICTIONARY:
			return _failed(&"invalid_intent_request", "restore requires object source_locator")
	if typeof(request.get("transaction_issuer_receipt")) != TYPE_DICTIONARY:
		return _failed(&"invalid_intent_request", "transaction_issuer_receipt must be a dictionary")
	return {"ok": true}


func _validate_advance_request(request: Dictionary, operation: Dictionary) -> Dictionary:
	if typeof(request.get("transaction_id")) != TYPE_STRING or str(request["transaction_id"]).strip_edges().is_empty():
		return _failed(&"invalid_advance_request", "transaction_id must be non-empty")
	if typeof(request.get("request_fingerprint")) != TYPE_STRING or str(request["request_fingerprint"]).is_empty():
		return _failed(&"invalid_advance_request", "request_fingerprint must be non-empty")
	if str(request["request_fingerprint"]) != str(operation.get("request_fingerprint", "")):
		return _failed(&"continuation_request_conflict", str(request["transaction_id"]))
	if typeof(request.get("expected_stage")) != TYPE_STRING:
		return _failed(&"invalid_advance_request", "expected_stage must be a string")
	if typeof(request.get("next_stage")) != TYPE_STRING:
		return _failed(&"invalid_advance_request", "next_stage must be a string")
	if typeof(request.get("expected_next_participant_index")) != TYPE_INT:
		return _failed(&"invalid_advance_request", "expected_next_participant_index must be an integer")
	var index := int(request["expected_next_participant_index"])
	if index < 0 or index > PARTICIPANT_ORDER.size():
		return _failed(&"invalid_advance_request", "expected_next_participant_index out of range")
	var expected_stage := str(request["expected_stage"])
	var next_stage := str(request["next_stage"])
	if not STAGE_UNION.has(expected_stage):
		return _failed(&"invalid_advance_request", "expected_stage must be a legal stage")
	if not STAGE_UNION.has(next_stage):
		return _failed(&"invalid_advance_request", "next_stage must be a legal stage")
	if request["failure"] != null:
		var valid_failure := _validate_failure(request["failure"])
		if not valid_failure.get("ok", false):
			return valid_failure
	return {"ok": true}


func _validate_failure(value: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failed(&"invalid_failure", "failure must be a dictionary")
	var keys: Array = value.keys()
	keys.sort()
	var expected := ["code", "details", "message"]
	expected.sort()
	if keys != expected:
		return _failed(&"invalid_failure", "failure keys must be {code, message, details}")
	if typeof(value["code"]) != TYPE_STRING and typeof(value["code"]) != TYPE_STRING_NAME:
		return _failed(&"invalid_failure", "failure.code must be a string")
	if str(value["code"]).is_empty():
		return _failed(&"invalid_failure", "failure.code must be non-empty")
	if typeof(value["message"]) != TYPE_STRING and typeof(value["message"]) != TYPE_STRING_NAME:
		return _failed(&"invalid_failure", "failure.message must be a string")
	if str(value["message"]).is_empty():
		return _failed(&"invalid_failure", "failure.message must be non-empty")
	if typeof(value["details"]) != TYPE_DICTIONARY:
		return _failed(&"invalid_failure", "failure.details must be a dictionary")
	return {"ok": true}


func _advance_one_step(operation: Dictionary, request: Dictionary) -> Dictionary:
	var expected := str(request["expected_stage"])
	var next_stage := str(request["next_stage"])
	var index := int(request["expected_next_participant_index"])
	var failure: Variant = request.get("failure", null)
	var request_alloc_receipt: Variant = request.get("allocation_receipt")
	var request_name: Variant = request.get("participant_name")
	var request_receipt: Variant = request.get("participant_receipt")
	var operation_stage := str(operation.get("stage", ""))

	if failure != null and expected != STAGE_INTENT and next_stage == expected and \
			request_alloc_receipt == null and request_name == null and request_receipt == null:
		return _apply_recovery_diagnostic(operation, request)

	match expected:
		STAGE_INTENT:
			if next_stage == STAGE_ALLOCATED:
				return _advance_intent_to_allocated(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			if next_stage == STAGE_ABORTED:
				return _advance_intent_to_abort(operation, failure, request_alloc_receipt, request_name, request_receipt, index)
			return _failed(&"advance_request_invalid", "invalid intent transition")

		STAGE_ALLOCATED:
			if next_stage == STAGE_APPLYING:
				return _advance_allocated_to_applying(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			if next_stage == STAGE_APPLIED:
				return _advance_allocated_to_applied(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			if next_stage == STAGE_COMPLETED:
				return _advance_allocated_to_completed(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			return _failed(&"advance_request_invalid", "invalid allocation transition")

		STAGE_APPLYING:
			if next_stage == STAGE_APPLYING:
				return _advance_apply_participant(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			if next_stage == STAGE_APPLIED:
				return _advance_to_applied(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			if next_stage == STAGE_COMPLETED:
				return _advance_apply_to_completed(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			return _failed(&"advance_request_invalid", "invalid applying transition")

		STAGE_APPLIED:
			if next_stage == STAGE_COMPLETED:
				return _advance_to_completed(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			return _failed(&"advance_request_invalid", "invalid applied transition")

		_:
			return _failed(&"advance_request_invalid", "terminal stage cannot advance")


func _advance_intent_to_allocated(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_INTENT:
		return _failed(&"illegal_stage", "expected intent stage")
	if failure != null:
		return _failed(&"advance_request_invalid", "intent commit cannot carry failure")
	if participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "intent commit carries no participant evidence")
	if index != 0:
		return _failed(&"advance_request_invalid", "intent commit requires index 0")
	if typeof(allocation_receipt) != TYPE_DICTIONARY:
		return _failed(&"advance_request_invalid", "allocation_receipt must be a receipt")
	if operation.get("allocation_receipt") != null:
		return _failed(&"advance_request_invalid", "allocation already present")
	var next := operation.duplicate(true)
	next["allocation_receipt"] = (allocation_receipt as Dictionary).duplicate(true)
	next["stage"] = STAGE_ALLOCATED
	next["next_participant_index"] = 0
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_intent_to_abort(operation: Dictionary, failure: Variant, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int) -> Dictionary:
	if str(operation.get("stage", "")) != STAGE_INTENT:
		return _failed(&"illegal_stage", "expected intent stage")
	if failure == null:
		return _failed(&"advance_request_invalid", "pre-allocation diagnostic requires typed failure")
	if index != 0:
		return _failed(&"advance_request_invalid", "pre-allocation abort requires index 0")
	if allocation_receipt != null or participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "pre-allocation abort requires no evidence")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_ABORTED
	next["failure"] = (failure as Dictionary).duplicate(true)
	next["allocation_receipt"] = null
	var receipts: Dictionary = {}
	for name in PARTICIPANT_ORDER:
		receipts[name] = null
	next["participant_receipts"] = receipts
	next["next_participant_index"] = 0
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_allocated_to_applying(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_ALLOCATED:
		return _failed(&"illegal_stage", "expected allocation stage")
	if allocation_receipt != null:
		return _failed(&"advance_request_invalid", "allocation commit cannot include allocation receipt")
	if participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "allocation commit cannot include participant evidence")
	if index != 0:
		return _failed(&"advance_request_invalid", "expected_next_participant_index must be 0")
	if failure != null:
		return _failed(&"advance_request_invalid", "allocation transition cannot carry failure")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_APPLYING
	next["next_participant_index"] = 0
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_allocated_to_applied(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_ALLOCATED:
		return _failed(&"illegal_stage", "expected allocation stage")
	if allocation_receipt != null:
		return _failed(&"advance_request_invalid", "allocation commit cannot include allocation receipt")
	if participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "allocation commit cannot include participant evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "allocation transition cannot carry failure")
	if index != PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "allocation commit to applied requires index 8")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_APPLIED
	next["next_participant_index"] = PARTICIPANT_ORDER.size()
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_allocated_to_completed(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_ALLOCATED:
		return _failed(&"illegal_stage", "expected allocation stage")
	if allocation_receipt != null:
		return _failed(&"advance_request_invalid", "allocation transition cannot include allocation receipt")
	if participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "allocation transition cannot include participant evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "allocation transition cannot carry failure")
	if index != PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "allocation commit to completed requires index 8")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_COMPLETED
	next["next_participant_index"] = PARTICIPANT_ORDER.size()
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_apply_participant(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_APPLYING:
		return _failed(&"illegal_stage", "expected participants_applying stage")
	if index < 0 or index > PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "expected index out of range")
	if allocation_receipt != null:
		return _failed(&"advance_request_invalid", "participant transition cannot carry allocation evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "participant transition cannot carry failure")
	if index != int(operation.get("next_participant_index", 0)):
		return _failed(&"advance_request_invalid", "unexpected participant index")
	if participant_name == null or participant_receipt == null:
		return _failed(&"advance_request_invalid", "participant transition requires name and receipt")
	var expected_name := PARTICIPANT_ORDER[index]
	if str(participant_name) != expected_name:
		return _failed(&"advance_request_invalid", "participant order mismatch")
	if typeof(participant_receipt) != TYPE_DICTIONARY:
		return _failed(&"advance_request_invalid", "participant_receipt must be a dictionary")
	var receipts: Dictionary = operation.get("participant_receipts", {}).duplicate(true)
	for earlier in range(index):
		if receipts.get(PARTICIPANT_ORDER[earlier]) == null:
			return _failed(&"advance_request_invalid", "lower participant receipts must be present")
	if receipts.get(expected_name) != null:
		return _failed(&"advance_request_invalid", "current participant already recorded")
	receipts[expected_name] = (participant_receipt as Dictionary).duplicate(true)
	var next := operation.duplicate(true)
	next["participant_receipts"] = receipts
	next["next_participant_index"] = index + 1
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_to_applied(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_APPLYING:
		return _failed(&"illegal_stage", "expected participants_applying stage")
	if allocation_receipt != null or participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "stage completion may not carry evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "stage completion cannot carry failure")
	if index != PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "index must be 8 to reach participants_applied")
	var current_index := int(operation.get("next_participant_index", 0))
	# For unrecoverable frontier skips (never entered participants), allow a zero-progress jump.
	# After any partial participant application, require a complete set of receipts.
	if current_index != 0 and current_index != PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "all participants must be applied before participants_applied")
	if current_index == PARTICIPANT_ORDER.size():
		var receipts: Dictionary = operation.get("participant_receipts", {})
		for name in PARTICIPANT_ORDER:
			if receipts.get(name) == null:
				return _failed(&"advance_request_invalid", "all participants must be applied before participants_applied")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_APPLIED
	next["next_participant_index"] = PARTICIPANT_ORDER.size()
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_apply_to_completed(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_APPLYING:
		return _failed(&"illegal_stage", "expected participants_applying stage")
	if index != PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "completion index must be 8")
	if allocation_receipt != null or participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "completion may not carry evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "completion cannot carry failure")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_COMPLETED
	next["next_participant_index"] = PARTICIPANT_ORDER.size()
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_to_completed(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_APPLIED:
		return _failed(&"illegal_stage", "expected participants_applied stage")
	if allocation_receipt != null or participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "completion may not carry evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "completion may not carry failure")
	if index != PARTICIPANT_ORDER.size():
		return _failed(&"advance_request_invalid", "completion index must be 8")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_COMPLETED
	return {"ok": true, "value": _normalize_after_advance(next)}


func _apply_recovery_diagnostic(operation: Dictionary, request: Dictionary) -> Dictionary:
	var expected := str(request["expected_stage"])
	var next_stage := str(request["next_stage"])
	if expected != next_stage:
		return _failed(&"advance_request_invalid", "diagnostic must hold expected_stage")
	if expected == STAGE_INTENT:
		return _failed(&"advance_request_invalid", "diagnostic cannot replay intent")
	var request_index := int(request["expected_next_participant_index"])
	if int(operation.get("next_participant_index", 0)) != request_index:
		return _failed(&"advance_request_invalid", "diagnostic index must match next participant index")
	if request.get("allocation_receipt") != null:
		return _failed(&"advance_request_invalid", "diagnostic must not carry allocation evidence")
	if request.get("participant_name") != null or request.get("participant_receipt") != null:
		return _failed(&"advance_request_invalid", "diagnostic must not carry participant evidence")
	var failure: Variant = request["failure"]
	var valid_failure := _validate_failure(failure)
	if not valid_failure.get("ok", false):
		return valid_failure
	var next := operation.duplicate(true)
	if next.get("failure") != null and not _operation_equals(next.get("failure"), failure):
		return _failed(&"advance_request_invalid", "diagnostic failure must be byte-equal to retained diagnostic")
	if next.get("failure") == null and expected == STAGE_ALLOCATED:
		if str((failure as Dictionary).get("code", "")) != "source_unprovable":
			return _failed(&"advance_request_invalid", "diagnostic code not allowed for irreversible allocation recovery")
	next["failure"] = (failure as Dictionary).duplicate(true)
	return {"ok": true, "value": _normalize_after_advance(next)}


func _replay_for_advanced_transition(operation: Dictionary, request: Dictionary) -> Dictionary:
	var expected := str(request["expected_stage"])
	var next_stage := str(request["next_stage"])
	var transaction_id := str(request["transaction_id"])
	if str(operation.get("stage", "")) != next_stage:
		return _failed(&"advance_request_not_replayed", transaction_id)
	var request_fingerprint := str(request["request_fingerprint"])
	if request_fingerprint != str(operation.get("request_fingerprint", "")):
		return _failed(&"continuation_request_conflict", transaction_id)

	match expected:
		STAGE_INTENT:
			if next_stage != STAGE_ALLOCATED:
				return _failed(&"advance_request_invalid", "invalid replay transition")
			if int(request["expected_next_participant_index"]) != 0:
				return _failed(&"advance_request_invalid", "expected_next_participant_index must be 0 for replay")
			if request.get("allocation_receipt") == null \
					or _operation_equals(operation.get("allocation_receipt"), request.get("allocation_receipt")):
				pass
			else:
				return _failed(&"advance_request_invalid", "allocation receipt mismatch")
			if request.get("participant_name") != null or request.get("participant_receipt") != null:
				return _failed(&"advance_request_invalid", "replay carries no evidence")
			if request.get("failure", null) != null:
				return _failed(&"advance_request_invalid", "replay must not carry failure")
			return {"ok": true}

		STAGE_ALLOCATED:
			if next_stage != STAGE_APPLYING:
				if next_stage == STAGE_APPLIED:
					if int(request["expected_next_participant_index"]) != PARTICIPANT_ORDER.size():
						return _failed(&"advance_request_invalid", "replay index must be 8 for replayed allocation completion")
					if request.get("allocation_receipt") != null or request.get("participant_name") != null \
							or request.get("participant_receipt") != null or request.get("failure") != null:
						return _failed(&"advance_request_invalid", "replay must carry no evidence")
					return {"ok": true}
				if next_stage == STAGE_COMPLETED:
					if int(request["expected_next_participant_index"]) != PARTICIPANT_ORDER.size():
						return _failed(&"advance_request_invalid", "replay index must be 8 for replayed allocation completion")
					if request.get("allocation_receipt") != null or request.get("participant_name") != null \
							or request.get("participant_receipt") != null or request.get("failure") != null:
						return _failed(&"advance_request_invalid", "replay must carry no evidence")
					return {"ok": true}
				if next_stage == STAGE_ALLOCATED:
					return _replay_failure(operation, request)
				return _failed(&"advance_request_invalid", "invalid replay transition")
			if int(request["expected_next_participant_index"]) != 0:
				return _failed(&"advance_request_invalid", "replay index must be 0 for allocated entry")
			if request.get("allocation_receipt") != null or request.get("participant_name") != null \
					or request.get("participant_receipt") != null or request.get("failure") != null:
				return _failed(&"advance_request_invalid", "replay must carry no evidence")
			if operation.get("allocation_receipt") == null:
				return _failed(&"advance_request_invalid", "replay has no live allocation")
			return {"ok": true}

		STAGE_APPLYING:
			if next_stage != STAGE_APPLYING:
				if next_stage == STAGE_APPLIED:
					if int(request["expected_next_participant_index"]) != PARTICIPANT_ORDER.size():
						return _failed(&"advance_request_invalid", "participants_applying replay index must be 8")
					if request.get("allocation_receipt") != null or request.get("participant_name") != null \
							or request.get("participant_receipt") != null or request.get("failure") != null:
						return _failed(&"advance_request_invalid", "replay carries evidence")
					var receipts: Dictionary = operation.get("participant_receipts", {})
					for name in PARTICIPANT_ORDER:
						if receipts.get(name) == null:
							return _failed(&"advance_request_invalid", "participants were not fully applied")
					return {"ok": true}
				if next_stage == STAGE_APPLYING:
					return _replay_failure(operation, request)
				return _failed(&"advance_request_invalid", "invalid replay transition")
			if request.get("failure") != null:
				return _failed(&"advance_request_invalid", "replay carries no failure")
			if int(request["expected_next_participant_index"]) != int(operation.get("next_participant_index", -1)):
				return _failed(&"advance_request_invalid", "replay index must match next participant index")
			var name := str(request.get("participant_name", ""))
			var receipt: Variant = request.get("participant_receipt", null)
			var expected_name := PARTICIPANT_ORDER[int(request["expected_next_participant_index"])]
			var receipts: Dictionary = operation.get("participant_receipts", {})
			if name != expected_name:
				return _failed(&"advance_request_invalid", "replay participant name mismatch")
			if typeof(receipt) != TYPE_DICTIONARY:
				return _failed(&"advance_request_invalid", "replay requires participant_receipt")
			if receipts.get(name) != null:
				if receipts.get(name) != receipt:
					return _failed(&"advance_request_invalid", "participant receipt replay changed")
				return {"ok": true}
			return _failed(&"advance_request_invalid", "the replayed participant had not been recorded")

		STAGE_APPLIED:
			if next_stage != STAGE_COMPLETED:
				if next_stage == STAGE_APPLIED:
					return _replay_failure(operation, request)
				return _failed(&"advance_request_invalid", "invalid replay transition")
			if request.get("failure") != null:
				return _failed(&"advance_request_invalid", "replay cannot carry failure")
			if int(request["expected_next_participant_index"]) != PARTICIPANT_ORDER.size():
				return _failed(&"advance_request_invalid", "replay index must be 8")
			if request.get("allocation_receipt") != null or request.get("participant_name") != null \
					or request.get("participant_receipt") != null:
				return _failed(&"advance_request_invalid", "replay carries evidence")
			return {"ok": true}
	return _failed(&"advance_request_not_replayed", str(request["transaction_id"]))


func _replay_failure(operation: Dictionary, request: Dictionary) -> Dictionary:
	if request.get("failure") == null:
		return _failed(&"advance_request_invalid", "replay expects failure for diagnostic replay")
	var ok_failure := _validate_failure(request.get("failure"))
	if not ok_failure.get("ok", false):
		return ok_failure
	if operation.get("failure") == null:
		return _failed(&"advance_request_invalid", "diagnostic replay requires retained failure")
	if not _operation_equals(operation.get("failure"), request.get("failure")):
		return _failed(&"advance_request_invalid", "different diagnostic rejected")
	return {"ok": true}


func _normalize_after_advance(operation: Dictionary) -> Dictionary:
	return _intent_candidate_from_operation(operation)


func _intent_candidate(request: Dictionary) -> Dictionary:
	var operation := _base_operation(request)
	operation["stage"] = STAGE_INTENT
	operation["next_participant_index"] = 0
	var participant_receipts: Dictionary = {}
	for name: String in PARTICIPANT_ORDER:
		participant_receipts[name] = null
	operation["participant_receipts"] = participant_receipts
	return operation


func _intent_candidate_from_operation(operation: Dictionary) -> Dictionary:
	return {
		"allocation_candidate_fingerprint": operation.get("allocation_candidate_fingerprint"),
		"allocation_receipt": operation.get("allocation_receipt"),
		"failure": operation.get("failure"),
		"initial_context": _duplicate_or_null(operation.get("initial_context")),
		"initial_context_sha256": operation.get("initial_context_sha256"),
		"kind": operation.get("kind"),
		"next_participant_index": operation.get("next_participant_index"),
		"participant_receipts": (operation.get("participant_receipts", {}).duplicate(true)),
		"request_fingerprint": operation.get("request_fingerprint"),
		"source_locator": operation.get("source_locator"),
		"stage": operation.get("stage"),
		"transaction_id": operation.get("transaction_id"),
		"transaction_issuer_receipt": (operation.get("transaction_issuer_receipt") as Dictionary).duplicate(true),
	}


func _base_operation(request: Dictionary) -> Dictionary:
	return {
		"allocation_candidate_fingerprint": str(request.get("allocation_candidate_fingerprint", "")),
		"allocation_receipt": null,
		"failure": null,
		"initial_context": _duplicate_or_null(request.get("initial_context")),
		"initial_context_sha256": request.get("initial_context_sha256"),
		"kind": str(request["kind"]),
		"next_participant_index": 0,
		"participant_receipts": {},
		"request_fingerprint": str(request["request_fingerprint"]),
		"source_locator": request.get("source_locator"),
		"stage": STAGE_INTENT,
		"transaction_id": str(request["transaction_id"]),
		"transaction_issuer_receipt": (request["transaction_issuer_receipt"] as Dictionary).duplicate(true),
	}


func _canonical_sha256(value: Variant) -> String:
	var emitted := _CANONICAL_WRITER.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return _sha256_hex(str(emitted["value"]))


func _sha256_hex(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _operation_equals(left: Variant, right: Variant) -> bool:
	return left == right


func _duplicate_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


func _exact_keys(value: Dictionary, expected: Array[String]) -> Dictionary:
	if value.size() != expected.size():
		return _failed(&"request_member_set_invalid", "expected %d members, saw %d" % [expected.size(), value.size()])
	for key in expected:
		if not value.has(key):
			return _failed(&"request_member_set_invalid", "missing " + str(key))
	return {"ok": true}


func tx_hash_reason(operation: Dictionary) -> String:
	if typeof(operation.get("initial_context")) == TYPE_DICTIONARY or typeof(operation.get("initial_context")) == TYPE_ARRAY:
		return operation.get("transaction_id", "")
	return "new operation has non-composite context"


func _storage_failure(result: Dictionary, fallback: StringName = &"journal_storage_failed") -> Dictionary:
	var code: Variant = result.get("code", fallback)
	return _failed(StringName(str(code)), str(result.get("message", "storage refused")))


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopContinuationOperationJournal: " + message}


