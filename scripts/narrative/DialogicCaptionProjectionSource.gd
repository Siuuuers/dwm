extends RefCounted
class_name DialogicCaptionProjectionSource

var _session_id: StringName = &""
var _language_mode: StringName = &"single"
var _records: Dictionary = {}

func configure(session_id: StringName, language_mode: StringName, event_records: Array) -> Dictionary:
	if session_id == &"" or language_mode not in [&"single", &"dual"]:
		return {"ok": false, "code": &"caption_source_configuration_invalid"}
	var candidate: Dictionary = {}
	for record_value: Variant in event_records:
		if not record_value is Dictionary:
			return {"ok": false, "code": &"caption_event_record_incomplete"}
		var record: Dictionary = record_value
		if not record.has_all(["event_index", "event_kind", "semantic_id"]):
			return {"ok": false, "code": &"caption_event_record_incomplete"}
		var index := int(record.event_index)
		if candidate.has(index) or StringName(record.semantic_id) == &"":
			return {"ok": false, "code": &"caption_event_record_invalid"}
		candidate[index] = record.duplicate(true)
	_session_id = session_id
	_language_mode = language_mode
	_records = candidate
	return {"ok": true, "code": &"caption_source_configured"}

func get_session_projection() -> Dictionary:
	return {"session_id": _session_id, "language_mode": _language_mode}

func project_text(event_index: int, text_info: Dictionary) -> Dictionary:
	var record: Dictionary = _records.get(event_index, {})
	if record.is_empty() or str(record.event_kind) != "text":
		return {"ok": false, "code": &"unknown_caption_event"}
	if not text_info.has("text") or not text_info.has("append"):
		return {"ok": false, "code": &"caption_text_info_incomplete"}
	return {
		"ok": true,
		"code": &"caption_text_projected",
		"append": bool(text_info.append),
		"projection": {
			"session_id": _session_id,
			"semantic_id": StringName(record.semantic_id),
			"primary_text": str(text_info.text),
			"secondary_text": str(text_info.get("secondary_text", "")),
		},
	}
