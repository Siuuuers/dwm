extends RefCounted
## Opt-in fixed authored Solo catalogue and one semantic ledger. No production
## catalogue is loaded implicitly, and the catalogue never executes story code.
const LEDGER := preload("res://scripts/narrative/NarrativeCaptionLedger.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var catalogue: Dictionary = {}
var fingerprint := ""
var registry: Dictionary = {}
var manifest: Dictionary = {}
var ledger: NarrativeCaptionLedger
var command_id := ""
var pre_entry_id := ""
var latest_entry := ""
var boundary := "between_entries"

func configure(document: Dictionary) -> Dictionary:
	if not catalogue.is_empty(): return _fail(&"reading_catalogue_already_configured")
	if not FROZEN._exact(document, ["kind", "schema_version", "entries"]) \
			or document.get("kind") != "solo_reading_catalogue" \
			or typeof(document.get("schema_version")) != TYPE_INT or document.schema_version != 1 \
			or not document.get("entries") is Array or document.entries.size() != 2:
		return _fail(&"reading_catalogue_invalid")
	var compiled := {}
	var beats: Array = []
	var entries: Array = []
	for row: Variant in document.entries:
		if not row is Dictionary or not FROZEN._exact(row, ["entry_id", "content_version", "lines"]) \
				or not row.get("entry_id") is String or not row.entry_id.begins_with("dating.solo.") \
				or typeof(row.get("content_version")) != TYPE_INT or row.content_version <= 0 \
				or not row.get("lines") is Array or row.lines.is_empty() or compiled.has(row.entry_id):
			return _fail(&"reading_catalogue_invalid")
		for line: Variant in row.lines:
			if not line is Dictionary or not FROZEN._exact(line, ["beat_id", "line_id", "text", "revision"]):
				return _fail(&"reading_catalogue_invalid")
			for field: String in ["beat_id", "line_id", "text", "revision"]:
				if not line[field] is String or line[field].strip_edges().is_empty():
					return _fail(&"reading_catalogue_invalid")
			beats.append({"beat_id": line.beat_id, "line_id": line.line_id,
				"owning_entry_id": row.entry_id, "presentation_signature": {
					"content_revision": line.revision, "variant_id": line.beat_id}})
		compiled[row.entry_id] = row.duplicate(true)
		entries.append({"entry_id": row.entry_id})
	var first: String = document.entries[0].entry_id
	if not first.ends_with(".pre_challenge") \
			or document.entries[1].entry_id != first.trim_suffix(".pre_challenge") + ".post_challenge":
		return _fail(&"reading_catalogue_invalid")
	var registered := {"kind": "narrative_caption_registry", "schema_version": 1, "beats": beats}
	var entry_manifest := {"entries": entries}
	var checked := preload("res://scripts/narrative/DialogicEntryManifest.gd").validate_caption_registry(entry_manifest, registered)
	if not checked.ok: return checked
	var encoded := JSON_WRITER.stringify(document)
	if not encoded.ok: return encoded
	catalogue = compiled
	registry = registered
	manifest = entry_manifest
	fingerprint = str(encoded.value).sha256_text()
	return {"ok": true}

func begin(completion_transaction_id: String, pre_entry: String) -> Dictionary:
	if ledger != null: return _fail(&"reading_session_already_initialized")
	if completion_transaction_id.is_empty() or not catalogue.has(pre_entry) \
			or not pre_entry.ends_with(".pre_challenge"):
		return _fail(&"reading_session_invalid")
	var candidate := LEDGER.new()
	var context := {"completion_transaction_id": completion_transaction_id, "pre_entry_id": pre_entry}
	var initialized := candidate.initialize(completion_transaction_id, context, manifest, registry, true)
	if not initialized.ok: return initialized
	command_id = completion_transaction_id
	pre_entry_id = pre_entry
	ledger = candidate
	return {"ok": true}

func admit(entry_id: String, context: Dictionary) -> Dictionary:
	if ledger == null or not catalogue.has(entry_id): return _fail(&"reading_session_unavailable")
	if not _context_shape(context): return _fail(&"reading_context_invalid")
	var checked := FROZEN.validate(entry_id, context.presentation)
	if not checked.ok: return checked
	if context.get("expected_stage") != entry_id.get_slice(".", 4) \
			or context.get("transaction_id") != command_id + ":" + str(context.get("expected_stage")):
		return _fail(&"reading_context_invalid")
	var admitted := ledger.admit_entry_context(command_id, entry_id, context)
	if not admitted.ok: return admitted
	latest_entry = entry_id
	boundary = "line"
	return {"ok": true}

func completed(entry_id: String) -> void:
	if latest_entry == entry_id: boundary = "between_entries"

func capture(frontier: Dictionary) -> Dictionary:
	if ledger == null or latest_entry.is_empty(): return _fail(&"reading_session_unavailable")
	var saved := {"schema_version": 1, "catalogue_fingerprint": fingerprint,
		"boundary": boundary, "ledger": ledger.snapshot(), "frontier": frontier.duplicate(true)}
	var checked := validate_saved(saved, latest_entry)
	return {"ok": true, "value": saved} if checked.ok else checked

## Validates the full fixed-prose sequence before a fresh candidate is installed.
func validate_saved(saved: Dictionary, entry_id: String) -> Dictionary:
	if not FROZEN._exact(saved, ["schema_version", "catalogue_fingerprint", "boundary", "ledger", "frontier"]) \
			or typeof(saved.get("schema_version")) != TYPE_INT or saved.schema_version != 1 \
			or not saved.get("catalogue_fingerprint") is String \
			or not saved.get("boundary") is String or saved.boundary not in ["line", "between_entries"] \
			or not saved.get("ledger") is Dictionary or not saved.get("frontier") is Dictionary:
		return _fail(&"reading_checkpoint_invalid")
	if saved.catalogue_fingerprint != fingerprint: return _fail(&"reading_catalogue_mismatch")
	var source: Dictionary = saved.ledger
	if not source.get("frozen_context") is Dictionary \
			or not FROZEN._exact(source.frozen_context, ["completion_transaction_id", "pre_entry_id"]) \
			or not source.frozen_context.get("completion_transaction_id") is String \
			or source.frozen_context.completion_transaction_id.is_empty() \
			or not source.frozen_context.get("pre_entry_id") is String \
			or not catalogue.has(source.frozen_context.pre_entry_id) \
			or not source.frozen_context.pre_entry_id.ends_with(".pre_challenge") \
			or not source.get("entry_contexts") is Dictionary or not catalogue.has(entry_id):
		return _fail(&"reading_checkpoint_invalid")
	var candidate := LEDGER.new()
	var restored := candidate.restore_snapshot(source.frozen_context.completion_transaction_id,
		source.frozen_context, manifest, registry, source, source.entry_contexts, true)
	if not restored.ok: return restored
	if not source.entry_contexts.has(entry_id): return _fail(&"reading_context_invalid")
	for key: Variant in source.entry_contexts:
		var context: Dictionary = source.entry_contexts[key]
		if not _context_shape(context): return _fail(&"reading_context_invalid")
		var checked := FROZEN.validate(key, context.presentation)
		if not checked.ok: return checked
		if context.get("expected_stage") != str(key).get_slice(".", 4) \
				or context.get("transaction_id") != str(source.frozen_context.completion_transaction_id) + ":" + str(context.get("expected_stage")):
			return _fail(&"reading_context_invalid")
	var expected: Array = []
	for entry: Dictionary in manifest.entries:
		for line: Dictionary in catalogue[entry.entry_id].lines:
			expected.append({"entry_id": entry.entry_id, "line_id": line.line_id})
	if source.captions.is_empty() or source.captions.size() > expected.size(): return _fail(&"reading_sequence_invalid")
	for index: int in source.captions.size():
		var beat: Dictionary = source.captions[index].beat
		if beat.owning_entry_id != expected[index].entry_id or beat.line_id != expected[index].line_id:
			return _fail(&"reading_sequence_invalid")
	var tail: Dictionary = source.captions.back()
	if tail.beat.owning_entry_id != entry_id: return _fail(&"reading_frontier_invalid")
	if saved.boundary == "line":
		if not FROZEN._exact(saved.frontier, ["line_id", "publication_id"]) \
				or saved.frontier.get("line_id") != tail.beat.line_id \
				or saved.frontier.get("publication_id") != tail.publication_id:
			return _fail(&"reading_frontier_invalid")
	else:
		if not saved.frontier.is_empty() or tail.beat.line_id != catalogue[entry_id].lines.back().line_id:
			return _fail(&"reading_frontier_invalid")
	return {"ok": true, "value": candidate}

func restore(saved: Dictionary, entry_id: String) -> Dictionary:
	var checked := validate_saved(saved, entry_id)
	if not checked.ok: return checked
	ledger = checked.value
	command_id = saved.ledger.frozen_context.completion_transaction_id
	pre_entry_id = saved.ledger.frozen_context.pre_entry_id
	latest_entry = entry_id
	boundary = saved.boundary
	return {"ok": true}

func project(frontier: Dictionary) -> Dictionary:
	var captured := capture(frontier)
	if not captured.ok: return captured
	var rows: Array[Dictionary] = []
	for row: Dictionary in captured.value.ledger.captions:
		for line: Dictionary in catalogue[row.beat.owning_entry_id].lines:
			if line.line_id == row.beat.line_id:
				rows.append({"publication_id": row.publication_id, "beat_id": row.beat.beat_id,
					"line_id": line.line_id, "entry_id": row.beat.owning_entry_id, "text": line.text})
	return {"ok": true, "value": {"captions": rows, "frontier": frontier.duplicate(true), "session_id": command_id}}

static func _context_shape(context: Dictionary) -> bool:
	return FROZEN._exact(context, ["expected_stage", "playback_id", "role", "transaction_id", "presentation"]) \
		and context.get("role") == "dating_phase" and context.get("playback_id") is String \
		and not str(context.playback_id).is_empty() and context.get("presentation") is Dictionary

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": ""}
