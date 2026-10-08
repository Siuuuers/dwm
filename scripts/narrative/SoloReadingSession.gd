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
var marker_document: Dictionary = {}
var marker_fingerprint := ""
var marker_entries: Dictionary = {}
var marker_frontier: Dictionary = {}

## Opt-in scene programme. No production caller installs this family implicitly.
## Durable admission authentication belongs to the Run owner before admit_scene.
var scene_occurrence := ""
var scene_index := 0
var _scene_nodes: Dictionary = {}

func configure_scene() -> Dictionary:
	if not catalogue.is_empty() or ledger != null: return _fail(&"reading_catalogue_already_configured")
	var owner := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var selected := owner.scene_registration()
	if not selected.ok: return selected
	var bundle: Dictionary = selected.value
	var entries := {}
	for entry: Dictionary in bundle.entry_manifest.entries: entries[entry.entry_id] = entry
	var compiled_nodes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		var entry: Dictionary = entries[programme.entry_id]
		var compiled := DialogicRuntimeAdapter.compile_scene_programme(entry.locators.en.path,
			programme.entry_id, entries.keys(), programme.markers)
		if not compiled.ok: return compiled
		if compiled.value.content_sha256 != programme.content_sha256 or compiled.value.program_sha256 != programme.program_sha256:
			return _fail(&"reading_catalogue_mismatch")
		compiled_nodes[programme.entry_id] = compiled.value.nodes.duplicate(true)
	var compiled_catalogue := {}
	var beats: Array = []
	for entry: Dictionary in bundle.caption_registry.entries:
		var row: Dictionary = entry.duplicate(true)
		row["label"] = entry.entry_id
		row["content_version"] = entries[entry.entry_id].content_version
		compiled_catalogue[entry.entry_id] = row
		for line: Dictionary in entry.lines:
			beats.append({"beat_id": line.beat_id, "line_id": line.line_id, "owning_entry_id": entry.entry_id,
				"presentation_signature": {"content_revision": line.revision, "variant_id": line.beat_id}})
	family = "scene"
	catalogue_schema_version = 5
	fingerprint = owner.scene_registration_fingerprint()
	manifest = bundle.entry_manifest.duplicate(true)
	catalogue = compiled_catalogue
	registry = {"kind": "narrative_caption_registry", "schema_version": 1, "beats": beats}
	_scene_nodes = compiled_nodes
	for beat: Dictionary in beats: _caption_variants_by_line[beat.line_id] = beat
	FROZEN._freeze(catalogue)
	FROZEN._freeze(registry)
	FROZEN._freeze(_scene_nodes)
	return {"ok": true}

func begin_scene(session_token: String) -> Dictionary:
	if family != "scene" or ledger != null or session_token.strip_edges().is_empty(): return _fail(&"reading_session_invalid")
	var candidate := LEDGER.new()
	var initialized := candidate.initialize(session_token, {"family": "scene", "session_token": session_token,
		"registration_sha256": fingerprint}, manifest, registry, true, true)
	if not initialized.ok: return initialized
	ledger = candidate
	command_id = session_token
	return {"ok": true}

## Admission never publishes; the configured Bridge owns the saved target gate.
## index permits registered internal targets, after the owner authenticates them.
func admit_scene(entry_id: String, context: Dictionary, index: int = 0) -> Dictionary:
	if family != "scene" or ledger == null or not catalogue.has(entry_id): return _fail(&"reading_session_unavailable")
	var occurrence: String = str(context.get("playback_id", ""))
	if not LEDGER.valid_scene_frame(context, occurrence, entry_id) or index < 0 \
			or index >= _scene_nodes[entry_id].size() or _scene_nodes[entry_id][index].kind != "caption":
		return _fail(&"reading_context_invalid")
	var admitted := ledger.admit_entry_context(command_id, entry_id, context, occurrence)
	if not admitted.ok: return admitted
	latest_entry = entry_id
	scene_occurrence = occurrence
	scene_index = index
	boundary = "line"
	next_operation = {}
	return {"ok": true}

func _capture_scene(frontier: Dictionary) -> Dictionary:
	if ledger == null or latest_entry.is_empty(): return _fail(&"reading_session_unavailable")
	var saved := {"schema_version": 5, "registration_sha256": fingerprint, "entry_id": latest_entry,
		"occurrence_id": scene_occurrence, "program_index": scene_index, "boundary": boundary,
		"ledger": ledger.snapshot(), "frontier": frontier.duplicate(true),
		"next_operation": null if next_operation.is_empty() else next_operation.duplicate(true)}
	var checked := _validate_scene_saved(saved, latest_entry)
	return {"ok": true, "value": saved} if checked.ok else checked

func _validate_scene_base(saved: Dictionary, entry_id: String) -> Dictionary:
	if not TRAVERSAL.valid_scene_reading_shape(saved) or saved.entry_id != entry_id \
			or saved.registration_sha256 != fingerprint or not _scene_nodes.has(entry_id):
		return _fail(&"reading_checkpoint_invalid")
	var nodes: Array = _scene_nodes[entry_id]
	if saved.program_index >= nodes.size(): return _fail(&"reading_frontier_invalid")
	var node: Dictionary = nodes[saved.program_index]
	var expected_kind: String = "line" if node.kind == "caption" else ("between_entries" if node.kind == "completion" else node.kind)
	if saved.boundary != expected_kind: return _fail(&"reading_frontier_invalid")
	if saved.boundary == "line" and node.line_id != saved.frontier.line_id: return _fail(&"reading_frontier_invalid")
	var retained: Dictionary = saved.ledger
	if not TRAVERSAL._same(retained.frozen_context, {"family": "scene", "session_token": retained.session_token,
			"registration_sha256": fingerprint}): return _fail(&"reading_context_invalid")
	var candidate := LEDGER.new()
	var restored := candidate.restore_snapshot(retained.session_token, retained.frozen_context, manifest,
		registry, retained, retained.entry_contexts, true, true)
	if not restored.ok: return restored
	return {"ok": true, "value": candidate}

func _validate_scene_saved(saved: Dictionary, entry_id: String) -> Dictionary:
	var checked := _validate_scene_base(saved, entry_id)
	if not checked.ok: return checked
	if saved.next_operation == null: return checked
	var operation := TRAVERSAL.validate(saved, entry_id)
	if not operation.ok: return operation
	var plan: Dictionary = operation.value.plan
	var path := TRAVERSAL.validate_scene_path(plan, _scene_nodes[entry_id])
	if not path.ok: return path
	for phase: String in ["source", "destination"]:
		var projected := TRAVERSAL.project(plan, phase)
		if not projected.ok: return projected
		var endpoint := _validate_scene_base(projected.value, entry_id)
		if not endpoint.ok: return endpoint
	return checked

func prepare_scene_next(frontier: Dictionary, is_witnessed: Callable) -> Dictionary:
	if family != "scene" or boundary != "line" or not is_witnessed.is_valid(): return _fail(&"reading_next_unavailable")
	var source := _capture_scene(frontier)
	if not source.ok: return source
	var reading: Dictionary = TRAVERSAL.without_operation(source.value)
	var candidate := LEDGER.new()
	var retained: Dictionary = reading.ledger
	var copied := candidate.restore_snapshot(command_id, retained.frozen_context, manifest, registry,
		retained, retained.entry_contexts, true, true)
	if not copied.ok: return copied
	var nodes: Array = _scene_nodes[latest_entry]
	var index: int = scene_index
	var path: Array = []
	var captions: Array = []
	var destination := {}
	var visited := {}
	while destination.is_empty():
		if visited.has(index): return _fail(&"reading_next_path_invalid")
		visited[index] = true
		var node: Dictionary = nodes[index]
		if node.kind not in ["caption", "jump"]: return _fail(&"reading_next_path_invalid")
		var target: int = node.next
		path.append({"from": index, "to": target})
		var next: Dictionary = nodes[target]
		var backward: bool = node.kind == "jump" and target <= index
		if next.kind == "caption":
			var beat: Dictionary = _caption_variants_by_line[next.line_id]
			var witnessed: Variant = is_witnessed.call(beat.duplicate(true))
			if typeof(witnessed) != TYPE_BOOL: return _fail(&"reading_next_witness_invalid")
			var allocation := candidate.allocate_publication(command_id, latest_entry, scene_occurrence)
			if not allocation.ok: return allocation
			var publication := candidate.publish_caption(command_id, allocation.value, beat, scene_occurrence)
			if not publication.ok: return publication
			var row := {"publication_id": allocation.value, "occurrence_id": scene_occurrence, "beat": beat.duplicate(true)}
			if backward or not witnessed: destination = {"kind": "line", "program_index": target, "caption": row}
			else: captions.append(row)
		elif next.kind in ["control", "completion"]:
			destination = {"kind": next.kind, "program_index": target, "caption": null}
		elif backward: return _fail(&"reading_next_path_invalid")
		index = target
	var plan := {"schema_version": 3, "entry_id": latest_entry, "source_reading": reading,
		"path": path, "traversed_captions": captions, "destination": destination}
	var checked := TRAVERSAL.validate_scene_path(plan, nodes)
	return {"ok": true, "value": plan} if checked.ok else checked

func _project_scene(frontier: Dictionary) -> Dictionary:
	var captured := _capture_scene(frontier)
	if not captured.ok: return captured
	var rows: Array[Dictionary] = []
	for row: Dictionary in captured.value.ledger.captions:
		var frame := LEDGER.resolve_scene_frame(captured.value.ledger.entry_contexts, row.occurrence_id, row.beat.owning_entry_id)
		if not frame.ok: return frame
		var programme := entry_program(row.beat.owning_entry_id, frame.value)
		if not programme.ok: return programme
		for line: Dictionary in programme.value.lines:
			if line.line_id == row.beat.line_id:
				rows.append({"publication_id": row.publication_id, "beat_id": row.beat.beat_id,
					"line_id": line.line_id, "entry_id": row.beat.owning_entry_id, "text": line.text})
	return {"ok": true, "value": {"captions": rows, "frontier": frontier.duplicate(true), "session_id": command_id}}


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
	if latest_entry != entry_id:
		next_operation = {}
		marker_frontier = {}
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
	if family == "scene":
		if ledger == null or boundary != "line" or latest_entry != entry_id or not ledger.is_current_occurrence(command_id, entry_id, frontier, scene_occurrence): return _fail(&"reading_frontier_unavailable")
		return {"ok": true, "value": _caption_variants_by_line[frontier.line_id].duplicate(true)}
	if ledger == null or boundary != "line" or latest_entry != entry_id \
			or not ledger.is_current_occurrence(command_id, entry_id, frontier):
		return _fail(&"reading_frontier_unavailable")
	var beat: Dictionary = _caption_variants_by_line.get(frontier.line_id, {})
	if beat.is_empty() or beat.owning_entry_id != entry_id:
		return _fail(&"reading_frontier_unavailable")
	return {"ok": true, "value": beat.duplicate(true)}

func capture(frontier: Dictionary) -> Dictionary:
	if family == "scene": return _capture_scene(frontier)
	if marker_entries.has(latest_entry): return _capture_marker(frontier)
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
	if family == "scene": return _validate_scene_saved(saved, entry_id)
	if marker_entries.has(entry_id) or saved.get("schema_version") == 4:
		return _validate_marker_saved(saved, entry_id)
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
	if family == "scene":
		var scene_checked := _validate_scene_saved(saved, entry_id)
		if not scene_checked.ok: return scene_checked
		ledger = scene_checked.value
		command_id = saved.ledger.session_token
		latest_entry = entry_id
		scene_occurrence = saved.occurrence_id
		scene_index = saved.program_index
		boundary = saved.boundary
		next_operation = saved.next_operation.duplicate(true) if saved.next_operation is Dictionary else {}
		return {"ok": true}
	var checked := validate_saved(saved, entry_id)
	if not checked.ok: return checked
	ledger = checked.value
	if catalogue_schema_version == 2: _install_programs(checked.programs, checked.registry)
	command_id = saved.ledger.frozen_context.completion_transaction_id
	pre_entry_id = saved.ledger.frozen_context.get("entry_id" if family in ["hospital", "ending"] else "pre_entry_id")
	latest_entry = entry_id
	boundary = saved.boundary
	next_operation = saved.next_operation.duplicate(true) if saved.get("next_operation") is Dictionary else {}
	marker_frontier = saved.frontier.duplicate(true) if saved.boundary == "notification" else {}
	return {"ok": true}

## Build one detached, exact route suffix. The live ledger and Profile are never
## changed by planning. Only the caller's validated exact-membership query may
## authorize silent traversal; the first unseen caption becomes the destination.
func prepare_next(frontier: Dictionary, is_witnessed: Callable) -> Dictionary:
	if family == "scene": return prepare_scene_next(frontier, is_witnessed)
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
	if family == "scene": return _project_scene(frontier)
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
	if family == "scene":
		if not catalogue.has(entry_id): return _fail(&"reading_entry_unavailable")
		if not context.is_empty() and not LEDGER.valid_scene_frame(context, str(context.get("playback_id", "")), entry_id): return _fail(&"reading_context_invalid")
		return {"ok": true, "value": catalogue[entry_id].duplicate(true)}
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


## The separate trusted document preserves catalogue/receipt identity. No saved
## checkpoint or native label may configure an event or its authored position.
func configure_markers(document: Dictionary) -> Dictionary:
	if document.is_empty(): return {"ok": true}
	if not marker_document.is_empty():
		return {"ok": true} if TRAVERSAL.EVENT._same_types(marker_document, document) and marker_document == document else _fail(&"reading_markers_already_configured")
	if not OS.has_feature("debug") or OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty() \
			or ledger != null or family != "solo" or catalogue_schema_version != 1 \
			or not FROZEN._exact(document, ["kind", "schema_version", "entries"]) \
			or document.get("kind") != "reading_notification_markers" \
			or typeof(document.get("schema_version")) != TYPE_INT or document.schema_version != 1 \
			or not document.get("entries") is Array or document.entries.is_empty(): return _fail(&"reading_markers_invalid")
	var selected := {}
	var ids := {}
	for raw: Variant in document.entries:
		if not raw is Dictionary or not FROZEN._exact(raw, ["entry_id", "content_version", "catalogue_fingerprint", "marker"]) \
				or not raw.entry_id is String or not catalogue.has(raw.entry_id) or selected.has(raw.entry_id) \
				or typeof(raw.content_version) != TYPE_INT or raw.content_version != catalogue[raw.entry_id].content_version \
				or raw.catalogue_fingerprint != fingerprint or not raw.marker is Dictionary: return _fail(&"reading_markers_invalid")
		var marker: Dictionary = raw.marker
		if not FROZEN._exact(marker, ["event_id", "ordinal", "predecessor", "kind", "payload", "after_line_id", "before_line_id", "label"]) \
				or not TRAVERSAL.EVENT._id(marker.event_id) or ids.has(marker.event_id) \
				or typeof(marker.ordinal) != TYPE_INT or marker.ordinal != 0 or marker.predecessor != "" \
				or marker.kind != "notification.set" or marker.label != "scene.marker." + marker.event_id \
				or not TRAVERSAL.EVENT._id(marker.label) or not marker.payload is Dictionary \
				or not FROZEN._exact(marker.payload, ["notification_id", "content_id", "parameters"]) \
				or not TRAVERSAL.EVENT._id(marker.payload.notification_id) or not TRAVERSAL.EVENT._id(marker.payload.content_id) \
				or not marker.payload.parameters is Dictionary: return _fail(&"reading_markers_invalid")
		for key: Variant in marker.payload.parameters:
			if not TRAVERSAL.EVENT._id(key) or typeof(marker.payload.parameters[key]) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL]:
				return _fail(&"reading_markers_invalid")
		var lines: Array = catalogue[raw.entry_id].lines
		var gap := -1
		for index: int in range(lines.size() - 1):
			if lines[index].line_id == marker.after_line_id and lines[index + 1].line_id == marker.before_line_id: gap = index
		if gap < 0: return _fail(&"reading_marker_position_invalid")
		selected[raw.entry_id] = marker.duplicate(true)
		ids[marker.event_id] = true
	var encoded := JSON_WRITER.stringify(document)
	if not encoded.ok: return encoded
	marker_document = document.duplicate(true)
	marker_entries = selected
	marker_fingerprint = str(encoded.value).sha256_text()
	FROZEN._freeze(marker_document)
	FROZEN._freeze(marker_entries)
	return {"ok": true}

func _capture_marker(frontier: Dictionary) -> Dictionary:
	if ledger == null: return _fail(&"reading_session_unavailable")
	var saved := {"schema_version": 4, "catalogue_fingerprint": fingerprint,
		"marker_program_fingerprint": marker_fingerprint, "boundary": boundary, "ledger": ledger.snapshot(),
		"frontier": marker_frontier.duplicate(true) if boundary == "notification" else frontier.duplicate(true),
		"next_operation": null if next_operation.is_empty() else next_operation.duplicate(true)}
	var checked := _validate_marker_saved(saved, latest_entry)
	return {"ok": true, "value": saved} if checked.ok else checked

func _validate_marker_saved(saved: Dictionary, entry_id: String) -> Dictionary:
	if not marker_entries.has(entry_id) or not TRAVERSAL.valid_marker_reading_shape(saved) \
			or saved.marker_program_fingerprint != marker_fingerprint: return _fail(&"reading_marker_checkpoint_invalid")
	if saved.next_operation != null:
		var checked := TRAVERSAL.validate(saved, entry_id)
		if not checked.ok: return checked
		for phase: String in ["source", "destination"]:
			var projected := TRAVERSAL.project(checked.value.plan, phase)
			if not projected.ok: return projected
			var endpoint := _validate_marker_base(projected.value, entry_id)
			if not endpoint.ok: return endpoint
		var route := _validate_marker_route(checked.value.plan)
		if not route.ok: return route
	return _validate_marker_base(saved, entry_id)

func _validate_marker_base(saved: Dictionary, entry_id: String) -> Dictionary:
	var base := {"schema_version": 1, "catalogue_fingerprint": saved.catalogue_fingerprint,
		"boundary": saved.boundary, "ledger": saved.ledger.duplicate(true), "frontier": saved.frontier.duplicate(true)}
	if saved.boundary == "notification":
		var marker: Dictionary = marker_entries[entry_id]
		var anchor: Dictionary = saved.frontier.anchor
		if saved.frontier.event_id != marker.event_id or anchor.line_id != marker.after_line_id \
				or anchor.content_version != catalogue[entry_id].content_version: return _fail(&"reading_marker_position_invalid")
		base.boundary = "line"
		base.frontier = {"line_id": anchor.line_id, "publication_id": anchor.publication_id}
	return _validate_base_saved(base, entry_id)

func _marker_crossed(reading: Dictionary, entry_id: String) -> bool:
	var marker: Dictionary = marker_entries[entry_id]
	for row: Dictionary in reading.ledger.captions:
		if row.beat.owning_entry_id == entry_id and row.beat.line_id == marker.before_line_id: return true
	return reading.ledger.captions.back().beat.owning_entry_id == entry_id \
		and reading.boundary in ["notification", "between_entries"]

func _validate_marker_route(plan: Dictionary) -> Dictionary:
	var source: Dictionary = plan.source_reading
	var destination := TRAVERSAL._marker_projection(plan, "destination")
	var crossed_before := _marker_crossed(source, plan.entry_id)
	var crossed_after := _marker_crossed(destination, plan.entry_id)
	if not crossed_before and crossed_after and plan.destination.kind != "notification": return _fail(&"reading_marker_bypassed")
	if crossed_before and plan.destination.kind == "notification": return _fail(&"reading_marker_repeated")
	if plan.destination.kind == "notification":
		var semantic: Dictionary = plan.destination.semantic
		var marker: Dictionary = marker_entries[plan.entry_id]
		for key: String in ["event_id", "ordinal", "predecessor", "kind", "payload"]:
			if not TRAVERSAL.EVENT._same_types(semantic[key], marker[key]) or semantic[key] != marker[key]:
				return _fail(&"reading_marker_registration_mismatch")
	return {"ok": true}

## A detached route stops at the first marker, before querying a later witness.
## The issuer-supplied semantic command is needed only if that stop is reached.
func prepare_marker_next(frontier: Dictionary, is_witnessed: Callable, semantic: Dictionary = {}) -> Dictionary:
	if family == "scene":
		# Held controls need the Run owner's committed target; a semantic copy
		# supplied to the old notification seam is never that authority.
		if not semantic.is_empty(): return _fail(&"reading_next_unavailable")
		return prepare_scene_next(frontier, is_witnessed)
	if not marker_entries.has(latest_entry) or not is_witnessed.is_valid() \
			or boundary not in ["line", "notification"]: return _fail(&"reading_next_unavailable")
	var captured := capture(frontier)
	if not captured.ok: return captured
	var source := TRAVERSAL.without_operation(captured.value)
	var marker: Dictionary = marker_entries[latest_entry]
	var lines: Array = catalogue[latest_entry].lines
	var tail: Dictionary = source.ledger.captions.back()
	var index := -1
	for ordinal: int in lines.size():
		if lines[ordinal].line_id == tail.beat.line_id: index = ordinal
	if index < 0: return _fail(&"reading_frontier_invalid")
	var candidate := LEDGER.new()
	var copied := candidate.restore_snapshot(command_id, source.ledger.frozen_context, manifest,
		registry, source.ledger, source.ledger.entry_contexts, true)
	if not copied.ok: return copied
	var traversed: Array = []
	var destination := {"kind": "completion"}
	var crossed := _marker_crossed(source, latest_entry)
	for ordinal: int in range(index, lines.size()):
		if not crossed and lines[ordinal].line_id == marker.after_line_id:
			if semantic.is_empty(): return {"ok": true, "needs_event": true}
			var anchor_row: Dictionary = candidate.snapshot().captions.back()
			destination = {"kind": "notification", "semantic": semantic.duplicate(true), "anchor": {
				"session_id": command_id, "entry_id": latest_entry, "content_version": catalogue[latest_entry].content_version,
				"catalogue_fingerprint": fingerprint, "line_id": anchor_row.beat.line_id, "publication_id": anchor_row.publication_id}}
			break
		if ordinal + 1 >= lines.size(): break
		var variant: Dictionary = _caption_variants_by_line[lines[ordinal + 1].line_id]
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
	var plan := {"schema_version": 2, "entry_id": latest_entry, "source_reading": source,
		"traversed_captions": traversed, "destination": destination}
	var made := TRAVERSAL.create(plan, "source")
	if not made.ok: return made
	var route := _validate_marker_route(plan)
	return {"ok": true, "value": plan} if route.ok else route

## Converse proof is derived from authored positions, including preceding entries;
## no saved flag or receipt cache can grant a skipped marker.
func validate_marker_receipts(saved: Dictionary, entry_id: String, receipts: Dictionary, run_id: String) -> Dictionary:
	var admitted := validate_saved(saved, entry_id)
	if not admitted.ok: return admitted
	var checked := TRAVERSAL.EVENT.validate_receipts(receipts)
	if not checked.ok: return checked
	# A source-phase checkpoint has no marker receipt yet, but its immutable
	# planned command must already belong to this Run. Issuer authentication
	# remains with the event port, including when resuming this planned command.
	if saved.get("next_operation") is Dictionary and saved.next_operation.schema_version == 2:
		var target: Dictionary = saved.next_operation.plan.destination
		if target.kind == "notification" and target.semantic.source.run_id != run_id:
			return _fail(&"reading_marker_receipt_conflict")
	for marked: String in marker_entries:
		var marker: Dictionary = marker_entries[marked]
		var key: String = str(JSON_WRITER.stringify([saved.ledger.session_token, marked]).value)
		var group: Dictionary = checked.value.occurrences.get(key, {})
		var passed: bool = saved.ledger.entry_contexts.has(marked) and _marker_crossed(saved, marked)
		if not passed:
			if not group.is_empty(): return _fail(&"reading_marker_receipt_ahead")
			continue
		if group.is_empty() or group.receipts.size() != 1 or group.source.run_id != run_id \
				or group.source.content_version != catalogue[marked].content_version: return _fail(&"reading_marker_receipt_missing")
		var receipt: Dictionary = group.receipts[0]
		var event: Dictionary = receipt.scene_event.semantic
		for field: String in ["event_id", "ordinal", "predecessor", "kind", "payload"]:
			if not TRAVERSAL.EVENT._same_types(event[field], marker[field]) or event[field] != marker[field]:
				return _fail(&"reading_marker_receipt_conflict")
		var anchor: Dictionary = receipt.scene_event.reading_anchor
		var expected := {}
		for row: Dictionary in saved.ledger.captions:
			if row.beat.owning_entry_id == marked and row.beat.line_id == marker.after_line_id:
				expected = {"session_id": saved.ledger.session_token, "entry_id": marked,
					"content_version": catalogue[marked].content_version, "catalogue_fingerprint": fingerprint,
					"publication_id": row.publication_id, "line_id": row.beat.line_id}
		if expected.is_empty() or not TRAVERSAL.EVENT._same_types(anchor, expected) or anchor != expected:
			return _fail(&"reading_marker_receipt_conflict")
		if marked == entry_id:
			var cursors: Array = [saved]
			if saved.get("next_operation") is Dictionary and saved.next_operation.schema_version == 2:
				cursors.append(saved.next_operation.plan.source_reading)
			for cursor: Dictionary in cursors:
				if cursor.boundary != "notification": continue
				if cursor.frontier.command_id != receipt.transaction_id or cursor.frontier.event_digest != receipt.request_fingerprint \
						or not TRAVERSAL.EVENT._same_types(cursor.frontier.anchor, anchor) or cursor.frontier.anchor != anchor:
					return _fail(&"reading_marker_receipt_conflict")
	return {"ok": true}

