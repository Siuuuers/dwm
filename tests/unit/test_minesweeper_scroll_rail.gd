extends "res://addons/gut/test.gd"

const RAIL := preload("res://scripts/ui/minesweeper/MinesweeperScrollRail.gd")
const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")
const MINESWEEPER_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")


func _rail(vertical: bool = false) -> Control:
	var control: Control = RAIL.new()
	add_child_autofree(control)
	assert_true(control.configure(vertical,"en",MINESWEEPER_THEME.build("en",100,&"after_hours")))
	return control


func test_layout_rail_places_native_geometry_at_double_logical_scale() -> void:
	var geometry: Dictionary = LAYOUT.measure(16,8,Vector2i(200,160)).value
	var control: Control = _rail()
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,geometry.scroll.x,geometry.well.size.x,true))
	assert_eq(control.position,Vector2(geometry.horizontal.rect.position*2))
	assert_eq(control.size,Vector2(geometry.horizontal.rect.size*2))
	assert_eq(control._local_thumb(),Rect2(Vector2((geometry.horizontal.thumb.position-geometry.horizontal.rect.position)*2),Vector2(geometry.horizontal.thumb.size*2)))
	assert_eq(control.focus_mode,Control.FOCUS_ALL)


func test_invalid_or_zero_extent_geometry_is_atomic() -> void:
	var geometry: Dictionary = LAYOUT.measure(16,8,Vector2i(200,160)).value
	var control: Control = _rail()
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	var retained: Dictionary = control.rail
	assert_false(control.present({"rect":Rect2i(0,0,24,24),"thumb":Rect2i(0,0,24,24)},0,0,24,true))
	assert_false(control.present({"rect":geometry.horizontal.rect,"thumb":geometry.horizontal.thumb,"owner_id":"private"},geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	var wrong_thumb: Dictionary = geometry.horizontal.duplicate(true)
	var short_thumb: Rect2i = wrong_thumb.thumb
	short_thumb.size.x -= 1
	wrong_thumb.thumb = short_thumb
	assert_false(control.present(wrong_thumb,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	var wrong_cross: Dictionary = geometry.horizontal.duplicate(true)
	var wide_rect: Rect2i = wrong_cross.rect
	var wide_thumb: Rect2i = wrong_cross.thumb
	wide_rect.size.y = 25
	wide_thumb.size.y = 25
	wrong_cross.rect = wide_rect
	wrong_cross.thumb = wide_thumb
	assert_false(control.present(wrong_cross,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	assert_eq(control.rail,retained)


func test_thumb_drag_maps_native_integer_range_and_track_click_pages() -> void:
	var geometry: Dictionary = LAYOUT.measure(16,8,Vector2i(200,160)).value
	var control: Control = _rail()
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	watch_signals(control)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(10,20)
	down.pressed = true
	control._gui_input(down)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(106,20)
	control._gui_input(motion)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[105])
	var up: InputEventMouseButton = down.duplicate()
	up.position = motion.position
	up.pressed = false
	control._gui_input(up)
	assert_false(control._dragging)

	var track: InputEventMouseButton = InputEventMouseButton.new()
	track.button_index = MOUSE_BUTTON_LEFT
	track.position = Vector2(control.size.x-4,20)
	track.pressed = true
	control._gui_input(track)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[geometry.well.size.x])


func test_synchronous_thumb_refresh_preserves_original_drag_binding() -> void:
	var band := Vector2i(200,160)
	var geometry: Dictionary = LAYOUT.measure(16,8,band).value
	var control: Control = _rail()
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	var requested: Array[int] = []
	control.scroll_requested.connect(func(next_value: int) -> void:
		requested.append(next_value)
		var refreshed: Dictionary = LAYOUT.measure(16,8,band,false,Vector2i(next_value,0)).value
		assert_true(control.present(refreshed.horizontal,refreshed.maximum_scroll.x,next_value,refreshed.well.size.x,true))
	)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(10,20)
	down.pressed = true
	control._gui_input(down)
	var first: InputEventMouseMotion = InputEventMouseMotion.new()
	first.position = Vector2(58,20)
	control._gui_input(first)
	var second: InputEventMouseMotion = InputEventMouseMotion.new()
	second.position = Vector2(106,20)
	control._gui_input(second)
	assert_eq(requested,[53,105])
	assert_true(control._dragging)
	var release: InputEventMouseButton = down.duplicate()
	release.position = second.position
	release.pressed = false
	control._gui_input(release)
	assert_false(control._dragging)


func test_orientation_change_cancels_drag_and_ready_preserves_presented_focus_mode() -> void:
	var geometry: Dictionary = LAYOUT.measure(16,8,Vector2i(200,160)).value
	var control: Control = RAIL.new()
	assert_true(control.configure(false,"en",MINESWEEPER_THEME.build("en",100,&"after_hours")))
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	control._dragging = true
	assert_true(control.configure(true,"en",MINESWEEPER_THEME.build("en",100,&"after_hours")))
	assert_false(control._dragging)
	assert_true(control.configure(false,"en",MINESWEEPER_THEME.build("en",100,&"after_hours")))
	add_child_autofree(control)
	await get_tree().process_frame
	assert_eq(control.focus_mode,Control.FOCUS_ALL)


func test_keys_wheel_and_clamps_use_public_native_values() -> void:
	var geometry: Dictionary = LAYOUT.measure(8,16,Vector2i(200,160),false,Vector2i(0,100)).value
	var control: Control = _rail(true)
	assert_true(control.present(geometry.vertical,geometry.maximum_scroll.y,geometry.scroll.y,geometry.well.size.y,true))
	watch_signals(control)
	var down: InputEventKey = InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	control._gui_input(down)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[124])
	var page_down: InputEventKey = InputEventKey.new()
	page_down.keycode = KEY_PAGEDOWN
	page_down.pressed = true
	control._gui_input(page_down)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[236])
	var home: InputEventKey = InputEventKey.new()
	home.keycode = KEY_HOME
	home.pressed = true
	control._gui_input(home)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[0])
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	control._gui_input(wheel)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[76])
	var ignored_horizontal_wheel: InputEventMouseButton = InputEventMouseButton.new()
	ignored_horizontal_wheel.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	ignored_horizontal_wheel.pressed = true
	var emitted_before: int = get_signal_emit_count(control,"scroll_requested")
	control._gui_input(ignored_horizontal_wheel)
	assert_eq(get_signal_emit_count(control,"scroll_requested"),emitted_before)


func test_horizontal_wheel_uses_horizontal_buttons_only() -> void:
	var geometry: Dictionary = LAYOUT.measure(16,8,Vector2i(200,160)).value
	var control: Control = _rail()
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,0,geometry.well.size.x,true))
	watch_signals(control)
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	right.pressed = true
	control._gui_input(right)
	assert_signal_emitted_with_parameters(control,"scroll_requested",[24])
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	var emitted_before: int = get_signal_emit_count(control,"scroll_requested")
	control._gui_input(up)
	assert_eq(get_signal_emit_count(control,"scroll_requested"),emitted_before)


func test_inert_rail_has_no_focus_contacts_or_owner_metadata() -> void:
	var geometry: Dictionary = LAYOUT.measure(16,8,Vector2i(200,160)).value
	var control: Control = _rail()
	assert_true(control.present(geometry.horizontal,geometry.maximum_scroll.x,0,geometry.well.size.x,false))
	assert_eq(control.focus_mode,Control.FOCUS_NONE)
	assert_eq(control.accessibility_name,"Horizontal scroll")
	assert_eq(control.accessibility_description,"Position 0 of %d" % geometry.maximum_scroll.x)
	assert_eq(control.rail.keys(),["rect","thumb"])
	watch_signals(control)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(10,10)
	click.pressed = true
	control._gui_input(click)
	assert_signal_emit_count(control,"scroll_requested",0)
