extends "res://tests/integration/scene_caption_challenge_child.gd"
func test_fresh_process_restores_cue_and_closed_save_without_duplicate_closure() -> void:
	await load_caption_challenge()
