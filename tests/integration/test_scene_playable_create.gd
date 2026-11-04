extends "res://tests/integration/scene_playable_child.gd"

func test_genuine_playable_installs_live_control_and_manual_save() -> void:
	await create_playable()
