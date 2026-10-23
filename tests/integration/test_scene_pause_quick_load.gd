extends "res://tests/support/ScenePauseLoadTestBase.gd"
func test_real_text_quick_load_retains_pending_identity_and_rejects_old_pause_completion() -> void:
	await happy_load(true)
