extends "res://tests/integration/scene_playable_child.gd"

func test_real_destination_survives_native_custody_loss() -> void:
	await create_playable("native_refusal")
