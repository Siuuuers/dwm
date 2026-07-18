extends AppWindowBase
class_name SettingsApp

## Desktop settings app window (mirrors Setting.tscn controls) (prompt_docs/requirements/audio_preferences.md).

@onready var language_option: OptionButton = %LanguageOption
@onready var accessibility_container: VBoxContainer = %AccessibilityContainer
@onready var audio_container: VBoxContainer = %AudioContainer
