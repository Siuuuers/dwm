extends PanelContainer
class_name DialogueBox

## Shared dialogue box: speaker/text/log/skip/auto/next (FLOWS.md §9).

signal next_pressed()
signal skip_pressed()
signal auto_toggled(enabled: bool)
signal log_pressed()

@onready var speaker_name_label: Label = %SpeakerNameLabel
@onready var input_hint_label: Label = %InputHintLabel
@onready var dialogue_text_label: RichTextLabel = %DialogueTextLabel
@onready var log_button: Button = %LogButton
@onready var skip_button: Button = %SkipButton
@onready var auto_button: Button = %AutoButton
@onready var next_button: Button = %NextButton

var auto_enabled: bool = false

func _ready() -> void:
	for b in [log_button, skip_button, auto_button, next_button]:
		if is_instance_valid(b):
			b.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(next_button) and not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if is_instance_valid(skip_button) and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if is_instance_valid(auto_button) and not auto_button.pressed.is_connected(_on_auto_pressed):
		auto_button.pressed.connect(_on_auto_pressed)
	if is_instance_valid(log_button) and not log_button.pressed.is_connected(_on_log_pressed):
		log_button.pressed.connect(_on_log_pressed)

func set_line(speaker_name: String, text: String) -> void:
	if is_instance_valid(speaker_name_label):
		speaker_name_label.text = speaker_name
	if is_instance_valid(dialogue_text_label):
		dialogue_text_label.text = text

func _on_next_pressed() -> void:
	next_pressed.emit()

func _on_skip_pressed() -> void:
	skip_pressed.emit()

func _on_auto_pressed() -> void:
	auto_enabled = not auto_enabled
	auto_toggled.emit(auto_enabled)

func _on_log_pressed() -> void:
	log_pressed.emit()
