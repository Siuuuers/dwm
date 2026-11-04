extends "res://tests/integration/authored_week_child.gd"

func test_loaded_late_transition_and_following_caption() -> void:
	_phase = "load"
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-late-transition.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	var seed_user_dir: String = proof.user_dir
	assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	assert_eq(_autosave_sha256(), proof.autosave_sha256)
	if not _setup_authored(): return
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	var first: int = _entry_starts["Day7.A"]
	assert_eq(_expected[first - 1].line_id, "line.Day7.untouched.impulse.004")
	assert_eq(_expected[first].line_id, "line.Day7.A.001")
	assert_eq(_expected[first + 1].line_id, "line.Day7.A.002")
	for index: int in [first, first + 1]:
		assert_false(profile.get_profile_snapshot().visited_line_ids.has(_expected[index].line_id))
	# The wrapper clones exact saved bytes into each process's isolated user directory.
	proof.user_dir = ProjectSettings.globalize_path("user://")
	if not await _load_authored(3, proof): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day7.untouched.impulse.004")
	_timings.clear()
	if not await _walk_authored(first, first + 1): return
	assert_eq(_timings.size(), 2)
	assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.slot_sha256)
	for index: int in [first, first + 1]:
		assert_true(profile.get_profile_snapshot().visited_line_ids.has(_expected[index].line_id))
	var case_id := OS.get_environment("DWM_MATCH_CASE")
	assert_false(case_id.is_empty())
	if case_id.is_empty(): return
	_write_json("res://.godot/ci/late-transition/" + case_id + ".json", {
		"timings": _timings, "process_id": OS.get_process_id(), "seed_process_id": proof.process_id,
		"seed_user_dir": seed_user_dir, "user_dir": ProjectSettings.globalize_path("user://"),
		"slot_sha256": proof.slot_sha256, "seed_profile_sha256": proof.profile_sha256,
		"profile_sha256": FileAccess.get_sha256("user://profile.json"),
		"registration_sha256": AUTHORED_MANIFEST.scene_registration_fingerprint(),
		"observed_lines": observed_lines})
