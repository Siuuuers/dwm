extends "res://tests/integration/scene_apps_connected_child.gd"
func test_fresh_scene_apps_load_preserves_purchase_and_challenge() -> void:
	await load_apps_scene()
