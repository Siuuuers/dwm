extends "res://tests/integration/scene_audio_connected_child.gd"
func test_fresh_scene_audio_load_retains_admission_and_uses_anchor() -> void:
	await load_audio_scene()
