extends Container
class_name DesktopPanelSplit

signal split_changed(width: float)
signal width_committed(width: float)
signal drag_changed(active: bool)

const MIN_ANGELA_WIDTH := 320.0
const MAX_ANGELA_WIDTH := 480.0
const MIN_COMPUTER_WIDTH := 800.0
const HANDLE_SIZE := Vector2(64, 64)
const WIDTH_STEP := 2.0
const KEYBOARD_STEP := 16.0
const HANDLE_ACCESSIBILITY_COPY := {
	"en": ["Resize panels", "Drag horizontally. Left/Right adjust width; Home/End use the minimum/maximum."],
	"zh-CN": ["调整面板大小", "横向拖动。左右键调整宽度，Home/End 键设为最小/最大。"],
	"zh-HK": ["調整面板大小", "橫向拖動。左右鍵調整寬度，Home/End 鍵設為最小/最大。"],
	"ja": ["パネルのサイズ変更", "左右にドラッグ。左右キーで幅を調整、Home/End で最小/最大にします。"],
	"ko": ["패널 크기 조절", "가로로 드래그하세요. 좌우 키로 너비를 조절하고 Home/End로 최소/최대 크기를 설정하세요."],
}


class SplitDragHandle extends Control:
	var separator_height := 0.0
	var separator_color := Color(0.65, 0.68, 0.72)
	var grip_color := Color(0.11, 0.14, 0.18)
	var focus_color := Color(0.95, 0.78, 0.30)
	var preview_offset := 0.0
	var preview_visible := false

	func _init() -> void:
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(63, -position.y, 2, separator_height), separator_color)
		var grip := Rect2(30, 16, 28, 32)
		draw_rect(grip, grip_color)
		draw_rect(grip, separator_color, false, 2)
		draw_polyline(PackedVector2Array([Vector2(47, 24), Vector2(39, 32), Vector2(47, 40)]), separator_color, 2)
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
var minimum_first_width := MIN_ANGELA_WIDTH
var maximum_first_width := MAX_ANGELA_WIDTH
var minimum_second_width := MIN_COMPUTER_WIDTH
var width_step := WIDTH_STEP
var _input_admission: Callable
var _custom_handle_accessibility := false


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	_ensure_handle()
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null:
		localization.locale_changed.connect(_refresh_handle_accessibility)
		_refresh_handle_accessibility(str(localization.get_locale()))
	set_process(_input_admission.is_valid())
	queue_sort()


func _get_minimum_size() -> Vector2:
	return Vector2(minimum_first_width + minimum_second_width, 0)


func set_input_admission(admission: Callable) -> void:
	_input_admission = admission
	set_process(admission.is_valid())
	_sync_input_admission()


func _process(_delta: float) -> void:
	_sync_input_admission()


func _input_admitted() -> bool:
	return not _input_admission.is_valid() or bool(_input_admission.call())


func _sync_input_admission() -> void:
	if not is_instance_valid(_handle): return
	var admitted := _input_admitted()
	if not admitted: _retire_drag()
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP if admitted else Control.MOUSE_FILTER_IGNORE
	_handle.focus_mode = Control.FOCUS_ALL if admitted else Control.FOCUS_NONE


func is_dragging() -> bool:
	return _mouse_dragging or _touch_index >= 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_children()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_retire_drag()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_retire_drag()


func _input(event: InputEvent) -> void:
	if not _input_admitted():
		_retire_drag()
		return
	# Own the remainder of a resize gesture even when it leaves the grip.
	var captured: bool = (_mouse_dragging and (event is InputEventMouseMotion or
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed))) \
		or (_touch_index >= 0 and ((event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index == _touch_index))
	if captured:
		_observe_consumed_contact(event)
		var local_event: InputEvent = event.duplicate()
		local_event.position = _handle.get_global_transform_with_canvas().affine_inverse() * event.position
		_on_handle_gui_input(local_event)
		get_viewport().set_input_as_handled()
		return
	if is_dragging():
		_observe_consumed_contact(event)
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_retire_drag()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and is_instance_valid(_handle) and _handle.get_global_rect().has_point(event.position):
		_focus_before_pointer = get_viewport().gui_get_focus_owner()
	elif event is InputEventScreenTouch and event.pressed and is_instance_valid(_handle) \
			and _handle.get_global_rect().has_point(event.position):
		_focus_before_pointer = get_viewport().gui_get_focus_owner()


func _observe_consumed_contact(event: InputEvent) -> void:
	# Global capture runs before the autoload: keep its contact ledger in sync.
	var input_owner := get_node_or_null("/root/InputManager")
	if input_owner != null and input_owner.has_method("observe_physical_contact"):
		input_owner.observe_physical_contact(event)


func set_angela_width(width: float) -> void:
	var next := clampf(snappedf(width, width_step), minimum_first_width, maximum_first_width)
	if is_equal_approx(next, _angela_width):
		return
	_angela_width = next
	queue_sort()
	split_changed.emit(_angela_width)


func get_angela_width() -> float:
	return _angela_width


func set_handle_accessibility(name: String, description: String) -> void:
	_ensure_handle()
	_custom_handle_accessibility = true
	_handle.accessibility_name = name
	_handle.accessibility_description = description


func _refresh_handle_accessibility(locale_id: String) -> void:
	if _custom_handle_accessibility: return
	var copy: Array = HANDLE_ACCESSIBILITY_COPY.get(locale_id, HANDLE_ACCESSIBILITY_COPY["en"])
	_handle.accessibility_name = copy[0]
	_handle.accessibility_description = copy[1]


func _ensure_handle() -> void:
	if is_instance_valid(_handle):
		return
	_handle = SplitDragHandle.new()
	_handle.name = "SplitDragHandle"
	_handle.custom_minimum_size = HANDLE_SIZE
	_handle.focus_mode = Control.FOCUS_ALL
	_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_refresh_handle_accessibility("en")
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
	if has_theme_color(&"face", &"Desktop"):
		_handle.grip_color = get_theme_color(&"face", &"Desktop")
	if has_theme_color(&"focus", &"Desktop"):
		_handle.focus_color = get_theme_color(&"focus", &"Desktop")
	_handle.queue_redraw()


func _on_handle_gui_input(event: InputEvent) -> void:
	if not _input_admitted():
		_retire_drag()
		_handle.accept_event()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		_handle.accept_event()
		return
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
				_commit_width(_angela_width - KEYBOARD_STEP)
			KEY_RIGHT:
				_commit_width(_angela_width + KEYBOARD_STEP)
			KEY_HOME:
				_commit_width(minimum_first_width)
			KEY_END:
				_commit_width(maximum_first_width)
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
	drag_changed.emit(true)


func _update_drag(pointer_x: float) -> void:
	# Keep both panes and their hit targets stable until the pointer is released.
	_preview_width = clampf(snappedf(_drag_origin_width + pointer_x - _drag_origin_x, width_step),
		minimum_first_width, maximum_first_width)
	_handle.preview_offset = _preview_width - _angela_width
	_handle.queue_redraw()


func _finish_drag() -> void:
	var committed_width := _preview_width
	_retire_drag()
	_commit_width(committed_width)


func _commit_width(width: float) -> void:
	var previous := _angela_width
	set_angela_width(width)
	if not is_equal_approx(previous, _angela_width):
		width_committed.emit(_angela_width)


func _retire_drag() -> void:
	var was_dragging := is_dragging()
	_mouse_dragging = false
	_touch_index = -1
	if is_instance_valid(_handle):
		_handle.preview_visible = false
		_handle.preview_offset = 0.0
		_handle.queue_redraw()
	if was_dragging: drag_changed.emit(false)


func _handle_point_to_split_x(point: Vector2) -> float:
	var canvas_point := _handle.get_global_transform_with_canvas() * point
	return (get_global_transform_with_canvas().affine_inverse() * canvas_point).x


func _restore_pointer_focus() -> void:
	if is_instance_valid(_focus_before_pointer) and _focus_before_pointer.is_inside_tree():
		_focus_before_pointer.grab_focus()
	_focus_before_pointer = null
