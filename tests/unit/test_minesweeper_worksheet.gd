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

func test_rules_replace_only_worksheet_and_return_restores_mode_cell_scroll_and_source() -> void:
	var worksheet := _worksheet("expert")
	assert_true(worksheet.set_mode(&"flag"))
	worksheet.grid._set_focused(200)
	worksheet.set_scroll(Vector2i(80,140))
	worksheet.vertical_rail.grab_focus()
	var source: Control = worksheet.vertical_rail
	var before: Dictionary = worksheet.grid.projection.duplicate(true)
	assert_true(worksheet.open_rules())
	assert_false(worksheet.well.visible)
	assert_false(source.visible)
	assert_eq(worksheet.grid.process_mode,Node.PROCESS_MODE_DISABLED)
	assert_true(worksheet.information_sheet.rows[0].has_focus())
	assert_false(worksheet.set_mode(&"drag"))
	worksheet.set_scroll(Vector2i.ZERO)
	assert_eq(worksheet.get_scroll(),Vector2i(80,140))
	worksheet.information_sheet.return_button.pressed.emit()
	assert_null(worksheet.information_sheet)
	assert_true(worksheet.well.visible)
	assert_true(source.has_focus())
	assert_eq(worksheet.grid.mode,&"flag")
	assert_eq(worksheet.grid.focused_index,200)
	assert_eq(worksheet.get_scroll(),Vector2i(80,140))
	assert_eq(worksheet.grid.projection,before)

func test_sheet_tab_traps_focus_and_escape_restores_grid_without_command() -> void:
	var worksheet := _worksheet()
	worksheet.grid.grab_focus()
	watch_signals(worksheet)
	assert_true(worksheet.open_rules())
	var viewport: SubViewport = worksheet.get_viewport()
	var sheet: Control = worksheet.information_sheet
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	for index in 5:
		viewport.push_input(tab,true)
		await get_tree().process_frame
	assert_true(sheet.rows[0].has_focus())
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	viewport.push_input(confirm,true)
	assert_signal_emit_count(worksheet,"cell_action_requested",0)
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true
	viewport.push_input(back,true)
	await get_tree().process_frame
	assert_null(worksheet.information_sheet)
	assert_true(worksheet.grid.has_focus())
	assert_signal_emit_count(worksheet,"cell_action_requested",0)

func test_missing_assignment_truth_does_not_open_or_disturb_grid() -> void:
	var worksheet := _worksheet()
	worksheet.grid.grab_focus()
	assert_false(worksheet.open_assignments([]))
	assert_null(worksheet.information_sheet)
	assert_true(worksheet.well.visible)
	assert_true(worksheet.grid.has_focus())
	assert_true(worksheet.open_assignments([false,false,false,false,false,false,false,false,true]))
	assert_eq(worksheet.information_sheet.rows[8].accessibility_name,"Complete all three tiers — Claimed")

func test_sheet_return_preserves_manual_pan_even_when_source_grid_cell_is_offscreen() -> void:
	var worksheet := _worksheet("expert")
	worksheet.grid.grab_focus()
	worksheet.set_scroll(Vector2i(100,200))
	assert_eq(worksheet.grid.focused_index,0)
	assert_true(worksheet.open_rules())
	worksheet.close_information()
	assert_true(worksheet.grid.has_focus())
	assert_eq(worksheet.get_scroll(),Vector2i(100,200),"Sheet Return restores the exact retained pan before any new navigation.")
	worksheet.grid._move_focus(Vector2i.RIGHT)
	assert_eq(worksheet.get_scroll(),Vector2i(25,1),"A later navigation still reveals its complete target.")

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

func test_information_closing_reenables_external_source_before_exact_focus_restoration() -> void:
	var worksheet := _worksheet("expert")
	var source := Button.new()
	source.position = Vector2(900,20)
	source.size = Vector2(128,48)
	worksheet.get_viewport().add_child(source)
	source.grab_focus()
	worksheet.set_scroll(Vector2i(100,200))
	assert_true(worksheet.open_rules(source))
	var sheet: Control = worksheet.information_sheet
	source.disabled = true
	source.focus_mode = Control.FOCUS_NONE
	watch_signals(worksheet)
	var order: Array[String] = []
	worksheet.information_closing.connect(func() -> void:
		order.append("closing")
		assert_null(worksheet.information_sheet)
		assert_null(sheet.get_parent())
		assert_false(source.has_focus())
		source.disabled = false
		source.focus_mode = Control.FOCUS_ALL
		worksheet.close_information()
	)
	worksheet.information_closed.connect(func() -> void:
		order.append("closed")
		assert_true(source.has_focus())
	)
	worksheet.close_information()
	worksheet.close_information()
	assert_eq(order,["closing","closed"])
	assert_signal_emit_count(worksheet,"information_closing",1)
	assert_signal_emit_count(worksheet,"information_closed",1)
	assert_true(source.has_focus())
	assert_eq(worksheet.get_scroll(),Vector2i(100,200))

func test_interaction_block_preserves_public_facts_scroll_and_open_sheet_return() -> void:
	var worksheet := _worksheet("expert")
	assert_true(worksheet.set_mode(&"flag"))
	worksheet.grid.grab_focus()
	worksheet.set_scroll(Vector2i(100,200))
	assert_true(worksheet.open_rules())
	var sheet: Control = worksheet.information_sheet
	var retained: Dictionary = worksheet.grid.projection.duplicate(true)
	var retained_scroll: Vector2i = worksheet.get_scroll()
	worksheet.set_interaction_blocked(true)
	assert_same(worksheet.information_sheet,sheet)
	assert_true(sheet.rows[0].has_focus())
	assert_false(worksheet.vertical_rail.interactive)
	assert_false(worksheet.horizontal_rail.interactive)
	assert_eq(worksheet.grid.focus_mode,Control.FOCUS_NONE)
	sheet.return_button.pressed.emit()
	assert_null(worksheet.information_sheet)
	assert_eq(worksheet.grid.projection,retained)
	assert_false(worksheet.grid.has_focus())
	assert_false(worksheet.open_rules())
	assert_false(worksheet.set_mode(&"drag"))
	worksheet.set_scroll(Vector2i.ZERO)
	worksheet._pan(Vector2(0,-20))
	assert_eq(worksheet.get_scroll(),retained_scroll)
	assert_true(worksheet.present(retained))
	assert_false(worksheet.vertical_rail.interactive)
	assert_eq(worksheet.grid.focus_mode,Control.FOCUS_NONE)
	worksheet.set_interaction_blocked(false)
	assert_true(worksheet.vertical_rail.interactive)
	assert_true(worksheet.horizontal_rail.interactive)
	assert_eq(worksheet.grid.focus_mode,Control.FOCUS_ALL)
	assert_eq(worksheet.grid.mode,&"flag")
	assert_eq(worksheet.grid.projection,retained)
	assert_eq(worksheet.get_scroll(),retained_scroll)
	assert_true(worksheet.open_rules())
