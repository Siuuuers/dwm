extends AppWindowBase
class_name SettingsApp

const SETTINGS_PANEL_CONTROLLER := preload("res://scripts/ui/SettingsPanelController.gd")

## Desktop settings app window (mirrors Setting.tscn controls) (prompt_docs/requirements/audio_preferences.md).

@onready var language_option: OptionButton = %LanguageOption
@onready var language_status: Label = %LanguageStatus
@onready var accessibility_container: VBoxContainer = %AccessibilityContainer
@onready var audio_container: VBoxContainer = %AudioContainer
@onready var settings_scroll: ScrollContainer = %SettingsScroll

var _controller: RefCounted = SETTINGS_PANEL_CONTROLLER.new()
var _desktop_ready_result: Dictionary = {"ok": false, "code": &"settings_not_ready"}
var _desktop_home: Button
var _last_focus: WeakRef

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(800, 656)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$VBoxContainer/TopBar.hide()
	$VBoxContainer.add_theme_constant_override("separation", 0)
	_content_host.custom_minimum_size = Vector2(800, 656)
	for owner_path: String in ["/root/ProfileManager", "/root/LocalizationManager"]:
		var owner := get_node_or_null(owner_path)
		if owner != null and owner.has_method("get_readiness") and owner.get_readiness() != &"ready":
			_desktop_ready_result = {"ok": false, "code": &"settings_dependencies_not_ready"}
			return
	_desktop_ready_result = _controller.bind(self, language_option, language_status,
		accessibility_container, audio_container).duplicate(true)
	if _desktop_ready_result.get("ok", false):
		_arrange_controls(settings_scroll)
		_connect_home_focus()

func _exit_tree() -> void:
	_controller.unbind()


func get_desktop_ready_result() -> Dictionary:
	return _desktop_ready_result.duplicate(true)


func configure_desktop_home(home: Button) -> void:
	_desktop_home = home
	if is_node_ready():
		_connect_home_focus()


func _connect_home_focus() -> void:
	if is_instance_valid(_desktop_home):
		language_option.focus_neighbor_top = language_option.get_path_to(_desktop_home)
		language_option.focus_previous = language_option.get_path_to(_desktop_home)
		_desktop_home.focus_next = _desktop_home.get_path_to(language_option)
		_desktop_home.focus_neighbor_bottom = _desktop_home.get_path_to(language_option)


func can_return_home() -> bool:
	return not _has_open_window(self)


func show_window() -> void:
	show()
	if not _desktop_ready_result.get("ok", false) or _has_open_window(self):
		return
	var previous: Control = _last_focus.get_ref() as Control if _last_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree() \
			and previous.focus_mode != Control.FOCUS_NONE \
			and not (previous is BaseButton and previous.disabled):
		previous.grab_focus()
	else:
		language_option.grab_focus()


func _arrange_controls(node: Node) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if node is Label:
		(node as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(node as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is HSlider:
		(node as HSlider).custom_minimum_size = Vector2(180, 48)
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		(node as Control).focus_entered.connect(_remember_focus.bind(node))
	for child in node.get_children():
		_arrange_controls(child)


func _remember_focus(control: Control) -> void:
	_last_focus = weakref(control)
	settings_scroll.ensure_control_visible(control)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel") \
			or _has_open_window(self):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused != self and not is_ancestor_of(focused):
		return
	# One Back returns to the app root; a subsequent Back returns Home. An open
	# confirmation or option popup always owns its own dismissal first.
	if language_option.has_focus():
		hide_window()
	else:
		language_option.grab_focus()
	get_viewport().set_input_as_handled()


func _has_open_window(node: Node) -> bool:
	for child in node.get_children(true):
		if child is Window and child.visible:
			return true
		if _has_open_window(child):
			return true
	return false
