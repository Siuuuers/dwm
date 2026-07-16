extends Control
class_name Setting

## Menu-sized settings panel (FLOWS.md §9, CONTRACTS.md §8).

@onready var language_option: OptionButton = %LanguageOption
@onready var accessibility_container: VBoxContainer = %AccessibilityContainer
@onready var audio_container: VBoxContainer = %AudioContainer
@onready var close_button: Button = %CloseButton
