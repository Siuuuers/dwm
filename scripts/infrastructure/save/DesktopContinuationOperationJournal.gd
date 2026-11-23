class_name DesktopContinuationOperationJournal
extends RefCounted

const JOURNAL_PATH := "desktop-continuation-operations.json"
const SCHEMA_VERSION := 5
const SCENE_PARTICIPANT_ORDER: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "profile",
	"localization", "audio", "route", "narrative",
]
const STAGE_COMPLETED := "completed"

const OPERATION_KEYS: Array[String] = [
	"activation_state", "allocation_candidate_fingerprint",
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

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _NEW_RUN_MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")

static func get_creation_operation(storage: Object, bundle: Dictionary, issuer: Object, transaction_id: String) -> Dictionary:
	if storage == null: return _failed(&"journal_not_configured", "storage is unavailable")
	var read: Dictionary = storage.reconcile(JOURNAL_PATH, _STRICT_JSON.parse_object)
	if not read.ok: return read
	if not read.get("exists", false): return _failed(&"continuation_transaction_not_found", transaction_id)
	var document: Dictionary = read.value
	if document.size() != 2 or typeof(document.get("schema_version")) != TYPE_INT \
			or document.schema_version != SCHEMA_VERSION or not document.get("operations") is Dictionary:
		return _failed(&"journal_schema_invalid", "invalid creation journal envelope")
	if not document.operations.has(transaction_id): return _failed(&"continuation_transaction_not_found", transaction_id)
	var value: Variant = document.operations[transaction_id]
	if not value is Dictionary or value.get("kind") != "scene_new_run" or value.get("stage") != STAGE_COMPLETED \
			or value.get("activation_state") != "acknowledged":
		return _failed(&"scene_creation_not_activated", "durable completed creation and activation required")
	var operation: Dictionary = value
	if operation.size() != OPERATION_KEYS.size() or not operation.has_all(OPERATION_KEYS) \
			or operation.transaction_id != transaction_id or operation.failure != null or operation.source_locator != null \
			or typeof(operation.next_participant_index) != TYPE_INT or operation.next_participant_index != SCENE_PARTICIPANT_ORDER.size() \
			or not operation.participant_receipts is Dictionary or operation.participant_receipts.size() != SCENE_PARTICIPANT_ORDER.size():
		return _failed(&"journal_schema_invalid", "completed creation fields are invalid")
	for participant: String in SCENE_PARTICIPANT_ORDER:
		if not operation.participant_receipts.get(participant) is Dictionary:
			return _failed(&"journal_schema_invalid", "missing participant receipt")
	if not operation.initial_context is Dictionary or not operation.allocation_candidate_fingerprint is String \
			or _canonical_sha256(operation.initial_context) != operation.initial_context_sha256:
		return _failed(&"journal_schema_invalid", "initial context differs from recorded identity")
	var materials_ok := _NEW_RUN_MATERIALS.validate(operation.new_run_materials, operation.initial_context,
		transaction_id, operation.allocation_candidate_fingerprint, bundle, issuer)
	if not materials_ok.ok: return _failed(&"journal_schema_invalid", str(materials_ok.get("message", "invalid creation materials")))
	var materials: Dictionary = operation.new_run_materials
	if not _CANONICAL_WRITER._deep_same(operation.allocation_receipt, materials.allocation_candidate) \
			or not _CANONICAL_WRITER._deep_same(operation.transaction_issuer_receipt, materials.allocation_candidate.request.transaction_issuer_receipt) \
			or operation.new_run_targets != {"identity": operation.allocation_candidate_fingerprint,
				"autosave": materials.autosave.outgoing_hash, "profile": materials.profile.outgoing_hash}:
		return _failed(&"journal_schema_invalid", "creation receipts differ from their frozen materials")
	if operation.request_fingerprint != _canonical_sha256({"kind": "scene_new_run", "transaction_id": transaction_id,
			"initial_context": operation.initial_context, "new_run_materials": materials}):
		return _failed(&"journal_schema_invalid", "creation request fingerprint differs")
	return {"ok": true, "value": operation}

static func _canonical_sha256(value: Dictionary) -> String:
	var emitted := _CANONICAL_WRITER.stringify(value)
	return str(emitted.value).sha256_text() if emitted.ok else ""

static func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopContinuationOperationJournal: " + message}
