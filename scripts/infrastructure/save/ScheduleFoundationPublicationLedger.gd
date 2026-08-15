class_name ScheduleFoundationPublicationLedger
extends RefCounted

## Durable Schedule-foundation publication ledger (Plan 01 Task 4, dwm-p2r.13).
##
## One append-only document at one fixed relative path, written through the SAME approved
## root-scoped `StorageAdapter` object that owns the desktop issuer root. It is deliberately NOT a
## selectable save artifact: selected Load, New Run, profile reset, ordinary candidate rollback and
## recovery-journal rewind never reach it, and nothing here registers a restore participant.
##
## AT-MOST-ONCE BOUNDARY. `record_before_emit()` writes and RE-READS the exact candidate before its
## caller may emit an observation signal. A process loss after the durable record but before or
## after the signal is therefore an intentional at-most-once boundary: a cold instance re-reads the
## record from storage and answers `first_delivery=false`. No in-memory flag is ever treated as
## restart proof -- `_loaded` only caches bytes that came from storage in this process.
##
## `_SCHEMA` and `_RECORD_SCHEMA` mirror schemas/save/schedule-foundation-publication-ledger.schema.json;
## the key, hash and receipt-binding laws the mini dialect cannot express are hand-written below.

const FIXED_PATH := "schedule-foundation-publications.json"
const SCHEMA_VERSION := 1

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const DOCUMENT_KEYS: Array[String] = ["records", "schema_version"]
const RECORD_KEYS: Array[String] = [
	"key", "kind", "publication", "publication_sha256", "semantic_receipt",
]
const REQUEST_KEYS: Array[String] = [
	"kind", "publication", "publication_sha256", "semantic_receipt",
]
const KINDS: Array[String] = ["schedule_commit", "day_resolution_start"]

## The exact publication member set and bound receipt member for each kind.
const PUBLICATION_KEYS := {
	"schedule_commit": ["committed_schedule", "schedule_commit_receipt"],
	"day_resolution_start": ["day_resolution_start_receipt", "resolution_plan"],
}
const PUBLICATION_RECEIPT_MEMBER := {
	"schedule_commit": "schedule_commit_receipt",
	"day_resolution_start": "day_resolution_start_receipt",
}

## The exact StorageAdapter capability this ledger consumes; it never constructs storage itself and
## never chooses a `user://` root.
const STORAGE_METHODS: Array[String] = [
	"read_text", "write_atomic", "reconcile", "exists", "describe_root",
]

const _SCHEMA := {
	"$schema": "https://json-schema.org/draft/2020-12/schema",
	"type": "object",
	"additionalProperties": false,
	"required": ["schema_version", "records"],
	"properties": {
		"schema_version": {"const": 1},
		"records": {"type": "object"},
	},
}

const _RECORD_SCHEMA := {
	"type": "object",
	"additionalProperties": false,
	"required": ["key", "kind", "publication", "publication_sha256", "semantic_receipt"],
	"properties": {
		"key": {"type": "string", "minLength": 1},
		"kind": {"enum": ["schedule_commit", "day_resolution_start"]},
		"semantic_receipt": {"type": "object"},
		"publication": {"type": "object"},
		"publication_sha256": {"type": "string", "minLength": 64},
	},
}

var _storage: Object = null
var _document: Dictionary = {}
var _loaded := false


# ---- frozen public surface ----

func configure(storage: Object) -> Dictionary:
	if storage == null:
		return _failed(&"publication_ledger_storage_unbound", "configure requires a storage")
	for method_name: String in STORAGE_METHODS:
		if not storage.has_method(method_name):
			return _failed(&"publication_ledger_storage_invalid", "storage is missing " + method_name)
	if str(storage.call(&"describe_root")).strip_edges().is_empty():
		return _failed(&"publication_ledger_storage_unrooted",
			"the storage must describe the already-approved application root")
	if _storage != null:
		if _storage == storage:
			return _ok({"already_configured": true})
		return _failed(&"publication_ledger_already_configured",
			"a second root owner is refused")
	_storage = storage
	_loaded = false
	_document = {}
	return _ok({"already_configured": false})


## Reconciles and reads the durable document, or initializes the exact empty one when the fixed path
## is absent. Both branches re-read, strict-parse, schema/key/value-validate and detach.
func load() -> Dictionary:
	var ready := _require_configured("load")
	if not ready.get("ok", false):
		return ready
	var loaded := _load(true)
	if not loaded.get("ok", false):
		return loaded
	return _ok({"document": _document.duplicate(true)})


func record_before_emit(request: Dictionary) -> Dictionary:
	var ready := _require_configured("record_before_emit")
	if not ready.get("ok", false):
		return ready
	if typeof(request) != TYPE_DICTIONARY:
		return _failed(&"publication_request_invalid", "the request must be a dictionary")
	var shape := _exact_keys(request, REQUEST_KEYS, &"publication_request_invalid")
	if not shape.get("ok", true):
		return shape
	var kind_value: Variant = request["kind"]
	if typeof(kind_value) != TYPE_STRING or not KINDS.has(str(kind_value)):
		return _failed(&"publication_request_invalid", "kind is a closed String union")
	var kind := str(kind_value)
	var publication: Variant = request["publication"]
	var semantic_receipt: Variant = request["semantic_receipt"]
	if typeof(publication) != TYPE_DICTIONARY or typeof(semantic_receipt) != TYPE_DICTIONARY:
		return _failed(&"publication_request_invalid",
			"publication and semantic_receipt are dictionaries")
	var binding := _publication_binding_error(kind, publication, semantic_receipt)
	if not binding.is_empty():
		return binding
	var hashed := _canonical_sha256(publication)
	if hashed.is_empty():
		return _failed(&"publication_request_invalid", "the publication is not canonicalizable")
	if typeof(request["publication_sha256"]) != TYPE_STRING \
			or str(request["publication_sha256"]) != hashed:
		return _failed(&"publication_request_invalid",
			"publication_sha256 must equal the canonical publication digest")

	var loaded := _load()
	if not loaded.get("ok", false):
		return loaded

	var key := _key_for(kind, str((semantic_receipt as Dictionary)["receipt_id"]))
	var candidate := {
		"key": key,
		"kind": kind,
		"semantic_receipt": (semantic_receipt as Dictionary).duplicate(true),
		"publication": (publication as Dictionary).duplicate(true),
		"publication_sha256": hashed,
	}
	var records: Dictionary = _document.get("records", {})
	if records.has(key):
		if records[key] == candidate:
			return _ok({"record": (records[key] as Dictionary).duplicate(true),
				"first_delivery": false})
		return _failed(&"publication_record_conflict", key)

	var next_document := _document.duplicate(true)
	(next_document["records"] as Dictionary)[key] = candidate.duplicate(true)
	var validated := _validate_document(next_document)
	if not validated.get("ok", false):
		return validated
	var canonical := _canonical(next_document)
	if canonical.is_empty():
		return _failed(&"publication_ledger_serialization_failed",
			"the document is not canonicalizable")
	var text := canonical + "\n"
	var written: Dictionary = _storage.call(
		&"write_atomic", FIXED_PATH, text, Callable(self, "_parse_document"), true)
	if not written.get("ok", false):
		return _storage_failure(written)
	var reread: Dictionary = _storage.call(&"read_text", FIXED_PATH)
	if not reread.get("ok", false):
		return _storage_failure(reread)
	if str(reread.get("value", "")) != text:
		return _failed(&"publication_record_unverified",
			"the re-read document is not the exact candidate")
	var reparsed: Dictionary = _STRICT_JSON.parse_object(text)
	if not reparsed.get("ok", false):
		return _failed(&"publication_ledger_malformed", "the candidate did not strict-parse")
	var confirmed := _validate_document(reparsed["value"])
	if not confirmed.get("ok", false):
		return confirmed
	if (reparsed["value"] as Dictionary)["records"].get(key) != candidate:
		return _failed(&"publication_record_unverified",
			"the durable record is not the exact candidate")
	_document = next_document
	_loaded = true
	return _ok({"record": candidate.duplicate(true), "first_delivery": true})


# ---- internals ----

func _require_configured(method_name: String) -> Dictionary:
	if _storage == null:
		return _failed(&"publication_ledger_not_configured",
			"ScheduleFoundationPublicationLedger.%s before configure" % method_name)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _load(force := false) -> Dictionary:
	if _loaded and not force:
		return {"ok": true}
	var expected_text := ""
	if not bool(_storage.call(&"exists", FIXED_PATH)):
		var canonical := _canonical(_empty_document())
		if canonical.is_empty():
			return _failed(&"publication_ledger_serialization_failed",
				"the empty document is not canonicalizable")
		expected_text = canonical + "\n"
		var written: Dictionary = _storage.call(
			&"write_atomic", FIXED_PATH, expected_text, Callable(self, "_parse_document"), true)
		if not written.get("ok", false):
			return _storage_failure(written)
	var reconciled: Dictionary = _storage.call(
		&"reconcile", FIXED_PATH, Callable(self, "_parse_document"))
	if not reconciled.get("ok", false):
		return _storage_failure(reconciled)
	if not reconciled.get("exists", false):
		return _failed(&"publication_ledger_unreadable",
			"the initialized document is absent after reconciliation")
	var text_result: Dictionary = _storage.call(&"read_text", FIXED_PATH)
	if not text_result.get("ok", false):
		return _storage_failure(text_result)
	var text := str(text_result.get("value", ""))
	if not expected_text.is_empty() and text != expected_text:
		return _failed(&"publication_ledger_initialization_mismatch",
			"initialization did not produce the exact empty document bytes")
	var parsed: Dictionary = _STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return _failed(&"publication_ledger_malformed",
			"the durable document is not strict JSON")
	var document: Dictionary = parsed["value"]
	var validated := _validate_document(document)
	if not validated.get("ok", false):
		return validated
	_document = document.duplicate(true)
	_loaded = true
	return {"ok": true}


func _parse_document(text: String) -> Dictionary:
	return _STRICT_JSON.parse_object(text)


func _validate_document(document: Variant) -> Dictionary:
	if typeof(document) != TYPE_DICTIONARY:
		return _failed(&"publication_ledger_schema_invalid", "the document must be a dictionary")
	# The strict member/type laws run BEFORE the schema dialect: its `const` comparison raises on a
	# type-changed member instead of reporting it.
	var keys: Array = (document as Dictionary).keys()
	keys.sort()
	if keys != DOCUMENT_KEYS:
		return _failed(&"publication_ledger_schema_invalid", "the document member set is exact")
	if typeof((document as Dictionary)["schema_version"]) != TYPE_INT \
			or int((document as Dictionary)["schema_version"]) != SCHEMA_VERSION:
		return _failed(&"publication_ledger_schema_invalid", "schema_version must be the int 1")
	var records: Variant = (document as Dictionary)["records"]
	if typeof(records) != TYPE_DICTIONARY:
		return _failed(&"publication_ledger_schema_invalid", "records must be a dictionary")
	var shape: Dictionary = _SCHEMA_VALIDATOR.validate(document, _SCHEMA)
	if not shape.get("ok", false):
		return _failed(&"publication_ledger_schema_invalid",
			str(shape.get("message", "schema rejected")))
	for key: Variant in records as Dictionary:
		if typeof(key) != TYPE_STRING or str(key).strip_edges().is_empty():
			return _failed(&"publication_ledger_schema_invalid", "a record key is a nonblank String")
		var record_error := _validate_record((records as Dictionary)[key], str(key))
		if not record_error.get("ok", false):
			return record_error
	return {"ok": true}


func _validate_record(raw: Variant, key: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _failed(&"publication_ledger_schema_invalid", "a record must be a dictionary")
	var record: Dictionary = raw
	var keys: Array = record.keys()
	keys.sort()
	if keys != RECORD_KEYS:
		return _failed(&"publication_ledger_schema_invalid", "the record member set is exact")
	for field: String in ["key", "kind", "publication_sha256"]:
		if typeof(record[field]) != TYPE_STRING:
			return _failed(&"publication_ledger_schema_invalid", field + " must be a String")
	var shape: Dictionary = _SCHEMA_VALIDATOR.validate(record, _RECORD_SCHEMA)
	if not shape.get("ok", false):
		return _failed(&"publication_ledger_schema_invalid",
			str(shape.get("message", "record schema rejected")))
	if str(record["key"]) != key:
		return _failed(&"publication_ledger_schema_invalid",
			"the record key must equal its index")
	var kind := str(record["kind"])
	var binding := _publication_binding_error(kind, record["publication"],
		record["semantic_receipt"])
	if not binding.is_empty():
		return binding
	if _key_for(kind, str((record["semantic_receipt"] as Dictionary)["receipt_id"])) != key:
		return _failed(&"publication_ledger_schema_invalid",
			"the key is exactly kind + ':' + semantic receipt id")
	var hashed := _canonical_sha256(record["publication"])
	if hashed.is_empty() or str(record["publication_sha256"]) != hashed:
		return _failed(&"publication_ledger_schema_invalid",
			"publication_sha256 must equal the canonical publication digest")
	return {"ok": true}


func _publication_binding_error(kind: String, publication: Variant,
		semantic_receipt: Variant) -> Dictionary:
	if not KINDS.has(kind):
		return _failed(&"publication_request_invalid", "kind is a closed String union")
	if typeof(publication) != TYPE_DICTIONARY or typeof(semantic_receipt) != TYPE_DICTIONARY:
		return _failed(&"publication_request_invalid",
			"publication and semantic_receipt are dictionaries")
	var expected: Array = (PUBLICATION_KEYS[kind] as Array).duplicate()
	expected.sort()
	var keys: Array = (publication as Dictionary).keys()
	keys.sort()
	if keys != expected:
		return _failed(&"publication_request_invalid",
			"a %s publication carries exactly %s" % [kind, str(expected)])
	var receipt_member := str(PUBLICATION_RECEIPT_MEMBER[kind])
	var bound: Variant = (publication as Dictionary)[receipt_member]
	if typeof(bound) != TYPE_DICTIONARY or bound != semantic_receipt:
		return _failed(&"publication_request_invalid",
			"the semantic receipt must be byte-equal to " + receipt_member)
	var receipt_id: Variant = (semantic_receipt as Dictionary).get("receipt_id")
	if typeof(receipt_id) != TYPE_STRING or str(receipt_id).strip_edges().is_empty():
		return _failed(&"publication_request_invalid",
			"the semantic receipt names a nonblank receipt_id")
	return {}


func _empty_document() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "records": {}}


static func _key_for(kind: String, receipt_id: String) -> String:
	return kind + ":" + receipt_id


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_WRITER.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"])


func _canonical_sha256(value: Variant) -> String:
	var canonical := _canonical(value)
	if canonical.is_empty():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	var wanted: Array = expected.duplicate()
	wanted.sort()
	if keys != wanted:
		return _failed(code, "the member set is exactly " + str(wanted))
	return {"ok": true}


func _storage_failure(result: Dictionary) -> Dictionary:
	return _failed(StringName(str(result.get("code", &"publication_ledger_storage_failed"))),
		str(result.get("message", "storage refused")))


func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code,
		"message": "ScheduleFoundationPublicationLedger: " + message, "details": {}}
