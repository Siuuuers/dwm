extends RefCounted
## Offline TEST authoring preparation; does not install content or start a Run.
const SEQUENCE := preload("res://tools/authoring/SceneSequenceAuthoring.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PATH := "res://tests/fixtures/dialogic/seven_day_templates.dtl"
# This explicit list owns ordinary-next ordering, independently of registry sorting.
const ORDER := ["Day1", "Day2", "Day3", "Day4", "Day5", "Day6", "Day7"]

static func prepare() -> Dictionary:
	var bundle := {"kind": "scene_reading_registration", "schema_version": 1,
		"entry_manifest": {"kind": "dialogic_entries", "schema_version": 2,
			"default_locale": "en", "locales": ["en"], "entry_count": ORDER.size(), "entries": []},
		"context_registry": {"kind": "dialogic_frozen_context_registry", "schema_version": 1, "schemas": []},
		"ids_registry": {"kind": "scene_ids_registry", "schema_version": 1, "lines": [],
			"signals": [{"signal_id": "history.line.witness",
				"payload_fields": ["entry_id", "line_id", "playback_token", "receipt_id"]},
				{"signal_id": "scene.transition", "payload_fields": ["target_id"]}]},
		"caption_registry": {"kind": "scene_caption_registry", "schema_version": 1, "entries": []},
		"scene_programme": {"kind": "scene_programme", "schema_version": 1, "entries": []},
		"targets": [], "board_profiles": [], "challenges": [], "contacts": []}
	var bindings := {}
	for index in range(ORDER.size()):
		var id: String = ORDER[index]
		var markers: Array = []
		var grants := ["history.line.witness"]
		var next_marker := ""
		if index < ORDER.size() - 1:
			next_marker = id + ".next"
			markers.append({"marker_id": next_marker, "label": next_marker,
				"after_line_id": "line." + id + ".one", "kind": "scene.transition",
				"payload": {"target_id": "target." + ORDER[index + 1]}})
			grants.append("scene.transition")
		bindings[id] = {"target_id": "target." + id, "next_marker_id": next_marker}
		var compiled: Dictionary = ADAPTER.compile_scene_programme(PATH, id, ORDER, markers)
		if not compiled.get("ok", false): return compiled
		bundle.entry_manifest.entries.append({"entry_id": id, "role": "scene",
			"allowed_signals": grants, "atom_namespace": "atom." + id,
			"line_namespace": "line." + id, "content_version": 1,
			"context_schema_id": "context.scene." + id + ".v1",
			"locators": {"en": {"path": PATH, "label": id}},
			"visual_ids": {"required": [], "optional": []},
			"presentation_signature_schema": {"schema_version": 1, "fields": {}}})
		bundle.context_registry.schemas.append({"entry_id": id,
			"schema_id": "context.scene." + id + ".v1", "schema_version": 1,
			"fields": {"entry_id": {"const": id}, "entry_role": {"const": "scene"},
				"occurrence_id": "id", "admission_receipt_id": "id"}})
		bundle.ids_registry.lines.append({"line_id": "line." + id + ".one", "owning_entry_id": id})
		# Captions come from the compiler, so replacing DTL text has one source of truth.
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind == "text":
				lines.append({"beat_id": "beat." + id + ".one", "line_id": event.line_id,
					"text": event.text, "revision": "1"})
		bundle.caption_registry.entries.append({"entry_id": id, "lines": lines})
		bundle.scene_programme.entries.append({"entry_id": id, "content_version": 1,
			"content_sha256": compiled.value.content_sha256,
			"program_sha256": compiled.value.program_sha256, "markers": markers})
		bundle.targets.append({"target_id": "target." + id, "target": {"kind": "scene",
			"entry_id": id, "label": id, "content_version": 1,
			"program_sha256": compiled.value.program_sha256}})
	# Closed registration tables require canonical sorting; story order remains ORDER.
	for rows: Array in [bundle.entry_manifest.entries, bundle.context_registry.schemas,
			bundle.caption_registry.entries, bundle.scene_programme.entries]:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target_id < b.target_id)
	var result: Dictionary = SEQUENCE.build(ORDER, bundle, bindings)
	if not result.get("ok", false): return result
	# Deliberately outside the closed registration. Day7's return is NOT completion.
	result.value["terminal_dependency"] = {
		"status": "pending", "source_entry_id": "Day7", "after_line_id": "line.Day7.one",
		"required": "authenticated_registered_ending_connection"}
	return result
