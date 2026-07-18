extends PanelContainer
class_name MinesweeperChallengeOverlay

## Placeholder 9x9/18-mine dating challenge board (prompt_docs/requirements/desktop_minesweeper_handoff.md).

signal challenge_finished(result: Dictionary)

@onready var title_label: Label = %TitleLabel
@onready var board_info_label: Label = %BoardInfoLabel
@onready var board_scroll: ScrollContainer = %BoardScroll
@onready var placeholder_board: Control = %PlaceholderBoard
@onready var normal_result_buttons: HBoxContainer = %NormalResultButtons
@onready var dark_path_buttons: HBoxContainer = %DarkPathButtons
@onready var status_label: Label = %StatusLabel
@onready var cancel_or_close_button: Button = %CancelOrCloseButton

func _emit_result(path: String, affection_delta: int, dark_point: int, entered_true_path: bool) -> void:
	challenge_finished.emit({
		"context": "dating",
		"path": path,
		"affection_delta": affection_delta,
		"dark_point": dark_point,
		"entered_true_path": entered_true_path,
	})
