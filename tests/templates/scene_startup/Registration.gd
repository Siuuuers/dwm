extends "res://tests/support/ScenePlayableFixture.gd"
## Editable TEST content; existing registration/compilation owners remain authoritative.
const STORY := "res://tests/fixtures/dialogic/scene_title_template.dtl"
const OPENING_TARGET := "target_b"

func _registration_bundle() -> Dictionary:
	var built: Dictionary = super._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	bundle.schema_version = 3
	var bindings: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		bindings.append({"entry_id": entry.entry_id, "plan_id": null})
	bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle["audio_catalogue"] = {"kind": "scene_audio_catalogue", "schema_version": 1,
		"assets": [], "plans": [], "bindings": bindings}
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = STORY
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(STORY, programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		# Keep prose owned by DTL; retain registered semantic IDs and beat ownership.
		var text_by_id := {}
		for event: Dictionary in compiled.value.events:
			if event.kind == "text": text_by_id[event.line_id] = event.text
		for entry: Dictionary in bundle.caption_registry.entries:
			if entry.entry_id != programme.entry_id: continue
			for line: Dictionary in entry.lines:
				if not text_by_id.has(line.line_id): return {"ok": false, "code": &"TEST.template_line_missing"}
				line.text = text_by_id[line.line_id]
				line.revision = str(line.text).sha256_text()
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for row: Dictionary in bundle.targets: row.target.program_sha256 = hashes[row.target.entry_id]
	return {"ok": true, "value": bundle}
