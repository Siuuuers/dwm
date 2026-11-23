extends "res://tests/integration/current_title_scene_child.gd"
func test_current_title_fresh_process_selected_load() -> void:
	await load_current_title_scene()
	assert_eq(FileAccess.get_sha256(OLD_JOURNAL), FileAccess.get_sha256(PENDING_JOURNAL))
