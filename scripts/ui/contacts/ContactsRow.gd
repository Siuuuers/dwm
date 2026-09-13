extends Button
## One target; marks are drawn, never extra controls or unread counts.

var identity_index := 0
var selected := false
var unread := false
var display_name := ""
var portrait_texture: Texture2D

const INSPECT_SECONDS := 0.5
const TOUCH_SLOP := 8.0

var _input_owner: Node
var _pointer: Control
var _hold_timer: Timer
var _touches: Dictionary = {}
var _fresh_touch_id := ""
var _touch: Dictionary = {}
var _touch_inspecting := false
var _foreground := true
var _retired_frame := -1

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	for event in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)
	# A nonfocusable child catches touch before BaseButton can receive an emulated
	# click. Real mouse packets pass through to the existing native Button behavior.
	_pointer = Control.new()
	_pointer.name = "PointerSurface"
	_pointer.mouse_filter = Control.MOUSE_FILTER_PASS
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.gui_input.connect(_pointer_input)
	add_child(_pointer)
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = INSPECT_SECONDS
	_hold_timer.timeout.connect(_inspect_touch)
	add_child(_hold_timer)
	focus_exited.connect(_retain_contacts)
	visibility_changed.connect(_retain_contacts)
	bind_input_custody(get_node_or_null("/root/InputManager"))


func bind_input_custody(owner: Node) -> bool:
	if owner == null or not owner.has_signal("source_input_custody_changed"):
		return false
	for method: String in ["get_physical_contacts", "observe_physical_contact", "get_physical_contact_id", "is_source_input_admitted"]:
		if not owner.has_method(method): return false
	if _input_owner != null: return _input_owner == owner
	_input_owner = owner
	owner.connect("source_input_custody_changed", _retain_contacts)
	_retain_contacts()
	return true


func is_touch_inspecting() -> bool:
	return _touch_inspecting


func _retain_contacts() -> void:
	_cancel_touch()
	# Mouse emulation may transfer focus/custody before the matching touch packet.
	_retired_frame = Engine.get_process_frames()
	_fresh_touch_id = ""
	_touches = _current_touches()


func _current_touches() -> Dictionary:
	var contacts := {}
	if is_instance_valid(_input_owner):
		for id: String in _input_owner.get_physical_contacts():
			if id.begins_with("touch:"): contacts[id] = true
	return contacts


func _touch_admitted() -> bool:
	return is_inside_tree() and is_visible_in_tree() and can_process() and not disabled \
		and _foreground and is_instance_valid(_input_owner) \
		and Engine.get_process_frames() != _retired_frame \
		and _input_owner.is_source_input_admitted()


func _cancel_touch() -> void:
	_touch.clear()
	_touch_inspecting = false
	if is_instance_valid(_hold_timer): _hold_timer.stop()
	queue_redraw()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_foreground = false
		_retain_contacts()
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_foreground = true
		_retain_contacts()
	elif what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]:
		_retain_contacts()


func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenDrag:
		if not _touch.is_empty() and _touch.id == "touch:%s:%s" % [event.device, event.index]:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if point.distance_to(_touch.origin) > TOUCH_SLOP or not Rect2(Vector2.ZERO, size).has_point(point):
				_cancel_touch()
		return
	if not event is InputEventScreenTouch:
		if event.is_pressed() and not _touch.is_empty() \
				and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
			_cancel_touch()
		return
	_fresh_touch_id = ""
	if not is_instance_valid(_input_owner): return
	_input_owner.observe_physical_contact(event)
	var id: String = _input_owner.get_physical_contact_id(event)
	var fresh: bool = event.pressed and not _touches.has(id)
	_touches = _current_touches()
	if event.canceled or _touches.size() > 1:
		_cancel_touch()
	elif fresh and _touches.size() == 1 and _touch_admitted():
		_fresh_touch_id = id
	if not event.pressed and not _touch.is_empty() and _touch.id == id:
		_hold_timer.stop()
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, size).has_point(point): _cancel_touch()


func _pointer_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		_pointer.accept_event()
		return
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
	_pointer.accept_event()
	if event is InputEventScreenDrag: return
	if event.pressed:
		if "touch:%s:%s" % [event.device, event.index] != _fresh_touch_id or not _touch_admitted(): return
		grab_focus()
		# Focus observers may synchronously hide/reopen the app or transfer custody.
		if "touch:%s:%s" % [event.device, event.index] != _fresh_touch_id \
				or not _touch_admitted() or not has_focus(): return
		_touch = {"id": "touch:%s:%s" % [event.device, event.index],
			"origin": event.position, "started": Time.get_ticks_msec()}
		_hold_timer.start()
	elif not _touch.is_empty() and _touch.id == "touch:%s:%s" % [event.device, event.index]:
		var activate: bool = _touch_admitted() and has_focus() and not event.canceled \
			and not _touch_inspecting and Time.get_ticks_msec() - int(_touch.started) < int(INSPECT_SECONDS * 1000)
		_cancel_touch()
		if activate: pressed.emit()


func _inspect_touch() -> void:
	if _touch.is_empty() or not _touch_admitted() or not has_focus() or _touches.size() != 1:
		_cancel_touch()
		return
	var remaining := INSPECT_SECONDS - (Time.get_ticks_msec() - int(_touch.started)) / 1000.0
	if remaining > 0:
		_hold_timer.start(remaining)
		return
	_touch_inspecting = true
	queue_redraw()

func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), color)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), color)
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y)), color)

func _draw() -> void:
	var ink := get_theme_color("ink", "Contacts")
	var dark := get_theme_color("instrument", "Contacts")
	var bone := get_theme_color("bone", "Contacts")
	var filed := get_theme_color("filed", "Contacts")
	var void_color := get_theme_color("void", "Contacts")
	draw_rect(Rect2(0, 0, 248, 96), dark)
	draw_rect(Rect2(8, 8, 32, 80), void_color)
	draw_rect(Rect2(216, 8, 24, 80), void_color)
	if selected:
		draw_rect(Rect2(40, 8, 176, 80), filed)
		draw_rect(Rect2(40, 8, 2, 80), ink)
	var identity := get_theme_color("identity_%d" % identity_index, "Contacts")
	if portrait_texture != null:
		draw_texture_rect(portrait_texture, Rect2(8, 16, 32, 64), false)
	elif identity_index == 2:
		draw_rect(Rect2(16, 16, 6, 64), identity)
		draw_rect(Rect2(26, 16, 6, 64), identity)
	else:
		draw_rect(Rect2(16, 16, 16, 64), identity)
		if identity_index == 1:
			draw_rect(Rect2(24, 44, 8, 8), void_color)
	if unread:
		draw_rect(Rect2(224, 44, 8, 8), get_theme_color("paper_mark", "Contacts"))
	if is_pressed():
		draw_rect(Rect2(44, 14, 166, 2), ink if selected else bone)
		draw_rect(Rect2(44, 14, 2, 68), ink if selected else bone)
	elif is_hovered() or _touch_inspecting:
		draw_rect(Rect2(46, 82, 164, 2), ink if selected else get_theme_color("gold", "Contacts"))
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	var baseline := (96 - font.get_height(font_size)) / 2 + font.get_ascent(font_size)
	draw_string(font, Vector2(48, baseline), display_name, HORIZONTAL_ALIGNMENT_LEFT, 160, font_size, ink if selected else bone)
	if has_focus():
		_outline(Rect2(0, 0, 248, 96), ink if selected else bone)
		_outline(Rect2(2, 2, 244, 92), filed if selected else dark)
		_outline(Rect2(4, 4, 240, 88), ink if selected else get_theme_color("gold", "Contacts"))
