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
## FIX (dwm-p2r.35.1 remediation, finding W1): the closed `kind` union is exactly the three record
## kinds the frozen contract names at plan02-frozen-contracts.md line 328 -- `causal_sequence`,
## `action_source`, `board_fate` -- one per Plan-02 publisher (`DesktopCausalSequencePort`; the two
## action-source participants, `MinesweeperRoundCoordinator`/`MinesweeperShopPurchaseParticipant`,
## sharing one kind; `DesktopBoardFatePort`), never the causal reservation's own
## `minesweeper_round|shop_purchase|schedule_done` `source_kind` union a prior implementation reused
## here by mistake. Each kind has its OWN publication shape and its OWN receipt-id field for key
## derivation (line 335): `causal_sequence`'s `semantic_receipt` equals `publication` in its entirety
## (`{causal_sequence_receipt,admission_checkpoint_receipt}`), keyed off the nested
## `causal_sequence_receipt.receipt_id`; `action_source`'s `semantic_receipt` is the exact
## `DesktopActionReceipt`, keyed off its `commit_receipt_id` (that receipt has no top-level
## `receipt_id` member at all); `board_fate`'s `semantic_receipt` is the exact `board_fate_receipt`,
## keyed off its ordinary `receipt_id`.

const FIXED_PATH := "desktop-publications.json"
const SCHEMA_VERSION := 1

const KINDS: Array[String] = ["causal_sequence", "action_source", "board_fate"]

## The exact publication member set for each kind (frozen contract line 335).
const PUBLICATION_KEYS := {
	"causal_sequence": ["admission_checkpoint_receipt", "causal_sequence_receipt"],
	"action_source": ["action_candidate_sha256", "action_receipt"],
	"board_fate": ["board_candidate", "board_fate_receipt"],
}
## The publication member that must be byte-equal to `semantic_receipt`; an empty string means
## `semantic_receipt` equals `publication` in its entirety instead of nesting inside one member
## (`causal_sequence` alone -- frozen contract line 335's "semantic receipt and publication are both
## exactly {causal_sequence_receipt,admission_checkpoint_receipt}").
const _PUBLICATION_RECEIPT_MEMBER := {
	"causal_sequence": "", "action_source": "action_receipt", "board_fate": "board_fate_receipt",
}
## The path inside `semantic_receipt` whose final String value is the record key's id suffix.
const _RECEIPT_ID_PATH := {
	"causal_sequence": ["causal_sequence_receipt", "receipt_id"],
	"action_source": ["commit_receipt_id"],
	"board_fate": ["receipt_id"],
}

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
		"kind": {"enum": ["causal_sequence", "action_source", "board_fate"]},
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
# Exact canonical documents constructed and fully validated in this process. Storage callbacks may
# reuse them only while the text is byte-identical; cold or changed bytes always take the full parser.
# An entry may also carry `canonical_records` (record key -> the exact text CanonicalJsonWriter
# emits for that record value) and `canonical_fields` (each OTHER top-level field's canonical text):
# the incremental emit cache `_compose_candidate_text()` composes an append from. It lives INSIDE
# the memo entry on purpose, so a cache and the document text it describes share one lifetime and
# an evicted or superseded text can never leave a stale cache behind.
var _validated_text_documents: Dictionary = {}
var _validated_text_order: Array[String] = []
## The exact text `_cached_document` was parsed from, or written as. The canonical cache is keyed by
## text, so this is how a cache entry is proved to describe THIS document and not a superseded one.
var _cached_text := ""
## DWM_CONSEQUENCE_PROFILE gate, read from the environment once per instance in _init(). Every
## profile marker below costs exactly one boolean check while the variable is unset.
var _profile_enabled: bool = false


func _init() -> void:
	_profile_enabled = OS.get_environment("DWM_CONSEQUENCE_PROFILE") == "1"


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
	_cached_text = ""
	_validated_text_documents = {}
	_validated_text_order = []
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
	var profile := {}
	var tick := 0
	if _profile_enabled:
		tick = Time.get_ticks_usec()
		profile = {"scope": "desktop_publication_ledger",
			"kind": str(request.get("kind", "")), "_started_us": tick}
	var checked := _check_request(request, profile)
	tick = _profile_phase(profile, "request_check_us", tick)
	if not checked.get("ok", false):
		return _profile_result(profile, checked)
	var entry: Dictionary = checked["value"]["entry"]

	var refreshed := _refresh_from_disk()
	tick = _profile_phase(profile, "disk_refresh_us", tick)
	if not refreshed.get("ok", false):
		return _profile_result(profile, refreshed)
	var existing_records: Dictionary = _cached_document.get("records", {})
	if not profile.is_empty():
		profile["records_before"] = existing_records.size()
		tick = Time.get_ticks_usec()
	if existing_records.has(entry["key"]):
		var stored: Dictionary = existing_records[entry["key"]]
		# FIX: same canonical-representation comparison as _confirm_written_entry() below, for the
		# identical reason -- after a cold restart, `stored` is read fresh from disk (plain String
		# throughout), while a genuinely byte-identical replay's freshly built `entry` may still carry
		# a StringName a production caller embedded (e.g. a checkpoint header's own `kind`). Raw `!=`
		# would misreport that replay as a conflict instead of the no-op success it actually is.
		if _digest_source(stored) == _digest_source(entry):
			_profile_phase(profile, "replay_compare_us", tick)
			return _profile_result(profile,
				_accepted({"record": stored.duplicate(true), "first_delivery": false}))
		_profile_phase(profile, "replay_compare_us", tick)
		return _profile_result(profile,
			_rejected(&"publication_record_conflict", str(entry["key"])))

	return _profile_result(profile, _commit_new_entry(entry, profile))


func _check_request(request: Dictionary, profile: Dictionary = {}) -> Dictionary:
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
	var binding_error := _publication_binding_error(kind, publication, semantic_receipt)
	if not binding_error.is_empty():
		return _rejected(&"publication_request_invalid", binding_error)
	var digest_started := Time.get_ticks_usec() if not profile.is_empty() else 0
	var digest := _digest(publication)
	_profile_phase(profile, "request_digest_us", digest_started)
	if digest.is_empty():
		return _rejected(&"publication_request_invalid", "publication is not canonically representable")
	if str(request.get("publication_sha256", "")) != digest:
		return _rejected(&"publication_request_invalid", "publication_sha256 does not match the canonical digest")
	var receipt_id := str(_receipt_id_for_key(kind, semantic_receipt as Dictionary))
	return {"ok": true, "value": {"entry": {
		"key": _ledger_key(kind, receipt_id),
		"kind": kind,
		"semantic_receipt": (semantic_receipt as Dictionary).duplicate(true),
		"publication": (publication as Dictionary).duplicate(true),
		"publication_sha256": digest,
	}}}


func _commit_new_entry(entry: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var tick := Time.get_ticks_usec() if not profile.is_empty() else 0
	# Normalize the one new record's engine text (StringName keys and values a production caller
	# embeds, e.g. a checkpoint header's own `kind`) exactly as the historical canonical emit plus
	# strict re-parse did, without emitting or parsing the ~100 KB board_fate entry: the walk is
	# identity-preserving on StringName-free subtrees, and `_confirm_written_entry()` below proves
	# after the exact reread that the durable record still deep-equals the original entry. The
	# entry is canonicalizable by construction here: `_check_request()` already emitted and
	# digested `publication`, and every kind binds `semantic_receipt` to a member of it.
	var normalized_entry: Dictionary = _normalize_engine_text(entry)
	tick = _profile_phase(profile, "entry_normalize_us", tick)
	# A cached document is immutable once cached (`_parse_known_document()` hands the memoized
	# document out by reference), and a record is only ever APPENDED under a key `record_before_emit`
	# has already proved absent -- never mutated in place. So the candidate copies exactly the two
	# containers this append changes, the envelope and the records map, and shares every retained
	# record object with the cached document instead of deep-copying the whole ~800 KB document.
	var candidate_document := _cached_document.duplicate()
	var candidate_records: Dictionary = (_cached_document.get("records", {}) as Dictionary).duplicate()
	candidate_records[normalized_entry["key"]] = normalized_entry
	candidate_document["records"] = candidate_records
	tick = _profile_phase(profile, "candidate_build_us", tick)
	# The cached document was fully validated by refresh; check only the newly appended record. The
	# publication digest was already emitted and compared in `_check_request()`, so it is passed
	# along instead of canonicalizing the same ~80 KB publication a second time.
	var entry_error := _record_shape_error(normalized_entry, str(normalized_entry["key"]),
		str(normalized_entry["publication_sha256"]))
	tick = _profile_phase(profile, "shape_check_us", tick)
	if not entry_error.is_empty():
		return _rejected(&"publication_ledger_schema_invalid", entry_error)
	# One emit of the ONE new record, joined to the retained records' already-cached canonical texts,
	# instead of re-canonicalizing the whole ~800 KB document for every append. The composer returns
	# nothing when no cache describes the cached document (a cold instance, externally changed bytes,
	# an exotic key set), and then the historical full emit below runs exactly as it always did.
	var composed := _compose_candidate_text(normalized_entry, profile)
	var body := str(composed.get("text", ""))
	if body.is_empty():
		body = _digest_source(candidate_document)
		tick = _profile_phase(profile, "full_emit_us", tick)
	else:
		tick = _profile_phase(profile, "compose_us", tick)
	if not profile.is_empty():
		profile["emit_path"] = "full" if composed.is_empty() else "composed"
		profile["document_bytes"] = body.to_utf8_buffer().size() + 1
		tick = Time.get_ticks_usec()
	if body.is_empty():
		return _rejected(&"publication_ledger_serialization_failed", "candidate document is not canonicalizable")
	var payload := body + "\n"
	_remember_validated_text(payload, candidate_document, true, true)
	tick = _profile_phase(profile, "cache_seed_us", tick)
	var write_result: Dictionary = _storage.call(
		&"write_atomic", FIXED_PATH, payload, Callable(self, "_parse_known_storage_witness"), true)
	tick = _profile_phase(profile, "write_atomic_us", tick)
	if not write_result.get("ok", false):
		return _from_storage_failure(write_result)
	var confirmed := _confirm_written_entry(payload, entry, profile)
	if not confirmed.get("ok", false):
		return confirmed
	_cached_document = candidate_document
	_cached_text = payload
	_has_cached_document = true
	_adopt_canonical_texts(payload, composed)
	return _accepted({"record": entry.duplicate(true), "first_delivery": true})


func _confirm_written_entry(expected_payload: String, entry: Dictionary,
		profile: Dictionary = {}) -> Dictionary:
	var tick := Time.get_ticks_usec() if not profile.is_empty() else 0
	var reread: Dictionary = _storage.call(&"read_text", FIXED_PATH)
	tick = _profile_phase(profile, "reread_us", tick)
	if not reread.get("ok", false):
		return _from_storage_failure(reread)
	# Exact reread equality proves the validated candidate bytes survived unchanged.
	if str(reread.get("value", "")) != expected_payload:
		return _rejected(&"publication_record_unverified", "the re-read bytes are not the exact candidate")
	var known: Dictionary = _parse_known_document(expected_payload)
	if not known.get("ok", false):
		return _rejected(&"publication_record_unverified", "the durable record diverges from the candidate")
	# ONE record is read out of the validated document: `_parse_known_document()` hands the memoized
	# document out by reference, so fetching it no longer deep-copies the whole ~800 KB document.
	var reparsed_entry: Variant = (known["value"] as Dictionary)["records"].get(entry["key"])
	# Type-aware deep equality (StringName folded on the entry side only, 1 and 1.0 distinct) is the
	# same proof the two canonical emits gave, without emitting the ~100 KB entry twice.
	if not _CANON._deep_same(entry, reparsed_entry):
		_profile_phase(profile, "confirmation_us", tick)
		return _rejected(&"publication_record_unverified", "the durable record diverges from the candidate")
	_profile_phase(profile, "confirmation_us", tick)
	return {"ok": true}


static func _profile_phase(profile: Dictionary, phase: String, started_us: int) -> int:
	if profile.is_empty():
		return 0
	var now := Time.get_ticks_usec()
	profile[phase] = now - started_us
	return now


static func _profile_result(profile: Dictionary, result: Dictionary) -> Dictionary:
	if not profile.is_empty():
		profile["elapsed_us"] = Time.get_ticks_usec() - int(profile["_started_us"])
		profile.erase("_started_us")
		profile["ok"] = bool(result.get("ok", false))
		var value: Variant = result.get("value")
		if value is Dictionary:
			profile["first_delivery"] = (value as Dictionary).get("first_delivery", null)
		if not profile["ok"]:
			profile["code"] = str(result.get("code", ""))
		print("DWM_CONSEQUENCE_PROFILE " + JSON.stringify(profile))
	return result


func _refresh_from_disk() -> Dictionary:
	if not bool(_storage.call(&"exists", FIXED_PATH)):
		var seed_error := _seed_empty_document()
		if not seed_error.is_empty():
			return seed_error
	var reconciled: Dictionary = _storage.call(&"reconcile", FIXED_PATH, Callable(self, "_parse_known_storage_witness"))
	if not reconciled.get("ok", false):
		return _from_storage_failure(reconciled)
	if not reconciled.get("exists", false):
		return _rejected(&"publication_ledger_unreadable", "the seeded document is unexpectedly absent")
	var read_result: Dictionary = _storage.call(&"read_text", FIXED_PATH)
	if not read_result.get("ok", false):
		return _from_storage_failure(read_result)
	var text := str(read_result.get("value", ""))
	var parsed: Dictionary = _parse_known_document(text)
	if not parsed.get("ok", false):
		return parsed
	# The parsed document is the memoized one and is never mutated in place, so refresh does not copy
	# what the parser already owns; `load()` below still hands its caller an own deep copy.
	_cached_document = parsed["value"]
	_cached_text = text
	_has_cached_document = true
	return {"ok": true}


func _seed_empty_document() -> Dictionary:
	var body := _digest_source(_empty_document())
	if body.is_empty():
		return _rejected(&"publication_ledger_serialization_failed", "the empty document is not canonicalizable")
	var seeded: Dictionary = _storage.call(&"write_atomic", FIXED_PATH, body + "\n", Callable(self, "_parse_known_storage_witness"), true)
	if not seeded.get("ok", false):
		return _from_storage_failure(seeded)
	return {}


func _parse_known_storage_text(text: String) -> Dictionary:
	if _validated_text_documents.has(text):
		_touch_validated_text(text)
		var known: Dictionary = _validated_text_documents[text]
		return {"ok": true, "code": &"ok", "value": (known["document"] as Dictionary).duplicate(true)}
	var parsed: Dictionary = _JSON.parse_object(text)
	if parsed.get("ok", false):
		_remember_validated_text(text, parsed["value"], false)
	return parsed


## Storage needs a validity WITNESS for bytes, while this owner retains the document itself. On the
## three call sites that discard the value storage hands back -- `_refresh_from_disk()`'s reconcile,
## `_commit_new_entry()`'s and `_seed_empty_document()`'s write_atomic -- an already-validated text
## therefore answers with an EMPTY value instead of a deep copy of the whole ~800 KB document that
## nothing ever reads (storage copies a validator result twice more on top of that). Unknown or
## changed text still takes `_parse_known_storage_text()` unchanged, so the cold path returns the
## full validated document, seeds the memo the same way, and keeps every refusal code and its order
## exactly as before. Mirrors `DesktopIssuerRootStore._parse_known_write_document()`.
func _parse_known_storage_witness(text: String) -> Dictionary:
	if _validated_text_documents.has(text):
		_touch_validated_text(text)
		return {"ok": true, "code": &"ok", "value": {}}
	return _parse_known_storage_text(text)


## Returns the validated document BY REFERENCE. Every document this class caches is immutable once
## cached -- `_commit_new_entry()` copies the two containers an append changes and mutates neither
## source, and `load()` gives its caller an own deep copy -- so this internal reader no longer
## deep-copies an ~800 KB document on every refresh and every write confirmation.
func _parse_known_document(text: String) -> Dictionary:
	var document: Dictionary
	if _validated_text_documents.has(text):
		_touch_validated_text(text)
		var known: Dictionary = _validated_text_documents[text]
		document = known["document"]
		if bool(known["schema_validated"]):
			return {"ok": true, "code": &"ok", "value": document}
	else:
		var parsed: Dictionary = _JSON.parse_object(text)
		if not parsed.get("ok", false):
			return _rejected(&"publication_ledger_malformed", "the durable document is not strict JSON")
		document = parsed["value"]
	var shape_error := _document_shape_error(document)
	if not shape_error.is_empty():
		return _rejected(&"publication_ledger_schema_invalid", shape_error)
	# Both branches hold a document only this instance owns: the memo's own copy, or a strict parse
	# nothing else has seen.
	_remember_validated_text(text, document, true, true)
	return {"ok": true, "code": &"ok", "value": document}


## `already_owned` marks a document this instance alone holds -- the memo's own document, a fresh
## strict parse, or a candidate it just built -- which is memoized as it is. The storage-callback
## path hands its parsed value to storage as well, so that one is still copied in.
func _remember_validated_text(text: String, document: Dictionary, schema_validated: bool = true,
		already_owned: bool = false) -> void:
	_validated_text_documents[text] = {
		"document": document if already_owned else document.duplicate(true),
		"schema_validated": schema_validated,
	}
	_touch_validated_text(text)
	while _validated_text_order.size() > 3:
		_validated_text_documents.erase(_validated_text_order.pop_front())


func _touch_validated_text(text: String) -> void:
	_validated_text_order.erase(text)
	_validated_text_order.append(text)


## Composes the outgoing document text from the per-record canonical cache plus ONE emit of the new
## record, byte-identically to `_digest_source(candidate_document)` -- exactly the arrangement
## `DesktopIssuerRootStore._write_issued_document()` / `_compose_issue_document()` already use for
## the issuer root. Returns `{}` whenever the composed text cannot be proved identical (no cache
## describes the cached document, a piece refuses to canonicalize, an exotic key set); the caller
## then takes the historical full emit, so a miss costs speed and never bytes.
func _compose_candidate_text(normalized_entry: Dictionary, profile: Dictionary) -> Dictionary:
	var cache := _canonical_cache_entry(profile)
	if cache.is_empty():
		return {}
	var encoded_entry: Dictionary = _CANON.stringify(normalized_entry)
	if not encoded_entry.get("ok", false):
		return {}
	# The cached map may still describe a memoized document, so the append copies it (String values,
	# one shallow copy) instead of writing the new record into the map the old text is composed of.
	var record_texts: Dictionary = (cache["canonical_records"] as Dictionary).duplicate()
	record_texts[str(normalized_entry["key"])] = str(encoded_entry["value"])
	var fields: Dictionary = cache["canonical_fields"]
	var text := _compose_document_text(record_texts, fields)
	if text.is_empty():
		return {}
	return {"text": text, "records": record_texts, "fields": fields}


## The exact bytes `CanonicalJsonWriter.stringify()` emits for a document whose records are already
## encoded: sorted keys, `"key":value` pairs joined by commas, no separator whitespace anywhere.
func _compose_document_text(record_texts: Dictionary, fields: Dictionary) -> String:
	var record_keys: Variant = _canonical_key_order(record_texts.keys())
	if record_keys == null:
		return ""
	var encoded_records := PackedStringArray()
	for record_key: Variant in record_keys as Array:
		var encoded_key: Dictionary = _CANON.stringify(str(record_key))
		if not encoded_key.get("ok", false):
			return ""
		encoded_records.append(str(encoded_key["value"]) + ":" + str(record_texts[record_key]))
	var names: Array = fields.keys()
	names.append("records")
	var ordered: Variant = _canonical_key_order(names)
	if ordered == null:
		return ""
	var parts := PackedStringArray()
	for name_key: Variant in ordered as Array:
		var name := str(name_key)
		var encoded_name: Dictionary = _CANON.stringify(name)
		if not encoded_name.get("ok", false):
			return ""
		var encoded_value := ""
		if name == "records":
			encoded_value = "{" + ",".join(encoded_records) + "}"
		else:
			encoded_value = str(fields.get(name, ""))
		if encoded_value.is_empty():
			return ""
		parts.append(str(encoded_name["value"]) + ":" + encoded_value)
	return "{" + ",".join(parts) + "}"


## `null` when any key falls outside printable ASCII: the writer then orders that dictionary with
## its own UTF-8 byte comparator, which this composer deliberately does not reproduce, so the caller
## falls back to the full emit. On printable ASCII the writer sorts by plain String order in BOTH
## its native and its checked emitter, which is exactly what this returns.
static func _canonical_key_order(keys: Array) -> Variant:
	for key: Variant in keys:
		var name := str(key)
		for index in range(name.length()):
			var codepoint := name.unicode_at(index)
			if codepoint < 0x20 or codepoint > 0x7E:
				return null
	var ordered: Array = keys.duplicate()
	ordered.sort()
	return ordered


## The memo entry for `_cached_text` once it carries the canonical cache, rebuilding that cache ONCE
## per distinct document text. The rebuild costs one full emit and replaces the full emit every
## append used to pay; a cache that cannot be PROVED to describe `_cached_document` -- an evicted
## memo entry, a document refreshed from externally changed bytes -- is rebuilt, never trusted.
func _canonical_cache_entry(profile: Dictionary) -> Dictionary:
	if _cached_text.is_empty() or not _validated_text_documents.has(_cached_text):
		return {}
	var known: Dictionary = _validated_text_documents[_cached_text]
	if not is_same(known.get("document"), _cached_document):
		return {}
	if known.has("canonical_records"):
		return known
	var rebuilt := _rebuild_canonical_cache(_cached_document)
	if rebuilt.is_empty():
		return {}
	known["canonical_records"] = rebuilt["records"]
	known["canonical_fields"] = rebuilt["fields"]
	if not profile.is_empty():
		profile["canonical_rebuilt"] = true
	return known


func _rebuild_canonical_cache(document: Dictionary) -> Dictionary:
	var records := {}
	var fields := {}
	for key: Variant in document:
		var name := str(key)
		if name == "records":
			for record_key: Variant in document[name] as Dictionary:
				var encoded_record: Dictionary = _CANON.stringify((document[name] as Dictionary)[record_key])
				if not encoded_record.get("ok", false):
					return {}
				records[str(record_key)] = str(encoded_record["value"])
			continue
		var encoded_field: Dictionary = _CANON.stringify(document[name])
		if not encoded_field.get("ok", false):
			return {}
		fields[name] = str(encoded_field["value"])
	return {"records": records, "fields": fields}


## The new record joins the canonical cache only once its exact bytes are durable AND confirmed, so
## a refused or unverified write leaves the cache describing what is really on disk.
func _adopt_canonical_texts(text: String, composed: Dictionary) -> void:
	if composed.is_empty() or not _validated_text_documents.has(text):
		return
	var known: Dictionary = _validated_text_documents[text]
	known["canonical_records"] = composed["records"]
	known["canonical_fields"] = composed["fields"]


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


## `known_publication_digest`, when nonempty, is a digest this instance already emitted and
## compared for this exact publication (`_check_request()`); the disk-validation path passes
## nothing and still canonicalizes every stored publication.
func _record_shape_error(candidate: Variant, expected_key: String,
		known_publication_digest: String = "") -> String:
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
	var kind := str(record["kind"])
	var binding_error := _publication_binding_error(kind, record["publication"], record["semantic_receipt"])
	if not binding_error.is_empty():
		return binding_error
	var receipt_id := str(_receipt_id_for_key(kind, record["semantic_receipt"] as Dictionary))
	if _ledger_key(kind, receipt_id) != expected_key:
		return "key must equal kind + ':' + the kind-specific semantic-receipt id"
	var digest := known_publication_digest
	if digest.is_empty():
		digest = _digest(record["publication"])
	if digest.is_empty() or str(record["publication_sha256"]) != digest:
		return "publication_sha256 must equal the canonical publication digest"
	return ""


## Kind-specific binding law (frozen contract line 335, see the class doc's FIX note): every kind
## pins its own publication member set, which member (if any) must be byte-equal to `semantic_receipt`,
## and where inside `semantic_receipt` the record key's id suffix lives.
func _publication_binding_error(kind: String, publication: Variant, semantic_receipt: Variant) -> String:
	if typeof(publication) != TYPE_DICTIONARY or typeof(semantic_receipt) != TYPE_DICTIONARY:
		return "publication and semantic_receipt must both be dictionaries"
	var expected_keys: Array = PUBLICATION_KEYS[kind]
	var member_error := _mismatched_members(publication as Dictionary, expected_keys)
	if not member_error.is_empty():
		return member_error
	var receipt_member := str(_PUBLICATION_RECEIPT_MEMBER[kind])
	if receipt_member.is_empty():
		if (publication as Dictionary) != (semantic_receipt as Dictionary):
			return "publication must be byte-equal to semantic_receipt"
	elif (publication as Dictionary)[receipt_member] != semantic_receipt:
		return "publication." + receipt_member + " must be byte-equal to semantic_receipt"
	var receipt_id: Variant = _receipt_id_for_key(kind, semantic_receipt as Dictionary)
	if typeof(receipt_id) != TYPE_STRING or str(receipt_id).strip_edges().is_empty():
		return "semantic_receipt does not carry a nonblank id for this kind"
	return ""


## Walks `_RECEIPT_ID_PATH[kind]` inside `semantic_receipt` and returns the final String value, or
## null when any path segment is absent -- e.g. `action_source` reads the top-level `commit_receipt_id`
## while `causal_sequence` reads the nested `causal_sequence_receipt.receipt_id`.
func _receipt_id_for_key(kind: String, semantic_receipt: Dictionary) -> Variant:
	var path: Array = _RECEIPT_ID_PATH[kind]
	var cursor: Variant = semantic_receipt
	for segment: Variant in path:
		if typeof(cursor) != TYPE_DICTIONARY or not (cursor as Dictionary).has(str(segment)):
			return null
		cursor = (cursor as Dictionary)[str(segment)]
	return cursor


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


## Identity-preserving: a subtree that holds no StringName is returned AS IS, so a StringName-free
## entry allocates nothing here. Exact mirror of SaveDocumentSchema._normalize_engine_text();
## it converts StringName keys and values only and can introduce no float, no key, no reorder.
static func _normalize_engine_text(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME: return String(value)
		TYPE_ARRAY:
			var source_array: Array = value
			var array: Array = []
			var array_converted := false
			for element: Variant in source_array:
				var normalized_element: Variant = _normalize_engine_text(element)
				if not is_same(normalized_element, element):
					array_converted = true
				array.append(normalized_element)
			return array if array_converted else source_array
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			var dictionary := {}
			var dictionary_converted := false
			for raw_key: Variant in source_dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				if not is_same(key, raw_key):
					dictionary_converted = true
				var member: Variant = source_dictionary[raw_key]
				var normalized_member: Variant = _normalize_engine_text(member)
				if not is_same(normalized_member, member):
					dictionary_converted = true
				dictionary[key] = normalized_member
			return dictionary if dictionary_converted else source_dictionary
	return value


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
