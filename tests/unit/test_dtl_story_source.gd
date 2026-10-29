extends "res://addons/gut/test.gd"

const SOURCE := preload("res://tools/authoring/DtlStorySource.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PATH := "res://replacement.dtl"

func test_migrated_structure_matches_installed_gameplay() -> void:
	var config := STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/authored_week_source.json"))
	var discovered := SOURCE.prepare(config.value)
	assert_true(discovered.ok, str(discovered))
	if not discovered.ok: return
	var installed := STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json"))
	var expected := {}
	for entry: Dictionary in installed.value.scene_programme.entries: expected[entry.entry_id] = entry.markers
	assert_eq(discovered.value.entries.size(), expected.size())
	assert_eq(discovered.value.first_entry_id, "Day1")
	for entry: Dictionary in discovered.value.entries:
		assert_eq(entry.markers, expected[entry.entry_id], entry.entry_id)
		assert_eq(entry.story_day, installed.value.scene_programme.story_days[entry.entry_id])
	var challenges: Array = discovered.value.challenges
	challenges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.challenge_id < b.challenge_id)
	assert_eq(challenges, installed.value.challenges)

func test_replacement_week_discovers_only_explicit_entries_and_native_markers() -> void:
	var text := "# Ordinary author notes remain comments.\nreturn\n"
	for day: int in range(1, 8):
		text += "label replacement.%s\n# story entry day=%s%s\n" % [day, day, " start" if day == 3 else ""]
		text += "\\TEST caption. #id:line.replacement.%s\n" % day
		text += "# self-talk\n\\TEST thought. #id:line.thought.%s\n" % day
		text += "label internal.%s\n" % day
		if day < 7:
			text += '# story marker {"kind":"scene.transition","payload":{"target_id":"target.replacement.%s"}}\n' % (day + 1)
		text += "return\n"
	var result := SOURCE.prepare_texts({}, {PATH: text})
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.entries.size(), 7, "ordinary labels are not entries")
	assert_eq(result.value.first_entry_id, "replacement.3", "start is explicit, not file or day ordering")
	var labels: Array = result.value.entries.map(func(entry: Dictionary) -> String: return entry.entry_id)
	for entry: Dictionary in result.value.entries:
		var compiled := ADAPTER._compile_scene_programme_source(text, entry.entry_id, labels, entry.markers)
		assert_true(compiled.ok, str(compiled))
		if not entry.markers.is_empty():
			assert_eq(entry.markers[0].after_line_id, "line.replacement.%s" % entry.story_day,
				"self-talk does not replace its caption's marker anchor")
	assert_eq(SOURCE.prepare_texts({}, {PATH: text}), result, "discovery is deterministic")

func test_entry_add_rename_remove_needs_no_parallel_registration_list() -> void:
	var first := "label first\n# story entry day=1 start\n\\TEST first. #id:line.first\nreturn\n"
	var later := "label later\n# story entry day=7\n\\TEST later. #id:line.later\nreturn\n"
	var added := SOURCE.prepare_texts({}, {PATH: first + later})
	assert_eq(added.value.entries.size(), 2)
	var renamed := SOURCE.prepare_texts({}, {PATH: (first + later).replace("label later", "label renamed")})
	assert_eq(renamed.value.entries[1].entry_id, "renamed")
	var removed := SOURCE.prepare_texts({}, {PATH: first})
	assert_eq(removed.value.entries.size(), 1)

func test_manual_directive_errors_identify_source_location() -> void:
	var valid := "label first\n# story entry day=1 start\n\\TEST first. #id:line.first\nreturn\n"
	for text: String in [valid.replace("day=1", "day=8"), valid.replace("entry", "entyr"),
			valid + valid, valid + valid.replace("first", "second"), valid.replace(" start", "")]:
		var result := SOURCE.prepare_texts({"timeline_root": PATH}, {PATH: text})
		assert_false(result.ok, text)
		assert_eq(result.path, PATH)
		assert_gt(result.line, 0)
	var dangling := valid.replace("return", 'label next\n# story marker {"kind":"scene.transition","payload":{"target_id":"target.missing"}}\nreturn')
	var result := SOURCE.prepare_texts({}, {PATH: dangling})
	assert_eq(result.code, "story_target_missing")
	assert_eq(result.path, PATH)
	assert_eq(result.line, 5)

func test_library_membership_does_not_create_a_checkpoint_or_marker() -> void:
	var text := 'label first\n# story entry day=1 start\n# story passage {"id":"chapter.room","title_key":"room","requirements":{"all":["choice.yes"]}}\n\\TEST first. #id:line.first\nreturn\n'
	var result := SOURCE.prepare_texts({}, {PATH: text})
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_true(result.value.entries[0].markers.is_empty())
	assert_eq(result.value.library_memberships[0].entry_id, "first")
	assert_eq(result.value.library_memberships[0].data.id, "chapter.room")
