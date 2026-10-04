extends RefCounted
## Finite noncanonical selector admission for the first Solo pre/post pair.
## This compiler owns no live state, ledger, native event or reached receipt.

const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PRE_ENTRY := "dating.solo.priscilla.day1.pre_challenge"
const POST_ENTRY := "dating.solo.priscilla.day1.post_challenge"
const PRE_SELECTORS := ["entry_id", "entry_role", "day", "friend_id", "challenge_slot",
	"phase", "tier", "tone", "attitude", "due_echoes", "attempt_residue_id"]
const POST_SELECTORS := ["entry_id", "entry_role", "day", "friend_id", "challenge_slot",
	"phase", "tier", "tone", "attitude", "due_echoes", "attempt_residue_id",
	"board_result", "perfect_reasons", "relationship_outcome"]

static func compile(document: Dictionary) -> Dictionary:
	if not FROZEN._exact(document, ["kind", "schema_version", "entries"]) \
			or document.get("kind") != "solo_reading_catalogue" \
			or typeof(document.get("schema_version")) != TYPE_INT or document.schema_version != 2 \
			or not document.get("entries") is Array or document.entries.size() != 2:
		return _fail(&"reading_catalogue_invalid")
	var entries := {}
	var identity_lines := {}
	var identity_beats := {}
	var descriptor_text := {}
	for index: int in 2:
		var row: Variant = document.entries[index]
		var expected: String = PRE_ENTRY if index == 0 else POST_ENTRY
		if not row is Dictionary or not FROZEN._exact(row,
				["entry_id", "content_version", "selector_fields", "variants"]) \
				or row.get("entry_id") != expected \
				or typeof(row.get("content_version")) != TYPE_INT or row.content_version <= 0 \
				or not row.get("variants") is Array or row.variants.is_empty() \
				or not _same_fields(row.get("selector_fields"),
					PRE_SELECTORS if index == 0 else POST_SELECTORS):
			return _fail(&"reading_catalogue_invalid")
		var schema := FROZEN.schema_for_entry(expected)
		if not schema.ok: return schema
		var projections := {}
		var labels := {}
		for variant: Variant in row.variants:
			if not variant is Dictionary or not FROZEN._exact(variant, ["selector_values", "label", "lines"]) \
					or not variant.get("selector_values") is Dictionary \
					or not FROZEN._exact(variant.selector_values, row.selector_fields) \
					or not _identifier(variant.get("label")) \
					or not variant.get("lines") is Array or variant.lines.is_empty():
				return _fail(&"reading_catalogue_invalid")
			var selectors: Dictionary = variant.selector_values
			if not FROZEN._primitive(selectors): return _fail(&"reading_selector_invalid")
			for field: String in row.selector_fields:
				if not FROZEN._field(selectors[field], schema.value.fields[field]):
					return _fail(&"reading_selector_invalid")
			var bound := FROZEN._bindings(expected, selectors)
			if not bound.ok: return bound
			var encoded := WRITER.stringify(selectors)
			if not encoded.ok: return encoded
			if projections.has(encoded.value): return _fail(&"reading_selector_ambiguous")
			# A native label has one fixed programme. Separate selector rows may
			# reuse it only when their complete authored line programmes agree.
			if labels.has(variant.label) and labels[variant.label] != variant.lines:
				return _fail(&"reading_label_conflict")
			projections[encoded.value] = true
			labels[variant.label] = variant.lines
			var local_lines := {}
			var local_beats := {}
			for line: Variant in variant.lines:
				if not line is Dictionary or not FROZEN._exact(line,
						["beat_id", "line_id", "text", "revision", "variant_id", "selector_fields"]):
					return _fail(&"reading_catalogue_invalid")
				for field: String in ["beat_id", "line_id", "text", "revision", "variant_id"]:
					if not _identifier(line[field]): return _fail(&"reading_catalogue_invalid")
				if not _subset_fields(line.selector_fields, row.selector_fields):
					return _fail(&"reading_selector_invalid")
				if local_lines.has(line.line_id) or local_beats.has(line.beat_id):
					return _fail(&"reading_catalogue_invalid")
				local_lines[line.line_id] = true
				local_beats[line.beat_id] = true
				var line_owner := {"entry_id": expected, "beat_id": line.beat_id}
				var beat_owner := {"entry_id": expected, "line_id": line.line_id}
				if (identity_lines.has(line.line_id) and identity_lines[line.line_id] != line_owner) \
						or (identity_beats.has(line.beat_id) and identity_beats[line.beat_id] != beat_owner):
					return _fail(&"reading_identity_conflict")
				identity_lines[line.line_id] = line_owner
				identity_beats[line.beat_id] = beat_owner
				var descriptor := _descriptor(expected, line, selectors)
				var key := WRITER.stringify(descriptor)
				if not key.ok: return key
				if descriptor_text.has(key.value) and descriptor_text[key.value] != line.text:
					return _fail(&"reading_variant_text_conflict")
				descriptor_text[key.value] = line.text
		entries[expected] = row.duplicate(true)
	return {"ok": true, "value": {"entries": entries}}

## Resolve only an independently admitted canonical frame. Missing rows refuse;
## no wildcard/default, runtime rescan or invented post-board fact is permitted.
static func select(entry: Dictionary, presentation: Dictionary) -> Dictionary:
	var entry_id: Variant = entry.get("entry_id")
	if not entry_id is String or entry_id not in [PRE_ENTRY, POST_ENTRY] \
			or not entry.get("variants") is Array \
			or not _same_fields(entry.get("selector_fields"),
				PRE_SELECTORS if entry_id == PRE_ENTRY else POST_SELECTORS):
		return _fail(&"reading_catalogue_invalid")
	var validated := FROZEN.validate(entry_id, presentation)
	if not validated.ok: return validated
	var selectors := _project(validated.value.fields, entry.selector_fields)
	var chosen := {}
	for variant: Dictionary in entry.variants:
		if variant.selector_values == selectors:
			if not chosen.is_empty(): return _fail(&"reading_selector_ambiguous")
			chosen = variant
	if chosen.is_empty(): return _fail(&"reading_selector_unavailable")
	var beats: Array = []
	for line: Dictionary in chosen.lines:
		beats.append(_descriptor(entry_id, line, selectors))
	return {"ok": true, "value": {"entry_id": entry_id, "content_version": entry.content_version,
		"label": chosen.label, "lines": chosen.lines.duplicate(true), "beats": beats,
		"selectors": selectors}}

static func _descriptor(entry_id: String, line: Dictionary, selectors: Dictionary) -> Dictionary:
	return {"beat_id": line.beat_id, "line_id": line.line_id, "owning_entry_id": entry_id,
		"presentation_signature": {"content_revision": line.revision, "variant_id": line.variant_id,
			"selectors": _project(selectors, line.selector_fields)}}

static func _project(fields: Dictionary, names: Array) -> Dictionary:
	var result := {}
	for field: String in names: result[field] = fields[field]
	return result.duplicate(true)

static func _same_fields(value: Variant, expected: Array) -> bool:
	return value is Array and value.size() == expected.size() and _subset_fields(value, expected)

static func _subset_fields(value: Variant, allowed: Array) -> bool:
	if not value is Array: return false
	var seen := {}
	for field: Variant in value:
		if not field is String or not allowed.has(field) or seen.has(field): return false
		seen[field] = true
	return true

static func _identifier(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": ""}
