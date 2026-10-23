extends "res://tests/integration/scene_completion_child.gd"
## TEST registration only; admission uses the mounted caption's normal Viewport input.
func _start_playable() -> bool:
	if not _start_services(): return false
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return false
	# Let the ordinary text reveal finish; never invoke the runtime reveal/admission APIs.
	var deadline := Time.get_ticks_msec() + 15000
	while not bridge._runtime_adapter.is_current_line_complete() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(bridge._runtime_adapter.is_current_line_complete())
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.b.one")
	assert_true(caption.caption_text.is_visible_in_tree())
	assert_true("B first." in caption.caption_text.text)
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	var before_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	await _screenshot("manual-before-playable")
	await _click(caption.caption_text)
	var admitted: Dictionary = game.capture_scene_challenge_command()
	if not _ok(admitted): return false
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return false
	assert_eq(checkpoint.value.reading_session.boundary, "control")
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.b.one",
		"Accept admits Playable without clicking through to the next caption.")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "Admission does not start a board.")
	assert_eq(profile.get_profile_snapshot(), before_profile, "Admission creates no physical attempt/history.")
	var playable_count := 0
	for receipt: Dictionary in game.capture_run_snapshot_input().command_receipts.values():
		if receipt.get("scene_event", {}).get("result", {}).get("kind") == "challenge_playable":
			playable_count += 1
	assert_eq(playable_count, 1, "One normal accept creates exactly one Playable receipt.")
	await _screenshot("manual-playable-admitted")
	return true
