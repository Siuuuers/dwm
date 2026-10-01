extends Control
## Opaque, inspect-only projection. The retained lifecycle owner suspends the source.
signal close_requested

class HistoryClose extends Button:
	var admitted: Callable
	var generation := 0
	func _notification(what: int) -> void:
		if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
		var element := get_accessibility_element()
		if element.is_valid():
			DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK, _activate.bind(generation))
	func _activate(_request: Variant, captured_generation: int) -> void:
		if captured_generation == generation and admitted.is_valid() and admitted.call() == true:
			pressed.emit()

class ReadingScroll extends ScrollContainer:
	var admitted: Callable
	var generation := 0
	func _notification(what: int) -> void:
		if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
		var element := get_accessibility_element()
		if not element.is_valid(): return
		DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_SCROLL_VIEW)
		DisplayServer.accessibility_update_set_scroll_y(element, scroll_vertical)
		var bar := get_v_scroll_bar()
		DisplayServer.accessibility_update_set_scroll_y_range(element, 0, maxf(0, bar.max_value - bar.page))
		for pair: Array in [[DisplayServer.ACTION_SCROLL_UP, -1], [DisplayServer.ACTION_SCROLL_DOWN, 1],
				[DisplayServer.ACTION_SCROLL_BACKWARD, -1], [DisplayServer.ACTION_SCROLL_FORWARD, 1]]:
			DisplayServer.accessibility_update_add_action(element, pair[0], _accessibility_scroll.bind(pair[1], generation))
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_SET_SCROLL_OFFSET, _accessibility_offset.bind(generation))
	func _accessibility_scroll(unit: Variant, direction: int, captured_generation: int) -> void:
		if captured_generation == generation and admitted.is_valid() and admitted.call() == true:
			scroll_vertical += direction * int(size.y if unit == DisplayServer.SCROLL_UNIT_PAGE else 64)
	func _accessibility_offset(value: Variant, captured_generation: int) -> void:
		if value is Vector2 and captured_generation == generation and admitted.is_valid() and admitted.call() == true:
			scroll_vertical = int(value.y)

var reading_scroll: ReadingScroll
var close_button: HistoryClose
var _heading: Label
var _rows: VBoxContainer
var _captions: Array[String] = []
var _admission: Callable
var _active := false
var _interactive := false
var _foreground := true
var _close_touch: Dictionary = {}
var _touch_id := -1
var _back_contact := ""
var _blocked_contacts: Dictionary = {}
var _input_owner: Node
var _roles: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func _ready() -> void:
	_heading = Label.new()
	_heading.name = "Heading"
	_heading.position = Vector2(32, 16)
	_heading.size = Vector2(928, 64)
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	close_button = HistoryClose.new()
	close_button.admitted = _is_admitted
	close_button.name = "Close"
	close_button.position = Vector2(992, 16)
	close_button.size = Vector2(272, 64)
	close_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	close_button.pressed.connect(_request_close)
	add_child(close_button)
	reading_scroll = ReadingScroll.new()
	reading_scroll.name = "ReadingScroll"
	reading_scroll.position = Vector2(16, 96)
	reading_scroll.size = Vector2(1248, 608)
	reading_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reading_scroll.focus_mode = Control.FOCUS_ALL
	reading_scroll.admitted = _is_admitted
	reading_scroll.gui_input.connect(_scroll_input)
	reading_scroll.draw.connect(_draw_focus.bind(reading_scroll))
	add_child(reading_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "Captions"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override(&"separation", 16)
	reading_scroll.add_child(_rows)
	reading_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	for control: Control in [reading_scroll, close_button]:
		control.focus_entered.connect(control.queue_redraw)
		control.focus_exited.connect(control.queue_redraw)
		var other: Control = close_button if control == reading_scroll else reading_scroll
		control.focus_next = control.get_path_to(other)
		control.focus_previous = control.get_path_to(other)
		control.focus_neighbor_left = control.get_path_to(other)
		control.focus_neighbor_right = control.get_path_to(other)
		control.focus_neighbor_top = control.get_path_to(other)
		control.focus_neighbor_bottom = control.get_path_to(other)
	close_button.draw.connect(_draw_focus.bind(close_button))

func configure(presentation: Theme, localization: Object, input_owner: Node, admission: Callable) -> bool:
	if not is_node_ready() or presentation == null or not admission.is_valid() \
			or not is_instance_valid(localization) or not is_instance_valid(input_owner): return false
	for method: String in ["has_key", "t", "get_locale"]:
		if not localization.has_method(method): return false
	for method: String in ["get_physical_contacts", "get_physical_contact_id", "observe_physical_contact"]:
		if not input_owner.has_method(method): return false
	for key: String in ["witnessed.transport.history", "button.close"]:
		if localization.call("has_key", key) != true: return false
	var roles := {}
	for role: StringName in [&"field", &"deep", &"current", &"text", &"rule", &"focus_outer", &"focus_inner"]:
		if not presentation.has_color(role, &"WitnessedCaption"): return false
		roles[role] = presentation.get_color(role, &"WitnessedCaption")
		var color: Color = roles[role]
		if color.a != 1.0: return false
	_roles = roles
	_input_owner = input_owner
	_admission = admission
	theme = presentation.duplicate()
	_heading.text = String(localization.call("t", "witnessed.transport.history"))
	close_button.text = String(localization.call("t", "button.close"))
	var locale := String(localization.call("get_locale")).replace("_", "-")
	_heading.language = locale
	close_button.language = locale
	reading_scroll.accessibility_name = _heading.text
	reading_scroll.accessibility_description = ""
	_heading.add_theme_color_override(&"font_color", _roles[&"text"])
	var plane := _plate(_roles[&"current"], Color.TRANSPARENT)
	plane.set_content_margin_all(16)
	reading_scroll.add_theme_stylebox_override(&"panel", plane)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		close_button.add_theme_stylebox_override(state, _plate(_roles[&"field"], _roles[&"rule"]))
	close_button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		close_button.add_theme_color_override(state, _roles[&"text"])
	# Keep the existing 48/64 target and thumb minimums; recolour its well only.
	var track := theme.get_stylebox(&"scroll", &"VScrollBar").duplicate() as StyleBoxFlat
	track.bg_color = _roles[&"field"]
	track.border_color = _roles[&"rule"]
	theme.set_stylebox(&"scroll", &"VScrollBar", track)
	queue_redraw()
	return true

func present(captions: Array) -> bool:
	if _roles.is_empty() or not _admission.is_valid() or _admission.call() != true or captions.is_empty(): return false
	for caption: Variant in captions:
		if typeof(caption) != TYPE_STRING or String(caption).strip_edges().is_empty(): return false
	_captions.assign(captions)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for index: int in _captions.size():
		if index > 0:
			var separator := HSeparator.new()
			separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			separator.add_theme_stylebox_override(&"separator", _plate(_roles[&"rule"], Color.TRANSPARENT))
			separator.custom_minimum_size.y = 2
			_rows.add_child(separator)
		var label := RichTextLabel.new()
		label.name = "Caption%d" % index
		label.bbcode_enabled = false
		label.selection_enabled = false
		label.focus_mode = Control.FOCUS_NONE
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.fit_content = true
		label.scroll_active = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
		label.add_theme_color_override(&"default_color", _roles[&"text"])
		label.add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
		label.add_theme_constant_override(&"outline_size", 0)
		label.language = close_button.language
		label.text = _captions[index]
		_rows.add_child(label)
	_active = true
	set_interactive(true)
	reading_scroll.scroll_vertical = 0
	show()
	reading_scroll.grab_focus()
	queue_accessibility_update()
	return true

func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	_back_contact = ""
	_touch_id = -1
	_close_touch.clear()
	_blocked_contacts = _input_owner.get_physical_contacts() if is_instance_valid(_input_owner) else {}
	if is_instance_valid(close_button):
		close_button.disabled = not enabled
		close_button.set_pressed_no_signal(false)
		close_button.generation += 1
		close_button.queue_accessibility_update()
	if is_instance_valid(reading_scroll):
		reading_scroll.generation += 1
		reading_scroll.queue_accessibility_update()

func dismiss() -> void:
	_active = false
	set_interactive(false)
	hide()
	_captions.clear()
	queue_accessibility_update()

func get_captions() -> Array[String]:
	return _captions.duplicate()

func _is_admitted() -> bool:
	return _active and _interactive and _foreground and _blocked_contacts.is_empty() and is_visible_in_tree() and _admission.is_valid() and _admission.call() == true

func _request_close() -> void:
	if _is_admitted(): close_requested.emit()

func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree(): return
	_input_owner.observe_physical_contact(event)
	var contacts: Dictionary = _input_owner.get_physical_contacts()
	for id: String in _blocked_contacts.keys():
		if contacts.get(id) != _blocked_contacts[id]: _blocked_contacts.erase(id)
	if not _is_admitted() or not _blocked_contacts.is_empty():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if contacts.size() > 1:
		_back_contact = ""
		_close_touch.clear()
		close_button.set_pressed_no_signal(false)
	if event is InputEventScreenTouch:
		var local := close_button.get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO, close_button.size).has_point(local)
		if event.pressed and inside:
			if contacts.size() == 1 and not event.canceled and not event.double_tap:
				_close_touch = {"index": event.index, "position": event.position, "started": Time.get_ticks_msec()}
				close_button.set_pressed_no_signal(true)
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and _close_touch.get("index", -1) == event.index:
			var activate := inside and not event.canceled and event.position.distance_to(_close_touch.position) <= 8.0 \
				and Time.get_ticks_msec() - int(_close_touch.started) < 500
			_close_touch.clear()
			close_button.set_pressed_no_signal(false)
			get_viewport().set_input_as_handled()
			if activate: _request_close()
			return
	elif event is InputEventScreenDrag and _close_touch.get("index", -1) == event.index:
		if event.position.distance_to(_close_touch.position) > 8.0:
			_close_touch.clear()
			close_button.set_pressed_no_signal(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		var id: String = _input_owner.get_physical_contact_id(event)
		if event.is_pressed():
			if not event.is_echo() and not id.is_empty(): _back_contact = id
		elif not id.is_empty() and id == _back_contact:
			_back_contact = ""
			_request_close()
		return
	var direction := 0
	if event.is_action(&"ui_page_up"): direction = -1
	elif event.is_action(&"ui_page_down"): direction = 1
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER: direction = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER: direction = 1
	if direction != 0:
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo(): reading_scroll.scroll_vertical += direction * int(reading_scroll.size.y)
	elif event.is_action(&"ui_up") or event.is_action(&"ui_down"):
		if reading_scroll.has_focus():
			get_viewport().set_input_as_handled()
			if event.is_pressed(): reading_scroll.scroll_vertical += -64 if event.is_action(&"ui_up") else 64
	elif event is InputEventScreenDrag and event.index == _touch_id:
		reading_scroll.scroll_vertical -= int(event.relative.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed and event.index == _touch_id:
		_touch_id = -1
		get_viewport().set_input_as_handled()

func _scroll_input(event: InputEvent) -> void:
	if not _is_admitted(): return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		_touch_id = event.index
		reading_scroll.accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _active and is_visible_in_tree() and (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if _roles.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), _roles[&"field"])
	draw_rect(Rect2(0, 0, 1280, 80), _roles[&"deep"])
	draw_rect(Rect2(0, 80, 1280, 2), _roles[&"rule"])

func _draw_focus(control: Control) -> void:
	if not control.has_focus() or _roles.is_empty(): return
	control.draw_rect(Rect2(Vector2(3, 3), control.size - Vector2(6, 6)), _roles[&"focus_outer"], false, 2)
	control.draw_rect(Rect2(Vector2(7, 7), control.size - Vector2(14, 14)), _roles[&"focus_inner"], false, 2)

func _plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = fill
	plate.border_color = edge
	plate.set_border_width_all(2 if edge.a > 0 else 0)
	return plate

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_foreground = false
		set_interactive(_interactive)
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_foreground = true
		set_interactive(_interactive)
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	var element := get_accessibility_element()
	if element.is_valid():
		DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_DIALOG)
		DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_MODAL, true)
