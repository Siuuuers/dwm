extends Control
class_name MainGameScene

## Main desktop scene: Angela/stat panel + computer panel; Day-1 tutorial (FLOWS.md §9).

const COMPUTER_DESKTOP_SCENE := preload("res://scenes/desktop/ComputerDesktop.tscn")
const TUTORIAL_OVERLAY_SCENE := preload("res://scenes/overlay/TutorialOverlay.tscn")

@onready var _computer_panel: PanelContainer = %ComputerPanel
@onready var _tutorial_overlay_host: Control = %TutorialOverlayHost

var _computer_desktop_instance: Node = null

func _ready() -> void:
	_ensure_computer_desktop()
	_maybe_show_tutorial()
	if has_node("/root/InputManager"):
		get_node("/root/InputManager").call_deferred("focus_first_control", self)

func _ensure_computer_desktop() -> void:
	if is_instance_valid(_computer_desktop_instance):
		return
	if not is_instance_valid(_computer_panel):
		return
	_computer_desktop_instance = COMPUTER_DESKTOP_SCENE.instantiate()
	_computer_panel.add_child(_computer_desktop_instance)

func _maybe_show_tutorial() -> void:
	if not has_node("/root/GameState") or not is_instance_valid(_tutorial_overlay_host):
		return
	var gs := get_node("/root/GameState")
	if gs.day == 1 and gs.opening_seen and not gs.tutorial_seen:
		var overlay: Node = TUTORIAL_OVERLAY_SCENE.instantiate()
		_tutorial_overlay_host.add_child(overlay)
		_tutorial_overlay_host.visible = true
		if overlay.has_signal("tutorial_finished"):
			overlay.tutorial_finished.connect(_on_tutorial_finished)

func _on_tutorial_finished() -> void:
	if is_instance_valid(_tutorial_overlay_host):
		_tutorial_overlay_host.visible = false
