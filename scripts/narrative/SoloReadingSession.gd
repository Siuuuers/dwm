extends RefCounted
## Opt-in Solo, Hospital or ordered-ending catalogue and one semantic ledger. No production
## catalogue is loaded implicitly, and the catalogue never executes story code.
const LEDGER := preload("res://scripts/narrative/NarrativeCaptionLedger.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const AUTHORED := preload("res://scripts/narrative/SoloReadingCatalogue.gd")
const TRAVERSAL := preload("res://scripts/narrative/ReadingTraversalOperation.gd")

var catalogue: Dictionary = {}
var catalogue_schema_version := 1
var family := "solo"
var _selected_entries: Dictionary = {}
var fingerprint := ""
var registry: Dictionary = {}
var manifest: Dictionary = {}
var ledger: NarrativeCaptionLedger
var command_id := ""
var pre_entry_id := ""
var latest_entry := ""
var boundary := "between_entries"
var _caption_variants_by_line: Dictionary = {}
var next_operation: Dictionary = {}

func configure(document: Dictionary) -> Dictionary:
	if not catalogue.is_empty(): return _fail(&"reading_catalogue_already_configured")
	if typeof(document.get("schema_version")) == TYPE_INT and document.schema_version == 2:
		var authored := AUTHORED.compile(document)
		if not authored.ok: return authored
		var encoded := JSON_WRITER.stringify(document)
		if not encoded.ok: return encoded
		catalogue = authored.value.entries
		catalogue_schema_version = 2
		manifest = {"entries": []}
		for entry: Dictionary in document.entries:
			manifest.entries.append({"entry_id": entry.entry_id})
		FROZEN._freeze(catalogue)
		fingerprint = str(encoded.value).sha256_text()
		return {"ok": true}
	var hospital: bool = document.get("kind") == "hospital_reading_catalogue"
	var ending: bool = document.get("kind") == "ending_reading_catalogue"
	if not FROZEN._exact(document, ["kind", "schema_version", "entries"]) \
			or document.get("kind") not in ["solo_reading_catalogue", "hospital_reading_catalogue", "ending_reading_catalogue"] \
			or typeof(document.get("schema_version")) != TYPE_INT or document.schema_version != 1 \
			or not document.get("entries") is Array or document.entries.is_empty() \
			or (not ending and document.entries.size() != (1 if hospital else 2)):
		return _fail(&"reading_catalogue_invalid")
	var compiled := {}
	var beats: Array = []
	var entries: Array = []
	for row: Variant in document.entries:
		if not row is Dictionary or not FROZEN._exact(row, ["entry_id", "content_version", "lines"]) \
				or not row.get("entry_id") is String \
				or (not _ending_entry(row.entry_id) if ending else (not _hospital_entry(row.entry_id) if hospital else not row.entry_id.begins_with("dating.solo."))) \
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
	if not hospital and not ending and (not first.ends_with(".pre_challenge") \
			or document.entries[1].entry_id != first.trim_suffix(".pre_challenge") + ".post_challenge"):
		return _fail(&"reading_catalogue_invalid")
	var registered := {"kind": "narrative_caption_registry", "schema_version": 1, "beats": beats}
	var entry_manifest := {"entries": entries}
	var checked := preload("res://scripts/narrative/DialogicEntryManifest.gd").validate_caption_registry(entry_manifest, registered)
	if not checked.ok: return checked
	var encoded := JSON_WRITER.stringify(document)
	if not encoded.ok: return encoded
	catalogue = compiled
	family = "ending" if ending else ("hospital" if hospital else "solo")
	registry = registered
	# This index carries authored identity only; causal entry frames and publication
	# IDs establish ownership of an occurrence without making it another variant.
	FROZEN._freeze(registry)
	for beat: Dictionary in registry.beats:
		_caption_variants_by_line[beat.line_id] = beat
	manifest = entry_manifest
	fingerprint = str(encoded.value).sha256_text()
	return {"ok": true}

func begin(completion_transaction_id: String, pre_entry: String) -> Dictionary:
	if ledger != null: return _fail(&"reading_session_already_initialized")
	if completion_transaction_id.is_empty() or not catalogue.has(pre_entry) \
			or (pre_entry != manifest.entries[0].entry_id if family == "ending" else (not _hospital_entry(pre_entry) if family == "hospital" else not pre_entry.ends_with(".pre_challenge"))):
		return _fail(&"reading_session_invalid")
	var candidate := LEDGER.new()
	var context := _session_context(completion_transaction_id, pre_entry)
	# A selector catalogue has no chosen caption registration until its real
	# phase frame exists. The retained ledger object is initialized on admission.
	if catalogue_schema_version == 1:
		var initialized := candidate.initialize(completion_transaction_id, context, manifest, registry, true)
		if not initialized.ok: return initialized
	command_id = completion_transaction_id
	pre_entry_id = pre_entry
	ledger = candidate
	return {"ok": true}

func admit(entry_id: String, context: Dictionary) -> Dictionary:
	if ledger == null or not catalogue.has(entry_id): return _fail(&"reading_session_unavailable")
	var checked := _validate_frame(entry_id, context, command_id)
	if not checked.ok: return checked
	if family == "ending":
		var index := _entry_index(entry_id)
		if latest_entry.is_empty():
			if index != 0: return _fail(&"reading_context_invalid")
		elif latest_entry == entry_id and boundary == "between_entries":
			return _fail(&"reading_context_invalid")
		elif latest_entry != entry_id:
			if boundary != "between_entries" or index != _entry_index(latest_entry) + 1:
				return _fail(&"reading_context_invalid")
			var preceding := capture({})
			if not preceding.ok: return preceding
	if catalogue_schema_version == 2:
		var selected := _admit_authored(entry_id, context)
		if not selected.ok: return selected
	else:
		var admitted := ledger.admit_entry_context(command_id, entry_id, context)
		if not admitted.ok: return admitted
	# A successful physical handoff has already checkpointed the preceding
	# operation. The next independently admitted frame starts a fresh frontier.
	if latest_entry != entry_id: next_operation = {}
	latest_entry = entry_id
	boundary = "line"
	return {"ok": true}

func completed(entry_id: String) -> void:
	if latest_entry == entry_id:
		if not next_operation.is_empty() and (next_operation.phase != "destination" \
				or next_operation.plan.destination.kind != "completion"):
			next_operation = {}
		boundary = "between_entries"

## A registered descriptor is available only for the admitted, published tail.
## Hot acknowledgement checks never copy the retained History or scan prose.
func current_caption_variant(entry_id: String, frontier: Dictionary) -> Dictionary:
	if ledger == null or boundary != "line" or latest_entry != entry_id \
			or not ledger.is_current_occurrence(command_id, entry_id, frontier):
		return _fail(&"reading_frontier_unavailable")
	var beat: Dictionary = _caption_variants_by_line.get(frontier.line_id, {})
	if beat.is_empty() or beat.owning_entry_id != entry_id:
		return _fail(&"reading_frontier_unavailable")
	return {"ok": true, "value": beat.duplicate(true)}

func capture(frontier: Dictionary) -> Dictionary:
	if ledger == null or latest_entry.is_empty(): return _fail(&"reading_session_unavailable")
	var saved := {"schema_version": 1, "catalogue_fingerprint": fingerprint,
		"boundary": boundary, "ledger": ledger.snapshot(), "frontier": frontier.duplicate(true)}
	if family in ["hospital", "ending"]:
		if not next_operation.is_empty(): return _fail(&"reading_next_unavailable")
		saved.schema_version = 3
		saved["family"] = family
	elif not next_operation.is_empty():
		saved.schema_version = 2
		saved["next_operation"] = next_operation.duplicate(true)
	var checked := validate_saved(saved, latest_entry)
	return {"ok": true, "value": saved} if checked.ok else checked

## Validates the full fixed-prose sequence before a fresh candidate is installed.
func validate_saved(saved: Dictionary, entry_id: String) -> Dictionary:
	if family in ["hospital", "ending"]: return _validate_base_saved(saved, entry_id)
	if typeof(saved.get("schema_version")) == TYPE_INT and saved.schema_version == 2:
		var operation := TRAVERSAL.validate(saved, entry_id)
		if not operation.ok: return operation
		# Admit both ends, including the source record's not-yet-traversed plan,
		# against the actual complete registered programme. No valid prefix can
		# hide a forged future variant or a missing intermediate caption.
		for phase: String in ["source", "destination"]:
			var projected := TRAVERSAL.project(operation.value.plan, phase)
			if not projected.ok: return projected
			var endpoint := _validate_base_saved(TRAVERSAL.without_operation(projected.value), entry_id)
			if not endpoint.ok: return endpoint
		return _validate_base_saved(TRAVERSAL.without_operation(saved), entry_id)
	return _validate_base_saved(saved, entry_id)

func _validate_base_saved(saved: Dictionary, entry_id: String) -> Dictionary:
	var fields := ["schema_version", "catalogue_fingerprint", "boundary", "ledger", "frontier"]
	if family in ["hospital", "ending"]: fields.append("family")
	if not FROZEN._exact(saved, fields) \
			or typeof(saved.get("schema_version")) != TYPE_INT or saved.schema_version != (3 if family in ["hospital", "ending"] else 1) \
			or (family in ["hospital", "ending"] and (not saved.get("family") is String or saved.family != family)) \
			or not saved.get("catalogue_fingerprint") is String \
			or not saved.get("boundary") is String or saved.boundary not in ["line", "between_entries"] \
			or not saved.get("ledger") is Dictionary or not saved.get("frontier") is Dictionary:
		return _fail(&"reading_checkpoint_invalid")
	if saved.catalogue_fingerprint != fingerprint: return _fail(&"reading_catalogue_mismatch")
	var source: Dictionary = saved.ledger
	if not source.get("frozen_context") is Dictionary \
			or not source.frozen_context.get("completion_transaction_id") is String \
			or source.frozen_context.completion_transaction_id.is_empty() \
			or not source.get("entry_contexts") is Dictionary or not catalogue.has(entry_id):
		return _fail(&"reading_checkpoint_invalid")
	var first: Variant = source.frozen_context.get("entry_id" if family in ["hospital", "ending"] else "pre_entry_id")
	if not first is String or not catalogue.has(first) \
			or (first != manifest.entries[0].entry_id if family == "ending" else (not _hospital_entry(first) if family == "hospital" else not first.ends_with(".pre_challenge"))) \
			or source.frozen_context != _session_context(source.frozen_context.completion_transaction_id, first):
		return _fail(&"reading_checkpoint_invalid")
	if family == "hospital" and (first != entry_id or not FROZEN._exact(source.entry_contexts, [entry_id])):
		return _fail(&"reading_context_invalid")
	if family == "ending":
		var expected_frames: Array = []
		for index: int in range(_entry_index(entry_id) + 1):
			expected_frames.append(manifest.entries[index].entry_id)
		if not FROZEN._exact(source.entry_contexts, expected_frames): return _fail(&"reading_context_invalid")
	var programs := _programs_for_frames(source.entry_contexts, source.frozen_context.completion_transaction_id)
	if not programs.ok: return programs
	if not source.entry_contexts.has(entry_id): return _fail(&"reading_context_invalid")
	if catalogue_schema_version == 2:
		var expected_frames := [pre_entry_for(entry_id)]
		if entry_id.ends_with(".post_challenge"): expected_frames.append(entry_id)
		if not FROZEN._exact(source.entry_contexts, expected_frames): return _fail(&"reading_context_invalid")
	var candidate := LEDGER.new()
	var restored := candidate.restore_snapshot(source.frozen_context.completion_transaction_id,
		source.frozen_context, manifest, programs.value.registry, source, source.entry_contexts, true)
	if not restored.ok: return restored
	var expected: Array = []
	for entry: Dictionary in manifest.entries:
		if not programs.value.entries.has(entry.entry_id): continue
		for line: Dictionary in programs.value.entries[entry.entry_id].lines:
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
		if not saved.frontier.is_empty() or tail.beat.line_id != programs.value.entries[entry_id].lines.back().line_id:
			return _fail(&"reading_frontier_invalid")
	return {"ok": true, "value": candidate, "programs": programs.value.entries, "registry": programs.value.registry}

func restore(saved: Dictionary, entry_id: String) -> Dictionary:
	var checked := validate_saved(saved, entry_id)
	if not checked.ok: return checked
	ledger = checked.value
	if catalogue_schema_version == 2: _install_programs(checked.programs, checked.registry)
	command_id = saved.ledger.frozen_context.completion_transaction_id
	pre_entry_id = saved.ledger.frozen_context.get("entry_id" if family in ["hospital", "ending"] else "pre_entry_id")
	latest_entry = entry_id
	boundary = saved.boundary
	next_operation = saved.get("next_operation", {}).duplicate(true)
	return {"ok": true}

## Build one detached, exact route suffix. The live ledger and Profile are never
## changed by planning. Only the caller's validated exact-membership query may
## authorize silent traversal; the first unseen caption becomes the destination.
func prepare_next(frontier: Dictionary, is_witnessed: Callable) -> Dictionary:
	if family != "solo" or not is_witnessed.is_valid() or boundary != "line": return _fail(&"reading_next_unavailable")
	var source := capture(frontier)
	if not source.ok: return source
	var lines: Array = entry_program(latest_entry).value.lines
	var index := -1
	for ordinal: int in lines.size():
		if lines[ordinal].line_id == frontier.line_id: index = ordinal
	if index < 0: return _fail(&"reading_frontier_invalid")
	var retained: Dictionary = source.value.ledger
	var candidate := LEDGER.new()
	var copied := candidate.restore_snapshot(command_id, retained.frozen_context, manifest,
		registry, retained, retained.entry_contexts, true)
	if not copied.ok: return copied
	var traversed: Array = []
	var destination := {"kind": "completion", "caption": null}
	for ordinal: int in range(index + 1, lines.size()):
		var variant: Dictionary = _caption_variants_by_line[lines[ordinal].line_id]
		var witnessed: Variant = is_witnessed.call(variant.duplicate(true))
		if typeof(witnessed) != TYPE_BOOL: return _fail(&"reading_next_witness_invalid")
		var allocation := candidate.allocate_publication(command_id, latest_entry)
		if not allocation.ok: return allocation
		var published := candidate.publish_caption(command_id, allocation.value, variant)
		if not published.ok: return published
		var row := {"publication_id": allocation.value, "beat": variant.duplicate(true)}
		if not witnessed:
			destination = {"kind": "line", "caption": row}
			break
		traversed.append(row)
	var plan := {"entry_id": latest_entry, "catalogue_fingerprint": fingerprint,
		"source_ledger": retained.duplicate(true), "source_frontier": frontier.duplicate(true),
		"traversed_captions": traversed, "destination": destination}
	var checked := TRAVERSAL.create(plan, "source")
	return {"ok": true, "value": plan} if checked.ok else checked

func project(frontier: Dictionary) -> Dictionary:
	var captured := capture(frontier)
	if not captured.ok: return captured
	var rows: Array[Dictionary] = []
	for row: Dictionary in captured.value.ledger.captions:
		for line: Dictionary in entry_program(row.beat.owning_entry_id).value.lines:
			if line.line_id == row.beat.line_id:
				rows.append({"publication_id": row.publication_id, "beat_id": row.beat.beat_id,
					"line_id": line.line_id, "entry_id": row.beat.owning_entry_id, "text": line.text})
	return {"ok": true, "value": {"captions": rows, "frontier": frontier.duplicate(true), "session_id": command_id}}

## Resolve from a supplied canonical frame before native playback, or return the
## already admitted programme. No mutable gameplay reads or future defaults.
func entry_program(entry_id: String, context: Dictionary = {}) -> Dictionary:
	if not catalogue.has(entry_id): return _fail(&"reading_entry_unavailable")
	if catalogue_schema_version == 1:
		var row: Dictionary = catalogue[entry_id].duplicate(true)
		row["label"] = entry_id
		return {"ok": true, "value": row}
	if not context.is_empty():
		if not _context_shape(context): return _fail(&"reading_context_invalid")
		return AUTHORED.select(catalogue[entry_id], context.presentation)
	if not _selected_entries.has(entry_id): return _fail(&"reading_context_unavailable")
	return {"ok": true, "value": _selected_entries[entry_id].duplicate(true)}

func _programs_for_frames(frames: Dictionary, transaction_id: String) -> Dictionary:
	var selected := {}
	var beats: Array = []
	for key: Variant in frames:
		if not key is String or not catalogue.has(key) or not frames[key] is Dictionary:
			return _fail(&"reading_context_invalid")
		var context: Dictionary = frames[key]
		var checked := _validate_frame(key, context, transaction_id)
		if not checked.ok: return checked
		var programme := entry_program(key, context)
		if not programme.ok: return programme
		selected[key] = programme.value
	if catalogue_schema_version == 1:
		for key: String in catalogue: selected[key] = entry_program(key).value
		return {"ok": true, "value": {"entries": selected, "registry": registry}}
	for entry: Dictionary in manifest.entries:
		if selected.has(entry.entry_id): beats.append_array(selected[entry.entry_id].beats)
	var registered := {"kind": "narrative_caption_registry", "schema_version": 1, "beats": beats}
	var checked := preload("res://scripts/narrative/DialogicEntryManifest.gd").validate_caption_registry(manifest, registered)
	if not checked.ok: return checked
	return {"ok": true, "value": {"entries": selected, "registry": registered}}

func _admit_authored(entry_id: String, context: Dictionary) -> Dictionary:
	var source: Dictionary = ledger.snapshot()
	if _selected_entries.is_empty():
		if entry_id != pre_entry_id: return _fail(&"reading_context_invalid")
		source = {"session_token": command_id, "frozen_context": {
			"completion_transaction_id": command_id, "pre_entry_id": pre_entry_id},
			"entry_contexts": {}, "captions": []}
	elif source.entry_contexts.has(entry_id):
		if latest_entry != entry_id: return _fail(&"reading_context_invalid")
		return {"ok": true} if source.entry_contexts[entry_id] == context else _fail(&"caption_entry_context_conflict")
	elif entry_id != pre_entry_id.trim_suffix(".pre_challenge") + ".post_challenge" \
			or latest_entry != pre_entry_id or boundary != "between_entries":
		return _fail(&"reading_context_invalid")
	else:
		var completed_source := capture({})
		if not completed_source.ok: return completed_source
	var frames: Dictionary = source.entry_contexts.duplicate(true)
	frames[entry_id] = context.duplicate(true)
	var programs := _programs_for_frames(frames, command_id)
	if not programs.ok: return programs
	source.entry_contexts = frames
	var candidate := LEDGER.new()
	var copied := candidate.restore_snapshot(command_id, source.frozen_context, manifest,
		programs.value.registry, source, frames, true)
	if not copied.ok: return copied
	# Install the whole candidate only after existing History and the new phase
	# are both admitted. The departing phase has no active native publication.
	ledger = candidate
	_install_programs(programs.value.entries, programs.value.registry)
	return {"ok": true}

func _install_programs(entries: Dictionary, registered: Dictionary) -> void:
	_selected_entries = entries.duplicate(true)
	registry = registered.duplicate(true)
	FROZEN._freeze(_selected_entries)
	FROZEN._freeze(registry)
	_caption_variants_by_line = {}
	for beat: Dictionary in registry.beats: _caption_variants_by_line[beat.line_id] = beat

static func pre_entry_for(entry_id: String) -> String:
	return entry_id.trim_suffix(".post_challenge") + ".pre_challenge" if entry_id.ends_with(".post_challenge") else entry_id

static func _context_shape(context: Dictionary) -> bool:
	return FROZEN._exact(context, ["expected_stage", "playback_id", "role", "transaction_id", "presentation"]) \
		and context.get("role") == "dating_phase" and context.get("playback_id") is String \
		and not str(context.playback_id).is_empty() and context.get("presentation") is Dictionary

func _session_context(completion_transaction_id: String, first_entry: String) -> Dictionary:
	if family in ["hospital", "ending"]:
		return {"family": family, "completion_transaction_id": completion_transaction_id, "entry_id": first_entry}
	return {"completion_transaction_id": completion_transaction_id, "pre_entry_id": first_entry}

func _validate_frame(entry_id: String, context: Dictionary, completion_transaction_id: String) -> Dictionary:
	if family == "ending":
		if not FROZEN._exact(context, ["expected_stage", "playback_id", "role", "transaction_id", "presentation"]) \
				or context.get("expected_stage") != "PRIMARY_PENDING" \
				or context.get("role") not in ["special_prefix", "core", "pair_coda", "observer_coda"] \
				or context.get("playback_id") != "%s:%d" % [completion_transaction_id, _entry_index(entry_id)] \
				or context.get("transaction_id") != str(context.playback_id) + ":complete" \
				or not context.get("presentation") is Dictionary:
			return _fail(&"reading_context_invalid")
		var ending := FROZEN.validate(entry_id, context.presentation)
		if not ending.ok: return ending
		if ending.value.fields.step_token != context.playback_id or ending.value.fields.ending_role != context.role:
			return _fail(&"reading_context_invalid")
		return {"ok": true}
	if family == "hospital":
		if not FROZEN._exact(context, ["expected_stage", "playback_id", "role", "transaction_id", "presentation"]) \
				or context.get("role") != "hospital" or not context.get("playback_id") is String \
				or not str(context.playback_id).ends_with(":hospital") \
				or str(context.playback_id).trim_suffix(":hospital").strip_edges().is_empty() \
				or not context.get("presentation") is Dictionary:
			return _fail(&"reading_context_invalid")
	elif not _context_shape(context):
		return _fail(&"reading_context_invalid")
	var checked := FROZEN.validate(entry_id, context.presentation)
	if not checked.ok: return checked
	var stage := "hospital" if family == "hospital" else entry_id.get_slice(".", 4)
	if context.get("expected_stage") != stage or context.get("transaction_id") != completion_transaction_id + ":" + stage:
		return _fail(&"reading_context_invalid")
	if family == "hospital" and checked.value.fields.qualifying_cause != "schedule_done":
		return _fail(&"reading_context_invalid")
	return {"ok": true}

func _entry_index(entry_id: String) -> int:
	for index: int in manifest.entries.size():
		if manifest.entries[index].entry_id == entry_id: return index
	return -1

static func _ending_entry(entry_id: String) -> bool:
	return entry_id.begins_with("ending.") and FROZEN.schema_for_entry(entry_id).get("ok", false)

static func _hospital_entry(entry_id: String) -> bool:
	for day: int in range(1, 8):
		if entry_id == "hospital.faint.day%d" % day: return true
	return false

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": ""}
