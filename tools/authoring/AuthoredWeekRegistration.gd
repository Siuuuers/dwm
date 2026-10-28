extends RefCounted
## Native compilation remains the authority for text, native positions and hashes.
const SOURCE_PATH := "res://data/manifests/authored_week_source.json"
const REGISTRATION_PATH := "res://data/manifests/scene_story_registration.json"
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const BASE := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const ART_PATH := "res://data/manifests/art_placements.json"
const LIBRARY := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")

static func prepare() -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(SOURCE_PATH))
	if not parsed.ok: return parsed
	var source: Dictionary = parsed.value
	# The installed catalogue supplies revision continuity only. Its old source
	# hashes must not validate the edited DTL that this export is rebuilding.
	var installed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(REGISTRATION_PATH))
	if not installed.ok: return installed
	var previous_lines := {}
	for entry: Dictionary in installed.value.caption_registry.entries:
		for line: Dictionary in entry.lines: previous_lines[line.line_id] = line
	var prepared: Dictionary = BASE.prepare()
	if not prepared.ok: return prepared
	var bundle: Dictionary = prepared.value.registration
	bundle.entry_manifest.entries = []
	bundle.context_registry.schemas = []
	bundle.ids_registry.lines = []
	bundle.ids_registry.signals = []
	bundle.caption_registry.entries = []
	bundle.scene_programme.entries = []
	bundle.scene_programme["story_days"] = {}
	bundle.targets = []
	bundle.audio_catalogue.bindings = []
	bundle.challenges = source.challenges.duplicate(true)
	bundle.board_profiles = [{"board_profile_id": "week.canonical_solo", "board_kind": "solo_challenge",
		"difficulty_id": "canonical_solo", "width": 18, "height": 18, "base_mine_count": 36,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1", "capability_policy_id": "owned_inventory_v1"}]
	var payloads := {"history.line.witness": ["entry_id", "line_id", "playback_token", "receipt_id"],
		"passage.start": ["passage_id"], "passage.finish": ["passage_id"],
		"scene.transition": ["target_id"], "thought.pass": ["opportunity_id", "yes_target_id", "pass_target_id"],
		"thought.options": ["opportunity_id", "options", "pass_target_id"],
		"challenge.playable": ["challenge_id"], "challenge.end": ["challenge_id"],
		"challenge.recall": ["challenge_id", "never_started_target_id", "unfinished_target_id", "won_target_id", "lost_target_id", "perfect_target_id"]}
	var signal_ids: Array = payloads.keys()
	signal_ids.sort()
	for signal_id: String in signal_ids:
		bundle.ids_registry.signals.append({"signal_id": signal_id, "payload_fields": payloads[signal_id]})
	var ids: Array = []
	var compiled_entries := {}
	for spec: Dictionary in source.entries: ids.append(spec.entry_id)
	for spec: Dictionary in source.entries:
		var id: String = spec.entry_id
		if typeof(spec.get("story_day")) != TYPE_INT or spec.story_day < 1 or spec.story_day > 7:
			return {"ok": false, "code": "authored_story_day_invalid"}
		bundle.scene_programme.story_days[id] = spec.story_day
		var compiled: Dictionary = ADAPTER.compile_scene_programme(spec.path, id, ids, spec.markers)
		if not compiled.ok: return compiled
		compiled_entries[id] = compiled.value
		if spec.role != "scene": return {"ok": false, "code": "authored_scene_role_required"}
		var grants: Array = ["history.line.witness"]
		for marker: Dictionary in spec.markers:
			if marker.kind not in grants: grants.append(marker.kind)
		grants.sort()
		var entry: Dictionary = {
			"entry_id": id, "role": "scene", "allowed_signals": grants,
			"atom_namespace": "atom." + id, "line_namespace": "line." + id, "content_version": 1,
			"context_schema_id": "context.scene." + id + ".v1", "visual_ids": {"required": [], "optional": []},
			"presentation_signature_schema": {"schema_version": 1, "fields": {}}}
		entry.locators = {"en": {"path": spec.path, "label": id}}
		bundle.entry_manifest.entries.append(entry)
		bundle.context_registry.schemas.append({
			"entry_id": id, "schema_id": entry.context_schema_id, "schema_version": 1,
			"fields": {"entry_id": {"const": id}, "entry_role": {"const": "scene"},
				"occurrence_id": "id", "admission_receipt_id": "id"}})
		var lines: Array = caption_lines(compiled.value.events, previous_lines)
		for line: Dictionary in lines:
			bundle.ids_registry.lines.append({"line_id": line.line_id, "owning_entry_id": id})
		bundle.caption_registry.entries.append({"entry_id": id, "lines": lines})
		bundle.scene_programme.entries.append({"entry_id": id, "content_version": 1,
			"content_sha256": compiled.value.content_sha256, "program_sha256": compiled.value.program_sha256, "markers": spec.markers})
		bundle.targets.append({"target_id": "target." + id, "target": {"kind": "scene",
			"entry_id": id, "label": id, "content_version": 1, "program_sha256": compiled.value.program_sha256}})
		bundle.audio_catalogue.bindings.append({"entry_id": id, "plan_id": BASE.MUSIC_PLAN_ID})
	bundle.entry_manifest.entry_count = ids.size()
	for rows: Array in [bundle.entry_manifest.entries, bundle.context_registry.schemas, bundle.caption_registry.entries, bundle.scene_programme.entries]:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id < b.target_id)
	bundle.challenges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.challenge_id < b.challenge_id)
	bundle.audio_catalogue.bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	var checked: Dictionary = MANIFEST.validate_scene_registration(bundle)
	if not checked.ok: return checked
	var placements: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(ART_PATH))
	if not placements.ok: return placements
	var library := prepare_dialogue_library(placements.value, bundle, compiled_entries)
	if not library.ok: return library
	return {"ok": true, "value": {"registration": bundle, "dialogue_library": library.value,
		"first_target_id": "target." + source.first_entry_id}}

## Authors select entry groups, never copy dialogue, revisions or thought roles.
## The native compiler and freshly rebuilt caption registry supply those facts.
static func prepare_dialogue_library(placements: Dictionary, registration: Dictionary,
		compiled_entries: Dictionary) -> Dictionary:
	var authored: Variant = placements.get("dialogue_library", {})
	var checkpoints: Variant = placements.get("presentation_checkpoints", {})
	var bindings: Variant = placements.get("presentation_entries", {})
	if not authored is Dictionary or not authored.get("passages", []) is Array \
			or not authored.get("condition_labels", {}) is Dictionary \
			or not checkpoints is Dictionary or not bindings is Dictionary:
		return {"ok": false, "code": &"library_authoring_invalid"}
	var bound_checkpoints := {}
	for entry_id: Variant in bindings:
		if not entry_id is String or not compiled_entries.has(entry_id):
			return {"ok": false, "code": &"library_authoring_entry_unknown", "reference": str(entry_id)}
		if not bindings[entry_id] is Array:
			return {"ok": false, "code": &"library_authoring_invalid"}
		for command: Variant in bindings[entry_id]:
			if not command is Dictionary:
				return {"ok": false, "code": &"library_authoring_invalid"}
			if command.get("kind") == "checkpoint":
				if not command.get("id") is String or not checkpoints.has(command.id):
					return {"ok": false, "code": &"library_checkpoint_invalid"}
				bound_checkpoints[command.id] = true
	var lines_by_entry := {}
	var registered_beats: Array = []
	for entry: Dictionary in registration.caption_registry.entries:
		var lines := {}
		for line: Dictionary in entry.lines:
			var beat := {"beat_id": line.beat_id, "line_id": line.line_id,
				"owning_entry_id": entry.entry_id, "presentation_signature": {
					"content_revision": line.revision, "variant_id": line.beat_id}}
			lines[line.line_id] = {"beat": beat, "text": {"en": line.text}}
			registered_beats.append(beat)
		lines_by_entry[entry.entry_id] = lines
	var passages: Array = []
	for passage: Variant in authored.get("passages", []):
		if not passage is Dictionary or not passage.get("entries") is Array:
			return {"ok": false, "code": &"library_authoring_invalid"}
		if not bound_checkpoints.has(passage.get("id")):
			return {"ok": false, "code": &"library_checkpoint_unbound", "reference": str(passage.get("id"))}
		var expanded := {"id": passage.get("id"), "title": passage.get("title"), "entries": []}
		for selector: Variant in passage.entries:
			if not selector is Dictionary or not selector.get("entry_id") is String \
					or not lines_by_entry.has(selector.entry_id) or not compiled_entries.has(selector.entry_id):
				return {"ok": false, "code": &"library_authoring_entry_unknown", "reference": str(selector)}
			var lines: Dictionary = lines_by_entry[selector.entry_id]
			for node: Dictionary in compiled_entries[selector.entry_id].nodes:
				if node.kind != "caption": continue
				var ids: Array = [node.line_id]
				if node.has("self_talk"): ids.append(node.self_talk.line_id)
				for index: int in ids.size():
					var row: Dictionary = lines[ids[index]].duplicate(true)
					row["kind"] = "caption" if index == 0 else "thought"
					row["requirements"] = selector.get("requirements", {})
					expanded.entries.append(row)
		passages.append(expanded)
	var conditions: Dictionary = authored.get("condition_labels", {})
	var checked: Dictionary = LIBRARY.prepare(passages, registered_beats, checkpoints, conditions)
	if not checked.ok: return checked
	return {"ok": true, "value": {"passages": passages, "condition_labels": conditions.duplicate(true)}}

## Native-compiled IDs and prose own the current text; the source adapter's old
## line list is provenance only. Unchanged captions retain legacy read marks.
static func caption_lines(events: Array, previous_lines: Dictionary) -> Array:
	var lines: Array = []
	for event: Dictionary in events:
		if event.kind != "text": continue
		var previous: Dictionary = previous_lines.get(event.line_id, {})
		var revision: String = previous.revision if previous.get("text") == event.text else event.text.sha256_text()
		lines.append({"beat_id": "beat." + event.line_id, "line_id": event.line_id,
			"text": event.text, "revision": revision})
	return lines
