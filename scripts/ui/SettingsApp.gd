extends Control
class_name SettingsApp

signal window_hidden()

@onready var settings_content: Control = %SettingsContent
var _closing := false
var _generation := 0
var _desktop_home: Button
var _last_focus: WeakRef
var _host_interactive := true

func configure_pause() -> void:
	$SettingsContent.host_context = "pause"

func configure_run_presentation(palette: StringName, day: int) -> Dictionary:
	return $SettingsContent.configure_run_presentation(palette, day)

func configure_scene_run_presentation(palette: StringName) -> Dictionary:
	return $SettingsContent.configure_scene_run_presentation(palette)

func set_interaction_enabled(enabled: bool) -> void:
	if enabled == _host_interactive and settings_content.is_interaction_enabled() == enabled: return
	_host_interactive = enabled
	settings_content.set_interaction_enabled(enabled)
	if not enabled: settings_content.get_controller().depart()

func focus_entry() -> void:
	settings_content.focus_rail()

func handle_back() -> bool:
	if not _closing: settings_content.handle_back()
	return true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_content.close_requested.connect(hide_window)
	visibility_changed.connect(_on_visibility_changed)
	if not is_visible_in_tree():
		settings_content.set_interaction_enabled(false)
	_connect_home_focus()


func get_content_host() -> Control:
	return settings_content


func get_desktop_ready_result() -> Dictionary:
	if not is_node_ready():
		return {"ok": false, "code": &"settings_not_ready"}
	var services: Dictionary = settings_content.get("_services")
	var profile: Variant = services.get("profile")
	var localization: Variant = services.get("localization")
	if not is_instance_valid(profile) or not profile.has_method("get_profile_snapshot") \
			or profile.get_profile_snapshot().is_empty() \
			or not is_instance_valid(localization) or not localization.has_method("get_readiness") \
			or localization.get_readiness() != &"ready":
		return {"ok": false, "code": &"settings_dependencies_not_ready"}
	return {"ok": true, "code": &"ok"}


func configure_desktop_home(home: Button) -> void:
	_desktop_home = home
	if is_node_ready():
		_connect_home_focus()


func _connect_home_focus() -> void:
	if not is_instance_valid(_desktop_home):
		return
	var first: Control = settings_content.find_child("LanguageCategory", true, false)
	first.focus_previous = first.get_path_to(_desktop_home)
	_desktop_home.focus_next = _desktop_home.get_path_to(first)
	_desktop_home.focus_neighbor_bottom = _desktop_home.get_path_to(first)


func can_return_home() -> bool:
	return not _closing and not settings_content.is_departure_blocked()


func remember_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		_last_focus = weakref(focused)


func show_window() -> void:
	if _closing:
		return
	if visible:
		_on_visibility_changed()
	else:
		show()


func hide_window() -> void:
	if _closing or not is_visible_in_tree() or settings_content.is_profile_write_uncertain() or settings_content.get_controller().is_commit_pending():
		return
	remember_focus()
	_closing = true
	_generation += 1
	settings_content.set_interaction_enabled(false)
	await settings_content.get_controller().depart()
	if not is_inside_tree():
		return
	hide()
	_closing = false
	window_hidden.emit()


func _on_visibility_changed() -> void:
	_generation += 1
	if not is_visible_in_tree():
		settings_content.set_interaction_enabled(false)
		return
	if not _closing:
		settings_content.set_interaction_enabled(_host_interactive)
		if _host_interactive: call_deferred("_focus_if_current", _generation)


func _focus_if_current(generation: int) -> void:
	if generation != _generation or _closing or not _host_interactive or not is_visible_in_tree():
		return
	var previous: Control = _last_focus.get_ref() as Control if _last_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree() \
			and previous.get_focus_mode_with_override() != Control.FOCUS_NONE \
			and not (previous is BaseButton and previous.disabled) \
			and not (previous is Slider and not previous.editable):
		previous.grab_focus()
	else:
		settings_content.focus_rail()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not _closing and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		await settings_content.handle_back()
