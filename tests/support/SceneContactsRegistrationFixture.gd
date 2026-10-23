extends "res://tests/support/ScenePlayableFixture.gd"
## TEST-only registration; immutable selection occurs before FINAL Bootstrap.
const CONTACT_PATH := "res://tests/fixtures/dialogic/scene_contacts_connected.dtl"

func _registration_bundle() -> Dictionary:
	var built: Dictionary = super._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	bundle.contact_definitions.replies = []
	bundle.ids_registry.signals.append({"signal_id": "contact.enter", "payload_fields": ["contact_event_id"]})
	bundle.ids_registry.signals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.signal_id < b.signal_id)
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		entry.locators.en.path = CONTACT_PATH
		if entry.entry_id == BASE_READING.A:
			entry.allowed_signals = ["contact.enter", "history.line.witness"]
	var hashes := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == BASE_READING.A:
			programme.markers = [{"marker_id": "scene.test.a.contact", "label": "scene.test.a.contact",
				"after_line_id": "line.scene.test.a.one", "kind": "contact.enter",
				"payload": {"contact_event_id": "contact_test"}}]
		var compiled: Dictionary = RUNTIME_ADAPTER.compile_scene_programme(CONTACT_PATH, programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		hashes[programme.entry_id] = programme.program_sha256
	for row: Dictionary in bundle.targets: row.target.program_sha256 = hashes[row.target.entry_id]
	return {"ok": true, "value": bundle}
