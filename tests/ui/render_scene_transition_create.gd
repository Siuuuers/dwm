extends "res://tests/ui/render_scene_transition_base.gd"

func test_manual_transition_discards_input_then_saves_visible_destination() -> void:
	if not await _begin_transition_fixture(): return
	await _screenshot("scene-transition-source")
	await _click(_caption().transport_rail.get_node("Next"))
	assert_true(bridge.is_scene_transition_active(), "manual Next starts the rendered dissolve")
	if not bridge.is_scene_transition_active(): return
	# A fresh contact entirely within the transition, followed by a held contact.
	_transition_key(true)
	await get_tree().process_frame
	_transition_key(false)
	await get_tree().process_frame
	_transition_key(true)
	_transition_key(true, true)
	while bridge.is_scene_transition_active() and bridge._scene_transition_progress < 0.25:
		await get_tree().process_frame
	var mid_capture := false
	if bridge.is_scene_transition_active():
		await RenderingServer.frame_post_draw
		if bridge.is_scene_transition_active():
			var pixels: Image = get_viewport().get_texture().get_image()
			assert_eq(pixels.save_png("res://.godot/ci/scene-transition-middle.png"), OK)
			mid_capture = true
	if not await _wait_transition_finished(): return
	assert_false(transition_frames.is_empty(), "actual transition frames were observed")
	assert_false(transition_frames.filter(func(frame: Dictionary) -> bool:
		return frame.has_capture and frame.has_tween and frame.progress_millionths > 0 and frame.progress_millionths < 1000000).is_empty(),
		"an actual captured intermediate frame progressed through the dissolve")
	assert_gte(int(transition_events[1].ticks_usec) - int(transition_events[0].ticks_usec), 200000,
		"normal motion includes the selected 250 ms animation")
	_transition_key(false)
	for frame: int in 3: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), TARGET_LINE, "release of a transition-held key cannot advance")
	assert_eq(bridge._reading_session.boundary, "line")
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	await _screenshot("scene-transition-destination")
	if not await _save_transition_slot(): return
	await _accept()
	assert_true(game.capture_scene_challenge_command().get("ok", false), "fresh post-transition input reaches the next authored control")
	assert_eq(bridge._reading_session.boundary, "control")
	assert_false(profile.is_line_visited("line.scene.test.b.two"))
	if not _write_json("res://.godot/ci/scene-transition-create.json", {"events": transition_events,
		"frames": transition_frames, "process_id": OS.get_process_id(), "mid_capture": mid_capture}): return
	print("SCENE_TRANSITION_CREATE_COMPLETED")
