extends "res://tests/integration/scene_computer_child.gd"
## Diagnostic only: real input through the authored Day1 opening, never a test timeline.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STORY := preload("res://scripts/localization/StoryLocalization.gd")

class UnavailableSpeechDisplay extends RefCounted:
	func has_feature(_feature: int) -> bool: return false
	func tts_get_voices() -> Array: return []
	func tts_set_utterance_callback(_event: int, _callback: Callable) -> void: pass
	func tts_speak(_text: String, _voice: String, _volume: int, _pitch: float,
			_rate: float, _id: int, _interrupt: bool) -> void: pass
	func tts_stop() -> void: pass

func _install_content_registration() -> Dictionary:
	return MANIFEST.scene_registration()

func _send_enter(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	get_viewport().push_input(event, true)

func test_native_enter_to_first_draw_and_history_after_thirty() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "latency requires a rendered cloud process")
	if DisplayServer.get_name() == "headless": return
	var dual := OS.get_environment("DWM_READING_DUAL").to_lower() in ["1", "true", "dual"]
	var size_text := OS.get_environment("DWM_READING_TEXT_SIZE")
	var percent := 100 if size_text.is_empty() else int(size_text)
	assert_true(percent in [100, 150])
	if percent not in [100, 150]: return
	get_node("/root/SystemTtsCoordinator")._port._display = UnavailableSpeechDisplay.new()
	if not _start_services(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	var localization: Node = get_node("/root/LocalizationManager")
	if not _ok(localization.set_locale("en")): return
	for setting: Array in [
		[&"preferences.language.secondary_locale_id", "zh_HK"],
		[&"preferences.language.dual_enabled", dual],
		[&"preferences.accessibility.text_size", percent],
		[&"preferences.reading.auto_enabled", false],
		[&"preferences.reading.read_aloud_enabled", false],
		[&"preferences.reading.reveal_speed", "instant"],
	]:
		if not _ok(profile.set_preference(setting[0], setting[1])): return
	var started: Dictionary = saves.start_scene_new_run("target.Day1", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return
	var text_owner: Object = get_node("/root/Dialogic").get_subsystem("Text")
	var samples: Array[Dictionary] = []
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.one")
	for number: int in range(2, 31):
		caption.caption_text.grab_focus()
		var admitted := false
		for frame: int in 180:
			if caption.accept_input.is_source_admitted() and not caption.caption_text.revealing \
					and bridge.can_auto_advance_current_line():
				admitted = true
				break
			await get_tree().process_frame
		assert_true(admitted, "ordinary native gate before line %03d" % number)
		if not admitted: return
		# Signal observation is deliberately cheap; all semantic assertions are outside timing.
		var published := [false]
		var observer: Callable = func(_info: Dictionary) -> void: published[0] = true
		text_owner.text_started.connect(observer, CONNECT_ONE_SHOT)
		var layout_before: int = caption._layout_generation
		var draw_count := 0
		Engine.set_meta(&"dwm_reading_latency", {"enabled": true, "methods": {}})
		var began := Time.get_ticks_usec()
		_send_enter(true)
		for frame: int in 180:
			await RenderingServer.frame_post_draw
			draw_count += 1
			if published[0] and caption.caption_text.is_visible_in_tree(): break
		var elapsed := Time.get_ticks_usec() - began
		_send_enter(false)
		for frame: int in 2: await get_tree().process_frame
		var trace: Dictionary = Engine.get_meta(&"dwm_reading_latency")
		trace.enabled = false
		Engine.set_meta(&"dwm_reading_latency", trace)
		assert_true(published[0], "physical Enter publishes one next caption")
		if not published[0]:
			if text_owner.text_started.is_connected(observer): text_owner.text_started.disconnect(observer)
			return
		var expected := "line.Day1.%03d" % number
		assert_eq(bridge._runtime_adapter.current_line_id(), expected)
		assert_eq(caption.caption_text.get_parsed_text(), STORY.catalog("en")[expected])
		assert_eq(caption.secondary_caption.get_parsed_text(), STORY.catalog("zh_HK")[expected] if dual else "")
		assert_eq(caption.secondary_caption.visible, dual)
		samples.append({"action": "advance", "line_id": expected, "elapsed_us": elapsed,
			"draws_until_publication": draw_count, "layout_generations": caption._layout_generation - layout_before,
			"methods": trace.methods.duplicate(true)})
	if dual:
		for frame: int in 6: await get_tree().process_frame
		await _screenshot("reading-latency-authored-reading")
	# Do not inspect History before this measurement: opening is its first projection request.
	var history_button: Control = caption.transport_rail.get_node("History")
	history_button.grab_focus()
	for frame: int in 3: await get_tree().process_frame
	assert_true(caption._history_admitted())
	if not caption._history_admitted(): return
	_send_enter(true)
	var history_layout_before: int = caption._layout_generation
	Engine.set_meta(&"dwm_reading_latency", {"enabled": true, "methods": {}})
	var history_began := Time.get_ticks_usec()
	_send_enter(false)
	var history_draws := 0
	for frame: int in 180:
		await RenderingServer.frame_post_draw
		history_draws += 1
		if caption._history_open and caption._history_overlay.is_visible_in_tree(): break
	var history_elapsed := Time.get_ticks_usec() - history_began
	for frame: int in 2: await get_tree().process_frame
	var history_trace: Dictionary = Engine.get_meta(&"dwm_reading_latency")
	history_trace.enabled = false
	Engine.set_meta(&"dwm_reading_latency", history_trace)
	assert_true(caption._history_open)
	if not caption._history_open: return
	assert_eq(caption._history_overlay.get_captions().size(), 30)
	var history: Dictionary = bridge.get_reading_history()
	if not _ok(history): return
	assert_eq(history.value.captions.size(), 30)
	for index: int in history.value.captions.size():
		var row: Dictionary = history.value.captions[index]
		var expected := "line.Day1.one" if index == 0 else "line.Day1.%03d" % (index + 1)
		assert_eq(row.line_id, expected)
		assert_eq(row.get("secondary_text", ""), STORY.catalog("zh_HK")[expected] if dual else "")
	samples.append({"action": "history", "caption_count": 30, "elapsed_us": history_elapsed,
		"draws_until_publication": history_draws, "layout_generations": caption._layout_generation - history_layout_before,
		"methods": history_trace.methods.duplicate(true)})
	_write_json("res://.godot/ci/reading-latency.json", {"schema_version": 1,
		"process_id": OS.get_process_id(), "engine": Engine.get_version_info(), "os": OS.get_name(),
		"display": DisplayServer.get_name(), "dual_enabled": dual, "text_size": percent,
		"primary_locale": "en", "secondary_locale": "zh_HK", "reveal_speed": "instant",
		"advance_metric": "physical Enter key-down to first post-draw following native text_started",
		"history_metric": "focused History Enter key-up to first post-draw with visible History",
		"attribution_window": "input through first draw plus two settling process frames",
		"samples": samples})
	if dual:
		for frame: int in 6: await get_tree().process_frame
		await _screenshot("reading-latency-history")
		await _click(caption._history_overlay.close_button)
		for frame: int in 120:
			if not caption._history_open and not get_tree().paused: break
			await get_tree().process_frame
		assert_false(caption._history_open)
		assert_false(get_tree().paused)
		if caption._history_open or get_tree().paused: return
		var pause: Node = get_node("/root/SceneRouter")._production_pause
		if not _ok(await pause.open_scene_settings()): return
		var settings: Control = pause.surface._hosts[&"settings"].get_content_host()
		settings.select_category("language")
		for frame: int in 6: await get_tree().process_frame
		await _screenshot("reading-latency-language-settings")
