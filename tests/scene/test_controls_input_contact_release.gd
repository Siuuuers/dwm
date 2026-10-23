extends "res://addons/gut/test.gd"
## Actual embedded Controls capture window crossing the parent input owner's contact boundary.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")

var _surface: SubViewport
var _map: Dictionary = {}

func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_map[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.gui_embed_subwindows = true
	add_child(_surface)

func after_each() -> void:
	if is_instance_valid(_surface): _surface.free()
	for action: StringName in InputMap.get_actions():
		if not _map.has(action): InputMap.erase_action(action)
	for action: StringName in _map:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _map[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _map[action].events: InputMap.action_add_event(action, event)
	_map.clear()

func _settle() -> void:
	for _frame: int in range(4): await get_tree().process_frame

func _event(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func _key(viewport: Viewport, code: int, pressed: bool) -> void:
	viewport.push_input(_event(code, pressed), true)
	await _settle()

func test_release_inside_real_controls_capture_clears_parent_contact_before_first_returned_grid_press() -> void:
	var profile := PROFILE.new()
	_surface.add_child(profile)
	assert_true(profile.initialize(STORAGE.new("controls-contact-release.memory", FILES.new())).ok)
	var input := INPUT.new()
	_surface.add_child(input)
	assert_true(input.initialize(profile).ok)
	var localization := LOCALIZATION.new()
	_surface.add_child(localization)
	assert_true(localization.initialize(profile).ok)
	var content: Control = CONTENT.instantiate()
	content.configure_services({"profile": profile, "localization": localization, "input": input,
		"audio": null, "volume": null, "tts": null, "window": null,
		"profile_reset_admission": func() -> bool: return false})
	_surface.add_child(content)
	content.scale = Vector2(1.2, 1.2)
	content.select_category("controls")
	content.hide()
	var grid: Control = GRID.new()
	_surface.add_child(grid)
	assert_true(grid.configure())
	assert_true(grid.configure_input(input))
	assert_true(grid.present({"width": 2, "height": 1, "revision": 7,
		"mine_estimate": 1, "terminal": false, "custody": false,
		"cells": [
			{"index": 0, "face": "covered", "mark": "none", "number": 0,
				"bracketed": false, "inspectable": true, "pressable": true, "actions": ["reveal", "flag"]},
			{"index": 1, "face": "covered", "mark": "none", "number": 0,
				"bracketed": false, "inspectable": true, "pressable": true, "actions": ["reveal", "flag"]}]}))
	var modes: Array = []
	var commands: Array = []
	grid.mode_changed.connect(func(mode): modes.append(mode))
	grid.cell_action_requested.connect(func(action, index, revision): commands.append([action, index, revision]))
	await _settle()
	grid.grab_focus()
	await _key(_surface, KEY_F, true)
	assert_eq(modes, [&"flag"])
	var held_id: String = input.get_physical_contact_id(_event(KEY_F, true))
	assert_true(input.get_physical_contacts().has(held_id), "real parent press must first establish the contact")
	var generation: int = input.get_physical_contacts()[held_id]
	var board: Dictionary = grid.projection.duplicate(true)
	grid.hide()
	content.show()
	var sheet: Control = content._controls_sheet
	sheet.button_for("game_quick_save", "keyboard").grab_focus()
	await _key(_surface, KEY_ENTER, true)
	await _key(_surface, KEY_ENTER, false)
	assert_true(sheet.capture_dialog.visible)
	assert_almost_eq(sheet.capture_dialog.content_scale_factor, 1.2, 0.001, "Binding capture magnifies with the computer content")
	assert_eq(sheet.capture_dialog.size.x, 864, "The enlarged capture window keeps its full content width")
	if not sheet.capture_dialog.visible: return
	var revision: int = profile.get_profile_revision()
	await _key(sheet.capture_dialog, KEY_F6, true)
	var candidate_id: String = input.get_physical_contact_id(_event(KEY_F6, true))
	assert_true(input.get_physical_contacts().has(candidate_id), "capture-window press is observed by the same physical contact owner")
	assert_true(sheet.capture_dialog.visible, "candidate waits for its own physical release")
	await _key(sheet.capture_dialog, KEY_F, false)
	assert_false(input.get_physical_contacts().has(held_id), "release delivered to the capture Window must retire the parent's contact")
	await _key(sheet.capture_dialog, KEY_F6, false)
	assert_false(input.get_physical_contacts().has(candidate_id), "committing release retires the captured candidate contact too")
	assert_false(sheet.capture_dialog.visible)
	assert_eq(profile.get_profile_revision(), revision + 1)
	assert_eq(input.get_action_label("game_quick_save"), OS.get_keycode_string(KEY_F6))
	assert_false(input.get_physical_contacts().has(held_id))
	content.hide()
	content.process_mode = Node.PROCESS_MODE_DISABLED
	grid.show()
	grid.grab_focus()
	await _settle()
	assert_same(_surface.gui_get_focus_owner(), grid)
	await _key(_surface, KEY_F, true)
	assert_eq(modes, [&"flag", &"reveal"], "first fresh press after capture must work without a sacrificial release")
	assert_gt(input.get_physical_contacts()[held_id], generation)
	await _key(_surface, KEY_F, false)
	assert_eq(grid.projection, board)
	assert_true(commands.is_empty())
