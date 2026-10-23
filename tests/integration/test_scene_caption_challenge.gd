extends "res://tests/integration/scene_caption_challenge_child.gd"
func test_computer_admits_current_cue_and_continue_closes_without_an_extra_caption() -> void:
	await create_caption_challenge()
