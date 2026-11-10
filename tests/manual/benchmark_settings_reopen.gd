extends "res://tests/integration/authored_week_child.gd"
## English Day1 opening, instant reveal and Auto off; source-process diagnostic only.

func test_settings_reopen_latency() -> void:
	_phase = "create"
	if not _setup_authored(false, "Day1"): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	var host: Node = get_tree().current_scene
	var caption: Node = _caption()
	var settings_button: Button = caption.transport_rail._settings_button
	var computer: Button = host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer")
	var samples: Array[Dictionary] = []
	var previous_theme_id := 0
	var previous_content_id := 0
	for attempt: int in 5:
		assert_false(host.is_computer_open())
		assert_true(settings_button.is_visible_in_tree())
		assert_false(settings_button.disabled)
		var point := settings_button.get_global_transform_with_canvas() * (settings_button.size / 2.0)
		var events: Array[InputEvent] = []
		for pressed: bool in [true, false]:
			var motion := InputEventMouseMotion.new()
			motion.position = point
			motion.global_position = point
			motion.button_mask = 0 if pressed else MOUSE_BUTTON_MASK_LEFT
			events.append(motion)
			var button := InputEventMouseButton.new()
			button.position = point
			button.global_position = point
			button.button_index = MOUSE_BUTTON_LEFT
			button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			button.pressed = pressed
			events.append(button)
		await get_tree().process_frame
		var started := Time.get_ticks_usec()
		for event: InputEvent in events: get_viewport().push_input(event, true)
		var dispatch_us := Time.get_ticks_usec() - started
		await get_tree().process_frame
		var following_frame_us := Time.get_ticks_usec() - started
		var post_draw_us: Variant = null
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			post_draw_us = Time.get_ticks_usec() - started
		assert_true(host.is_computer_open())
		var content: SettingsContent = host.get_computer_mount().find_child("SettingsContent", true, false)
		assert_not_null(content)
		if content == null: return
		assert_true(content.is_visible_in_tree())
		assert_true(content.interaction_enabled)
		assert_not_null(content.theme)
		if content.theme == null: return
		var locale_control: OptionButton = content.controls[&"preferences.language.primary_locale_id"]
		assert_true(locale_control.is_visible_in_tree())
		assert_false(locale_control.disabled)
		assert_false(computer.disabled)
		assert_eq(bridge._reading_session.ledger.snapshot().captions.back().beat.line_id, _expected[0].line_id)
		var theme_id := content.theme.get_instance_id()
		var content_id := content.get_instance_id()
		if attempt > 0: assert_eq(content_id, previous_content_id, "Settings instance is reused")
		samples.append({"attempt": attempt + 1, "first_open": attempt == 0,
			"input_dispatch_us": dispatch_us, "input_to_following_process_frame_us": following_frame_us,
			"input_to_post_draw_us": post_draw_us, "theme_id": theme_id,
			"theme_reused": attempt > 0 and theme_id == previous_theme_id,
			"content_id": content_id, "locale_control_enabled": not locale_control.disabled})
		previous_theme_id = theme_id
		previous_content_id = content_id
		await _click(computer)
		assert_false(host.is_computer_open())
		assert_false(settings_button.disabled)
		assert_eq(bridge._runtime_adapter.current_line_id(), _expected[0].line_id)
	var report := {"revision": OS.get_environment("DWM_BENCHMARK_REVISION"),
		"engine": Engine.get_version_info().string, "display": DisplayServer.get_name(),
		"locale": "en", "reveal": "instant", "auto": false,
		"text_size": profile.get_preference(&"preferences.accessibility.text_size", 0),
		"window_size": [get_window().size.x, get_window().size.y], "samples": samples,
		"limits": "Source project; Day1 opening after authored setup; first open is not cold OS cache. Process-frame and post-draw endpoints are not physical display latency. Assertions and event construction are outside timers."}
	print("SETTINGS_REOPEN_LATENCY " + JSON.stringify(report))
	_write_json("user://settings-reopen-latency.json", report)
