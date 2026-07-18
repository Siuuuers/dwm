extends Control
class_name EndingScene

## Ending scene: selects timeline by GameState.route_context["ending_id"] (prompt_docs/requirements/dating_endings.md).

@onready var _ending_title_label: Label = %EndingTitleLabel
@onready var _ending_body_label: Label = %EndingBodyLabel
@onready var _return_to_menu_button: Button = %ReturnToMenuButton

func _ready() -> void:
	if is_instance_valid(_return_to_menu_button) and not _return_to_menu_button.pressed.is_connected(_on_return_pressed):
		_return_to_menu_button.pressed.connect(_on_return_pressed)
	_show_ending()

func _show_ending() -> void:
	if not has_node("/root/GameState"):
		return
	var gs := get_node("/root/GameState")
	var ending_id: String = String(gs.route_context.get("ending_id", ""))
	if ending_id == "":
		ending_id = "ending.alone"
	if is_instance_valid(_ending_title_label):
		_ending_title_label.text = ending_id
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_music_context("ending", {"ending_id": ending_id})
	if has_node("/root/DialogicBridge"):
		var bridge := get_node("/root/DialogicBridge")
		if bridge.is_dialogic_available():
			bridge.start_timeline_id(ending_id)
		else:
			push_warning("Dialogic 2 addon file does not exist.")
	gs.record_ending_seen(ending_id)

func _on_return_pressed() -> void:
	if has_node("/root/SceneRouter"):
		get_node("/root/SceneRouter").goto_menu()
