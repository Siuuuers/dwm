extends SceneTree
## Actual viewport proof. Canonical sample is a public covered-shell fixture, not an owner integration.
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/minesweeper_viewport")
	DirAccess.make_dir_recursive_absolute(folder)
	var samples := [
		["beginner-en100", "desktop_app", "beginner", "en", 100, false, &"after_hours", false],
		["beginner-hk150-large", "desktop_app", "beginner", "zh-HK", 150, true, &"midnight", true],
		["expert-en150-last-cell", "desktop_app", "expert", "en", 150, false, &"after_hours", true],
		["canonical-cn125", "canonical_pair", "", "zh-CN", 125, false, &"midnight", false],
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
		var worksheet: Control = WORKSHEET.new()
		viewport.add_child(worksheet)
		worksheet.position = Vector2(64,100)
		var public: Dictionary
		if sample[1] == "desktop_app": public = QUERY.desktop(STATE.new().capture(),sample[2],true).value
		else: public = _canonical_fixture()
		if not worksheet.configure(sample[1],sample[3],sample[4],sample[5],sample[6]) or not worksheet.present(public):
			quit(1)
			return
		if sample[7]:
			worksheet.grid.grab_focus()
			for step in public.height - 1: worksheet.grid._move_focus(Vector2i.DOWN)
			for step in public.width - 1: worksheet.grid._move_focus(Vector2i.RIGHT)
		for frame in 5: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		if pixels == null or pixels.is_empty():
			quit(1)
			return
		var filename: String = folder.path_join(sample[0]+".png")
		if pixels.save_png(filename) != OK or not _verify_empty_allocations(pixels,worksheet):
			quit(1)
			return
		print("WORKSHEET_CAPTURE ",filename," scroll=",worksheet.get_scroll()," focus=",worksheet.grid.focused_index)
		root.remove_child(viewport)
		viewport.queue_free()
	print("WORKSHEET_GUTTERS_VERIFIED samples=4 fit-axis-targets=absent corner=inert clipping=contained")
	quit(0)

func _canonical_fixture() -> Dictionary:
	var cells: Array[Dictionary] = []
	for index in 18 * 18:
		cells.append({"index":index,"face":"covered","mark":"none","number":0,"bracketed":false,
			"inspectable":true,"pressable":true,"actions":["reveal"]})
	return {"width":18,"height":18,"revision":0,"mine_estimate":null,"terminal":false,"custody":false,"cells":cells}

func _verify_empty_allocations(pixels: Image, worksheet: Control) -> bool:
	var g: Dictionary = worksheet.geometry
	var origin := Vector2i(worksheet.position)
	var habitat: Color = worksheet.get_theme_color(&"habitat",&"Minesweeper")
	var regions: Array[Rect2i] = [g.corner]
	if g.vertical == null: regions.append(Rect2i(g.well.size.x,0,g.target,g.well.size.y))
	if g.horizontal == null: regions.append(Rect2i(0,g.well.size.y,g.well.size.x,g.target))
	for native: Rect2i in regions:
		if not _solid(pixels,Rect2i(origin+native.position*2,native.size*2),habitat): return false
	var size := Vector2i(worksheet.size)
	return _solid(pixels,Rect2i(origin+Vector2i(size.x,0),Vector2i(8,size.y)),Color("30343d")) \
		and _solid(pixels,Rect2i(origin+Vector2i(0,size.y),Vector2i(size.x,8)),Color("30343d"))

func _solid(pixels: Image, rect: Rect2i, expected: Color) -> bool:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if not pixels.get_pixel(x,y).is_equal_approx(expected):
				push_error("Unexpected pixels outside the allocated content/scroll area at %s" % Vector2i(x,y))
				return false
	return true
