extends Button
class_name IconButton

## Focusable icon + label button used by the desktop icon grid and shared UI (FLOWS.md §9).

@onready var _icon_image: TextureRect = %IconImage
@onready var _icon_label: Label = %IconLabel

var icon_texture_path: String = ""
var label_key: String = ""

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	refresh_localization()
	_refresh_icon()
	if has_node("/root/LocalizationManager"):
		var loc := get_node("/root/LocalizationManager")
		if not loc.locale_changed.is_connected(_on_locale_changed):
			loc.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	refresh_localization()

func set_icon_button(new_label_key: String, new_icon_path: String = "") -> void:
	label_key = new_label_key
	if new_icon_path != "":
		icon_texture_path = new_icon_path
	refresh_localization()
	_refresh_icon()

func refresh_localization() -> void:
	if not is_instance_valid(_icon_label):
		return
	if label_key != "" and has_node("/root/LocalizationManager"):
		_icon_label.text = get_node("/root/LocalizationManager").t(label_key)

func _refresh_icon() -> void:
	if not is_instance_valid(_icon_image):
		return
	if icon_texture_path != "" and ResourceLoader.exists(icon_texture_path):
		_icon_image.texture = load(icon_texture_path)
	else:
		_icon_image.texture = null
