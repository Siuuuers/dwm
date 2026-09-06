extends SceneTree
## Real font/canvas proof. Assignment receipts below are explicit fixture state in a detached real owner.

const SHEET := preload("res://scripts/ui/minesweeper/MinesweeperInformationSheet.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperAssignmentsQuery.gd")
const STATE := preload("res://autoload/GameState.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/minesweeper_sheets")
	DirAccess.make_dir_recursive_absolute(folder)
	var state := STATE.new()
	state.reset_game()
	state.check_and_claim_minesweeper_task_rewards({"task_ids":["complete_beginner","complete_intermediate","complete_expert"]})
	var claimed: Array = QUERY.from_sources(state,CATALOG.new()).value
	state.free()
	var samples := [
		["rules-en100","desktop_app","en",100,false,&"after_hours","rules",0],
		["rules-cn100","desktop_app","zh-CN",100,false,&"midnight","rules",0],
		["rules-hk100-large","desktop_app","zh-HK",100,true,&"after_hours","rules",0],
		["assignments-en150-last","desktop_app","en",150,false,&"midnight","assignments",8],
		["assignments-cn125-middle","desktop_app","zh-CN",125,false,&"after_hours","assignments",4],
		["assignments-hk150-large-last","desktop_app","zh-HK",150,true,&"midnight","assignments",8],
		["rules-canonical-en150","canonical_pair","en",150,false,&"midnight","rules",0],
	]
	for sample: Array in samples:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280,720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color("30343d")
		background.size = viewport.size
		viewport.add_child(background)
		var sheet: Control = SHEET.new()
		viewport.add_child(sheet)
		sheet.position = Vector2(64,100)
		if not sheet.configure(sample[1],sample[2],sample[3],sample[4],sample[5]):
			quit(1)
			return
		var accepted: bool = sheet.present_rules() if sample[6] == "rules" else sheet.present_assignments(claimed)
		if not accepted:
			quit(1)
			return
		sheet.rows[sample[7]].grab_focus()
		for frame in 4: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		var file: String = folder.path_join(sample[0]+".png")
		if pixels.save_png(file) != OK:
			quit(1)
			return
		var apertures: Array[Rect2i] = []
		var body_rect := Rect2i(Vector2i(sheet.position+sheet.body.position),Vector2i(sheet.body.size))
		for row: Control in sheet.rows:
			var row_origin := Vector2i(sheet.position+sheet.body.position+sheet.document.position+row.position)
			var copy_rect := Rect2i(row_origin+Vector2i(12,12),Vector2i(row.size)-Vector2i(24,24))
			apertures.append(copy_rect.intersection(body_rect))
			var silent_theme := row.theme.duplicate() as Theme
			silent_theme.set_color(&"primary_paper_copy",&"Minesweeper",row.theme.get_color(&"paper",&"Minesweeper"))
			row.theme = silent_theme
			row.queue_redraw()
		for frame in 3: await RenderingServer.frame_post_draw
		var silent: Image = viewport.get_texture().get_image()
		for y in pixels.get_height():
			for x in pixels.get_width():
				if pixels.get_pixel(x,y).is_equal_approx(silent.get_pixel(x,y)): continue
				var admitted := false
				for aperture: Rect2i in apertures:
					if aperture.has_point(Vector2i(x,y)):
						admitted = true
						break
				if not admitted:
					push_error("Sheet row ink escapes copy aperture: %s at %s" % [sample[0],Vector2i(x,y)])
					quit(1)
					return
		print("SHEET_CAPTURE ",file," rows=",sheet.rows.size()," scroll=",sheet.get_scroll()," row_ink=contained")
		root.remove_child(viewport)
		viewport.queue_free()
	print("SHEET_RENDER_VERIFIED samples=7 licensed-font-size=unchanged copy-apertures=contained")
	quit(0)
