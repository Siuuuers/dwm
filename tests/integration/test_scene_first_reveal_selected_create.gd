extends "res://tests/integration/scene_first_reveal_connected_child.gd"
func test_selected_absence_survives_source_overwrite_and_destination_retry() -> void:
	await create_selected_recovery()
