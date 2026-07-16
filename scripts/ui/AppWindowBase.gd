extends PanelContainer
class_name AppWindowBase

## Base for desktop app windows. Hide (not free) semantics per FLOWS.md §9.

signal window_hidden()

@onready var _title_label: Label = %TitleLabel
@onready var _hide_button: Button = %HideButton
@onready var _content_host: Control = %ContentHost

var title_key: String = ""

func _ready() -> void:
	if is_instance_valid(_hide_button):
		_hide_button.focus_mode = Control.FOCUS_ALL
		if not _hide_button.pressed.is_connected(hide_window):
			_hide_button.pressed.connect(hide_window)
	refresh_localization()
	if has_node("/root/LocalizationManager"):
		var loc := get_node("/root/LocalizationManager")
		if not loc.locale_changed.is_connected(_on_locale_changed):
			loc.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	refresh_localization()

func get_content_host() -> Control:
	return _content_host

func show_window() -> void:
	show()
	_focus_first_control()

func hide_window() -> void:
	hide()
	window_hidden.emit()

func _focus_first_control() -> void:
	if has_node("/root/InputManager"):
		get_node("/root/InputManager").call_deferred("focus_first_control", self)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_window()
		get_viewport().set_input_as_handled()

func refresh_localization() -> void:
	if is_instance_valid(_title_label) and title_key != "" and has_node("/root/LocalizationManager"):
		_title_label.text = get_node("/root/LocalizationManager").t(title_key)
