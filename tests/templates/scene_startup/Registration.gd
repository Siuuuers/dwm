extends "res://tests/support/ScenePlayableFixture.gd"
## Editable TEST content; existing registration/compilation owners remain authoritative.
const STORY := "res://tests/fixtures/dialogic/scene_title_template.dtl"
const OPENING_TARGET := "target_b"

func _registration_bundle() -> Dictionary:
	var built: Dictionary = super._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = STORY
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(STORY, programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for row: Dictionary in bundle.targets: row.target.program_sha256 = hashes[row.target.entry_id]
	return {"ok": true, "value": bundle}
