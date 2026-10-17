extends "res://tests/integration/scene_challenge_recall_child.gd"
func test_never_started_end_save_then_later_recall() -> void:
	await create_recall()
