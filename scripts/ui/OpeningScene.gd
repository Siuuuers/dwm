extends Control
class_name OpeningScene

## Opening narrative scene; requires Dialogic 2 (prompt_docs/requirements/dialogic_skip.md).

const TIMELINE_ID := "opening.day1"

@onready var _continue_button: Button = %ContinueButton

var _dialogic_blocked: bool = false

func _ready() -> void:
	if is_instance_valid(_continue_button) and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	_start_timeline()

func _start_timeline() -> void:
	if not has_node("/root/DialogicBridge"):
		return
	var bridge := get_node("/root/DialogicBridge")
	if not bridge.is_dialogic_available():
		_dialogic_blocked = true
		push_warning("Dialogic 2 addon file does not exist.")
		return
	# Stable timeline ID only; forward the bridge receipt and never inspect an event index.
	var started: Dictionary = bridge.start_timeline_id(TIMELINE_ID)
	if not started.get("ok", false):
		_dialogic_blocked = true
		push_warning("OpeningScene: timeline did not start: %s" % str(started.get("reason", started.get("code", ""))))

func _on_continue_pressed() -> void:
	if _dialogic_blocked:
		return
	if has_node("/root/GameState"):
		get_node("/root/GameState").mark_opening_seen()
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").goto_main()
