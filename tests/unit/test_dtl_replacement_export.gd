extends "res://addons/gut/test.gd"

const WEEK := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const SOURCE := preload("res://tools/authoring/DtlStorySource.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ROOT := "res://tests/fixtures/dialogic/_dtl_replacement"
const CONFIG := ROOT + "/source.json"
const OUTCOMES := ["never_started", "unfinished", "won", "lost", "perfect"]

func after_each() -> void:
	for file: String in DirAccess.get_files_at(ROOT):
		var path := ROOT.path_join(file)
		ADAPTER._scene_compile_cache.erase(path)
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ROOT)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null: file.store_string(text)

func _marker(label: String, kind: String, payload: Dictionary) -> String:
	return "label " + label + "\n# story marker " + JSON.stringify({"kind": kind, "payload": payload}) + "\n"

func _entry(id: String, day: int, start: bool = false) -> String:
	return "label %s\n# story entry day=%s%s\n" % [id, day, " start" if start else ""]

func test_entire_replacement_story_exports_from_dtl_and_unchanged_catalogues() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var original := STRICT.parse_object(FileAccess.get_file_as_string(WEEK.SOURCE_PATH))
	var config: Dictionary = original.value.duplicate(true)
	config.timeline_root = ROOT
	config["library_titles"] = {"replacement": {"en": "Replacement passage"}}
	config["condition_labels"] = {"choice.pass": {"en": "Pass on the offer"}}
	_write(CONFIG, JSON.stringify(config))

	# File sorting deliberately does not choose the start. Both choices reach day 2.
	var first := "return\n" + _entry("replacement.opening", 1, true)
	first += '# story passage {"id":"replacement.arrival","title_key":"replacement"}\n'
	first += "# art background shell.background\n# checkpoint replacement.arrival\n"
	first += "# audio music template.shared.music.plan\n"
	first += "\\TEST opening. #id:line.replacement.opening\n# self-talk\n\\TEST offer. #id:line.replacement.thought\n"
	first += _marker("replacement.offer", "thought.pass", {"opportunity_id": "replacement.choice",
		"yes_target_id": "target.replacement.day2", "pass_target_id": "target.replacement.pass"}) + "return\n"
	first += _entry("replacement.pass", 1)
	first += '# story passage {"id":"replacement.arrival","requirements":{"label":"choice.pass"}}\n'
	first += "\\TEST passed. #id:line.replacement.pass\n"
	first += _marker("replacement.pass.next", "scene.transition", {"target_id": "target.replacement.day2"}) + "return\n"
	_write(ROOT + "/z-opening.dtl", first)

	var targets := {}
	for outcome: String in OUTCOMES: targets[outcome] = "target.replacement.result." + outcome
	var second := "return\n" + _entry("replacement.day2", 2)
	second += "# story challenge " + JSON.stringify({"challenge_id": "replacement.challenge",
		"playable_marker_id": "replacement.playable", "end_marker_id": "replacement.end",
		"board_profile_id": "week.canonical_solo", "targets": targets}) + "\n"
	second += "\\TEST challenge. #id:line.replacement.challenge\n"
	second += _marker("replacement.playable", "challenge.playable", {"challenge_id": "replacement.challenge"})
	second += _marker("replacement.end", "challenge.end", {"challenge_id": "replacement.challenge"}) + "return\n"
	for outcome: String in OUTCOMES:
		var id := "replacement.result." + outcome
		second += _entry(id, 2) + "\\TEST %s. #id:line.%s\n" % [outcome, id]
		second += _marker(id + ".next", "scene.transition", {"target_id": "target.replacement.day3"}) + "return\n"
	_write(ROOT + "/day2.dtl", second)
	for day: int in range(3, 8):
		var id := "replacement.day%s" % day
		var text := "return\n" + _entry(id, day)
		if day == 7: text += _marker("replacement.passage.start", "passage.start", {"passage_id": "passage.replacement.ending"})
		text += "\\TEST day %s. #id:line.%s\n" % [day, id]
		text += _marker(id + ".next", "scene.transition", {"target_id": "target.replacement.day%s" % (day + 1)}) \
			if day < 7 else _marker("replacement.passage.finish", "passage.finish", {"passage_id": "passage.replacement.ending"})
		_write(ROOT + "/day%s.dtl" % day, text + "return\n")

	var result := WEEK.prepare(CONFIG)
	assert_true(result.ok, str(result))
	if not result.ok: return
	var bundle: Dictionary = result.value.registration
	assert_eq(result.value.first_target_id, "target.replacement.opening")
	assert_eq(bundle.entry_manifest.entries.size(), 13, "seven days plus one choice branch and five outcome entries")
	assert_eq(bundle.challenges.size(), 1)
	assert_eq(bundle.challenges[0].targets, targets, "all five result routes come from DTL")
	var days: Array = bundle.scene_programme.story_days.values()
	for day: int in range(1, 8): assert_has(days, day)
	var entries := {}
	for entry: Dictionary in bundle.scene_programme.entries: entries[entry.entry_id] = entry
	assert_eq(entries["replacement.opening"].markers[0].payload.pass_target_id, "target.replacement.pass")
	assert_eq(entries["replacement.day2"].markers[0].after_line_id, "line.replacement.challenge")
	assert_eq(entries["replacement.day2"].markers[1].after_line_id, "line.replacement.challenge")
	var library: Dictionary = result.value.dialogue_library
	assert_eq(library.passages.size(), 1)
	assert_eq(library.passages[0].entries.size(), 3, "caption/thought pair and ordinary member branch")
	assert_eq(library.passages[0].entries[2].requirements, {"label": "choice.pass"})
	assert_eq(WRITER.stringify(WEEK.prepare(CONFIG).value).value, WRITER.stringify(result.value).value,
		"repeat full export is deterministic without hand-edited registrations")
