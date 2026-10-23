extends "res://tests/integration/scene_loss_child.gd"

func test_fresh_process_load_and_resave_preserve_lost_attempt_and_single_closure() -> void:
	await load_completed_scene()
