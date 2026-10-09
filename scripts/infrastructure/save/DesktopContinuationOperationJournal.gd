class_name DesktopContinuationOperationJournal
extends RefCounted

## Durable New Run / selected Load continuation-operation journal (Plan 02 Task 1, dwm-p2r.16).
## External to every selectable snapshot: this uses its injected atomic storage and source-loader.
const JOURNAL_PATH := "desktop-continuation-operations.json"
const SCHEMA_VERSION := 4
const SCENE_SCHEMA_VERSION := 5
const SCENE_PARTICIPANT_ORDER: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "profile",
	"localization", "audio", "route", "narrative",
]
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
	"new_run_materials",
	"new_run_targets",
	"next_participant_index",
	"participant_receipts",
	"request_fingerprint",
	"source_locator",
	"stage",
	"transaction_id",
	"transaction_issuer_receipt",
]

const TRANSACTION_ISSUER_RECEIPT_KEYS: Array[String] = [
	"counter",
	"namespace",
	"numeric_value",
	"purpose",
	"receipt_id",
	"token",
]

const SOURCE_LOCATOR_KEYS: Array[String] = [
	"bundle_id",
	"checkpoint_id",
	"document_sha256",
	"slot_id",
]

const INITIAL_CONTEXT_KEYS: Array[String] = [
	"active_app_id",
	"audio_context",
	"content_version",
	"dialogic_checkpoint",
	"dark_mode",
	"route_id",
]

const PREPARE_INTENT_KEYS: Array[String] = [
	"allocation_candidate_fingerprint",
	"initial_context",
	"initial_context_sha256",
	"kind",
	"new_run_materials",
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
	"schedule_view",
	"profile",
	"localization",
	"audio",
	"route",
	"narrative",
]
const NEW_RUN_TARGET_ORDER: Array[String] = ["identity", "autosave", "profile"]

const STAGE_UNION: Array[String] = [
	STAGE_INTENT,
	STAGE_ALLOCATED,
	STAGE_APPLYING,
	STAGE_APPLIED,
	STAGE_COMPLETED,
	STAGE_ABORTED,
]

const KIND_UNION: Array[String] = ["new_run", "restore", "scene_restore"]
const DOCUMENT_KEYS: Array[String] = ["operations", "schema_version"]

const _SAVE_DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _NEW_RUN_MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")

var _storage: Object = null
var _source_loader: Object = null
var _document: Dictionary = {}
var _loaded := false
# Exact texts accepted by the strict parser or canonical writer. Atomic storage rechecks
# outgoing/current/backup bytes; retain this bounded proof window and return detached values.
# Loading still validates the full journal schema, including on a cached parse.
var _validated_text_documents: Dictionary = {}
var _validated_text_order: Array[String] = []
# One detached canonical proof per current operation; historical receipts never change on a forward step.
var _operation_text_cache: Dictionary = {}
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

	var shape := _exact_keys(request, _intent_keys(request))
	if not shape.get("ok", false):
		return shape

	var request_ok := _validate_intent_request(request)
	if not request_ok.get("ok", false):
		return request_ok

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded

	var txid := str(request["transaction_id"])
	var pending_ok := _pending_conflict(txid)
	if not pending_ok.get("ok", false): return pending_ok

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

	var shape := _exact_keys(candidate, _operation_keys(candidate))
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
	var pending_ok := _pending_conflict(txid)
	if not pending_ok.get("ok", false): return pending_ok

	var operations: Dictionary = _document.get("operations", {})
	if operations.has(txid):
		var recorded: Dictionary = operations[txid]
		if _operation_equals(recorded, candidate):
			return {"ok": true, "value": recorded.duplicate(true)}
		return _failed(&"continuation_transaction_conflict", txid)

	var next_document := _document.duplicate(true)
	next_document["operations"][txid] = candidate.duplicate(true)
	if candidate.get("kind") == "scene_restore": next_document["schema_version"] = SCENE_SCHEMA_VERSION
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
	var pending_ok := _pending_conflict(txid)
	if not pending_ok.get("ok", false): return pending_ok

	var operations: Dictionary = _document.get("operations", {})
	if not operations.has(txid):
		return _failed(&"continuation_transaction_not_found", txid)
	var operation: Dictionary = operations[txid]
	if str(request["request_fingerprint"]) != str(operation.get("request_fingerprint", "")):
		return _failed(&"continuation_request_conflict", txid)

	var request_ok := _validate_advance_request(request, operation)
	if not request_ok.get("ok", false):
		return request_ok
	if operation.get("failure") != null:
		if _is_identical_diagnostic_replay(operation, request):
			return {"ok": true, "value": operation.duplicate(true)}
		return _failed(&"advance_blocked_by_recovery_diagnostic",
			"the retained diagnostic must be proven and durably cleared before forward advancement")

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
	var written := _write(next_document, txid)
	if not written.get("ok", false):
		return written
	_document["operations"][txid] = progressed
	return {"ok": true, "value": progressed.duplicate(true)}


## Records readback proof for one frozen New Run durability target. Target order is strict and an
## identical replay is idempotent; changed proof at an occupied target is a conflict.
func record_new_run_target(transaction_id: String, request_fingerprint: String,
		target: StringName, revision: String) -> Dictionary:
	var ready := _require_configured("record_new_run_target")
	if not ready.get("ok", false):
		return ready
	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded
	var operations: Dictionary = _document.get("operations", {})
	if not operations.has(transaction_id):
		return _failed(&"continuation_transaction_not_found", transaction_id)
	var operation: Dictionary = operations[transaction_id]
	if request_fingerprint != str(operation.get("request_fingerprint", "")):
		return _failed(&"continuation_request_conflict", transaction_id)
	if operation.get("kind") != "new_run" or operation.get("stage") != STAGE_ALLOCATED:
		return _failed(&"new_run_target_stage_invalid", str(operation.get("stage", "")))
	var target_name := String(target)
	if target_name not in NEW_RUN_TARGET_ORDER or not _is_sha256(revision):
		return _failed(&"new_run_target_invalid", target_name)
	var targets: Dictionary = (operation["new_run_targets"] as Dictionary).duplicate(true)
	var index := NEW_RUN_TARGET_ORDER.find(target_name)
	var expected := _expected_new_run_target_revision(operation, target_name)
	if expected != revision:
		return _failed(&"new_run_target_proof_mismatch", target_name)
	if targets.get(target_name) != null:
		if targets[target_name] == revision:
			return {"ok": true, "value": operation.duplicate(true)}
		return _failed(&"new_run_target_proof_conflict", target_name)
	for prior_index: int in range(index):
		if targets.get(NEW_RUN_TARGET_ORDER[prior_index]) == null:
			return _failed(&"new_run_target_out_of_order", target_name)
	for later_index: int in range(index + 1, NEW_RUN_TARGET_ORDER.size()):
		if targets.get(NEW_RUN_TARGET_ORDER[later_index]) != null:
			return _failed(&"new_run_target_out_of_order", target_name)
	targets[target_name] = revision
	var next := operation.duplicate(true)
	next["new_run_targets"] = targets
	var valid := _validate_operation(next)
	if not valid.get("ok", false):
		return valid
	var next_document := _document.duplicate(true)
	next_document["operations"][transaction_id] = next
	var written := _write(next_document, transaction_id)
	if not written.get("ok", false):
		return written
	_document = next_document
	return {"ok": true, "value": next.duplicate(true)}

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
	var pending_ok := _pending_conflict()
	if not pending_ok.get("ok", false): return pending_ok
	var listed: Array[Dictionary] = []
	for operation: Dictionary in (_document.get("operations", {}).values() as Array):
		var stage := str(operation.get("stage", ""))
		if (stage == STAGE_COMPLETED and not _activation_pending(operation)) or stage == STAGE_ABORTED:
			continue
		listed.append(operation.duplicate(true))
	return {"ok": true, "value": listed}


## Uncertain completion/acknowledgement is resolved from atomic storage while the
## caller retains custody. A read failure is not evidence that the write refused.
func reload_operation_from_storage(transaction_id: String) -> Dictionary:
	_loaded = false
	return get_operation(transaction_id)


func reconcile_startup(transaction_id: String, issuer: Object) -> Dictionary:
	var ready := _require_configured("reconcile_startup")
	if not ready.get("ok", false):
		return ready

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded
	var pending_ok := _pending_conflict(transaction_id)
	if not pending_ok.get("ok", false): return pending_ok

	var operations: Dictionary = _document.get("operations", {})
	if not operations.has(transaction_id):
		return _failed(&"continuation_transaction_not_found", transaction_id)
	var operation: Dictionary = operations[transaction_id]

	var verified: Dictionary = issuer.call(
		&"verify_issued", operation.get("transaction_issuer_receipt"), &"transaction_id")
	if not verified.get("ok", false):
		return verified

	var stage := str(operation.get("stage", ""))
	if (stage == STAGE_COMPLETED and not _activation_pending(operation)) or stage == STAGE_ABORTED:
		return {"ok": true}
	if str(operation.get("kind", "")) == "new_run":
		var computed := _canonical_sha256(operation.get("initial_context"))
		if computed.is_empty():
			return _failed(&"continuation_context_hash_unhashable", _tx_hash_reason(operation))
		if str(operation.get("initial_context_sha256", "")) != str(computed):
			return _failed(&"continuation_context_hash_mismatch", str(operation.get("transaction_id", "")))
	else:
		var locator: Variant = operation.get("source_locator")
		if typeof(locator) != TYPE_DICTIONARY:
			return _failed(&"operation_source_locator_invalid", str(operation.get("transaction_id", "")))
		var loaded_source: Dictionary
		if operation.get("kind") == "scene_restore":
			if not _source_loader.has_method(&"load_restore_context"):
				return _failed(&"scene_source_loader_unbound", transaction_id)
			loaded_source = _source_loader.call(&"load_restore_context", transaction_id, locator.duplicate(true))
		else:
			loaded_source = _source_loader.call(&"load_context", locator)
		if not loaded_source.get("ok", false):
			return loaded_source
		var payload: Dictionary = loaded_source.get("value", {})
		if not payload.has("context") or not payload.has("context_sha256"):
			return _failed(&"operation_source_payload_invalid", str(operation.get("transaction_id", "")))
		if str(payload.get("context_sha256", "")) != str(locator.get("document_sha256", "")) \
				or (operation.get("kind") == "scene_restore" and _canonical_sha256(payload.get("context")) != str(locator["document_sha256"])):
			return _failed(&"continuation_source_hash_mismatch", str(operation.get("transaction_id", "")))

	if operation.get("failure", null) == null:
		return {"ok": true}
	var cleared_operation := operation.duplicate(true)
	cleared_operation["failure"] = null
	var next_document := _document.duplicate(true)
	next_document["operations"][transaction_id] = cleared_operation
	var written := _write(next_document, transaction_id)
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
		var canonical := _serialize_document(document)
		if canonical.get("ok", false) and str(canonical["value"]).sha256_text() == str(reconciled.get("hash", "")):
			_remember_validated_text(str(canonical["value"]), document)
	_document = document.duplicate(true)
	_loaded = true
	return {"ok": true}


func _write(document: Dictionary, changed_transaction: String = "") -> Dictionary:
	# Every caller uses a validated entry path: commit/target call _validate_operation, advance
	# constructs an exhaustive legal transition, and diagnostic clearing only nulls an
	# already-validated failure. _document itself was validated on load. Avoid rescanning all
	# historical completed operations on every forward step. Reuse their exact canonical bytes;
	# changed operations still pass through the canonical writer.
	var emitted := _serialize_document(document, changed_transaction)
	if not emitted.get("ok", false):
		return _failed(&"journal_serialization_failed", str(emitted.get("message", "cannot serialize journal")))
	_remember_validated_text(str(emitted["value"]), document)
	var write_result: Dictionary = _storage.call(
		&"write_atomic", JOURNAL_PATH, str(emitted["value"]), Callable(self, "_parse_known_document"), true
	)
	if not write_result.get("ok", false):
		# An atomic adapter may report failure after the destination promotion became durable.
		# Drop the process-local cache so the next operation reconciles physical bytes before retry.
		_loaded = false
		return _storage_failure(write_result)
	return {"ok": true}

## The surrounding schema is fixed and was validated on load/construction. Only internal writers
## that clone _document and replace exactly one operation may name changed_transaction; every other
## operation then reuses its detached canonical proof. Generic callers omit the hint and retain the
## type-preserving comparison (Dictionary == would equate 1 and 1.0).
func _serialize_document(document: Dictionary, changed_transaction: String = "") -> Dictionary:
	var operations: Dictionary = document["operations"]
	for transaction_id: String in _operation_text_cache.keys():
		if not operations.has(transaction_id): _operation_text_cache.erase(transaction_id)
	var keys: Array = operations.keys()
	keys.sort_custom(_CANONICAL_WRITER._utf8_less)
	var members: Array[String] = []
	for transaction_id: String in keys:
		var operation: Dictionary = operations[transaction_id]
		var cached: Dictionary = _operation_text_cache.get(transaction_id, {})
		if cached.is_empty() or transaction_id == changed_transaction \
				or (changed_transaction.is_empty() and not _CANONICAL_WRITER._deep_same(operation, cached["operation"])):
			var emitted := _serialize_operation(operation)
			if not emitted.get("ok", false): return emitted
			cached = {"operation": operation.duplicate(true), "text": str(emitted["value"])}
			_operation_text_cache[transaction_id] = cached
		var key_text: Dictionary = _CANONICAL_WRITER.stringify(transaction_id)
		if not key_text.get("ok", false): return key_text
		members.append(str(key_text["value"]) + ":" + str(cached["text"]))
	return {"ok": true, "value": '{"operations":{' + ",".join(members) + '},"schema_version":' + str(document["schema_version"]) + '}'}

func _serialize_operation(operation: Dictionary) -> Dictionary:
	return _CANONICAL_WRITER.stringify(operation)


func _parse_known_document(text: String) -> Dictionary:
	if _validated_text_documents.has(text):
		_touch_validated_text(text)
		# JsonFileStorage uses this value only as a validation witness during an atomic write.
		# The journal retains its separately validated document and reloads through _parse_document.
		return {"ok": true, "code": &"ok", "value": {}}
	return _parse_document(text)

func _parse_document(text: String) -> Dictionary:
	if _validated_text_documents.has(text):
		_touch_validated_text(text)
		return {"ok": true, "code": &"ok",
			"value": (_validated_text_documents[text] as Dictionary).duplicate(true)}
	var parsed: Dictionary = _STRICT_JSON.parse_object(text)
	if parsed.get("ok", false): _remember_validated_text(text, parsed["value"])
	return parsed


func _touch_validated_text(text: String) -> void:
	_validated_text_order.erase(text)
	_validated_text_order.append(text)


func _remember_validated_text(text: String, document: Dictionary) -> void:
	if _validated_text_documents.has(text):
		_validated_text_order.erase(text)
	_validated_text_documents[text] = document.duplicate(true)
	_validated_text_order.append(text)
	while _validated_text_order.size() > 3:
		_validated_text_documents.erase(_validated_text_order.pop_front())


func _validate_document(document: Variant) -> Dictionary:
	if typeof(document) != TYPE_DICTIONARY:
		return _failed(_schema_error, "document is not a dictionary")
	var document_keys: Array = document.keys()
	document_keys.sort()
	if document_keys != DOCUMENT_KEYS:
		return _failed(_schema_error, "document has unexpected members: " + str(document_keys))
	if typeof(document.get("schema_version")) != TYPE_INT \
			or document.get("schema_version") not in [SCHEMA_VERSION, SCENE_SCHEMA_VERSION]:
		return _failed(_schema_error, "invalid schema_version")
	if typeof(document.get("operations", {})) != TYPE_DICTIONARY:
		return _failed(_schema_error, "operations is not a dictionary")
	var pending_count := 0
	for key: String in document["operations"]:
		if key.is_empty():
			return _failed(_schema_error, "transaction_id must be non-empty")
		var operation_value: Variant = document["operations"][key]
		if typeof(operation_value) != TYPE_DICTIONARY:
			return _failed(_schema_error, "operation must be a dictionary for key " + str(key))
		var operation: Dictionary = operation_value
		if typeof(operation.get("transaction_id")) != TYPE_STRING:
			return _failed(_schema_error, "transaction_id must be a string for key " + str(key))
		if str(operation.get("transaction_id")) != key:
			return _failed(_schema_error, "transaction_id must match operations key")
		if document["schema_version"] == SCHEMA_VERSION and operation.get("kind") == "scene_restore":
			return _failed(_schema_error, "scene operation requires journal5")
		var validated := _validate_operation(operation)
		if not validated.get("ok", false):
			return validated
		if _activation_pending(operation): pending_count += 1
	if pending_count > 1:
		return _failed(&"scene_activation_conflict", "multiple pending scene activations")
	return {"ok": true}


func _validate_operation(operation: Dictionary) -> Dictionary:
	var keys: Array = operation.keys()
	keys.sort()
	var expected := _operation_keys(operation)
	expected.sort()
	if keys != expected:
		return _failed(_schema_error, "operation has unexpected members: " + str(keys))
	if typeof(operation.get("transaction_id")) != TYPE_STRING \
			or str(operation.get("transaction_id", "")).strip_edges().is_empty():
		return _failed(_schema_error, "transaction_id must be a nonblank string")
	var transaction_id := str(operation["transaction_id"])
	var issuer_receipt_ok := _validate_transaction_issuer_receipt(
		operation.get("transaction_issuer_receipt"), transaction_id)
	if not issuer_receipt_ok.get("ok", false):
		return issuer_receipt_ok
	if typeof(operation.get("kind")) != TYPE_STRING:
		return _failed(_schema_error, "kind must be a string")
	var kind := str(operation["kind"])
	if not KIND_UNION.has(kind):
		return _failed(_schema_error, "invalid kind: " + kind)
	for fingerprint_name: String in ["request_fingerprint", "allocation_candidate_fingerprint"]:
		if not _is_sha256(operation.get(fingerprint_name)):
			return _failed(_schema_error, "%s must be lowercase SHA-256" % fingerprint_name)
	var kind_fields_ok := _validate_kind_fields(operation, kind)
	if not kind_fields_ok.get("ok", false):
		return kind_fields_ok
	if typeof(operation.get("stage")) != TYPE_STRING:
		return _failed(_schema_error, "stage must be a string")
	var stage := str(operation["stage"])
	if operation.get("kind") == "scene_restore":
		var activation: Variant = operation.get("activation_state")
		if stage == STAGE_COMPLETED:
			if typeof(activation) != TYPE_STRING or activation not in ["pending", "acknowledged"]:
				return _failed(_schema_error, "completed scene activation state is invalid")
		elif activation != null:
			return _failed(_schema_error, "uncompleted scene cannot activate")
	if not STAGE_UNION.has(stage):
		return _failed(_schema_error, "invalid stage: " + stage)
	var allocation_receipt: Variant = operation.get("allocation_receipt")
	if allocation_receipt != null and typeof(allocation_receipt) != TYPE_DICTIONARY:
		return _failed(_schema_error, "allocation_receipt must be null or a dictionary")
	var next_index: Variant = operation.get("next_participant_index", -1)
	if typeof(next_index) != TYPE_INT:
		return _failed(_schema_error, "next_participant_index must be an integer")
	var index := int(next_index)
	if index < 0 or index > _participant_order(operation).size():
		return _failed(_schema_error, "invalid participant index: " + str(index))
	var receipts_value: Variant = operation.get("participant_receipts", {})
	if typeof(receipts_value) != TYPE_DICTIONARY:
		return _failed(_schema_error, "participant_receipts must be a dictionary")
	var receipts: Dictionary = receipts_value
	var receipt_keys: Array = receipts.keys()
	receipt_keys.sort()
	var ordered := _participant_order(operation)
	ordered.sort()
	if receipt_keys != ordered:
		return _failed(_schema_error, "invalid participant_receipts members")
	for name in _participant_order(operation):
		var receipt: Variant = receipts.get(name)
		if receipt != null and typeof(receipt) != TYPE_DICTIONARY:
			return _failed(_schema_error, "participant receipt must be null or a dictionary")
	var failure: Variant = operation.get("failure")
	if failure != null:
		var failure_ok := _validate_failure(failure)
		if not failure_ok.get("ok", false):
			return _failed(_schema_error, str(failure_ok.get("message", "failure is malformed")))
	return _validate_stage_relationship(operation, stage, index, receipts)


func _validate_transaction_issuer_receipt(value: Variant, transaction_id: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failed(_schema_error, "transaction_issuer_receipt must be a dictionary")
	var receipt: Dictionary = value
	var shape := _exact_keys(receipt, TRANSACTION_ISSUER_RECEIPT_KEYS)
	if not shape.get("ok", false):
		return _failed(_schema_error, "transaction_issuer_receipt has unexpected members")
	for member: String in ["namespace", "purpose", "receipt_id", "token"]:
		if typeof(receipt.get(member)) != TYPE_STRING:
			return _failed(_schema_error, "transaction_issuer_receipt.%s must be a string" % member)
	if not _is_sha256(receipt.get("namespace")) \
			or not _is_prefixed_sha256(receipt.get("receipt_id"), "issuer_receipt."):
		return _failed(_schema_error, "transaction issuer namespace and receipt_id are malformed")
	if typeof(receipt.get("counter")) != TYPE_INT or int(receipt["counter"]) < 0:
		return _failed(_schema_error, "transaction issuer counter must be a nonnegative integer")
	if str(receipt["purpose"]) != "transaction_id":
		return _failed(_schema_error, "transaction issuer purpose must be transaction_id")
	if not _is_prefixed_sha256(receipt.get("token"), "transaction_id."):
		return _failed(_schema_error, "transaction issuer token is malformed")
	if str(receipt["token"]) != transaction_id:
		return _failed(_schema_error, "transaction issuer token must equal transaction_id")
	if receipt.get("numeric_value") != null:
		return _failed(_schema_error, "transaction issuer numeric_value must be null")
	return {"ok": true}


func _validate_kind_fields(operation: Dictionary, kind: String) -> Dictionary:
	if kind in ["restore", "scene_restore"]:
		if operation.get("initial_context") != null or operation.get("initial_context_sha256") != null:
			return _failed(_schema_error, "restore requires null initial context fields")
		if operation.get("new_run_materials") != null:
			return _failed(_schema_error, "restore requires null new_run_materials")
		if operation.has("new_run_targets") and operation.get("new_run_targets") != null:
			return _failed(_schema_error, "restore requires null new_run_targets")
		var locator_ok := _validate_source_locator(operation.get("source_locator"))
		if not locator_ok.get("ok", false): return locator_ok
		if kind == "scene_restore": return _validate_scene_source(operation)
		return {"ok": true}
	if operation.get("source_locator") != null:
		return _failed(_schema_error, "new_run requires null source_locator")
	var context_value: Variant = operation.get("initial_context")
	if typeof(context_value) != TYPE_DICTIONARY:
		return _failed(_schema_error, "new_run initial_context must be a dictionary")
	var context: Dictionary = context_value
	var context_shape := _exact_keys(context, INITIAL_CONTEXT_KEYS)
	if not context_shape.get("ok", false):
		return _failed(_schema_error, "new_run initial_context has unexpected members")
	if typeof(context.get("route_id")) != TYPE_STRING or str(context["route_id"]) != "main":
		return _failed(_schema_error, "new_run route_id must be main")
	if typeof(context.get("dark_mode")) != TYPE_BOOL:
		return _failed(_schema_error, "new_run captured dark_mode must be Boolean")
	if context.get("active_app_id") != null:
		return _failed(_schema_error, "new_run active_app_id must be null")
	if typeof(context.get("dialogic_checkpoint")) != TYPE_DICTIONARY \
			or typeof(context.get("audio_context")) != TYPE_DICTIONARY:
		return _failed(_schema_error, "new_run context payloads must be dictionaries")
	if not (context["dialogic_checkpoint"] as Dictionary).is_empty() \
			or not (context["audio_context"] as Dictionary).is_empty():
		return _failed(_schema_error,
			"new_run dialogic_checkpoint and audio_context must both equal {}")
	if typeof(context.get("content_version")) != TYPE_INT or int(context["content_version"]) < 1:
		return _failed(_schema_error, "new_run content_version must be an integer >= 1")
	if not _is_sha256(operation.get("initial_context_sha256")):
		return _failed(_schema_error, "new_run initial_context_sha256 must be lowercase SHA-256")
	var computed := _canonical_sha256(context)
	if computed.is_empty() or computed != str(operation["initial_context_sha256"]):
		return _failed(_schema_error, "new_run initial context hash does not match its bytes")
	var materials_ok: Dictionary = _NEW_RUN_MATERIALS.validate(operation.get("new_run_materials"),
		context, str(operation.get("transaction_id", "")),
		str(operation.get("allocation_candidate_fingerprint", "")))
	if not materials_ok.get("ok", false):
		return _failed(_schema_error, str(materials_ok.get("message", "new_run_materials are invalid")))
	var allocation: Dictionary = operation["new_run_materials"]["allocation_candidate"]
	if (allocation["request"] as Dictionary).get("transaction_issuer_receipt") \
			!= operation.get("transaction_issuer_receipt"):
		return _failed(_schema_error, "new_run allocation uses another transaction receipt")
	var expected_request_fingerprint := _canonical_sha256({
		"kind": "new_run", "transaction_id": operation["transaction_id"],
		"initial_context": context, "new_run_materials": operation["new_run_materials"],
	})
	if expected_request_fingerprint.is_empty() \
			or expected_request_fingerprint != str(operation.get("request_fingerprint", "")):
		return _failed(_schema_error, "new_run request fingerprint does not bind retained materials")
	if operation.has("new_run_targets"):
		return _validate_new_run_targets(operation["new_run_targets"], operation)
	return {"ok": true}


func _validate_new_run_targets(value: Variant, operation: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_target_keys(value):
		return _failed(_schema_error, "new_run_targets have unexpected members")
	var targets: Dictionary = value
	var missing_seen := false
	for target_name: String in NEW_RUN_TARGET_ORDER:
		var proof: Variant = targets[target_name]
		if proof == null:
			missing_seen = true
			continue
		if missing_seen or not _is_sha256(proof):
			return _failed(_schema_error, "new_run target proofs must be an ordered hash prefix")
		if str(proof) != _expected_new_run_target_revision(operation, target_name):
			return _failed(_schema_error, "new_run target proof does not match frozen material")
	return {"ok": true}


func _expected_new_run_target_revision(operation: Dictionary, target_name: String) -> String:
	var materials: Dictionary = operation.get("new_run_materials", {})
	match target_name:
		"identity":
			return str(operation.get("allocation_candidate_fingerprint", ""))
		"autosave":
			return str((materials.get("autosave", {}) as Dictionary).get("outgoing_hash", ""))
		"profile":
			return str((materials.get("profile", {}) as Dictionary).get("outgoing_hash", ""))
	return ""


func _all_new_run_targets_proven(operation: Dictionary) -> bool:
	if operation.get("kind") != "new_run":
		return true
	var targets: Variant = operation.get("new_run_targets")
	if typeof(targets) != TYPE_DICTIONARY or not _exact_target_keys(targets):
		return false
	for target_name: String in NEW_RUN_TARGET_ORDER:
		if str((targets as Dictionary).get(target_name, "")) \
				!= _expected_new_run_target_revision(operation, target_name):
			return false
	return true


func _exact_target_keys(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).size() != NEW_RUN_TARGET_ORDER.size():
		return false
	for target_name: String in NEW_RUN_TARGET_ORDER:
		if not (value as Dictionary).has(target_name):
			return false
	return true

func _validate_source_locator(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failed(_schema_error, "restore source_locator must be a dictionary")
	var locator: Dictionary = value
	var shape := _exact_keys(locator, SOURCE_LOCATOR_KEYS)
	if not shape.get("ok", false):
		return _failed(_schema_error, "restore source_locator has unexpected members")
	for member: String in SOURCE_LOCATOR_KEYS:
		if typeof(locator.get(member)) != TYPE_STRING:
			return _failed(_schema_error, "restore source_locator.%s must be a string" % member)
	var slot_id := str(locator["slot_id"])
	var valid_slot := slot_id in ["quick", "autosave"]
	if not valid_slot and slot_id.begins_with("slot:"):
		var suffix := slot_id.trim_prefix("slot:")
		valid_slot = suffix in ["1", "2", "3", "4", "5", "6", "7"]
	if not valid_slot:
		return _failed(_schema_error, "restore slot_id is outside the closed union")
	if str(locator["checkpoint_id"]).strip_edges().is_empty():
		return _failed(_schema_error, "restore checkpoint_id must be nonblank")
	if not _is_sha256(locator["bundle_id"]) or not _is_sha256(locator["document_sha256"]):
		return _failed(_schema_error, "restore locator hashes must be lowercase SHA-256")
	return {"ok": true}


func _validate_stage_relationship(operation: Dictionary, stage: String, index: int,
		receipts: Dictionary) -> Dictionary:
	var allocation_present := operation.get("allocation_receipt") != null
	var failure_present := operation.get("failure") != null
	var targets_empty: bool = operation.get("kind") != "new_run" or _new_run_target_count(operation) == 0
	var targets_complete: bool = _all_new_run_targets_proven(operation)
	match stage:
		STAGE_INTENT:
			if allocation_present or (failure_present and operation.get("kind") != "new_run") \
					or index != 0 or not targets_empty or not _receipts_match_index(operation, receipts, 0):
				return _failed(_schema_error, "intent_committed fields do not match their stage")
		STAGE_ALLOCATED:
			if not allocation_present or index != 0 or not _receipts_match_index(operation, receipts, 0):
				return _failed(_schema_error, "identity_allocation_committed fields do not match their stage")
		STAGE_APPLYING:
			if not allocation_present or not targets_complete \
					or not _receipts_match_index(operation, receipts, index):
				return _failed(_schema_error, "participants_applying fields do not match their stage")
		STAGE_APPLIED:
			if not allocation_present or not targets_complete or index != _participant_order(operation).size() \
					or not _receipts_match_index(operation, receipts, _participant_order(operation).size()):
				return _failed(_schema_error, "participants_applied fields do not match their stage")
		STAGE_COMPLETED:
			if not allocation_present or (failure_present and not _activation_pending(operation)) or not targets_complete \
					or index != _participant_order(operation).size() \
					or not _receipts_match_index(operation, receipts, _participant_order(operation).size()):
				return _failed(_schema_error, "completed fields do not match their stage")
		STAGE_ABORTED:
			if operation.get("kind") == "new_run" or allocation_present or not failure_present \
					or index != 0 or not targets_empty or not _receipts_match_index(operation, receipts, 0):
				return _failed(_schema_error, "aborted fields do not match their stage")
	return {"ok": true}


func _new_run_target_count(operation: Dictionary) -> int:
	if operation.get("kind") != "new_run" or typeof(operation.get("new_run_targets")) != TYPE_DICTIONARY:
		return 0
	var count := 0
	for target_name: String in NEW_RUN_TARGET_ORDER:
		if (operation["new_run_targets"] as Dictionary).get(target_name) != null:
			count += 1
	return count

func _receipts_match_index(operation: Dictionary, receipts: Dictionary, index: int) -> bool:
	for participant_index: int in range(_participant_order(operation).size()):
		var present := receipts.get(_participant_order(operation)[participant_index]) != null
		if present != (participant_index < index):
			return false
	return true


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
	var kind_fields_ok := _validate_kind_fields(request, kind)
	if not kind_fields_ok.get("ok", false):
		return kind_fields_ok
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
	if index < 0 or index > _participant_order(operation).size():
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


func _validate_failure(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _failed(&"invalid_failure", "failure must be a dictionary")
	var failure: Dictionary = value
	var keys: Array = failure.keys()
	keys.sort()
	var expected := ["code", "details", "message"]
	expected.sort()
	if keys != expected:
		return _failed(&"invalid_failure", "failure keys must be {code, message, details}")
	if typeof(failure["code"]) != TYPE_STRING:
		return _failed(&"invalid_failure", "failure.code must be a string")
	if str(failure["code"]).strip_edges().is_empty():
		return _failed(&"invalid_failure", "failure.code must be non-empty")
	if typeof(failure["message"]) != TYPE_STRING:
		return _failed(&"invalid_failure", "failure.message must be a string")
	if str(failure["message"]).strip_edges().is_empty():
		return _failed(&"invalid_failure", "failure.message must be non-empty")
	if typeof(failure["details"]) != TYPE_DICTIONARY:
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

	if failure != null and (expected in [STAGE_ALLOCATED, STAGE_APPLYING, STAGE_APPLIED] \
			or (expected == STAGE_COMPLETED and _activation_pending(operation)) \
			or (expected == STAGE_INTENT and operation.get("kind") == "new_run")) \
			and next_stage == expected and \
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
			return _failed(&"advance_request_invalid", "invalid allocation transition")

		STAGE_APPLYING:
			if next_stage == STAGE_APPLYING:
				return _advance_apply_participant(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
			if next_stage == STAGE_APPLIED:
				return _advance_to_applied(operation, request_alloc_receipt, request_name, request_receipt, index, failure, operation_stage)
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
	if operation.get("kind") == "new_run":
		var frozen_candidate: Dictionary = operation["new_run_materials"]["allocation_candidate"]
		if allocation_receipt != frozen_candidate \
				or _canonical_sha256(allocation_receipt) != str(operation["allocation_candidate_fingerprint"]):
			return _failed(&"advance_request_invalid", "allocation receipt changed from frozen New Run identity")
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
	if operation.get("kind") == "new_run":
		return _failed(&"advance_request_invalid", "a durable New Run decision cannot abort")
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
	for name in _participant_order(operation):
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
	if not _all_new_run_targets_proven(operation):
		return _failed(&"new_run_targets_unproven", "all New Run durability targets require readback proof")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_APPLYING
	next["next_participant_index"] = 0
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_apply_participant(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_APPLYING:
		return _failed(&"illegal_stage", "expected participants_applying stage")
	if index < 0 or index >= _participant_order(operation).size():
		return _failed(&"advance_request_invalid", "expected index out of range")
	if allocation_receipt != null:
		return _failed(&"advance_request_invalid", "participant transition cannot carry allocation evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "participant transition cannot carry failure")
	if index != int(operation.get("next_participant_index", 0)):
		return _failed(&"advance_request_invalid", "unexpected participant index")
	if participant_name == null or participant_receipt == null:
		return _failed(&"advance_request_invalid", "participant transition requires name and receipt")
	var expected_name := _participant_order(operation)[index]
	if str(participant_name) != expected_name:
		return _failed(&"advance_request_invalid", "participant order mismatch")
	if typeof(participant_receipt) != TYPE_DICTIONARY:
		return _failed(&"advance_request_invalid", "participant_receipt must be a dictionary")
	var receipts: Dictionary = operation.get("participant_receipts", {}).duplicate(true)
	for earlier in range(index):
		if receipts.get(_participant_order(operation)[earlier]) == null:
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
	if index != _participant_order(operation).size():
		return _failed(&"advance_request_invalid", "index must equal participant count to reach participants_applied")
	var current_index := int(operation.get("next_participant_index", 0))
	if current_index != _participant_order(operation).size():
		return _failed(&"advance_request_invalid", "all participants must be applied before participants_applied")
	var receipts: Dictionary = operation.get("participant_receipts", {})
	for name in _participant_order(operation):
		if receipts.get(name) == null:
			return _failed(&"advance_request_invalid", "all participants must be applied before participants_applied")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_APPLIED
	next["next_participant_index"] = _participant_order(operation).size()
	next["failure"] = null
	return {"ok": true, "value": _normalize_after_advance(next)}


func _advance_to_completed(operation: Dictionary, allocation_receipt: Variant, participant_name: Variant,
		participant_receipt: Variant, index: int, failure: Variant, operation_stage: String) -> Dictionary:
	if operation_stage != STAGE_APPLIED:
		return _failed(&"illegal_stage", "expected participants_applied stage")
	if allocation_receipt != null or participant_name != null or participant_receipt != null:
		return _failed(&"advance_request_invalid", "completion may not carry evidence")
	if failure != null:
		return _failed(&"advance_request_invalid", "completion may not carry failure")
	if index != _participant_order(operation).size():
		return _failed(&"advance_request_invalid", "completion index must equal participant count")
	var next := operation.duplicate(true)
	next["stage"] = STAGE_COMPLETED
	if operation.get("kind") == "scene_restore": next["activation_state"] = "pending"
	return {"ok": true, "value": _normalize_after_advance(next)}


func _apply_recovery_diagnostic(operation: Dictionary, request: Dictionary) -> Dictionary:
	var expected := str(request["expected_stage"])
	var next_stage := str(request["next_stage"])
	if expected not in [STAGE_ALLOCATED, STAGE_APPLYING, STAGE_APPLIED] \
			and not (expected == STAGE_COMPLETED and _activation_pending(operation)) \
			and not (expected == STAGE_INTENT and operation.get("kind") == "new_run"):
		return _failed(&"advance_request_invalid", "diagnostic requires a recoverable nonterminal stage")
	if expected != next_stage:
		return _failed(&"advance_request_invalid", "diagnostic must hold expected_stage")
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
					if int(request["expected_next_participant_index"]) != _participant_order(operation).size():
						return _failed(&"advance_request_invalid", "participants_applying replay index must equal participant count")
					if request.get("allocation_receipt") != null or request.get("participant_name") != null \
							or request.get("participant_receipt") != null or request.get("failure") != null:
						return _failed(&"advance_request_invalid", "replay carries evidence")
					var receipts: Dictionary = operation.get("participant_receipts", {})
					for name in _participant_order(operation):
						if receipts.get(name) == null:
							return _failed(&"advance_request_invalid", "participants were not fully applied")
					return {"ok": true}
				return _failed(&"advance_request_invalid", "invalid replay transition")
			if request.get("failure") != null:
				return _failed(&"advance_request_invalid", "replay carries no failure")
			if request.get("allocation_receipt") != null:
				return _failed(&"advance_request_invalid", "participant replay carries no allocation receipt")
			var replay_index := int(request["expected_next_participant_index"])
			if replay_index < 0 or replay_index >= _participant_order(operation).size():
				return _failed(&"advance_request_invalid", "participant replay index is out of range")
			var name := str(request.get("participant_name", ""))
			var receipt: Variant = request.get("participant_receipt", null)
			var expected_name := _participant_order(operation)[replay_index]
			var receipts: Dictionary = operation.get("participant_receipts", {})
			if name != expected_name:
				return _failed(&"advance_request_invalid", "replay participant name mismatch")
			if typeof(receipt) != TYPE_DICTIONARY:
				return _failed(&"advance_request_invalid", "replay requires participant_receipt")
			if replay_index >= int(operation.get("next_participant_index", -1)) \
					or receipts.get(name) == null:
				return _failed(&"advance_request_invalid", "the replayed participant had not been recorded")
			if receipts.get(name) != receipt or (operation.get("kind") == "scene_restore" \
					and not _CANONICAL_WRITER._deep_same(receipts.get(name), receipt)):
				return _failed(&"advance_request_invalid", "participant receipt replay changed")
			return {"ok": true}

		STAGE_APPLIED:
			if next_stage != STAGE_COMPLETED:
				if next_stage == STAGE_APPLIED:
					return _replay_failure(operation, request)
				return _failed(&"advance_request_invalid", "invalid replay transition")
			if request.get("failure") != null:
				return _failed(&"advance_request_invalid", "replay cannot carry failure")
			if int(request["expected_next_participant_index"]) != _participant_order(operation).size():
				return _failed(&"advance_request_invalid", "replay index must equal participant count")
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


func _is_identical_diagnostic_replay(operation: Dictionary, request: Dictionary) -> bool:
	var stage := str(operation.get("stage", ""))
	if (stage == STAGE_COMPLETED and not _activation_pending(operation)) or stage == STAGE_ABORTED:
		return false
	return str(request.get("expected_stage", "")) == stage \
		and str(request.get("next_stage", "")) == stage \
		and int(request.get("expected_next_participant_index", -1)) \
			== int(operation.get("next_participant_index", -2)) \
		and request.get("allocation_receipt") == null \
		and request.get("participant_name") == null \
		and request.get("participant_receipt") == null \
		and request.get("failure") == operation.get("failure")


func _normalize_after_advance(operation: Dictionary) -> Dictionary:
	return _intent_candidate_from_operation(operation)


func _intent_candidate(request: Dictionary) -> Dictionary:
	var operation := _base_operation(request)
	operation["stage"] = STAGE_INTENT
	operation["next_participant_index"] = 0
	var participant_receipts: Dictionary = {}
	for name: String in _participant_order(operation):
		participant_receipts[name] = null
	operation["participant_receipts"] = participant_receipts
	return operation


func _intent_candidate_from_operation(operation: Dictionary) -> Dictionary:
	var candidate := {
		"allocation_candidate_fingerprint": operation.get("allocation_candidate_fingerprint"),
		"allocation_receipt": operation.get("allocation_receipt"),
		"failure": operation.get("failure"),
		"initial_context": _duplicate_or_null(operation.get("initial_context")),
		"initial_context_sha256": operation.get("initial_context_sha256"),
		"kind": operation.get("kind"),
		"new_run_materials": _duplicate_or_null(operation.get("new_run_materials")),
		"new_run_targets": _duplicate_or_null(operation.get("new_run_targets")),
		"next_participant_index": operation.get("next_participant_index"),
		"participant_receipts": (operation.get("participant_receipts", {}).duplicate(true)),
		"request_fingerprint": operation.get("request_fingerprint"),
		"source_locator": operation.get("source_locator"),
		"stage": operation.get("stage"),
		"transaction_id": operation.get("transaction_id"),
		"transaction_issuer_receipt": (operation.get("transaction_issuer_receipt") as Dictionary).duplicate(true),
	}


	if operation.get("kind") == "scene_restore":
		candidate["selected_document"] = (operation["selected_document"] as Dictionary).duplicate(true)
		candidate["source_locator"] = (operation["source_locator"] as Dictionary).duplicate(true)
		candidate["activation_state"] = operation.get("activation_state")
	return candidate

func _base_operation(request: Dictionary) -> Dictionary:
	var candidate := {
		"allocation_candidate_fingerprint": str(request.get("allocation_candidate_fingerprint", "")),
		"allocation_receipt": null,
		"failure": null,
		"initial_context": _duplicate_or_null(request.get("initial_context")),
		"initial_context_sha256": request.get("initial_context_sha256"),
		"kind": str(request["kind"]),
		"new_run_materials": _duplicate_or_null(request.get("new_run_materials")),
		"new_run_targets": {"identity": null, "autosave": null, "profile": null} \
			if str(request["kind"]) == "new_run" else null,
		"next_participant_index": 0,
		"participant_receipts": {},
		"request_fingerprint": str(request["request_fingerprint"]),
		"source_locator": request.get("source_locator"),
		"stage": STAGE_INTENT,
		"transaction_id": str(request["transaction_id"]),
		"transaction_issuer_receipt": (request["transaction_issuer_receipt"] as Dictionary).duplicate(true),
	}


	if request.get("kind") == "scene_restore":
		candidate["selected_document"] = (request["selected_document"] as Dictionary).duplicate(true)
		candidate["source_locator"] = (request["source_locator"] as Dictionary).duplicate(true)
		candidate["activation_state"] = null
	return candidate

func _canonical_sha256(value: Variant) -> String:
	var emitted := _CANONICAL_WRITER.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return _sha256_hex(str(emitted["value"]))


func _is_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != 64:
		return false
	for codepoint: int in (value as String).to_ascii_buffer():
		if not (codepoint >= 0x30 and codepoint <= 0x39) \
				and not (codepoint >= 0x61 and codepoint <= 0x66):
			return false
	return true


func _is_prefixed_sha256(value: Variant, prefix: String) -> bool:
	return typeof(value) == TYPE_STRING and str(value).begins_with(prefix) \
		and _is_sha256(str(value).trim_prefix(prefix))


func _sha256_hex(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _operation_equals(left: Variant, right: Variant) -> bool:
	if (typeof(left) == TYPE_DICTIONARY and left.get("kind") == "scene_restore") \
			or (typeof(right) == TYPE_DICTIONARY and right.get("kind") == "scene_restore"):
		return _CANONICAL_WRITER._deep_same(left, right)
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


func _tx_hash_reason(operation: Dictionary) -> String:
	if typeof(operation.get("initial_context")) == TYPE_DICTIONARY or typeof(operation.get("initial_context")) == TYPE_ARRAY:
		return operation.get("transaction_id", "")
	return "new operation has non-composite context"


func _storage_failure(result: Dictionary, fallback: StringName = &"journal_storage_failed") -> Dictionary:
	var code: Variant = result.get("code", fallback)
	return _failed(StringName(str(code)), str(result.get("message", "storage refused")))


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopContinuationOperationJournal: " + message}

## Scene activation is acknowledged only by SaveManager after physical readiness.
## This durable marker is not a live-session capability and never authorizes Start alone.
func acknowledge_scene_activation(transaction_id: String, request_fingerprint: String) -> Dictionary:
	var ready := _require_configured("acknowledge_scene_activation")
	if not ready.get("ok", false): return ready
	var loaded := _load()
	if not loaded.get("ok", false): return loaded
	var pending_ok := _pending_conflict(transaction_id)
	if not pending_ok.get("ok", false): return pending_ok
	var operations: Dictionary = _document["operations"]
	if not operations.has(transaction_id):
		return _failed(&"continuation_transaction_not_found", transaction_id)
	var operation: Dictionary = operations[transaction_id]
	if operation.get("request_fingerprint") != request_fingerprint:
		return _failed(&"continuation_request_conflict", transaction_id)
	if operation.get("kind") != "scene_restore" or operation.get("stage") != STAGE_COMPLETED:
		return _failed(&"scene_activation_stage_invalid", transaction_id)
	if operation.get("failure") != null:
		return _failed(&"advance_blocked_by_recovery_diagnostic", transaction_id)
	if operation.get("activation_state") == "acknowledged":
		return {"ok": true, "value": operation.duplicate(true)}
	var next := operation.duplicate(true)
	next["activation_state"] = "acknowledged"
	var document := _document.duplicate(true)
	document["operations"][transaction_id] = next
	var written := _write(document, transaction_id)
	if not written.get("ok", false): return written
	_document = document
	return {"ok": true, "value": next.duplicate(true)}


func _activation_pending(operation: Dictionary) -> bool:
	return operation.get("kind") == "scene_restore" \
		and operation.get("stage") == STAGE_COMPLETED \
		and operation.get("activation_state") == "pending"


func _pending_conflict(transaction_id: String = "") -> Dictionary:
	var pending: Array[String] = []
	for operation: Dictionary in _document.get("operations", {}).values():
		if _activation_pending(operation): pending.append(str(operation["transaction_id"]))
	if pending.size() > 1:
		return _failed(&"scene_activation_conflict", "multiple pending scene activations")
	if pending.size() == 1 and not transaction_id.is_empty() and pending[0] != transaction_id:
		return _failed(&"scene_activation_pending", pending[0])
	return {"ok": true}


func _participant_order(operation: Dictionary) -> Array[String]:
	return SCENE_PARTICIPANT_ORDER.duplicate() if operation.get("kind") == "scene_restore" else PARTICIPANT_ORDER.duplicate()


func _operation_keys(operation: Dictionary) -> Array[String]:
	var keys := OPERATION_KEYS.duplicate()
	if operation.get("kind") == "scene_restore":
		keys.append_array(["selected_document", "activation_state"])
	return keys


func _intent_keys(request: Dictionary) -> Array[String]:
	var keys := PREPARE_INTENT_KEYS.duplicate()
	if request.get("kind") == "scene_restore": keys.append("selected_document")
	return keys


func _validate_scene_source(operation: Dictionary) -> Dictionary:
	var document: Variant = operation.get("selected_document")
	if typeof(document) != TYPE_DICTIONARY or typeof(document.get("schema_version")) != TYPE_INT \
			or document.get("schema_version") != 9:
		return _failed(_schema_error, "scene restore requires actual Save9 selected_document")
	var admitted: Dictionary = _SAVE_DOCUMENT.validate(document)
	if not admitted.get("ok", false): return admitted
	if not _CANONICAL_WRITER._deep_same(document, admitted["value"]["candidate"]):
		return _failed(_schema_error, "selected_document must already be the exact validated Save9 value")
	var locator: Dictionary = operation["source_locator"]
	var slot := str(document["kind"])
	if slot == "slot": slot = "slot:" + str(document["slot_id"])
	if slot != locator["slot_id"]:
		return _failed(_schema_error, "selected document slot differs from locator")
	var matches := 0
	var bundles: Array = [document["current_snapshot"]]
	bundles.append_array(document["recovery_journal"])
	for raw_bundle: Variant in bundles:
		if typeof(raw_bundle) != TYPE_DICTIONARY:
			return _failed(_schema_error, "retained recovery bundle is malformed")
		var bundle: Dictionary = raw_bundle
		if typeof(bundle.get("snapshot")) != TYPE_DICTIONARY:
			return _failed(_schema_error, "retained recovery bundle is malformed")
		var snapshot: Dictionary = bundle["snapshot"]
		if snapshot.get("checkpoint_id") != locator["checkpoint_id"]: continue
		var selected_ok: Dictionary = _SAVE_DOCUMENT._validate_bundle(bundle)
		if not selected_ok.get("ok", false): return selected_ok
		if not _CANONICAL_WRITER._deep_same(snapshot, selected_ok["value"]["candidate"]):
			return _failed(_schema_error, "selected snapshot must already be validated")
		# A repeated checkpoint identity is ambiguous even when only one hash matches.
		matches += 1
		if _canonical_sha256(bundle) != locator["bundle_id"] \
				or _canonical_sha256(snapshot) != locator["document_sha256"]:
			return _failed(_schema_error, "selected checkpoint identity or content conflicts")
	if matches != 1:
		return _failed(_schema_error, "selected checkpoint must be unique")
	var fingerprint := _canonical_sha256({
		"kind": "scene_restore", "transaction_id": operation["transaction_id"],
		"source_locator": locator, "selected_document": document,
	})
	if fingerprint.is_empty() or fingerprint != operation["request_fingerprint"]:
		return _failed(_schema_error, "scene request fingerprint must bind complete selected document")
	return {"ok": true}

