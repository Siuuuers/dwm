extends "res://tests/integration/test_scene_interrupt_child.gd"

func test_fresh_process_loads_original_save_without_resuming_interruption() -> void:
	await resume_interrupted_load()
