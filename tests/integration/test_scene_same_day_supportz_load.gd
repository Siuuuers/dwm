extends "res://tests/integration/scene_same_day_supportz_child.gd"
func test_fresh_same_day_load_keeps_settled_board_and_supportz_without_replay() -> void:
	await load_same_day_supportz()
