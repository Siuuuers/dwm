extends "res://tests/integration/scene_seven_day_connected_child.gd"

func test_normal_title_new_game_reaches_day4_and_saves_exact_caption() -> void:
	await create_week()
