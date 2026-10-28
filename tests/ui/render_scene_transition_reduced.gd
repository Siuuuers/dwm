extends "res://tests/ui/render_scene_transition_base.gd"

func test_reduced_motion_swaps_without_snapshot_animation() -> void:
	if not await _begin_transition_fixture(true): return
	await _click(_caption().transport_rail.get_node("Next"))
	if not await _wait_transition_finished(): return
	for frame: Dictionary in transition_frames:
		assert_false(frame.has_capture, "Reduced Motion never holds a captured dissolve image")
		assert_false(frame.has_tween, "Reduced Motion adds no hidden animation timer")
	assert_true(get_node("/root/AccessibilityManager").should_reduce_motion())
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	await _screenshot("scene-transition-reduced-destination")
	_write_json("res://.godot/ci/scene-transition-reduced.json", {"events": transition_events, "frames": transition_frames})
	print("SCENE_TRANSITION_REDUCED_COMPLETED")
