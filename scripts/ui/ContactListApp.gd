extends AppWindowBase
class_name ContactListApp

## Contact list + chat panel app window (prompt_docs/requirements/contacts_invitations.md).

const ENGLISH_FONT := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED_FONT := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL_FONT := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")

signal presentation_failed(result: Dictionary)

@onready var contacts_panel: Control = %ContactsPanel

var _command_port: Object = null
var _presentation_port: Object = null
var _localization: Object = null
var _profile: Object = null
var _primary := "en"
var _secondary := ""
var _reply_button: Button
var _status_label: Label
var last_result: Dictionary = {}
var _desktop_home: Button
var _cached_focus_kind := ""
var _cached_row_index := 0


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(800, 656)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$VBoxContainer.add_theme_constant_override("separation", 0)
	var top_bar: PanelContainer = $VBoxContainer/TopBar
	top_bar.hide()
	top_bar.custom_minimum_size.y = 64
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color("151b25")
	bar_style.content_margin_left = 16
	bar_style.content_margin_right = 16
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	top_bar.add_theme_stylebox_override("panel", bar_style)
	_content_host.custom_minimum_size = Vector2(800, 656)
	_status_label = Label.new()
	_status_label.name = "ContactStatus"
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.visible = false
	# Technical feedback is a transient notice in the pane, not correspondence
	# or a second title bar. It leaves the reading geometry unchanged.
	_status_label.position = Vector2(264, 608)
	_status_label.size = Vector2(520, 48)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = Color("151b25")
	_status_label.add_theme_stylebox_override("normal", notice_style)
	add_child(_status_label)
	contacts_panel.open_requested.connect(_on_open_requested)
	contacts_panel.back_requested.connect(hide_window)
	get_viewport().gui_focus_changed.connect(_remember_control)
	_apply_typography()
	if _presentation_port != null:
		refresh_view()


func configure_presentation(port: Object, localization: Object = null, profile: Object = null) -> Dictionary:
	if port == null:
		return _failure(&"invalid_contacts_presentation_port", "presentation port required")
	for method in ["get_projection", "open_friend", "reply_to_group"]:
		if not port.has_method(method):
			return _failure(&"invalid_contacts_presentation_port", "missing " + method)
	if _presentation_port != null and _presentation_port != port:
		return _failure(&"contacts_presentation_already_configured", "replacement refused")
	_presentation_port = port
	_localization = localization
	_profile = profile
	if _localization != null and _localization.has_signal("locale_changed"):
		if not _localization.is_connected("locale_changed", _on_presentation_locale_changed):
			_localization.connect("locale_changed", _on_presentation_locale_changed)
	if _profile != null and _profile.has_signal("preference_changed"):
		if not _profile.is_connected("preference_changed", _on_preference_changed):
			_profile.connect("preference_changed", _on_preference_changed)
	return refresh_view() if is_node_ready() else {"ok": true}


func refresh_view() -> Dictionary:
	if _presentation_port == null:
		return _failure(&"contacts_presentation_unconfigured", "presentation not available")
	var previous_locale := _primary
	var requested_locale := _requested_locale()
	var result: Dictionary = _presentation_port.get_projection(contacts_panel.selected_friend, requested_locale, _secondary)
	if result.get("ok", false):
		_primary = requested_locale
	var presented := _present(result)
	if not presented.get("ok", false):
		_primary = previous_locale
	return presented


func _requested_locale() -> String:
	if _localization != null and _localization.has_method("get_locale"):
		var requested := str(_localization.get_locale()).replace("_", "-")
		if requested in ["en", "zh-CN", "zh-HK"]:
			return requested
	return _primary


func _apply_typography() -> void:
	var percent := 100
	if _profile != null and _profile.has_method("get_preference"):
		percent = int(_profile.get_preference("preferences.accessibility.text_size", 100))
	contacts_panel.configure(ENGLISH_FONT, SIMPLIFIED_FONT, TRADITIONAL_FONT, percent)
	theme = contacts_panel.theme
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("151b25")
		style.border_color = Color("a9935f") if state == "hover" else Color("d8cfb7")
		style.set_border_width_all(2)
		style.content_margin_left = 12
		style.content_margin_right = 12
		theme.set_stylebox(state, "Button", style)
	var button_focus := StyleBoxFlat.new()
	button_focus.bg_color = Color.TRANSPARENT
	button_focus.border_color = Color("a9935f")
	button_focus.set_border_width_all(2)
	button_focus.expand_margin_left = 4
	button_focus.expand_margin_right = 4
	button_focus.expand_margin_top = 4
	button_focus.expand_margin_bottom = 4
	theme.set_stylebox("focus", "Button", button_focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color("d8cfb7"))
	_title_label.add_theme_color_override("font_color", Color("d8cfb7"))
	_title_label.text = {"en": "Contacts", "zh-CN": "联系人", "zh-HK": "聯絡人"}[_primary]
	_title_label.add_theme_font_override("font", {"en": ENGLISH_FONT, "zh-CN": SIMPLIFIED_FONT, "zh-HK": TRADITIONAL_FONT}[_primary])
	_hide_button.accessibility_name = {"en": "Back to desktop", "zh-CN": "返回桌面", "zh-HK": "返回桌面"}[_primary]
	_hide_button.custom_minimum_size = Vector2(64, 48)
	_status_label.add_theme_font_override("font", {"en": ENGLISH_FONT, "zh-CN": SIMPLIFIED_FONT, "zh-HK": TRADITIONAL_FONT}[_primary])
	_status_label.add_theme_color_override("font_color", Color("d8cfb7"))


func _present(result: Dictionary) -> Dictionary:
	var restore_reply_focus := is_instance_valid(_reply_button) and _reply_button.has_focus() and is_visible_in_tree()
	last_result = result.duplicate(true)
	if not result.get("ok", false):
		_status_label.text = {"en": "Conversation unavailable", "zh-CN": "会话暂不可用", "zh-HK": "對話暫不可用"}[_primary]
		_status_label.show()
		presentation_failed.emit(last_result)
		return last_result
	var value: Dictionary = result.get("value", {})
	if not value.has_all(["friend_id", "entries", "unread"]):
		return _failure(&"invalid_contacts_projection", "incomplete view")
	_apply_typography()
	if not contacts_panel.set_projection(value.friend_id, value.entries, value.unread, _primary, _secondary):
		last_result = _failure(&"invalid_contacts_projection", "presentation rejected view")
		presentation_failed.emit(last_result)
		return last_result
	_status_label.hide()
	_reply_button = null
	if value.get("reply_required", false) and contacts_panel.messages != null:
		_reply_button = Button.new()
		_reply_button.name = "ReplyButton"
		_reply_button.text = {"en": "Reply", "zh-CN": "回复", "zh-HK": "回覆"}[_primary]
		_reply_button.add_theme_font_override("font", {"en": ENGLISH_FONT, "zh-CN": SIMPLIFIED_FONT, "zh-HK": TRADITIONAL_FONT}[_primary])
		_reply_button.custom_minimum_size.y = 48
		_reply_button.focus_mode = Control.FOCUS_ALL
		_reply_button.pressed.connect(_on_reply_requested)
		var reply_margin := MarginContainer.new()
		reply_margin.set_meta("entry_id", "ui:reply")
		for edge in ["left", "right", "top", "bottom"]:
			reply_margin.add_theme_constant_override("margin_" + edge, 4)
		contacts_panel.messages.add_child(reply_margin)
		reply_margin.add_child(_reply_button)
		contacts_panel.transcript.focus_neighbor_bottom = contacts_panel.transcript.get_path_to(_reply_button)
		_reply_button.focus_neighbor_top = _reply_button.get_path_to(contacts_panel.transcript)
	if restore_reply_focus:
		if _reply_button != null:
			_reply_button.grab_focus()
		elif contacts_panel.transcript != null:
			contacts_panel.transcript.grab_focus()
	return last_result


func _on_open_requested(friend_id: String) -> void:
	if _presentation_port != null:
		_present(_presentation_port.open_friend(friend_id, _primary, _secondary))


func _on_reply_requested() -> void:
	if _presentation_port != null:
		_present(_presentation_port.reply_to_group(contacts_panel.selected_friend, _primary, _secondary))


func _on_presentation_locale_changed(_locale_id: String) -> void:
	refresh_view()


func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == &"preferences.accessibility.text_size":
		refresh_view()


func show_window() -> void:
	var focus_kind := _cached_focus_kind
	var row_index := _cached_row_index
	show()
	if _presentation_port != null:
		refresh_view()
	if focus_kind == "reply" and is_instance_valid(_reply_button):
		_reply_button.grab_focus()
		return
	if focus_kind in ["transcript", "reply"] and is_instance_valid(contacts_panel.transcript):
		contacts_panel.transcript.grab_focus()
		return
	if focus_kind == "row":
		contacts_panel.rows[row_index].grab_focus()
		return
	var index: int = contacts_panel.FRIENDS.find(contacts_panel.selected_friend)
	contacts_panel.rows[maxi(0, index)].grab_focus()


func hide_window() -> void:
	remember_focus()
	super.hide_window()


func remember_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		_remember_control(focused)


func _remember_control(focused: Control) -> void:
	if not is_visible_in_tree() or not is_ancestor_of(focused):
		return
	if focused is Button and focused in contacts_panel.rows:
		_cached_focus_kind = "row"
		_cached_row_index = contacts_panel.rows.find(focused)
	elif focused == contacts_panel.transcript:
		_cached_focus_kind = "transcript"
	elif focused == _reply_button:
		_cached_focus_kind = "reply"


func configure_desktop_home(home: Button) -> void:
	_desktop_home = home
	var first: Button = contacts_panel.rows[0]
	first.focus_previous = first.get_path_to(home)
	first.focus_neighbor_top = first.get_path_to(home)
	home.focus_next = home.get_path_to(first)
	home.focus_neighbor_bottom = home.get_path_to(first)


func configure_command_port(command_port: Object) -> Dictionary:
	if command_port == null or not command_port.has_method("request_open_contact") \
			or not command_port.has_method("request_reply_invitation"):
		return _failure(&"invalid_contact_command_port", "command port contract incomplete")
	if _command_port != null:
		if _command_port != command_port:
			return _failure(&"contact_command_port_already_configured", "replacement refused")
		return {"ok": true, "code": &"ok", "value": {
			"port_instance_id": _command_port.get_instance_id(), "already_configured": true,
		}, "receipt": {}}
	_command_port = command_port
	return {"ok": true, "code": &"ok", "value": {
		"port_instance_id": _command_port.get_instance_id(), "already_configured": false,
	}, "receipt": {}}


func open_friend(friend_id: String) -> Dictionary:
	if _command_port == null:
		return _failure(&"contact_command_port_unconfigured", "command port injection is required")
	var result: Variant = _command_port.call(&"request_open_contact", friend_id)
	return _as_command_result(result)


func reply_to_group(friend_id: String) -> Dictionary:
	if _command_port == null:
		return _failure(&"contact_command_port_unconfigured", "command port injection is required")
	var result: Variant = _command_port.call(&"request_reply_invitation", friend_id)
	return _as_command_result(result)


func _as_command_result(result: Variant) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY:
		return _failure(&"contact_command_result_malformed", "command port returned no result")
	return (result as Dictionary).duplicate(true)


func _failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
