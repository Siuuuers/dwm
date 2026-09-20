extends "res://addons/gut/test.gd"

const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const SHELL_FIXTURES := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT_FIXTURES := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD_FIXTURES := preload("res://tests/unit/test_stat_hud_week_tint.gd")
const MINESWEEPER_FIXTURES := preload("res://tests/unit/test_minesweeper_app.gd")

class ShellMinesweeperPort extends MINESWEEPER_FIXTURES.PublicPort:
	var desktop_owner: Control
	func set_foreground(foreground: bool, revision: int) -> Dictionary:
		if app == null: app = desktop_owner.app_window_host.get_child(0)
		return super.set_foreground(foreground, revision)

class NavigationProfile extends CONTACT_FIXTURES.FakeProfile:
	var large_targets := false
	func get_preference(path: StringName, default: Variant = null) -> Variant:
		if path == &"preferences.accessibility.large_targets": return large_targets
		return super.get_preference(path, default)
	func change_large_targets(value: bool) -> void:
		large_targets = value
		preference_changed.emit(&"preferences.accessibility.large_targets", value)

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
			for row: Control in hud.get_node("%Rows").get_children():
				if row.visible: assert_true(hud.get_global_rect().encloses(row.get_global_rect()), "visible fact fits")
			var art: Control = main.get_node("%AngelaImage")
			assert_gt(art.size.y, 0.0, "text leaves some portrait height")
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
	var strip: Control = desktop.get_node("AppStrip")
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
	app._status_label.text = "Temporary status"
	app._status_label.show()
	for width: int in [960, 880, 800]:
		main.get_node("RootHBox").set_angela_width(1280 - width)
		await settle()
		assert_eq(app.size, Vector2(width, 656), "app uses the expanded desktop")
		assert_eq(panel.size, app.size)
		assert_eq(transcript.size, Vector2(width - 248, 560), "extra width goes to reading")
		assert_same(panel.messages, messages, "resize retains message nodes")
		assert_same(panel.transcript, transcript)
		assert_same(app._reply_button, reply, "pending action is not recreated")
		assert_same(viewport.gui_get_focus_owner(), transcript)
		assert_eq(panel._scroll_anchor().get("id"), anchor.get("id"), "same message remains at the top")
		assert_eq(port.reads, reads, "resize does not query or commit gameplay")
		assert_eq(app._status_label.get_rect().end.x, float(width - 16))
		assert_eq(app._status_label.get_rect(), Rect2(264, 608, width - 280, 48), "visible notice stays in its bottom strip")
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
	var decisions: Array[bool] = []
	var response: Dictionary = desktop.present_confirmation({
		"title": "Test confirmation", "body": "Inspect before confirming.",
		"cancel": "Cancel", "confirm": "Confirm",
		"theme": preload("res://scripts/ui/backup/BackupTheme.gd").build("en", 100),
	}, func(): decisions.append(true), func(): decisions.append(false))
	assert_true(response.get("ok", false))
	await settle()
	var modal: Control = response.value.confirmation
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


func test_app_footer_controls_fit_with_large_navigation_and_release_space_when_hidden() -> void:
	var controls := HBoxContainer.new()
	controls.custom_minimum_size = Vector2(320, 48)
	desktop.app_footer_slot.add_child(controls)
	profile.change_large_targets(true)
	await settle()
	assert_true(desktop.app_footer_slot.visible)
	assert_false(desktop.clock_label.visible, "secondary clock yields space to app and accessible controls")
	var strip: Control = desktop.get_node("AppStrip")
	for control: Control in [desktop.home_button, controls, desktop.touch_navigation]:
		assert_true(strip.get_global_rect().encloses(control.get_global_rect()))
	controls.hide()
	await settle()
	assert_false(desktop.app_footer_slot.visible)
	assert_true(desktop.clock_label.visible)


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
	for language: String in ["en", "zh-CN", "zh-HK"]:
		locale.change(language)
		for percent: float in [1.0, 1.25, 1.5]:
			profile.change_scale(percent)
			for large: bool in [false, true]:
				profile.change_large_targets(large)
				await settle()
				var strip: Control = desktop.get_node("AppStrip")
				assert_true(strip.get_global_rect().encloses(controls.get_global_rect()),
					"real Minesweeper footer fits %s/%s/large=%s" % [language, percent, large])
				for control: Control in app.panel.worksheet.zoom_controls:
					assert_true(strip.get_global_rect().encloses(control.get_global_rect()))
	assert_true(desktop.return_home().get("ok", false))
	await settle()
	assert_false(controls.is_visible_in_tree())
	assert_false(desktop.app_footer_slot.visible)
	assert_true(desktop.open_app(&"minesweeper").get("ok", false))
	await settle()
	assert_same(app.panel.worksheet.view_controls, controls, "cached app reuses its footer controls")
	assert_true(controls.is_visible_in_tree())
	app.panel.dock.buttons.rules.pressed.emit()
	await settle()
	assert_same(desktop._touch_focus_scope(), desktop, "switchable views keep their tabs and Home in scope")
	assert_false(controls.is_visible_in_tree(), "board sizing stays out of document views")
	app.panel.worksheet.information_sheet.return_button.grab_focus()
	await tap_navigation(desktop.touch_navigation.next_button)
	assert_true(app.panel.dock.is_ancestor_of(viewport.gui_get_focus_owner()),
		"assisted navigation can leave the document and reach its view tabs")
	app.panel.dock.buttons.assignments.grab_focus()
	await tap_navigation(desktop.touch_navigation.confirm_button)
	assert_eq(app.panel.worksheet.information_sheet.kind, "assignments")
	assert_true(port.commands.is_empty(), "view switching cannot dispatch a board action")
