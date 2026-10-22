extends "res://tests/integration/scene_playable_child.gd"

func test_genuine_playable_retries_and_commits_control() -> void:
	await create_playable("normal")
