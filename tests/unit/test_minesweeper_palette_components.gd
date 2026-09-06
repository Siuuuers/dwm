extends GutTest

const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

func _view(difficulty: String = "expert") -> Dictionary:
	return {"board":QUERY.desktop(STATE.new().capture(),difficulty,true).value,
		"register":{"difficulty":difficulty,"rounds":2,"mine_estimate":null,"foresight":null,
			"no_flag":"intact","custody":false,"difficulty_enabled":[]},
		"assignments":[false,false,false,false,false,false,false,false,false],
		"actions":["reveal","flag","drag","assignments","rules"]}

func _panel() -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	add_child_autofree(viewport)
	var panel: Control = PANEL.new()
	viewport.add_child(panel)
	assert_true(panel.configure())
	assert_true(panel.present(_view()))
	return panel

func _assert_roles(control: Control, expected: Theme) -> void:
	for role: StringName in [&"paper",&"controlled_face",&"primary_paper_copy",&"primary_dark_copy",&"selected_plane",&"dark_focus_outer",&"paper_focus_inner"]:
		assert_eq(control.get_theme_color(role,&"Minesweeper"),expected.get_color(role,&"Minesweeper"),str(control.name)+": "+str(role))

func test_accessibility_tuple_reaches_existing_new_and_ephemeral_components() -> void:
	var panel := _panel()
	for preset: String in ["standard","protan","deutan","tritan"]:
		for high_contrast: bool in [false,true]:
			var expected: Theme = MS_THEME.build("en",100,&"midnight",high_contrast,preset)
			assert_true(panel.configure("en",100,false,&"midnight",high_contrast,preset))
			for control: Control in [panel.register,panel.register.metrics.rounds,panel.register.difficulties.beginner,
				panel.dock,panel.dock.buttons.flag,panel.worksheet,panel.worksheet.grid,panel.worksheet.grid.cell_nodes[0],panel.worksheet.vertical_rail]:
				_assert_roles(control,expected)
			assert_true(panel.worksheet.open_assignments(panel.public_view.assignments))
			var sheet: Control = panel.worksheet.information_sheet
			for control: Control in [sheet,sheet.rows[0],sheet.return_button]: _assert_roles(control,expected)
			assert_eq(sheet.rail.get_theme_color(&"controlled_face",&"Minesweeper"),expected.get_color(&"paper",&"Minesweeper"))
			panel.worksheet.close_information()
	# New cells and later composition probes consume the retained tuple too.
	assert_true(panel.present(_view("beginner")))
	assert_true(panel.present(_view()))
	_assert_roles(panel.worksheet.grid.cell_nodes[400],MS_THEME.build("en",100,&"midnight",true,"tritan"))

func test_palette_only_change_preserves_grid_contact_and_manual_pan() -> void:
	var panel := _panel()
	var worksheet: Control = panel.worksheet
	var grid: Control = worksheet.grid
	grid.grab_focus()
	worksheet.set_scroll(Vector2i(100,200))
	var before: Dictionary = grid.projection.duplicate(true)
	# A fresh touch begins after the manual viewport move.
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	assert_true(grid.has_held_touch())
	assert_true(panel.configure("en",100,false,&"after_hours",true,"deutan"))
	assert_true(grid.has_held_touch())
	assert_true(grid.has_focus())
	assert_eq(worksheet.get_scroll(),Vector2i(100,200))
	assert_eq(grid.projection,before)
	touch.pressed = false
	touch.canceled = true
	grid._gui_input(touch)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	grid._gui_input(enter)
	assert_true(grid._confirm_held)
	assert_true(panel.configure("en",100,false,&"midnight",false,"protan"))
	assert_true(grid._confirm_held)
	enter.pressed = false
	grid._gui_input(enter)

func test_open_sheet_reconfigures_without_losing_semantic_focus_scroll_or_public_truth() -> void:
	var panel := _panel()
	panel.dock.buttons.assignments.pressed.emit()
	var sheet: Control = panel.worksheet.information_sheet
	sheet.set_scroll(37)
	sheet.rail.grab_focus()
	var before: Dictionary = panel.public_view.duplicate(true)
	assert_true(panel.configure("en",100,false,&"midnight",true,"tritan"))
	assert_same(panel.worksheet.information_sheet,sheet)
	assert_true(sheet.rail.has_focus())
	assert_eq(sheet.get_scroll(),37)
	_assert_roles(sheet.rows[8],MS_THEME.build("en",100,&"midnight",true,"tritan"))
	assert_eq(panel.public_view,before)
	var retained_theme: Theme = sheet.theme
	var retained_focus: Control = sheet.rail
	assert_false(panel.configure("en",100,false,&"after_hours",true,"unknown"))
	assert_same(sheet.theme,retained_theme)
	assert_same(sheet.rail,retained_focus)
	assert_true(retained_focus.has_focus())
	assert_eq(sheet.get_scroll(),37)
	assert_eq(panel.public_view,before)

func test_invalid_component_tuple_leaves_valid_themes_and_cell_identity_intact() -> void:
	var panel := _panel()
	var cell: Control = panel.worksheet.grid.cell_nodes[0]
	var grid_theme: Theme = panel.worksheet.grid.theme
	var worksheet_theme: Theme = panel.worksheet.theme
	var register_theme: Theme = panel.register.theme
	var dock_theme: Theme = panel.dock.theme
	assert_false(cell.configure("en",100,false,&"after_hours",false,"unknown"))
	assert_false(panel.worksheet.grid.configure("en",100,false,&"after_hours",false,"unknown"))
	assert_false(panel.worksheet.configure("desktop_app","en",100,false,&"after_hours",Vector2i.ZERO,false,"unknown"))
	assert_false(panel.register.configure("desktop_app","en",100,false,&"after_hours",false,"unknown"))
	assert_false(panel.dock.configure("desktop_app","en",100,false,&"after_hours",false,"unknown"))
	assert_same(panel.worksheet.grid.theme,grid_theme)
	assert_same(panel.worksheet.theme,worksheet_theme)
	assert_same(panel.register.theme,register_theme)
	assert_same(panel.dock.theme,dock_theme)
	assert_same(panel.worksheet.grid.cell_nodes[0],cell)
