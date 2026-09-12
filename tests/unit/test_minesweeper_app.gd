extends GutTest

const APP := preload("res://scenes/apps/MinesweeperApp.tscn")
const BOARD_QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

class LocaleFixture extends RefCounted:
	signal locale_changed(locale: String)
	var locale := "en"
	func get_locale() -> String:
		return locale
	func change(value: String) -> void:
		locale = value
		locale_changed.emit(value)

class ProfileFixture extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var values: Dictionary = {}
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return values.get(String(path),fallback)
	func change(path: String, value: Variant) -> void:
		values[path] = value
		preference_changed.emit(StringName(path),value)

class PublicPort extends RefCounted:
	var view: Dictionary = {}
	var live_view: Dictionary = {}
	var lifecycle: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var refused := false
	var unavailable := false
	var app: Control
	func pull() -> Dictionary:
		return {"ok":true,"value":view.duplicate(true)}
	func dispatch(action: String, index: int, revision: int) -> Dictionary:
		commands.append({"action":action,"index":index,"revision":revision})
		return pull()
	func set_foreground(foreground: bool, revision: int) -> Dictionary:
		lifecycle.append({"foreground":foreground,"revision":revision,"visible":app.visible})
		if unavailable: return {"ok":false,"code":&"minesweeper_panel_unavailable"}
		if refused:
			return {"ok":false,"code":&"minesweeper_panel_command_refused","value":view.duplicate(true)}
		if foreground:
			var next_revision: int = view.board.revision+1
			view = live_view.duplicate(true)
			view.board.revision = next_revision
		else:
			live_view = view.duplicate(true)
			view.board.revision += 1
			view.board.custody = true
			view.register.custody = true
			view.actions = []
			for cell: Dictionary in view.board.cells:
				cell.inspectable = false
				cell.pressable = false
				cell.actions = []
		return pull()

class PreparationPort extends PublicPort:
	var advances: Array[int] = []
	var next_result := {"ok":true,"advanced":false}
	func advance_preparation(revision: int) -> Dictionary:
		advances.append(revision)
		var result := next_result.duplicate(true)
		if not result.ok or result.get("advanced",false): result["value"] = view.duplicate(true)
		return result

class ParkedPreparationPort extends PreparationPort:
	var parkable := true
	func can_park_preparation(revision: int) -> bool:
		return parkable and revision == int(view.board.revision)
	func set_foreground(foreground: bool, revision: int) -> Dictionary:
		lifecycle.append({"foreground":foreground,"revision":revision,"visible":app.visible})
		return pull()

var _app: Control
var _viewport: SubViewport
var _home: Button
var _port: PublicPort
var _locale: LocaleFixture
var _profile: ProfileFixture

func _view() -> Dictionary:
	var board: Dictionary = BOARD_QUERY.desktop(STATE.new().capture(),"expert",true).value
	# The fixture supplies only public active-cell permissions; no layout is passed to the App.
	for cell: Dictionary in board.cells: cell.actions = ["reveal","flag"]
	board.mine_estimate = 99
	return {"board":board,"register":{"difficulty":"expert","rounds":1,"mine_estimate":99,
		"foresight":null,"no_flag":"intact","custody":false,"difficulty_enabled":[]},
		"assignments":[true,false,false,false,false,false,false,false,false],
		"actions":["reveal","flag","drag","assignments","rules"],"settled":false}

func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280,720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_home = Button.new()
	_home.text = "Desktop Home"
	_home.position = Vector2(900,20)
	_viewport.add_child(_home)
	_app = APP.instantiate()
	_viewport.add_child(_app)
	_app.hide()
	_port = PublicPort.new()
	_port.view = _view()
	_port.live_view = _port.view.duplicate(true)
	_port.app = _app
	_locale = LocaleFixture.new()
	_profile = ProfileFixture.new()
	assert_true(_app.configure_presentation(_port,_locale,_profile).ok)
	_app.configure_desktop_home(_home)
	assert_true(_app.refresh_view().ok)
	await get_tree().process_frame

func _show() -> void:
	assert_true(_app.prepare_show_window().ok)
	_app.show_window()
	assert_true(_app.visible)

func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	_viewport.push_input(event,true)

func test_scene_contains_real_panel_without_local_topbar_or_simulation_controls() -> void:
	assert_not_null(_app.panel)
	assert_false(_app.get_node("VBoxContainer/TopBar").visible)
	for name: String in ["DifficultyTabs","SimulationButtons","ExplodedButton","ClearButton","PerfectButton","NoFlagButton","ForesightButton","InvitationNotification"]:
		assert_null(_app.find_child(name,true,false),"Removed placeholder must not remain as a hidden simulation path: "+name)
	assert_eq(_app.panel.public_view.board.cells.size(),484)
	assert_true(_app.panel.dock.buttons.new_board.disabled)
	assert_true(_port.commands.is_empty())

func test_prepared_lifecycle_commits_before_visibility_changes() -> void:
	var initial_revision: int = _app.panel.public_view.board.revision
	assert_true(_app.prepare_show_window().ok)
	assert_false(_app.visible)
	assert_eq(_port.lifecycle,[{"foreground":true,"revision":initial_revision,"visible":false}])
	_app.show_window()
	assert_true(_app.visible)
	assert_eq(_port.lifecycle.size(),1,"Showing an already prepared window does not repeat owner work.")
	var active_revision: int = _app.panel.public_view.board.revision
	watch_signals(_app)
	assert_true(_app.prepare_return_home().ok)
	assert_true(_app.visible,"The host still controls the final visual hide after successful preparation.")
	assert_eq(_port.lifecycle[1],{"foreground":false,"revision":active_revision,"visible":true})
	_app.hide_window()
	assert_false(_app.visible)
	assert_eq(_port.lifecycle.size(),2)
	assert_signal_emit_count(_app,"window_hidden",1)
	assert_true(_port.commands.is_empty())

func test_owner_refusal_keeps_visible_window_and_emits_no_hidden_signal() -> void:
	_show()
	_port.refused = true
	watch_signals(_app)
	assert_false(_app.prepare_return_home().ok)
	assert_true(_app.visible)
	_app.hide_window()
	assert_true(_app.visible,"A direct hide cannot bypass a refused suspension.")
	assert_signal_emit_count(_app,"window_hidden",0)
	assert_true(_port.commands.is_empty())

func test_failed_resume_never_shows_a_hidden_window() -> void:
	_port.refused = true
	assert_false(_app.prepare_show_window().ok)
	assert_false(_app.visible)
	_app.show_window()
	assert_false(_app.visible,"The visibility API must preserve a refused resume.")
	assert_true(_port.commands.is_empty())

func test_missing_foreground_publication_blocks_old_facts_until_a_valid_refresh() -> void:
	_show()
	var before: Dictionary = _app.panel.public_view.duplicate(true)
	_port.unavailable = true
	assert_false(_app.prepare_return_home().ok)
	assert_true(_app.visible)
	assert_eq(_app.panel.public_view,before)
	assert_false(_app.panel.has_valid_presentation())
	assert_eq(_app.panel.worksheet.grid.focus_mode,Control.FOCUS_NONE)
	for button: Button in _app.panel.dock.buttons.values(): assert_true(button.disabled)
	assert_false(_app.can_return_home())
	_port.unavailable = false
	assert_true(_app.refresh_view().ok)
	assert_true(_app.can_return_home())

func test_rules_and_assignments_block_home_and_escape_closes_only_the_sheet() -> void:
	_show()
	watch_signals(_app)
	for action: String in ["rules","assignments"]:
		var source: Button = _app.panel.dock.buttons[action]
		source.grab_focus()
		source.pressed.emit()
		assert_not_null(_app.panel.worksheet.information_sheet)
		assert_false(_app.can_return_home())
		var before: int = _port.lifecycle.size()
		assert_false(_app.prepare_return_home().ok)
		assert_eq(_port.lifecycle.size(),before,"A local sheet consumes Home before any lifecycle command.")
		_key(KEY_ESCAPE)
		_key(KEY_ESCAPE,false)
		assert_null(_app.panel.worksheet.information_sheet)
		assert_true(_app.visible)
		assert_true(source.has_focus())
		assert_true(_app.can_return_home())
		assert_signal_emit_count(_app,"window_hidden",0)
	assert_true(_port.commands.is_empty())

func test_reopening_retains_mode_semantic_cell_manual_pan_and_focus() -> void:
	_show()
	_app.panel.dock.buttons.flag.pressed.emit()
	_app.panel.worksheet.grid.grab_focus()
	_app.panel.worksheet.grid._set_focused(200)
	_app.panel.worksheet.set_scroll(Vector2i(80,140))
	_app.remember_focus()
	var retained_scroll: Vector2i = _app.panel.worksheet.get_scroll()
	assert_true(_app.prepare_return_home().ok)
	_app.hide_window()
	assert_false(_app.visible)
	_show()
	assert_eq(_app.panel.worksheet.grid.mode,&"flag")
	assert_eq(_app.panel.worksheet.grid.focused_index,200)
	assert_eq(_app.panel.worksheet.get_scroll(),retained_scroll)
	assert_true(_app.panel.worksheet.grid.has_focus())
	assert_true(_app.panel.dock.buttons.flag.selected)
	assert_true(_port.commands.is_empty())

func test_hide_cancels_pending_touch_without_a_delayed_flag_or_release_action() -> void:
	_show()
	await get_tree().process_frame
	var grid: Control = _app.panel.worksheet.grid
	grid.set_process(false)
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = grid.get_global_transform_with_canvas().origin+Vector2(122,26)
	touch.pressed = true
	_viewport.push_input(touch,true)
	assert_true(grid.has_held_touch())
	assert_true(_app.prepare_return_home().ok)
	_app.hide_window()
	assert_false(grid.has_held_touch())
	grid._process(1.0)
	touch.pressed = false
	_viewport.push_input(touch,true)
	assert_true(_port.commands.is_empty())
	assert_false(_app.visible)

func test_locale_and_profile_signals_apply_real_font_preferences_without_resetting_view_state() -> void:
	_show()
	_app.panel.dock.buttons.flag.pressed.emit()
	_app.panel.worksheet.grid._set_focused(200)
	_app.panel.worksheet.set_scroll(Vector2i(80,140))
	var retained_scroll: Vector2i = _app.panel.worksheet.get_scroll()
	_app.panel.dock.buttons.rules.grab_focus()
	var before: Dictionary = _app.panel.public_view.duplicate(true)
	var lifecycle_before: int = _port.lifecycle.size()
	_profile.change("preferences.accessibility.font_scale",1.25)
	assert_eq(_app.panel.dock.buttons.rules.theme.default_font_size,25)
	_profile.change("preferences.accessibility.large_click_targets",true)
	assert_eq(_app.panel.worksheet.grid.cell_nodes[0].size,Vector2(64,64))
	_locale.change("zh-HK")
	assert_eq(_app.panel.dock.buttons.rules.public_copy,"規則")
	_profile.change("preferences.accessibility.text_size",150)
	_profile.change("preferences.accessibility.large_targets",true)
	_profile.change("preferences.accessibility.font_scale",1.0)
	_profile.change("preferences.accessibility.large_click_targets",false)
	assert_eq(_app.panel.dock.buttons.rules.theme.default_font_size,30,"Canonical text size wins over legacy font scale.")
	assert_eq(_app.panel.worksheet.grid.cell_nodes[0].size,Vector2(64,64),"Canonical targets win over the legacy preference.")
	assert_eq(_app.panel.worksheet.grid.mode,&"flag")
	assert_eq(_app.panel.worksheet.grid.focused_index,200)
	assert_eq(_app.panel.worksheet.get_scroll(),retained_scroll)
	assert_true(_app.panel.dock.buttons.rules.has_focus())
	assert_eq(_app.panel.public_view,before)
	assert_eq(_port.lifecycle.size(),lifecycle_before)
	assert_true(_port.commands.is_empty())

func test_configured_dependencies_are_idempotent_and_cannot_be_rebound() -> void:
	assert_true(_app.configure_presentation(_port,_locale,_profile).ok)
	var replacement := PublicPort.new()
	replacement.view = _view()
	replacement.live_view = replacement.view.duplicate(true)
	replacement.app = _app
	assert_false(_app.configure_presentation(replacement,_locale,_profile).ok)
	assert_true(_app.refresh_view().ok)
	_show()
	assert_eq(_port.lifecycle.size(),1)
	assert_true(replacement.lifecycle.is_empty())

func test_accessibility_preferences_retheme_without_owner_commands_or_navigation_changes() -> void:
	_show()
	_app.panel.dock.buttons.flag.pressed.emit()
	_app.panel.worksheet.grid._set_focused(200)
	_app.panel.worksheet.set_scroll(Vector2i(80,140))
	var retained_scroll: Vector2i = _app.panel.worksheet.get_scroll()
	_app.panel.dock.buttons.rules.grab_focus()
	var before: Dictionary = _app.panel.public_view.duplicate(true)
	var lifecycle_before: int = _port.lifecycle.size()
	_profile.change("preferences.accessibility.high_contrast",true)
	assert_eq(_app.panel.worksheet.grid.cell_nodes[0].get_theme_color("controlled_face","Minesweeper"),Color("0b1018"))
	_profile.change("preferences.accessibility.colour_differentiation","tritan")
	assert_eq(_app.panel.dock.buttons.flag.get_theme_color("selected_plane","Minesweeper"),Color("c4aba2"))
	assert_eq(_app.panel.worksheet.grid.mode,&"flag")
	assert_eq(_app.panel.worksheet.grid.focused_index,200)
	assert_eq(_app.panel.worksheet.get_scroll(),retained_scroll)
	assert_true(_app.panel.dock.buttons.rules.has_focus())
	assert_eq(_app.panel.public_view,before)
	assert_eq(_port.lifecycle.size(),lifecycle_before)
	assert_true(_port.commands.is_empty())

func test_legacy_colour_preference_is_read_only_compatibility_with_canonical_precedence() -> void:
	_show()
	var pairs := {"none":"789083","protanopia":"7d94ae","deuteranopia":"869aaa","tritanopia":"a59289"}
	for legacy: String in pairs:
		_profile.change("preferences.accessibility.colorblind_mode",legacy)
		assert_eq(_app.panel.dock.buttons.flag.get_theme_color("selected_plane","Minesweeper"),Color(pairs[legacy]))
	_profile.change("preferences.accessibility.colour_differentiation","protan")
	_profile.change("preferences.accessibility.colorblind_mode","tritanopia")
	assert_eq(_app.panel.dock.buttons.flag.get_theme_color("selected_plane","Minesweeper"),Color("7d94ae"))
	assert_eq(_profile.values.size(),2,"Reading compatibility does not write defaults or migrate saves.")
	assert_true(_port.commands.is_empty())

func test_invalid_accessibility_preference_keeps_last_valid_theme_and_public_facts() -> void:
	_show()
	var before: Dictionary = _app.panel.public_view.duplicate(true)
	var before_theme: Theme = _app.panel.dock.theme
	watch_signals(_app)
	_profile.change("preferences.accessibility.high_contrast","true")
	assert_eq(_app.last_result.code,&"invalid_minesweeper_preferences")
	assert_same(_app.panel.dock.theme,before_theme)
	_profile.change("preferences.accessibility.high_contrast",false)
	before_theme = _app.panel.dock.theme
	_profile.change("preferences.accessibility.colour_differentiation","invented")
	assert_eq(_app.last_result.code,&"invalid_minesweeper_preferences")
	assert_same(_app.panel.dock.theme,before_theme)
	assert_eq(_app.panel.public_view,before)
	assert_true(_app.panel.has_valid_presentation())
	assert_signal_emit_count(_app,"recovery_requested",2)
	assert_true(_port.commands.is_empty())

func test_palette_change_with_open_sheet_retains_sheet_focus_scroll_and_home_block() -> void:
	_show()
	_profile.change("preferences.accessibility.text_size",150)
	_profile.change("preferences.accessibility.large_targets",true)
	_app.panel.dock.buttons.assignments.pressed.emit()
	var sheet: Control = _app.panel.worksheet.information_sheet
	assert_not_null(sheet.rail)
	sheet.rail.grab_focus()
	var before: Dictionary = _app.panel.public_view.duplicate(true)
	_profile.change("preferences.accessibility.high_contrast",true)
	_profile.change("preferences.accessibility.colour_differentiation","deutan")
	assert_same(_app.panel.worksheet.information_sheet,sheet)
	assert_true(sheet.rail.has_focus())
	assert_eq(sheet.get_theme_color("paper","Minesweeper"),Color("e9e2d0"))
	assert_eq(sheet.return_button.get_theme_color("selected_plane","Minesweeper"),Color("acbecd"))
	assert_true(_home.disabled)
	assert_false(_app.can_return_home())
	assert_eq(_app.panel.public_view,before)
	assert_true(_port.commands.is_empty())

func test_palette_publication_preserves_pending_touch_without_issuing_an_action() -> void:
	_show()
	var grid: Control = _app.panel.worksheet.grid
	grid.set_process(false)
	var touch := InputEventScreenTouch.new()
	touch.index = 11
	touch.position = Vector2(10,10)
	touch.pressed = true
	grid._gui_input(touch)
	assert_true(grid.has_held_touch())
	_profile.change("preferences.accessibility.high_contrast",true)
	assert_true(grid.has_held_touch())
	_profile.change("preferences.accessibility.colour_differentiation","protan")
	assert_true(grid.has_held_touch())
	assert_true(_port.commands.is_empty())
	touch.pressed = false
	touch.canceled = true
	grid._gui_input(touch)

func _prepared_view(forced: int) -> Dictionary:
	var view: Dictionary = _view()
	for index: int in view.board.cells.size():
		var cell: Dictionary = view.board.cells[index]
		cell.bracketed = index == forced
		cell.inspectable = index == forced
		cell.pressable = index == forced
		cell.actions = ["reveal"] if index == forced else []
	return view

func test_first_open_focuses_and_reveals_the_only_legal_prepared_cell() -> void:
	_port.view = _prepared_view(400)
	_port.live_view = _port.view.duplicate(true)
	assert_true(_app.refresh_view().ok)
	_show()
	var grid: Control = _app.panel.worksheet.grid
	var well: Control = _app.panel.worksheet.well
	assert_eq(grid.focused_index,400)
	assert_true(grid.has_focus())
	var cell: Control = grid.cell_nodes[400]
	assert_true(Rect2(Vector2.ZERO,well.size).encloses(Rect2(grid.position+cell.position*grid.scale,cell.size*grid.scale)))
	assert_gt(_app.panel.worksheet.get_scroll().y,0,"Manual view pans to reveal the prepared cell below the visible rows.")
	assert_false(grid.focus_cell(0),"An uninspectable cell cannot replace the repaired legal target.")
	assert_false(grid.focus_cell(-1))
	assert_false(grid.focus_cell(grid.cell_nodes.size()))
	assert_eq(grid.focused_index,400)
	assert_true(grid.has_focus())
	assert_true(_port.commands.is_empty())

func test_reopen_discards_illegal_cached_cell_and_pan_for_current_prepared_target() -> void:
	_show()
	var grid: Control = _app.panel.worksheet.grid
	assert_true(grid.focus_cell(400))
	_app.panel.worksheet.set_scroll(Vector2i(80,250))
	assert_true(_app.prepare_return_home().ok)
	_app.hide_window()
	_port.view = _prepared_view(10)
	_port.live_view = _port.view.duplicate(true)
	assert_true(_app.refresh_view().ok)
	_show()
	assert_eq(grid.focused_index,10)
	assert_true(grid.has_focus())
	var cell: Control = grid.cell_nodes[10]
	var well: Control = _app.panel.worksheet.well
	assert_true(Rect2(Vector2.ZERO,well.size).encloses(Rect2(grid.position+cell.position*grid.scale,cell.size*grid.scale)))
	assert_ne(_app.panel.worksheet.get_scroll(),Vector2i(80,250),"The old manual pan is retired; the complete legal cell visibility above is the requirement.")
	assert_true(_port.commands.is_empty())

func test_focus_loss_clears_held_keyboard_confirmation_and_pending_touch() -> void:
	_show()
	var grid: Control = _app.panel.worksheet.grid
	grid.grab_focus()
	_key(KEY_ENTER)
	assert_eq(_port.commands.size(),1)
	assert_true(grid._confirm_held)
	_app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(grid._confirm_held)
	_key(KEY_ENTER)
	assert_eq(_port.commands.size(),2,"The next fresh native confirmation is not stuck behind the lost release.")
	_key(KEY_ENTER,false)
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = grid.get_global_transform_with_canvas().origin+Vector2(122,26)
	touch.pressed = true
	_viewport.push_input(touch,true)
	assert_true(grid.has_held_touch())
	_app._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_false(grid.has_held_touch())
	grid._process(1.0)
	touch.pressed = false
	_viewport.push_input(touch,true)
	assert_eq(_port.commands.size(),2,"A touch canceled by focus loss cannot flag later or activate on release.")


func test_preparation_pump_is_foreground_one_step_and_stops_for_sheet_pause_or_failure() -> void:
	var app: Control = APP.instantiate()
	_viewport.add_child(app)
	app.set_process(false)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN) # Explicit native focus in a headless fixture.
	app.hide()
	var port := PreparationPort.new()
	port.app = app
	port.view = _view()
	port.live_view = port.view.duplicate(true)
	assert_true(app.configure_presentation(port,_locale,_profile).ok)
	app._process(0.0)
	assert_true(port.advances.is_empty(),"Hidden cached apps do no preparation work.")
	app.show_window()
	watch_signals(app.panel)
	app._process(0.0)
	assert_eq(port.advances.size(),1)
	assert_signal_not_emitted(app.panel,"presentation_changed","Idle preparation does not republish a view.")
	app.panel.dock.buttons.rules.pressed.emit()
	app._process(0.0)
	assert_eq(port.advances.size(),1)
	app.panel.worksheet.close_information()
	get_tree().paused = true
	app._process(0.0)
	get_tree().paused = false
	assert_eq(port.advances.size(),1)
	port.next_result = {"ok":false,"code":&"minesweeper_preparation_refused"}
	app._process(0.0)
	assert_eq(port.advances.size(),2)
	assert_false(app.last_result.ok)
	assert_true(app._preparation_retry.visible)
	app._process(0.0)
	assert_eq(port.advances.size(),2,"Failure waits for explicit recovery instead of retrying I/O every frame.")
	port.next_result = {"ok":true,"advanced":true}
	app._preparation_retry.pressed.emit()
	assert_eq(port.advances.size(),3)
	assert_true(app.last_result.ok)
	assert_false(app._preparation_retry.visible)
	app.queue_free()


func test_preparation_home_parks_only_published_stable_frontier_and_hidden_app_does_no_work() -> void:
	var app: Control = APP.instantiate()
	_viewport.add_child(app)
	app.set_process(false)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN) # Explicit native focus in a headless fixture.
	app.hide()
	var port := ParkedPreparationPort.new()
	port.app = app
	port.view = _view()
	port.view.board.custody = true
	port.view.register.custody = true
	port.view.actions = []
	for cell: Dictionary in port.view.board.cells:
		cell.inspectable = false
		cell.pressable = false
		cell.actions = []
	assert_true(app.configure_presentation(port,_locale,_profile).ok)
	app.show_window()
	assert_true(app.visible)
	assert_true(app.can_return_home())
	port.parkable = false
	assert_false(app.can_return_home(), "Other custody does not inherit preparation parking.")
	port.parkable = true
	app._busy = true
	assert_false(app.can_return_home(), "An in-flight slice cannot be parked.")
	app._busy = false
	app.last_result = {"ok":false}
	assert_false(app.can_return_home(), "A failed slice stays at explicit Retry.")
	app.last_result = {"ok":true}
	var before: Dictionary = port.view.duplicate(true)
	assert_true(app.prepare_return_home().ok)
	app.hide_window()
	assert_false(app.visible)
	app._process(0.0)
	assert_true(port.advances.is_empty())
	assert_eq(port.view, before)
	app.show_window()
	assert_true(app.visible)
	app._process(0.0)
	assert_eq(port.advances, [int(before.board.revision)])
	assert_true(port.commands.is_empty())
	app.queue_free()


func test_unfocused_window_parks_preparation_and_retains_explicit_retry() -> void:
	var app: Control = APP.instantiate()
	_viewport.add_child(app)
	app.set_process(false)
	app.hide()
	var port := PreparationPort.new()
	port.app = app
	port.view = _view()
	port.live_view = port.view.duplicate(true)
	assert_true(app.configure_presentation(port,_locale,_profile).ok)
	app.show_window()
	app._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var before: Dictionary = port.view.duplicate(true)
	app._process(0.0)
	assert_true(port.advances.is_empty(),"A visible unfocused game does not advance preparation.")
	assert_eq(port.view,before)
	app._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	app._process(0.0)
	assert_eq(port.advances.size(),1)
	port.next_result = {"ok":false,"code":&"minesweeper_preparation_refused"}
	app._process(0.0)
	assert_eq(port.advances.size(),2)
	assert_true(app._preparation_retry.visible)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	port.next_result = {"ok":true,"advanced":true}
	app._preparation_retry.pressed.emit()
	app._process(0.0)
	assert_eq(port.advances.size(),2,"Unfocused Retry cannot start work or discard its pending retry.")
	assert_true(app._preparation_retry_needed)
	assert_false(app.last_result.ok)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app._preparation_retry.pressed.emit()
	assert_eq(port.advances.size(),3)
	assert_true(app.last_result.ok)
	assert_false(app._preparation_retry_needed)
	assert_true(port.commands.is_empty())
	app.queue_free()

func test_host_resize_keeps_complete_app_inside_available_display_area() -> void:
	var host := Control.new()
	_viewport.add_child(host)
	_app.reparent(host)
	for available: Vector2 in [Vector2(1280,656),Vector2(640,480),Vector2(320,240),Vector2(1920,1080)]:
		host.size = available
		_app._fit_host()
		assert_true(Rect2(Vector2.ZERO,available).encloses(Rect2(_app.position,_app.size*_app.scale)))
		assert_true(_app.panel.has_valid_presentation())
