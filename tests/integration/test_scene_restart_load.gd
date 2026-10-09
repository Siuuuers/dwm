extends "res://tests/integration/test_scene_restart_child.gd"

func test_fresh_process_selected_load_preserves_saved_caption_and_history() -> void:
	await exercise_phase("load")
