extends "res://tests/integration/test_scene_interrupt_child.gd"

func test_selected_load_stops_at_exact_durable_boundary() -> void:
	await interrupt_selected_load()
