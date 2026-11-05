extends "res://tests/integration/authored_week_child.gd"

var samples: Array[Dictionary] = []
var measuring := false
var previous_frame := 0
var largest_frame := 0
var sample_started := 0
var presented_us := -1

func observe_frame() -> void:
	var now := Time.get_ticks_usec()
	if measuring: largest_frame = maxi(largest_frame, now - previous_frame)
	previous_frame = now

func begin_sample() -> int:
	largest_frame = 0
	previous_frame = Time.get_ticks_usec()
	measuring = true
	sample_started = previous_frame
	presented_us = -1
	return previous_frame

func end_sample(action: String, started: int, detail: String = "") -> void:
	measuring = false
	var row := {"action": action, "detail": detail, "elapsed_us": Time.get_ticks_usec() - started, "largest_frame_us": largest_frame}
	if presented_us >= 0: row["presentation_ack_us"] = presented_us
	samples.append(row)
	print("PLAYER_LATENCY " + JSON.stringify(row))

func draw_complete() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

func _wait_line(line_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if bridge._runtime_adapter.current_line_id() == line_id and bridge.is_current_line_presentation_acknowledged():
			var caption: Node = _caption()
			if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree() and not caption.caption_text.revealing:
				await draw_complete()
				presented_us = Time.get_ticks_usec() - sample_started
				break
		await get_tree().process_frame
	return await super._wait_line(line_id)

func _click(control: Control) -> void:
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	var point := control.get_global_transform_with_canvas() * (control.size / 2.0)
	for pressed: bool in [true, false]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		get_viewport().push_input(motion, true)
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await get_tree().process_frame
	await draw_complete()

func audit_ui(label: String) -> void:
	var caption: Node = _caption()
	for attempt: int in 3:
		var started := begin_sample()
		await _click(caption.transport_rail._history_button)
		assert_true(caption._history_open)
		end_sample("history", started, label)
		await _click(caption._history_overlay.close_button)
		started = begin_sample()
		await _click(caption.transport_rail.get_node("Save"))
		var sheet: Node = get_node("/root/SceneRouter")._production_pause
		assert_not_null(sheet)
		end_sample("save_menu", started, label)
		if not is_instance_valid(sheet): return
		var app: Control = sheet.surface._hosts[&"backup"]
		await _click(app.drawer_buttons["slot:1"])
		started = begin_sample()
		await _click(app.action_buttons["save"])
		if is_instance_valid(app.confirmation): await _click(app.confirmation.confirm_button)
		while app._in_operation: await get_tree().process_frame
		await draw_complete()
		end_sample("save_write", started, label)
		assert_true(app.last_result.get("ok", false))
		await _click(sheet.surface._sheet_back)
		assert_false(get_tree().paused)
		started = begin_sample()
		await _click(caption.transport_rail._settings_button)
		end_sample("settings", started, label)
		var host: Node = get_tree().current_scene
		var computer: Control = host.get_node("SceneControlsLayer/Surface/Controls/CheckComputer")
		assert_true(host.is_computer_open())
		await _click(computer)
		assert_false(host.is_computer_open())
		started = begin_sample()
		await _click(computer)
		assert_true(host.is_computer_open())
		end_sample("computer", started, label)
		await _click(computer)
		assert_false(host.is_computer_open())

func audit_title() -> void:
	if not await _wait_route(MENU): return
	for frame: int in 3: await get_tree().process_frame
	var menu: Node = get_tree().current_scene
	for attempt: int in 3:
		var started := begin_sample()
		await _click(menu.get_node("%GalleryButton"))
		var gallery: Node = menu._gallery_instance
		assert_not_null(gallery)
		end_sample("gallery", started, str(attempt))
		if not is_instance_valid(gallery): return
		started = begin_sample()
		await _click(gallery._gallery_tabs.get_child(2))
		end_sample("dialogue_library", started, str(attempt))
		await _click(gallery._gallery_tabs.get_child(1))
		for row: Button in gallery._artwork._rows:
			if DisplayServer.get_name() == "headless": continue
			assert_false(row.disabled)
			started = begin_sample()
			await _click(row)
			end_sample("artwork_select", started, row.name)
			started = begin_sample()
			await _click(gallery._artwork._preview)
			assert_true(is_instance_valid(gallery._artwork._viewer))
			end_sample("artwork_fullscreen", started, row.name)
			gallery._artwork.close_viewer()
			await get_tree().process_frame
		await menu._close_gallery()
	var started := begin_sample()
	await _click(menu.get_node("%LogInButton"))
	end_sample("load_menu", started)
	var app: Control = menu._backup_app_instance
	await _click(app.drawer_buttons["slot:1"])
	ready_count = 0
	started = begin_sample()
	await _click(app.action_buttons["load"])
	if is_instance_valid(app) and is_instance_valid(app.confirmation): await _click(app.confirmation.confirm_button)
	if not await _await_ready(): return
	await draw_complete()
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day7.untouched.impulse.004")
	assert_eq(_caption().caption_text.get_parsed_text(), _texts["line.Day7.untouched.impulse.004"])
	end_sample("load_checkpoint", started)

func test_player_latency() -> void:
	_phase = "create"
	if not _setup_authored(false): return
	get_tree().process_frame.connect(observe_frame)
	get_node("/root/SceneRouter").goto_menu()
	var started := begin_sample()
	if not await _new_from_title(1, _expected[0].line_id): return
	end_sample("new_game_flow", started)
	await audit_ui("Day1")
	for index: int in range(1, _expected.size()):
		var caption: Node = _caption()
		caption.caption_text.grab_focus()
		await get_tree().process_frame
		started = begin_sample()
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			get_viewport().push_input(event, true)
		if not await _wait_line(_expected[index].line_id): return
		end_sample("entry" if index == _entry_starts[_expected[index].entry_id] else "caption", started, _expected[index].line_id)
		if _expected[index].line_id == "line.Day7.untouched.impulse.004": await audit_ui("Day7")
	await _complete_authored()
	await audit_title()
	_write_json("res://.godot/ci/player-latency.json", {"revision": OS.get_environment("DWM_BENCHMARK_REVISION"), "display": DisplayServer.get_name(), "artwork_samples_excluded": DisplayServer.get_name() == "headless", "samples": samples})
