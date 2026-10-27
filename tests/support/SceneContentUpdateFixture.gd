extends RefCounted
## One TEST-authored graph, compiled independently before each FINAL process.
## Old/current DTL uses the same physical path and stable authored identities.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const CONTACT := preload("res://tests/support/SceneContactFixture.gd")
const CHALLENGE := preload("res://tests/support/SceneChallengeFixture.gd")
const STORY := "res://tests/fixtures/dialogic/_scene_content_update.dtl"
const CASES := ["wording", "deleted_line", "deleted_checkpoint", "history", "active_board", "transfer_active", "transfer_terminal", "resolved_unfinished", "completed_appended", "completed_deleted", "invalid_choice", "invalid_choice_missing_default"]
const A := "TEST.update.A"
const B := "TEST.update.B"
const FINISH := "passage.TEST.content_update"

static func selected_case() -> String:
	return OS.get_environment("DWM_CONTENT_UPDATE_CASE")

static func completed_case(case_id: String) -> bool:
	return case_id in ["completed_appended", "completed_deleted"]

static func board_case(case_id: String) -> bool:
	return case_id in ["active_board", "transfer_active", "transfer_terminal", "resolved_unfinished"]

static func line(entry: String, suffix: String) -> String:
	return "line." + entry + "." + suffix

static func install(updated: bool, case_id: String) -> Dictionary:
	if case_id not in CASES: return {"ok": false, "code": &"TEST.content_update_case_required"}
	if updated and case_id in ["invalid_choice", "invalid_choice_missing_default"]:
		# Keep shipped registration fixed. Only the second case edits DTL bytes,
		# so the required default fails when execution first needs its passage.
		var installed := install(false, case_id)
		if not installed.ok or case_id == "invalid_choice": return installed
		var source := FileAccess.get_file_as_string(STORY)
		var start := source.find("label update.two\n")
		var finish := source.find("label update.three\n", start)
		if start < 0 or finish < 0: return {"ok": false, "code": &"TEST.default_passage_missing"}
		source = source.substr(0, start) + source.substr(finish)
		var edited := FileAccess.open(STORY, FileAccess.WRITE)
		if edited == null: return {"ok": false, "code": &"TEST.content_update_write_failed"}
		edited.store_string(source)
		edited.close()
		return installed
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_reading_registration.json"))
	if not parsed.ok: return parsed
	var bundle: Dictionary = parsed.value
	var entry_template: Dictionary = bundle.entry_manifest.entries[1].duplicate(true)
	var context_template: Dictionary = bundle.context_registry.schemas[1].duplicate(true)
	bundle.schema_version = 2
	bundle["contact_definitions"] = CONTACT.definitions()
	bundle.entry_manifest.entries = []
	bundle.context_registry.schemas = []
	bundle.ids_registry.lines = []
	bundle.ids_registry.signals = [
		{"signal_id": "challenge.end", "payload_fields": ["challenge_id"]},
		{"signal_id": "challenge.playable", "payload_fields": ["challenge_id"]},
		{"signal_id": "history.line.witness", "payload_fields": ["entry_id", "line_id", "playback_token", "receipt_id"]},
		{"signal_id": "passage.finish", "payload_fields": ["passage_id"]},
		{"signal_id": "passage.start", "payload_fields": ["passage_id"]},
		{"signal_id": "scene.transition", "payload_fields": ["target_id"]},
		{"signal_id": "thought.pass", "payload_fields": ["opportunity_id", "yes_target_id", "pass_target_id"]}]
	bundle.caption_registry.entries = []
	bundle.scene_programme.entries = []
	bundle.scene_programme["story_days"] = {}
	bundle.targets = []
	bundle.board_profiles = CHALLENGE.bundle().board_profiles
	bundle.challenges = []
	bundle.contacts = []
	var entries: Array[String] = ["Day1", "update.one", "update.two", "update.three", "update.four", "update.a", "update.after_a", "update.b", "update.end"]
	var definitions := {}
	var source := "return\n\n"
	for id: String in entries:
		var captions: Array = ["anchor", "middle", "last"]
		if id in ["update.a", "update.b"]: captions = ["cue", "following"]
		var remove_a: bool = updated and case_id in ["transfer_active", "transfer_terminal", "resolved_unfinished"] and id == "update.a"
		if updated and id == "update.one" and case_id in ["deleted_line", "deleted_checkpoint"]:
			captions.erase("middle")
			if case_id == "deleted_checkpoint": captions.erase("anchor")
		if updated and id == "update.two" and case_id == "history": captions.erase("middle")
		if updated and ((id == "update.one" and case_id == "wording") or (id == "update.four" and case_id == "history")):
			captions.insert(1, "inserted_before")
			captions.insert(captions.size() - 1, "inserted_after")
		if updated and id == "update.end":
			if case_id == "completed_appended": captions.append("appended")
			elif case_id == "completed_deleted": captions.erase("last")
		var markers: Array = []
		var last: String = line(id, str(captions.back()))
		if id in ["Day1", "update.one", "update.two", "update.three"]:
			var destination: String = {"Day1": "update.one", "update.one": "update.two", "update.two": "update.three", "update.three": "update.four"}[id]
			markers.append({"marker_id": id + ".choice", "label": id + ".choice", "after_line_id": last,
				"kind": "thought.pass", "payload": {"opportunity_id": "TEST.choice." + id,
				"yes_target_id": "target." + destination + ".yes", "pass_target_id": "target." + destination}})
		elif remove_a:
			# Transfer tests preserve the saved cue and held marker identity. The
			# updated marker leaves A without closing its retained physical board;
			# B must bind that exact board, not benefit from deleted-ID recovery.
			markers = [{"marker_id": id + ".playable", "label": id + ".playable", "after_line_id": line(id, "cue"),
				"kind": "scene.transition", "payload": {"target_id": "target.update.after_a"}}]
		elif id in ["update.a", "update.b"]:
			var challenge_id := A if id == "update.a" else B
			markers = [{"marker_id": id + ".playable", "label": id + ".playable", "after_line_id": line(id, "cue"),
				"kind": "challenge.playable", "payload": {"challenge_id": challenge_id}},
				{"marker_id": id + ".end", "label": id + ".end", "after_line_id": last,
				"kind": "challenge.end", "payload": {"challenge_id": challenge_id}}]
			var outcomes := {}
			for result: String in ["never_started", "unfinished", "won", "lost", "perfect"]:
				outcomes[result] = "target.update.after_a" if id == "update.a" else "target.update.end"
			bundle.challenges.append({"challenge_id": challenge_id, "entry_id": id, "playable_marker_id": id + ".playable",
				"end_marker_id": id + ".end", "board_profile_id": "TEST.profile", "targets": outcomes})
		elif id == "update.end" and completed_case(case_id):
			markers = [{"marker_id": id + ".start", "label": id + ".start", "after_line_id": line(id, "anchor"),
				"kind": "passage.start", "payload": {"passage_id": FINISH}},
				{"marker_id": id + ".finish", "label": id + ".finish", "after_line_id": last,
				"kind": "passage.finish", "payload": {"passage_id": FINISH}}]
		elif id != "update.end":
			var destination := "update.after_a" if id == "update.a" else ("update.b" if id == "update.after_a" else "update.a")
			markers.append({"marker_id": id + ".next", "label": id + ".next", "after_line_id": last,
				"kind": "scene.transition", "payload": {"target_id": "target." + destination}})
		source += "label " + id + "\n"
		var revisions := {}
		for suffix: String in captions:
			var changed: bool = updated and ((id == "Day1" and suffix == "middle") or (id == "update.one" and suffix == "middle") or (id == "update.three" and suffix == "middle"))
			var text := "TEST " + id + " " + suffix + (" revised." if changed else ".")
			var line_id := line(id, suffix)
			revisions[line_id] = "2" if changed else "1"
			source += "\\" + text + " #id:" + line_id + "\n"
			for marker: Dictionary in markers:
				if marker.after_line_id == line_id: source += "label " + marker.label + "\n"
		source += "return\n\n"
		definitions[id] = {"markers": markers, "revisions": revisions}
	var file := FileAccess.open(STORY, FileAccess.WRITE)
	if file == null: return {"ok": false, "code": &"TEST.content_update_write_failed"}
	file.store_string(source)
	file.close()
	entries.sort()
	bundle.entry_manifest.entry_count = entries.size()
	for id: String in entries:
		var markers: Array = definitions[id].markers
		var compiled := ADAPTER.compile_scene_programme(STORY, id, entries, markers)
		if not compiled.ok: return compiled
		var entry: Dictionary = entry_template.duplicate(true)
		entry.entry_id = id
		entry.atom_namespace = "atom." + id
		entry.line_namespace = "line." + id
		entry.context_schema_id = "context.scene." + id + ".v1"
		entry.locators.en = {"path": STORY, "label": id}
		entry.allowed_signals = ["history.line.witness"]
		for marker: Dictionary in markers:
			if marker.kind not in entry.allowed_signals: entry.allowed_signals.append(marker.kind)
		entry.allowed_signals.sort()
		bundle.entry_manifest.entries.append(entry)
		var context: Dictionary = context_template.duplicate(true)
		context.entry_id = id
		context.schema_id = entry.context_schema_id
		context.fields.entry_id = {"const": id}
		bundle.context_registry.schemas.append(context)
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind != "text": continue
			lines.append({"beat_id": "beat." + event.line_id, "line_id": event.line_id, "text": event.text,
				"revision": definitions[id].revisions[event.line_id]})
			bundle.ids_registry.lines.append({"line_id": event.line_id, "owning_entry_id": id})
		bundle.caption_registry.entries.append({"entry_id": id, "lines": lines})
		bundle.scene_programme.entries.append({"entry_id": id, "content_version": 1,
			"content_sha256": compiled.value.content_sha256, "program_sha256": compiled.value.program_sha256, "markers": markers})
		bundle.scene_programme.story_days[id] = 1
		bundle.targets.append({"target_id": "target." + id, "target": {"kind": "scene", "entry_id": id,
			"label": id, "content_version": 1, "program_sha256": compiled.value.program_sha256}})
		# Distinct authored choice targets may converge on the same next entry.
		# The choice owner still persists yes/pass independently of this route.
		if id in ["update.one", "update.two", "update.three", "update.four"]:
			bundle.targets.append({"target_id": "target." + id + ".yes", "target": bundle.targets.back().target.duplicate(true)})
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	return MANIFEST.configure_test_scene_registration(bundle)
