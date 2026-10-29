extends "res://tests/integration/scene_inline_audio_child.gd"

func test_auto_plays_and_skip_consumes_one_shots_without_a_later_burst() -> void:
	if not await _begin_inline(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_delay", "short")): return
	if not _ok(profile.set_preference(&"preferences.reading.skip_mode", "all_text")): return
	await _click(_caption().transport_rail.get_node("Auto"))
	var deadline := Time.get_ticks_msec() + 12000
	while bridge._runtime_adapter.current_line_id() == "line.scene.test.a.one" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two")
	await _click(_caption().transport_rail.get_node("Auto"))
	assert_eq(_starts("SFX"), 2, "Auto executes the accompanying one-shot")
	_assert_selection("TEST.inline.b")
	await _click(_caption().transport_rail.get_node("Skip"))
	deadline = Time.get_ticks_msec() + 12000
	while _caption().skip_controller.is_skip_active() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(_caption().skip_controller.is_skip_active())
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.five")
	_assert_selection("TEST.inline.a")
	assert_eq(_starts("SFX"), 2, "Skip consumes intermediate SFX")
	for frame: int in 10: await get_tree().process_frame
	assert_eq(_starts("SFX"), 2, "suppressed SFX are never queued")
	if not await _advance_to("four"): return
	assert_eq(_starts("SFX"), 3, "later manual encounter remains audible")
	# The existing Scene Next control does not admit this ordinary loop.
	# A disabled click is not evidence that a fast traversal executed.
	if _caption().caption_text.revealing: await _accept()
	assert_false(_caption()._next_admitted(), "ordinary Scene fast Next is currently unavailable")
	var before_next: Dictionary = bridge.capture_reading_checkpoint(false)
	await _click(_caption().transport_rail.get_node("Next"))
	assert_eq(bridge.capture_reading_checkpoint(false), before_next)
	assert_eq(_starts("SFX"), 3, "unavailable Next leaves the encounter unchanged")
	_assert_selection("TEST.inline.a")
	await _screenshot("inline-audio-transport")
	_write_json("res://.godot/ci/inline-audio-transport.json", {"starts": observed.starts,
		"line_id": bridge._runtime_adapter.current_line_id(), "renderer": DisplayServer.get_name()})
