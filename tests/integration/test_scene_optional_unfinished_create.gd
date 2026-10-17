extends "res://tests/integration/scene_optional_child.gd"
func test_optional_unfinished_create() -> void:
	await create_optional("unfinished")
