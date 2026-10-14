extends "res://tests/integration/scene_pointer_save_load_child.gd"

func test_pointer_save_overwrite_and_selected_load_restores_visible_board() -> void:
	await run_pointer_save_load()
