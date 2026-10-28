extends "res://tests/integration/scene_computer_child.gd"
## One native story execution, with live paired display and current-profile Load.
const STORY := preload("res://scripts/localization/StoryLocalization.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")

class UnavailableSpeechDisplay extends RefCounted:
	func has_feature(_feature: int) -> bool: return false
	func tts_get_voices() -> Array: return []
	func tts_set_utterance_callback(_event: int, _callback: Callable) -> void: pass
	func tts_speak(_text: String, _voice: String, _volume: int, _pitch: float,
			_rate: float, _id: int, _interrupt: bool) -> void: pass
	func tts_stop() -> void: pass

func _install_content_registration() -> Dictionary:
	return MANIFEST.scene_registration()

func _screenshot(label: String) -> void:
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await super._screenshot(label)

func test_native_pair_settings_missing_translation_and_current_profile_load() -> void:
	get_node("/root/SystemTtsCoordinator")._port._display = UnavailableSpeechDisplay.new()
	if not _start_services(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var localization: Node = get_node("/root/LocalizationManager")
	if not _ok(localization.set_locale("en")): return
	if not _ok(profile.set_preference(&"preferences.language.secondary_locale_id", "zh_HK")): return
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", true)): return
	var started: Dictionary = saves.start_scene_new_run("target.Day1", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not _ok(bridge._runtime_adapter.reveal_current_line(true)): return
	for frame: int in 6: await get_tree().process_frame
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return
	var line: String = bridge._runtime_adapter.current_line_id()
	assert_eq(line, "line.Day1.one")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var receipts: Dictionary = game.capture_run_snapshot_input().command_receipts.duplicate(true)
	var witnesses: Dictionary = profile.get_profile_snapshot().witnessed_caption_variants.duplicate(true)
	var library: Dictionary = profile.get_dialogue_library().duplicate(true)
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	# Each change uses the actual Settings owner while the caption is held.
	for pair: Array in [["en", "zh_HK"], ["zh_HK", "en"], ["ja", "ko"], ["ko", "zh_CN"]]:
		if not _ok(await pause.open_scene_settings()): return
		var content: Control = pause.surface._hosts[&"settings"].get_content_host()
		content.select_category("language")
		var controller: Object = content.get_controller()
		for path: StringName in [&"preferences.language.primary_locale_id", &"preferences.language.dual_enabled", &"preferences.language.secondary_locale_id"]:
			assert_true(controller._controls.has(path), "player can configure " + str(path))
			if not controller._controls.has(path): return
		if not _ok(await controller.commit_preference(&"preferences.language.dual_enabled", false)): return
		assert_true(controller._controls[&"preferences.language.secondary_locale_id"].disabled)
		if not _ok(await controller.commit_preference(&"preferences.language.dual_enabled", true)): return
		assert_false(controller._controls[&"preferences.language.secondary_locale_id"].disabled)
		if not _ok(await controller.commit_preference(&"preferences.language.primary_locale_id", pair[0])): return
		for frame: int in 3: await get_tree().process_frame
		if not _ok(await controller.commit_preference(&"preferences.language.secondary_locale_id", pair[1])): return
		for frame: int in 3: await get_tree().process_frame
		assert_eq(bridge.capture_current_bilingual_presentation().value.secondary_locale, pair[1])
		await _click(pause.surface._sheet_back)
		for frame: int in 120:
			if not get_tree().paused: break
			await get_tree().process_frame
		assert_false(get_tree().paused, str(pause.last_result))
		if get_tree().paused: return
		for frame: int in 6: await get_tree().process_frame
		assert_eq(caption.caption_text.get_parsed_text(), STORY.catalog(pair[0])[line])
		assert_eq(caption.secondary_caption.get_parsed_text(), STORY.catalog(pair[1])[line])
		assert_true(caption.secondary_caption.visible)
		assert_eq(caption.secondary_caption.language, str(pair[1]).replace("_", "-"))
		assert_eq(caption.secondary_caption.visible_ratio, caption.caption_text.visible_ratio)
		assert_false(caption.older.visible)
		assert_false(caption.previous.visible, "dual live view contains only the current pair")
		assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
		assert_eq(game.capture_run_snapshot_input().command_receipts, receipts)
		assert_eq(profile.get_profile_snapshot().witnessed_caption_variants, witnesses)
		assert_eq(profile.get_dialogue_library(), library)
		var history: Dictionary = bridge.get_reading_history()
		if not _ok(history): return
		assert_eq(history.value.captions.size(), 1, "translations are not History events")
		assert_eq(history.value.captions[0].secondary_text, STORY.catalog(pair[1])[line])
		for percent: int in [100, 125, 150]:
			if not _ok(profile.set_preference(&"preferences.accessibility.text_size", percent)): return
			for frame: int in 4: await get_tree().process_frame
			var projection: Dictionary = caption.get_caption_projection()
			for rect: Rect2 in projection.visible_leaf_rects:
				assert_lte(rect.end.y, caption.FIELD_BOTTOM, "paired text stays above controls")
			assert_eq(caption.secondary_caption.get_theme_font_size("normal_font_size"),
				caption.caption_text.get_theme_font_size("normal_font_size"), "Secondary retains accessibility size")
		await _screenshot("bilingual-" + str(pair[0]) + "-" + str(pair[1]))
	# Missing authored Secondary is a normal authoring state, not another fallback row.
	var secondary: Dictionary = STORY.catalog("zh_CN")
	var translated: String = secondary[line]
	secondary.erase(line)
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", false)): return
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", true)): return
	for frame: int in 5: await get_tree().process_frame
	assert_false(caption.secondary_caption.visible)
	assert_eq(bridge.get_reading_history().value.captions[0].secondary_text, "")
	# Deliberately long, clearly synthetic text exercises bounded scrolling at 150%.
	secondary[line] = "SYNTHETIC LAYOUT FIXTURE — " + "这是用于验证双语长段落换行和滚动的合成示例。".repeat(24)
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", false)): return
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", true)): return
	for frame: int in 8: await get_tree().process_frame
	assert_eq(caption.secondary_caption.get_parsed_text(), secondary[line])
	assert_gt(caption.get_caption_projection().scroll_extent, 0.0, "long Secondary remains scrollable")
	await _screenshot("bilingual-synthetic-long-secondary")
	secondary[line] = translated
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", false)): return
	for frame: int in 4: await get_tree().process_frame
	assert_false(caption.secondary_caption.visible)
	assert_eq(caption.caption_text.get_parsed_text(), STORY.catalog("ko")[line])
	if not _ok(profile.set_preference(&"preferences.language.dual_enabled", true)): return
	for frame: int in 4: await get_tree().process_frame
	assert_eq(caption.secondary_caption.get_parsed_text(), translated)
	# One physical Advance moves both presentations to exactly one next beat.
	if not _ok(profile.set_preference(&"preferences.reading.reveal_speed", "slow")): return
	await _click(caption.caption_text)
	for frame: int in 20: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.002")
	var native: DialogicNode_DialogText = caption.caption_text
	assert_true(native.revealing, "exercise an unfinished native reveal, not a fully shown pair")
	if not native.revealing: return
	# Hold the remaining duration deterministically while using native input and
	# reveal completion. This changes no text, publication or story position.
	native.active_speed = 10.0
	assert_gt(native.visible_ratio, 0.0)
	assert_lt(native.visible_ratio, 1.0)
	assert_almost_eq(caption.secondary_caption.visible_ratio, native.visible_ratio, 0.001)
	var partial_checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var partial_receipts: Dictionary = game.capture_run_snapshot_input().command_receipts.duplicate(true)
	var partial_ratio: float = native.visible_ratio
	if not _ok(profile.set_preference(&"preferences.language.secondary_locale_id", "ja")): return
	for frame: int in 3: await get_tree().process_frame
	assert_true(native.revealing)
	assert_almost_eq(native.visible_ratio, partial_ratio, 0.001)
	assert_almost_eq(caption.secondary_caption.visible_ratio, native.visible_ratio, 0.001)
	assert_eq(caption.secondary_caption.get_parsed_text(), STORY.catalog("ja")["line.Day1.002"])
	assert_eq(bridge.capture_reading_checkpoint(false), partial_checkpoint)
	assert_eq(game.capture_run_snapshot_input().command_receipts, partial_receipts)
	if not _ok(profile.set_preference(&"preferences.reading.auto_delay", "long")): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", true)): return
	assert_false(caption.auto_controller._armed, "Auto cannot count down while the pair is revealing")
	caption.auto_controller._process(10.0)
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.002")
	await _click(caption.caption_text)
	for frame: int in 4: await get_tree().process_frame
	assert_false(native.revealing, "one Advance completes both texts")
	assert_eq(native.visible_ratio, 1.0)
	assert_eq(caption.secondary_caption.visible_ratio, 1.0)
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.002", "reveal press does not advance")
	assert_true(caption.auto_controller._armed, "the shared completion starts one Auto delay")
	caption.auto_controller.set_process(false)
	caption.auto_controller._process(0.0)
	caption.auto_controller._process(0.5)
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.002", "Auto retains the existing reading delay")
	caption.auto_controller._process(4.1)
	for frame: int in 20: await get_tree().process_frame
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.003", "one Auto completion advances one semantic beat")
	if not _ok(bridge._runtime_adapter.reveal_current_line(true)): return
	for frame: int in 5: await get_tree().process_frame
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(frontier) or not _ok(bridge.acknowledge_current_line_presentation(frontier)): return
	if not _ok(await pause.request_pause()): return
	var backup: Object = pause._backup_port
	var save_prepared: Dictionary = backup.prepare_action("save", "slot:1")
	if not _ok(save_prepared) or not _ok(await backup.commit_action(save_prepared.value.token)): return
	var saved_sha := FileAccess.get_sha256("user://saves/slot_1.json")
	if not _ok(await pause.request_continue()): return
	if not _ok(localization.set_locale("ja")): return
	if not _ok(profile.set_preference(&"preferences.language.secondary_locale_id", "en")): return
	if not _ok(await pause.request_pause()): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	ready_count = 0
	if not _ok(await backup.commit_action(prepared.value.token)) or not await _await_ready(): return
	for frame: int in 6: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.003")
	assert_eq(_caption().caption_text.get_parsed_text(), STORY.catalog("ja")["line.Day1.003"])
	assert_eq(_caption().secondary_caption.get_parsed_text(), STORY.catalog("en")["line.Day1.003"])
	assert_eq(profile.get_preference(&"preferences.language.secondary_locale_id", ""), "en")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), saved_sha)
	await _screenshot("bilingual-current-preferences-load")
