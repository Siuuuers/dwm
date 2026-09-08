extends SceneTree
## GPU propagation proof for sixteen presentation tuples, plus two local-sheet views.
## The schema-valid reducer fixture is evidence only, not production gameplay integration.

const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const TUPLE_LOCALES := [["en",100,false],["zh-CN",125,false],["zh-HK",150,true]]

var _folder := ""
var _captures := 0

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/minesweeper_accessibility")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"evidence directory unavailable"):
		quit(1)
		return
	var public := _public_fixture()
	if public.is_empty():
		quit(1)
		return
	var tuple_index := 0
	for palette: StringName in [&"after_hours",&"midnight"]:
		for high_contrast: bool in [false,true]:
			for colour_preset: String in ["standard","protan","deutan","tritan"]:
				var locale_tuple: Array = TUPLE_LOCALES[tuple_index%TUPLE_LOCALES.size()]
				var locale: String = locale_tuple[0]
				var percent: int = locale_tuple[1]
				var large: bool = locale_tuple[2]
				var expected: Theme = THEME.build(locale,percent,palette,high_contrast,colour_preset)
				var viewport := SubViewport.new()
				viewport.size = Vector2i(864,720)
				viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				root.add_child(viewport)
				var background := ColorRect.new()
				background.color = Color("30343d")
				background.size = Vector2(viewport.size)
				background.mouse_filter = Control.MOUSE_FILTER_IGNORE
				viewport.add_child(background)
				var panel: Control = PANEL.new()
				viewport.add_child(panel)
				panel.position = Vector2(32,32)
				if not _check(expected != null and panel.configure(locale,percent,large,palette,high_contrast,colour_preset) and panel.present(public),"tuple configuration or public fixture rejected"):
					quit(1)
					return
				panel.dock.buttons.flag.pressed.emit()
				if not _check(panel.worksheet.vertical_rail != null and panel.worksheet.horizontal_rail != null,"Expert fixture must retain both scroll rails"):
					quit(1)
					return
				panel.worksheet.vertical_rail.grab_focus()
				var name := "%s-%s-%s-%s%d%s" % [palette,"hc" if high_contrast else "standard",colour_preset,locale,percent,"-large" if large else ""]
				if not await _capture(viewport,panel,expected,public,name,large,""):
					quit(1)
					return
				# Every tuple has a board capture; extra sheet captures retain that coverage.
				if tuple_index in [7,15]:
					var sheet_kind := "rules" if tuple_index == 7 else "assignments"
					panel.dock.buttons[sheet_kind].pressed.emit()
					var sheet: Control = panel.worksheet.information_sheet
					if not _check(sheet != null,"local information sheet failed to open"):
						quit(1)
						return
					if sheet.rail != null:
						sheet.set_scroll(32)
						sheet.rail.grab_focus()
					if sheet_kind == "assignments" and not _check(sheet.get_scroll() > 0,"Assignments capture did not exercise scrolling"):
						quit(1)
						return
					if not await _capture(viewport,panel,expected,public,name+"-"+sheet_kind,large,sheet_kind):
						quit(1)
						return
				root.remove_child(viewport)
				viewport.queue_free()
				await process_frame
				tuple_index += 1
	print("ACCESSIBILITY_RENDER_VERIFIED tuples=",tuple_index," captures=",_captures," board_captures=16 sheet_captures=2 fixture=public_reducer_projection production_gameplay_acceptance=false")
	quit(0)

func _capture(viewport: SubViewport, panel: Control, expected: Theme, public: Dictionary,
		name: String, large: bool, sheet_kind: String) -> bool:
	for frame in 4: await RenderingServer.frame_post_draw
	if not _check(panel.public_view == public and panel.worksheet.grid.projection == public.board,"tuple or sheet changed public board facts"): return false
	if not _check(panel.size == Vector2(800,656) and panel.worksheet.position.y == panel.register.size.y and panel.dock.position.y+panel.dock.size.y == 656,"tuple changed fixed body geometry"): return false
	if not _check(panel.worksheet.grid.mode == &"flag" and panel.dock.buttons.flag.selected and panel.dock.buttons.new_board.disabled,"mode commitment or disabled replacement changed"): return false
	if not _check(panel.worksheet.grid.cell_nodes[0].size == Vector2.ONE*(64 if large else 48),"tuple changed cell target geometry"): return false
	var pixels: Image = viewport.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(),"empty GPU capture"): return false
	var file := _folder.path_join(name+".png")
	# Preserve failed captures as well as successful evidence.
	if not _check(pixels.save_png(file) == OK,"cannot write GPU capture"): return false
	var metric: Control = panel.register.metrics.rounds
	if not _pixel(pixels,metric,Vector2(4,4),_role(expected,&"controlled_face"),"register substrate"): return false
	var selected: Button = panel.dock.buttons.flag
	var selected_face: Rect2 = selected._face_rect()
	if not _pixel(pixels,selected,selected_face.position+Vector2(3,3),_role(expected,&"selected_plane"),"Selected mode substrate"): return false
	if not _pixel(pixels,selected,Vector2(selected_face.end.x-3,selected_face.position.y+4),_role(expected,&"selected_ink"),"Selected filing seam ink"): return false
	var disabled: Button = panel.dock.buttons.new_board
	if not _pixel(pixels,disabled,Vector2(disabled.size.x/2,disabled.size.y-3),_role(expected,&"dark_registration"),"disabled action bar"): return false
	var register_origin := Vector2i(panel.register.global_position)
	for x in range(register_origin.x,register_origin.x+int(panel.register.size.x)):
		if not _check(_same_color(pixels.get_pixel(x,register_origin.y+int(panel.register.size.y)-1),_role(expected,&"dark_registration")),"tuple interrupted register separator"): return false
	if sheet_kind.is_empty():
		var grid: Control = panel.worksheet.grid
		if not _check(grid.projection.cells[0].number > 0 and grid.projection.cells[1].mark == "flag" and grid.projection.cells[2].face == "covered","public cell morphology fixture was lost"): return false
		if not _pixel(pixels,grid.cell_nodes[0],Vector2(10,10),_role(expected,&"paper"),"revealed cell substrate"): return false
		if not _pixel(pixels,grid.cell_nodes[2],Vector2(10,10),_role(expected,&"controlled_face"),"covered cell substrate"): return false
		var aperture: Rect2 = grid.cell_nodes[1]._aperture()
		if not _pixel(pixels,grid.cell_nodes[1],aperture.position+Vector2(11 if large else 9,8),_role(expected,&"dark_mark"),"Flag mast ink"): return false
		var corner: Rect2i = panel.worksheet.geometry.corner
		if not _pixel(pixels,panel.worksheet,Vector2(corner.get_center()*2),_role(expected,&"habitat"),"empty worksheet corner substrate"): return false
		if not _rail_pixels(pixels,panel.worksheet.vertical_rail,expected,false): return false
	else:
		var sheet: Control = panel.worksheet.information_sheet
		if not _check(sheet != null and not panel.worksheet.well.visible,"sheet did not replace the worksheet"): return false
		if not _pixel(pixels,sheet,Vector2(4,4),_role(expected,&"paper"),"information sheet substrate"): return false
		if not _pixel(pixels,sheet.return_button,Vector2.ONE*(sheet.return_button._inset+3),_role(expected,&"controlled_face"),"sheet Return face"): return false
		for button: Button in panel.dock.buttons.values():
			if not _check(button.disabled and button.focus_mode == Control.FOCUS_NONE,"sheet left dock input enabled"): return false
		if sheet.rail != null and not _rail_pixels(pixels,sheet.rail,expected,true): return false
	_captures += 1
	print("ACCESSIBILITY_CAPTURE ",file," revision=",public.board.revision," mode=flag sheet=",sheet_kind if not sheet_kind.is_empty() else "none"," native_body=400x328 pixel_propagation=verified")
	return true

func _rail_pixels(pixels: Image, rail: Control, expected: Theme, paper: bool) -> bool:
	if not _check(rail.has_focus(),"capture lacks the requested focused rail"): return false
	if not _pixel(pixels,rail,Vector2(2,20),_role(expected,&"paper_focus_outer" if paper else &"dark_focus_outer"),"focused rail outer ink"): return false
	var thumb: Rect2 = rail._local_thumb()
	return _pixel(pixels,rail,thumb.get_center(),_role(expected,&"paper_scroll_thumb" if paper else &"dark_scroll_thumb"),"scroll thumb substrate")

func _pixel(pixels: Image, control: Control, local: Vector2, expected: Color, label: String) -> bool:
	var point := Vector2i(control.get_global_transform_with_canvas()*local)
	if not _check(Rect2i(Vector2i.ZERO,pixels.get_size()).has_point(point),label+" probe escaped viewport"): return false
	return _check(_same_color(pixels.get_pixelv(point),expected),label+" tuple did not reach rendered pixel at "+str(point))

func _same_color(actual: Color, expected: Color) -> bool:
	var tolerance := 1.1/255.0
	return absf(actual.r-expected.r) <= tolerance and absf(actual.g-expected.g) <= tolerance and absf(actual.b-expected.b) <= tolerance and absf(actual.a-expected.a) <= tolerance

func _role(expected: Theme, role: StringName) -> Color:
	return expected.get_color(role,&"Minesweeper")

func _check(condition: bool, message: String) -> bool:
	if not condition: push_error("ACCESSIBILITY_RENDER_FAILED: "+message)
	return condition

func _public_fixture() -> Dictionary:
	var mines: Array[int] = []
	for index in range(1,100): mines.append(index)
	var layout := {"schema_version":1,"width":22,"height":22,"mine_indices":mines,"mine_count":99}
	var first: Dictionary = REDUCER.first_reveal(layout,0)
	if not _check(first.get("ok",false),"reducer first-Reveal fixture failed"): return {}
	var identity := {"run_id":"evidence-run","branch_id":"evidence-branch","desktop_timeline_generation":0,"causal_day_instance":"evidence-day","app_round_ordinal":1}
	var spec := {"schema_version":1,"board_kind":"desktop","board_token":"evidence-token","board_token_receipt_id":"evidence-receipt",
		"difficulty_id":"expert","width":22,"height":22,"base_mine_count":99,"pressure":0,"penalty_points_today":0,
		"raw_extra_mines":0,"requested_mine_count":99,"capability_ids":["first_cell_safe"],
		"placement_stream_id":"minesweeper_placement_v1","placement_nonce":"evidence-p","placement_nonce_receipt_id":"evidence-pr",
		"debug_stream_id":"minesweeper_debug_v1","debug_nonce":"evidence-d","debug_nonce_receipt_id":"evidence-dr",
		"explosion_stream_id":"minesweeper_explosion_v1","explosion_nonce":"evidence-e","explosion_nonce_receipt_id":"evidence-er",
		"generator_version":"dwm_generator_v1","verifier_version":"visible_deduction_v1"}
	var state := STATE.new()
	var prepared: Dictionary = state.prepare_first_reveal({"transaction_id":"evidence-first","identity":identity,"expected_revision":0,
		"cell_index":0,"spec":spec,"request_fingerprint":"evidence-first"},{"layout":layout,"board":first.value.board},{"checkpoint_id":"evidence-checkpoint"})
	if not _check(prepared.get("ok",false) and state.commit(prepared.value.candidate).get("ok",false),"fixture state first-Reveal commit failed"): return {}
	var flagged: Dictionary = REDUCER.set_flag(first.value.board,1,true,"evidence-flag")
	if not _check(flagged.get("ok",false),"fixture Flag reducer failed"): return {}
	var command: Dictionary = state.prepare_board_command({"transaction_id":"evidence-flag","identity":identity,"expected_revision":1,
		"kind":&"set_flag","request_fingerprint":"evidence-flag"},flagged.value.board)
	if not _check(command.get("ok",false) and state.commit(command.value.candidate).get("ok",false),"fixture Flag state commit failed"): return {}
	var projected: Dictionary = QUERY.desktop(state.capture(),"expert")
	if not _check(projected.get("ok",false),"fixture public projection failed"): return {}
	return {"board":projected.value,"register":{"difficulty":"expert","rounds":1,"mine_estimate":projected.value.mine_estimate,
		"foresight":null,"no_flag":"lost","custody":false,"difficulty_enabled":[]},
		"assignments":[false,false,false,false,false,false,false,false,false],
		"actions":["reveal","flag","drag","assignments","rules"],"settled":false}
