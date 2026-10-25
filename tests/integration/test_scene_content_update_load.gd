extends "res://tests/integration/scene_content_update_child.gd"
func test_load_current_content_without_replaying_gameplay() -> void:
	await load_content_update()
