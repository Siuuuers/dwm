extends Control
class_name MainGameScene

## In-run shell; fresh entry goes directly to the desktop launcher.

const COMPUTER_DESKTOP_SCENE := preload("res://scenes/desktop/ComputerDesktop.tscn")

@onready var _computer_panel: PanelContainer = %ComputerPanel

var _computer_desktop_instance: Node = null

func _ready() -> void:
	_ensure_computer_desktop()

func _ensure_computer_desktop() -> void:
	if is_instance_valid(_computer_desktop_instance):
		return
	if not is_instance_valid(_computer_panel):
		return
	_computer_desktop_instance = COMPUTER_DESKTOP_SCENE.instantiate()
	_computer_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_computer_panel.add_child(_computer_desktop_instance)
