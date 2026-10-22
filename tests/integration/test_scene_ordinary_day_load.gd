extends "res://tests/integration/scene_ordinary_day_child.gd"
func test_fresh_load_keeps_renewal_and_abandons_old_board() -> void:
	await load_ordinary_day()
