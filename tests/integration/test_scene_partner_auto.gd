extends "res://tests/integration/scene_partner_fork_child.gd"
func test_fresh_resolved_load_then_earlier_auto_pass() -> void:
	await load_partner_auto()
