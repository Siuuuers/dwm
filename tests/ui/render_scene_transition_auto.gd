extends "res://tests/ui/render_scene_transition_base.gd"

func test_auto_waits_for_visible_transition_destination() -> void:
	if not await _begin_transition_fixture(): return
	await _click(_caption().transport_rail.get_node("Auto"))
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false))
	if not await _wait_transition_finished(): return
	assert_false(transition_frames.is_empty())
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false), "transition preserves enabled Auto preference")
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	assert_eq(bridge._runtime_adapter.current_line_id(), TARGET_LINE)
	assert_false(game.capture_scene_challenge_command().get("ok", false), "Auto has not consumed the hidden incoming caption")
	await _screenshot("scene-transition-auto-destination")
	if not _write_json("res://.godot/ci/scene-transition-auto.json", {"events": transition_events, "frames": transition_frames}): return
	print("SCENE_TRANSITION_AUTO_COMPLETED")
