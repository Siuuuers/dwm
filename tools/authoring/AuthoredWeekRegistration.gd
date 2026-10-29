extends RefCounted
## Native compilation remains the authority for text, native positions and hashes.
const SOURCE_PATH := "res://data/manifests/authored_week_source.json"
const REGISTRATION_PATH := "res://data/manifests/scene_story_registration.json"
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const BASE := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const LIBRARY := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")

static func prepare(source_path: String = SOURCE_PATH) -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(source_path))
	if not parsed.ok: return parsed
	var discovered: Dictionary = preload("res://tools/authoring/DtlStorySource.gd").prepare(parsed.value)
	if not discovered.ok: return discovered
	var source: Dictionary = discovered.value
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
	var parsed_sources := {}
	for spec: Dictionary in source.entries: ids.append(spec.entry_id)
	var audio := prepare_audio_catalogue(source.get("audio"), bundle.audio_catalogue, ids, source.first_entry_id)
	if not audio.ok: return audio
	bundle.audio_catalogue = audio.value
	for spec: Dictionary in source.entries:
		var id: String = spec.entry_id
		if typeof(spec.get("story_day")) != TYPE_INT or spec.story_day < 1 or spec.story_day > 7:
			return {"ok": false, "code": "authored_story_day_invalid"}
		bundle.scene_programme.story_days[id] = spec.story_day
		var compiled: Dictionary = ADAPTER._compile_scene_programme_in_registration(spec.path, id, ids, spec.markers, parsed_sources)
		if not compiled.ok: return compiled
		# Registered entries are admitted at a caption. Local jumps remain valid
		# inside an entry, but cannot stand in for its initial reading boundary.
		if compiled.value.nodes[compiled.value.label_nodes[id]].kind != "caption":
			return {"ok": false, "code": &"story_entry_requires_caption", "path": spec.path,
				"line": discovered.locations[id].line, "reference": id}
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
	bundle.entry_manifest.entry_count = ids.size()
	for rows: Array in [bundle.entry_manifest.entries, bundle.context_registry.schemas, bundle.caption_registry.entries, bundle.scene_programme.entries]:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id < b.target_id)
	bundle.challenges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.challenge_id < b.challenge_id)
	bundle.audio_catalogue.bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	var checked: Dictionary = MANIFEST.validate_scene_registration(bundle)
	if not checked.ok: return checked
	var library := prepare_dtl_library(source, bundle, compiled_entries)
	if not library.ok: return library
	return {"ok": true, "value": {"registration": bundle, "dialogue_library": library.value,
		"first_target_id": "target." + source.first_entry_id}}


## Export boundary: authors supply stable IDs and files; hashes, durations and
## catalogue records are generated once. Music/SFX placements live only in DTL.
static func prepare_audio_catalogue(authored: Variant, fallback: Dictionary,
		entry_ids: Array, first_entry_id: String) -> Dictionary:
	var owner := preload("res://scripts/data/AudioManifest.gd")
	var catalogue: Dictionary = fallback.duplicate(true)
	catalogue.schema_version = 3
	catalogue.bindings = []
	var initial_music: String = BASE.MUSIC_PLAN_ID
	if authored != null:
		if not authored is Dictionary or not authored.get("music", []) is Array \
				or not authored.get("sfx", []) is Array or not authored.get("initial_music", "") is String:
			return {"ok": false, "code": &"audio_authoring_invalid"}
		for key: String in authored:
			if key not in ["music", "sfx", "initial_music"]:
				return {"ok": false, "code": &"audio_authoring_invalid", "reference": key}
		initial_music = authored.get("initial_music", "")
		catalogue.assets = []
		catalogue.plans = []
		for kind: String in ["music", "sfx"]:
			for row: Variant in authored.get(kind, []):
				if not row is Dictionary or not owner._scene_id(row.get("id")) \
						or row.id == "stop" or not owner._scene_path(row.get("path"), 3):
					return {"ok": false, "code": &"audio_authoring_invalid"}
				for key: String in row:
					if key not in ["id", "path", "gain_db"] and not (kind == "music" and key == "entrance_ms"):
						return {"ok": false, "code": &"audio_authoring_invalid", "reference": key}
				if not FileAccess.file_exists(row.path):
					return {"ok": false, "code": &"audio_authoring_media_missing", "reference": row.path}
				var stream: AudioStream = ResourceLoader.load(row.path) as AudioStream
				if stream == null or not is_finite(stream.get_length()) or stream.get_length() <= 0.0:
					return {"ok": false, "code": &"audio_authoring_media_invalid", "reference": row.path}
				if kind == "music":
					var looping: bool = (stream is AudioStreamOggVorbis and stream.loop) \
							or (stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED) \
							or (stream is AudioStreamMP3 and stream.loop)
					if not looping: return {"ok": false, "code": &"audio_authoring_music_not_looping", "reference": row.path}
				var asset := {"asset_id": row.id, "path": row.path, "sha256": FileAccess.get_sha256(row.path),
					"duration_ms": roundi(stream.get_length() * 1000.0)}
				if row.has("gain_db"): asset["gain_db"] = row.gain_db
				catalogue.assets.append(asset)
				if kind == "music":
					var entrance: Variant = row.get("entrance_ms", 0)
					catalogue.plans.append({"plan_id": row.id, "revision": 1, "variant_id": "base",
						"ambience_asset_id": null, "music": row.id, "entrance_ms": entrance,
						"load_anchor_id": row.id + ".start", "load_anchor_ms": entrance,
						"authorial": true, "essential": false, "missing_media": "silence", "cues": []})
		catalogue.assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.asset_id < b.asset_id)
		catalogue.plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.plan_id < b.plan_id)
	for id: String in entry_ids:
		catalogue.bindings.append({"entry_id": id,
			"plan_id": initial_music if id == first_entry_id and not initial_music.is_empty() else null})
	catalogue.bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	return owner.validate_scene_catalogue(catalogue, entry_ids)

## Authors select entry groups, never copy dialogue, revisions or thought roles.
## The native compiler and freshly rebuilt caption registry supply those facts.
static func prepare_dtl_library(source: Dictionary, registration: Dictionary,
		compiled_entries: Dictionary) -> Dictionary:
	var checkpoints := {}
	var bindings := {}
	for entry_id: String in compiled_entries:
		for node: Dictionary in compiled_entries[entry_id].nodes:
			for command: Dictionary in node.get("presentation_commands", []):
				if command.kind != "checkpoint": continue
				checkpoints[command.id] = true
				if not bindings.has(entry_id): bindings[entry_id] = []
				bindings[entry_id].append(command)
	var passages: Array = []
	var passage_indices := {}
	var titles: Dictionary = source.get("library_titles", {})
	for membership: Dictionary in source.get("library_memberships", []):
		var data: Dictionary = membership.data
		var error := {"ok": false, "code": &"library_dtl_membership_invalid",
			"path": membership.path, "line": membership.line}
		for key: String in data:
			if key not in ["id", "title_key", "requirements"]: return error
		if not data.get("id") is String or data.id.is_empty() or not checkpoints.has(data.id):
			return error
		if not passage_indices.has(data.id):
			if not data.get("title_key") is String or not titles.has(data.title_key): return error
			passage_indices[data.id] = passages.size()
			passages.append({"id": data.id, "title": titles[data.title_key], "entries": []})
		var passage: Dictionary = passages[passage_indices[data.id]]
		if data.has("title_key") and (not titles.has(data.title_key) or titles[data.title_key] != passage.title):
			return error
		for previous: Dictionary in passage.entries:
			if previous.entry_id == membership.entry_id: return error
		passage.entries.append({"entry_id": membership.entry_id, "requirements": data.get("requirements", {})})
	return prepare_dialogue_library({"presentation_checkpoints": checkpoints,
		"presentation_entries": bindings, "dialogue_library": {"passages": passages,
			"condition_labels": source.get("condition_labels", {})}}, registration, compiled_entries)


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
