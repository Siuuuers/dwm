extends "res://tests/integration/scene_seven_day_connected_child.gd"

func test_fresh_load_witness_save_back_reaches_ending_and_preserves_completion() -> void:
	await load_and_complete_week(false, true)
