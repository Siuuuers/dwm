extends AppWindowBase
class_name SettingsApp

const SETTINGS_PANEL_CONTROLLER := preload("res://scripts/ui/SettingsPanelController.gd")

## Desktop settings app window (mirrors Setting.tscn controls) (prompt_docs/requirements/audio_preferences.md).

@onready var language_option: OptionButton = %LanguageOption
@onready var language_status: Label = %LanguageStatus
@onready var accessibility_container: VBoxContainer = %AccessibilityContainer
@onready var audio_container: VBoxContainer = %AudioContainer

var _controller: RefCounted = SETTINGS_PANEL_CONTROLLER.new()

func _ready() -> void:
	super._ready()
	_controller.bind(self, language_option, language_status, accessibility_container, audio_container)

func _exit_tree() -> void:
	_controller.unbind()
