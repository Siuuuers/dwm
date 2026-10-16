extends "res://tests/integration/scene_seven_day_connected_child.gd"
## Focused layout journey: real Title, registered Day7 and ending, not a full-week rerun.

func _clock(clock: Label) -> void:
	clock.configure_clock(func() -> Dictionary: return {"hour": 9, "minute": 7, "second": 13})
	clock.set_foreground_eligible(true)
	assert_eq(clock.text, "09:07")
	assert_eq(clock.focus_mode, Control.FOCUS_NONE)
	assert_eq(clock.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func _reading_layout() -> void:
	var layer: Node = _caption()
	var rail: Control = layer.transport_rail
	_clock(rail.clock_label)
	assert_eq(rail.position + rail.clock_label.position, Vector2(1128, 656))
	assert_eq(rail.clock_label.size, Vector2(152, 64))
	assert_eq(layer.scroll.get_rect().end.y, 592.0, "caption window ends before upper transport")
	assert_eq(layer.scroll.size.y, 208.0, "100% caption window keeps its reading height")
	for name: String in ["Skip", "Auto", "Next"]:
		var button: Control = rail.get_node(name)
		assert_true(button.is_visible_in_tree())
		assert_eq(rail.position.y + button.position.y, 592.0)
		assert_gte(button.position.x, 640.0)
		assert_false(layer.scroll.get_global_rect().intersects(button.get_global_rect()))
	assert_eq(rail.get_node("Next").get_rect().end.x, 1280.0)
	for name: String in ["History", "Save", "Load"]:
		var button: Control = rail.get_node(name)
		assert_true(button.is_visible_in_tree())
		assert_eq(rail.position.y + button.position.y, 656.0)
		assert_false(button.get_rect().intersects(rail.clock_label.get_rect()))

func test_clock_and_upper_transport_on_title_ordinary_and_ending() -> void:
	if not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	var menu: Node = get_tree().current_scene
	_clock(menu._clock_label)
	assert_eq(menu._clock_label.get_global_rect(), Rect2(1128, 656, 152, 64))
	assert_true(menu._new_acc_button.is_visible_in_tree())
	await _screenshot("clock-title")
	var started: Dictionary = saves.start_scene_new_run("target.Day7", {
		"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("line.Day7.one"): return
	_reading_layout()
	await _screenshot("clock-ordinary")
	# Ordinary schema-2 reading retains existing Next unavailability. A click must
	# not fall through to background Accept after moving the control.
	assert_true(_caption().transport_rail.get_node("Next").disabled)
	await _click(_caption().transport_rail.get_node("Next"))
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day7.one")
	await _accept()
	if not await _wait_line("line.Day7.two"): return
	await _accept()
	if not await _wait_line("line.ending.alone.normal.one"): return
	assert_true(get_tree().current_scene is EndingScene)
	_reading_layout()
	await _screenshot("clock-ending")
	await _accept()
	if not await _wait_route(MENU): return
	_clock(get_tree().current_scene._clock_label)
	assert_eq(get_tree().current_scene._clock_label.get_global_rect(), Rect2(1128, 656, 152, 64))
	assert_true(get_tree().current_scene._new_acc_button.is_visible_in_tree())
	await _screenshot("clock-return-title")
