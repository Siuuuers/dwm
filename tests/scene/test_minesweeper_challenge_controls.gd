extends GutTest
## The canonical challenge host shares view controls without issuing gameplay commands.

const SCENE := preload("res://scenes/dating/DatingScene.tscn")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")

class PublicPort extends RefCounted:
	var view: Dictionary
	var observer: Dictionary = {}
	var commands: Array[Dictionary] = []
	func begin(_command: Dictionary) -> Dictionary:
		return {"ok":true}
	func complete(_command: Dictionary) -> Dictionary:
		return {"ok":true}
	func pull_physical(_command: Dictionary) -> Dictionary:
		return {"ok":true,"value":view.duplicate(true)}
	func pull_observer(_command: Dictionary) -> Dictionary:
		return {"ok":true,"value":observer.duplicate(true)}
	func dispatch_physical(_command: Dictionary, action: String, index: int, revision: int) -> Dictionary:
		commands.append({"action":action,"index":index,"revision":revision})
		return {"ok":true}

class ViewProfile extends RefCounted:
	var font_style := "pixel"
	func get_preference(path: StringName, fallback: Variant) -> Variant:
		return font_style if path == &"preferences.accessibility.font_style" else fallback

var _port: PublicPort
var _scene: Control
var _previous_dating_width := 480.0

func before_each() -> void:
	_previous_dating_width = ART_VIEW._dating_width
	ART_VIEW._dating_width = 480.0
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
	await _settle_layout()

func after_each() -> void:
	ART_VIEW._dating_width = _previous_dating_width

func _settle_layout() -> void:
	for frame in 4: await get_tree().process_frame

func _paint_portrait_fixture() -> void:
	var image := Image.create(64,96,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.3,0.5,0.7,0.6))
	var texture := ImageTexture.create_from_image(image)
	var portraits: Array[Texture2D] = [texture,texture]
	_scene._scene_art.configure_textures(texture,portraits,null,_scene._percent,true,true)

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



func test_resized_challenge_keeps_board_rules_and_full_size_copy_inside_right_pane() -> void:
	var original: Dictionary = _scene.worksheet.grid.projection.duplicate(true)
	var profile := ViewProfile.new()
	for font_style: String in ["pixel","readable"]:
		profile.font_style = font_style
		for locale: String in ["en","zh-CN","zh-HK","ja","ko"]:
			for percent: int in [100,150]:
				assert_true(_scene.configure_presentation_services(null,locale,percent,true,
					&"after_hours",false,"standard",profile).ok)
				_paint_portrait_fixture()
				for width: float in [320.0,640.0]:
					_scene._scene_art.set_portrait_width(width)
					await _settle_layout()
					var right: Rect2 = _scene._scene_art.get_right_rect()
					var host: Control = _scene._challenge_content
					var sheet: Control = _scene.worksheet
					assert_eq(right,Rect2(width,0,1280-width,720))
					assert_eq(host.position,right.position)
					assert_eq(host.size,right.size)
					assert_gte(sheet.get_global_rect().position.x,right.position.x)
					assert_lte(sheet.get_global_rect().end.x,right.end.x)
					assert_lte(_scene._challenge_panel.get_combined_minimum_size().x,host.size.x)
					assert_same(_scene._challenge_panel.theme.default_font,sheet.theme.default_font)
					assert_eq(_scene._challenge_panel.theme.default_font_size,sheet.theme.default_font_size)
					assert_same(sheet.theme.default_font,TYPOGRAPHY.font(locale,percent,font_style))
					assert_eq(sheet.theme.default_font_size,TYPOGRAPHY.font_size(locale,percent,20,font_style))
					assert_eq(sheet.grid.projection,original)
					var rules: Button = _scene.find_child("Rules",true,false)
					rules.pressed.emit()
					assert_not_null(sheet.information_sheet,"Rules available at %s/%s/%d/%d" % [font_style,locale,percent,width])
					if sheet.information_sheet != null:
						assert_lte(sheet.information_sheet.size.x,sheet.size.x)
						for row: Control in sheet.information_sheet.rows:
							assert_lte(row.size.y,sheet.information_sheet.body.size.y)
						sheet.information_sheet.return_button.pressed.emit()
						_paint_portrait_fixture()
	assert_true(_port.commands.is_empty())
	assert_true(_scene.configure_presentation_services(null,"en",150,true,
		&"after_hours",false,"standard",profile).ok)
	_port.observer = {"scope":"priscilla", "counterpart":false, "captured":false,
		"checkpoint_pending":false, "text":"I remembered the words that we had left unfinished beside the window. ".repeat(3)}
	_scene._physical_view.phase = "pre_challenge"
	_scene._refresh_challenge()
	_scene._build_observer()
	_paint_portrait_fixture()
	_scene._scene_art.set_portrait_width(640.0)
	await _settle_layout()
	var line: Button = _scene.find_child("PreviousSceneLine",true,false)
	assert_eq(line.text,_port.observer.text)
	assert_eq(line.autowrap_mode,TextServer.AUTOWRAP_WORD_SMART)
	assert_gt(line.size.y,44.0,"Long observer copy wraps at full font size.")
	assert_lte(_scene._challenge_panel.get_combined_minimum_size().x,640.0)
	assert_lte(line.get_global_rect().end.x,1280.0)
	assert_lte(_scene._observer_action.get_global_rect().end.x,1280.0)
	assert_true(_port.commands.is_empty())

func test_divider_drag_keeps_pending_contacts_out_of_challenge_and_preserves_document_gate() -> void:
	_paint_portrait_fixture()
	_scene._scene_art.set_portrait_width(480.0)
	await _settle_layout()
	var sheet: Control = _scene.worksheet
	var grid: Control = sheet.grid
	var original: Dictionary = grid.projection.duplicate(true)
	var art: Control = _scene._scene_art
	var handle: Control = art.get_split_handle()
	var origin: Vector2 = handle.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = origin
	click.pressed = true
	_scene.get_viewport().push_input(click,true)
	assert_true(art.is_split_dragging())
	assert_true(_scene._split_dragging)
	assert_false(grid.is_view_input_admitted())
	var motion := InputEventMouseMotion.new()
	motion.position = origin+Vector2(96,0)
	motion.relative = Vector2(96,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_scene.get_viewport().push_input(motion,true)
	assert_eq(art.get_portrait_width(),480.0,"Portrait and board geometry commit on release.")
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.position = grid.cell_nodes[0].get_global_rect().get_center()
	touch.pressed = true
	_scene.get_viewport().push_input(touch,true)
	touch.pressed = false
	_scene.get_viewport().push_input(touch,true)
	click.position = motion.position
	click.pressed = false
	_scene.get_viewport().push_input(click,true)
	await _settle_layout()
	assert_false(art.is_split_dragging())
	assert_false(_scene._split_dragging)
	assert_eq(art.get_portrait_width(),576.0)
	assert_true(grid.is_view_input_admitted())
	assert_eq(grid.projection,original)
	assert_true(_port.commands.is_empty())
	var rules: Button = _scene.find_child("Rules",true,false)
	rules.pressed.emit()
	assert_not_null(sheet.information_sheet)
	_scene._on_challenge_split_drag_changed(true)
	_scene._on_challenge_split_drag_changed(false)
	assert_not_null(sheet.information_sheet)
	assert_eq(grid.process_mode,Node.PROCESS_MODE_DISABLED)
	assert_true(_scene.find_child("Flag",true,false).disabled)
	assert_true(_port.commands.is_empty())
