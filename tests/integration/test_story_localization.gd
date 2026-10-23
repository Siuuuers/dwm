extends "res://tests/integration/scene_computer_child.gd"
## One real authored-story journey; language is presentation, not saved story identity.
const STORY := preload("res://scripts/localization/StoryLocalization.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")

# The cloud renderer has no libspeechd. Exercise the supported unavailable-platform
# capability seam instead of asking the native backend to dereference a null synth.
class UnavailableSpeechDisplay extends RefCounted:
	func has_feature(_feature: int) -> bool: return false
	func tts_get_voices() -> Array: return []
	func tts_set_utterance_callback(_event: int, _callback: Callable) -> void: pass
	func tts_speak(_text: String, _voice: String, _volume: int, _pitch: float,
			_rate: float, _id: int, _interrupt: bool) -> void: pass
	func tts_stop() -> void: pass

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result.get("code", "ok")))
	return result.get("ok", false)

func _screenshot(label: String) -> void:
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await super._screenshot(label)

func _install_content_registration() -> Dictionary:
	return MANIFEST.scene_registration()

func test_authored_caption_languages_preserve_checkpoint_and_load() -> void:
	get_node("/root/SystemTtsCoordinator")._port._display = UnavailableSpeechDisplay.new()
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var locale := get_node("/root/LocalizationManager")
	if not _ok(locale.set_locale("en")): return
	var new_run_started := Time.get_ticks_msec()
	var started: Dictionary = saves.start_scene_new_run("target.Day1", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	print("STORY_TIMING new_run_ms=", Time.get_ticks_msec() - new_run_started)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not _ok(bridge._runtime_adapter.reveal_current_line(true)): return
	for frame: int in 5: await get_tree().process_frame
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return
	var line: String = bridge._runtime_adapter.current_line_id()
	assert_eq(line, "line.Day1.one")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var receipts: Dictionary = game.capture_run_snapshot_input().command_receipts.duplicate(true)
	for language: String in ["zh_HK", "zh_CN", "ja", "ko", "en"]:
		assert_eq(STORY.catalog(language).size(), 1682, language + " complete catalog")
		if not _ok(locale.set_locale(language)): return
		for frame: int in 3: await get_tree().process_frame
		assert_eq(caption.caption_text.get_parsed_text(), STORY.catalog(language)[line], language + " native caption")
		assert_eq(bridge.capture_reading_checkpoint(false), checkpoint, "language preserves canonical checkpoint")
		assert_eq(game.capture_run_snapshot_input().command_receipts, receipts, "language dispatches no story action")
		var history: Dictionary = bridge.get_reading_history()
		if not _ok(history): return
		assert_eq(history.value.captions.back().text, STORY.catalog(language)[line], language + " History projection")
		# Every shipped story codepoint must be available in both existing font styles.
		var missing := {}
		var codepoints := {}
		for translated: String in STORY.catalog(language).values():
			for character: String in translated:
				if character.unicode_at(0) > 32: codepoints[character] = true
		for style: String in ["pixel", "readable"]:
			for percent: int in [100, 125, 150]:
				var font: Font = TYPOGRAPHY.story_font(language, percent, style)
				for character: String in codepoints:
					if not font.has_char(character.unicode_at(0)): missing[character] = true
		assert_true(missing.is_empty(), language + " missing glyphs: " + str(missing.keys()))
		if language != "en":
			if not _ok(profile.set_preference(&"preferences.accessibility.text_size", 150)): return
			for frame: int in 5: await get_tree().process_frame
			await _screenshot("story-" + language)
			# A labelled font specimen additionally exercises the crossed-out clue.
			var layer := CanvasLayer.new()
			layer.layer = 200
			get_tree().root.add_child(layer)
			var plate := ColorRect.new()
			plate.color = Color("171717")
			plate.position = Vector2(24, 24)
			plate.size = Vector2(1232, 200)
			layer.add_child(plate)
			var specimen := RichTextLabel.new()
			specimen.position = Vector2(40, 32)
			specimen.size = Vector2(1200, 176)
			specimen.add_theme_font_override("normal_font", TYPOGRAPHY.story_font(language, 150, "pixel"))
			specimen.add_theme_font_size_override("normal_font_size", 36)
			specimen.bbcode_enabled = true
			specimen.text = "FONT SAMPLE / " + language + " / 150%\n" + STORY.display_markup(STORY.catalog(language)["line.Day6.098"]) + "\nș 唾"
			layer.add_child(specimen)
			for frame: int in 3: await get_tree().process_frame
			assert_eq(specimen.get_parsed_text(), "FONT SAMPLE / " + language + " / 150%\n" + STORY.catalog(language)["line.Day6.098"] + "\nș 唾", "strike markup preserves plain caption identity")
			await _screenshot("glyphs-" + language)
			layer.free()


	# Advance in a translated language, then save and reload the same stable line.
	if not _ok(locale.set_locale("ko")): return
	await _click(caption.caption_text)
	for frame: int in 20: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.002")
	if not _ok(bridge._runtime_adapter.reveal_current_line(true)): return
	for frame: int in 3: await get_tree().process_frame
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(frontier) or not _ok(bridge.acknowledge_current_line_presentation(frontier)): return
	# Save/Load both use the production pause owner, which captures live reading.
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	if not _ok(await pause.request_pause()): return
	var backup: Object = pause._backup_port
	var save_started := Time.get_ticks_msec()
	var save_prepared: Dictionary = backup.prepare_action("save", "slot:1")
	if not _ok(save_prepared): return
	if not _ok(await backup.commit_action(save_prepared.value.token)): return
	print("STORY_TIMING save_ms=", Time.get_ticks_msec() - save_started)
	var saved_sha := FileAccess.get_sha256("user://saves/slot_1.json")
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	ready_count = 0
	var load_started := Time.get_ticks_msec()
	var loaded: Dictionary = await backup.commit_action(prepared.value.token)
	print("STORY_TIMING load_ms=", Time.get_ticks_msec() - load_started)
	if not _ok(loaded) or not await _await_ready(): return
	for frame: int in 5: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.002")
	assert_eq(_caption().caption_text.get_parsed_text(), STORY.catalog(locale.get_locale())["line.Day1.002"])
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), saved_sha, "load leaves the selected save intact")
