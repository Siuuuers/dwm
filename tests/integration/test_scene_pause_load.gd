extends "res://tests/support/ScenePauseLoadTestBase.gd"
func test_real_text_pause_load_finishes_async_activation_once_and_releases_custody() -> void:
	await happy_load(false)
