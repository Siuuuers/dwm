extends "res://tests/integration/scene_challenge_recall_child.gd"
func test_fresh_load_retains_closure_and_repeats_only_later_recall() -> void:
	await load_recall()
