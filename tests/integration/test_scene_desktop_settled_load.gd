extends "res://tests/integration/scene_desktop_first_reveal_child.gd"
func test_fresh_scene_load_retains_settlement_without_rewards() -> void:
	await load_scene_desktop_settled_result()
