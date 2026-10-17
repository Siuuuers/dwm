extends "res://tests/integration/scene_later_caption_child.gd"
func test_native_accept_reaches_later_partial_caption_and_saves_exact_frontier() -> void:
	await create_later_caption()
