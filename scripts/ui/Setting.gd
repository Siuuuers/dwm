extends Control
class_name Setting

signal window_hidden()

@onready var settings_content: Control = %SettingsContent
var _closing := false
var _generation := 0


func _ready() -> void:
	settings_content.close_requested.connect(hide_window)
	visibility_changed.connect(_on_visibility_changed)
	if not is_visible_in_tree():
		settings_content.set_interaction_enabled(false)


func show_window() -> void:
	if _closing:
		return
	if visible:
		_on_visibility_changed()
	else:
		show()


func hide_window() -> void:
	if _closing or not is_visible_in_tree() or settings_content.get_controller().is_commit_pending():
		return
	_closing = true
	_generation += 1
	settings_content.set_interaction_enabled(false)
	await settings_content.get_controller().depart()
	if not is_inside_tree():
		return
	hide()
	_closing = false
	window_hidden.emit()

func can_return_home() -> bool:
	return not _closing and not settings_content.is_departure_blocked()


func _close_settings() -> void:
	await hide_window()


func _on_visibility_changed() -> void:
	_generation += 1
	if not is_visible_in_tree():
		settings_content.set_interaction_enabled(false)
		return
	if not _closing:
		settings_content.set_interaction_enabled(true)
		call_deferred("_focus_if_current", _generation)


func _focus_if_current(generation: int) -> void:
	if generation == _generation and not _closing and is_visible_in_tree():
		settings_content.focus_rail()
