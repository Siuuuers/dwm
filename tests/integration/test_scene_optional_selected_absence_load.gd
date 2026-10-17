extends "res://tests/integration/scene_optional_child.gd"
func test_optional_selected_absence_load() -> void:
	await load_optional("selected_absence")
