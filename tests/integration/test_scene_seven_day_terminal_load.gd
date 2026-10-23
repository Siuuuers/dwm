extends "res://tests/integration/scene_seven_day_terminal_child.gd"

func test_fresh_process_restores_saved_ending_line_without_replay_then_completes() -> void:
	await load_saved_terminal_line()
