extends "res://tests/integration/scene_bootstrap_restart_child.gd"
func test_real_bootstrap_writes_physical_text_save() -> void:
	await create_saved_text()
