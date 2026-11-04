extends "res://tests/integration/authored_week_child.gd"

const CUE := "line.Day7.untouched.impulse.004"
const RESULT_LINES := ["line.Day7.A.001", "line.Day7.A.002"]

func test_natural_aged_day7_accept() -> void:
	_phase = "create"
	if not _setup_authored(false): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	var cue_index := -1
	for index: int in _expected.size():
		if _expected[index].line_id == CUE: cue_index = index
	assert_eq(cue_index, 799)
	if cue_index != 799 or not await _walk_authored(1, cue_index): return
	var before: Dictionary = bridge._reading_session.ledger.snapshot()
	var before_run: Dictionary = game.capture_run_snapshot_input()
	var before_board: Dictionary = game.capture_dating_challenge_state()
	assert_eq(before.captions.size(), 1)
	var measurements: Array[Dictionary] = []
	for line_id: String in RESULT_LINES:
		var started := Time.get_ticks_usec()
		await _accept()
		if not await _wait_line(line_id): return
		measurements.append({"line_id": line_id, "elapsed_us": Time.get_ticks_usec() - started})
	var after: Dictionary = bridge._reading_session.ledger.snapshot()
	var after_run: Dictionary = game.capture_run_snapshot_input()
	var after_board: Dictionary = game.capture_dating_challenge_state()
	assert_eq(after.captions.size(), 1)
	assert_eq(after.captions.back().beat.line_id, RESULT_LINES.back())
	for command_id: String in before_run.command_receipts:
		assert_eq(after_run.command_receipts.get(command_id), before_run.command_receipts[command_id])
	assert_true(before_board.ok and after_board.ok)
	assert_eq(after_board.value, before_board.value)
	var result := {"revision": OS.get_environment("DWM_BENCHMARK_REVISION"),
		"display_server": DisplayServer.get_name(), "process_id": OS.get_process_id(),
		"cue": CUE, "measurements": measurements,
		"captions_before": before.captions.size(), "captions_after": after.captions.size(),
		"receipts_before": before_run.command_receipts.size(), "receipts_after": after_run.command_receipts.size(),
		"board_before": before_board.value, "board_after": after_board.value,
		"outcomes_before": before_run.gameplay.scene_challenge_outcomes,
		"outcomes_after": after_run.gameplay.scene_challenge_outcomes,
		"library_witnesses": profile.get_dialogue_library().witnesses.size(),
		"history_blocks": bridge._reading_session.player_progress.history_sections}
	print("AGED_SCENE_ADVANCE " + JSON.stringify(result))
	_write_json("user://aged-scene-advance.json", result)
