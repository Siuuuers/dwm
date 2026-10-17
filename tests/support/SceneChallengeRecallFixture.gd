extends RefCounted
## TEST-only five-result dispatch and later recall qualification; no production content.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const CONTACT := preload("res://tests/support/SceneContactFixture.gd")
const CHALLENGE := preload("res://tests/support/SceneChallengeFixture.gd")
const STORY := "res://tests/fixtures/dialogic/scene_challenge_recall.dtl"
const OUTCOMES := ["never_started", "unfinished", "won", "lost", "perfect"]
const START := "scene.test.recall.start"
const LATER := "scene.test.recall.later"
const CHALLENGE_ID := "TEST.recall.challenge"

static func target_id(outcome: String, later: bool = false) -> String:
	return ("recall_" if later else "echo_") + str("abcde"[OUTCOMES.find(outcome)]) + "_day1"

static func recall_payload() -> Dictionary:
	var payload := {"challenge_id": CHALLENGE_ID}
	for outcome: String in OUTCOMES: payload[outcome + "_target_id"] = target_id(outcome, true)
	return payload

static func marker(id: String, line: String, kind: String, payload: Dictionary) -> Dictionary:
	return {"marker_id": id, "label": id, "after_line_id": line, "kind": kind, "payload": payload}

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
		{"signal_id": "challenge.end", "payload_fields": ["challenge_id"]},
		{"signal_id": "challenge.playable", "payload_fields": ["challenge_id"]},
		{"signal_id": "challenge.recall", "payload_fields": ["challenge_id", "never_started_target_id", "unfinished_target_id", "won_target_id", "lost_target_id", "perfect_target_id"]},
		{"signal_id": "history.line.witness", "payload_fields": ["entry_id", "line_id", "playback_token", "receipt_id"]},
		{"signal_id": "scene.transition", "payload_fields": ["target_id"]}]
	value.caption_registry.entries = []
	value.scene_programme.entries = []
	value.targets = []
	value.board_profiles = []
	value.challenges = []
	value.contacts = []
	var entries: Array = [START, LATER]
	var targets := {}
	for outcome: String in OUTCOMES:
		entries.append("scene.test." + target_id(outcome))
		entries.append("scene.test." + target_id(outcome, true))
		targets[outcome] = target_id(outcome)
	value.board_profiles = CHALLENGE.bundle().board_profiles
	value.challenges = [{"challenge_id": CHALLENGE_ID, "entry_id": START,
		"playable_marker_id": START + ".playable", "end_marker_id": START + ".end",
		"board_profile_id": "TEST.profile", "targets": targets}]
	entries.sort()
	value.entry_manifest.entry_count = entries.size()
	for id: String in entries:
		var markers: Array = []
		if id == START:
			markers = [marker(START + ".playable", "line." + START + ".one", "challenge.playable", {"challenge_id": CHALLENGE_ID}),
				marker(START + ".end", "line." + START + ".two", "challenge.end", {"challenge_id": CHALLENGE_ID})]
		elif id == LATER:
			markers = [marker(LATER + ".recall", "line." + LATER + ".one", "challenge.recall", recall_payload())]
		elif id.begins_with("scene.test.echo_"):
			markers = [marker(id + ".next", "line." + id + ".one", "scene.transition", {"target_id": "recall.later"})]
		var compiled: Dictionary = ADAPTER.compile_scene_programme(STORY, id, entries, markers)
		if not compiled.ok: return compiled
		var entry := entry_template.duplicate(true)
		entry.entry_id = id
		entry.atom_namespace = "atom." + id
		entry.line_namespace = "line." + id
		entry.context_schema_id = "context.scene." + id + ".v1"
		entry.locators.en = {"path": STORY, "label": id}
		entry.allowed_signals = ["history.line.witness"]
		for registered: Dictionary in markers:
			if not registered.kind in entry.allowed_signals: entry.allowed_signals.append(registered.kind)
		entry.allowed_signals.sort()
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
