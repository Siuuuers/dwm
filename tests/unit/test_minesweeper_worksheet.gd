extends "res://addons/gut/test.gd"

const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

func _projection(difficulty: String = "beginner") -> Dictionary:
	return QUERY.desktop(STATE.new().capture(), difficulty, true).value

func _worksheet(difficulty: String = "beginner", large: bool = false) -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	var worksheet: Control = WORKSHEET.new()
	viewport.add_child(worksheet)
	assert_true(worksheet.configure("desktop_app","en",100,large))
	assert_true(worksheet.present(_projection(difficulty)))
	return worksheet

func test_fit_axes_have_no_rail_nodes_or_targets_and_large_keeps_only_vertical() -> void:
	var ordinary := _worksheet()
	assert_eq(ordinary.well.size,Vector2(752,444))
	assert_eq(ordinary.grid.position,Vector2(182,28))
	assert_null(ordinary.horizontal_rail)
	assert_null(ordinary.vertical_rail)
	assert_true(ordinary.well.clip_contents)
	var large := _worksheet("beginner",true)
	assert_eq(large.well.size,Vector2(736,400))
	assert_eq(large.grid.position,Vector2(110,0))
	assert_null(large.horizontal_rail)
	assert_not_null(large.vertical_rail)
	assert_eq(large.vertical_rail.position,Vector2(736,0))
	assert_eq(large.vertical_rail.size,Vector2(64,400))

func test_scroll_clamps_integer_geometry_and_never_changes_public_board() -> void:
	var worksheet := _worksheet("expert")
	var original: Dictionary = worksheet.grid.projection.duplicate(true)
	worksheet.set_scroll(Vector2i(9999,9999))
	assert_eq(worksheet.get_scroll(),Vector2i(154,308))
	assert_eq(worksheet.grid.position,Vector2(-308,-616))
	assert_eq(worksheet.grid.projection,original)
	assert_eq(worksheet.horizontal_rail.value,154)
	assert_eq(worksheet.vertical_rail.value,308)
	assert_eq(worksheet.vertical_rail.rail.thumb.end.y,worksheet.geometry.well.end.y)

func test_focus_navigation_and_return_reveal_the_complete_semantic_cell() -> void:
	var worksheet := _worksheet("expert")
	worksheet.grid.grab_focus()
	for move in 21: worksheet.grid._move_focus(Vector2i.DOWN)
	for move in 21: worksheet.grid._move_focus(Vector2i.RIGHT)
	assert_eq(worksheet.grid.focused_index,483)
	var focused: Control = worksheet.grid.cell_nodes[483]
	assert_true(Rect2(Vector2.ZERO,worksheet.well.size).encloses(Rect2(worksheet.grid.position+focused.position,focused.size)))
	worksheet.vertical_rail.grab_focus()
	worksheet.set_scroll(Vector2i.ZERO)
	worksheet.grid.grab_focus()
	assert_eq(worksheet.grid.focused_index,483)
	assert_true(Rect2(Vector2.ZERO,worksheet.well.size).encloses(Rect2(worksheet.grid.position+focused.position,focused.size)),"Returning from another control restores the retained cell in view.")

func test_real_wheel_route_scrolls_once_through_child_and_parent() -> void:
	var worksheet := _worksheet("expert")
	var viewport: SubViewport = worksheet.get_viewport()
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(100,100)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	viewport.push_input(wheel,true)
	await get_tree().process_frame
	assert_eq(worksheet.get_scroll(),Vector2i(0,24),"Child scroll handling must not bubble into a second parent step.")
	assert_eq(worksheet.grid.projection.revision,0)

func test_fractional_pointer_motion_accumulates_without_fractional_board_placement() -> void:
	var worksheet := _worksheet("expert")
	worksheet._pan(Vector2(0,-1))
	assert_eq(worksheet.get_scroll(),Vector2i.ZERO)
	worksheet._pan(Vector2(0,-1))
	assert_eq(worksheet.get_scroll(),Vector2i(0,1))
	assert_eq(worksheet.grid.position,Vector2(0,-2))
	worksheet._set_panning(true)
	assert_true(worksheet._seam.visible)
	worksheet._set_panning(false)
	assert_false(worksheet._seam.visible)

func test_actual_drag_route_moves_viewport_without_issuing_a_cell_command() -> void:
	var worksheet := _worksheet("expert")
	assert_true(worksheet.set_mode(&"drag"))
	watch_signals(worksheet)
	var viewport: SubViewport = worksheet.get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(200,150)
	down.pressed = true
	viewport.push_input(down,true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(200,138)
	motion.relative = Vector2(0,-12)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion,true)
	await get_tree().process_frame
	assert_eq(worksheet.get_scroll(),Vector2i(0,6))
	assert_true(worksheet._seam.visible)
	down.position = motion.position
	down.pressed = false
	viewport.push_input(down,true)
	await get_tree().process_frame
	assert_false(worksheet._seam.visible)
	assert_signal_emit_count(worksheet,"cell_action_requested",0)

func test_touch_drag_uses_real_gui_routing_and_never_activates_on_release() -> void:
	var worksheet := _worksheet("expert")
	watch_signals(worksheet)
	var viewport: SubViewport = worksheet.get_viewport()
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = Vector2(200,150)
	touch.pressed = true
	viewport.push_input(touch,true)
	assert_eq(worksheet.grid._touch_id,2)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(200,138)
	drag.relative = Vector2(0,-12)
	viewport.push_input(drag,true)
	assert_eq(worksheet.get_scroll(),Vector2i(0,6))
	assert_true(worksheet._seam.visible)
	touch.position = drag.position
	touch.pressed = false
	viewport.push_input(touch,true)
	assert_false(worksheet._seam.visible)
	assert_signal_emit_count(worksheet,"cell_action_requested",0)
	assert_eq(worksheet.grid.projection.revision,0)

func test_real_thumb_drag_preserves_its_origin_through_synchronous_viewport_updates() -> void:
	var worksheet := _worksheet("expert")
	var viewport: SubViewport = worksheet.get_viewport()
	var rail: Control = worksheet.vertical_rail
	var thumb: Rect2 = rail._local_thumb()
	var start: Vector2 = rail.position+thumb.get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = start
	down.pressed = true
	viewport.push_input(down,true)
	assert_true(rail._dragging)
	var motion := InputEventMouseMotion.new()
	motion.position = start+Vector2(0,120)
	motion.relative = Vector2(0,120)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion,true)
	assert_eq(worksheet.get_scroll().y,roundi(60.0*308/130))
	assert_true(rail._dragging,"Presentation refresh must retain the physical drag.")
	motion.position = start+Vector2(0,200)
	motion.relative = Vector2(0,80)
	viewport.push_input(motion,true)
	assert_eq(worksheet.get_scroll().y,roundi(100.0*308/130),"The second motion still maps from the original thumb/value.")
	down.position = motion.position
	down.pressed = false
	viewport.push_input(down,true)
	assert_false(rail._dragging)

func test_custody_keeps_truth_and_scroll_but_removes_all_input() -> void:
	var worksheet := _worksheet("expert")
	worksheet.set_scroll(Vector2i(4,9))
	var inert: Dictionary = worksheet.grid.projection.duplicate(true)
	inert.custody = true
	for cell: Dictionary in inert.cells:
		cell.inspectable = false
		cell.pressable = false
		cell.actions = []
	assert_true(worksheet.present(inert))
	assert_eq(worksheet.get_scroll(),Vector2i(4,9))
	assert_false(worksheet.vertical_rail.interactive)
	assert_eq(worksheet.vertical_rail.focus_mode,Control.FOCUS_NONE)
	assert_eq(worksheet.grid.focus_mode,Control.FOCUS_NONE)
	assert_true(worksheet._seam.visible)
	worksheet.set_scroll(Vector2i(50,50))
	worksheet._pan(Vector2(10,10))
	assert_eq(worksheet.get_scroll(),Vector2i(4,9))
	assert_eq(worksheet.grid.projection,inert)

func test_configuration_and_invalid_projection_preserve_the_current_view_atomically() -> void:
	var worksheet := _worksheet("expert")
	worksheet.set_scroll(Vector2i(4,9))
	var retained: Dictionary = worksheet.geometry.duplicate(true)
	assert_false(worksheet.configure("unknown"))
	assert_false(worksheet.configure("desktop_app","en",100,false,&"after_hours",Vector2i(25,25)))
	assert_false(worksheet.present({"private_board":true}))
	assert_eq(worksheet.geometry,retained)
	assert_eq(worksheet.get_scroll(),Vector2i(4,9))

func test_reconfiguring_to_a_fit_board_removes_existing_axis_nodes() -> void:
	var worksheet := _worksheet("expert")
	var prior_vertical: Control = worksheet.vertical_rail
	var prior_horizontal: Control = worksheet.horizontal_rail
	assert_true(worksheet.present(_projection()))
	assert_null(worksheet.vertical_rail)
	assert_null(worksheet.horizontal_rail)
	assert_null(prior_vertical.get_parent())
	assert_null(prior_horizontal.get_parent())
	assert_eq(worksheet.get_scroll(),Vector2i.ZERO)

func test_configure_and_present_before_tree_mount_keep_focus_and_geometry() -> void:
	var worksheet: Control = WORKSHEET.new()
	assert_true(worksheet.configure())
	assert_true(worksheet.present(_projection()))
	add_child_autofree(worksheet)
	assert_eq(worksheet.grid.focus_mode,Control.FOCUS_ALL)
	assert_eq(worksheet.grid.position,Vector2(182,28))
