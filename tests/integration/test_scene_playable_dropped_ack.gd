extends "res://tests/integration/scene_playable_child.gd"

func test_real_destination_survives_dropped_ack() -> void:
	await create_playable("dropped_ack")
