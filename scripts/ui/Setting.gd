extends Control
class_name Setting

const SETTINGS_PANEL_CONTROLLER := preload("res://scripts/ui/SettingsPanelController.gd")

## Menu-sized settings panel (prompt_docs/requirements/audio_preferences.md).

@onready var language_option: OptionButton = %LanguageOption
@onready var language_status: Label = %LanguageStatus
@onready var accessibility_container: VBoxContainer = %AccessibilityContainer
@onready var audio_container: VBoxContainer = %AudioContainer
@onready var close_button: Button = %CloseButton

var _controller: RefCounted = SETTINGS_PANEL_CONTROLLER.new()

func _ready() -> void:
	_controller.bind(self, language_option, language_status, accessibility_container, audio_container)
	if not close_button.pressed.is_connected(hide):
		close_button.pressed.connect(hide)

func _exit_tree() -> void:
	_controller.unbind()
