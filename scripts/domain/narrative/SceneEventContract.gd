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
