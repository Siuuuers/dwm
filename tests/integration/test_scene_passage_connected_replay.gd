extends "res://tests/integration/scene_passage_child.gd"
func test_completed_load_returns_title_and_gallery_replays_only_passage() -> void:
	await replay_completed_passage_scene()
