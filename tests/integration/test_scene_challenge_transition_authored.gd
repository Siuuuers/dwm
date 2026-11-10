extends "res://tests/integration/authored_week_child.gd"

func test_authored_day1_challenge_end_reaches_result_once() -> void:
	_phase = "create"
	if not _setup_authored(false): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	if not await _walk_authored(1, _entry_starts["Day1.result.A"]): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.result.A.001")
	var outcomes: Dictionary = game.capture_run_snapshot_input().gameplay.scene_challenge_outcomes
	assert_eq(outcomes.size(), 1)
	if outcomes.size() == 1:
		assert_eq(outcomes.values()[0].challenge_id, "Day1.challenge")
		assert_eq(outcomes.values()[0].outcome, "never_started")
