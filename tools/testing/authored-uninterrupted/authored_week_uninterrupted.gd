extends "res://tests/integration/authored_week_child.gd"
## Diagnostic only: one fresh process, shipped default route, no Save/Load detour.
## The cloud controller selects this one method and owns the 3600-second budget.

func test_uninterrupted_authored_week_from_title_to_completed_title() -> void:
	_phase = "create"
	for path: String in ["user://saves/autosave.json", "user://saves/slot_1.json", "user://saves/slot_2.json"]:
		assert_false(FileAccess.file_exists(path), "fresh isolated journey: " + path)
		if FileAccess.file_exists(path): return
	if not _setup_authored(): return
	var before: Dictionary = profile.get_profile_snapshot()
	assert_true(before.gallery_transaction_receipts.is_empty(), "fresh Profile has no Gallery receipts")
	if not before.gallery_transaction_receipts.is_empty(): return
	var registration: String = AUTHORED_MANIFEST.scene_registration_fingerprint()
	var started := Time.get_ticks_msec()
	print("AUTHORED_UNINTERRUPTED_BEGIN process_id=", OS.get_process_id(), " registration_sha256=", registration)
	get_node("/root/SceneRouter").goto_menu()
	if not await _wait_route(MENU): return
	await _screenshot("authored-uninterrupted-title")
	if not await _new_from_title(1): return
	var run_id: String = str(game._run_lifecycle.to_dict().run_id)
	assert_false(run_id.is_empty())
	if run_id.is_empty(): return
	if not await _walk_authored(1, ENDING_INDEX): return
	assert_true(get_tree().current_scene is EndingScene, "native route reaches the registered ending")
	if not get_tree().current_scene is EndingScene: return
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "default route leaves Challenges unstarted")
	await _screenshot("authored-uninterrupted-ending")
	if not await _walk_authored(ENDING_INDEX + 1, _expected.size() - 1): return
	var expected_lines: Array[String] = []
	for row: Dictionary in _expected: expected_lines.append(row.line_id)
	assert_eq(observed_lines, expected_lines, "all 836 authored captions in exact order, without restart")
	assert_eq(_timings.size(), 835, "every native transition completed")
	var finished: Dictionary = await _complete_authored()
	if finished.is_empty(): return
	assert_eq(finished.run_id, run_id, "one run from New Acc through completion")
	assert_eq(ready_count, 1, "no Load or second New Acc")
	assert_eq(AUTHORED_MANIFEST.scene_registration_fingerprint(), registration)
	var completed_profile: Dictionary = profile.get_profile_snapshot()
	var gallery_id := "ending:%s:gallery:ending.alone" % run_id
	assert_eq(completed_profile.gallery_transaction_receipts, {
		gallery_id: {"ending_id": "ending.alone", "unlocked": true}}, "exactly one durable Gallery receipt")
	var durable_profile: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://profile.json"))
	if not _ok(durable_profile): return
	assert_eq(durable_profile.value.gallery_transaction_receipts, completed_profile.gallery_transaction_receipts)
	assert_eq(get_tree().current_scene.scene_file_path, MENU)
	_write_json("res://.godot/ci/authored-week-uninterrupted.json", {
		"scope": "fresh_title_uninterrupted_default_authored_week_completed_title",
		"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"registration_sha256": registration, "elapsed_ms": Time.get_ticks_msec() - started,
		"observed_lines": observed_lines, "timings": _timings, "day_elapsed_ms": _day_timings(),
		"completed_lifecycle": finished, "gallery_receipts": completed_profile.gallery_transaction_receipts,
		"autosave_sha256": FileAccess.get_sha256("user://saves/autosave.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")})
	print("AUTHORED_UNINTERRUPTED_COMPLETE process_id=", OS.get_process_id(), " captions=", observed_lines.size())
