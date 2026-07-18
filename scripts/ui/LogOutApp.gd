extends PanelContainer
class_name LogOutApp

## Log-out confirmation panel (prompt_docs/requirements/desktop_minesweeper_handoff.md).

@onready var confirm_label: Label = %ConfirmLabel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton

func _ready() -> void:
	if is_instance_valid(no_button) and not no_button.pressed.is_connected(_on_no_pressed):
		no_button.pressed.connect(_on_no_pressed)

func _on_no_pressed() -> void:
	hide()
