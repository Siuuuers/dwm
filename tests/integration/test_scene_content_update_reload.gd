extends "res://tests/integration/scene_content_update_child.gd"
func test_fresh_reload_preserves_suspended_and_bound_state() -> void:
	await reload_current_content()
