extends AppWindowBase
class_name SettingsApp

## Desktop settings app window (mirrors Setting.tscn controls) (FLOWS.md §9, CONTRACTS.md §8).

@onready var language_option: OptionButton = %LanguageOption
@onready var accessibility_container: VBoxContainer = %AccessibilityContainer
@onready var audio_container: VBoxContainer = %AudioContainer
