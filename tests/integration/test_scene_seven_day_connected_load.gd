extends "res://tests/integration/scene_seven_day_connected_child.gd"

func test_fresh_load_finishes_seven_days_and_real_ending_then_starts_fresh_day1() -> void:
	await load_and_complete_week()
