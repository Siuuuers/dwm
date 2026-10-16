extends "res://tests/integration/scene_later_caption_child.gd"
func test_fresh_process_load_restores_later_caption_and_accept_reenters_loop_once() -> void:
	await load_later_caption()
