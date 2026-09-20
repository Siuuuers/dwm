extends SceneTree
## Production desktop scenes with isolated existing test owners.
## Shop catalog/art and contact messages are synthetic; no player commands or saves are performed.
## Native captures require a renderer; headless mode checks setup/geometry only.
const SPLIT := preload("res://tests/desktop_shell/test_desktop_split_touch.gd")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD := preload("res://tests/unit/test_stat_hud_week_tint.gd")
const SETTINGS := preload("res://tests/unit/test_settings_panel_resize.gd")
const SHOP := preload("res://tests/manual/verify_shop_desktop_native.gd")
const SCHEDULE := preload("res://tests/manual/verify_schedule_desktop_native.gd")
const QUICK := preload("res://tests/manual/verify_quick_status_native.gd")
const MINES := preload("res://tests/unit/test_minesweeper_app.gd")
class VisualLocale extends QUICK.CatalogLocale:
	func get_selectable_locales() -> Array[Dictionary]:
		return [{"id":"en","native_name":"English","release_status":"complete"},{"id":"zh_CN","native_name":"简体中文","release_status":"draft"},{"id":"zh_HK","native_name":"繁體中文","release_status":"draft"}]

var viewport: SubViewport
var main: Control
var desktop: Control
var profile: Node
var locale: Node
var host: RefCounted
var folder := OS.get_environment("DWM_RENDER_OUTPUT")
var failures: Array[String] = []
var captures := 0
var geometry_samples := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("VISUAL_CHECK_FAIL ", message)
func settle() -> void:
	for frame in 6: await process_frame
func capture(name: String, width: int) -> void:
	main.get_node("RootHBox").set_angela_width(1280 - width)
	await settle()
	check(desktop.desktop_canvas.scale.is_equal_approx(Vector2.ONE * (width / 800.0)), name + ": proportional canvas")
	check(desktop.get_global_rect().encloses(desktop.home_button.get_global_rect()), name + ": Home stays visible")
	check(not desktop.status_label.visible, name + ": no presentation failure notice")
	geometry_samples += 1
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		check(not image.is_empty() and image.get_size() == Vector2i(1280,720), name + ": full viewport pixels")
		check(image.save_png(folder.path_join("%s-%d.png" % [name,width])) == OK,"capture "+name)
		captures += 1
	print("SCALING_SAMPLE ",name," width=",width," scale=",desktop.desktop_canvas.scale," scroll=",desktop.app_scroll.scroll_vertical)
func pair(name: String) -> void:
	for width in [800,960]: await capture(name,width)
func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/all_app_scaling")
	DirAccess.make_dir_recursive_absolute(folder)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	locale = VisualLocale.new()
	viewport.add_child(locale)
	check(locale.present("en"),"catalog locale")
	profile = SCHEDULE.Preferences.new()
	viewport.add_child(profile)
	main = SPLIT.MAIN.instantiate()
	var stats := HUD.OwnerFixture.new()
	viewport.add_child(stats)
	main.get_node("%StatHud").configure(stats,locale,profile)
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	host = SCHEDULE.HOST.new()
	host.reset(1)
	check(desktop.configure_contacts(CONTACT.FakePort.new(),locale,profile,host).get("ok",false),"contacts configured")
	desktop._foreground_eligible = true
	await settle()
	await pair("launcher")
	var opened: Dictionary = desktop.open_contacts()
	check(opened.get("ok",false),"contacts opened")
	if opened.get("ok",false):
		opened.value.app.contacts_panel.open_requested.emit("lavinia")
		await pair("contacts")
		var reply: Control = opened.value.app._reply_button
		opened.value.app.contacts_panel.transcript.ensure_control_visible(reply)
		reply.grab_focus()
		await capture("contacts-bottom",960)
		check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(reply.get_global_rect()), "Contacts reply remains reachable: %s in %s" % [reply.get_global_rect(),desktop.app_scroll.get_global_rect()])
	desktop.return_home()
	check(desktop.configure_backup_port(QUICK.RecordsFixture.new()).get("ok",false),"backup configured")
	opened = desktop.open_app(&"backup")
	check(opened.get("ok",false),"backup opened")
	if opened.get("ok",false):
		await pair("backup")
		opened.value.app._select_drawer("slot:7")
		desktop.app_scroll.ensure_control_visible(opened.value.app.drawer_buttons["slot:7"])
		await capture("backup-bottom",960)
		check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(opened.value.app.drawer_buttons["slot:7"].get_global_rect()), "last Backup drawer remains reachable: %s in %s" % [opened.value.app.drawer_buttons["slot:7"].get_global_rect(),desktop.app_scroll.get_global_rect()])
	desktop.return_home()
	var settings: Control = preload("res://scenes/apps/SettingsApp.tscn").instantiate()
	var content: Control = settings.get_node("SettingsContent")
	var settings_profile := SETTINGS.MemoryProfile.new()
	content.configure_services({"profile":settings_profile,"localization":locale,"volume":SETTINGS.MemoryVolume.new(),"audio":null,"tts":null,"input":null,"window":null})
	desktop.app_window_host.add_child(settings)
	desktop._cached_app_windows[&"settings"] = settings
	check(desktop.open_app(&"settings").get("ok",false),"settings opened")
	content.select_category("display")
	await pair("settings-display")
	content.select_category("accessibility")
	await pair("settings-accessibility")
	var last_setting: Control = content.control_for(&"preferences.accessibility.sound_detail_text")
	last_setting.grab_focus()
	await capture("settings-bottom",960)
	check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(last_setting.get_global_rect()), "last Setting remains reachable")
	var menu: OptionButton = content.control_for(&"preferences.accessibility.text_size")
	menu.grab_focus()
	await settle()
	menu.show_popup()
	await capture("settings-popup",960)
	menu.get_popup().hide()
	content.select_category("records")
	content.find_child("PreferencesResetButton",true,false).pressed.emit()
	await capture("settings-reset",960)
	check(content.confirmations.preferences.visible, "real Settings reset opener displays confirmation")
	check(is_equal_approx(content.confirmations.preferences.content_scale_factor,1.2), "Settings confirmation follows desktop scale")
	content.confirmations.preferences.hide()
	desktop.return_home()
	var shop_fixture := SHOP.FIXTURES.new()
	var catalog := SHOP.CatalogFixture.new()
	catalog.rows = shop_fixture._valid_rows()
	shop_fixture.free()
	check(desktop.configure_shop(catalog,locale,profile,host,1).get("ok",false),"shop configured")
	opened = desktop.open_app(&"shop")
	check(opened.get("ok",false),"shop opened")
	if opened.get("ok",false):
		await settle()
		opened.value.app.cards.wine.grab_focus()
		await pair("shop")
		desktop.app_scroll.ensure_control_visible(opened.value.app._buy_button)
		await capture("shop-bottom",960)
	desktop.return_home()
	var loaded: Dictionary = SCHEDULE.REGISTRY.load_current()
	var draft := SCHEDULE.VIEW.new()
	check(draft.configure(loaded.value.registry,SCHEDULE.RULES,loaded.value.registry_fingerprint).ok,"draft configured")
	check(draft.open_day(1,"visual-draft-day").ok,"draft opened")
	var issuer := SCHEDULE.ISSUER.new()
	check(issuer.configure(SCHEDULE.ROOT_STORE.new("73".repeat(32),23)).ok,"issuer configured")
	var port := SCHEDULE.PORT.new()
	var owner := SCHEDULE.DraftSource.new()
	owner.day = 1
	check(port.configure(owner,draft,loaded.value.registry,loaded.value.registry_fingerprint,issuer,{"training":{"en":"Training","zh-CN":"训练","zh-HK":"訓練"},"working":{"en":"Working","zh-CN":"工作","zh-HK":"工作"},"rest":{"en":"Rest","zh-CN":"休息","zh-HK":"休息"}}).ok,"schedule port configured")
	for id: String in ["training","working","rest"]:
		var projected: Dictionary = port.project("en")
		check(port.append(id,projected.value.fingerprint,"en").ok,"append "+id)
	check(desktop.configure_schedule(port,locale,profile,host,1).get("ok",false),"schedule configured")
	opened = desktop.open_app(&"schedule")
	check(opened.get("ok",false),"schedule opened")
	if opened.get("ok",false): await pair("schedule")
	desktop.return_home()
	var mine_fixture := MINES.new()
	var mine_port := SPLIT.ShellMinesweeperPort.new()
	mine_port.desktop_owner = desktop
	mine_port.view = mine_fixture._view()
	mine_port.live_view = mine_port.view.duplicate(true)
	mine_fixture.free()
	check(desktop.configure_minesweeper(mine_port,locale,profile).get("ok",false),"mines configured")
	opened = desktop.open_app(&"minesweeper")
	check(opened.get("ok",false),"mines opened")
	if opened.get("ok",false):
		await pair("minesweeper")
		profile.present(150,true)
		await settle()
		check(opened.value.app.last_result.get("ok",false), "Minesweeper accepts enlarged preferences")
		check(opened.value.app.panel._percent == 150 and opened.value.app.panel._large, "Minesweeper applies enlarged text and targets")
		desktop.app_scroll.ensure_control_visible(opened.value.app.panel.dock)
		await settle()
		check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(opened.value.app.panel.dock.get_global_rect()), "large Minesweeper dock remains reachable")
		await capture("minesweeper-large",960)
		profile.present(100,false)
		await settle()
		check(opened.value.app.panel._percent == 100 and not opened.value.app.panel._large, "Minesweeper restores ordinary preferences")
		check(opened.value.app.panel.layout_height == 536 and desktop.app_scroll.scroll_vertical == 0, "Minesweeper restores compact height and removes extra scrolling")
		var mine_menu: OptionButton = opened.value.app.panel.worksheet.cell_size_menu
		mine_menu.show_popup()
		await capture("minesweeper-popup",960)
		mine_menu.get_popup().hide()
	desktop.return_home()
	var confirmation: Dictionary = desktop.present_confirmation({"title":"Review your choice","body":"This dialog and its controls enlarge with the whole computer panel.","cancel":"Cancel","confirm":"Confirm","theme":preload("res://scripts/ui/backup/BackupTheme.gd").build("en",100)},func():pass,func():pass)
	check(confirmation.get("ok",false),"confirmation configured")
	await pair("confirmation")
	check(geometry_samples == 26, "all expected sample states checked")
	if DisplayServer.get_name() != "headless": check(captures == 26, "all expected screenshots saved")
	var report := {"ok":failures.is_empty(),"renderer":DisplayServer.get_name(),"samples":geometry_samples,"captures":captures,"failures":failures}
	var file := FileAccess.open(folder.path_join("results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("DESKTOP_SCALING_RENDER_VERIFIED ",JSON.stringify(report)) if captures == 26 else print("DESKTOP_SCALING_GEOMETRY_CHECKED ",JSON.stringify(report))
	viewport.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
