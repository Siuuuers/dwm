extends Control
class_name TutorialOverlay

## Day-1 tutorial overlay; requires Dialogic 2 (prompt_docs/requirements/dialogic_skip.md).

signal tutorial_finished()

const TIMELINE_ID := "tutorial.desktop_day1"

@onready var _finish_button: Button = %FinishButton

var _dialogic_blocked: bool = false

func _ready() -> void:
	if is_instance_valid(_finish_button) and not _finish_button.pressed.is_connected(_on_finish_pressed):
		_finish_button.pressed.connect(_on_finish_pressed)
	_start_timeline()

func _start_timeline() -> void:
	if not has_node("/root/DialogicBridge"):
		return
	var bridge := get_node("/root/DialogicBridge")
	if not bridge.is_dialogic_available():
		_dialogic_blocked = true
		push_warning("Dialogic 2 addon file does not exist.")
		return
	bridge.start_timeline_id(TIMELINE_ID)

func _on_finish_pressed() -> void:
	if has_node("/root/GameState"):
		get_node("/root/GameState").mark_tutorial_seen()
	tutorial_finished.emit()
	queue_free()
