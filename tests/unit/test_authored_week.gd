extends "res://addons/gut/test.gd"
const WEEK := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")

func test_direct_dtl_edits_preserve_ids_and_only_revise_changed_text() -> void:
	var original := "label authoring.test\n\\TEST first. #id:line.authoring.first\n\\TEST second. #id:line.authoring.second\nreturn\n"
	var compiled: Dictionary = ADAPTER._compile_scene_programme_source(original, "authoring.test", ["authoring.test"], [])
	assert_true(compiled.ok)
	if not compiled.ok: return
	var previous := {
		"line.authoring.first": {"line_id": "line.authoring.first", "text": "TEST first.", "revision": "1"},
		"line.authoring.second": {"line_id": "line.authoring.second", "text": "TEST second.", "revision": "retained-revision"}}
	var unchanged: Array = WEEK.caption_lines(compiled.value.events, previous)
	assert_eq(unchanged[0].revision, "1", "legacy witnesses keep their unchanged revision")
	assert_eq(unchanged[1].revision, "retained-revision")
	var edited := original.replace("TEST first.", "TEST revised first.").replace(
		"\\TEST second.", "\\TEST inserted. #id:line.authoring.inserted\n\\TEST second.")
	compiled = ADAPTER._compile_scene_programme_source(edited, "authoring.test", ["authoring.test"], [])
	assert_true(compiled.ok)
	if not compiled.ok: return
	var lines: Array = WEEK.caption_lines(compiled.value.events, previous)
	assert_eq(lines.map(func(line: Dictionary) -> String: return line.line_id),
		["line.authoring.first", "line.authoring.inserted", "line.authoring.second"])
	assert_eq(lines[0].revision, "TEST revised first.".sha256_text())
	assert_eq(lines[1].revision, "TEST inserted.".sha256_text())
	assert_eq(lines[2], unchanged[1], "insertion does not rename or unread a later unchanged caption")
	var exported := {}
	for line: Dictionary in lines: exported[line.line_id] = line
	assert_eq(WEEK.caption_lines(compiled.value.events, exported), lines, "repeat export is stable")
	for invalid: String in [original.replace(" #id:line.authoring.first", ""),
			original.replace("line.authoring.second", "line.authoring.first")]:
		assert_false(ADAPTER._compile_scene_programme_source(invalid, "authoring.test", ["authoring.test"], []).ok,
			"native compiler still rejects missing or duplicate stable identity")

func test_authored_week_compiles_and_preserves_conditional_branch_bindings() -> void:
	var prepared: Dictionary = WEEK.prepare()
	assert_true(prepared.get("ok", false), str(prepared.get("code", "")))
	if not prepared.get("ok", false): return
	var writer := preload("res://scripts/validation/CanonicalJsonWriter.gd")
	var parsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json"))
	assert_true(parsed.ok, "installed registration is strict JSON")
	if not parsed.ok: return
	var library: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string("res://data/manifests/dialogue_library_registration.json"))
	assert_true(library.ok, "installed library is strict JSON")
	if not library.ok: return
	assert_eq(library.value, prepared.value.dialogue_library, "installed library matches current native DTL export")
	var bundle: Dictionary = parsed.value
	assert_true(writer.stringify(bundle).value == writer.stringify(prepared.value.registration).value,
		"installed JSON matches the native-generated registration")
	var checked: Dictionary = CONTRACT.validate_bundle_structure(bundle)
	assert_true(checked.ok, str(checked.get("code", "")))
	assert_eq(prepared.value.first_target_id, "target.Day1")
	var entries := {}
	for entry: Dictionary in bundle.scene_programme.entries: entries[entry.entry_id] = entry
	assert_eq(entries.size(), 92)
	assert_eq(bundle.challenges.size(), 9, "mutually exclusive Day3 and clipboard branches share the seven-day journey")
	var paths := {}
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		paths[entry.entry_id] = entry.locators.en.path
		labels.append(entry.entry_id)
	var paired_offers := 0
	for entry: Dictionary in bundle.scene_programme.entries:
		for marker: Dictionary in entry.markers:
			if marker.kind not in ["thought.pass", "thought.options"]: continue
			var compiled: Dictionary = ADAPTER.compile_scene_programme(paths[entry.entry_id], entry.entry_id, labels, entry.markers)
			assert_true(compiled.ok, entry.entry_id)
			if not compiled.ok: return
			var control: int = compiled.value.label_nodes[marker.label]
			var preceding: Dictionary = compiled.value.nodes[control - 1]
			assert_eq(preceding.line_id, marker.after_line_id, "offer remains anchored to its paired caption frontier")
			assert_true(preceding.has("self_talk"), "each shipped offer has the selected testing thought")
			paired_offers += 1
	assert_eq(paired_offers, 15)
	var threshold: Dictionary = entries["Day2.result.D"].markers[0]
	assert_eq(threshold.kind, "thought.options")
	assert_eq(threshold.payload.pass_target_id, "target.Day2.threshold.benchmark")
	assert_eq(threshold.payload.options.size(), 2)
	var cheek: Dictionary = entries.Day5.markers[0].payload
	assert_eq(cheek.challenge_id, "Day2.challenge")
	assert_eq(cheek.lost_target_id, "target.Day5.cheek")
	assert_eq(cheek.never_started_target_id, "target.Day5.impulse")
	for branch: String in ["crossed", "untouched"]:
		var recall: Dictionary = entries["Day7." + branch + ".D"].markers[0].payload
		assert_eq(recall.challenge_id, "Day1.challenge")
		assert_ne(recall.lost_target_id, recall.never_started_target_id)
	for challenge: Dictionary in bundle.challenges:
		var markers: Array = entries[challenge.entry_id].markers
		assert_eq(markers.size(), 2)
		assert_eq(markers[0].kind, "challenge.playable")
		assert_eq(markers[1].kind, "challenge.end")
		assert_eq(markers[0].after_line_id, markers[1].after_line_id, "one real cue caption, no invented intermediate witness")
	var ending: Dictionary = bundle.entry_manifest.entries.back()
	assert_eq(ending.entry_id, "ending.alone.normal")
	assert_eq(ending.role, "scene")
	var passages: Dictionary = preload("res://scripts/narrative/ScenePassageCatalog.gd").inspect(bundle)
	assert_true(passages.ok, str(passages))
	if not passages.ok: return
	var umbrella: Dictionary = passages.value.records.get("passage.umbrella", {})
	assert_false(umbrella.is_empty())
	if umbrella.is_empty(): return
	assert_eq(umbrella.entry_id, "ending.alone.normal")
	assert_eq(umbrella.line_ids.size(), 22)
	assert_eq(umbrella.line_ids.front(), "line.ending.alone.normal.001")
	assert_eq(umbrella.line_ids.back(), "line.ending.alone.normal.022")
	assert_eq(entries["ending.alone.normal"].markers[0].after_line_id, "")
	for target: Dictionary in bundle.targets:
		assert_ne(target.target.kind, "ending", "production finishes through ordinary passage markers")
