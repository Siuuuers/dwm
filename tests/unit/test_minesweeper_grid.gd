extends "res://addons/gut/test.gd"

const INPUT_FIXTURE := preload("res://tests/support/MinesweeperInputFixture.gd")
var _input_fixture: RefCounted


const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")

func _cell(index: int, overrides: Dictionary = {}) -> Dictionary:
	var cell := {"index":index,"face":"covered","mark":"none","number":0,"bracketed":false,"inspectable":true,"pressable":true,"actions":["reveal","flag"]}
	cell.merge(overrides,true)
	return cell

func _projection(cells: Array, width: int = 2, custody: bool = false, terminal: bool = false) -> Dictionary:
	return {"width":width,"height":int(cells.size()/width),"revision":7,"mine_estimate":1,"terminal":terminal,"custody":custody,"cells":cells}

func _grid(large: bool = false) -> Control:
	var grid: Control = GRID.new()
	add_child_autofree(grid)
	assert_true(grid.configure("en",100,large))
	return grid

func test_strict_projection_builds_contiguous_exact_mount() -> void:
	for large: bool in [false,true]:
		var grid: Control = _grid(large)
		assert_true(grid.present(_projection([_cell(0),_cell(1),_cell(2),_cell(3)])))
		var target: int = 64 if large else 48
		assert_eq(grid.size,Vector2(2*target+4,2*target+4))
		assert_eq(grid.cell_nodes[0].position,Vector2(2,2))
		assert_eq(grid.cell_nodes[1].position,Vector2(2+target,2))
		assert_eq(grid.cell_nodes[2].position,Vector2(2,2+target))
		assert_eq(grid.cell_nodes[3].position,Vector2(2+target,2+target))
		assert_eq(grid.focus_mode,Control.FOCUS_ALL)

func test_invalid_projection_is_atomic_and_rejects_private_keys() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var retained: Dictionary = grid.projection
	var retained_node: Control = grid.cell_nodes[0]
	var invalid: Dictionary = _projection([_cell(0),_cell(1)])
	invalid.private_board_id = "hidden"
	assert_false(grid.present(invalid))
	assert_eq(grid.projection,retained)
	assert_same(grid.cell_nodes[0],retained_node)

func test_same_dimensions_reuse_cell_and_theme_instances_across_revisions() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1),_cell(2),_cell(3)])))
	var retained_nodes: Array = grid.cell_nodes.duplicate()
	var retained_themes: Array = []
	for cell: Control in grid.cell_nodes: retained_themes.append(cell.theme)
	var changed: Dictionary = _projection([_cell(0,{"mark":"flag","actions":["unflag"]}),_cell(1),_cell(2),_cell(3)])
	changed.revision = 8
	assert_true(grid.present(changed))
	for index in 4:
		assert_same(grid.cell_nodes[index],retained_nodes[index])
		assert_same(grid.cell_nodes[index].theme,retained_themes[index])
	assert_eq(grid.cell_nodes[0].public_cell.mark,"flag")

func test_resize_keeps_prefix_frees_removed_suffix_and_reflows_positions() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1),_cell(2),_cell(3)])))
	var first: Control = grid.cell_nodes[0]
	var second: Control = grid.cell_nodes[1]
	var removed: Control = grid.cell_nodes[3]
	assert_true(grid.present(_projection([_cell(0),_cell(1)],1)))
	assert_eq(grid.cell_nodes.size(),2)
	assert_same(grid.cell_nodes[0],first)
	assert_same(grid.cell_nodes[1],second)
	assert_false(is_instance_valid(removed))
	assert_eq(grid.cell_nodes[0].position,Vector2(2,2))
	assert_eq(grid.cell_nodes[1].position,Vector2(2,50))
	assert_eq(grid.size,Vector2(52,100))

func test_roving_focus_moves_without_wrap_and_bracketed_repairs_first() -> void:
	var grid: Control = _grid()
	var cells: Array = [_cell(0),_cell(1),_cell(2,{"bracketed":true,"actions":["reveal"]}),_cell(3)]
	assert_true(grid.present(_projection(cells)))
	assert_eq(grid.focused_index,2)
	grid._move_focus(Vector2i.RIGHT)
	assert_eq(grid.focused_index,3)
	grid._move_focus(Vector2i.RIGHT)
	assert_eq(grid.focused_index,3,"Right edge does not wrap.")
	grid._move_focus(Vector2i.UP)
	assert_eq(grid.focused_index,1)

func test_modes_and_explicit_actions_never_infer_illegal_commands() -> void:
	var grid: Control = _grid()
	var cells: Array = [
		_cell(0,{"actions":["reveal"],"pressable":true}),
		_cell(1,{"mark":"flag","actions":["unflag"]}),
		_cell(2,{"face":"revealed","number":2,"actions":["chord"]}),
		_cell(3,{"face":"revealed","number":0,"actions":[],"pressable":false}),
	]
	assert_true(grid.present(_projection(cells)))
	assert_eq(grid._pointer_action(0,MOUSE_BUTTON_RIGHT),&"","NONE projection does not invent pre-Reveal Flag.")
	assert_eq(grid._mode_action(1),&"","Reveal mode does not Reveal a Flag.")
	assert_true(grid.set_mode(&"flag"))
	assert_eq(grid._mode_action(2),&"chord","Flag mode still admits the published Chord action.")
	assert_eq(grid._mode_action(1),&"unflag")
	assert_true(grid.set_mode(&"drag"))
	assert_eq(grid._mode_action(0),&"")

func test_paired_pointer_release_and_keyboard_emit_once_with_revision() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.device = 0
	down.position = Vector2(10,10)
	down.pressed = true
	grid._gui_input(down)
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	grid._gui_input(up)
	grid._gui_input(up)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"reveal",0,7])
	assert_signal_emit_count(grid,"cell_action_requested",1)

func test_pointer_focuses_read_only_cell_and_press_submits_before_any_release() -> void:
	var grid: Control = _grid()
	var cells: Array = [_cell(0),_cell(1,{"face":"revealed","number":0,"actions":[],"pressable":false})]
	assert_true(grid.present(_projection(cells)))
	watch_signals(grid)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.device = 0
	down.position = Vector2(60,10)
	down.pressed = true
	grid._gui_input(down)
	assert_eq(grid.focused_index,1)
	assert_signal_emit_count(grid,"cell_action_requested",0)
	down.position = Vector2(10,10)
	grid._gui_input(down)
	var wrong_up: InputEventMouseButton = down.duplicate()
	wrong_up.button_index = MOUSE_BUTTON_RIGHT
	wrong_up.pressed = false
	grid._gui_input(wrong_up)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"reveal",0,7])
	assert_signal_emit_count(grid,"cell_action_requested",1,"dwm-634.1: the press submits; a mismatched release adds nothing")
	assert_eq(grid._held_index,-1,"any release clears the held contact")

func test_accessibility_exposes_one_based_coordinate_and_visible_fact_only() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1,{"mark":"flag","actions":["unflag"]})])))
	grid._move_focus(Vector2i.RIGHT)
	assert_eq(grid.accessibility_name,"Row 1, column 2, Flag")
	assert_false(grid.accessibility_name.contains("unflag"))
	assert_true(grid.configure("zh-CN",100,false))
	assert_eq(grid.accessibility_name,"第1行，第2列，旗帜")
	assert_true(grid.present(_projection([_cell(0),_cell(1,{"face":"revealed","number":0,"actions":[],"pressable":false})])))
	assert_eq(grid.accessibility_name,"第1行，第2列，空白")
	grid._move_focus(Vector2i.LEFT)
	assert_eq(grid.accessibility_name,"第1行，第1列，未揭开")

func test_keyboard_f_toggles_mode_and_space_requests_new_board_without_cell_action() -> void:
	var grid: Control = _grid()
	assert_true(_input_fixture.bind_grid(grid,grid))
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var f: InputEventKey = InputEventKey.new()
	f.keycode = KEY_F
	f.physical_keycode = KEY_F
	f.pressed = true
	grid.grab_focus()
	grid._input_owner._input(f)
	grid._gui_input(f)
	assert_eq(grid.mode,&"flag")
	f.pressed = false
	grid._input_owner._input(f)
	grid._gui_input(f)
	assert_true(grid.set_mode(&"drag"))
	f.pressed = true
	grid._input_owner._input(f)
	grid._gui_input(f)
	assert_eq(grid.mode,&"flag")
	f.pressed = false
	grid._input_owner._input(f)
	grid._gui_input(f)
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	grid._input_owner._input(space)
	grid._gui_input(space)
	assert_signal_emit_count(grid,"new_board_requested",1)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_cross_cell_rules_reject_terminal_or_custody_contacts_atomically() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	var retained: Dictionary = grid.projection
	assert_false(grid.present(_projection([_cell(0),_cell(1)],2,true)))
	assert_false(grid.present(_projection([_cell(0,{"face":"revealed","mark":"mine","actions":[],"pressable":false}),_cell(1)],2,false,false)))
	assert_false(grid.present(_projection([_cell(0,{"bracketed":true,"actions":[],"pressable":false}),_cell(1,{"inspectable":false,"actions":[],"pressable":false})],2,true,true)))
	assert_eq(grid.projection,retained)

func test_joy_axis_navigation_is_edge_latched_until_neutral() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1),_cell(2),_cell(3),_cell(4),_cell(5)],3)))
	var axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	grid._gui_input(axis)
	assert_eq(grid.focused_index,1)
	grid._gui_input(axis)
	assert_eq(grid.focused_index,1,"A held axis does not repeat navigation.")
	axis.axis_value = 0.0
	grid._gui_input(axis)
	axis.axis_value = 1.0
	grid._gui_input(axis)
	assert_eq(grid.focused_index,2,"A fresh edge after neutral moves again.")

func test_confirm_is_shared_latched_and_blocks_pointer_and_space_until_release() -> void:
	var grid: Control = _grid()
	assert_true(_input_fixture.bind_grid(grid,grid))
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	grid.grab_focus()
	watch_signals(grid)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	grid._gui_input(enter)
	grid._gui_input(enter)
	assert_signal_emit_count(grid,"cell_action_requested",1)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.device = 0
	down.position = Vector2(10,10)
	down.pressed = true
	grid._gui_input(down)
	assert_eq(grid._held_index,-1)
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	grid._input_owner._input(space)
	grid._gui_input(space)
	assert_signal_emit_count(grid,"new_board_requested",0)
	enter.pressed = false
	grid._gui_input(enter)
	grid._gui_input(space)
	assert_signal_emit_count(grid,"new_board_requested",0,"the Space contact held through Confirm release is not fresh")
	space.pressed = false
	grid._input_owner._input(space)
	grid._gui_input(space)
	space.pressed = true
	grid._input_owner._input(space)
	grid._gui_input(space)
	assert_signal_emit_count(grid,"new_board_requested",1)

func test_custody_cancels_contact_and_removes_grid_focus() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	grid._held_index = 0
	var inert: Array = [_cell(0,{"inspectable":false,"pressable":false,"actions":[]}),_cell(1,{"inspectable":false,"pressable":false,"actions":[]})]
	assert_true(grid.present(_projection(inert,2,true)))
	assert_eq(grid._held_index,-1)
	assert_eq(grid.focused_index,-1)
	assert_eq(grid.focus_mode,Control.FOCUS_NONE)

func test_drag_mode_mouse_slop_emits_content_motion_and_stationary_release_is_inert() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	assert_true(grid.set_mode(&"drag"))
	watch_signals(grid)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.device = 0
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(10,10)
	down.pressed = true
	grid._gui_input(down)
	var small: InputEventMouseMotion = InputEventMouseMotion.new()
	small.device = 0
	small.position = Vector2(15,10)
	small.relative = Vector2(5,0)
	grid._gui_input(small)
	assert_signal_emit_count(grid,"pan_requested",0)
	var jitter_back: InputEventMouseMotion = small.duplicate()
	jitter_back.position = Vector2(10,10)
	jitter_back.relative = Vector2(-5,0)
	grid._gui_input(jitter_back)
	assert_signal_emit_count(grid,"pan_requested",0,"Jitter distance is radial from the gesture origin, not cumulative travel.")
	var crossing: InputEventMouseMotion = small.duplicate()
	crossing.position = Vector2(20,10)
	crossing.relative = Vector2(9,0)
	grid._gui_input(crossing)
	assert_signal_emitted_with_parameters(grid,"panning_changed",[true])
	assert_signal_emitted_with_parameters(grid,"pan_requested",[Vector2(9,0)])
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	grid._gui_input(up)
	assert_signal_emitted_with_parameters(grid,"panning_changed",[false])
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_touch_short_tap_long_press_and_pan_are_mutually_exclusive() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 3
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	assert_true(grid.cell_nodes[0].pressed,"A legal pending Reveal tap shows Press chrome.")
	grid._process(0.49)
	assert_signal_emit_count(grid,"cell_action_requested",0)
	grid._process(0.011)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"flag",0,7])
	touch.pressed = false
	grid._gui_input(touch)
	assert_signal_emit_count(grid,"cell_action_requested",1,"Release after long press cannot activate.")
	touch.pressed = true
	grid._gui_input(touch)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(20,10)
	drag.relative = Vector2(9,0)
	grid._gui_input(drag)
	assert_false(grid.cell_nodes[0].pressed,"Crossing pan slop clears Press chrome.")
	grid._process(1.0)
	assert_signal_emitted_with_parameters(grid,"pan_requested",[Vector2(9,0)])
	touch.position = Vector2(20,10)
	touch.pressed = false
	grid._gui_input(touch)
	assert_false(grid.cell_nodes[0].pressed)
	assert_signal_emit_count(grid,"cell_action_requested",1)
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	touch.pressed = false
	grid._gui_input(touch)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"reveal",0,7])
	assert_signal_emit_count(grid,"cell_action_requested",2)

func test_touch_press_chrome_requires_current_mode_primary_action() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0,{"mark":"flag","actions":["unflag"]}),_cell(1)])))
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 8
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	assert_false(grid.cell_nodes[0].pressed,"Reveal mode does not show Press for a flag whose only primary action is unavailable.")
	grid.cancel_pointer_gesture()
	assert_true(grid.set_mode(&"flag"))
	grid._gui_input(touch)
	assert_true(grid.cell_nodes[0].pressed)
	touch.pressed = false
	grid._gui_input(touch)
	assert_false(grid.cell_nodes[0].pressed)

func test_canceled_touch_and_double_tap_never_activate() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 6
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	assert_true(grid.cell_nodes[0].pressed)
	touch.pressed = false
	touch.canceled = true
	grid._gui_input(touch)
	assert_eq(grid._touch_id,-1)
	assert_false(grid.cell_nodes[0].pressed)
	assert_signal_emit_count(grid,"cell_action_requested",0)
	touch.canceled = false
	touch.double_tap = true
	touch.pressed = true
	grid._gui_input(touch)
	assert_eq(grid._touch_id,-1)
	touch.pressed = false
	grid._gui_input(touch)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_second_touch_cancels_pending_tap_and_public_cancel_does_not_release_confirm() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var first: InputEventScreenTouch = InputEventScreenTouch.new()
	first.index = 1
	first.position = Vector2(10,10)
	first.pressed = true
	grid._gui_input(first)
	var second: InputEventScreenTouch = first.duplicate()
	second.index = 2
	grid._gui_input(second)
	assert_eq(grid._touch_id,-1,"Second touch cancels the pending tap even at zero pinch distance.")
	assert_true(grid.has_held_touch())
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.device = 0
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(10,10)
	mouse.pressed = true
	grid._gui_input(mouse)
	assert_eq(grid._held_index,-1,"Mouse cannot steal a live touch gesture.")
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	grid._gui_input(space)
	assert_signal_emit_count(grid,"new_board_requested",0)
	grid._confirm_held = true
	grid.cancel_pointer_gesture()
	assert_eq(grid._touch_id,-1)
	assert_true(grid._confirm_held)

func test_long_press_refresh_keeps_release_gate_until_same_finger_lifts() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	grid.cell_action_requested.connect(func(_action: StringName, _index: int, _revision: int) -> void:
		var changed: Dictionary = _projection([_cell(0,{"mark":"flag","actions":["unflag"]}),_cell(1)])
		changed.revision = 8
		assert_true(grid.present(changed))
	)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 4
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	grid._process(0.5)
	assert_eq(grid._touch_id,4,"Synchronous projection replacement retains the release gate.")
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.device = 0
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.position = Vector2(10,10)
	mouse.pressed = true
	grid._gui_input(mouse)
	assert_eq(grid._held_index,-1)
	touch.pressed = false
	grid._gui_input(touch)
	assert_eq(grid._touch_id,-1)
	assert_signal_emit_count(grid,"cell_action_requested",1)

func test_right_stick_pan_waits_for_touch_release_and_latches_until_neutral() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = 1.0
	grid._gui_input(axis)
	assert_signal_emit_count(grid,"pan_requested",0,"Pending touch cannot be displaced by another input device.")
	assert_eq(grid._touch_id,2)
	touch.pressed = false
	touch.canceled = true
	grid._gui_input(touch)
	grid._gui_input(axis)
	grid._gui_input(axis)
	assert_signal_emit_count(grid,"pan_requested",1)
	axis.axis_value = 0.0
	grid._gui_input(axis)
	axis.axis_value = 1.0
	grid._gui_input(axis)
	assert_signal_emit_count(grid,"pan_requested",2)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_focus_signal_reports_repair_move_and_focus_reentry() -> void:
	var grid: Control = _grid()
	watch_signals(grid)
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	assert_signal_emitted_with_parameters(grid,"focused_cell_changed",[0])
	grid._move_focus(Vector2i.RIGHT)
	assert_signal_emitted_with_parameters(grid,"focused_cell_changed",[1])
	grid._on_focus_entered()
	assert_signal_emit_count(grid,"focused_cell_changed",3)

func test_real_f_route_emits_only_actual_valid_mode_changes() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,240)
	add_child_autofree(viewport)
	var grid: Control = GRID.new()
	viewport.add_child(grid)
	assert_true(_input_fixture.bind_grid(grid,viewport))
	assert_true(grid.configure())
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	grid.grab_focus()
	watch_signals(grid)
	assert_true(grid.set_mode(&"reveal"))
	assert_false(grid.set_mode(&"unknown"))
	assert_signal_emit_count(grid,"mode_changed",0)
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = true
	viewport.push_input(event,true)
	assert_eq(grid.mode,&"flag")
	assert_signal_emitted_with_parameters(grid,"mode_changed",[&"flag"])
	event.echo = true
	viewport.push_input(event,true)
	assert_signal_emit_count(grid,"mode_changed",1)
	event.echo = false
	event.pressed = false
	viewport.push_input(event,true)
	event.pressed = true
	viewport.push_input(event,true)
	assert_eq(grid.mode,&"reveal")
	assert_signal_emitted_with_parameters(grid,"mode_changed",[&"reveal"])
	assert_signal_emit_count(grid,"mode_changed",2)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_identical_or_rejected_mode_preserves_pending_contact_and_active_pan() -> void:
	var grid := _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(10,10)
	click.pressed = true
	grid._gui_input(click)
	assert_eq(grid._held_index,0)
	assert_true(grid.set_mode(&"reveal"))
	assert_false(grid.set_mode(&"unknown"))
	assert_eq(grid._held_index,0)
	assert_signal_emit_count(grid,"mode_changed",0)
	click.pressed = false
	grid._gui_input(click)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"reveal",0,7])
	assert_true(grid.set_mode(&"drag"))
	click.pressed = true
	grid._gui_input(click)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0,-12)
	grid._gui_input(motion)
	assert_true(grid._panning)
	assert_true(grid.set_mode(&"drag"))
	assert_true(grid._mouse_dragging)
	assert_true(grid._panning)
	grid._gui_input(motion)
	assert_signal_emit_count(grid,"pan_requested",2)
	assert_signal_emit_count(grid,"mode_changed",1)
	click.pressed = false
	grid._gui_input(click)
	assert_false(grid._panning)

func test_can_present_validates_without_changing_grid_projection_focus_or_children() -> void:
	var grid := _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	grid._set_focused(1)
	grid.grab_focus()
	var retained: Dictionary = grid.projection.duplicate(true)
	var retained_nodes: Array = grid.cell_nodes.duplicate()
	var retained_count: int = grid.get_child_count()
	watch_signals(grid)
	assert_true(grid.can_present(_projection([_cell(0),_cell(1),_cell(2),_cell(3)])))
	assert_false(grid.can_present(_projection([_cell(0),_cell(1,{"private_mine":true})])))
	assert_eq(grid.projection,retained)
	assert_eq(grid.focused_index,1)
	assert_true(grid.has_focus())
	assert_eq(grid.get_child_count(),retained_count)
	assert_eq(grid.cell_nodes.size(),retained_nodes.size())
	for index: int in retained_nodes.size(): assert_same(grid.cell_nodes[index],retained_nodes[index])
	assert_signal_emit_count(grid,"focused_cell_changed",0)
	assert_signal_emit_count(grid,"cell_action_requested",0)

func test_interaction_block_cancels_real_touch_and_ignores_input_without_changing_facts() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,240)
	add_child_autofree(viewport)
	var grid: Control = GRID.new()
	viewport.add_child(grid)
	assert_true(grid.configure())
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	assert_true(grid.set_mode(&"flag"))
	grid.grab_focus()
	var retained: Dictionary = grid.projection.duplicate(true)
	watch_signals(grid)
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = Vector2(10,10)
	touch.pressed = true
	viewport.push_input(touch,true)
	assert_true(grid.has_held_touch())
	grid.set_interaction_blocked(true)
	assert_false(grid.has_held_touch())
	assert_eq(grid.focus_mode,Control.FOCUS_NONE)
	assert_false(grid.has_focus())
	grid._process(1.0)
	touch.pressed = false
	viewport.push_input(touch,true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(10,10)
	click.pressed = true
	viewport.push_input(click,true)
	click.pressed = false
	viewport.push_input(click,true)
	assert_eq(grid.projection,retained)
	assert_eq(grid.mode,&"flag")
	assert_signal_emit_count(grid,"cell_action_requested",0)
	assert_signal_emit_count(grid,"pan_requested",0)
	assert_true(grid.present(retained))
	assert_eq(grid.focus_mode,Control.FOCUS_NONE,"Projection rebuild cannot bypass the interaction block.")
	grid.set_interaction_blocked(false)
	assert_eq(grid.focus_mode,Control.FOCUS_ALL)
	grid.grab_focus()
	assert_true(grid.has_focus())
	click.pressed = true
	viewport.push_input(click,true)
	click.pressed = false
	viewport.push_input(click,true)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"flag",0,7])
	assert_eq(grid.projection,retained)

func before_each() -> void:
	_input_fixture = INPUT_FIXTURE.new()

func after_each() -> void:
	_input_fixture.restore_map()
	_input_fixture = null


func test_mouse_press_submits_once_and_release_or_drag_off_submits_nothing_more() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.device = 0
	down.position = Vector2(10,10)
	down.pressed = true
	grid._gui_input(down)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"reveal",0,7])
	assert_signal_emit_count(grid,"cell_action_requested",1,"dwm-634.1: the press itself submits")
	assert_eq(grid._held_index,0,"the contact stays held until the button lifts")
	var elsewhere: InputEventMouseButton = down.duplicate()
	elsewhere.pressed = false
	elsewhere.position = Vector2(60,10)
	grid._gui_input(elsewhere)
	assert_signal_emit_count(grid,"cell_action_requested",1,"releasing on another cell submits nothing")
	assert_eq(grid._held_index,-1)
	var right: InputEventMouseButton = down.duplicate()
	right.button_index = MOUSE_BUTTON_RIGHT
	grid._gui_input(right)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"flag",0,7])
	assert_signal_emit_count(grid,"cell_action_requested",2)
	right.pressed = false
	grid._gui_input(right)
	assert_signal_emit_count(grid,"cell_action_requested",2)
