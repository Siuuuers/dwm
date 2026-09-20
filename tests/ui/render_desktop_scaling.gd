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
const EXPECTED_CAPTURES := 34
class VisualLocale extends QUICK.CatalogLocale:
	func get_selectable_locales() -> Array[Dictionary]:
		return [{"id":"en","native_name":"English","release_status":"complete"},{"id":"zh_CN","native_name":"简体中文","release_status":"draft"},{"id":"zh_HK","native_name":"繁體中文","release_status":"draft"}]

class VisualPreferences extends SCHEDULE.Preferences:
	var high_contrast := false
	var font_style := "pixel"
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		if path == &"preferences.accessibility.high_contrast": return high_contrast
		if path == &"preferences.accessibility.font_style": return font_style
		return super.get_preference(path, fallback)
	func present_font(value: String) -> void:
		font_style = value
		preference_changed.emit(&"preferences.accessibility.font_style", value)
	func present_contrast(value: bool) -> void:
		high_contrast = value
		preference_changed.emit(&"preferences.accessibility.high_contrast", value)

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
var launcher_pixels: Array[Dictionary] = []
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
	if name.begins_with("launcher"):
		_check_launcher_geometry(name)
	if name.begins_with("minesweeper"):
		for issue: String in mines_control_layout_failures(desktop._cached_app_windows[&"minesweeper"].panel):
			check(false,name+": "+issue)
	geometry_samples += 1
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		check(not image.is_empty() and image.get_size() == Vector2i(1280,720), name + ": full viewport pixels")
		if name.begins_with("launcher"): _check_launcher_pixels(image,name)
		check(image.save_png(folder.path_join("%s-%d.png" % [name,width])) == OK,"capture "+name)
		captures += 1
	print("SCALING_SAMPLE ",name," width=",width," scale=",desktop.desktop_canvas.scale," scroll=",desktop.app_scroll.scroll_vertical)
func pair(name: String) -> void:
	for width in [800,960]: await capture(name,width)

static func mines_control_layout_failures(panel: Control) -> Array[String]:
	var issues: Array[String] = []
	var dock: Control = panel.dock
	var controls: Array = dock.buttons.values()
	controls.sort_custom(func(a: Button,b: Button): return a.position.x < b.position.x)
	if controls.is_empty(): return ["Mines dock has no controls"]
	var gap := -1.0
	for index in controls.size():
		var button: Button = controls[index]
		if not Rect2(Vector2.ZERO,dock.size).grow(0.01).encloses(button.get_rect()):
			issues.append("Mines dock control escapes row: "+button.name)
		if button != dock.buttons.flag:
			if button._paragraph.get_line_count() != 1:
				issues.append("Mines dock label must stay on one line: "+button.public_copy)
			elif button._paragraph.get_line_width(0) > button.size.x-button._inset*2-8+0.01:
				issues.append("Mines dock label exceeds its text area: "+button.public_copy)
		if index > 0:
			var current_gap: float = button.position.x-controls[index-1].get_rect().end.x
			if current_gap < 0 or (gap >= 0 and not is_equal_approx(current_gap,gap)):
				issues.append("Mines dock gaps must be equal and nonnegative")
			gap = current_gap
	var left: float = controls[0].position.x
	var right: float = dock.size.x-controls.back().get_rect().end.x
	if absf(left-right) > 2.01: issues.append("Mines dock outer margins must balance on the two-pixel grid")
	for button: Button in panel.register.difficulties.values():
		if button._paragraph.get_line_count() != 1:
			issues.append("Mines difficulty label must stay on one line: "+button.public_copy)
		elif button._paragraph.get_line_width(0) > button.size.x-button._inset*2-8+0.01:
			issues.append("Mines difficulty label exceeds its text area: "+button.public_copy)
	for metric: Control in panel.register.metrics.values():
		var paragraph: TextParagraph = metric.label_shape.paragraph
		if paragraph.get_line_count() != 1:
			issues.append("Mines metric heading must stay on one line: "+metric.label_copy)
		elif paragraph.get_line_width(0) > metric.size.x-16+0.01:
			issues.append("Mines metric heading exceeds its text area: "+metric.label_copy)
	return issues

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
	profile = VisualPreferences.new()
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
	var contact_port := CONTACT.FakePort.new()
	check(desktop.configure_contacts(contact_port,locale,profile,host).get("ok",false),"contacts configured")
	desktop._foreground_eligible = true
	await settle()
	await pair("launcher")
	await _launcher_samples(contact_port)
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
		await _overlay_samples(opened.value.app, mine_port)
	desktop.return_home()
	var confirmation: Dictionary = desktop.present_confirmation({"title":"Review your choice","body":"This dialog and its controls enlarge with the whole computer panel.","cancel":"Cancel","confirm":"Confirm","theme":preload("res://scripts/ui/backup/BackupTheme.gd").build("en",100)},func():pass,func():pass)
	check(confirmation.get("ok",false),"confirmation configured")
	await pair("confirmation")
	check(geometry_samples == EXPECTED_CAPTURES, "all expected sample states checked")
	if DisplayServer.get_name() != "headless": check(captures == EXPECTED_CAPTURES, "all expected screenshots saved")
	var report := {"ok":failures.is_empty(),"renderer":DisplayServer.get_name(),"samples":geometry_samples,"captures":captures,"failures":failures,"launcher_pixels":launcher_pixels}
	var file := FileAccess.open(folder.path_join("results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("DESKTOP_SCALING_RENDER_VERIFIED ",JSON.stringify(report)) if captures == EXPECTED_CAPTURES and failures.is_empty() else print("DESKTOP_SCALING_GEOMETRY_CHECKED ",JSON.stringify(report))
	viewport.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func _overlay_samples(app: Control, port: RefCounted) -> void:
	# A valid public touched-board fixture supplies New Board permission. No game command runs.
	var original_view: Dictionary = port.view.duplicate(true)
	port.view = app.panel.public_view.duplicate(true)
	port.view.board.cells[0].face = "revealed"
	port.view.board.cells[0].actions = []
	port.view.board.cells[0].pressable = false
	port.view.actions.append("new_board")
	port.view.register.difficulty_enabled = ["beginner", "intermediate", "expert"]
	port.live_view = port.view.duplicate(true)
	check(app.refresh_view().get("ok",false), "valid touched board for overlay evidence")
	await _capture_overlay(app,"rules","en",800)
	await _capture_overlay(app,"assignments","en",960)
	check(locale.present("ja"), "Japanese overlay catalog")
	profile.present(150,true)
	profile.present_contrast(true)
	await settle()
	check(app.panel._locale == "ja" and app.panel._percent == 150 and app.panel._large and app.panel._high_contrast,
		"overlay applies Japanese enlarged text, targets and high contrast")
	await _capture_overlay(app,"rules","ja-large-contrast",960)
	await _capture_overlay(app,"assignments","ja-large-contrast",960)
	port.view = original_view
	port.live_view = original_view.duplicate(true)
	check(app.refresh_view().get("ok",false), "restore ordinary board fixture after overlay evidence")
	profile.present_contrast(false)
	profile.present(100,false)
	check(locale.present("en"), "restore English after overlay evidence")
	await settle()
	check(port.commands.is_empty(), "overlay screenshots do not dispatch gameplay commands")

func _capture_overlay(app: Control, kind: String, variant: String, width: int) -> void:
	main.get_node("RootHBox").set_angela_width(1280-width)
	await settle()
	var worksheet: Control = app.panel.worksheet
	var grid: Control = worksheet.grid
	var board_rect := grid.get_rect()
	var board_scroll: Vector2i = worksheet.get_scroll()
	app.panel.dock.buttons[kind].pressed.emit()
	await settle()
	var sheet: Control = worksheet.information_sheet
	check(sheet != null, kind+": real information overlay opened")
	if sheet == null: return
	check(not app.panel.dock.buttons.has("board"), kind+": redundant Board control absent")
	check(worksheet.well.is_visible_in_tree() and grid.is_visible_in_tree(), kind+": board remains mounted and visible beneath sheet")
	check(grid.process_mode == Node.PROCESS_MODE_DISABLED, kind+": covered board input remains blocked")
	check(grid.get_rect() == board_rect and worksheet.get_scroll() == board_scroll, kind+": opening sheet preserves board geometry and pan")
	check(sheet.get_global_rect().encloses(sheet.return_button.get_global_rect()), kind+": Return remains within overlay")
	check(is_equal_approx(sheet.return_button.position.x,sheet.size.x-144)
		and is_equal_approx(sheet.return_button.position.y+sheet.return_button.custom_minimum_size.y,sheet.size.y-24),
		kind+": Return keeps its original lower-right placement")
	check(not desktop.home_button.disabled and not app.panel.dock.buttons.new_board.disabled, kind+": Home and permitted New Board remain available")
	for button: Button in app.panel.register.difficulties.values():
		check(not button.disabled, kind+": permitted difficulty remains available")
	desktop.app_scroll.ensure_control_visible(sheet.return_button)
	await settle()
	check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(sheet.return_button.get_global_rect()), kind+": Return remains reachable in desktop viewport")
	await capture("minesweeper-"+kind+"-"+variant,width)
	sheet.return_button.pressed.emit()
	await settle()
	check(worksheet.information_sheet == null and worksheet.grid == grid, kind+": Return closes only overlay and retains board")

func _check_launcher_geometry(name: String) -> void:
	check(desktop.launcher_buttons.keys() == SHELL.APP_IDS, name+": seven original app targets in registry order")
	for id: StringName in desktop.launcher_buttons:
		var button: Button = desktop.launcher_buttons[id]
		var caption: Label = button.caption
		check(button.icon_id == id, name+": icon identifies "+String(id))
		check(caption.get_theme_font("font") == SPLIT.TYPOGRAPHY.font(desktop._locale,profile.percent,profile.font_style), name+": selected font face is applied to "+String(id))
		check(caption.get_theme_font_size("font_size") == SPLIT.TYPOGRAPHY.font_size(desktop._locale,profile.percent,24,profile.font_style), name+": selected font size is retained for "+String(id))
		check(button.get_global_rect().grow(0.01).encloses(caption.get_global_rect()), name+": complete caption remains inside "+String(id))
		check(caption.size.y >= caption.get_minimum_size().y, name+": native caption height retained for "+String(id))
		check(button.find_children("*","BaseButton",true,false).is_empty(), name+": decorative icon adds no action target")
		check(caption.mouse_filter == Control.MOUSE_FILTER_IGNORE and caption.focus_mode == Control.FOCUS_NONE, name+": caption remains inert")
	check(desktop.contacts_button.caption.text == desktop.LABELS[desktop._locale][1], name+": unread marker does not wrap the Contacts name")

func _icon_sample(image: Image, button: Control, point: Vector2) -> Color:
	return image.get_pixelv(Vector2i(button.get_global_transform() * point))

func _check_launcher_pixels(image: Image, name: String) -> void:
	var silhouettes: Array[String] = []
	for id: StringName in desktop.launcher_buttons:
		var button: Button = desktop.launcher_buttons[id]
		check(button.get("_icon_texture") == null, name+": procedural fallback is actually rendered for "+String(id))
		var background := _icon_sample(image,button,Vector2(65,9))
		var mask := ""
		# Sample the centers of the24x24 logical pixels, independent of canvas scaling phase.
		for y: int in range(24):
			for x: int in range(24):
				mask += "0" if _icon_sample(image,button,Vector2(65+x*2,9+y*2)) == background else "1"
		check(mask.count("1") >= 8 and mask.count("0") >= 8, name+": nonempty visible silhouette for "+String(id))
		var signature := mask.sha256_text()
		check(not silhouettes.has(signature), name+": distinct silhouette for "+String(id))
		silhouettes.append(signature)
	var contacts: Button = desktop.contacts_button
	var badge_visible := _icon_sample(image,contacts,Vector2(108,12)) != _icon_sample(image,contacts,Vector2(65,9))
	check(badge_visible == contacts.unread, name+": unread badge matches visible native pixels")
	launcher_pixels.append({"sample":name,"distinct_icons":silhouettes.size(),"unread":contacts.unread})

func _launcher_samples(port: RefCounted) -> void:
	var before_unread: Dictionary = port.unread.duplicate(true)
	var before_opens: Array = port.opens.duplicate()
	var before_replies: int = port.reply_count
	var focus := viewport.gui_get_focus_owner()
	profile.present(150,false)
	await capture("launcher-en-pixel-large-unread",960)
	profile.present_font("readable")
	await capture("launcher-en-readable-large",960)
	check(locale.present("ja"),"Japanese enlarged launcher locale")
	await capture("launcher-ja-readable-large",960)
	profile.present_contrast(true)
	await capture("launcher-ja-readable-large-contrast",960)
	for friend_id: String in port.unread: port.unread[friend_id] = false
	desktop._on_contacts_changed({})
	await settle()
	check(not desktop.contacts_button.unread,"all-read fixture clears the inert badge")
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var contacts: Button = desktop.contacts_button
		check(_icon_sample(image,contacts,Vector2(108,12)) == _icon_sample(image,contacts,Vector2(65,9)),"all-read badge clears from native pixels")
	port.unread = before_unread
	desktop._on_contacts_changed({})
	profile.present_contrast(false)
	profile.present_font("pixel")
	profile.present(100,false)
	check(locale.present("en"),"restore English launcher preferences")
	await settle()
	check(viewport.gui_get_focus_owner() == focus,"launcher preview preserves the same focused app")
	check(port.opens == before_opens and port.reply_count == before_replies and port.unread == before_unread,"launcher previews do not open messages, submit replies or change saved unread state")
