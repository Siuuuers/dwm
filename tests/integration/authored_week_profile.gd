extends "res://tests/integration/authored_week_child.gd"
## Bounded fresh-Title baseline; never whole-week acceptance.
const TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")

func _measure_memory(label: String) -> void:
	var caption: Node = _caption()
	var started := Time.get_ticks_usec()
	var result: Dictionary = bridge.get_scene_caption_memory(caption._presented_line)
	var elapsed := Time.get_ticks_usec() - started
	assert_true(result.get("ok", false), "measured memory remains valid")
	print("AUTHORED_MEMORY_TIMING " + JSON.stringify({"label": label, "elapsed_us": elapsed,
		"ok": result.get("ok", false), "captions": result.get("value", {}).get("captions", []).size()}))

func test_profile_first_32_authored_captions() -> void:
	_phase = "create"
	_ending_phase_timing = true
	if not _setup_authored(): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1): return
	_measure_memory("first")
	for index: int in range(1, 32):
		var active := TIMING.begin_scope("authored_caption_%d" % index, "PLAYING", "", index)
		assert_true(active, "profiling enabled")
		if not active: return
		var ok: bool = await _walk_authored(index, index)
		if active: TIMING.end_scope(ok)
		if not ok: return
	_measure_memory("32")
	assert_eq(observed_lines.size(), 32)
	await _screenshot("authored-profile-32")
	_write_json("res://.godot/ci/authored-profile.json", {"scope": "fresh_title_first_32_captions",
		"observed_lines": observed_lines, "timings": _timings, "process_id": OS.get_process_id()})
