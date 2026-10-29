extends "res://tests/integration/current_title_scene_child.gd"
## Observation-only baseline on shipped content; no wall-clock performance gate.
## Fresh means a new process/profile, not cold operating-system caches.
const RUNTIME := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
var _measurement: Dictionary = {}
var _samples: Array[Dictionary] = []

func _observe_draw() -> void:
	if _measurement.is_empty() or _measurement.has("usable_us"): return
	var caption: Node = _caption()
	if not is_instance_valid(caption) or not caption.caption_text.is_visible_in_tree(): return
	var native: Node = caption.caption_text
	if bridge._runtime_adapter.current_line_id() != _measurement.line_id \
			or native.get_parsed_text() != _measurement.expected_text or native.visible_ratio <= 0.0: return
	var now := Time.get_ticks_usec()
	if not _measurement.has("first_draw_us"): _measurement.first_draw_us = now
	var event: DialogicTextEvent = bridge._runtime_adapter._current_skip_text(true)
	var inputs: Node = bridge._runtime_adapter._dialogic.get_subsystem("Inputs")
	if event != null and event.state == DialogicTextEvent.States.DONE \
			and not native.revealing and native.visible_ratio == 1.0 \
			and not inputs.is_input_blocked() and bridge.is_current_line_presentation_acknowledged():
		_measurement.usable_us = now

func _prepare_sample(operation: String, line_id: String) -> bool:
	var text: Variant = STORY_TEXT.catalog("en").get(line_id)
	assert_true(text is String and not str(text).strip_edges().is_empty(), "shipped caption exists")
	if not text is String or str(text).strip_edges().is_empty(): return false
	_measurement = {"operation": operation, "line_id": line_id, "expected_text": text,
		"runtime_programme_cached": RUNTIME._scene_runtime_programmes.has("Day1")}
	return true

func _finish_sample() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while not _measurement.has("usable_us") and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(_measurement.has("usable_us"), "correct visible caption becomes usable: " + str(_measurement))
	if not _measurement.has("usable_us"): return false
	assert_gte(int(_measurement.first_draw_us), int(_measurement.input_us))
	assert_gte(int(_measurement.usable_us), int(_measurement.first_draw_us))
	_measurement["input_to_first_draw_us"] = _measurement.first_draw_us - _measurement.input_us
	_measurement["input_to_usable_us"] = _measurement.usable_us - _measurement.input_us
	_samples.append(_measurement.duplicate(true))
	return true

func test_current_content_native_input_reading_baseline() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "baseline requires actual rendering")
	if DisplayServer.get_name() == "headless" or not _start_services(): return
	assert_false(FileAccess.file_exists(TITLE_SLOT), "isolated fresh profile")
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	if not _ok(profile.set_preference(&"preferences.reading.reveal_speed", "fast")): return
	if not _ok(get_node("/root/LocalizationManager").set_locale("en")): return
	var menu: Node = await _title_menu()
	var button: Button = menu.get_node("%NewAccButton")
	assert_true(button.is_visible_in_tree() and not button.disabled)
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size / 2.0)
	if not _prepare_sample("fresh_process_new_acc", FIRST_LINE): return
	assert_false(_measurement.runtime_programme_cached, "first entry has no prepared runtime programme")
	RenderingServer.frame_post_draw.connect(_observe_draw)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		if pressed: _measurement.input_us = Time.get_ticks_usec()
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	if not await _finish_sample(): return
	var run_id: String = game.capture_live_session().value.run_id
	for index: int in range(2, 5):
		var caption: Node = _caption()
		caption.caption_text.grab_focus()
		await get_tree().process_frame
		assert_true(caption.caption_text.has_focus(), "native Accept owns focus")
		if not caption.caption_text.has_focus(): return
		if not _prepare_sample("warm_programme_next", "line.Day1.%03d" % index): return
		assert_true(_measurement.runtime_programme_cached, "ordinary reading uses its prepared entry")
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			if pressed: _measurement.input_us = Time.get_ticks_usec()
			get_viewport().push_input(event, true)
			await get_tree().process_frame
		if not await _finish_sample(): return
	RenderingServer.frame_post_draw.disconnect(_observe_draw)
	assert_eq(game.capture_live_session().value.run_id, run_id, "reading stays in the same run")
	assert_eq(_samples.size(), 4, "every requested action produced a complete sample")
	assert_false(FileAccess.file_exists(AUTOSAVE), "ordinary opening captions do not checkpoint")
	var output := OS.get_environment("DWM_READING_BASELINE_OUTPUT")
	assert_false(output.is_empty(), "cloud runner supplies unique output directory")
	if output.is_empty(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(output), OK)
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	assert_false(pixels.is_empty())
	var screenshot := output.path_join("last-caption.png")
	assert_eq(pixels.save_png(screenshot), OK)
	var proof := {"scope": "shipped Day1 New Acc and three ordinary next captions; fresh process/profile, OS caches uncontrolled; fast reveal; software rendered editor, not exported-player latency",
		"source_sha": OS.get_environment("DWM_READING_BASELINE_SHA"),
		"engine": Engine.get_version_info(), "renderer": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"process_id": OS.get_process_id(), "registration_sha256": CURRENT_MANIFEST.scene_registration_fingerprint(),
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"samples": _samples, "screenshot_sha256": FileAccess.get_sha256(screenshot)}
	assert_eq(str(proof.source_sha).length(), 40)
	if not _write_json(output.path_join("samples.json"), proof): return
	print("CURRENT_READING_BASELINE_VERIFIED ", JSON.stringify({"samples": _samples.size(), "process_id": OS.get_process_id()}))
