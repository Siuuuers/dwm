extends "res://tests/integration/scene_playable_child.gd"

func test_fresh_process_restores_same_playable_without_replay() -> void:
	await load_playable()
