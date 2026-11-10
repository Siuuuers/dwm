extends "res://tests/integration/authored_week_child.gd"

func test_history_and_save_do_not_construct_settings() -> void:
	_phase = "create"
	if not _setup_authored(false, "Day1"): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	var caption: Node = _caption()
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	await caption._on_history_requested()
	assert_true(caption._history_open)
	assert_false(pause.surface._hosts.has(&"settings"))
	await caption._on_history_close_requested()
	assert_false(caption._history_open)
	assert_true((await pause.open_scene_backup("save")).get("ok", false))
	assert_false(pause.surface._hosts.has(&"settings"))
	assert_true((await pause.request_continue()).get("ok", false))
	assert_true((await pause.open_scene_settings()).get("ok", false))
	var settings: Control = pause.surface._hosts[&"settings"]
	assert_eq(pause.surface.entered_action, &"settings")
	assert_true(settings.is_visible_in_tree())
	assert_true((await pause.request_continue()).get("ok", false))
	assert_true((await pause.open_scene_settings()).get("ok", false))
	assert_same(pause.surface._hosts[&"settings"], settings)
	assert_true((await pause.request_continue()).get("ok", false))
	assert_eq(bridge._runtime_adapter.current_line_id(), _expected[0].line_id)
