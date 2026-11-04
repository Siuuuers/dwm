extends "res://tests/integration/compact_history_restore_child.gd"

func test_fresh_load_keeps_global_discovery_and_restores_local_blocks() -> void:
	await load_older_save_preserves_later_global_discoveries()
