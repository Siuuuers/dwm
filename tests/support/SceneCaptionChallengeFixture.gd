extends "res://tests/support/ScenePlayableFixture.gd"
## Same real owners and profile, with only the authored one-caption binding changed.
const CAPTION_PATH := "res://tests/fixtures/dialogic/scene_caption_challenge.dtl"

func _registration_bundle() -> Dictionary:
	var built: Dictionary = super._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = CAPTION_PATH
	bundle.ids_registry.lines = bundle.ids_registry.lines.filter(func(row: Dictionary) -> bool: return row.line_id != "line.scene.test.b.two")
	for captions: Dictionary in bundle.caption_registry.entries:
		if captions.entry_id == BASE_READING.B:
			captions.lines = captions.lines.filter(func(row: Dictionary) -> bool: return row.line_id != "line.scene.test.b.two")
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == BASE_READING.B:
			programme.markers[1].after_line_id = "line.scene.test.b.one"
		var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(CAPTION_PATH, programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for target: Dictionary in bundle.targets:
		target.target.program_sha256 = hashes[target.target.entry_id]
	return {"ok": true, "value": bundle}
