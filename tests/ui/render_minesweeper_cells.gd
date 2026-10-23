extends SceneTree
## Deterministic cell atlas and raster-bound proof. Requires a real GPU display driver.

const CELL := preload("res://scripts/ui/minesweeper/MinesweeperCell.gd")
const THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const LOCALES := ["en","zh-CN","zh-HK"]
const PALETTES := [&"after_hours",&"midnight"]
const PRESETS := [100,125,150]
const STATES := [
	["covered",{}], ["flag",{"mark":"flag"}], ["bracketed",{"bracketed":true}],
	["flag+\nbracket",{"mark":"flag","bracketed":true}], ["blank",{"face":"revealed","pressable":false}],
	["1",{"face":"revealed","number":1}], ["2",{"face":"revealed","number":2}],
	["3",{"face":"revealed","number":3}], ["4",{"face":"revealed","number":4}],
	["5",{"face":"revealed","number":5}], ["6",{"face":"revealed","number":6}],
	["7",{"face":"revealed","number":7}], ["8",{"face":"revealed","number":8}],
	["mine",{"face":"revealed","mark":"mine","pressable":false}],
	["exploded",{"face":"revealed","mark":"exploded","pressable":false}],
	["correct",{"mark":"correct_flag","pressable":false}],
	["incorrect",{"mark":"incorrect_flag","pressable":false}],
	["marked\nmine",{"face":"revealed","mark":"marked_mine"}], ["marked\nflag",{"mark":"marked_flag"}],
	["focus",{"contact":"focus"}], ["hover",{"contact":"hover"}], ["press",{"contact":"press"}],
]
const ATLAS_SIZE := Vector2i(1712,640)
const PITCH_X := 68
const PITCH_Y := 96
const ORIGIN := Vector2i(200,64)

func _initialize() -> void:
	_render_all.call_deferred()

func _render_all() -> void:
	var evidence := ProjectSettings.globalize_path("user://evidence/minesweeper_cells")
	if DirAccess.make_dir_recursive_absolute(evidence) != OK:
		push_error("Could not create Minesweeper cell evidence directory")
		quit(1)
		return
	for locale: String in LOCALES:
		for palette: StringName in PALETTES:
			var viewport := SubViewport.new()
			viewport.size = ATLAS_SIZE
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			viewport.transparent_bg = false
			root.add_child(viewport)
			var background := ColorRect.new()
			background.size = ATLAS_SIZE
			background.color = Color("30343d")
			viewport.add_child(background)
			for column in STATES.size():
				var heading := Label.new()
				heading.text = STATES[column][0]
				heading.position = Vector2(ORIGIN.x+column*PITCH_X,0)
				heading.size = Vector2(PITCH_X,60)
				heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				heading.add_theme_font_size_override("font_size",10)
				background.add_child(heading)
			var proof_rows: Array[Dictionary] = []
			var row := 0
			for percent: int in PRESETS:
				for large: bool in [false,true]:
					var label := Label.new()
					label.text = "%s\n%d%% %s\n%s" % [locale,percent,"Large" if large else "Ordinary",palette]
					label.position = Vector2(4,ORIGIN.y+row*PITCH_Y)
					label.size = Vector2(192,64)
					label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					label.add_theme_font_size_override("font_size",10)
					background.add_child(label)
					var row_cells: Array[Control] = []
					for column in STATES.size():
						var state: Array = STATES[column]
						var cell: Control = CELL.new()
						cell.position = Vector2(ORIGIN.x+column*PITCH_X,ORIGIN.y+row*PITCH_Y)
						background.add_child(cell)
						if not cell.configure(locale,percent,large,palette) or not cell.present(_public(state[1],column)):
							push_error("Cell fixture refused %s %s %s" % [locale,palette,state[0]])
							quit(1)
							return
						match state[1].get("contact",""):
							"focus": cell.set_contact(true,false,false)
							"hover": cell.set_contact(false,true,false)
							"press": cell.set_contact(false,true,true)
						row_cells.append(cell)
					proof_rows.append({"cells":row_cells,"large":large,"percent":percent})
					row += 1
			for frame in 5: await RenderingServer.frame_post_draw
			var pixels: Image = viewport.get_texture().get_image()
			if pixels == null or pixels.is_empty():
				quit(1)
				return
			var filename := "%s/%s-%s.png" % [evidence,locale.replace("-","_"),palette]
			if pixels.save_png(filename) != OK:
				push_error("Could not save %s" % filename)
				quit(1)
				return
			print("CELL_ATLAS ",filename," ",pixels.get_size())
			if not _verify_numerals(pixels,proof_rows,palette):
				quit(1)
				return
			root.remove_child(viewport)
			viewport.queue_free()
	print("NUMERAL_BOUNDS_VERIFIED locales=3 presets=3 sizes=2 palettes=2 numerals=8")
	quit(0)

func _public(overrides: Dictionary, index: int) -> Dictionary:
	var value := {"index":index,"face":"covered","mark":"none","number":0,"bracketed":false,"inspectable":true,"pressable":true,"actions":[]}
	for key: String in overrides:
		if key != "contact": value[key] = overrides[key]
	if value.face == "covered":
		if value.mark == "none": value.actions = ["reveal"] if value.bracketed else ["reveal","flag"]
		elif value.mark == "flag": value.actions = ["unflag"]
		elif value.mark == "marked_flag": value.actions = ["activate"]
	elif value.mark == "none" and value.number > 0: value.actions = ["chord"]
	elif value.mark == "marked_mine": value.actions = ["activate"]
	value.pressable = not value.actions.is_empty()
	return value

func _verify_numerals(pixels: Image, rows: Array[Dictionary], palette: StringName) -> bool:
	var ink: Color = THEME.build("en",100,palette).get_color(&"paper_mark",&"Minesweeper")
	for row: Dictionary in rows:
		var blank: Control = row.cells[4]
		var blank_origin := Vector2i(blank.global_position)
		var cell_size: int = 64 if row.large else 48
		var aperture := Rect2i(16,16,32,32) if row.large else Rect2i(12,12,24,24)
		for numeral in range(1,9):
			var numbered: Control = row.cells[4+numeral]
			var numbered_origin := Vector2i(numbered.global_position)
			var exact_ink_found := false
			for y in cell_size:
				for x in cell_size:
					var local := Vector2i(x,y)
					var actual := pixels.get_pixelv(numbered_origin+local)
					var reference := pixels.get_pixelv(blank_origin+local)
					if actual.is_equal_approx(reference): continue
					if not aperture.has_point(local):
						push_error("Numeral %d ink escaped aperture at %s (%s %s %d%%)" % [numeral,local,palette,"Large" if row.large else "Ordinary",row.percent])
						return false
					if actual.is_equal_approx(ink): exact_ink_found = true
			if not exact_ink_found:
				push_error("Numeral %d has no exact contextual ink pixel (%s %s %d%%)" % [numeral,palette,"Large" if row.large else "Ordinary",row.percent])
				return false
	return true
