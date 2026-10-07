class_name SceneEventContract
extends RefCounted
## Isolated, nonwired contract foundation. Registration is supplied by a trusted owner,
## never by DTL. This validates semantic input, not content approval or disk durability.
## A production adapter must bind registration/identity/frontier to one supported Run.

const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ENVELOPE_KEYS := ["schema_version", "source", "event_id", "ordinal", "predecessor",
	"kind", "payload", "command_id", "issuer_receipt", "playback_token"]
const SOURCE_KEYS := ["run_id", "branch_id", "causal_day_instance", "scene_occurrence",
	"entry_id", "content_version"]
const RECORD_KEYS := ["event_id", "ordinal", "predecessor", "kind", "payload", "command_id"]
const PAYLOAD_KEYS := {
	"scene.enter": ["scene_id", "entry_id", "context_id"],
	"day.begin": ["source_phase", "target_day"],
	"day.complete": ["source_day", "successor_id"],
	"background.set": ["art_id"],
	"self_talk.trigger": ["entry_id", "segment_id"],
	"notification.set": ["notification_id", "content_id", "parameters"],
	"notification.clear": ["notification_id"],
	"appointment.admit": ["appointment_id", "invitation_receipt_id"],
	"appointment.complete": ["appointment_id", "completion_receipt_id"],
}

static func inspect(envelope: Variant) -> Dictionary:
	if not _keys(envelope, ENVELOPE_KEYS): return _fail(&"event_shape_invalid")
	if typeof(envelope.schema_version) != TYPE_INT or envelope.schema_version != 1:
		return _fail(&"event_version_invalid")
	if not _keys(envelope.source, SOURCE_KEYS): return _fail(&"event_source_invalid")
	for key: String in SOURCE_KEYS:
		if key == "content_version":
			if typeof(envelope.source[key]) != TYPE_INT or envelope.source[key] < 1:
				return _fail(&"event_source_invalid")
		elif not _id(envelope.source[key]): return _fail(&"event_source_invalid")
	for key: String in ["event_id", "kind", "command_id", "playback_token"]:
		if not _id(envelope[key]): return _fail(&"event_identity_invalid")
	if typeof(envelope.ordinal) != TYPE_INT or envelope.ordinal < 0:
		return _fail(&"event_ordinal_invalid")
	if typeof(envelope.predecessor) != TYPE_STRING or (envelope.predecessor != "" and not _id(envelope.predecessor)):
		return _fail(&"event_predecessor_invalid")
	if not envelope.issuer_receipt is Dictionary: return _fail(&"event_issuer_invalid")
	if not PAYLOAD_KEYS.has(envelope.kind): return _fail(&"event_kind_unregistered")
	if not _keys(envelope.payload, PAYLOAD_KEYS[envelope.kind]): return _fail(&"event_payload_invalid")
	for key: String in PAYLOAD_KEYS[envelope.kind]:
		var value: Variant = envelope.payload[key]
		if key in ["target_day", "source_day"]:
			if typeof(value) != TYPE_INT or value < 1 or value > 7: return _fail(&"event_payload_invalid")
		elif key == "parameters":
			if not value is Dictionary: return _fail(&"event_payload_invalid")
			for parameter: Variant in value:
				if not _id(parameter) or typeof(value[parameter]) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL]:
					return _fail(&"event_payload_invalid")
		elif not _id(value): return _fail(&"event_payload_invalid")
	# The live token is deliberately not semantic identity. Receipt authentication is
	# delegated to the existing issuer by the application port, not reimplemented here.
	var semantic: Dictionary = envelope.duplicate(true)
	semantic.erase("playback_token")
	var encoded: Dictionary = WRITER.stringify(semantic)
	if not encoded.get("ok", false): return _fail(&"event_not_canonical")
	return {"ok": true, "value": {"semantic": semantic,
		"digest": str(encoded.value).sha256_text()}}

static func match_registration(envelope: Dictionary, record: Variant) -> Dictionary:
	var shaped: Dictionary = inspect(envelope)
	if not shaped.get("ok", false): return shaped
	if not _keys(record, RECORD_KEYS): return _fail(&"event_registration_invalid")
	for key: String in RECORD_KEYS:
		if typeof(envelope[key]) != typeof(record[key]): return _fail(&"event_registration_invalid")
		if envelope[key] != record[key]: return _fail(&"event_registration_mismatch")
	return {"ok": true}

const RECEIPT_KEYS := ["transaction_id", "request_fingerprint", "kind", "source_id", "scene_event"]
const SAVED_EVENT_KEYS := ["schema_version", "semantic", "registration_fingerprint", "reading_anchor", "result"]
const ANCHOR_KEYS := ["session_id", "entry_id", "content_version", "catalogue_fingerprint", "publication_id", "line_id"]
const RESULT_KEYS := ["event_id", "ordinal", "notification"]

static func occurrence_key(source: Dictionary) -> String:
	# IDs can contain colons; a canonical tuple keeps distinct occurrences distinct.
	return str(WRITER.stringify([source.scene_occurrence, source.entry_id]).value)

static func registration_fingerprint(record: Dictionary) -> Dictionary:
	if not _keys(record, RECORD_KEYS): return _fail(&"event_registration_invalid")
	var encoded: Dictionary = WRITER.stringify(record)
	if not encoded.get("ok", false): return _fail(&"event_registration_invalid")
	return {"ok": true, "value": str(encoded.value).sha256_text()}

static func make_receipt(envelope: Dictionary, anchor: Dictionary) -> Dictionary:
	var shaped: Dictionary = inspect(envelope)
	if not shaped.ok: return shaped
	if typeof(envelope.issuer_receipt.get("token")) != TYPE_STRING or envelope.issuer_receipt.get("token") != envelope.command_id:
		return _fail(&"event_issuer_invalid")
	if envelope.kind not in ["notification.set", "notification.clear"]:
		return _fail(&"event_kind_unsupported")
	if not _valid_anchor(anchor, envelope.source): return _fail(&"event_anchor_invalid")
	var record := {}
	for key: String in RECORD_KEYS: record[key] = envelope[key]
	var fingerprint: Dictionary = registration_fingerprint(record)
	if not fingerprint.ok: return fingerprint
	return {"ok": true, "value": {"transaction_id": envelope.command_id,
		"request_fingerprint": shaped.value.digest, "kind": "scene_event",
		"source_id": envelope.source.scene_occurrence, "scene_event": {
			"schema_version": 1, "semantic": shaped.value.semantic,
			"registration_fingerprint": fingerprint.value, "reading_anchor": anchor.duplicate(true),
			"result": {"event_id": envelope.event_id, "ordinal": envelope.ordinal,
				"notification": envelope.payload.duplicate(true) if envelope.kind == "notification.set" else {}}}}}

static func validate_receipts(receipts: Dictionary) -> Dictionary:
	var occurrences := {}
	for command: Variant in receipts:
		var receipt: Variant = receipts[command]
		# The owning Run schema validates legacy variants.
		if not receipt is Dictionary or receipt.get("kind") != "scene_event": continue
		if not _keys(receipt, RECEIPT_KEYS): return _fail(&"event_receipt_invalid")
		if typeof(command) != TYPE_STRING or receipt.transaction_id != command:
			return _fail(&"event_receipt_identity_invalid")
		var saved: Variant = receipt.scene_event
		if not _keys(saved, SAVED_EVENT_KEYS): return _fail(&"event_receipt_invalid")
		if typeof(saved.schema_version) != TYPE_INT or saved.schema_version != 1:
			return _fail(&"event_receipt_invalid")
		if not saved.semantic is Dictionary or saved.semantic.has("playback_token"):
			return _fail(&"event_receipt_invalid")
		var envelope: Dictionary = saved.semantic.duplicate(true)
		envelope["playback_token"] = "receipt.validation"
		if not saved.reading_anchor is Dictionary: return _fail(&"event_anchor_invalid")
		var rebuilt: Dictionary = make_receipt(envelope, saved.reading_anchor)
		if not rebuilt.ok: return rebuilt
		# Canonical comparison checks nested field types as well as values (1 != 1.0).
		var actual: Dictionary = WRITER.stringify(receipt)
		var expected: Dictionary = WRITER.stringify(rebuilt.value)
		if not actual.get("ok", false) or actual.value != expected.value or not _same_types(receipt, rebuilt.value):
			return _fail(&"event_receipt_mismatch")
		var key: String = occurrence_key(envelope.source)
		if not occurrences.has(key):
			occurrences[key] = {"source": envelope.source.duplicate(true), "next_ordinal": 0,
				"predecessor": "", "notification": {}, "receipts": []}
		var group: Dictionary = occurrences[key]
		if group.source != envelope.source: return _fail(&"event_receipt_source_changed")
		if not group.receipts.is_empty():
			var prior_anchor: Dictionary = group.receipts[0].scene_event.reading_anchor
			# Publication and line may advance; the owner binds each to its ledger.
			for field: String in ["session_id", "entry_id", "content_version", "catalogue_fingerprint"]:
				if prior_anchor[field] != saved.reading_anchor[field]: return _fail(&"event_anchor_changed")
		group.receipts.append(receipt.duplicate(true))
	for key: String in occurrences:
		var group: Dictionary = occurrences[key]
		group.receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.scene_event.semantic.ordinal < b.scene_event.semantic.ordinal)
		var seen_events := {}
		for receipt: Dictionary in group.receipts:
			var semantic: Dictionary = receipt.scene_event.semantic
			if semantic.ordinal != group.next_ordinal or semantic.predecessor != group.predecessor \
					or seen_events.has(semantic.event_id): return _fail(&"event_receipt_chain_invalid")
			if semantic.kind == "notification.clear" and group.notification.get("notification_id", "") != semantic.payload.notification_id:
				return _fail(&"event_notification_clear_invalid")
			seen_events[semantic.event_id] = true
			group.notification = receipt.scene_event.result.notification.duplicate(true)
			group.next_ordinal += 1
			group.predecessor = semantic.event_id
	return {"ok": true, "value": {"occurrences": occurrences}}

static func _same_types(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected): return false
	if actual is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in actual:
			if typeof(key) != TYPE_STRING or not expected.has(key) or not _same_types(actual[key], expected[key]): return false
	elif actual is Array:
		if actual.size() != expected.size(): return false
		for index in range(actual.size()):
			if not _same_types(actual[index], expected[index]): return false
	return true

static func _valid_anchor(anchor: Dictionary, source: Dictionary) -> bool:
	if not _keys(anchor, ANCHOR_KEYS): return false
	for key: String in ANCHOR_KEYS:
		if key == "content_version":
			if typeof(anchor[key]) != TYPE_INT or anchor[key] < 1: return false
		elif not _id(anchor[key]): return false
	return anchor.session_id == source.scene_occurrence and anchor.entry_id == source.entry_id \
		and anchor.content_version == source.content_version

static func _id(value: Variant) -> bool:
	# Semantic identifiers, never resource paths or executable snippets. Content text
	# and localized parameters are registry-owned and compared in full at admission.
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 256: return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
				or code in [45, 46, 58, 95]): return false
	return true

static func _keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
