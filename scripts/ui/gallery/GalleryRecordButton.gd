extends Button
## The row owns one semantic target. Its wrapped caption owns no input.

var selected := false:
	set(value):
		selected = value
		_sync_caption()
		queue_redraw()
		if is_inside_tree(): queue_accessibility_update()
var caption: Label
var _pointer: Control
var _pointer_down := false
var _pointer_hover := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caption = Label.new()
	caption.position = Vector2(16, 8)
	caption.size.x = 264
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_constant_override("line_spacing", 0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	# A nonfocusable pointer surface prevents native mouse-down focus from
	# selecting a row before its lawful release. Keyboard/assistive input keeps
	# the native Button, while wheel input continues to the index scroll owner.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer = Control.new()
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.focus_mode = Control.FOCUS_NONE
	_pointer.mouse_filter = Control.MOUSE_FILTER_PASS
	_pointer.gui_input.connect(_pointer_input)
	_pointer.mouse_exited.connect(_cancel_pointer)
	add_child(_pointer)
	visibility_changed.connect(_cancel_pointer)
	# Button's own text remains the public/assistive title, but is not painted
	# or allowed to impose an independent single-line minimum width.
	clip_text = true
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)
	_sync_caption()

func _cancel_pointer() -> void:
	_pointer_down = false
	_pointer_hover = false
	queue_redraw()

func cancel_pointer_press() -> void:
	_cancel_pointer()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _cancel_pointer()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var element := get_accessibility_element()
		if element.is_valid():
			DisplayServer.accessibility_update_set_role(element, DisplayServer.ROLE_LIST_BOX_OPTION)
			DisplayServer.accessibility_update_set_list_item_selected(element, selected)

func _pointer_input(event: InputEvent) -> void:
	if disabled or not is_visible_in_tree():
		_cancel_pointer()
		return
	if event is InputEventPanGesture or event is InputEventScreenDrag or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]):
		_cancel_pointer()
		return
	if event is InputEventMouseMotion:
		_pointer_hover = Rect2(Vector2.ZERO, size).has_point(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer.accept_event()
		_pointer_hover = Rect2(Vector2.ZERO, size).has_point(event.position)
		if event.pressed:
			_pointer_down = not event.double_click
		else:
			var activate := _pointer_down and Rect2(Vector2.ZERO, size).has_point(event.position)
			_pointer_down = false
			if activate:
				grab_focus(true)
				pressed.emit()
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if has_focus() and ((event is InputEventKey and event.pressed) or
			(event is InputEventJoypadButton and event.pressed)):
		grab_focus()
		queue_redraw()

func refresh_caption() -> void:
	if not is_instance_valid(caption): return
	caption.language = language
	caption.text = text
	caption.size = Vector2(264, 0)
	# Measure the actual localized Label, including fallback-font line metrics.
	var height := ceilf(caption.get_minimum_size().y / 2) * 2
	custom_minimum_size = Vector2(296, 16 + maxf(64, height))
	caption.size = Vector2(264, height)
	accessibility_name = text
	_sync_caption()

func _sync_caption() -> void:
	if is_instance_valid(caption):
		caption.add_theme_color_override("font_color", get_theme_color("paper_ink" if selected else "ink", "Gallery"))

func _draw() -> void:
	if not has_theme_color("face", "Gallery"): return
	var ink := get_theme_color("paper_ink" if selected else "ink", "Gallery")
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("filed" if selected else "face", "Gallery"))
	draw_rect(Rect2(16, size.y - 2, 264, 2), ink)
	if selected: draw_rect(Rect2(292, 0, 4, size.y), ink)
	if is_pressed() or (_pointer_down and _pointer_hover): draw_rect(Rect2(0, 0, size.x, 2), ink)
	elif _pointer_hover: draw_rect(Rect2(0, 0, 2, size.y), ink)
	if has_focus(true):
		draw_rect(Rect2(-7, -7, size.x + 14, size.y + 14), get_theme_color("ink", "Gallery"), false, 2)
		draw_rect(Rect2(-3, -3, size.x + 6, size.y + 6), get_theme_color("focus", "Gallery"), false, 2)
