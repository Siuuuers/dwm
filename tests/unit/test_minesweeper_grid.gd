extends "res://addons/gut/test.gd"

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
	var retained: Dictionary = grid.projection
	var retained_node: Control = grid.cell_nodes[0]
	var invalid: Dictionary = _projection([_cell(0),_cell(1)])
	invalid.private_board_id = "hidden"
	assert_false(grid.present(invalid))
	assert_eq(grid.projection,retained)
	assert_same(grid.cell_nodes[0],retained_node)

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
	assert_eq(grid._mode_action(2),&"","Flag mode does not Flag a revealed number.")
	assert_eq(grid._mode_action(1),&"unflag")
	assert_true(grid.set_mode(&"drag"))
	assert_eq(grid._mode_action(0),&"")

func test_paired_pointer_release_and_keyboard_emit_once_with_revision() -> void:
	var grid: Control = _grid()
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(10,10)
	down.pressed = true
	grid._gui_input(down)
	var up: InputEventMouseButton = down.duplicate()
	up.pressed = false
	grid._gui_input(up)
	grid._gui_input(up)
	assert_signal_emitted_with_parameters(grid,"cell_action_requested",[&"reveal",0,7])
	assert_signal_emit_count(grid,"cell_action_requested",1)

func test_pointer_focuses_read_only_cell_and_button_pair_must_match() -> void:
	var grid: Control = _grid()
	var cells: Array = [_cell(0),_cell(1,{"face":"revealed","number":0,"actions":[],"pressable":false})]
	assert_true(grid.present(_projection(cells)))
	watch_signals(grid)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
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
	assert_signal_emit_count(grid,"cell_action_requested",0)

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
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var f: InputEventKey = InputEventKey.new()
	f.keycode = KEY_F
	f.pressed = true
	grid._gui_input(f)
	assert_eq(grid.mode,&"flag")
	assert_true(grid.set_mode(&"drag"))
	grid._gui_input(f)
	assert_eq(grid.mode,&"flag")
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
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
	assert_true(grid.present(_projection([_cell(0),_cell(1)])))
	watch_signals(grid)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	grid._gui_input(enter)
	grid._gui_input(enter)
	assert_signal_emit_count(grid,"cell_action_requested",1)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(10,10)
	down.pressed = true
	grid._gui_input(down)
	assert_eq(grid._held_index,-1)
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	grid._gui_input(space)
	assert_signal_emit_count(grid,"new_board_requested",0)
	enter.pressed = false
	grid._gui_input(enter)
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
