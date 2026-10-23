extends "res://tests/integration/scene_contacts_connected_child.gd"
func test_fresh_contact_load_returns_to_parent_once() -> void:
	await load_contacts_scene()
