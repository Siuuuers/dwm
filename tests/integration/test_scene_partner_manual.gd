extends "res://tests/integration/scene_partner_fork_child.gd"
func test_fresh_load_manual_pass() -> void:
	await load_partner_manual()
