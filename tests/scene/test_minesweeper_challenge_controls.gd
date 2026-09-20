extends GutTest
## The canonical challenge host shares view controls without issuing gameplay commands.

const SCENE := preload("res://scenes/dating/DatingScene.tscn")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

class PublicPort extends RefCounted:
	var view: Dictionary
	var commands: Array[Dictionary] = []
	func begin(_command: Dictionary) -> Dictionary:
		return {"ok":true}
	func complete(_command: Dictionary) -> Dictionary:
		return {"ok":true}
	func pull_physical(_command: Dictionary) -> Dictionary:
		return {"ok":true,"value":view.duplicate(true)}
	func dispatch_physical(_command: Dictionary, action: String, index: int, revision: int) -> Dictionary:
		commands.append({"action":action,"index":index,"revision":revision})
		return {"ok":true}

var _port: PublicPort
var _scene: Control

func before_each() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	_port = PublicPort.new()
	_port.view = {"host":"canonical_solo","phase":"challenge",
		"board":QUERY.desktop(STATE.new().capture(),"expert",true).value,
		"special_mine_visible":false,"special_mine_enabled":false}
	_scene = SCENE.instantiate()
	assert_true(_scene.configure_presentation(_port,{"physical_token":"test.challenge",
		"context":{"kind":"solo","day":3,"participants":["sylvia"]}}).ok)
	viewport.add_child(_scene)
	_scene.set_process(false)
	await get_tree().process_frame

func test_flag_toggle_drag_and_rules_preserve_challenge_board_and_navigation() -> void:
	var sheet: Control = _scene.worksheet
	var original: Dictionary = sheet.grid.projection.duplicate(true)
	var cells: Array = sheet.grid.cell_nodes.duplicate()
	var flag: Button = _scene.find_child("Flag",true,false)
	var drag: Button = _scene.find_child("Drag",true,false)
	var rules: Button = _scene.find_child("Rules",true,false)
	assert_null(_scene.find_child("Board",true,false))
	assert_not_null(flag)
	assert_not_null(drag)
	assert_null(_scene.find_child("Reveal",true,false))
	assert_eq(sheet.grid.mode,&"reveal")
	assert_false(flag.button_pressed)
	flag.pressed.emit()
	assert_eq(sheet.grid.mode,&"flag")
	assert_true(flag.button_pressed)
	flag.pressed.emit()
	assert_eq(sheet.grid.mode,&"reveal")
	assert_false(flag.button_pressed)
	drag.pressed.emit()
	assert_eq(sheet.grid.mode,&"drag")
	sheet.grid._set_focused(200)
	sheet.set_scroll(Vector2i(80,140))
	var retained_scroll: Vector2i = sheet.get_scroll()
	rules.pressed.emit()
	assert_not_null(sheet.information_sheet)
	assert_true(sheet.well.is_visible_in_tree())
	assert_true(sheet.grid.is_visible_in_tree())
	assert_false(rules.disabled)
	assert_true(flag.disabled)
	assert_true(drag.disabled)
	sheet.information_sheet.return_button.pressed.emit()
	assert_null(sheet.information_sheet)
	assert_true(rules.has_focus())
	assert_eq(sheet.grid.mode,&"drag")
	assert_eq(sheet.grid.focused_index,200)
	assert_eq(sheet.get_scroll(),retained_scroll)
	assert_eq(sheet.grid.projection,original)
	for index in cells.size(): assert_same(sheet.grid.cell_nodes[index],cells[index])
	assert_true(_port.commands.is_empty())

func test_challenge_size_and_fit_controls_live_in_footer_and_preserve_progress() -> void:
	var sheet: Control = _scene.worksheet
	var footer: Control = _scene.find_child("ChallengeViewFooter",true,false)
	assert_not_null(footer)
	var original: Dictionary = sheet.grid.projection.duplicate(true)
	for control: Control in sheet.zoom_controls:
		assert_true(footer.is_ancestor_of(control))
	var picklist: OptionButton = sheet.zoom_controls[0]
	assert_eq(picklist.item_count,27)
	picklist.item_selected.emit(picklist.get_item_index(48))
	assert_eq(sheet.cell_size,48)
	sheet.zoom_controls[1].pressed.emit()
	assert_true(sheet.always_fit)
	assert_true(Rect2(Vector2.ZERO,sheet.well.size).encloses(Rect2(sheet.grid.position,sheet.grid.size*sheet.grid.scale)))
	assert_eq(sheet.grid.projection,original)
	assert_true(_port.commands.is_empty())


func test_challenge_rules_overlay_blocks_native_cell_contacts_and_return_restores_play() -> void:
	var worksheet: Control = _scene.worksheet
	var grid: Control = worksheet.grid
	var rules: Button = _scene.find_child("Rules", true, false)
	var cell: Control = grid.cell_nodes[0]
	var point: Vector2 = cell.get_global_transform_with_canvas() * (cell.size / 2.0)
	var original: Dictionary = grid.projection.duplicate(true)
	rules.pressed.emit()
	assert_not_null(worksheet.information_sheet)
	assert_true(worksheet.well.is_visible_in_tree())
	assert_eq(grid.process_mode, Node.PROCESS_MODE_DISABLED)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	_scene.get_viewport().push_input(click, true)
	click.pressed = false
	_scene.get_viewport().push_input(click, true)
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.position = point
	touch.pressed = true
	_scene.get_viewport().push_input(touch, true)
	touch.pressed = false
	_scene.get_viewport().push_input(touch, true)
	assert_false(grid.has_held_touch())
	assert_true(_port.commands.is_empty())
	assert_eq(grid.projection, original)
	worksheet.information_sheet.return_button.pressed.emit()
	assert_null(worksheet.information_sheet)
	assert_true(rules.has_focus())
	click.pressed = true
	_scene.get_viewport().push_input(click, true)
	click.pressed = false
	_scene.get_viewport().push_input(click, true)
	assert_eq(_port.commands, [{"action":"reveal", "index":0, "revision":original.revision}])
