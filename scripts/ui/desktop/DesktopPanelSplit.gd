extends Container
class_name DesktopPanelSplit

signal split_changed(width: float)

const MIN_ANGELA_WIDTH := 320.0
const MAX_ANGELA_WIDTH := 480.0
const MIN_COMPUTER_WIDTH := 800.0
const HANDLE_SIZE := Vector2(64, 64)
const KEYBOARD_STEP := 16.0


class SplitDragHandle extends Control:
	var separator_height := 0.0
	var separator_color := Color(0.65, 0.68, 0.72)
	var focus_color := Color(0.95, 0.78, 0.30)
	var preview_offset := 0.0
	var preview_visible := false

	func _init() -> void:
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(63, -position.y, 2, separator_height), separator_color)
		draw_rect(Rect2(40, 27, 16, 10), separator_color)
		if preview_visible:
			draw_rect(Rect2(63 + preview_offset, -position.y, 2, separator_height), focus_color)
		if has_focus():
			draw_rect(Rect2(2, 2, 60, 60), focus_color, false, 2)


var _angela_width := MAX_ANGELA_WIDTH
var _handle: SplitDragHandle
var _mouse_dragging := false
var _touch_index := -1
var _drag_origin_x := 0.0
var _drag_origin_width := MAX_ANGELA_WIDTH
var _preview_width := MAX_ANGELA_WIDTH
var _focus_before_pointer: Control


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	_ensure_handle()
	queue_sort()


func _get_minimum_size() -> Vector2:
	return Vector2(MIN_ANGELA_WIDTH + MIN_COMPUTER_WIDTH, 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_children()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_retire_drag()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_retire_drag()


func _input(event: InputEvent) -> void:
	if (_mouse_dragging or _touch_index >= 0) and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE:
		_retire_drag()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and is_instance_valid(_handle) and _handle.get_global_rect().has_point(event.position):
		_focus_before_pointer = get_viewport().gui_get_focus_owner()
	elif event is InputEventScreenTouch and event.pressed and is_instance_valid(_handle) \
			and _handle.get_global_rect().has_point(event.position):
		_focus_before_pointer = get_viewport().gui_get_focus_owner()


func set_angela_width(width: float) -> void:
	var next := clampf(width, MIN_ANGELA_WIDTH, MAX_ANGELA_WIDTH)
	if is_equal_approx(next, _angela_width):
		return
	_angela_width = next
	queue_sort()
	split_changed.emit(_angela_width)


func get_angela_width() -> float:
	return _angela_width


func set_handle_accessibility(name: String, description: String) -> void:
	_ensure_handle()
	_handle.accessibility_name = name
	_handle.accessibility_description = description


func _ensure_handle() -> void:
	if is_instance_valid(_handle):
		return
	_handle = SplitDragHandle.new()
	_handle.name = "SplitDragHandle"
	_handle.custom_minimum_size = HANDLE_SIZE
	_handle.focus_mode = Control.FOCUS_ALL
	_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_handle.accessibility_name = "Resize Angela panel"
	_handle.accessibility_description = "Drag horizontally or use Left and Right arrow keys"
	_handle.gui_input.connect(_on_handle_gui_input)
	add_child(_handle)
	move_child(_handle, get_child_count() - 1)


func _on_child_entered_tree(child: Node) -> void:
	if child == _handle:
		return
	_move_handle_last.call_deferred()
	queue_sort()


func _move_handle_last() -> void:
	if is_instance_valid(_handle) and _handle.get_index() != get_child_count() - 1:
		move_child(_handle, get_child_count() - 1)


func _pane_controls() -> Array[Control]:
	var panes: Array[Control] = []
	for child: Node in get_children():
		if child is Control and child != _handle:
			panes.append(child as Control)
			if panes.size() == 2:
				break
	return panes


func _layout_children() -> void:
	_ensure_handle()
	var panes := _pane_controls()
	if panes.size() >= 1:
		fit_child_in_rect(panes[0], Rect2(0, 0, _angela_width, size.y))
	if panes.size() >= 2:
		fit_child_in_rect(panes[1], Rect2(_angela_width, 0,
			maxf(0, size.x - _angela_width), size.y))
	var handle_position := Vector2(_angela_width - HANDLE_SIZE.x,
		maxf(0, (size.y - HANDLE_SIZE.y) * 0.5))
	fit_child_in_rect(_handle, Rect2(handle_position, HANDLE_SIZE))
	_handle.separator_height = size.y
	if has_theme_color(&"font_color", &"Label"):
		_handle.separator_color = get_theme_color(&"font_color", &"Label")
	if has_theme_color(&"focus", &"Desktop"):
		_handle.focus_color = get_theme_color(&"focus", &"Desktop")
	_handle.queue_redraw()


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(_handle_point_to_split_x(event.position))
			_restore_pointer_focus.call_deferred()
		else:
			if _mouse_dragging:
				_update_drag(_handle_point_to_split_x(event.position))
				_finish_drag()
		_handle.accept_event()
		return
	if event is InputEventMouseMotion and _mouse_dragging:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_retire_drag()
			return
		_update_drag(_handle_point_to_split_x(event.position))
		_handle.accept_event()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0:
			_touch_index = event.index
			_begin_drag(_handle_point_to_split_x(event.position), false)
			_restore_pointer_focus.call_deferred()
			_handle.accept_event()
		elif not event.pressed and event.index == _touch_index:
			if event.canceled:
				_retire_drag()
			else:
				_update_drag(_handle_point_to_split_x(event.position))
				_finish_drag()
			_handle.accept_event()
		return
	if event is InputEventScreenDrag and event.index == _touch_index:
		_update_drag(_handle_point_to_split_x(event.position))
		_handle.accept_event()
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				set_angela_width(_angela_width - KEYBOARD_STEP)
			KEY_RIGHT:
				set_angela_width(_angela_width + KEYBOARD_STEP)
			KEY_HOME:
				set_angela_width(MIN_ANGELA_WIDTH)
			KEY_END:
				set_angela_width(MAX_ANGELA_WIDTH)
			_:
				return
		_handle.accept_event()


func _begin_drag(pointer_x: float, mouse: bool = true) -> void:
	_mouse_dragging = mouse
	_drag_origin_x = pointer_x
	_drag_origin_width = _angela_width
	_preview_width = _angela_width
	_handle.preview_visible = true
	_handle.preview_offset = 0.0
	_handle.queue_redraw()


func _update_drag(pointer_x: float) -> void:
	# Keep both panes and their hit targets stable until the pointer is released.
	_preview_width = clampf(_drag_origin_width + pointer_x - _drag_origin_x,
		MIN_ANGELA_WIDTH, MAX_ANGELA_WIDTH)
	_handle.preview_offset = _preview_width - _angela_width
	_handle.queue_redraw()


func _finish_drag() -> void:
	var committed_width := _preview_width
	_retire_drag()
	set_angela_width(committed_width)


func _retire_drag() -> void:
	_mouse_dragging = false
	_touch_index = -1
	if is_instance_valid(_handle):
		_handle.preview_visible = false
		_handle.preview_offset = 0.0
		_handle.queue_redraw()


func _handle_point_to_split_x(point: Vector2) -> float:
	var canvas_point := _handle.get_global_transform_with_canvas() * point
	return (get_global_transform_with_canvas().affine_inverse() * canvas_point).x


func _restore_pointer_focus() -> void:
	if is_instance_valid(_focus_before_pointer) and _focus_before_pointer.is_inside_tree():
		_focus_before_pointer.grab_focus()
	_focus_before_pointer = null
