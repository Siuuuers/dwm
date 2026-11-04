extends "res://tests/integration/compact_history_restore_child.gd"

func test_save_then_add_later_library_discovery() -> void:
	await create_older_save_then_discover_more_dialogue()
