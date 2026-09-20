extends SceneTree
## Assembled desktop/App GPU evidence with real runtime owners and test-only in-memory
## generation/checkpoint fixtures. This does not install production Bootstrap dependencies.

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const PANEL_PORT := preload("res://scripts/application/minesweeper/MinesweeperPanelPort.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE_PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")

class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	# Identical Bootstrap-only isolation to test_minesweeper_desktop_host.gd.
	func _configure_from_bootstrap() -> void:
		pass

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

var _state: Object
var _coordinator: Object
var _host: Object
var _generation: Object
var _viewport: SubViewport
var _desktop: Control
var _app: Control
var _locale := LocaleFixture.new()
var _profile := ProfileFixture.new()
var _folder := ""

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	_folder = ProjectSettings.globalize_path("user://evidence/minesweeper_app")
	if not _check(DirAccess.make_dir_recursive_absolute(_folder) == OK,"evidence directory unavailable"):
		quit(1)
		return
	if not _setup():
		quit(1)
		return
	for frame in 4: await RenderingServer.frame_post_draw
	_desktop.launcher_buttons[&"minesweeper"].pressed.emit()
	_app = _desktop.app_window_host.find_child("MinesweeperApp",false,false)
	if not _check(_app != null,"launcher did not mount Minesweeper"):
		quit(1)
		return
	var grid: Control = _app.panel.worksheet.grid
	grid.cell_action_requested.emit(&"reveal",0,grid.projection.revision)
	if not _check(_coordinator.get_state().value.phase == "ACTIVE_VISIBLE" and _state.minesweeper_rounds_left == 1,"first Reveal did not commit through the real owners"):
		quit(1)
		return
	grid.cell_action_requested.emit(&"flag",2,grid.projection.revision)
	_app.panel.dock.action_requested.emit(&"flag")
	grid.focus_cell(2)
	grid.grab_focus()
	if not _check(grid.projection.cells[2].mark == "flag" and _app.panel.register.public_view.no_flag == "lost","Flag publication missing from the assembled App"):
		quit(1)
		return
	if not await _capture("active-en100",false):
		quit(1)
		return

	_set_preferences("zh-CN",125,false)
	_app.panel.dock.buttons.rules.grab_focus()
	_app.panel.dock.buttons.rules.pressed.emit()
	if not _check(_app.panel.worksheet.information_sheet != null and _desktop.home_button.disabled,"Rules did not own local input and disable shared Home"):
		quit(1)
		return
	if not await _capture("rules-cn125",true):
		quit(1)
		return
	_app.panel.worksheet.information_sheet.return_requested.emit()

	var retained_cell: Control = grid.cell_nodes[2]
	var board_before: Dictionary = _coordinator.get_state().value.board.duplicate(true)
	var state_before: Dictionary = _state.to_save_dict().duplicate(true)
	var generation_before: Array = _generation.call_log.duplicate(true)
	if not _check(_desktop.return_home().ok,"Home refused the active fixture"):
		quit(1)
		return
	if not _check(_coordinator.get_state().value.phase == "ACTIVE_SUSPENDED" and not _app.visible and _desktop.icon_grid.visible,"Home did not suspend before hiding the App"):
		quit(1)
		return
	print("APP_RENDER_LIFECYCLE phase=ACTIVE_SUSPENDED app_visible=false fixture_generation=memory checkpoint=memory")
	_set_preferences("zh-HK",150,true)
	var reopened: Dictionary = _desktop.open_app(&"minesweeper")
	if not _check(reopened.get("ok",false) and reopened.value.app == _app,"reopen did not return the cached App"):
		quit(1)
		return
	if not _check(_coordinator.get_state().value.phase == "ACTIVE_VISIBLE" and _coordinator.get_state().value.board == board_before,"reopen altered the retained board"):
		quit(1)
		return
	if not _check(_state.to_save_dict() == state_before and _generation.call_log == generation_before,"reopen spent resources or generated another board"):
		quit(1)
		return
	if not _check(grid.cell_nodes[2] == retained_cell and grid.mode == &"flag" and grid.projection.cells[2].mark == "flag","reopen lost cached cells, mode, or public Flag"):
		quit(1)
		return
	grid.focus_cell(2)
	grid.grab_focus()
	if not await _capture("reopened-hk150-large",false):
		quit(1)
		return
	print("APP_RENDER_VERIFIED samples=3 real_scene=true real_owner=true production_bootstrap_configured=false generation=memory_fixture checkpoint=memory_fixture")
	root.remove_child(_viewport)
	_viewport.queue_free()
	await process_frame
	_state.free()
	quit(0)

func _setup() -> bool:
	_state = GAME_STATE.new()
	_state.reset_game()
	_state.set_stat("pressure",0)
	_host = HOST.new()
	_host.reset(1)
	var issuer := ISSUER.new()
	if not _check(issuer.configure(ROOT_STORE.new("42".repeat(32),1)).ok,"issuer fixture configuration failed"): return false
	var state_port := STATE_PORT.new()
	if not _check(state_port.configure(_state,issuer,{"run_id":"render-run","branch_id":"render-branch",
		"desktop_timeline_generation":0,"causal_day_instance":"render-day"}).ok,"state port configuration failed"): return false
	_generation = GENERATION.new()
	_generation.arm_materialize({"schema_version":1,"width":8,"height":8,"mine_indices":[1,2,3,4,5,6,7,8,9,10],"mine_count":10})
	_coordinator = COORDINATOR.new()
	if not _check(_coordinator.configure(state_port,CHECKPOINT.new(),_generation,issuer).ok,"coordinator configuration failed"): return false
	var port := PANEL_PORT.new()
	if not _check(port.configure(_coordinator,issuer,_state,CATALOG.new()).ok,"panel port configuration failed"): return false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800,720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = true
	root.add_child(_viewport)
	_desktop = DESKTOP.instantiate()
	_desktop.set_script(IsolatedDesktop)
	_viewport.add_child(_desktop)
	_desktop.configure_clock(func() -> Dictionary: return {"hour":9,"minute":41})
	return _check(_desktop.configure_minesweeper(port,_locale,_profile,_host,1).ok,"desktop presentation configuration failed")

func _set_preferences(locale: String, percent: int, large: bool) -> void:
	_profile.change("preferences.accessibility.text_size",percent)
	_profile.change("preferences.accessibility.large_targets",large)
	# The existing shared shell still reads its legacy scale; keep both surfaces at this fixture's scale.
	_profile.change("preferences.accessibility.font_scale",percent/100.0)
	_profile.change("preferences.accessibility.large_click_targets",large)
	_locale.change(locale)

func _capture(name: String, sheet_open: bool) -> bool:
	for frame in 4: await RenderingServer.frame_post_draw
	if not _verify_mount(sheet_open): return false
	var pixels: Image = _viewport.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty() and pixels.get_size() == Vector2i(800,720),"assembled viewport capture is empty or has the wrong size"): return false
	var home_origin := Vector2i(_desktop.home_button.global_position)
	var home_ink: Color = _desktop.home_button.get_theme_color("ink","Desktop")
	if not _check(pixels.get_pixelv(home_origin+Vector2i(22,34)).is_equal_approx(home_ink),"shared Home pictogram must render with its inherited theme"): return false
	if sheet_open and not _check(pixels.get_pixelv(home_origin+Vector2i(20,50)).is_equal_approx(home_ink),"inactive shared Home must retain a visible blocked action edge"): return false
	var file := _folder.path_join(name+".png")
	if not _check(pixels.save_png(file) == OK,"assembled screenshot could not be written"): return false
	var public: Dictionary = _app.panel.public_view
	print("APP_CAPTURE ",file," locale=",_locale.get_locale()," phase=",_coordinator.get_state().value.phase,
		" rounds=",public.register.rounds," mine_estimate=",public.register.mine_estimate,
		" no_flag=",public.register.no_flag," mode=",_app.panel.worksheet.grid.mode," sheet_open=",sheet_open,
		" body=(0,64,800,656) shared_strip=(0,0,800,64)")
	return true

func _verify_mount(sheet_open: bool) -> bool:
	if not _check(_app.is_visible_in_tree() and _app.panel.is_visible_in_tree() and not _desktop.icon_grid.visible,"App is not the visible desktop body"): return false
	if not _check(_host.get_state().active_app_id == &"minesweeper","host no longer owns Minesweeper"): return false
	if not _check(_app.get_global_rect() == Rect2(0,64,800,656) and _app.panel.get_global_rect() == Rect2(0,64,800,656),"App body does not close at the delegated mount"): return false
	var strip: Control = _desktop.get_node("DesktopCanvas/AppStrip")
	if not _check(strip.is_visible_in_tree() and strip.get_global_rect() == Rect2(0,0,800,64),"shared AppStrip mount changed"): return false
	if not _check(_desktop.home_button.is_visible_in_tree() and _desktop.home_button.disabled == sheet_open,"shared Home does not match local input ownership"): return false
	if not _check(not _app.get_node("VBoxContainer/TopBar").visible,"local TopBar duplicates shared chrome"): return false
	for name: String in ["DifficultyTabs","SimulationButtons","ExplodedButton","ClearButton","PerfectButton","NoFlagButton","ForesightButton"]:
		if not _check(_app.find_child(name,true,false) == null,"placeholder simulation control remains"): return false
	if not _check(_app.panel.worksheet.well.is_visible_in_tree() != sheet_open,"worksheet/sheet visibility is inconsistent"): return false
	if sheet_open:
		for button: Button in _app.panel.dock.buttons.values():
			if not _check(button.disabled,"sheet leaves a dock action enabled"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition: push_error("APP_RENDER_FAILED: "+message)
	return condition
