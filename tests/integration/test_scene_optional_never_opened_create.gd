extends "res://tests/integration/scene_optional_child.gd"
func test_optional_never_opened_create() -> void:
	await create_optional("never_opened")
