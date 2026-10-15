extends "res://tests/integration/test_scene_interrupt_child.gd"

func test_fresh_process_resumes_same_operation_and_confirms_native_mount_once() -> void:
	await resume_interrupted_load()
