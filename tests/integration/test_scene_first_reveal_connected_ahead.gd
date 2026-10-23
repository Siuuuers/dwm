extends "res://tests/integration/scene_first_reveal_connected_child.gd"
func test_first_reveal_profile_ahead_of_refused_run_write() -> void:
	await create_connected("profile_ahead")
