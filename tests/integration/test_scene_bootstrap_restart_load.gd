extends "res://tests/integration/scene_bootstrap_restart_child.gd"
func test_fresh_bootstrap_loads_same_files_without_replay() -> void:
	await load_saved_text()
