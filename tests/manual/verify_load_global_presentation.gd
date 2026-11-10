extends "res://tests/integration/authored_week_child.gd"

func test_load_keeps_current_global_presentation_and_reuses_unchanged_run_theme() -> void:
	_phase = "create"
	if not _setup_authored(false, "Day1"): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	var proof: Dictionary = await _save_authored(1, "global-presentation")
	assert_false(proof.is_empty())
	if proof.is_empty(): return
	assert_true(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
	var caption: Node = _caption()
	assert_eq(caption.get_caption_projection().text_percent, 150)
	assert_true(caption.get_caption_projection().high_contrast)
	var material: Theme = caption._caption_theme
	assert_true(caption.configure_run_presentation(get_node("/root/GameState")))
	assert_same(caption._caption_theme, material)
	if not await _wait_line(_expected[0].line_id): return
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	var opened: Dictionary = await pause.open_scene_backup("load")
	assert_true(opened.get("ok", false))
	if not opened.get("ok", false): return
	var app: Control = pause.surface._hosts[&"backup"]
	if not await _press_authored(app.drawer_buttons["slot:1"]): return
	ready_count = 0
	if not await _press_authored(app.action_buttons["load"]): return
	if is_instance_valid(app) and is_instance_valid(app.confirmation):
		if not await _press_authored(app.confirmation.confirm_button): return
	if not await _await_ready(): return
	if not await _wait_line(_expected[0].line_id): return
	caption = _caption()
	assert_eq(profile.get_preference(&"preferences.accessibility.text_size"), 150)
	assert_true(profile.get_preference(&"preferences.accessibility.high_contrast"))
	assert_eq(caption.get_caption_projection().text_percent, 150)
	assert_true(caption.get_caption_projection().high_contrast)
	assert_eq(caption.get_caption_projection().day, get_node("/root/GameState").day)
	material = caption._caption_theme
	assert_true(caption.configure_run_presentation(get_node("/root/GameState")))
	assert_same(caption._caption_theme, material)
	assert_true(profile.set_preference(&"preferences.accessibility.text_size", 125).get("ok", false))
	assert_eq(caption.get_caption_projection().text_percent, 125)
	assert_true(caption.get_caption_projection().high_contrast)
	assert_ne(caption._caption_theme, material)
