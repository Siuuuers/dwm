extends "res://tests/integration/scene_completion_child.gd"
func test_fresh_process_load_preserves_completed_receipt_and_terminal_board() -> void:
	await load_completed_scene()
