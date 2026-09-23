class_name NarrativeCaptionRegistry
extends RefCounted
## Explicit semantic registrations for an internal caption stream. No production
## catalog is implied: callers supply the exact authored signature for each beat.
## Prose, DTL location and runtime event indices never establish membership.

const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const FIELDS := ["beat_id", "line_id", "owning_entry_id", "presentation_signature"]

static func validate_document(document: Dictionary, entry_ids: Array) -> Dictionary:
	if not FROZEN._exact(document, ["kind", "schema_version", "beats"]) \
			or document.get("kind") != "narrative_caption_registry" \
			or typeof(document.get("schema_version")) != TYPE_INT or document.schema_version != 1 \
			or not document.get("beats") is Array or document.beats.is_empty():
		return _fail(&"caption_registry_invalid")
	var beats := {}
	var lines := {}
	for row: Variant in document.beats:
		if not valid_beat(row): return _fail(&"caption_registration_invalid")
		if not entry_ids.has(row.owning_entry_id): return _fail(&"caption_entry_unregistered")
		if beats.has(row.beat_id) or lines.has(row.line_id): return _fail(&"caption_registration_duplicate")
		beats[row.beat_id] = true
		lines[row.line_id] = true
	return {"ok": true, "value": document.duplicate(true)}

static func valid_beat(value: Variant) -> bool:
	if not value is Dictionary or not FROZEN._exact(value, FIELDS): return false
	for field: String in ["beat_id", "line_id", "owning_entry_id"]:
		if not value[field] is String or value[field].strip_edges().is_empty(): return false
	return value.presentation_signature is Dictionary and not value.presentation_signature.is_empty() \
		and FROZEN._primitive(value.presentation_signature)

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
