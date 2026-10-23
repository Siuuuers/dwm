extends "res://tests/support/ScenePauseLoadTestBase.gd"
func test_real_precommit_write_refusal_preserves_paused_text_and_continue() -> void:
	await refused_load()
