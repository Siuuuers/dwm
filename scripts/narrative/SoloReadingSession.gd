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
var _scene_bundle: Dictionary = {}
var player_progress: Dictionary = {}
var _progress_serial := 0
var _pending_checkpoint := false
# Only immutable semantic data is shared; native playback resources and each
# session's ledger/cursor stay separate. Installed content is fixed for this process.
static var _prepared_scene_configuration: Dictionary = {}

func configure_scene() -> Dictionary:
	var timing := preload("res://scripts/narrative/SceneValidationTiming.gd")
	var started_us: int = timing.start_sample()
	if started_us < 0: return _configure_scene_observed_body()
	var result: Dictionary = _configure_scene_observed_body()
	timing.finish_sample("configuration", started_us, bool(result.get("ok", false)))
	return result

func _configure_scene_observed_body() -> Dictionary:
	if not catalogue.is_empty() or ledger != null: return _fail(&"reading_catalogue_already_configured")
	var owner := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var selected := owner.scene_contract_tables()
	if not selected.ok: return selected
	var bundle: Dictionary = selected.bundle
	var entries := {}
	for entry: Dictionary in bundle.entry_manifest.entries: entries[entry.entry_id] = entry
	var cacheable: bool = not ProjectSettings.get_setting("dialogic/translation/enabled", false)
	var prepared := {}
	if cacheable and is_same(_prepared_scene_configuration.get("bundle"), bundle):
		prepared = _prepared_scene_configuration
	else:
		var compiled_nodes := {}
		for programme: Dictionary in bundle.scene_programme.entries:
			var entry: Dictionary = entries[programme.entry_id]
			var compiled := DialogicRuntimeAdapter.compile_runtime_scene_programme(entry.locators.en.path,
				programme.entry_id, entries.keys(), programme.markers)
			if not compiled.ok: return compiled
			compiled_nodes[programme.entry_id] = compiled.value.nodes
		var compiled_catalogue := {}
		var beats: Array = []
		var variants := {}
		for entry: Dictionary in bundle.caption_registry.entries:
			var row: Dictionary = entry.duplicate(true)
			row["label"] = entry.entry_id
			row["content_version"] = entries[entry.entry_id].content_version
			compiled_catalogue[entry.entry_id] = row
			for line: Dictionary in entry.lines:
				var beat := {"beat_id": line.beat_id, "line_id": line.line_id, "owning_entry_id": entry.entry_id,
					"presentation_signature": {"content_revision": line.revision, "variant_id": line.beat_id}}
				beats.append(beat)
				variants[beat.line_id] = beat
		prepared = {"bundle": bundle, "manifest": bundle.entry_manifest,
			"catalogue": compiled_catalogue, "nodes": compiled_nodes, "variants": variants,
			"registry": {"kind": "narrative_caption_registry", "schema_version": 1, "beats": beats}}
		FROZEN._freeze(prepared)
		if cacheable: _prepared_scene_configuration = prepared
	family = "scene"
	catalogue_schema_version = 5
	fingerprint = owner.scene_registration_fingerprint()
	manifest = prepared.manifest
	catalogue = prepared.catalogue
	registry = prepared.registry
	_scene_nodes = prepared.nodes
	_scene_bundle = bundle
	_caption_variants_by_line = prepared.variants
	return {"ok": true}

## Same synchronous initial-candidate check only. Share configuration, never the
## restored ledger/cursor; the sibling must construct its own first publication.
func _fork_scene_configuration() -> RefCounted:
	var sibling: RefCounted = get_script().new()
	sibling.family = family
	sibling.catalogue_schema_version = catalogue_schema_version
	sibling.fingerprint = fingerprint
	sibling.manifest = manifest
	sibling.catalogue = catalogue
	sibling.registry = registry
	sibling._scene_nodes = _scene_nodes
	sibling._scene_bundle = _scene_bundle
	sibling._caption_variants_by_line = _caption_variants_by_line
	return sibling

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
	if not latest_entry.is_empty() and boundary == "control":
		_pending_checkpoint = _pending_checkpoint or _is_major_marker(_scene_nodes[latest_entry][scene_index].marker_id)
	_pending_checkpoint = _pending_checkpoint or player_progress.is_empty() \
		or _story_day(latest_entry if not latest_entry.is_empty() else player_progress.recovery_anchor.entry_id) != _story_day(entry_id)
	latest_entry = entry_id
	scene_occurrence = occurrence
	scene_index = index
	boundary = "line"
	next_operation = {}
	return {"ok": true}

## Ordinary native publication may cross jumps, but never skip another caption
## or a control owned by the durable traversal transaction.
func accept_scene_publication(index: int, frontier: Dictionary) -> Dictionary:
	if family != "scene" or boundary != "line" or ledger == null \
			or not _scene_nodes.has(latest_entry) \
			or not ledger.is_current_occurrence(command_id, latest_entry, frontier, scene_occurrence):
		return _fail(&"reading_frontier_invalid")
	var nodes: Array = _scene_nodes[latest_entry]
	if scene_index < 0 or scene_index >= nodes.size() or index < 0 or index >= nodes.size() \
			or nodes[scene_index].kind != "caption" or nodes[index].kind != "caption" \
			or nodes[index].line_id != frontier.line_id:
		return _fail(&"reading_frontier_invalid")
	var cursor: int = nodes[scene_index].next
	var visited := {}
	while cursor >= 0 and cursor < nodes.size():
		var node: Dictionary = nodes[cursor]
		if node.kind == "caption":
			if cursor != index: return _fail(&"reading_frontier_invalid")
			scene_index = index
			next_operation = {}
			return {"ok": true}
		if node.kind != "jump" or visited.has(cursor): break
		visited[cursor] = true
		cursor = node.next
	return _fail(&"reading_frontier_invalid")

func _capture_scene(frontier: Dictionary) -> Dictionary:
	if ledger == null or latest_entry.is_empty(): return _fail(&"reading_session_unavailable")
	var retained: Dictionary = ledger.snapshot()
	for row: Dictionary in retained.captions:
		var serial := _scene_publication_high_water([row])
		if serial <= _progress_serial: continue
		if row.occurrence_id == scene_occurrence and row.beat.owning_entry_id == latest_entry:
			TRAVERSAL.append_player_caption(player_progress, latest_entry, row.beat.line_id,
				_story_day(latest_entry), _pending_checkpoint)
			_pending_checkpoint = false
		_progress_serial = serial
	var saved := {"schema_version": 5, "registration_sha256": fingerprint, "entry_id": latest_entry,
		"occurrence_id": scene_occurrence, "program_index": scene_index, "boundary": boundary,
		"ledger": retained, "frontier": frontier.duplicate(true), "player_progress": player_progress.duplicate(true),
		"next_operation": null if next_operation.is_empty() else next_operation.duplicate(true)}
	var checked := _validate_scene_saved(saved, latest_entry)
	return {"ok": true, "value": saved} if checked.ok else checked

func _story_day(entry_id: String) -> int:
	return int(_scene_bundle.get("scene_programme", {}).get("story_days", {}).get(entry_id,
		player_progress.get("story_day", 1)))

func _is_major_marker(marker_id: String) -> bool:
	for programme: Dictionary in _scene_bundle.scene_programme.entries:
		for marker: Dictionary in programme.markers:
			if marker.marker_id == marker_id:
				return marker.kind in ["thought.pass", "thought.options", "challenge.end", "challenge.recall"]
	return false

func inherit_player_progress(source_session: RefCounted, major_checkpoint: bool = false) -> void:
	player_progress = source_session.player_progress.duplicate(true)
	# Keep this ledger's encounter cursor; inherited metadata has a separate publication history.
	_pending_checkpoint = major_checkpoint

## Player saves retain a stable authored position and its current genuine caption.
## History is derived separately; full capture/restore remains the live contract.
static func project_player_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if checkpoint.get("stage") != "scene": return {"ok": true, "value": checkpoint.duplicate(true)}
	var reading: Variant = checkpoint.get("reading_session")
	if not reading is Dictionary or reading.get("schema_version") not in [5, 7]:
		return _fail(&"reading_checkpoint_invalid")
	var session: RefCounted = load("res://scripts/narrative/SoloReadingSession.gd").new()
	var configured: Dictionary = session.configure_scene()
	if not configured.ok: return configured
	if reading.schema_version == 7:
		var checked: Dictionary = session.restore_player(reading, str(checkpoint.get("entry_id", "")))
		if not checked.ok: return checked
		var copy := checkpoint.duplicate(true)
		var expanded: Dictionary = session.capture({"line_id": reading.captions.back().line_id,
			"publication_id": reading.captions.back().publication_id} if reading.boundary == "line" else {})
		if not expanded.ok: return expanded
		var projected: Dictionary = session._project_player_reading(expanded.value)
		if not projected.ok: return projected
		copy.reading_session = projected.value
		return {"ok": true, "value": copy}
	var restored: Dictionary = session.restore(reading, str(checkpoint.get("entry_id", "")))
	if not restored.ok: return restored
	var projected: Dictionary = session._project_player_reading(reading)
	if not projected.ok: return projected
	var result := checkpoint.duplicate(true)
	result.reading_session = projected.value
	return {"ok": true, "value": result}

## External save admission owns this call. It prepares current story data only;
## the selected save, gameplay and Profile remain untouched until restore commits.
static func normalize_player_checkpoint(checkpoint: Dictionary, choices: Dictionary,
		outcomes: Dictionary) -> Dictionary:
	var saved: Variant = checkpoint.get("reading_session")
	if not saved is Dictionary or saved.get("schema_version") != 7:
		return _fail(&"reading_checkpoint_invalid")
	if not FROZEN._exact(checkpoint, ["entry_id", "content_version", "manifest_fingerprint", "frozen_context",
			"transaction_id", "stage", "reading_session"]) or checkpoint.stage != "scene" \
			or typeof(checkpoint.content_version) != TYPE_INT or checkpoint.content_version < 1 \
			or not checkpoint.frozen_context is Dictionary \
			or checkpoint.manifest_fingerprint != saved.get("registration_sha256") \
			or checkpoint.transaction_id != checkpoint.frozen_context.get("transaction_id"):
		return _fail(&"reading_checkpoint_invalid")
	var keys := ["schema_version", "registration_sha256", "entry_id", "occurrence_id", "boundary",
		"position_id", "session_token", "publication_serial", "captions", "story_day", "recovery_anchor", "history_sections"]
	if not FROZEN._exact(saved, keys) or saved.get("entry_id") != checkpoint.get("entry_id") \
			or not saved.registration_sha256 is String or not TRAVERSAL._hash(saved.registration_sha256) \
			or not saved.entry_id is String or saved.entry_id.is_empty() \
			or saved.boundary not in ["line", "control", "between_entries"] \
			or not saved.position_id is String or saved.position_id.is_empty() \
			or not saved.occurrence_id is String or saved.occurrence_id.is_empty() \
			or not saved.session_token is String or saved.session_token.is_empty() \
			or typeof(saved.publication_serial) != TYPE_INT or saved.publication_serial <= 0 \
			or saved.publication_serial == 9223372036854775807 \
			or not saved.captions is Array or saved.captions.size() != 1:
		return _fail(&"reading_checkpoint_invalid")
	if not LEDGER.valid_scene_frame(checkpoint.frozen_context, saved.occurrence_id, saved.entry_id):
		return _fail(&"reading_context_invalid")
	if checkpoint.transaction_id != saved.occurrence_id \
			or checkpoint.frozen_context.presentation.fields.admission_receipt_id != saved.occurrence_id:
		return _fail(&"reading_context_invalid")
	var tail: Variant = saved.captions[0]
	if not tail is Dictionary or not FROZEN._exact(tail, ["line_id", "publication_id"]) \
			or not tail.line_id is String or tail.line_id.is_empty() \
			or tail.publication_id != "caption:%d" % saved.publication_serial:
		return _fail(&"reading_checkpoint_invalid")
	if saved.boundary != "control" and saved.position_id != tail.line_id:
		return _fail(&"reading_frontier_invalid")
	var progress := {"story_day": saved.story_day, "recovery_anchor": saved.recovery_anchor,
		"history_sections": saved.history_sections}.duplicate(true)
	if not TRAVERSAL.valid_player_progress(progress): return _fail(&"reading_checkpoint_invalid")
	var session: RefCounted = load("res://scripts/narrative/SoloReadingSession.gd").new()
	var configured: Dictionary = session.configure_scene()
	if not configured.ok: return configured
	var days: Dictionary = session._scene_bundle.scene_programme.get("story_days", {})
	# Unchanged registrations without a day map need no recovery. Their strict
	# cursor restore is sufficient; changed content still requires authored days.
	if days.is_empty() and saved.registration_sha256 == session.fingerprint:
		var unchanged: Dictionary = session.restore_player(saved, saved.entry_id)
		if not unchanged.ok: return unchanged
		return {"ok": true, "value": {"checkpoint": checkpoint.duplicate(true),
			"story_day": session.player_progress.story_day, "fallback": false}}
	var entry_day: int = int(days.get(saved.entry_id, progress.story_day))
	if entry_day < 1 or entry_day > 7: return _fail(&"reading_history_day_unavailable")
	var day: int = maxi(entry_day, int(progress.story_day))
	if saved.registration_sha256 == session.fingerprint:
		if saved.story_day < entry_day: return _fail(&"reading_checkpoint_invalid")
		var original: RefCounted = session._fork_scene_configuration()
		var valid_original: Dictionary = original.restore_player(saved, saved.entry_id)
		if not valid_original.ok: return valid_original
	var history := load("res://scripts/narrative/SceneReadingHistory.gd")
	var route: Dictionary = history.current_day_route(session._scene_bundle, entry_day, choices, outcomes)
	if not route.ok: return route
	if saved.registration_sha256 == session.fingerprint and not route.value.entries.has(saved.entry_id):
		return _fail(&"reading_frontier_invalid")
	var current: Dictionary = saved.duplicate(true)
	current.registration_sha256 = session.fingerprint
	current.story_day = day
	var intact := false
	if route.value.entries.has(saved.entry_id):
		# A retained control's current predecessor may change without moving the
		# held operation. It is the caption the native restore will display.
		if current.boundary == "control":
			var nodes: Array = session._scene_nodes[saved.entry_id]
			for index: int in nodes.size():
				if nodes[index].kind != "control" or nodes[index].marker_id != current.position_id: continue
				for programme: Dictionary in session._scene_bundle.scene_programme.entries:
					if programme.entry_id != saved.entry_id: continue
					var preceding := DialogicRuntimeAdapter._scene_control_authored_predecessor(index, {"nodes": nodes}, programme.markers)
					if preceding.ok: current.captions[0].line_id = preceding.value.line_id
		var candidate: RefCounted = session._fork_scene_configuration()
		var checked: Dictionary = candidate.restore_player(current, current.entry_id)
		intact = checked.ok
		# If an entry gained new text after a formerly terminal caption, the
		# intact moment still wins over a checkpoint rewind.
		if not intact and current.boundary == "between_entries":
			current.boundary = "line"
			candidate = session._fork_scene_configuration()
			intact = candidate.restore_player(current, current.entry_id).ok
	var fallback := not intact
	if fallback:
		var anchor: Dictionary = progress.recovery_anchor
		var target := {}
		if route.value.entries.has(anchor.entry_id) and session._caption_variants_by_line.has(anchor.line_id) \
				and session._caption_variants_by_line[anchor.line_id].owning_entry_id == anchor.entry_id:
			target = anchor.duplicate(true)
		else:
			var start: String = route.value.start_entry
			for node: Dictionary in session._scene_nodes[start]:
				if node.kind == "caption":
					target = {"entry_id": start, "line_id": node.line_id}
					break
		if target.is_empty(): return _fail(&"reading_history_day_unavailable")
		current.entry_id = target.entry_id
		current.boundary = "line"
		current.position_id = target.line_id
		current.captions[0].line_id = target.line_id
		current.recovery_anchor = target
	# Keep only provable encountered IDs through the restored caption. No
	# route reconstruction may backfill newly inserted text into History.
	var sections: Array = []
	var found := false
	var restored_line: String = current.captions[0].line_id
	for section: Array in current.history_sections:
		var kept: Array = []
		for line_id: String in section:
			if not session._caption_variants_by_line.has(line_id): continue
			var owner: String = session._caption_variants_by_line[line_id].owning_entry_id
			if days.get(owner, entry_day) == entry_day and not route.value.entries.has(owner): continue
			if int(days.get(owner, day)) > day: continue
			kept.append(line_id)
			if line_id == restored_line:
				found = true
				break
		sections.append(kept)
		if found: break
	if not found:
		if fallback:
			var previous_sections: Array = []
			for section: Array in sections:
				var previous: Array = []
				for line_id: String in section:
					var owner: String = session._caption_variants_by_line[line_id].owning_entry_id
					if int(days.get(owner, entry_day)) < entry_day: previous.append(line_id)
				if not previous.is_empty(): previous_sections.append(previous)
			previous_sections.append([restored_line])
			while previous_sections.size() > 3: previous_sections.pop_front()
			sections = previous_sections
		else:
			if sections.is_empty(): sections.append([])
			sections.back().append(restored_line)
	current.history_sections = sections
	var restored: Dictionary = session.restore_player(current, current.entry_id)
	if not restored.ok: return restored
	var result := checkpoint.duplicate(true)
	result.entry_id = current.entry_id
	result.content_version = session.catalogue[current.entry_id].content_version
	result.manifest_fingerprint = session.fingerprint
	result.transaction_id = current.occurrence_id
	result.frozen_context = session.ledger.snapshot().entry_contexts[LEDGER.scene_frame_key(current.occurrence_id, current.entry_id)].duplicate(true)
	result.reading_session = current
	return {"ok": true, "value": {"checkpoint": result, "story_day": day, "fallback": fallback}}

static func expand_player_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if checkpoint.get("stage") != "scene": return {"ok": true, "value": checkpoint.duplicate(true)}
	var reading: Variant = checkpoint.get("reading_session")
	if not reading is Dictionary or reading.get("schema_version") not in [5, 7]:
		return _fail(&"reading_checkpoint_invalid")
	if reading.schema_version == 5: return {"ok": true, "value": checkpoint.duplicate(true)}
	var session: RefCounted = load("res://scripts/narrative/SoloReadingSession.gd").new()
	var configured: Dictionary = session.configure_scene()
	if not configured.ok: return configured
	var restored: Dictionary = session.restore_player(reading, str(checkpoint.get("entry_id", "")))
	if not restored.ok: return restored
	var frontier := {}
	if reading.boundary == "line":
		var tail: Dictionary = reading.captions.back()
		frontier = {"line_id": tail.line_id, "publication_id": tail.publication_id}
	var captured: Dictionary = session.capture(frontier)
	if not captured.ok: return captured
	var result := checkpoint.duplicate(true)
	result.reading_session = captured.value
	return {"ok": true, "value": result}

func _project_player_reading(saved: Dictionary) -> Dictionary:
	var captions: Array[Dictionary] = []
	for row: Dictionary in saved.ledger.captions:
		if row.occurrence_id == saved.occurrence_id and row.beat.owning_entry_id == saved.entry_id:
			captions.append({"line_id": row.beat.line_id, "publication_id": row.publication_id})
	if captions.is_empty(): return _fail(&"reading_frontier_invalid")
	captions = [captions.back()]
	var node: Dictionary = _scene_nodes[saved.entry_id][saved.program_index]
	var position: String = node.marker_id if saved.boundary == "control" else captions.back().line_id
	var compact := {"schema_version": 7, "registration_sha256": fingerprint,
		"entry_id": saved.entry_id, "occurrence_id": saved.occurrence_id,
		"boundary": saved.boundary, "position_id": position,
		"session_token": saved.ledger.session_token,
		"publication_serial": _scene_publication_high_water(saved.ledger.captions), "captions": captions}
	var progress: Dictionary = saved.get("player_progress", {}).duplicate(true)
	if progress.is_empty():
		TRAVERSAL.append_player_caption(progress, saved.entry_id, captions.back().line_id, _story_day(saved.entry_id))
	compact.merge(progress)
	# Authoritative current position must also resolve without the removed history.
	var candidate: RefCounted = _fork_scene_configuration()
	var checked: Dictionary = candidate.restore_player(compact, saved.entry_id)
	return {"ok": true, "value": compact} if checked.ok else checked

func restore_player(saved: Dictionary, entry_id: String) -> Dictionary:
	var keys := ["schema_version", "registration_sha256", "entry_id", "occurrence_id", "boundary",
		"position_id", "session_token", "publication_serial", "captions", "story_day", "recovery_anchor", "history_sections"]
	if family != "scene" or not FROZEN._exact(saved, keys) \
			or typeof(saved.schema_version) != TYPE_INT or saved.schema_version != 7 \
			or saved.registration_sha256 != fingerprint or saved.entry_id != entry_id \
			or not _scene_nodes.has(entry_id) or saved.boundary not in ["line", "control", "between_entries"] \
			or not saved.position_id is String or saved.position_id.is_empty() \
			or not saved.session_token is String or saved.session_token.strip_edges().is_empty() \
			or not saved.occurrence_id is String or saved.occurrence_id.strip_edges().is_empty() \
			or typeof(saved.publication_serial) != TYPE_INT or saved.publication_serial <= 0 \
			or saved.publication_serial == 9223372036854775807 \
			or not saved.captions is Array or saved.captions.size() != 1:
		return _fail(&"reading_checkpoint_invalid")
	var progress := {"story_day": saved.story_day, "recovery_anchor": saved.recovery_anchor,
		"history_sections": saved.history_sections}
	if not TRAVERSAL.valid_player_progress(progress): return _fail(&"reading_checkpoint_invalid")
	var rows: Array[Dictionary] = []
	var publications := {}
	for value: Variant in saved.captions:
		if not value is Dictionary or not FROZEN._exact(value, ["line_id", "publication_id"]) \
				or not value.line_id is String or not _caption_variants_by_line.has(value.line_id) \
				or not value.publication_id is String or value.publication_id.strip_edges().is_empty() \
				or value.publication_id != "caption:%d" % saved.publication_serial \
				or publications.has(value.publication_id): return _fail(&"reading_frontier_invalid")
		var beat: Dictionary = _caption_variants_by_line[value.line_id]
		if beat.owning_entry_id != entry_id: return _fail(&"reading_frontier_invalid")
		publications[value.publication_id] = true
		rows.append({"publication_id": value.publication_id, "occurrence_id": saved.occurrence_id,
			"beat": beat.duplicate(true)})
	# The retained caption includes the latest production allocation. Never restart
	# caption numbering and accidentally reuse an older command's reading anchor.
	if saved.publication_serial != _scene_publication_high_water(rows):
		return _fail(&"reading_frontier_invalid")
	var nodes: Array = _scene_nodes[entry_id]
	var index := -1
	for cursor: int in nodes.size():
		var node: Dictionary = nodes[cursor]
		if (saved.boundary == "control" and node.kind == "control" and node.marker_id == saved.position_id) \
				or (saved.boundary != "control" and node.kind == "caption" and node.line_id == saved.position_id):
			if index >= 0: return _fail(&"reading_frontier_invalid")
			index = cursor
	if index < 0: return _fail(&"reading_frontier_invalid")
	var tail: Dictionary = rows.back()
	if saved.boundary == "control":
		var registered := preload("res://scripts/narrative/DialogicEntryManifest.gd").scene_registration()
		if not registered.ok: return registered
		var predecessor := _fail(&"reading_frontier_invalid")
		for programme: Dictionary in registered.value.scene_programme.entries:
			if programme.entry_id == entry_id:
				predecessor = DialogicRuntimeAdapter._scene_control_authored_predecessor(index, {"nodes": nodes}, programme.markers)
		if not predecessor.ok or predecessor.value.line_id != tail.beat.line_id:
			return _fail(&"reading_frontier_invalid")
	else:
		if tail.beat.line_id != saved.position_id: return _fail(&"reading_frontier_invalid")
		if saved.boundary == "between_entries":
			index = nodes[index].next
			var visited := {}
			while index >= 0 and index < nodes.size() and nodes[index].kind == "jump" and not visited.has(index):
				visited[index] = true
				index = nodes[index].next
			if index < 0 or index >= nodes.size() or nodes[index].kind != "completion":
				return _fail(&"reading_frontier_invalid")
	var presentation := FROZEN.build(entry_id, {"entry_id": entry_id, "entry_role": "scene",
		"occurrence_id": saved.occurrence_id, "admission_receipt_id": saved.occurrence_id})
	if not presentation.ok: return presentation
	var frame := {"expected_stage": "scene", "playback_id": saved.occurrence_id, "role": "scene",
		"transaction_id": saved.occurrence_id, "presentation": presentation.value}
	var live := {"schema_version": 5, "registration_sha256": fingerprint, "entry_id": entry_id,
		"occurrence_id": saved.occurrence_id, "program_index": index, "boundary": saved.boundary,
		"ledger": {"schema_version": 2, "session_token": saved.session_token,
			"frozen_context": {"family": "scene", "session_token": saved.session_token, "registration_sha256": fingerprint},
			"entry_contexts": {LEDGER.scene_frame_key(saved.occurrence_id, entry_id): frame}, "captions": rows},
		"frontier": {"line_id": tail.beat.line_id, "publication_id": tail.publication_id} if saved.boundary == "line" else {},
		"next_operation": null}
	live["player_progress"] = progress.duplicate(true)
	return restore(live, entry_id)

static func _scene_publication_high_water(captions: Array) -> int:
	var result := 0
	for row: Dictionary in captions:
		var publication: String = row.publication_id
		if publication.begins_with("caption:") and publication.trim_prefix("caption:").is_valid_int():
			result = maxi(result, int(publication.trim_prefix("caption:")))
	return result

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
	var operation := TRAVERSAL.validate_scene_operation_path(saved, entry_id, _scene_nodes[entry_id])
	if not operation.ok: return operation
	# The operation proves saved is its selected projection. Its base was checked
	# above, so only the opposite endpoint still needs ledger/catalogue admission.
	var endpoint := _validate_scene_base(operation.value, entry_id)
	if not endpoint.ok: return endpoint
	return checked

## Pure plan only; the Run owner must authorize departure from the Challenge.
## Ordinary Next deliberately remains unable to leave a control boundary.
func prepare_scene_control_continuation() -> Dictionary:
	if family != "scene" or boundary != "control": return _fail(&"reading_next_unavailable")
	var source := _capture_scene({})
	if not source.ok: return source
	var nodes: Array = _scene_nodes[latest_entry]
	var node: Dictionary = nodes[scene_index]
	var target: int = scene_index + 1
	if node.kind != "control" or target >= nodes.size() or nodes[target].kind != "caption": return _fail(&"reading_next_path_invalid")
	var reading: Dictionary = TRAVERSAL.without_operation(source.value)
	var candidate := LEDGER.new()
	var retained: Dictionary = reading.ledger
	var copied := candidate.restore_snapshot(command_id, retained.frozen_context, manifest, registry,
		retained, retained.entry_contexts, true, true)
	if not copied.ok: return copied
	var beat: Dictionary = _caption_variants_by_line[nodes[target].line_id]
	var allocation := candidate.allocate_publication(command_id, latest_entry, scene_occurrence)
	if not allocation.ok: return allocation
	var published := candidate.publish_caption(command_id, allocation.value, beat, scene_occurrence)
	if not published.ok: return published
	var plan := {"schema_version": 3, "entry_id": latest_entry, "source_reading": reading,
		"major_checkpoint": _is_major_marker(node.marker_id),
		"path": [{"from": scene_index, "to": target}], "traversed_captions": [],
		"destination": {"kind": "line", "program_index": target, "caption": {
			"publication_id": allocation.value, "occurrence_id": scene_occurrence, "beat": beat.duplicate(true)}}}
	var checked := TRAVERSAL.validate_scene_path(plan, nodes)
	return {"ok": true, "value": plan} if checked.ok else checked

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

## Display-only current-day passage. Reconstructed rows are never published to
## the live ledger or used to authenticate gameplay commands.
func project_scene_day_history(frontier: Dictionary, _choices: Dictionary, _outcomes: Dictionary) -> Dictionary:
	if family != "scene": return _fail(&"reading_session_unavailable")
	var captured := _capture_scene(frontier)
	if not captured.ok: return captured
	var captions: Array = captured.value.ledger.captions
	if captions.is_empty(): return _fail(&"reading_frontier_invalid")
	var tail: Dictionary = captions.back()
	if tail.occurrence_id != scene_occurrence or tail.beat.owning_entry_id != latest_entry:
		return _fail(&"reading_frontier_invalid")
	var projected: Dictionary = load("res://scripts/narrative/SceneReadingHistory.gd").project_encountered(
		_scene_bundle, captured.value.player_progress.history_sections)
	var rows: Array = projected.value.captions
	if rows.is_empty() or rows.back().line_id != tail.beat.line_id or rows.back().entry_id != latest_entry:
		return _fail(&"reading_frontier_invalid")
	rows.back().publication_id = tail.publication_id
	return {"ok": true, "value": {"captions": rows, "frontier": frontier.duplicate(true),
		"session_id": command_id, "occurrence_id": scene_occurrence}}

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


## Presentation memory uses authenticated publication/occurrence identities, never
## text equality or entry name alone. The full History projection stays unchanged.
func project_scene_caption_memory(frontier: Dictionary) -> Dictionary:
	if family != "scene" or boundary != "line": return _fail(&"reading_frontier_unavailable")
	var projected := _project_scene(frontier)
	if not projected.ok: return projected
	var publications := {}
	for row: Dictionary in ledger.snapshot().captions:
		if row.occurrence_id == scene_occurrence and row.beat.owning_entry_id == latest_entry:
			publications[row.publication_id] = true
	var rows: Array[Dictionary] = []
	for row: Dictionary in projected.value.captions:
		if publications.has(row.publication_id): rows.append(row.duplicate(true))
	if rows.is_empty() or rows.back().publication_id != frontier.get("publication_id") \
			or rows.back().line_id != frontier.get("line_id"):
		return _fail(&"reading_frontier_invalid")
	return {"ok": true, "value": {"captions": rows, "frontier": frontier.duplicate(true),
		"session_id": command_id, "occurrence_id": scene_occurrence}}


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

## Membership belongs to this freshly admitted session, never a caller-supplied proof.
func validate_scene_event_anchors(anchors: Array[Dictionary]) -> Dictionary:
	if anchors.is_empty(): return {"ok": true}
	var retained := {}
	for anchor: Dictionary in anchors:
		var shape := validate_scene_anchor_shape(anchor)
		if not shape.ok: return shape
		if retained.is_empty():
			if family != "scene" or ledger == null: return _scene_anchor_failure(&"event_anchor_invalid")
			retained = ledger.snapshot()
		if anchor.catalogue_fingerprint != fingerprint or not catalogue.has(anchor.entry_id) \
				or catalogue[anchor.entry_id].content_version != anchor.content_version:
			return _scene_anchor_failure(&"event_anchor_catalogue_mismatch")
		var frame := LEDGER.resolve_scene_frame(retained.entry_contexts, anchor.session_id, anchor.entry_id)
		if not frame.ok: return _scene_anchor_failure(&"event_anchor_invalid")
		var found := false
		for row: Dictionary in retained.captions:
			if row.publication_id == anchor.publication_id and row.occurrence_id == anchor.session_id \
					and row.beat.owning_entry_id == anchor.entry_id and row.beat.line_id == anchor.line_id:
				found = true
				break
		if not found: return _scene_anchor_failure(&"event_anchor_invalid")
	return {"ok": true}

static func validate_scene_anchor_shape(anchor: Dictionary) -> Dictionary:
	var keys := ["session_id", "entry_id", "content_version", "catalogue_fingerprint", "publication_id", "line_id"]
	if anchor.size() != keys.size(): return _scene_anchor_failure(&"event_anchor_invalid")
	for key: String in keys:
		if not anchor.has(key): return _scene_anchor_failure(&"event_anchor_invalid")
	if typeof(anchor.get("content_version")) != TYPE_INT or anchor.content_version <= 0:
		return _scene_anchor_failure(&"event_anchor_invalid")
	for key: String in ["session_id", "entry_id", "catalogue_fingerprint", "publication_id", "line_id"]:
		if typeof(anchor[key]) != TYPE_STRING or anchor[key].strip_edges().is_empty(): return _scene_anchor_failure(&"event_anchor_invalid")
	return {"ok": true}

static func _scene_anchor_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}

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
		player_progress = saved.get("player_progress", {}).duplicate(true)
		_pending_checkpoint = player_progress.is_empty()
		_progress_serial = _scene_publication_high_water(saved.ledger.captions) if not player_progress.is_empty() else 0
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


