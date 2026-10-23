extends "res://addons/gut/test.gd"

const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")

class InputOwner extends RefCounted:
	signal input_bindings_changed()
	signal source_input_custody_changed()
	var admitted := true
	func get_physical_contacts() -> Dictionary: return {}
	func get_physical_contact_id(_event: InputEvent) -> String: return ""
	func is_source_input_admitted() -> bool: return admitted

class PolledGrid extends GRID:
	var physical_axes: Dictionary = {}
	func _poll_trigger_axes() -> void:
		for device: int in physical_axes:
			call("_observe_trigger_axis",device,JOY_AXIS_TRIGGER_LEFT,physical_axes[device].x)
			call("_observe_trigger_axis",device,JOY_AXIS_TRIGGER_RIGHT,physical_axes[device].y)

func _grid(polled: bool = false) -> Control:
	var grid: Control = PolledGrid.new() if polled else GRID.new()
	add_child_autofree(grid)
	grid.set_process(false)
	assert_true(grid.configure_input(InputOwner.new()))
	assert_true(grid.configure())
	var cells: Array = []
	for index in 4:
		cells.append({"index":index,"face":"covered","mark":"none","number":0,
			"bracketed":false,"inspectable":true,"pressable":true,"actions":["reveal","flag"]})
	assert_true(grid.present({"width":2,"height":2,"revision":7,"mine_estimate":1,
		"terminal":false,"custody":false,"cells":cells}))
	grid.grab_focus()
	watch_signals(grid)
	return grid

func _wheel(grid: Control, up: bool, ctrl: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.position = Vector2(24,24)
	grid._gui_input(event)

func _axis(grid: Control, axis: int, value: float, device: int = 907) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	grid._gui_input(event)

func _neutral(grid: Control, device: int = 907) -> void:
	_axis(grid,JOY_AXIS_TRIGGER_LEFT,0.0,device)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.0,device)
	grid._process(0.0)

func _touch(grid: Control, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = grid.get_global_transform_with_canvas().affine_inverse()*point
	event.pressed = pressed
	grid._gui_input(event)

func _drag(grid: Control, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = grid.get_global_transform_with_canvas().affine_inverse()*point
	grid._gui_input(event)

func test_ctrl_wheel_emits_signed_steps_at_pointer_and_plain_wheel_still_pans() -> void:
	var grid := _grid()
	assert_true(grid.has_signal("zoom_step_requested"))
	_wheel(grid,true)
	assert_signal_emitted_with_parameters(grid,"zoom_step_requested",[1,Vector2(24,24),&"wheel"])
	_wheel(grid,false)
	assert_signal_emitted_with_parameters(grid,"zoom_step_requested",[-1,Vector2(24,24),&"wheel"])
	assert_signal_emit_count(grid,"pan_requested",0)
	_wheel(grid,false,false)
	assert_signal_emitted_with_parameters(grid,"pan_requested",[Vector2(0,-48)])
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_zoom_rejects_held_cell_action_without_canceling_its_release() -> void:
	var grid := _grid()
	var down := InputEventMouseButton.new()
	down.position = Vector2(24,24)
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	grid._gui_input(down)
	assert_true(grid.call("has_held_action"))
	_wheel(grid,true)
	_neutral(grid)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	down.pressed = false
	grid._gui_input(down)
	assert_signal_emit_count(grid,"cell_action_requested",1)
	assert_false(grid.call("has_held_action"))

func test_second_touch_cancels_tap_and_longpress_and_both_releases_stay_inert() -> void:
	var grid := _grid()
	_touch(grid,1,Vector2(10,10),true)
	grid._process(0.3)
	_touch(grid,2,Vector2(50,10),true)
	grid._process(0.8)
	_drag(grid,2,Vector2(70,10))
	assert_signal_emitted_with_parameters(grid,"pinch_zoom_requested",[1.5,Vector2(40,10)])
	assert_signal_emit_count(grid,"cell_action_requested",0)
	_touch(grid,1,Vector2(10,10),false)
	_touch(grid,2,Vector2(70,10),false)
	assert_signal_emit_count(grid,"pinch_zoom_finished",1)
	assert_signal_emit_count(grid,"cell_action_requested",0)
	assert_false(grid.has_held_touch())
	_touch(grid,3,Vector2(10,10),true)
	_touch(grid,3,Vector2(10,10),false)
	assert_signal_emit_count(grid,"cell_action_requested",1)

func test_pinch_ratio_uses_stable_positions_when_grid_scale_and_origin_change() -> void:
	var grid := _grid()
	_touch(grid,1,Vector2(10,10),true)
	_touch(grid,2,Vector2(50,10),true)
	_drag(grid,2,Vector2(70,10))
	grid.scale = Vector2(2,2)
	grid.position = Vector2(5,3)
	_drag(grid,2,Vector2(90,10))
	assert_signal_emitted_with_parameters(grid,"pinch_zoom_requested",[2.0,Vector2(22.5,3.5)])
	_touch(grid,2,Vector2(90,10),false)
	_touch(grid,1,Vector2(10,10),false)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_third_touch_cancels_pinch_until_every_contact_is_up() -> void:
	var grid := _grid()
	_touch(grid,1,Vector2(10,10),true)
	_touch(grid,2,Vector2(50,10),true)
	_touch(grid,3,Vector2(30,30),true)
	var count: int = get_signal_emit_count(grid,"pinch_zoom_requested")
	_drag(grid,2,Vector2(90,10))
	_touch(grid,3,Vector2(30,30),false)
	_drag(grid,2,Vector2(70,10))
	_touch(grid,2,Vector2(70,10),false)
	_touch(grid,1,Vector2(10,10),false)
	assert_signal_emit_count(grid,"pinch_zoom_requested",count)
	assert_signal_emit_count(grid,"pinch_zoom_finished",1)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_focus_and_custody_cancel_pinch_without_releasing_a_cell_action() -> void:
	for cancellation: String in ["focus","custody","pause"]:
		var grid := _grid()
		_touch(grid,1,Vector2(10,10),true)
		_touch(grid,2,Vector2(50,10),true)
		if cancellation == "focus": grid._on_focus_exited()
		elif cancellation == "pause": grid._notification(Node.NOTIFICATION_PAUSED)
		else:
			grid._input_owner.admitted = false
			grid._input_owner.source_input_custody_changed.emit()
		_touch(grid,1,Vector2(10,10),false)
		_touch(grid,2,Vector2(50,10),false)
		assert_signal_emit_count(grid,"pinch_zoom_finished",1,cancellation)
		assert_signal_emit_count(grid,"cell_action_requested",0,cancellation)

func test_trigger_step_is_deferred_and_requires_release_threshold_before_repeating() -> void:
	var grid := _grid()
	_neutral(grid)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.5)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	grid._process(0.0)
	assert_signal_emitted_with_parameters(grid,"zoom_step_requested",[1,Vector2(-1,-1),&"controller"])
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.9)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.3)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",1)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.2)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",2)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.0)
	_axis(grid,JOY_AXIS_TRIGGER_LEFT,0.8)
	grid._process(0.0)
	assert_signal_emitted_with_parameters(grid,"zoom_step_requested",[-1,Vector2(-1,-1),&"controller"])

func test_simultaneous_triggers_are_coalesced_and_releasing_one_does_not_zoom() -> void:
	var grid := _grid()
	_neutral(grid)
	_axis(grid,JOY_AXIS_TRIGGER_LEFT,0.8)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	_axis(grid,JOY_AXIS_TRIGGER_LEFT,0.0)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	_neutral(grid)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",1)

func test_restore_requires_both_axes_observed_neutral_and_no_device_is_not_neutral() -> void:
	var grid := _grid()
	_neutral(grid)
	grid.cancel_input()
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.0)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	_neutral(grid)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",1)

func test_connected_axis_poll_can_rearm_after_missed_release_without_inventing_a_step() -> void:
	var grid := _grid(true)
	grid.cancel_input()
	grid.physical_axes = {907:Vector2(0,0)}
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	grid.physical_axes = {907:Vector2(0,0.8)}
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",1)

func test_zoom_is_suppressed_by_modal_focus_loss_and_projection_custody() -> void:
	var grid := _grid()
	_neutral(grid)
	_axis(grid,JOY_AXIS_TRIGGER_RIGHT,0.8)
	grid.release_focus()
	grid._process(0.0)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	grid.grab_focus()
	grid._input_owner.admitted = false
	grid._input_owner.source_input_custody_changed.emit()
	_wheel(grid,true)
	assert_signal_emit_count(grid,"zoom_step_requested",0)
	grid._input_owner.admitted = true
	grid.set_interaction_blocked(true)
	_wheel(grid,true)
	assert_signal_emit_count(grid,"zoom_step_requested",0)

func test_right_stick_pan_has_the_same_direction_as_scroll_wheel() -> void:
	var grid := _grid()
	_axis(grid,JOY_AXIS_RIGHT_Y,0.8)
	assert_signal_emitted_with_parameters(grid,"pan_requested",[Vector2(0,-48)])
	_axis(grid,JOY_AXIS_RIGHT_Y,0.0)
	_axis(grid,JOY_AXIS_RIGHT_X,0.8)
	assert_signal_emitted_with_parameters(grid,"pan_requested",[Vector2(-48,0)])

func test_vertical_grid_edge_can_focus_authored_toolbar_neighbor_without_wrapping() -> void:
	var grid := _grid()
	var button := Button.new()
	button.text = "Zoom"
	add_child_autofree(button)
	grid.focus_neighbor_bottom = grid.get_path_to(button)
	assert_true(grid.focus_cell(3))
	grid._move_focus(Vector2i.DOWN)
	assert_true(button.has_focus())
	assert_eq(grid.focused_index,3)
	grid.grab_focus()
	grid.focus_neighbor_bottom = NodePath("")
	grid._move_focus(Vector2i.DOWN)
	assert_true(grid.has_focus())
	assert_eq(grid.focused_index,3)
	grid.focus_neighbor_top = grid.get_path_to(button)
	assert_true(grid.focus_cell(0))
	grid._move_focus(Vector2i.UP)
	assert_true(button.has_focus())
	assert_eq(grid.focused_index,0)

func test_shared_view_admission_observes_quarantine_foreground_and_process_custody() -> void:
	var grid := _grid()
	grid.release_focus()
	assert_true(grid.call("is_view_input_admitted"),"Toolbar admission does not require Grid focus.")
	grid._input_owner.admitted = false
	grid._input_owner.source_input_custody_changed.emit()
	assert_false(grid.call("is_view_input_admitted"))
	assert_signal_emit_count(grid,"view_input_changed",1)
	grid._input_owner.source_input_custody_changed.emit()
	grid._refresh_contacts()
	assert_signal_emit_count(grid,"view_input_changed",1,"Repeated blocked refreshes do not redraw toolbar.")
	grid._input_owner.admitted = true
	grid._input_owner.source_input_custody_changed.emit()
	assert_true(grid.call("is_view_input_admitted"))
	assert_signal_emit_count(grid,"view_input_changed",2)
	grid._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(grid.call("is_view_input_admitted"))
	grid._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(grid.call("is_view_input_admitted"))
	grid.process_mode = Node.PROCESS_MODE_DISABLED
	assert_false(grid.call("is_view_input_admitted"))
	grid.process_mode = Node.PROCESS_MODE_INHERIT
	assert_true(grid.call("is_view_input_admitted"))

func test_view_input_signal_changes_once_per_hold_and_not_per_motion_or_refresh() -> void:
	var grid := _grid()
	_touch(grid,1,Vector2(10,10),true)
	assert_signal_emit_count(grid,"view_input_changed",1)
	grid._refresh_contacts()
	_touch(grid,2,Vector2(50,10),true)
	_drag(grid,2,Vector2(60,10))
	_drag(grid,2,Vector2(70,10))
	assert_signal_emit_count(grid,"view_input_changed",1)
	_touch(grid,1,Vector2(10,10),false)
	assert_signal_emit_count(grid,"view_input_changed",1,"One pinch finger is still held.")
	_touch(grid,2,Vector2(70,10),false)
	assert_signal_emit_count(grid,"view_input_changed",2)
	assert_false(grid.call("has_held_action"))
	grid._refresh_contacts()
	assert_signal_emit_count(grid,"view_input_changed",2)

func test_controller_confirm_hold_notifies_view_controls_on_press_and_release() -> void:
	var grid := _grid()
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	grid._gui_input(confirm)
	assert_true(grid.call("has_held_action"))
	assert_signal_emit_count(grid,"view_input_changed",1)
	confirm.pressed = false
	grid._gui_input(confirm)
	assert_false(grid.call("has_held_action"))
	assert_signal_emit_count(grid,"view_input_changed",2)

func test_show_restores_view_admission_without_requiring_grid_focus() -> void:
	var grid := _grid()
	grid.release_focus()
	grid.hide()
	assert_false(grid.call("is_view_input_admitted"))
	assert_signal_emit_count(grid,"view_input_changed",1)
	grid.show()
	assert_true(grid.call("is_view_input_admitted"))
	assert_false(grid.has_focus())
	assert_signal_emit_count(grid,"view_input_changed",2)
