extends "res://tests/integration/scene_seven_day_connected_child.gd"
## No Save/Pause detour: organic reveal guard, fresh Accept, durable Title return.

func test_direct_ending_accept_returns_without_save() -> void:
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	var started: Dictionary = saves.start_scene_new_run("target.Day7", {
		"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("line.Day7.one"): return
	await _accept()
	if not await _wait_line("line.Day7.two"): return
	# Widen the existing organic-reveal delay only to make the observed timing
	# race deterministic on rendered CI. Do not alter timer/position/lifecycle.
	var old_delay: Variant = ProjectSettings.get_setting("dialogic/text/advance_delay", 0.1)
	ProjectSettings.set_setting("dialogic/text/advance_delay", 1.0)
	await _accept()
	if not await _wait_line("line.ending.alone.normal.one"):
		ProjectSettings.set_setting("dialogic/text/advance_delay", old_delay)
		return
	ProjectSettings.set_setting("dialogic/text/advance_delay", old_delay)
	var inputs: Node = bridge._runtime_adapter._dialogic.get_subsystem("Inputs")
	var ending: Dictionary = game._run_lifecycle.to_dict().duplicate(true)
	var before: Dictionary = bridge.capture_reading_checkpoint(false).duplicate(true)
	assert_true(inputs.is_input_blocked(), "organic reveal is complete while native input remains blocked")
	print("DIRECT_ENDING_GUARD before_early_accept=", inputs.input_block_timer.time_left)
	await _accept(false)
	assert_true(get_tree().current_scene is EndingScene, "guard refuses the premature Enter")
	assert_eq(game._run_lifecycle.to_dict(), ending, "premature input cannot complete ending")
	assert_eq(bridge.capture_reading_checkpoint(false), before, "premature input preserves the exact caption")
	await _accept()
	if not await _wait_route(MENU): return
	var finished: Dictionary = game._run_lifecycle.to_dict()
	assert_eq(finished.state, "COMPLETED")
	assert_eq(finished.ending_plan.next_step_index, 1)
	assert_eq(finished.ending_plan.playback_stage, "GALLERY_RECORDED")
	assert_false(game.capture_live_session().value.active)
	assert_false(FileAccess.file_exists("user://saves/slot_2.json"), "Save is not a prerequisite")
	var durable: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(durable): return
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.ending_plan, finished.ending_plan)
	assert_eq(durable.value.current_snapshot.snapshot.lifecycle.state, "COMPLETED")
	var gallery_id := "ending:%s:gallery:ending.alone" % str(finished.run_id)
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts.get(gallery_id),
		{"ending_id": "ending.alone", "unlocked": true})
	print("DIRECT_ENDING_GUARD fresh_accept_returned_to_title_without_save")
