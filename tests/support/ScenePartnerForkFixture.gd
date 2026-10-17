extends RefCounted
## TEST-only registration of B's unchanged three content segments.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const CONTENT := preload("res://tests/unit/test_scene_partner_fork_template.gd")
const CONTACT := preload("res://tests/support/SceneContactFixture.gd")

static func bundle() -> Dictionary:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_reading_registration.json"))
	if not parsed.ok: return parsed
	var value: Dictionary = parsed.value
	var entry_template: Dictionary = value.entry_manifest.entries[1].duplicate(true)
	var context_template: Dictionary = value.context_registry.schemas[1].duplicate(true)
	value.schema_version = 2
	value["contact_definitions"] = CONTACT.definitions()
	value.entry_manifest.entries = []
	value.context_registry.schemas = []
	value.ids_registry.lines = []
	value.ids_registry.signals = [
		{"signal_id": "history.line.witness", "payload_fields": ["entry_id", "line_id", "playback_token", "receipt_id"]},
		{"signal_id": "thought.pass", "payload_fields": ["opportunity_id", "yes_target_id", "pass_target_id"]}]
	value.caption_registry.entries = []
	value.scene_programme.entries = []
	value.targets = []
	value.board_profiles = []
	value.challenges = []
	value.contacts = []
	var entries: Array = CONTENT.ENTRIES.duplicate()
	entries.sort()
	for id: String in entries:
		var shared: bool = id == "scene.test.partner.shared"
		var markers: Array = []
		if shared:
			markers.append({"marker_id": "scene.test.partner.expiry", "label": "scene.test.partner.expiry",
				"after_line_id": "line.scene.test.partner.shared.offer", "kind": "thought.pass",
				"payload": {"opportunity_id": "TEST.partner", "yes_target_id": "partner.sylvia", "pass_target_id": "partner.lavinia"}})
		var compiled: Dictionary = ADAPTER.compile_scene_programme(CONTENT.STORY, id, entries, markers)
		if not compiled.ok: return compiled
		var entry := entry_template.duplicate(true)
		entry.entry_id = id
		entry.atom_namespace = "atom." + id
		entry.line_namespace = "line." + id
		entry.context_schema_id = "context.scene." + id + ".v1"
		entry.locators.en = {"path": CONTENT.STORY, "label": id}
		entry.allowed_signals = ["history.line.witness", "thought.pass"] if shared else ["history.line.witness"]
		value.entry_manifest.entries.append(entry)
		var context := context_template.duplicate(true)
		context.entry_id = id
		context.schema_id = entry.context_schema_id
		context.fields.entry_id = {"const": id}
		value.context_registry.schemas.append(context)
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind != "text": continue
			lines.append({"beat_id": "beat." + event.line_id, "line_id": event.line_id, "text": event.text, "revision": "1"})
			value.ids_registry.lines.append({"line_id": event.line_id, "owning_entry_id": id})
		value.caption_registry.entries.append({"entry_id": id, "lines": lines})
		value.scene_programme.entries.append({"entry_id": id, "content_version": 1,
			"content_sha256": compiled.value.content_sha256, "program_sha256": compiled.value.program_sha256, "markers": markers})
		value.targets.append({"target_id": id.replace("scene.test.", ""), "target": {"kind": "scene", "entry_id": id,
			"label": id, "content_version": 1, "program_sha256": compiled.value.program_sha256}})
	value.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	return {"ok": true, "value": value}

static func install() -> Dictionary:
	var built := bundle()
	if not built.ok: return built
	return MANIFEST.configure_test_scene_registration(built.value)
