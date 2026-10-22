extends "res://tests/integration/scene_optional_child.gd"
func test_optional_never_started_load() -> void:
	await load_optional("never_started")
