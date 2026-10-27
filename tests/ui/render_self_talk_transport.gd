extends "res://tests/ui/render_self_talk_base.gd"
## Actual profile settings and rail input cross pairs through Auto and Skip.
var _native_lines: Array[String] = []

func _self_talk_markers() -> Array:
	return [{"marker_id": "scene.test.a.transition", "label": "scene.test.a.loop",
		"after_line_id": "line.scene.test.a.five", "kind": "scene.transition", "payload": {"target_id": "target_b"}}]

func _observe_native_line(_info: Dictionary) -> void:
	var runtime: Node = get_node("/root/Dialogic")
	var event: DialogicEvent = runtime.current_timeline.events[runtime.current_event_idx]
	if event is DialogicTextEvent:
		_native_lines.append(bridge._runtime_adapter._authored_line_id(event))

func _assert_pair_witnessed(caption_id: String) -> void:
	var beats: Array[Dictionary] = bridge._reading_session.scene_pair_beats(caption_id)
	assert_eq(beats.size(), 2)
	for beat: Dictionary in beats:
		assert_true(profile.is_caption_variant_witnessed(beat), "both authored variants witnessed: " + str(beat.line_id))
		assert_true(profile.is_line_visited(beat.line_id), "both stable line IDs visited: " + str(beat.line_id))

func test_auto_and_skip_cross_paired_text_without_executing_transition() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.reading.auto_delay", "short")): return
	if not _ok(profile.set_preference(&"preferences.reading.skip_mode", "all_text")): return
	get_node("/root/Dialogic").Text.text_started.connect(_observe_native_line)
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	for frame: int in 5: await get_tree().process_frame
	var caption: Node = _caption()
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.one")
	_assert_pair_witnessed("line.scene.test.a.one")
	assert_false(profile.is_line_visited("line.scene.test.a.two"))
	assert_false(profile.is_line_visited("line.scene.test.a.thought_two"))
	await _click(caption.transport_rail.get_node("Auto"))
	assert_true(profile.get_preference(&"preferences.reading.auto_enabled", false))
	var deadline := Time.get_ticks_msec() + 12000
	while bridge._runtime_adapter.current_line_id() == "line.scene.test.a.one" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two", "Auto reaches next primary caption without a thought-only step")
	for frame: int in 3: await get_tree().process_frame
	await _click(caption.transport_rail.get_node("Auto"))
	assert_false(profile.get_preference(&"preferences.reading.auto_enabled", true), "actual Auto button disables further automatic progression")
	_assert_pair_witnessed("line.scene.test.a.two")
	assert_eq(bridge.capture_self_talk_presentation().value.rows.size(), 2)
	assert_eq(_native_lines, ["line.scene.test.a.one", "line.scene.test.a.two"], "thoughts never became independent native text steps")
	await _capture_self_talk("auto-paired-step")
	assert_false(profile.is_line_visited("line.scene.test.a.four"))
	assert_false(profile.is_line_visited("line.scene.test.a.thought_three"))
	assert_false(profile.is_line_visited("line.scene.test.a.five"))
	assert_false(profile.is_line_visited("line.scene.test.a.thought_four"))
	await _click(caption.transport_rail.get_node("Skip"))
	deadline = Time.get_ticks_msec() + 12000
	while caption.skip_controller.is_skip_active() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(caption.skip_controller.is_skip_active(), "Skip stops at the required authored transition")
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.five", "Skip all crosses previously unread paired captions")
	assert_eq(bridge._reading_session.boundary, "line", "Skip does not execute transition")
	assert_eq(bridge._reading_session.latest_entry, "scene.test.a", "target B was not admitted")
	assert_false(profile.is_line_visited("line.scene.test.b.one"))
	assert_false(profile.is_line_visited("line.scene.test.a.six"))
	_assert_pair_witnessed("line.scene.test.a.four")
	_assert_pair_witnessed("line.scene.test.a.five")
	assert_eq(_native_lines, ["line.scene.test.a.one", "line.scene.test.a.two", "line.scene.test.a.three",
		"line.scene.test.a.four", "line.scene.test.a.five"])
	assert_eq(_history_ids(), ["line.scene.test.a.one", "line.scene.test.a.thought_one", "line.scene.test.a.two",
		"line.scene.test.a.thought_two", "line.scene.test.a.three", "line.scene.test.a.four",
		"line.scene.test.a.thought_three", "line.scene.test.a.five", "line.scene.test.a.thought_four"])
	await _capture_self_talk("skip-paired-boundary")
	_write_json("res://.godot/ci/self-talk-transport.json", {"native_lines": _native_lines,
		"history_ids": _history_ids(), "boundary": str(bridge._runtime_adapter.classify_next_event()),
		"skip_active": caption.skip_controller.is_skip_active(), "auto_enabled": caption.auto_controller.is_auto_enabled()})
	print("SELF_TALK_TRANSPORT_COMPLETED native_steps=", _native_lines.size(), " paired_history_rows=", _history_ids().size())
