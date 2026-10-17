extends "res://tests/integration/scene_optional_child.gd"
func test_optional_unfinished_load() -> void:
	await load_optional("unfinished")
