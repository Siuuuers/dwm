extends "res://tests/integration/scene_seven_day_connected_child.gd"
## No Save/Pause detour: organic reveal guard, fresh Accept, durable Title return.

func _ending_layout_observation(prior_layout_ref: WeakRef) -> Dictionary:
	var prior_layout: Node = prior_layout_ref.get_ref()
	var native: Node = bridge._runtime_adapter._dialogic
	var active: Node = native.Styles.get_layout_node()
	var result := {"process_id": OS.get_process_id(),
		"window_handle": DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, get_tree().root.get_window_id()),
		"prior_layout_alive": is_instance_valid(prior_layout),
		"prior_layout_in_tree": is_instance_valid(prior_layout) and prior_layout.is_inside_tree(),
		"layout_id": 0, "style": "", "caption_script": "",
		"ending_layout": false, "clock_present": true,
		"lifecycle": game._run_lifecycle.to_dict().duplicate(true),
		"reading_checkpoint": bridge.capture_reading_checkpoint(false).duplicate(true)}
	if is_instance_valid(active):
		result.layout_id = active.get_instance_id()
		var style: Resource = active.get_meta("style", null)
		if style != null: result.style = style.resource_path
	var current_caption: Node = _caption()
	if is_instance_valid(current_caption):
		result.caption_script = current_caption.get_script().resource_path
		result.ending_layout = current_caption.transport_rail.ending_layout
		result.clock_present = current_caption.transport_rail.has_node("AudienceClock")
	return result

func _capture_ending_layout() -> Dictionary:
	if DisplayServer.get_name() == "headless": return {}
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	assert_false(pixels.is_empty())
	var path := "res://.godot/ci/ending-layout-boundary.png"
	assert_eq(pixels.save_png(path), OK)
	return {"file": "ending-layout-boundary.png", "source": "Godot viewport, not desktop",
		"width": pixels.get_width(), "height": pixels.get_height(),
		"sha256": FileAccess.get_sha256(path)}

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
	var prior_layout: Node = bridge._runtime_adapter._dialogic.Styles.get_layout_node()
	var prior_layout_id: int = prior_layout.get_instance_id()
	var prior_layout_ref: WeakRef = weakref(prior_layout)
	var default_style: Variant = ProjectSettings.get_setting("dialogic/layout/default_style", "")
	var end_behaviour: Variant = ProjectSettings.get_setting("dialogic/layout/end_behaviour", 0)
	# Widen the existing organic-reveal delay only to make the observed timing
	# race deterministic on rendered CI. Do not alter timer/position/lifecycle.
	var old_delay: Variant = ProjectSettings.get_setting("dialogic/text/advance_delay", 0.1)
	ProjectSettings.set_setting("dialogic/text/advance_delay", 1.0)
	await _accept()
	var ending_ready: bool = await _wait_line("line.ending.alone.normal.one")
	if not ending_ready:
		_write_json("res://.godot/ci/ending-layout-boundary.json", _ending_layout_observation(prior_layout_ref))
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
	var observation := _ending_layout_observation(prior_layout_ref)
	observation["prior_layout_id"] = prior_layout_id
	observation["ending_ready"] = ending_ready
	observation["capture"] = await _capture_ending_layout()
	_write_json("res://.godot/ci/ending-layout-boundary.json", observation)
	assert_eq(observation.style, "res://dialogic/styles/witnessed_caption_style.tres")
	assert_eq(observation.caption_script, "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
	assert_ne(observation.layout_id, prior_layout_id, "ending selects its own layout after the ordinary layout retires")
	assert_false(observation.prior_layout_in_tree)
	assert_true(observation.ending_layout, "EndingScene retains its accepted six bottom controls")
	assert_false(observation.clock_present, "ending has no rail clock")
	assert_eq(ProjectSettings.get_setting("dialogic/layout/default_style", ""), default_style)
	assert_eq(ProjectSettings.get_setting("dialogic/layout/end_behaviour", 0), end_behaviour)
	# Comparative measurement only: retain the short route's real Accept and all
	# completion assertions. The inherited writer forwards to the production owner.
	if not _install_ending_writer_timing(): return
	_ending_phase_timing = true
	var had_checkpoint_profile: bool = OS.has_environment("DWM_CHECKPOINT_PROFILE")
	var previous_checkpoint_profile: String = OS.get_environment("DWM_CHECKPOINT_PROFILE")
	var had_scene_profile: bool = OS.has_environment("DWM_SCENE_VALIDATION_PROFILE")
	var previous_scene_profile: String = OS.get_environment("DWM_SCENE_VALIDATION_PROFILE")
	OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", "1")
	OS.set_environment("DWM_CHECKPOINT_PROFILE", "1")
	_ending_phase("direct_ending.accept.begin")
	await _accept()
	_ending_phase("direct_ending.accept.return")
	game._ending_checkpoint_writer = _original_ending_writer
	if had_checkpoint_profile:
		OS.set_environment("DWM_CHECKPOINT_PROFILE", previous_checkpoint_profile)
	else:
		OS.unset_environment("DWM_CHECKPOINT_PROFILE")
	if had_scene_profile:
		OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", previous_scene_profile)
	else:
		OS.unset_environment("DWM_SCENE_VALIDATION_PROFILE")
	_ending_phase_timing = false
	assert_gt(_ending_writer_calls, 0, "fresh Accept must exercise the real checkpoint writer")
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

