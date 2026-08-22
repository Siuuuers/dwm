class_name DesktopPublicationLedger
extends RefCounted

## Desktop consequence-publication ledger (Plan 02 Task 6, dwm-p2r.32, req.desktop
## .cross_app_actions, req.minesweeper.causal_departure). One append-only JSON document at one
## fixed relative path, guarding the at-most-once boundary between a durable consequence commit and
## the external observation signal that tells the rest of the game "this happened" -- a UI
## notification, a Hospital handoff, or an ordinary Schedule Done acknowledgement.
##
## Why this exists at all: `DesktopConsequenceState`'s own `outbox` member records that a
## publication *should* happen, inside the run's own save. This ledger is the separate, cross-
## process guard that a given publication has *already* happened, so a crash between "recorded
## internally" and "signal emitted" can never double-fire that signal on restart. The same root-
## scoped `StorageAdapter` family that owns the desktop issuer root writes it; it never becomes a
## selectable save artifact and registers no restore participant, so Load/New Run/profile reset/
## candidate rollback/journal rewind can never touch it.
##
## Structurally parallel to `ScheduleFoundationPublicationLedger` (Plan 01 Task 4) -- same
## configure/load/record_before_emit surface, same write-then-re-read-before-signal discipline --
## but deliberately disjoint from it: a distinct `FIXED_PATH`, a distinct closed `kind` union, and a
## distinct publication shape, so neither ledger's bytes can ever be mistaken for the other's.
##
## ASSUMPTION (documented per this project's convention for text the source plan leaves open, e.g.
## `DesktopIdentityNonceIssuer`'s schema_version note): the brief requires three closed kinds but
## never spells them out. Read as the causal reservation's own `source_kind` union --
## `minesweeper_round`, `shop_purchase`, `schedule_done` -- since that is the only closed
## three-member union anywhere in Task 6 that the brief's "each Plan-02 publisher" phrase could mean.

const FIXED_PATH := "desktop-publications.json"
const SCHEMA_VERSION := 1

const KINDS: Array[String] = ["minesweeper_round", "shop_purchase", "schedule_done"]

## A publication is the same shape for every kind: the causal-sequence receipt that anchors the
## consequence transaction, byte-equal to the record's own `semantic_receipt`, plus the outbox
## snapshot being published under it.
const PUBLICATION_KEYS: Array[String] = ["causal_sequence_receipt", "outbox"]
const _PUBLICATION_RECEIPT_FIELD := "causal_sequence_receipt"

const DOCUMENT_KEYS: Array[String] = ["records", "schema_version"]
const RECORD_KEYS: Array[String] = [
	"key", "kind", "publication", "publication_sha256", "semantic_receipt",
]
const REQUEST_KEYS: Array[String] = [
	"kind", "publication", "publication_sha256", "semantic_receipt",
]

## The capability this class borrows from an injected root-scoped storage; it never opens a file,
## chooses a root, or constructs storage on its own.
const _REQUIRED_STORAGE_CAPABILITY: Array[String] = [
	"describe_root", "exists", "read_text", "reconcile", "write_atomic",
]

const _DOCUMENT_SCHEMA := {
	"$schema": "https://json-schema.org/draft/2020-12/schema",
	"type": "object",
	"additionalProperties": false,
	"properties": {
		"schema_version": {"const": 1},
		"records": {"type": "object"},
	},
	"required": ["schema_version", "records"],
}

const _RECORD_SCHEMA := {
	"type": "object",
	"additionalProperties": false,
	"properties": {
		"key": {"type": "string", "minLength": 1},
		"kind": {"enum": ["minesweeper_round", "shop_purchase", "schedule_done"]},
		"publication": {"type": "object"},
		"publication_sha256": {"type": "string", "minLength": 64},
		"semantic_receipt": {"type": "object"},
	},
	"required": ["key", "kind", "publication", "publication_sha256", "semantic_receipt"],
}

const _JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _SCHEMA_CHECK := preload("res://scripts/validation/JsonSchemaValidator.gd")

var _storage: Object = null
var _cached_document: Dictionary = {}
var _has_cached_document := false


func configure(storage: Object) -> Dictionary:
	if storage == null:
		return _rejected(&"publication_ledger_storage_unbound", "a storage object is required")
	var missing := _first_missing_capability(storage)
	if not missing.is_empty():
		return _rejected(&"publication_ledger_storage_invalid", "storage is missing " + missing)
	if str(storage.call(&"describe_root")).strip_edges().is_empty():
		return _rejected(&"publication_ledger_storage_unrooted",
			"storage must describe an already-approved application root")
	if _storage == storage:
		return _accepted({"already_configured": true})
	if _storage != null:
		return _rejected(&"publication_ledger_already_configured", "a different root owner is already bound")
	_storage = storage
	_has_cached_document = false
	_cached_document = {}
	return _accepted({"already_configured": false})


func load() -> Dictionary:
	var gate := _require_bound("load")
	if not gate.is_empty():
		return gate
	var refreshed := _refresh_from_disk()
	if not refreshed.get("ok", false):
		return refreshed
	return _accepted({"document": _cached_document.duplicate(true)})


## Durably records ONE publication before its caller may emit the corresponding external signal.
## Replaying identical bytes for an already-recorded key is a no-op success reporting
## `first_delivery=false`; occupied bytes that differ conflict outright, and nothing is written to
## disk on any rejected path.
func record_before_emit(request: Dictionary) -> Dictionary:
	var gate := _require_bound("record_before_emit")
	if not gate.is_empty():
		return gate
	var checked := _check_request(request)
	if not checked.get("ok", false):
		return checked
	var entry: Dictionary = checked["value"]["entry"]

	var refreshed := _refresh_from_disk()
	if not refreshed.get("ok", false):
		return refreshed
	var existing_records: Dictionary = _cached_document.get("records", {})
	if existing_records.has(entry["key"]):
		var stored: Dictionary = existing_records[entry["key"]]
		if stored == entry:
			return _accepted({"record": stored.duplicate(true), "first_delivery": false})
		return _rejected(&"publication_record_conflict", str(entry["key"]))

	return _commit_new_entry(entry)


func _check_request(request: Dictionary) -> Dictionary:
	if typeof(request) != TYPE_DICTIONARY:
		return _rejected(&"publication_request_invalid", "request must be a dictionary")
	var member_error := _mismatched_members(request, REQUEST_KEYS)
	if not member_error.is_empty():
		return _rejected(&"publication_request_invalid", member_error)
	var kind := str(request.get("kind", ""))
	if not KINDS.has(kind):
		return _rejected(&"publication_request_invalid", "kind is not one of the closed union")
	var publication: Variant = request["publication"]
	var semantic_receipt: Variant = request["semantic_receipt"]
	var binding_error := _publication_binding_error(publication, semantic_receipt)
	if not binding_error.is_empty():
		return _rejected(&"publication_request_invalid", binding_error)
	var digest := _digest(publication)
	if digest.is_empty():
		return _rejected(&"publication_request_invalid", "publication is not canonically representable")
	if str(request.get("publication_sha256", "")) != digest:
		return _rejected(&"publication_request_invalid", "publication_sha256 does not match the canonical digest")
	var receipt_id := str((semantic_receipt as Dictionary)["receipt_id"])
	return {"ok": true, "value": {"entry": {
		"key": _ledger_key(kind, receipt_id),
		"kind": kind,
		"semantic_receipt": (semantic_receipt as Dictionary).duplicate(true),
		"publication": (publication as Dictionary).duplicate(true),
		"publication_sha256": digest,
	}}}


func _commit_new_entry(entry: Dictionary) -> Dictionary:
	var candidate_document := _cached_document.duplicate(true)
	(candidate_document["records"] as Dictionary)[entry["key"]] = entry.duplicate(true)
	var shape_error := _document_shape_error(candidate_document)
	if not shape_error.is_empty():
		return _rejected(&"publication_ledger_schema_invalid", shape_error)
	var body := _digest_source(candidate_document)
	if body.is_empty():
		return _rejected(&"publication_ledger_serialization_failed", "candidate document is not canonicalizable")
	var payload := body + "\n"
	var write_result: Dictionary = _storage.call(&"write_atomic", FIXED_PATH, payload, Callable(self, "_parse"), true)
	if not write_result.get("ok", false):
		return _from_storage_failure(write_result)
	var confirmed := _confirm_written_entry(payload, entry)
	if not confirmed.get("ok", false):
		return confirmed
	_cached_document = candidate_document
	_has_cached_document = true
	return _accepted({"record": entry.duplicate(true), "first_delivery": true})


func _confirm_written_entry(expected_payload: String, entry: Dictionary) -> Dictionary:
	var reread: Dictionary = _storage.call(&"read_text", FIXED_PATH)
	if not reread.get("ok", false):
		return _from_storage_failure(reread)
	if str(reread.get("value", "")) != expected_payload:
		return _rejected(&"publication_record_unverified", "the re-read bytes are not the exact candidate")
	var reparsed: Dictionary = _JSON.parse_object(expected_payload)
	if not reparsed.get("ok", false):
		return _rejected(&"publication_ledger_malformed", "the re-read document did not strict-parse")
	var reshaped := _document_shape_error(reparsed["value"])
	if not reshaped.is_empty():
		return _rejected(&"publication_ledger_schema_invalid", reshaped)
	if (reparsed["value"] as Dictionary)["records"].get(entry["key"]) != entry:
		return _rejected(&"publication_record_unverified", "the durable record diverges from the candidate")
	return {"ok": true}


func _refresh_from_disk() -> Dictionary:
	if not bool(_storage.call(&"exists", FIXED_PATH)):
		var seed_error := _seed_empty_document()
		if not seed_error.is_empty():
			return seed_error
	var reconciled: Dictionary = _storage.call(&"reconcile", FIXED_PATH, Callable(self, "_parse"))
	if not reconciled.get("ok", false):
		return _from_storage_failure(reconciled)
	if not reconciled.get("exists", false):
		return _rejected(&"publication_ledger_unreadable", "the seeded document is unexpectedly absent")
	var read_result: Dictionary = _storage.call(&"read_text", FIXED_PATH)
	if not read_result.get("ok", false):
		return _from_storage_failure(read_result)
	var parsed: Dictionary = _JSON.parse_object(str(read_result.get("value", "")))
	if not parsed.get("ok", false):
		return _rejected(&"publication_ledger_malformed", "the durable document is not strict JSON")
	var shape_error := _document_shape_error(parsed["value"])
	if not shape_error.is_empty():
		return _rejected(&"publication_ledger_schema_invalid", shape_error)
	_cached_document = (parsed["value"] as Dictionary).duplicate(true)
	_has_cached_document = true
	return {"ok": true}


func _seed_empty_document() -> Dictionary:
	var body := _digest_source(_empty_document())
	if body.is_empty():
		return _rejected(&"publication_ledger_serialization_failed", "the empty document is not canonicalizable")
	var seeded: Dictionary = _storage.call(&"write_atomic", FIXED_PATH, body + "\n", Callable(self, "_parse"), true)
	if not seeded.get("ok", false):
		return _from_storage_failure(seeded)
	return {}


func _parse(text: String) -> Dictionary:
	return _JSON.parse_object(text)


func _document_shape_error(document: Variant) -> String:
	if typeof(document) != TYPE_DICTIONARY:
		return "document must be a dictionary"
	var top_error := _mismatched_members(document as Dictionary, DOCUMENT_KEYS)
	if not top_error.is_empty():
		return top_error
	if int((document as Dictionary).get("schema_version", -1)) != SCHEMA_VERSION \
			or typeof((document as Dictionary)["schema_version"]) != TYPE_INT:
		return "schema_version must be the integer " + str(SCHEMA_VERSION)
	var records: Variant = (document as Dictionary)["records"]
	if typeof(records) != TYPE_DICTIONARY:
		return "records must be a dictionary"
	var against_schema: Dictionary = _SCHEMA_CHECK.validate(document, _DOCUMENT_SCHEMA)
	if not against_schema.get("ok", false):
		return str(against_schema.get("message", "document rejected by schema"))
	for record_key: Variant in records as Dictionary:
		if typeof(record_key) != TYPE_STRING or str(record_key).strip_edges().is_empty():
			return "every record key must be a nonblank String"
		var record_error := _record_shape_error((records as Dictionary)[record_key], str(record_key))
		if not record_error.is_empty():
			return record_error
	return ""


func _record_shape_error(candidate: Variant, expected_key: String) -> String:
	if typeof(candidate) != TYPE_DICTIONARY:
		return "record at " + expected_key + " must be a dictionary"
	var record: Dictionary = candidate
	var member_error := _mismatched_members(record, RECORD_KEYS)
	if not member_error.is_empty():
		return member_error
	for text_field: String in ["key", "kind", "publication_sha256"]:
		if typeof(record[text_field]) != TYPE_STRING:
			return text_field + " must be a String"
	var against_schema: Dictionary = _SCHEMA_CHECK.validate(record, _RECORD_SCHEMA)
	if not against_schema.get("ok", false):
		return str(against_schema.get("message", "record rejected by schema"))
	if str(record["key"]) != expected_key:
		return "record key must equal its map index"
	var binding_error := _publication_binding_error(record["publication"], record["semantic_receipt"])
	if not binding_error.is_empty():
		return binding_error
	var receipt_id := str((record["semantic_receipt"] as Dictionary)["receipt_id"])
	if _ledger_key(str(record["kind"]), receipt_id) != expected_key:
		return "key must equal kind + ':' + semantic_receipt.receipt_id"
	var digest := _digest(record["publication"])
	if digest.is_empty() or str(record["publication_sha256"]) != digest:
		return "publication_sha256 must equal the canonical publication digest"
	return ""


func _publication_binding_error(publication: Variant, semantic_receipt: Variant) -> String:
	if typeof(publication) != TYPE_DICTIONARY or typeof(semantic_receipt) != TYPE_DICTIONARY:
		return "publication and semantic_receipt must both be dictionaries"
	var member_error := _mismatched_members(publication as Dictionary, PUBLICATION_KEYS)
	if not member_error.is_empty():
		return member_error
	if (publication as Dictionary)[_PUBLICATION_RECEIPT_FIELD] != semantic_receipt:
		return "publication." + _PUBLICATION_RECEIPT_FIELD + " must be byte-equal to semantic_receipt"
	var receipt_id: Variant = (semantic_receipt as Dictionary).get("receipt_id")
	if typeof(receipt_id) != TYPE_STRING or str(receipt_id).strip_edges().is_empty():
		return "semantic_receipt.receipt_id must be a nonblank String"
	if typeof((publication as Dictionary)["outbox"]) != TYPE_DICTIONARY:
		return "publication.outbox must be a dictionary"
	return ""


func _first_missing_capability(candidate: Object) -> String:
	for method_name: String in _REQUIRED_STORAGE_CAPABILITY:
		if not candidate.has_method(method_name):
			return method_name
	return ""


func _mismatched_members(value: Dictionary, expected: Array) -> String:
	var actual_keys: Array = value.keys()
	actual_keys.sort()
	var wanted_keys: Array = expected.duplicate()
	wanted_keys.sort()
	if actual_keys != wanted_keys:
		return "member set must be exactly " + str(wanted_keys)
	return ""


func _empty_document() -> Dictionary:
	return {"records": {}, "schema_version": SCHEMA_VERSION}


static func _ledger_key(kind: String, receipt_id: String) -> String:
	return kind + ":" + receipt_id


func _digest_source(value: Variant) -> String:
	var emitted: Dictionary = _CANON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"])


func _digest(value: Variant) -> String:
	var source := _digest_source(value)
	if source.is_empty():
		return ""
	return source.sha256_text()


func _require_bound(caller: String) -> Dictionary:
	if _storage == null:
		return _rejected(&"publication_ledger_not_configured", "DesktopPublicationLedger.%s called before configure" % caller)
	return {}


func _from_storage_failure(result: Dictionary) -> Dictionary:
	return _rejected(StringName(str(result.get("code", &"publication_ledger_storage_failed"))),
		str(result.get("message", "the storage layer refused the operation")))


func _accepted(payload: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": payload, "receipt": {}}


func _rejected(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopPublicationLedger: " + message, "details": {}}
