extends SceneTree
## GPU evidence from public fixtures, not production gameplay acceptance.
## Atlas columns: resting, real pointer hover, held pointer press, selected + focus.

const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const WORDS := ["beginner","intermediate","expert","reveal","assignments"]
const CONTACTS := ["resting","hover","pressed","selected_focus"]
var _folder := ""
var _records: Array[Dictionary] = []
var _defects := 0
var _panel_captures := 0
var _contact_atlases := 0

class TextReference extends Control:
	var source: Button
	var mask := false
	func _draw() -> void:
		if source == null: return
		var face: Color = Color.BLACK if mask else source.get_theme_color(&"selected_plane" if source.selected else &"controlled_face",&"Minesweeper")
		var ink: Color = Color.WHITE if mask else source.get_theme_color(&"selected_ink" if source.selected else &"primary_dark_copy",&"Minesweeper")
		draw_rect(Rect2(Vector2.ZERO,size),face)
		var paragraph: TextParagraph = source._paragraph
		var top: float = floorf((size.y-source._text_height)/4.0)*2.0
		for line in paragraph.get_line_count():
			var x: float = floorf((size.x-paragraph.get_line_width(line))/4.0)*2.0
			paragraph.draw_line(get_canvas_item(),Vector2(x,top+source._baselines[line]-paragraph.get_line_ascent(line)),line,ink)

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/minesweeper_typography")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"cannot create evidence directory"):
		quit(1)
		return
	var public := _public_fixture()
	if public.is_empty():
		quit(1)
		return
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				var name := "%s%d-%s" % [locale,percent,"large" if large else "ordinary"]
				var next_theme: Theme = THEME.build(locale,percent,&"after_hours")
				if not await _panel_capture(public,next_theme,locale,percent,large,name) or not await _contact_atlas(next_theme,locale,percent,large,name):
					quit(1)
					return
	var report := FileAccess.open(_folder.path_join("contact-measurements.json"),FileAccess.WRITE)
	if not _check(report != null,"cannot write contact report"):
		quit(1)
		return
	report.store_string(JSON.stringify({"scope":"public fixture, no production gameplay claim","atlas_columns":CONTACTS,"atlas_rows":WORDS,
		"method":"Actual pointer motion/down/up. Compare rendered glyph-mask pixels with marker-free text drawn using the same paragraph, position, ink and substrate. Includes antialiased edge pixels.",
		"panel_captures":_panel_captures,"contact_atlases":_contact_atlases,"sample_count":_records.size(),"defect_samples":_defects,"samples":_records},"\t")+"\n")
	report.close()
	print("TYPOGRAPHY_RENDER_COMPLETE panel_captures=",_panel_captures," contact_atlases=",_contact_atlases," samples=",_records.size()," text_intersection_samples=",_defects," evidence=",_folder)
	quit(0 if _defects == 0 else 1)

func _panel_capture(public: Dictionary, next_theme: Theme, locale: String, percent: int, large: bool, name: String) -> bool:
	var viewport := _viewport(Vector2i(864,720))
	var panel: Control = PANEL.new()
	viewport.add_child(panel)
	panel.position = Vector2(32,32)
	if not _check(panel.configure(locale,percent,large,&"after_hours") and panel.present(public),"panel rejected public fixture"): return false
	panel.dock.buttons.flag.pressed.emit()
	panel.dock.buttons.flag.grab_focus()
	await _frames()
	if not _check(panel.public_view == public and panel.worksheet.grid.mode == &"flag" and panel.dock.buttons.flag.selected,"presentation changed facts or mode"): return false
	if not _check(panel.size == Vector2(800,656) and panel.dock.position.y+panel.dock.size.y == 656 and panel.worksheet.position.y == panel.register.size.y,"fixed body geometry changed"): return false
	if not _check(panel.dock.buttons.new_board.disabled and panel.worksheet.grid.cell_nodes[0].size == Vector2.ONE*(64 if large else 48),"disabled action or cell target changed"): return false
	for button: Button in panel.dock.buttons.values():
		if not _check(not button.public_copy.contains("\u00ad") and button.accessibility_name == button.public_copy,"discretionary characters leaked into semantic copy"): return false
	if not _check(panel.dock.get_theme_default_font_size() == next_theme.default_font_size,"full requested font was lost"): return false
	var pixels: Image = viewport.get_texture().get_image()
	if not _check(pixels.save_png(_folder.path_join(name+"-panel.png")) == OK,"cannot save panel capture"): return false
	_panel_captures += 1
	viewport.queue_free()
	await process_frame
	return true

func _contact_atlas(next_theme: Theme, locale: String, percent: int, large: bool, name: String) -> bool:
	var viewport := _viewport(Vector2i(672,224))
	# Image rows are actual buttons at native size; empty padding separates samples.
	var atlas := Image.create(800,880,false,Image.FORMAT_RGBA8)
	atlas.fill(Color("30343d"))
	var row_y := 48
	var localized: Dictionary = COPY.get_copy(locale)
	for semantic_key: String in WORDS:
		var word: String = localized[semantic_key]
		var button: Button = BUTTON.new()
		var width := 160 if semantic_key == "assignments" else 96
		if not _check(button.configure(word,next_theme,large,width),"action shaping rejected "+word): return false
		viewport.add_child(button)
		button.position = Vector2(16,16)
		button.present_state(true,false)
		var reference := TextReference.new()
		reference.source = button
		reference.position = Vector2(240,16)
		reference.size = button.size
		reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport.add_child(reference)
		var mask := TextReference.new()
		mask.source = button
		mask.mask = true
		mask.position = Vector2(464,16)
		mask.size = button.size
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport.add_child(mask)
		if not _check(button.public_copy == word and button.accessibility_name == word and button.get_theme_default_font_size() == next_theme.default_font_size and button.size.x == width,"semantic copy, font or fixed bay changed"): return false
		var line_widths: Array[float] = []
		for line in button._paragraph.get_line_count():
			var line_width: float = button._paragraph.get_line_width(line)
			line_widths.append(line_width)
			if not _check(line_width <= width-button._inset*2-8,"line exceeded content aperture"): return false
		for contact in 4:
			_motion(viewport,Vector2(660,210))
			button.release_focus()
			button.present_state(true,contact == 3)
			if contact in [1,2]: _motion(viewport,button.position+button.size/2)
			if contact == 2: _mouse_button(viewport,button.position+button.size/2,true)
			if contact == 3: button.grab_focus()
			reference.queue_redraw()
			mask.queue_redraw()
			await _frames()
			if not _check(button.is_hovered() == (contact in [1,2]) and button.is_pressed() == (contact == 2) and button.has_focus() == (contact in [2,3]),"native pointer/focus state failed for "+word+" "+CONTACTS[contact]): return false
			var pixels: Image = viewport.get_texture().get_image()
			var changed := 0
			var glyph_pixels := 0
			var first_changed := Vector2i(-1,-1)
			for y in int(button.size.y):
				for x in int(button.size.x):
					var local := Vector2i(x,y)
					if pixels.get_pixelv(Vector2i(mask.position)+local).r <= 0.02: continue
					glyph_pixels += 1
					if not _same_color(pixels.get_pixelv(Vector2i(button.position)+local),pixels.get_pixelv(Vector2i(reference.position)+local)):
						changed += 1
						if first_changed.x < 0: first_changed = local
			if not _check(glyph_pixels > 0,"empty reference glyph mask"): return false
			var record := {"locale":locale,"semantic_key":semantic_key,"word":word,"percent":percent,"large_targets":large,"contact":CONTACTS[contact],"width":width,"height":button.size.y,
				"font_size":next_theme.default_font_size,"line_widths":line_widths,"glyph_pixels":glyph_pixels,"changed_glyph_pixels":changed,"first_changed_local":str(first_changed)}
			_records.append(record)
			print("TYPOGRAPHY_CONTACT ",JSON.stringify(record))
			if changed > 0: _defects += 1
			atlas.blit_rect(pixels,Rect2i(Vector2i(button.position),Vector2i(button.size)),Vector2i(24+contact*192,row_y))
			if contact == 2: _mouse_button(viewport,button.position+button.size/2,false)
		row_y += int(button.size.y)+24
		button.queue_free()
		reference.queue_free()
		mask.queue_free()
		await process_frame
	atlas.crop(800,row_y)
	# Render the header at the same full font size, then copy into the atlas.
	viewport.size = Vector2i(800,64)
	for contact in 4:
		var label := Label.new()
		label.text = ["Resting","Hover","Pressed","Selected"][contact]
		label.theme = next_theme
		label.position = Vector2(24+contact*192,4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport.add_child(label)
	await _frames()
	atlas.blit_rect(viewport.get_texture().get_image(),Rect2i(0,0,800,44),Vector2i.ZERO)
	if not _check(atlas.save_png(_folder.path_join(name+"-contacts.png")) == OK,"cannot save contact atlas"): return false
	_contact_atlases += 1
	viewport.queue_free()
	await process_frame
	return true

func _viewport(dimensions: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("30343d")
	background.size = Vector2(864,880)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	return viewport

func _frames() -> void:
	for frame in 3: await RenderingServer.frame_post_draw

func _motion(viewport: SubViewport, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	viewport.push_input(event,true)

func _mouse_button(viewport: SubViewport, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	viewport.push_input(event,true)

func _same_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r-expected.r) <= 1.1/255 and absf(actual.g-expected.g) <= 1.1/255 and absf(actual.b-expected.b) <= 1.1/255

func _check(condition: bool, message: String) -> bool:
	if not condition: push_error("TYPOGRAPHY_RENDER_FAILED: "+message)
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
		"actions":["reveal","flag","drag","assignments","rules"]}
