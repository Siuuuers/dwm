extends "res://tests/integration/authored_week_child.gd"

func test_first_visit_ending() -> void:
	_phase = "load"
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-ending.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	if not _setup_authored(): return
	var before: Dictionary = profile.get_profile_snapshot()
	assert_eq(before, proof.profile)
	var first: int = _entry_starts["ending.alone.normal"] + 1
	for index: int in range(first, _expected.size()):
		assert_false(before.visited_line_ids.has(_expected[index].line_id))
	if not await _load_authored(2, proof): return
	if not await _walk_authored(first, _expected.size() - 1): return
	var finished: Dictionary = await _complete_authored()
	if finished.is_empty(): return
	var after: Dictionary = profile.get_profile_snapshot()
	for index: int in range(first, _expected.size()):
		assert_true(after.visited_line_ids.has(_expected[index].line_id))
	assert_eq(after.gallery_transaction_receipts.size(), before.gallery_transaction_receipts.size() + 1)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.slot_sha256)
	_write_json("res://.godot/ci/" + OS.get_environment("DWM_MATCH_CASE") + ".json", {
		"timings": _timings, "profile_sha256": FileAccess.get_sha256("user://profile.json"),
		"profile_before": before, "profile_after": after, "slot_sha256": proof.slot_sha256,
		"process_id": OS.get_process_id(), "completed_lifecycle": finished})
