extends "res://addons/gut/test.gd"

const MAIN := preload("res://scenes/main/MainGameScene.tscn")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const SHELL_FIXTURES := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT_FIXTURES := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD_FIXTURES := preload("res://tests/unit/test_stat_hud_week_tint.gd")

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
	profile = CONTACT_FIXTURES.FakeProfile.new()
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
