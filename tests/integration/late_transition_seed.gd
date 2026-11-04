extends "res://tests/integration/authored_week_child.gd"

func test_seed_naturally_reached_late_transition() -> void:
	_phase = "create"
	if not _setup_authored(): return
	assert_false(FileAccess.file_exists("user://saves/slot_3.json"))
	if FileAccess.file_exists("user://saves/slot_3.json"): return
	var first: int = _entry_starts["Day7.A"]
	assert_eq(_expected[first - 1].line_id, "line.Day7.untouched.impulse.004")
	assert_eq(_expected[first].line_id, "line.Day7.A.001")
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	if not await _walk_authored(1, first - 1): return
	assert_eq(observed_lines.size(), first)
	assert_false(profile.get_profile_snapshot().visited_line_ids.has(_expected[first].line_id))
	var proof: Dictionary = await _save_authored(3, "late-transition")
	if proof.is_empty(): return
	var destination := ProjectSettings.globalize_path("res://.godot/ci/late-transition/seed")
	assert_false(DirAccess.dir_exists_absolute(destination), "seed destination must be fresh")
	if DirAccess.dir_exists_absolute(destination): return
	if not _copy_late_seed(ProjectSettings.globalize_path("user://"), destination): return
	assert_eq(FileAccess.get_sha256(destination.path_join("saves/slot_3.json")), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256(destination.path_join("profile.json")), proof.profile_sha256)
	var live_input: Dictionary = game.capture_run_snapshot_input()
	var sizes := {"receipt_count": live_input.command_receipts.size(), "receipt_bytes": JSON.stringify(live_input.command_receipts).to_utf8_buffer().size(), "snapshot_bytes": JSON.stringify(live_input).to_utf8_buffer().size(), "ledger_captions": bridge._reading_session.ledger.snapshot().captions.size()}
	_timings.clear()
	if not await _walk_authored(first, first + 1): return
	assert_eq(_timings.size(), 2)
	assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.slot_sha256)
	_write_json("res://.godot/ci/late-transition/aged.json", {
		"timings": _timings, "live_sizes": sizes, "process_id": OS.get_process_id(),
		"slot_sha256": proof.slot_sha256, "seed_profile_sha256": proof.profile_sha256,
		"profile_sha256": FileAccess.get_sha256("user://profile.json")})

func _copy_late_seed(source: String, destination: String) -> bool:
	var made := DirAccess.make_dir_recursive_absolute(destination)
	assert_eq(made, OK)
	if made != OK: return false
	for file: String in DirAccess.get_files_at(source):
		var copied := DirAccess.copy_absolute(source.path_join(file), destination.path_join(file))
		assert_eq(copied, OK, file)
		if copied != OK: return false
	for folder: String in DirAccess.get_directories_at(source):
		if not _copy_late_seed(source.path_join(folder), destination.path_join(folder)): return false
	return true
