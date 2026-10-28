extends "res://tests/integration/scene_multiple_thoughts_child.gd"
## Synthetic paired wording on the real choice owner; no production translation approval.
const STORY_TEXT := preload("res://scripts/localization/StoryLocalization.gd")

func test_bilingual_choices_keep_one_option_and_one_branch() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var originals := STORY_TEXT._catalogs.duplicate(true)
	for locale: String in ["en", "zh_HK", "ja"]: STORY_TEXT.catalog(locale)
	for row: Array in [["first", "Choose the first continuation.", "測試：第一個選項", "テスト：最初の選択肢"],
			["second", "Choose the second continuation.", "測試：第二個較長的選項", "テスト：二番目の長い選択肢"]]:
		var key := "choice.TEST.partner." + str(row[0])
		STORY_TEXT._catalogs.en[key] = row[1]
		STORY_TEXT._catalogs.zh_HK[key] = row[2]
		STORY_TEXT._catalogs.ja[key] = row[3]
	if not _ok(profile.set_preference(&"preferences.language.secondary_locale_id", "zh_HK")): return
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", true)): return
	var started: Dictionary = saves.start_scene_new_run("partner.shared", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if not await _await_ready() or not await _wait_line("line.scene.test.partner.shared.before"): return
	await _accept()
	if not await _wait_line(OFFER): return
	var host: Control = get_tree().current_scene
	var scroll: ScrollContainer = host.get_node("SceneControlsLayer/Surface/ThoughtOptions")
	var row: HBoxContainer = scroll.get_node("Options")
	var before: Dictionary = bridge.capture_reading_checkpoint(false)
	for percent: int in [100, 125, 150]:
		if not _ok(profile.set_preference(&"preferences.accessibility.text_size", percent)): return
		for frame: int in 15: await get_tree().process_frame
		assert_eq(row.get_child_count(), 2, "translations are not new choices")
		if row.get_child_count() != 2: return
		for button: Button in row.get_children():
			var words: VBoxContainer = button.get_child(0)
			assert_eq(words.get_child_count(), 2)
			assert_eq(button.accessibility_labeled_by_nodes.size(), 2)
			assert_true(button.accessibility_name.is_empty(), "locale labels provide one accessible option name")
			assert_gte(button.size.x, words.get_combined_minimum_size().x + 24)
			assert_eq(words.get_node("Primary").language, "en")
			assert_eq(words.get_node("Secondary").language, "zh-HK")
			assert_eq(words.get_node("Secondary").focus_mode, Control.FOCUS_NONE)
			assert_gte(button.size.y, words.get_combined_minimum_size().y + 16)
			assert_lte(button.size.y, scroll.size.y, "both lines fit the existing horizontal choice row")
		assert_true(_caption().self_talk.get_global_rect().encloses(scroll.get_global_rect()))
		assert_eq(bridge.capture_reading_checkpoint(false), before)
		await _screenshot("bilingual-choices-%d" % percent)
	var second: Button = row.get_child(1)
	second.grab_focus()
	if not _ok(get_node("/root/LocalizationManager").set_locale("zh_HK")): return
	for frame: int in 15: await get_tree().process_frame
	second = row.get_child(1)
	assert_true(second.has_focus(), "language swap retains the same focusable choice")
	assert_eq(second.get_child(0).get_node("Primary").language, "zh-HK")
	assert_eq(second.get_child(0).get_node("Secondary").language, "en")
	if not _ok(profile.set_preference(&"preferences.language.secondary_locale_id", "ja")): return
	for frame: int in 15: await get_tree().process_frame
	second = row.get_child(1)
	assert_eq(second.get_child(0).get_node("Secondary").language, "ja")
	assert_eq(bridge.capture_reading_checkpoint(false), before, "display changes never resolve an offer")
	await _screenshot("bilingual-choices-swapped")
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", false)): return
	for frame: int in 15: await get_tree().process_frame
	second = row.get_child(1)
	assert_eq(second.get_child_count(), 0, "single mode restores the original native button")
	assert_eq(second.text, "測試：第二個較長的選項")
	await _click(second)
	if not await _wait_line("line.scene.test.partner.lavinia.after"): return
	assert_eq(game.scene_choices, {"TEST.partner": "second"}, "one activation commits one branch")
	STORY_TEXT._catalogs = originals
