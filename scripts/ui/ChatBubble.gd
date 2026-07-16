extends PanelContainer
class_name ChatBubble

## Single chat message bubble (FLOWS.md §9).

@onready var speaker_label: Label = %SpeakerLabel
@onready var message_label: RichTextLabel = %MessageLabel

func set_message(speaker_name: String, text: String) -> void:
	if is_instance_valid(speaker_label):
		speaker_label.text = speaker_name
	if is_instance_valid(message_label):
		message_label.text = text
