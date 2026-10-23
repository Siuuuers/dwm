extends "res://tests/integration/scene_first_reveal_connected_child.gd"
func test_first_reveal_selected_load_preserves_exact_saved_prefix() -> void:
	await load_connected()
