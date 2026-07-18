extends Button
class_name ContactBox

## Single friend row inside ContactListApp (prompt_docs/requirements/contacts_invitations.md).

signal contact_selected(friend_id: String)

@onready var portrait_image: TextureRect = %PortraitImage
@onready var name_label: Label = %NameLabel
@onready var status_label: Label = %StatusLabel
@onready var unread_badge_label: Label = %UnreadBadgeLabel

var friend_id: String = ""

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func set_contact(new_friend_id: String, display_name: String) -> void:
	friend_id = new_friend_id
	if is_instance_valid(name_label):
		name_label.text = display_name

func _on_pressed() -> void:
	contact_selected.emit(friend_id)
