extends GutTest

const SPLIT := preload("res://scripts/ui/desktop/DesktopPanelSplit.gd")

var _viewport: SubViewport
var _split: Container
var _angela: Control
var _computer: Control
var _focus_target: Button
var _edge_button: Button


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_split = SPLIT.new()
	_split.size = Vector2(1280, 720)
	_viewport.add_child(_split)
	_angela = Control.new()
	_angela.name = "AngelaPane"
	_split.add_child(_angela)
	_computer = Control.new()
	_computer.name = "ComputerPane"
	_split.add_child(_computer)
	_focus_target = Button.new()
	_focus_target.position = Vector2(40, 80)
	_focus_target.size = Vector2(120, 64)
	_focus_target.focus_mode = Control.FOCUS_ALL
	_computer.add_child(_focus_target)
	_edge_button = Button.new()
	_edge_button.position = Vector2(8, 328)
	_edge_button.size = Vector2(48, 64)
	_computer.add_child(_edge_button)
	await _settle()


func _settle() -> void:
	for frame: int in range(3):
		await get_tree().process_frame


func _push(event: InputEvent) -> bool:
	_viewport.push_input(event, true)
	return _viewport.is_input_handled()


func _mouse_button(point: Vector2, pressed: bool) -> bool:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return _push(event)


func _mouse_motion(point: Vector2, relative: Vector2,
		button_mask: int = MOUSE_BUTTON_MASK_LEFT) -> bool:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = button_mask
	return _push(event)


func _key(code: Key) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return _push(event)


func _touch(point: Vector2, pressed: bool, canceled: bool = false) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	return _push(event)


func _touch_drag(point: Vector2, relative: Vector2) -> bool:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = point
	event.relative = relative
	return _push(event)


func test_default_and_programmatic_widths_lay_out_two_panes_without_a_stolen_gutter() -> void:
	assert_eq(_split.get_angela_width(), 480.0)
	assert_eq(_angela.get_rect(), Rect2(0, 0, 480, 720))
	assert_eq(_computer.get_rect(), Rect2(480, 0, 800, 720))
	var changes: Array[float] = []
	_split.split_changed.connect(func(width: float): changes.append(width))
	_split.set_angela_width(400)
	await _settle()
	assert_eq(_angela.get_rect(), Rect2(0, 0, 400, 720))
	assert_eq(_computer.get_rect(), Rect2(400, 0, 880, 720))
	_split.set_angela_width(0)
	await _settle()
	assert_eq(_split.get_angela_width(), 320.0)
	assert_eq(_angela.get_rect(), Rect2(0, 0, 320, 720))
	assert_eq(_computer.get_rect(), Rect2(320, 0, 960, 720))
	_split.set_angela_width(1000)
	await _settle()
	assert_eq(_split.get_angela_width(), 480.0)
	assert_eq(_computer.get_rect(), Rect2(480, 0, 800, 720))
	assert_eq(changes, [400.0, 320.0, 480.0], "only effective public width changes are published")


func test_central_pointer_drag_clamps_and_preserves_existing_focus_and_children() -> void:
	_focus_target.grab_focus()
	var handle := _split.get_node("SplitDragHandle") as Control
	assert_eq(handle.size, Vector2(64, 64), "drag affordance is a large target")
	assert_eq(handle.position, Vector2(416, 328), "large target stays wholly on Angela's side")
	var angela_id := _angela.get_instance_id()
	var computer_id := _computer.get_instance_id()
	assert_true(_mouse_button(Vector2(472, 360), true))
	assert_true(_mouse_motion(Vector2(372, 360), Vector2(-100, 0)))
	assert_eq(_split.get_angela_width(), 380.0)
	assert_true(_mouse_motion(Vector2(332, 360), Vector2(-40, 0)))
	assert_eq(_split.get_angela_width(), 340.0, "successive motion uses stable split coordinates")
	assert_true(_mouse_motion(Vector2(252, 360), Vector2(-80, 0)))
	assert_true(_mouse_button(Vector2(252, 360), false))
	await _settle()
	assert_eq(_split.get_angela_width(), 320.0)
	assert_true(_focus_target.has_focus(), "resizing does not steal semantic app focus")
	assert_eq(_angela.get_instance_id(), angela_id)
	assert_eq(_computer.get_instance_id(), computer_id)
	assert_eq(_split.get_child_count(), 3, "resizing does not remount either pane")


func test_app_control_near_the_seam_remains_clickable() -> void:
	var presses: Array[int] = [0]
	_edge_button.pressed.connect(func(): presses[0] += 1)
	assert_true(_mouse_button(Vector2(496, 360), true))
	_mouse_button(Vector2(496, 360), false)
	await _settle()
	assert_eq(presses[0], 1)
	assert_eq(_split.get_angela_width(), 480.0, "app-edge input cannot begin a divider drag")


func test_focused_affordance_supports_bounded_keyboard_adjustment() -> void:
	var handle := _split.get_node("SplitDragHandle") as Control
	assert_eq(handle.focus_mode, Control.FOCUS_ALL)
	assert_eq(handle.accessibility_name, "Resize Angela panel")
	_split.set_handle_accessibility("调整安吉拉面板", "左右拖动或使用方向键")
	assert_eq(handle.accessibility_name, "调整安吉拉面板")
	assert_eq(handle.accessibility_description, "左右拖动或使用方向键")
	handle.grab_focus()
	assert_true(_key(KEY_LEFT))
	await _settle()
	assert_eq(_split.get_angela_width(), 464.0)
	assert_true(handle.has_focus())
	assert_true(_key(KEY_HOME))
	await _settle()
	assert_eq(_split.get_angela_width(), 320.0)
	assert_true(_key(KEY_RIGHT))
	await _settle()
	assert_eq(_split.get_angela_width(), 336.0)
	assert_true(_key(KEY_END))
	await _settle()
	assert_eq(_split.get_angela_width(), 480.0)
	assert_true(handle.has_focus())


func test_touch_drag_resizes_and_cancellation_ends_pointer_custody() -> void:
	assert_true(_touch(Vector2(472, 360), true))
	assert_true(_touch_drag(Vector2(422, 360), Vector2(-50, 0)))
	assert_eq(_split.get_angela_width(), 430.0)
	assert_true(_touch_drag(Vector2(362, 360), Vector2(-60, 0)))
	assert_eq(_split.get_angela_width(), 370.0, "successive touch motion uses stable split coordinates")
	assert_true(_touch(Vector2(362, 360), false, true))
	_touch_drag(Vector2(350, 360), Vector2(-50, 0))
	assert_eq(_split.get_angela_width(), 370.0)


func test_focus_loss_and_missing_release_retire_mouse_drag_ownership() -> void:
	assert_true(_mouse_button(Vector2(472, 360), true))
	assert_true(_mouse_motion(Vector2(422, 360), Vector2(-50, 0)))
	assert_eq(_split.get_angela_width(), 430.0)
	_split.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_mouse_motion(Vector2(372, 360), Vector2(-50, 0))
	assert_eq(_split.get_angela_width(), 430.0, "focus loss retires an unreleased drag")
	assert_true(_mouse_button(Vector2(422, 360), true))
	_mouse_motion(Vector2(392, 360), Vector2(-30, 0), 0)
	assert_eq(_split.get_angela_width(), 430.0, "motion without a held left button cannot resize")
	_mouse_motion(Vector2(362, 360), Vector2(-30, 0))
	assert_eq(_split.get_angela_width(), 430.0, "missing-button motion retires stale ownership")
