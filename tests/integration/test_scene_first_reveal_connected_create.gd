extends "res://tests/integration/scene_first_reveal_connected_child.gd"
func test_first_reveal_real_two_store_retry_and_save() -> void:
	await create_connected("normal")
