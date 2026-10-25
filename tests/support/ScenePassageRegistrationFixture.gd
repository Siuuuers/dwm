extends "res://tests/support/ScenePlayableFixture.gd"
## TEST ONLY. Production passage boundaries and prose remain unselected.
const PASSAGE_ID := "passage.TEST.finish"
const PASSAGE_PATH := "res://tests/fixtures/dialogic/scene_passage_connected.dtl"
var source_path := PASSAGE_PATH

func _registration_bundle() -> Dictionary:
	var built: Dictionary = super._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	for kind: String in ["passage.finish", "passage.start"]:
		bundle.ids_registry.signals.append({"signal_id": kind, "payload_fields": ["passage_id"]})
	bundle.ids_registry.signals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.signal_id < b.signal_id)
	bundle.ids_registry.lines.append({"line_id": "line.scene.test.a.three", "owning_entry_id": BASE_READING.A})
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = source_path
		if entry.entry_id == BASE_READING.A:
			entry.allowed_signals = ["history.line.witness", "passage.finish", "passage.start"]
	for entry: Dictionary in bundle.caption_registry.entries:
		if entry.entry_id != BASE_READING.A: continue
		entry.lines = [
			{"beat_id": "beat.scene.test.a.one", "line_id": "line.scene.test.a.one", "text": "TEST preface.", "revision": "1"},
			{"beat_id": "beat.scene.test.a.two", "line_id": "line.scene.test.a.two", "text": "TEST passage first.", "revision": "1"},
			{"beat_id": "beat.scene.test.a.three", "line_id": "line.scene.test.a.three", "text": "TEST passage last.", "revision": "1"}]
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == BASE_READING.A:
			programme.markers = [
				{"marker_id": "scene.test.a.start", "label": "scene.test.a.start", "after_line_id": "line.scene.test.a.one", "kind": "passage.start", "payload": {"passage_id": PASSAGE_ID}},
				{"marker_id": "scene.test.a.finish", "label": "scene.test.a.finish", "after_line_id": "line.scene.test.a.three", "kind": "passage.finish", "payload": {"passage_id": PASSAGE_ID}}]
		var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(source_path, programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for row: Dictionary in bundle.targets: row.target.program_sha256 = hashes[row.target.entry_id]
	return {"ok": true, "value": bundle}
