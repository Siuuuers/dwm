extends SceneTree
## Composition fixtures for public status formatting and native band proof, not runtime owner acceptance.

const REGISTER := preload("res://scripts/ui/minesweeper/MinesweeperRegister.gd")
const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	var folder := ProjectSettings.globalize_path("user://evidence/minesweeper_chrome")
	DirAccess.make_dir_recursive_absolute(folder)
	var samples := [
		["desktop-en100","desktop_app","en",100,false,&"after_hours"],
		["desktop-en150-large","desktop_app","en",150,true,&"midnight"],
		["desktop-cn125","desktop_app","zh-CN",125,false,&"midnight"],
		["desktop-hk150-large","desktop_app","zh-HK",150,true,&"after_hours"],
		["canonical-en125","canonical_pair","en",125,false,&"after_hours"],
		["canonical-cn150-large","canonical_solo","zh-CN",150,true,&"midnight"],
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
		var register: Control = REGISTER.new()
		var dock: Control = DOCK.new()
		var worksheet: Control = WORKSHEET.new()
		viewport.add_child(register)
		viewport.add_child(dock)
		viewport.add_child(worksheet)
		var desktop: bool = sample[1] == "desktop_app"
		var view := {"mine_estimate":9 if desktop else 35,"foresight":125,"no_flag":"lost","custody":false}
		if desktop:
			view.merge({"difficulty":"beginner","rounds":-3,"difficulty_enabled":["beginner","intermediate","expert"]})
		if not register.configure(sample[1],sample[2],sample[3],sample[4],sample[5]) or not register.present(view) \
				or not dock.configure(sample[1],sample[2],sample[3],sample[4],sample[5]):
			quit(1)
			return
		var native_band := Vector2i(400 if desktop else 480,328-int((register.size.y+dock.size.y)/2))
		var public: Dictionary = _public_fixture(8 if desktop else 18,9 if desktop else 35)
		if not worksheet.configure(sample[1],sample[2],sample[3],sample[4],sample[5],native_band) or not worksheet.present(public):
			quit(1)
			return
		var actions: Array = ["reveal","flag","drag","assignments","rules"] if desktop else ["reveal","flag","drag","rules","pause"]
		dock.present(&"reveal",actions)
		register.position = Vector2(64,32)
		worksheet.position = register.position+Vector2(0,register.size.y)
		dock.position = worksheet.position+Vector2(0,worksheet.size.y)
		dock.buttons.flag.grab_focus()
		for frame in 4: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		var file: String = folder.path_join(sample[0]+".png")
		if pixels.save_png(file) != OK:
			quit(1)
			return
		var separator_y := int(register.position.y+register.size.y)-1
		for x in range(int(register.position.x),int(register.position.x+register.size.x)):
			if not pixels.get_pixel(x,separator_y).is_equal_approx(register.theme.get_color(&"dark_registration",&"Minesweeper")):
				push_error("Register band separator is interrupted at %s" % Vector2i(x,separator_y))
				quit(1)
				return
		if desktop:
			var disabled_button: Button = dock.buttons.new_board
			var gate := Vector2i(dock.position+disabled_button.position+Vector2(disabled_button.size.x/2,disabled_button.size.y-3))
			if not pixels.get_pixelv(gate).is_equal_approx(dock.theme.get_color(&"dark_registration",&"Minesweeper")):
				push_error("Disabled New Board has no visible blocked action edge")
				quit(1)
				return
		if not desktop:
			var blank := Rect2i(Vector2i(register.position),Vector2i(560,int(register.size.y)-2))
			for y in range(blank.position.y,blank.end.y):
				for x in range(blank.position.x,blank.end.x):
					if not pixels.get_pixel(x,y).is_equal_approx(register.theme.get_color(&"habitat",&"Minesweeper")):
						push_error("Canonical blank register contains painted field at %s" % Vector2i(x,y))
						quit(1)
						return
		print("CHROME_CAPTURE ",file," native_bands=",Vector3i(int(register.size.y/2),native_band.y,int(dock.size.y/2))," total=328")
		root.remove_child(viewport)
		viewport.queue_free()
	print("CHROME_RENDER_VERIFIED samples=6 canonical-blank=empty formatting-fixtures-not-owner-acceptance")
	quit(0)

func _public_fixture(width: int, estimate: int) -> Dictionary:
	var cells: Array[Dictionary] = []
	for index in width*width:
		cells.append({"index":index,"face":"covered","mark":"none","number":0,"bracketed":false,"inspectable":true,"pressable":true,"actions":["reveal","flag"]})
	cells[0].face = "revealed"
	cells[0].number = 1
	cells[0].actions = ["chord"]
	cells[1].mark = "flag"
	cells[1].actions = ["unflag"]
	return {"width":width,"height":width,"revision":8,"mine_estimate":estimate,"terminal":false,"custody":false,"cells":cells}
