extends "res://tests/integration/test_scene_interrupt_child.gd"

func test_selected_load_stops_without_persistent_writes() -> void:
	await interrupt_selected_load()
