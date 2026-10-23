extends "res://tests/integration/scene_optional_child.gd"
func test_optional_selected_absence_create() -> void:
	await create_optional("selected_absence")
