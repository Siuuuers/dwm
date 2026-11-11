extends "res://tests/manual/benchmark_player_latency.gd"

func test_history_probe() -> void:
	_phase = "load"
	if not _setup_authored(false, "Day1"): return
	get_tree().process_frame.connect(observe_frame)
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	await _click(get_tree().current_scene.get_node("%LogInButton"))
	var app: Control = get_tree().current_scene._backup_app_instance
	await _click(app.drawer_buttons["slot:1"])
	ready_count = 0
	await _click(app.action_buttons["load"])
	if is_instance_valid(app) and is_instance_valid(app.confirmation): await _click(app.confirmation.confirm_button)
	if not await _await_ready(): return
	var caption: Node = _caption()
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day7.untouched.impulse.004")
	var history: Dictionary = bridge.get_reading_history()
	assert_true(history.ok)
	print("HISTORY_CONTENT " + JSON.stringify(history.value.captions).sha256_text())
	for attempt: int in 5:
		var started := begin_sample()
		await _click(caption.transport_rail._history_button)
		assert_true(caption._history_open)
		end_sample("history", started, str(attempt))
		assert_eq(caption._history_overlay._captions.size(), history.value.captions.size())
		started = Time.get_ticks_usec()
		for check: int in 20: assert_true(caption._history_overlay_admitted())
		print("ADMISSION_US " + str((Time.get_ticks_usec() - started) / 20.0))
		var scroll: ScrollContainer = caption._history_overlay.reading_scroll
		assert_gt(scroll.get_v_scroll_bar().max_value, scroll.get_v_scroll_bar().page)
		scroll._accessibility_page(null, 1, scroll.generation)
		await get_tree().process_frame
		assert_gt(scroll.scroll_vertical, 0)
		scroll._accessibility_page(null, -1, scroll.generation)
		await get_tree().process_frame
		assert_eq(scroll.scroll_vertical, 0)
		caption._history_overlay.close_button._activate(null, caption._history_overlay.close_button.generation)
		await get_tree().process_frame
		assert_false(caption._history_open)
		assert_false(get_tree().paused)
		for frame: int in 4: await get_tree().process_frame
		assert_true(caption._history_admitted())
	assert_eq(bridge.get_reading_history(), history)
