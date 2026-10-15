extends "res://tests/integration/scene_manual_entry_child.gd"
## Ordinary dialogue admission, then actual Viewport mine input. Hidden layout
## is TEST selection knowledge only; production owners commit the losing result.

func _expected_outcome() -> String:
	return "lost"

func _proof_prefix() -> String:
	return "scene-loss"

func _capture_label(label: String) -> String:
	return "loss-" + label

func _next_terminal_cell(record: Dictionary, panel: Control) -> int:
	for index: int in record.board.mine_indices:
		if "reveal" in panel.public_view.board.cells[index].actions:
			return index
	return -1
