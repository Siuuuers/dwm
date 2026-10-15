extends "res://tests/integration/test_scene_restart_child.gd"

func test_creation_commits_and_confirms_actual_mount_and_native_caption() -> void:
	await exercise_phase("create")
