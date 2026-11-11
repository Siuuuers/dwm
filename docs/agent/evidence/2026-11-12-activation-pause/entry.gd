extends "res://tests/manual/benchmark_player_latency.gd"

func test_entry_probe() -> void:
	_phase = "create"
	if not _setup_authored(false, "Day2"): return
	get_tree().process_frame.connect(observe_frame)
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	for index: int in range(1, _entry_starts["Day2"] + 1):
		var caption: Node = _caption()
		caption.caption_text.grab_focus()
		await get_tree().process_frame
		var started := begin_sample()
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			get_viewport().push_input(event, true)
		if not await _wait_line(_expected[index].line_id): return
		if index == _entry_starts[_expected[index].entry_id]:
			end_sample("entry", started, _expected[index].line_id)
		else: measuring = false
	assert_eq(bridge._runtime_adapter.current_line_id(), _expected[_entry_starts["Day2"]].line_id)
