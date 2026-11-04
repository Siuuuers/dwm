extends "res://tests/integration/authored_week_child.gd"

func test_shipped_result_transition() -> void:
	_phase = "create"
	if not _setup_authored(): return
	var entry := "Day7.untouched.impulse"
	var started: Dictionary = saves.start_scene_new_run("target." + entry, {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line(_expected[_entry_starts[entry]].line_id): return
	if not await _walk_authored(_entry_starts[entry] + 1, _entry_starts["Day7.A"] + 1): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day7.A.002")
	_write_json("res://.godot/ci/transition-" + OS.get_environment("DWM_TRANSITION_CASE") + ".json", {"timings": _timings,
		"scope": "fresh Run entering shipped Day7 impulse directly; no accumulated week history"})
