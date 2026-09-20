extends AppWindowBase
class_name ContactListApp

## Contact list + chat panel app window (prompt_docs/requirements/contacts_invitations.md).

const ENGLISH_FONT := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED_FONT := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL_FONT := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")
const CONTACTS_THEME := preload("res://scripts/ui/contacts/ContactsTheme.gd")

signal presentation_failed(result: Dictionary)

@onready var contacts_panel: Control = %ContactsPanel

var _command_port: Object = null
var _presentation_port: Object = null
var _localization: Object = null
var _profile: Object = null
var _palette: StringName = &"after_hours"
var _day := 1
var _primary := "en"
var _secondary := ""
var _reply_button: Button
var _status_label: Label
var last_result: Dictionary = {}
var _desktop_home: Button
var _cached_focus_kind := ""
var _cached_row_index := 0
var _ordinary_choices: Array[Button] = []
var _ordinary_pending: Dictionary = {}
var _ordinary_drawn := false
var _ordinary_busy := false
var _ordinary_generation := 0
var _ordinary_retry: Button


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
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = Color("151b25")
	_status_label.add_theme_stylebox_override("normal", notice_style)
	_content_host.add_child(_status_label)
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status_label.offset_left = 264
	_status_label.offset_right = -16
	_status_label.offset_top = -48
	contacts_panel.open_requested.connect(_on_open_requested)
	contacts_panel.pending_reply_drawn.connect(_on_pending_ordinary_drawn)
	contacts_panel.back_requested.connect(hide_window)
	get_viewport().gui_focus_changed.connect(_remember_control)
	visibility_changed.connect(_on_ordinary_visibility_changed)
	_apply_typography()
	if _presentation_port != null:
		refresh_view()


func configure_presentation(port: Object, localization: Object = null, profile: Object = null,
		palette: StringName = &"after_hours", day: int = 1) -> Dictionary:
	if CONTACTS_THEME.resolve(palette, day).is_empty():
		return _failure(&"invalid_contacts_presentation", "invalid palette or day")
	if port == null:
		return _failure(&"invalid_contacts_presentation_port", "presentation port required")
	for method in ["get_projection", "open_friend", "reply_to_group"]:
		if not port.has_method(method):
			return _failure(&"invalid_contacts_presentation_port", "missing " + method)
	if _presentation_port != null and _presentation_port != port:
		return _failure(&"contacts_presentation_already_configured", "replacement refused")
	if _presentation_port != null and (_palette != palette or _day != day):
		return _failure(&"contacts_presentation_already_configured", "installed context is retained")
	_presentation_port = port
	_palette = palette
	_day = day
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
		if requested in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
			return requested
	return _primary


func _apply_typography() -> void:
	var percent := 100
	if _profile != null and _profile.has_method("get_preference"):
		percent = int(_profile.get_preference("preferences.accessibility.text_size", 100))
	var appearance := _read_appearance()
	if appearance.is_empty(): return
	if not contacts_panel.configure(ENGLISH_FONT, SIMPLIFIED_FONT, TRADITIONAL_FONT, percent,
			_palette == &"midnight", _day, appearance.high_contrast, appearance.colour_preset): return
	_apply_app_colours()
	_title_label.text = {"en": "Contacts", "zh-CN": "联系人", "zh-HK": "聯絡人", "ja": "連絡先", "ko": "연락처"}[_primary]
	_title_label.add_theme_font_override("font", contacts_panel._fonts[_primary])
	_hide_button.accessibility_name = {"en": "Back to desktop", "zh-CN": "返回桌面", "zh-HK": "返回桌面", "ja": "デスクトップに戻る", "ko": "데스크톱으로 돌아가기"}[_primary]
	_hide_button.custom_minimum_size = Vector2(64, 48)
	_status_label.add_theme_font_override("font", contacts_panel._fonts[_primary])


func _read_appearance() -> Dictionary:
	var high_contrast: Variant = false
	var colour_preset: Variant = "standard"
	if _profile != null and _profile.has_method("get_preference"):
		high_contrast = _profile.get_preference("preferences.accessibility.high_contrast", false)
		colour_preset = _profile.get_preference("preferences.accessibility.colour_differentiation", "standard")
	if not high_contrast is bool or not colour_preset is String \
			or CONTACTS_THEME.resolve(_palette, _day, high_contrast, colour_preset).is_empty(): return {}
	return {"high_contrast": high_contrast, "colour_preset": colour_preset}


func _apply_app_colours() -> void:
	theme = contacts_panel.theme
	var instrument := theme.get_color("instrument", "Contacts")
	var bone := theme.get_color("bone", "Contacts")
	var gold := theme.get_color("gold", "Contacts")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = instrument
		style.border_color = gold if state == "hover" else bone
		style.set_border_width_all(2)
		style.content_margin_left = 12
		style.content_margin_right = 12
		theme.set_stylebox(state, "Button", style)
	var button_focus := StyleBoxFlat.new()
	button_focus.bg_color = Color.TRANSPARENT
	# This expanded ring sits on the transcript's paper, outside the dark button.
	button_focus.border_color = theme.get_color("ink", "Contacts")
	button_focus.set_border_width_all(2)
	button_focus.expand_margin_left = 4
	button_focus.expand_margin_right = 4
	button_focus.expand_margin_top = 4
	button_focus.expand_margin_bottom = 4
	theme.set_stylebox("focus", "Button", button_focus)
	var bar_focus := button_focus.duplicate() as StyleBoxFlat
	bar_focus.border_color = gold
	_hide_button.add_theme_stylebox_override("focus", bar_focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		theme.set_color(state, "Button", bone)
	_title_label.add_theme_color_override("font_color", bone)
	_status_label.add_theme_color_override("font_color", bone)
	var bar_style := $VBoxContainer/TopBar.get_theme_stylebox("panel") as StyleBoxFlat
	bar_style.bg_color = instrument
	var notice_style := _status_label.get_theme_stylebox("normal") as StyleBoxFlat
	notice_style.bg_color = instrument


func _present(result: Dictionary) -> Dictionary:
	var restore_reply_focus := is_instance_valid(_reply_button) and _reply_button.has_focus() and is_visible_in_tree()
	last_result = result.duplicate(true)
	if not result.get("ok", false):
		_status_label.text = {"en": "Conversation unavailable", "zh-CN": "会话暂不可用", "zh-HK": "對話暫不可用", "ja": "会話を表示できません", "ko": "대화를 볼 수 없어요"}[_primary]
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
		_reply_button.text = {"en": "Reply", "zh-CN": "回复", "zh-HK": "回覆", "ja": "返信", "ko": "답장"}[_primary]
		_reply_button.add_theme_font_override("font", contacts_panel._fonts[_primary])
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
	_present_ordinary_controls(value)
	if restore_reply_focus:
		if _reply_button != null:
			_reply_button.grab_focus()
		elif contacts_panel.transcript != null:
			contacts_panel.transcript.grab_focus()
	return last_result


func _on_open_requested(friend_id: String) -> void:
	if friend_id == contacts_panel.selected_friend and not _ordinary_pending.is_empty(): return
	if not _cancel_ordinary_pending(): return
	if _presentation_port != null:
		_present(_presentation_port.open_friend(friend_id, _primary, _secondary))


func _on_reply_requested() -> void:
	if not _ordinary_pending.is_empty() or _ordinary_busy: return
	if _presentation_port != null:
		_present(_presentation_port.reply_to_group(contacts_panel.selected_friend, _primary, _secondary))


func _ordinary_available() -> bool:
	if _presentation_port == null: return false
	for method: String in ["prepare_ordinary_reply", "acknowledge_ordinary_reply", "get_pending_ordinary_reply", "cancel_pending_ordinary_reply"]:
		if not _presentation_port.has_method(method): return false
	return true

func _present_ordinary_controls(value: Dictionary) -> void:
	_ordinary_generation += 1
	_ordinary_choices.clear()
	_ordinary_pending = {}
	_ordinary_drawn = false
	_ordinary_retry = null
	for row: Button in contacts_panel.rows: row.disabled = false
	if not _ordinary_available(): return
	var pending: Dictionary = _presentation_port.get_pending_ordinary_reply()
	if not pending.get("ok", false):
		_show_ordinary_failure(pending, &"pending")
		return
	var command: Variant = pending.get("value", {}).get("command", {})
	if command is Dictionary and not command.is_empty():
		_ordinary_pending = command.duplicate(true)
		if is_instance_valid(_reply_button): _reply_button.disabled = true
		if command.get("friend_id") != value.friend_id: return
		if not command.get("rendered_line") is Dictionary or not contacts_panel.present_pending_reply(command.rendered_line, str(command.get("locale", _primary))):
			_show_ordinary_failure(_failure(&"ordinary_pending_view_unavailable", "Pending reply could not be presented"), &"presentation")
			return
		_ordinary_retry = Button.new()
		_ordinary_retry.name = "RetryOrdinaryReply"
		_ordinary_retry.text = _ordinary_retry_copy()
		_ordinary_retry.add_theme_font_override("font", contacts_panel._fonts[_primary])
		_ordinary_retry.custom_minimum_size.y = 48
		_ordinary_retry.disabled = true
		_ordinary_retry.pressed.connect(_on_ordinary_retry)
		contacts_panel.messages.add_child(_ordinary_retry)
		return
	var choices: Variant = value.get("ordinary_choices", [])
	if not choices is Array or choices.is_empty() or contacts_panel.messages == null: return
	for choice: Variant in choices:
		if not choice is Dictionary or not choice.get("reply_id") is String or not choice.get("text") is String: continue
		var button := Button.new()
		button.name = "OrdinaryReply" + str(choice.reply_id).right(1).to_upper()
		button.custom_minimum_size.y = 56
		button.accessibility_name = str(choice.reply_id).right(1).to_upper() + ": " + choice.text
		button.pressed.connect(_on_ordinary_choice.bind(str(choice.reply_id)))
		var margin := MarginContainer.new()
		margin.set_meta("entry_id", "ui:ordinary-choice:" + str(choice.reply_id))
		for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 4)
		contacts_panel.messages.add_child(margin)
		margin.add_child(button)
		var caption := Label.new()
		caption.text = button.accessibility_name
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_override("font", contacts_panel._fonts[_primary])
		caption.set_meta("contacts_color_role", "bone")
		caption.set_meta("locale", _primary)
		caption.add_theme_color_override("font_color", theme.get_color("bone", "Contacts"))
		button.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left = 16
		caption.offset_right = -16
		caption.offset_top = 12
		caption.offset_bottom = -12
		caption.resized.connect(func():
			if is_instance_valid(button): button.custom_minimum_size.y = maxf(56, ceilf(caption.get_minimum_size().y) + 24))
		_ordinary_choices.append(button)
	for index: int in range(_ordinary_choices.size()):
		var button: Button = _ordinary_choices[index]
		button.focus_previous = _ordinary_choices[index - 1].get_path() if index > 0 else contacts_panel.transcript.get_path()
		button.focus_next = _ordinary_choices[index + 1].get_path() if index + 1 < _ordinary_choices.size() else contacts_panel.transcript.get_path()
	if not _ordinary_choices.is_empty():
		contacts_panel.transcript.focus_next = _ordinary_choices[0].get_path()
		contacts_panel.transcript.focus_neighbor_bottom = _ordinary_choices[0].get_path()

func _on_ordinary_choice(reply_id: String) -> void:
	if _ordinary_busy or not _ordinary_pending.is_empty() or not _ordinary_available(): return
	for button: Button in _ordinary_choices: button.disabled = true
	var prepared: Dictionary = _presentation_port.prepare_ordinary_reply(contacts_panel.selected_friend, reply_id, _primary)
	refresh_view() # The retained port is the sole authority for a pending choice.
	if not prepared.get("ok", false): _show_ordinary_failure(prepared, &"prepare")

func _on_pending_ordinary_drawn(rendered_line: Dictionary) -> void:
	if _ordinary_pending.is_empty() or rendered_line != _ordinary_pending.get("rendered_line") \
		or not is_visible_in_tree(): return
	_ordinary_drawn = true
	_acknowledge_ordinary.call_deferred(str(_ordinary_pending.command_id), _ordinary_generation)

func _on_ordinary_retry() -> void:
	if _ordinary_pending.is_empty() or not _ordinary_drawn: return
	_acknowledge_ordinary(str(_ordinary_pending.command_id), _ordinary_generation)

func _acknowledge_ordinary(command_id: String, generation: int) -> void:
	if _ordinary_busy or not _ordinary_drawn or _ordinary_pending.get("command_id") != command_id \
		or generation != _ordinary_generation or not is_inside_tree() or not is_visible_in_tree() or is_queued_for_deletion(): return
	_ordinary_busy = true
	if is_instance_valid(_ordinary_retry): _ordinary_retry.disabled = true
	var command := _ordinary_pending.duplicate(true)
	var result: Variant = await _presentation_port.acknowledge_ordinary_reply(command, command.rendered_line.duplicate(true), _primary, _secondary)
	if not is_inside_tree() or is_queued_for_deletion(): return
	_ordinary_busy = false
	if _ordinary_pending.get("command_id") != command_id: return
	if result is Dictionary and result.get("ok", false):
		refresh_view()
		return
	_show_ordinary_failure(result if result is Dictionary else _failure(&"ordinary_acknowledgment_malformed", "Reply acknowledgment returned no result"), &"commit")
	if is_instance_valid(_ordinary_retry):
		_ordinary_retry.disabled = false
		if is_visible_in_tree(): _ordinary_retry.grab_focus()

func _cancel_ordinary_pending() -> bool:
	if _ordinary_busy: return false
	if _ordinary_pending.is_empty(): return true
	if not _ordinary_available(): return false
	var command := _ordinary_pending.duplicate(true)
	var result: Dictionary = _presentation_port.cancel_pending_ordinary_reply(command)
	if not result.get("ok", false): return false
	_ordinary_generation += 1
	_ordinary_pending = {}
	_ordinary_drawn = false
	return true

func _on_ordinary_visibility_changed() -> void:
	if not is_visible_in_tree(): _cancel_ordinary_pending()

func _exit_tree() -> void:
	if not _ordinary_pending.is_empty() and is_instance_valid(_presentation_port) \
		and _presentation_port.has_method("cancel_pending_ordinary_reply"):
		_presentation_port.cancel_pending_ordinary_reply(_ordinary_pending.duplicate(true))

func _ordinary_retry_copy() -> String:
	return {"en": "Retry", "zh-CN": "\u91cd\u8bd5", "zh-HK": "\u91cd\u8a66", "ja": "再試行", "ko": "다시 시도"}[_primary]

func _show_ordinary_failure(result: Dictionary, phase: StringName) -> void:
	# Keep player logs useful without recording correspondence, identity tokens, or file paths.
	print("ORDINARY_REPLY_FAILURE: " + JSON.stringify({"phase": str(phase), "code": str(result.get("code", "unknown"))}))
	last_result = result.duplicate(true)
	presentation_failed.emit(last_result.duplicate(true))
	_status_label.text = {"en": "Your reply could not be saved. Please try again.",
		"zh-CN": "\u6682\u65f6\u65e0\u6cd5\u4fdd\u5b58\u56de\u590d\uff0c\u8bf7\u91cd\u8bd5\u3002", "zh-HK": "\u66ab\u6642\u7121\u6cd5\u5132\u5b58\u56de\u8986\uff0c\u8acb\u91cd\u8a66\u3002", "ja": "返信を保存できませんでした。もう一度お試しください。", "ko": "답장을 저장하지 못했어요. 다시 시도해 주세요."}[_primary]
	_status_label.show()

func _on_presentation_locale_changed(_locale_id: String) -> void:
	refresh_view()


func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == &"preferences.accessibility.text_size":
		refresh_view()
	elif is_node_ready() and path in [&"preferences.accessibility.high_contrast", &"preferences.accessibility.colour_differentiation"]:
		var appearance := _read_appearance()
		if not appearance.is_empty() and contacts_panel.apply_presentation(_palette, _day,
				appearance.high_contrast, appearance.colour_preset):
			_apply_app_colours()


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
	if not _cancel_ordinary_pending(): return
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
