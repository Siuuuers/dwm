extends RefCounted
## Offline TEST authoring preparation; does not install content or start a Run.
const SEQUENCE := preload("res://tools/authoring/SceneSequenceAuthoring.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const DAY_DIRECTORY := "res://tests/fixtures/dialogic/"
const CONTENT_VERSION := 1
# This explicit list owns ordinary-next ordering, independently of registry sorting.
const ORDER_PATH := "res://tests/templates/scene_sequence/seven_day_order.json"
const ENDING_PATH := DAY_DIRECTORY + "Day7.dtl"
const ENDING_ID := "ending.alone.normal"
const MUSIC_PATH := "res://audio/bgm/story_theme.ogg"
const MUSIC_ASSET_ID := "template.shared.music"
const MUSIC_PLAN_ID := "template.shared.music.plan"
const STRICT := preload("res://scripts/validation/StrictJson.gd")

static func prepare() -> Dictionary:
	# Scene music has its own replaceable file; Title keeps menu_theme.ogg.
	# Native import owns duration; original source bytes own media identity.
	if not FileAccess.file_exists(MUSIC_PATH):
		return {"ok": false, "code": "template_music_missing"}
	var soundtrack: AudioStreamOggVorbis = ResourceLoader.load(MUSIC_PATH) as AudioStreamOggVorbis
	if soundtrack == null or not soundtrack.loop:
		return {"ok": false, "code": "template_music_invalid"}
	var duration_seconds: float = soundtrack.get_length()
	if not is_finite(duration_seconds) or duration_seconds <= 0.0:
		return {"ok": false, "code": "template_music_invalid"}
	var duration_ms: int = roundi(duration_seconds * 1000.0)
	var configured: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(ORDER_PATH))
	if not configured.ok: return configured
	var order: Array = configured.value.order
	var bindings: Dictionary = configured.value.bindings
	var all_ids: Array = order.duplicate()
	all_ids.append(ENDING_ID)
	var bundle := {"kind": "scene_reading_registration", "schema_version": 3,
		"entry_manifest": {"kind": "dialogic_entries", "schema_version": 2,
			"default_locale": "en", "locales": ["en"], "entry_count": all_ids.size(), "entries": []},
		"context_registry": {"kind": "dialogic_frozen_context_registry", "schema_version": 1, "schemas": []},
		"ids_registry": {"kind": "scene_ids_registry", "schema_version": 1, "lines": [],
			"signals": [{"signal_id": "history.line.witness",
				"payload_fields": ["entry_id", "line_id", "playback_token", "receipt_id"]},
				{"signal_id": "scene.transition", "payload_fields": ["target_id"]}]},
		"caption_registry": {"kind": "scene_caption_registry", "schema_version": 1, "entries": []},
		"scene_programme": {"kind": "scene_programme", "schema_version": 1, "entries": [], "story_days": {}},
		"targets": [], "board_profiles": [], "challenges": [], "contacts": [],
		"contact_definitions": {"kind": "scene_contact_definitions", "schema_version": 1, "messages": [], "replies": []},
		"audio_catalogue": {"kind": "scene_audio_catalogue", "schema_version": 2,
			"assets": [{"asset_id": MUSIC_ASSET_ID, "path": MUSIC_PATH,
				"sha256": FileAccess.get_sha256(MUSIC_PATH), "duration_ms": duration_ms}],
			"plans": [{"plan_id": MUSIC_PLAN_ID, "revision": 1, "variant_id": "base",
				"ambience_asset_id": null, "entrance_ms": 0, "load_anchor_id": "template.music.start",
				"load_anchor_ms": 0, "authorial": true, "essential": false,
				"missing_media": "silence", "music": MUSIC_ASSET_ID, "cues": []}], "bindings": []}}
	for index in range(order.size()):
		var id: String = order[index]
		bundle.scene_programme.story_days[id] = index + 1
		var path: String = DAY_DIRECTORY + id + ".dtl"
		var markers: Array = []
		var grants := ["history.line.witness"]
		var next_marker := ""
		if index < order.size() - 1:
			next_marker = id + ".next"
			markers.append({"marker_id": next_marker, "label": next_marker,
				"after_line_id": "line." + id + ".two", "kind": "scene.transition",
				"payload": {"target_id": "target." + order[index + 1]}})
			grants.append("scene.transition")
		else:
			markers.append({"marker_id": "Day7.end", "label": "Day7.end",
				"after_line_id": "line.Day7.two", "kind": "scene.transition",
				"payload": {"target_id": "target." + ENDING_ID}})
			grants.append("scene.transition")
		var compiled: Dictionary = ADAPTER.compile_scene_programme(path, id, all_ids, markers)
		if not compiled.get("ok", false): return compiled
		bundle.entry_manifest.entries.append({"entry_id": id, "role": "scene",
			"allowed_signals": grants, "atom_namespace": "atom." + id,
			"line_namespace": "line." + id, "content_version": CONTENT_VERSION,
			"context_schema_id": "context.scene." + id + ".v1",
			"locators": {"en": {"path": path, "label": id}},
			"visual_ids": {"required": [], "optional": []},
			"presentation_signature_schema": {"schema_version": 1, "fields": {}}})
		bundle.context_registry.schemas.append({"entry_id": id,
			"schema_id": "context.scene." + id + ".v1", "schema_version": 1,
			"fields": {"entry_id": {"const": id}, "entry_role": {"const": "scene"},
				"occurrence_id": "id", "admission_receipt_id": "id"}})
		# Captions come from the compiler, so replacing DTL text has one source of truth.
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind == "text":
				bundle.ids_registry.lines.append({"line_id": event.line_id, "owning_entry_id": id})
				lines.append({"beat_id": "beat." + event.line_id, "line_id": event.line_id,
					"text": event.text, "revision": "1"})
		bundle.caption_registry.entries.append({"entry_id": id, "lines": lines})
		bundle.scene_programme.entries.append({"entry_id": id, "content_version": CONTENT_VERSION,
			"content_sha256": compiled.value.content_sha256,
			"program_sha256": compiled.value.program_sha256, "markers": markers})
		bundle.targets.append({"target_id": "target." + id, "target": {"kind": "scene",
			"entry_id": id, "label": id, "content_version": CONTENT_VERSION,
			"program_sha256": compiled.value.program_sha256}})
	# Use the real registered ending role/context, with a dedicated replaceable TEST locator.
	var legacy: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/dialogic_entries.json"))
	var contexts: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/dialogic_contexts.json"))
	if not legacy.ok: return legacy
	if not contexts.ok: return contexts
	var ending_entry: Dictionary = {}
	for entry: Dictionary in legacy.value.entries:
		if entry.entry_id == ENDING_ID: ending_entry = entry.duplicate(true)
	if ending_entry.is_empty(): return {"ok": false, "code": "ending_registration_missing"}
	ending_entry.locators = {"en": {"path": ENDING_PATH, "label": ENDING_ID}}
	bundle.entry_manifest.entries.append(ending_entry)
	bundle.scene_programme.story_days[ENDING_ID] = order.size()
	for context: Dictionary in contexts.value.schemas:
		if context.entry_id == ENDING_ID: bundle.context_registry.schemas.append(context.duplicate(true))
	var ending: Dictionary = ADAPTER.compile_scene_programme(ENDING_PATH, ENDING_ID, all_ids, [])
	if not ending.ok: return ending
	var ending_lines: Array = []
	for event: Dictionary in ending.value.events:
		if event.kind == "text":
			bundle.ids_registry.lines.append({"line_id": event.line_id, "owning_entry_id": ENDING_ID})
			ending_lines.append({"beat_id": "beat." + event.line_id, "line_id": event.line_id, "text": event.text, "revision": "1"})
	bundle.caption_registry.entries.append({"entry_id": ENDING_ID, "lines": ending_lines})
	bundle.scene_programme.entries.append({"entry_id": ENDING_ID, "content_version": ending_entry.content_version,
		"content_sha256": ending.value.content_sha256, "program_sha256": ending.value.program_sha256, "markers": []})
	bundle.targets.append({"target_id": "target." + ENDING_ID, "target": {"kind": "ending",
		"entry_id": ENDING_ID, "label": ENDING_ID, "content_version": ending_entry.content_version, "program_sha256": ending.value.program_sha256}})
	for id: String in all_ids: bundle.audio_catalogue.bindings.append({"entry_id": id, "plan_id": MUSIC_PLAN_ID})
	# Closed registration tables require canonical sorting; story order remains ORDER.
	for rows: Array in [bundle.entry_manifest.entries, bundle.context_registry.schemas,
			bundle.caption_registry.entries, bundle.scene_programme.entries]:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id < b.target_id)
	var result: Dictionary = SEQUENCE.build(order, bundle, bindings)
	if not result.get("ok", false): return result
	return result

