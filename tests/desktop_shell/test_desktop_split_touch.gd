extends "res://addons/gut/test.gd"

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const SHELL_FIXTURES := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT_FIXTURES := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD_FIXTURES := preload("res://tests/unit/test_stat_hud_week_tint.gd")
const MINESWEEPER_FIXTURES := preload("res://tests/unit/test_minesweeper_app.gd")
const BACKUP_FIXTURES := preload("res://tests/unit/test_backup_panel_resize.gd")
const SETTINGS_FIXTURES := preload("res://tests/unit/test_settings_panel_resize.gd")

class ShellMinesweeperPort extends MINESWEEPER_FIXTURES.PublicPort:
	var desktop_owner: Control
	func set_foreground(foreground: bool, revision: int) -> Dictionary:
		if app == null: app = desktop_owner.app_window_host.get_child(0)
		return super.set_foreground(foreground, revision)

class NavigationProfile extends CONTACT_FIXTURES.FakeProfile:
	var large_targets := false
	var font_style := "pixel"
	func get_preference(path: StringName, default: Variant = null) -> Variant:
		if path == &"preferences.accessibility.large_targets": return large_targets
		if path == &"preferences.accessibility.font_style": return font_style
		return super.get_preference(path, default)
	func change_large_targets(value: bool) -> void:
		large_targets = value
		preference_changed.emit(&"preferences.accessibility.large_targets", value)
	func change_font_style(value: String) -> void:
		font_style = value
		preference_changed.emit(&"preferences.accessibility.font_style", value)

var viewport: SubViewport
var main: Control
var desktop: Control
var locale: Node
var profile: RefCounted
var stats: Node


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	add_child_autofree(viewport)
	locale = CONTACT_FIXTURES.FakeLocale.new()
	add_child_autofree(locale)
	profile = NavigationProfile.new()
	stats = HUD_FIXTURES.OwnerFixture.new()
	stats.condition_effects_today = ["nausea", "dizzy", "sequela", "faint"]
	stats.penalty_points_today = 10
	add_child_autofree(stats)
	main = MAIN.instantiate()
	main.get_node("%StatHud").configure(stats, locale, profile)
	desktop = DESKTOP.instantiate()
	desktop.set_script(SHELL_FIXTURES.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL_FIXTURES.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	var host := CONTACT_FIXTURES.FakeHost.new()
	host.reject_next = false
	assert_true(desktop.configure_contacts(CONTACT_FIXTURES.FakePort.new(), locale, profile, host).get("ok", false))
	desktop._foreground_eligible = true
	await settle()


func settle() -> void:
	for frame: int in range(5): await get_tree().process_frame


func test_resizing_keeps_current_app_and_focus_and_hud_inside_the_shell() -> void:
	var split := main.get_node("RootHBox")
	assert_true(split.has_method("set_angela_width"), "main mounts the draggable split")
	if not split.has_method("set_angela_width"): return
	var opened: Dictionary = desktop.open_contacts()
	assert_true(opened.get("ok", false))
	if not opened.get("ok", false): return
	var app: Control = opened.value.app
	await settle()
	var focus: Control = viewport.gui_get_focus_owner()
	assert_not_null(focus)
	for language: String in ["en", "zh-CN", "zh-HK"]:
		locale.change(language)
		for scale_value: float in [1.0, 1.25, 1.5]:
			profile.change_scale(scale_value)
			split.set_angela_width(320)
			await settle()
			var panel: Control = main.get_node("%AngelaPanel")
			var hud: Control = main.get_node("%StatHud")
			assert_eq(panel.size.x, 320.0)
			assert_eq(desktop.size.x, 960.0)
			assert_true(panel.get_global_rect().encloses(hud.get_global_rect()), "HUD fits %s at %s" % [language, scale_value])
			var stat_scroll: ScrollContainer = hud.get_node("%StatScroll")
			for row: Control in hud.get_node("%Rows").get_children():
				if row.visible:
					stat_scroll.ensure_control_visible(row)
					await settle()
					assert_true(stat_scroll.get_global_rect().grow(0.01).encloses(row.get_global_rect()), "every fact remains reachable in the overlay")
			var art: Control = main.get_node("%AngelaImage")
			assert_eq(art.get_global_rect(), panel.get_global_rect(), "portrait continues behind the stat overlay")
			for layer: Control in art.get_children():
				assert_true(panel.get_global_rect().encloses(layer.get_global_rect()), "art remains inside Angela")
	assert_same(desktop._cached_app_windows[&"contacts"], app, "resize never remounts the app")
	# Isolate resizing from locale-driven app focus restoration.
	focus = viewport.gui_get_focus_owner()
	split.set_angela_width(480)
	await settle()
	assert_same(viewport.gui_get_focus_owner(), focus, "divider width alone preserves focus")
	assert_eq(desktop.size.x, 800.0)


func test_three_button_footer_leaves_full_app_height_and_navigation_never_launches() -> void:
	var navigation := desktop.find_child("TouchNavigation", true, false)
	assert_not_null(navigation, "desktop mounts the three-control focus bar")
	if navigation == null: return
	assert_false(navigation.visible, "ordinary pointer and keyboard users have a compact footer")
	profile.change_large_targets(true)
	await settle()
	assert_true(navigation.visible, "large targets retains assisted focus navigation")
	assert_eq(navigation.get_child_count(), 3)
	var strip: Control = desktop.get_node("DesktopCanvas/AppStrip")
	assert_eq(strip.position.y, 656.0)
	assert_eq(desktop.app_window_host.size.y, 656.0)
	assert_eq(desktop.app_window_host.position.y, 0.0)
	var first: Button = desktop.launcher_buttons[&"minesweeper"]
	first.grab_focus()
	navigation.next_button.pressed.emit()
	assert_same(viewport.gui_get_focus_owner(), desktop.contacts_button, "Next follows launcher reading order")
	assert_true(desktop._cached_app_windows.is_empty(), "inspection does not open an app")
	for language: String in ["en", "zh-CN", "zh-HK"]:
		locale.change(language)
		profile.change_scale(1.5)
		await settle()
		for control: Control in [desktop.home_button, desktop.title_label, desktop.clock_label, navigation]:
			assert_true(strip.get_global_rect().encloses(control.get_global_rect()), "footer fits at enlarged " + language)
		for button: Button in [navigation.previous_button, navigation.next_button, navigation.confirm_button]:
			assert_false(button.accessibility_name.is_empty())
			assert_eq(button.focus_mode, Control.FOCUS_NONE, "touch controls do not steal app focus")


func test_contacts_expands_the_same_thread_and_retains_its_reading_position() -> void:
	var opened: Dictionary = desktop.open_contacts()
	assert_true(opened.get("ok", false))
	if not opened.get("ok", false): return
	var app: Control = opened.value.app
	app.contacts_panel.open_requested.emit("lavinia")
	await settle()
	var panel: Control = app.contacts_panel
	var transcript: ScrollContainer = panel.transcript
	var messages: VBoxContainer = panel.messages
	var reply: Button = app._reply_button
	assert_not_null(reply)
	var block: Control = messages.get_child(4)
	transcript.scroll_vertical = int(block.position.y)
	transcript.grab_focus()
	await settle()
	var anchor: Dictionary = panel._scroll_anchor()
	var port: RefCounted = app._presentation_port
	var reads: int = port.reads
	var original_transcript_size := transcript.get_global_rect().size
	app._status_label.text = "Temporary status"
	app._status_label.show()
	for width: int in [960, 880, 800]:
		main.get_node("RootHBox").set_angela_width(1280 - width)
		await settle()
		assert_eq(app.size, Vector2(800, 656), "app retains its logical canvas while magnifying")
		assert_eq(panel.size, app.size)
		assert_true(transcript.get_global_rect().size.is_equal_approx(original_transcript_size * (width / 800.0)),
			"reading content enlarges proportionally with the pane")
		assert_same(panel.messages, messages, "resize retains message nodes")
		assert_same(panel.transcript, transcript)
		assert_same(app._reply_button, reply, "pending action is not recreated")
		assert_same(viewport.gui_get_focus_owner(), transcript)
		assert_eq(panel._scroll_anchor().get("id"), anchor.get("id"), "same message remains at the top")
		assert_eq(port.reads, reads, "resize does not query or commit gameplay")
		assert_eq(app._status_label.get_rect(), Rect2(264, 608, 520, 48), "visible notice retains its logical bottom strip")
		assert_true(panel.get_global_rect().encloses(transcript.get_global_rect()))


func tap_navigation(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame
	await settle()


func test_footer_home_keeps_hardware_navigation_into_current_app() -> void:
	var opened: Dictionary = desktop.open_contacts()
	assert_true(opened.get("ok", false))
	if not opened.get("ok", false): return
	await settle()
	for key: Key in [KEY_UP, KEY_DOWN]:
		desktop.home_button.grab_focus()
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = pressed
			viewport.push_input(event, true)
		await settle()
		assert_true(opened.value.app.is_ancestor_of(viewport.gui_get_focus_owner()),
			"Home Up enters the app; Home Down retains wrap navigation")


func test_footer_navigates_real_confirmation_without_activating_background() -> void:
	profile.change_large_targets(true)
	main.get_node("RootHBox").set_angela_width(320)
	await settle()
	var decisions: Array[bool] = []
	var response: Dictionary = desktop.present_confirmation({
		"title": "Test confirmation", "body": "Inspect before confirming.",
		"cancel": "Cancel", "confirm": "Confirm",
		"theme": preload("res://scripts/ui/backup/BackupTheme.gd").build("en", 100),
	}, func(): decisions.append(true), func(): decisions.append(false))
	assert_true(response.get("ok", false))
	await settle()
	var modal: Control = response.value.confirmation
	var sheet: Control = modal.get_node("ConfirmationSheet")
	assert_true(desktop.get_global_rect().encloses(sheet.get_global_rect()))
	assert_lte(sheet.get_global_rect().end.y, desktop.home_button.get_global_rect().position.y,
		"enlarged confirmation and its actions stay above the accessible footer")
	assert_eq(desktop.contacts_button.get_focus_mode_with_override(), Control.FOCUS_NONE,
		"moving confirmations into the scaled canvas preserves background input custody")
	modal.cancel_button.grab_focus()
	await tap_navigation(desktop.touch_navigation.next_button)
	assert_same(viewport.gui_get_focus_owner(), modal.confirm_button)
	assert_true(decisions.is_empty(), "Next only inspects the affirmative action")
	await tap_navigation(desktop.touch_navigation.previous_button)
	assert_same(viewport.gui_get_focus_owner(), modal.cancel_button)
	await tap_navigation(desktop.touch_navigation.confirm_button)
	assert_eq(decisions, [false], "Confirm uses the modal's normal Cancel key path once")
	assert_false(is_instance_valid(desktop._confirmation))
	assert_true(desktop._cached_app_windows.is_empty(), "modal navigation never launches the background app")


func test_footer_confirm_reaches_real_grid_without_changing_its_input_contract() -> void:
	profile.change_large_targets(true)
	# Read-only reuse of the existing grid: this feature owns no board mechanics.
	var grid: Control = preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd").new()
	desktop.app_window_host.add_child(grid)
	desktop.icon_grid.hide()
	desktop._active_id = &"minesweeper"
	desktop._refresh_app_scroll()
	assert_true(grid.configure("en", 100, false))
	var cells: Array = []
	for index: int in range(2):
		cells.append({"index": index, "face": "covered", "mark": "none", "number": 0,
			"bracketed": false, "inspectable": true, "pressable": true, "actions": ["reveal", "flag"]})
	assert_true(grid.present({"width": 2, "height": 1, "revision": 7, "mine_estimate": 1,
		"terminal": false, "custody": false, "cells": cells}))
	var actions: Array = []
	grid.cell_action_requested.connect(func(action, index, revision): actions.append([action, index, revision]))
	grid.grab_focus()
	await settle()
	await tap_navigation(desktop.touch_navigation.confirm_button)
	assert_eq(actions, [[&"reveal", 0, 7]], "one footer confirmation delivers one published grid action")
	assert_false(grid._confirm_held, "the paired release clears the grid's held confirm state")


func test_launcher_enlarges_after_resize_without_remounting_or_losing_focus() -> void:
	var first: Button = desktop.launcher_buttons[&"minesweeper"]
	first.grab_focus()
	var original_rect := first.get_global_rect()
	main.get_node("RootHBox").set_angela_width(320)
	await settle()
	assert_almost_eq(first.get_global_rect().size.x, original_rect.size.x * 1.2, 0.1,
		"wider computer pane enlarges icons and captions at the same window height")
	assert_almost_eq(first.get_global_rect().size.y, original_rect.size.y * 1.2, 0.1)
	assert_same(desktop.launcher_buttons[&"minesweeper"], first)
	assert_same(viewport.gui_get_focus_owner(), first)
	for button: Button in desktop.launcher_buttons.values():
		assert_true(desktop.get_global_rect().encloses(button.get_global_rect()))
		assert_lt(button.get_global_rect().end.y, desktop.home_button.get_global_rect().position.y)


func test_real_desktop_content_enlarges_only_after_divider_release() -> void:
	var first: Button = desktop.launcher_buttons[&"minesweeper"]
	first.grab_focus()
	var original := first.get_global_rect()
	var home_original: Rect2 = desktop.home_button.get_global_rect()
	var button := InputEventMouseButton.new()
	button.position = Vector2(472, 360)
	button.global_position = button.position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	viewport.push_input(button, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(312, 360)
	motion.global_position = motion.position
	motion.relative = Vector2(-160, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)
	await settle()
	assert_eq(first.get_global_rect(), original, "dragging only previews the divider")
	assert_eq(desktop.home_button.get_global_rect(), home_original)
	button = InputEventMouseButton.new()
	button.position = motion.position
	button.global_position = button.position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	viewport.push_input(button, true)
	await settle()
	assert_eq(desktop.size.x, 960.0)
	assert_true(first.get_global_rect().size.is_equal_approx(original.size * 1.2))
	assert_true(desktop.home_button.get_global_rect().size.is_equal_approx(home_original.size * 1.2),
		"the footer shares the same enlargement as app content")
	assert_same(viewport.gui_get_focus_owner(), first)
	assert_true(desktop.get_global_rect().encloses(desktop.home_button.get_global_rect()))


func test_backup_enlargement_preserves_pending_action_and_reaches_bottom_drawer() -> void:
	var port := BACKUP_FIXTURES.Port.new()
	assert_true(desktop.configure_backup_port(port).get("ok", false))
	var opened: Dictionary = desktop.open_app(&"backup")
	assert_true(opened.get("ok", false))
	if not opened.get("ok", false): return
	var app: Control = opened.value.app
	await settle()
	app._select_drawer("slot:7")
	var drawer: Button = app.drawer_buttons["slot:7"]
	var action: Button = app.action_buttons.save
	action.grab_focus()
	app._pending_token = "prepared-resize-token"
	var original_size := drawer.get_global_rect().size
	var projections: int = port.projections
	main.get_node("RootHBox").set_angela_width(320)
	await settle()
	assert_true(drawer.get_global_rect().size.is_equal_approx(original_size * 1.2))
	assert_same(desktop._cached_app_windows[&"backup"], app)
	assert_same(app.drawer_buttons["slot:7"], drawer)
	assert_same(app.action_buttons.save, action)
	assert_same(viewport.gui_get_focus_owner(), action)
	assert_eq(app.selected_locator, "slot:7")
	assert_eq(app._pending_token, "prepared-resize-token")
	assert_eq(port.projections, projections, "resize cannot replace a prepared backup action")
	desktop.app_scroll.ensure_control_visible(drawer)
	await settle()
	assert_true(desktop.app_scroll.get_global_rect().grow(0.01).encloses(drawer.get_global_rect()),
		"the bottom row stays reachable when the whole app is enlarged")
	assert_true(desktop.get_global_rect().encloses(desktop.home_button.get_global_rect()))


func test_settings_enlargement_preserves_preview_and_reaches_deep_controls() -> void:
	var app: Control = preload("res://scenes/apps/SettingsApp.tscn").instantiate()
	var content: Control = app.get_node("SettingsContent")
	var settings_profile := SETTINGS_FIXTURES.MemoryProfile.new()
	var volume := SETTINGS_FIXTURES.MemoryVolume.new()
	content.configure_services({"profile": settings_profile,
		"localization": SETTINGS_FIXTURES.MemoryLocalization.new(), "volume": volume,
		"audio": null, "tts": null, "input": null, "window": null})
	desktop.app_window_host.add_child(app)
	desktop._cached_app_windows[&"settings"] = app
	assert_true(desktop.open_app(&"settings").get("ok", false))
	await settle()
	content.select_category("audio")
	var category: Button = content.find_child("AudioCategory", true, false)
	var slider: HSlider = content.control_for(SETTINGS_FIXTURES.VOLUME_PATH)
	var controller: RefCounted = content.get_controller()
	slider.grab_focus()
	controller.begin_volume_drag(SETTINGS_FIXTURES.VOLUME_PATH)
	slider.set_value_no_signal(0.37)
	await controller._on_volume_changed(0.37, SETTINGS_FIXTURES.VOLUME_PATH)
	var pending: Dictionary = controller.get("_drag").duplicate(true)
	assert_false(pending.is_empty())
	var original_size := category.get_global_rect().size
	main.get_node("RootHBox").set_angela_width(320)
	await settle()
	assert_true(category.get_global_rect().size.is_equal_approx(original_size * 1.2))
	assert_same(content.find_child("AudioCategory", true, false), category)
	assert_same(content.control_for(SETTINGS_FIXTURES.VOLUME_PATH), slider)
	assert_same(viewport.gui_get_focus_owner(), slider)
	assert_true(category.button_pressed)
	assert_eq(slider.value, 0.37)
	assert_eq(controller.get("_drag"), pending)
	assert_true(settings_profile.commits.is_empty())
	await controller.cancel_volume_drag()
	content.select_category("accessibility")
	var last: Control = content.control_for(&"preferences.accessibility.sound_detail_text")
	last.grab_focus()
	await settle()
	assert_true(content.sheet_scroll.get_global_rect().encloses(last.get_global_rect()),
		"inner focus scrolling uses logical distances under desktop magnification")
	assert_true(desktop.app_scroll.get_global_rect().encloses(last.get_global_rect()),
		"outer scrolling leaves the focused setting above the fixed footer")
	var menu: OptionButton = content.control_for(&"preferences.accessibility.text_size")
	menu.grab_focus()
	await settle()
	menu.show_popup()
	await settle()
	assert_true(menu.get_popup().visible)
	assert_almost_eq(menu.get_popup().content_scale_factor, 1.2, 0.001,
		"native popup text follows the same desktop enlargement")
	menu.get_popup().hide()


func test_app_footer_controls_fit_with_large_navigation_and_release_space_when_hidden() -> void:
	var controls := HBoxContainer.new()
	controls.custom_minimum_size = Vector2(320, 48)
	desktop.app_footer_slot.add_child(controls)
	profile.change_large_targets(true)
	await settle()
	assert_true(desktop.app_footer_slot.visible)
	assert_true(desktop.clock_label.visible, "local time stays visible with app and accessible controls")
	var strip: Control = desktop.get_node("DesktopCanvas/AppStrip")
	for control: Control in [desktop.home_button, controls, desktop.touch_navigation]:
		assert_true(strip.get_global_rect().encloses(control.get_global_rect()))
	_assert_footer_clock()
	controls.hide()
	await settle()
	assert_false(desktop.app_footer_slot.visible)
	_assert_footer_clock()


func _assert_footer_clock() -> void:
	var strip: Control = desktop.get_node("DesktopCanvas/AppStrip")
	var clock_rect: Rect2 = desktop.clock_label.get_global_rect()
	assert_true(desktop.clock_label.is_visible_in_tree(), "local time never yields to footer controls")
	assert_same(strip.get_child(strip.get_child_count()-1),desktop.clock_label, "clock is the final footer item")
	assert_almost_eq(clock_rect.end.x,strip.get_global_rect().end.x,desktop.desktop_canvas.scale.x+0.01,
		"clock stays at the far right within one snapped logical pixel")
	assert_true(strip.get_global_rect().encloses(clock_rect), "clock fits the fixed footer")
	var font: Font = desktop.clock_label.get_theme_font("font")
	var font_size: int = desktop.clock_label.get_theme_font_size("font_size")
	assert_lte(font.get_string_size(desktop.clock_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,
		desktop.clock_label.size.x, "clock text fits without clipping")
	var right := strip.get_global_rect().position.x
	for control: Control in [desktop.home_button,desktop.title_label,desktop.app_footer_slot,desktop.touch_navigation,desktop.clock_label]:
		if not control.is_visible_in_tree(): continue
		assert_gte(control.get_global_rect().position.x,right-0.01, "footer items never overlap")
		right = control.get_global_rect().end.x


func test_real_minesweeper_footer_mounts_fits_and_tracks_cached_app_visibility() -> void:
	var fixture := MINESWEEPER_FIXTURES.new()
	add_child_autofree(fixture)
	var port := ShellMinesweeperPort.new()
	port.desktop_owner = desktop
	port.view = fixture._view()
	port.live_view = port.view.duplicate(true)
	assert_true(desktop.configure_minesweeper(port, locale, profile).get("ok", false))
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	assert_true(opened.get("ok", false))
	if not opened.get("ok", false): return
	var app: Control = opened.value.app
	var controls: Control = app.panel.worksheet.view_controls
	var menu: OptionButton = app.panel.worksheet.cell_size_menu
	await settle()
	assert_same(controls.get_parent(), desktop.app_footer_slot)
	assert_true(controls.is_visible_in_tree())
	assert_eq(menu.item_count, 27, "Fit and all 26 supported sizes are available in the real footer")
	for font_style: String in ["pixel","readable"]:
		profile.change_font_style(font_style)
		for pane_width: int in [800,960]:
			main.get_node("RootHBox").set_angela_width(1280-pane_width)
			await settle()
			for language: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
				locale.change(language)
				for percent: float in [1.0, 1.25, 1.5]:
					profile.change_scale(percent)
					for large: bool in [false, true]:
						profile.change_large_targets(large)
						await settle()
						assert_true(app.last_result.get("ok", false),
							"the requested presentation succeeds at %s/%s/large=%s: %s" % [language, percent, large, app.last_result])
						assert_eq(app.panel._locale, language)
						assert_eq(app.panel._percent, int(percent * 100), "font size must be applied before checking geometry")
						assert_eq(app.panel._large, large, "large-target presentation cannot silently retain an earlier state")
						var strip: Control = desktop.get_node("DesktopCanvas/AppStrip")
						assert_true(desktop.get_global_rect().encloses(strip.get_global_rect()),
							"footer stays inside the desktop at %s/%s/large=%s" % [language, percent, large])
						assert_lte(strip.size.y, 64.0, "footer controls cannot expand the bar below the desktop")
						_assert_footer_clock()
						var expected_font: Font = TYPOGRAPHY.font(language,int(percent*100),font_style)
						assert_same(desktop.theme.default_font,expected_font,"desktop applies selected font style")
						assert_same(desktop.clock_label.get_theme_font("font"),expected_font,
							"persistent clock follows the selected face with tabular digits")
						assert_same(app.panel.worksheet.theme.default_font,expected_font,"Mines footer follows selected font style")
						assert_true(strip.get_global_rect().encloses(controls.get_global_rect()),
							"real Minesweeper footer fits %s/%s/large=%s" % [language, percent, large])
						if desktop.app_scroll_rail.visible:
							desktop.app_scroll.ensure_control_visible(app.panel.dock)
							await settle()
						assert_true(desktop.app_scroll.get_global_rect().grow(0.01).encloses(app.panel.dock.get_global_rect()),
							"board actions remain reachable above the enlarged footer at %s/%s/large=%s" % [language, percent, large])
						if desktop.touch_navigation.visible:
							assert_true(strip.get_global_rect().encloses(desktop.touch_navigation.get_global_rect()),
								"assisted navigation stays inside the footer alongside the board controls")
						for control: Control in app.panel.worksheet.zoom_controls:
							assert_true(strip.get_global_rect().encloses(control.get_global_rect()))
	profile.change_scale(1.0)
	profile.change_large_targets(false)
	await settle()
	assert_true(app.last_result.get("ok", false), "a readable fallback can return to the compact presentation")
	assert_eq(app.panel._percent, 100)
	assert_false(app.panel._large)
	assert_lte(app.size.y, desktop.app_scroll.size.y + 0.01, "normal text fits the visible app height again")
	assert_false(desktop.app_scroll_rail.visible, "returning to normal text releases the outer scroll range")
	profile.change_large_targets(true)
	await settle()
	assert_true(desktop.return_home().get("ok", false))
	await settle()
	assert_false(controls.is_visible_in_tree())
	assert_false(desktop.app_footer_slot.visible)
	_assert_footer_clock()
	assert_true(desktop.open_app(&"minesweeper").get("ok", false))
	await settle()
	assert_same(app.panel.worksheet.view_controls, controls, "cached app reuses its footer controls")
	assert_true(controls.is_visible_in_tree())
	app.panel.dock.buttons.rules.pressed.emit()
	await settle()
	assert_same(desktop._touch_focus_scope(), desktop, "switchable views keep their tabs and Home in scope")
	assert_false(controls.is_visible_in_tree(), "board sizing stays out of document views")
	_assert_footer_clock()
	app.panel.worksheet.information_sheet.return_button.grab_focus()
	await tap_navigation(desktop.touch_navigation.next_button)
	assert_true(app.panel.dock.is_ancestor_of(viewport.gui_get_focus_owner()),
		"assisted navigation can leave the document and reach its view tabs")
	app.panel.dock.buttons.assignments.grab_focus()
	await tap_navigation(desktop.touch_navigation.confirm_button)
	assert_eq(app.panel.worksheet.information_sheet.kind, "assignments")
	assert_true(port.commands.is_empty(), "view switching cannot dispatch a board action")
