extends GutTest
## Real SubViewport routes across the grid, blank well, toolbar, and host focus boundary.

const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const INPUT_FIXTURE := preload("res://tests/support/MinesweeperInputFixture.gd")

class ViewProfile extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var writes: Array[Dictionary] = []
	func get_preference(_path: StringName, fallback: Variant) -> Variant:
		return fallback
	func set_preferences(values: Dictionary) -> Dictionary:
		writes.append(values.duplicate(true))
		return {"ok": true}

var _surface: SubViewport
var _input_fixture: RefCounted


func before_each() -> void:
	_input_fixture = INPUT_FIXTURE.new()
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.handle_input_locally = true
	add_child(_surface)


func after_each() -> void:
	if is_instance_valid(_surface): _surface.free()
	_input_fixture.restore_map()


func _worksheet(tier: String = "beginner") -> Control:
	var worksheet: Control = WORKSHEET.new()
	_surface.add_child(worksheet)
	worksheet.position = Vector2(80, 40)
	assert_true(_input_fixture.bind_grid(worksheet.grid, _surface))
	assert_true(worksheet.configure())
	assert_true(worksheet.present(QUERY.desktop(STATE.new().capture(), tier, true).value))
	return worksheet


func _panel(tier: String = "expert") -> Control:
	var panel: Control = PANEL.new()
	_surface.add_child(panel)
	panel.position = Vector2(80, 20)
	assert_true(_input_fixture.bind_grid(panel.worksheet.grid, _surface))
	var view := {"board": QUERY.desktop(STATE.new().capture(), tier, true).value,
		"register": {"difficulty": tier, "rounds": 2, "mine_estimate": null,
			"foresight": null, "no_flag": "intact", "custody": false, "difficulty_enabled": []},
		"assignments": [true, false, false, false, false, false, false, false, false],
		"actions": ["reveal", "flag", "drag", "assignments", "rules"], "settled": false}
	assert_true(panel.configure())
	assert_true(panel.present(view))
	return panel


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	_surface.push_input(event, true)


func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	_surface.push_input(event, true)


func _wheel(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.ctrl_pressed = true
	event.pressed = true
	_surface.push_input(event, true)


func _tab() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = true
	_surface.push_input(event, true)
	event.pressed = false
	_surface.push_input(event, true)


func test_second_touch_in_blank_well_cancels_cell_action_and_finishes_one_pinch_write() -> void:
	var worksheet := _worksheet()
	var profile := ViewProfile.new()
	assert_true(worksheet.bind_view_preferences(profile, "app_beginner"))
	watch_signals(worksheet)
	var cell: Control = worksheet.grid.cell_nodes[7]
	var first: Vector2 = worksheet.position + worksheet.grid.position + (cell.position + cell.size / 2.0) * worksheet.grid.scale
	var second: Vector2 = worksheet.position + Vector2(700, 100)
	assert_true(Rect2(worksheet.position, worksheet.well.size).has_point(second))
	assert_false(Rect2(worksheet.position + worksheet.grid.position,
		worksheet.grid.size * worksheet.grid.scale).has_point(second))
	_touch(1, first, true)
	assert_true(worksheet.grid.has_held_touch())
	_touch(2, second, true)
	worksheet.grid._process(0.6)
	assert_signal_emit_count(worksheet, "cell_action_requested", 0)
	_drag(2, second + Vector2(40, 0), Vector2(40, 0))
	assert_gt(worksheet.cell_size, 36)
	_touch(2, second + Vector2(40, 0), false)
	_touch(1, first, false)
	assert_signal_emit_count(worksheet, "cell_action_requested", 0)
	assert_eq(worksheet.grid.projection.revision, 0)
	assert_eq(profile.writes.size(), 1, "A completed pinch persists one preference transaction.")
	assert_eq(profile.writes[0][&"preferences.display.minesweeper_app_beginner_cell_size"], worksheet.cell_size)


func test_ctrl_wheel_over_grid_and_blank_well_each_zoom_once_with_vertical_anchor() -> void:
	var worksheet := _worksheet()
	assert_true(worksheet.step_zoom(10))
	assert_eq(worksheet.cell_size, 56)
	worksheet.set_scroll(Vector2i(0, 2))
	var cell: Control = worksheet.grid.cell_nodes[0]
	var over_grid: Vector2 = worksheet.position + worksheet.grid.position + (cell.position + cell.size / 2.0) * worksheet.grid.scale
	var blank: Vector2 = worksheet.position + Vector2(20, 120)
	for point: Vector2 in [over_grid, blank]:
		var before: Dictionary = worksheet.geometry.duplicate(true)
		var anchor_y: float = (point.y - worksheet.position.y) / 2.0
		var board_y: float = (anchor_y - before.mount.position.y) / before.scale
		var before_size: int = worksheet.cell_size
		_wheel(point)
		assert_eq(worksheet.cell_size, before_size + 2, "One wheel notch must cause one step.")
		var after: Dictionary = worksheet.geometry
		assert_true(absf(after.mount.position.y + board_y * after.scale - anchor_y) <= 1.0,
			"The native point under the pointer remains anchored where scroll bounds permit.")
	assert_eq(worksheet.cell_size, 60)
	assert_eq(worksheet.grid.projection.revision, 0)


func test_forced_cell_publication_reveals_it_without_stealing_external_focus() -> void:
	var worksheet := _worksheet()
	assert_true(worksheet.step_zoom(12))
	assert_eq(worksheet.cell_size, 60)
	var source := Button.new()
	_surface.add_child(source)
	source.position = Vector2(950, 40)
	source.grab_focus()
	assert_true(source.has_focus())
	var forced: Dictionary = worksheet.grid.projection.duplicate(true)
	forced.revision += 1
	forced.cells[63].bracketed = true
	worksheet.set_scroll(Vector2i.ZERO)
	assert_true(worksheet.present(forced))
	assert_eq(worksheet.grid.focused_index, 63)
	assert_true(_focused_cell_visible(worksheet))
	assert_true(source.has_focus(), "Publishing a forced cell must preserve the external source focus.")
	worksheet.set_scroll(Vector2i.ZERO)
	assert_false(_focused_cell_visible(worksheet), "The far-edge cell can be panned out of view.")
	assert_true(worksheet.present(forced))
	assert_true(_focused_cell_visible(worksheet), "Republishing the bracketed initial cell restores visibility.")
	assert_true(source.has_focus())


func test_fit_toggle_rebuilds_rail_tab_order_and_exits_to_host() -> void:
	var panel := _panel()
	var before := Button.new()
	var after := Button.new()
	_surface.add_child(before)
	_surface.add_child(after)
	before.position = Vector2(0, 0)
	after.position = Vector2(950, 0)
	assert_true(panel.connect_host_focus(before, after))
	assert_not_null(panel.worksheet.vertical_rail)
	assert_not_null(panel.worksheet.horizontal_rail)
	assert_true(panel.worksheet.set_always_fit(true))
	assert_null(panel.worksheet.vertical_rail)
	assert_null(panel.worksheet.horizontal_rail)
	panel.worksheet.grid.grab_focus()
	for target: Control in panel.worksheet.zoom_controls + [panel.dock.buttons.reveal,
		panel.dock.buttons.flag, panel.dock.buttons.drag, panel.dock.buttons.assignments,
		panel.dock.buttons.rules, after]:
		_tab()
		assert_same(_surface.gui_get_focus_owner(), target)
	assert_true(panel.worksheet.set_always_fit(false))
	assert_not_null(panel.worksheet.vertical_rail)
	assert_not_null(panel.worksheet.horizontal_rail)
	panel.worksheet.grid.grab_focus()
	for target: Control in [panel.worksheet.vertical_rail, panel.worksheet.horizontal_rail] \
			+ panel.worksheet.zoom_controls + [panel.dock.buttons.reveal,
		panel.dock.buttons.flag, panel.dock.buttons.drag, panel.dock.buttons.assignments,
		panel.dock.buttons.rules, after]:
		_tab()
		assert_same(_surface.gui_get_focus_owner(), target)


func _focused_cell_visible(worksheet: Control) -> bool:
	var cell: Control = worksheet.grid.cell_nodes[worksheet.grid.focused_index]
	var rendered := Rect2(worksheet.grid.position + cell.position * worksheet.grid.scale,
		cell.size * worksheet.grid.scale)
	return Rect2(Vector2.ZERO, worksheet.well.size).encloses(rendered)
