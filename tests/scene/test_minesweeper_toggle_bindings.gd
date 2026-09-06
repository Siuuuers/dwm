extends "res://addons/gut/test.gd"
## Real memory Profile + InputManager, native SubViewport input and public Grid
## projection. The fixture binds the owner before focus; no gameplay owner exists.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const ACTION := &"game_toggle_board_mode"
const PAUSE_HANDLE := {"generation": 1, "handle_id": "grid-toggle-pause", "holder": &"grid_toggle_test", "reason": &"universal_pause"}

var _surface: SubViewport
var _profile: Node
var _input: Node
var _grid: Control
var _storage: RefCounted
var _map_backup: Dictionary = {}
var _prior_process_mode: int
var _modes: Array = []
var _commands: Array = []

func before_each() -> void:
	_prior_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: StringName in InputMap.get_actions():
		_map_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_modes.clear()
	_commands.clear()
	_surface = SubViewport.new()
	_surface.size = Vector2i(640, 360)
	_surface.handle_input_locally = true
	_surface.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_surface)
	_profile = PROFILE.new()
	_surface.add_child(_profile)
	_storage = STORAGE.new("grid-toggle.memory", FILES.new())
	assert_true(_profile.initialize(_storage).ok)
	_input = INPUT.new()
	_surface.add_child(_input)
	assert_true(_input.initialize(_profile).ok)

func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(_surface): _surface.free()
	for action: StringName in InputMap.get_actions():
		if not _map_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _map_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _map_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _map_backup[action].events: InputMap.action_add_event(action, event)
	_map_backup.clear()
	process_mode = _prior_process_mode

func _projection(custody: bool = false) -> Dictionary:
	var cells: Array = []
	for index: int in range(4):
		cells.append({"index": index, "face": "covered", "mark": "none", "number": 0,
			"bracketed": false, "inspectable": not custody, "pressable": not custody,
			"actions": [] if custody else ["reveal", "flag"]})
	return {"width": 2, "height": 2, "revision": 7, "mine_estimate": 1,
		"terminal": false, "custody": custody, "cells": cells}

func _mount(bind_owner: bool = true) -> void:
	_grid = GRID.new()
	assert_true(_grid.configure("en", 100, false))
	if bind_owner: assert_true(_grid.configure_input(_input))
	assert_true(_grid.present(_projection()))
	_grid.position = Vector2(70, 50)
	_surface.add_child(_grid)
	_grid.mode_changed.connect(func(mode): _modes.append(mode))
	_grid.cell_action_requested.connect(func(action, index, revision): _commands.append([action, index, revision]))
	await get_tree().process_frame
	assert_true(_grid.focus_cell(2))
	assert_same(_surface.gui_get_focus_owner(), _grid)

func _key(code: int, pressed: bool, ctrl: bool = false, echo: bool = false, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.echo = echo
	_surface.push_input(event, true)

func _joy(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = 0
	event.pressed = pressed
	_surface.push_input(event, true)

func _tap(code: int, ctrl: bool = false, shift: bool = false) -> void:
	_key(code, true, ctrl, false, shift)
	_key(code, false, ctrl, false, shift)

func _rebind_key(code: int, ctrl: bool = false) -> void:
	var records: Array[Dictionary] = [{"kind": "key", "physical_keycode": code, "keycode": 0,
		"shift": false, "alt": false, "ctrl": ctrl, "meta": false}]
	assert_true(_profile.set_input_mapping(ACTION, records).ok)

func _rebind_joy(button: int) -> void:
	var records: Array[Dictionary] = [{"kind": "joypad_button", "button_index": button, "device": -1}]
	assert_true(_profile.set_input_mapping(ACTION, records).ok)

func test_default_keyboard_and_controller_toggle_preserve_projection_focus_cells_and_pan() -> void:
	await _mount()
	var snapshot: Dictionary = _grid.projection.duplicate(true)
	var cells: Array = _grid.cell_nodes.duplicate()
	var pans: Array = []
	_grid.pan_requested.connect(func(delta):
		pans.append(delta)
		_grid.position += delta)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	_surface.push_input(stick, true)
	stick = stick.duplicate()
	stick.axis_value = 0.0
	_surface.push_input(stick, true)
	assert_eq(pans, [Vector2(48, 0)], "native right-stick pan establishes retained placement")
	var position: Vector2 = _grid.position
	_tap(KEY_F)
	assert_eq(_grid.mode, &"flag")
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_X, false)
	assert_eq(_modes, [&"flag", &"reveal"])
	assert_eq(_grid.projection, snapshot)
	assert_eq(_grid.position, position, "toggle does not reset manual placement/pan")
	assert_eq(_grid.focused_index, 2)
	assert_same(_surface.gui_get_focus_owner(), _grid)
	for index: int in cells.size(): assert_same(_grid.cell_nodes[index], cells[index])
	assert_true(_commands.is_empty())
	assert_eq(pans.size(), 1, "toggle adds no pan request")

func test_saved_keyboard_and_controller_bindings_replace_defaults_with_exact_modifiers() -> void:
	_rebind_key(KEY_G)
	_rebind_joy(JOY_BUTTON_PADDLE1)
	var reloaded := PROFILE.new()
	_surface.add_child(reloaded)
	assert_true(reloaded.initialize(_storage).ok)
	assert_eq(reloaded.get_input_mappings(), _profile.get_input_mappings(), "bindings are durable through memory storage")
	await _mount()
	_tap(KEY_F)
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_X, false)
	_tap(KEY_G, true)
	_tap(KEY_G, true, true)
	_tap(KEY_G, false, true)
	assert_true(_modes.is_empty(), "retired defaults and non-exact modifier chords are inert")
	_tap(KEY_G)
	assert_eq(_grid.mode, &"flag")
	_joy(JOY_BUTTON_PADDLE1, true)
	_joy(JOY_BUTTON_PADDLE1, false)
	assert_eq(_modes, [&"flag", &"reveal"])
	assert_true(_commands.is_empty())

func test_duplicate_echo_and_simultaneous_sources_toggle_once_until_all_release() -> void:
	await _mount()
	_key(KEY_F, true)
	_key(KEY_F, true)
	_key(KEY_F, true, false, true)
	_joy(JOY_BUTTON_X, true)
	assert_eq(_modes, [&"flag"])
	_key(KEY_F, false)
	_key(KEY_F, true)
	assert_eq(_modes, [&"flag"], "controller still held keeps shared latch closed")
	_key(KEY_F, false)
	_joy(JOY_BUTTON_X, false)
	_tap(KEY_F)
	assert_eq(_modes, [&"flag", &"reveal"])

func test_held_contact_rebound_to_toggle_requires_its_own_release() -> void:
	await _mount()
	_key(KEY_G, true)
	assert_true(_modes.is_empty())
	_rebind_key(KEY_G)
	_key(KEY_G, true)
	_key(KEY_G, true, false, true)
	assert_true(_modes.is_empty(), "rebind must not make an already held key fresh")
	_key(KEY_G, false)
	_tap(KEY_G)
	assert_eq(_modes, [&"flag"])
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])

func test_focus_departure_and_application_focus_cycle_quarantine_held_contacts() -> void:
	await _mount()
	_key(KEY_F, true)
	_grid.release_focus()
	assert_true(_grid.focus_cell(2))
	_key(KEY_F, true)
	assert_eq(_modes, [&"flag"])
	_surface.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_surface.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(_grid.focus_cell(2))
	_key(KEY_F, true)
	assert_eq(_modes, [&"flag"])
	_key(KEY_F, false)
	_tap(KEY_F)
	assert_eq(_modes, [&"flag", &"reveal"])

func test_sheet_disabled_processing_cannot_replay_contact_on_return() -> void:
	await _mount()
	_grid.process_mode = Node.PROCESS_MODE_DISABLED
	_key(KEY_F, true)
	assert_false(_input.get_physical_contacts().is_empty(), "ALWAYS input owner observes the sheet-held key")
	assert_true(_modes.is_empty())
	_grid.process_mode = Node.PROCESS_MODE_INHERIT
	assert_true(_grid.focus_cell(2))
	_key(KEY_F, true)
	_key(KEY_F, true, false, true)
	assert_true(_modes.is_empty())
	_key(KEY_F, false)
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])

func test_contact_begun_during_application_focus_loss_is_inert_until_release_after_return() -> void:
	await _mount()
	_surface.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_key(KEY_F, true)
	assert_true(_modes.is_empty(), "a new contact is not admitted while the application is inactive")
	_surface.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(_grid.focus_cell(2))
	_key(KEY_F, true)
	assert_true(_modes.is_empty(), "focus return cannot reinterpret the inactive press")
	_key(KEY_F, false)
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])

func test_actual_worksheet_rules_sheet_return_preserves_focus_and_quarantines_sheet_contact() -> void:
	_surface.size = Vector2i(1280, 720)
	var worksheet: Control = WORKSHEET.new()
	assert_true(worksheet.grid.configure_input(_input))
	_surface.add_child(worksheet)
	assert_true(worksheet.configure("desktop_app", "en", 100, false))
	assert_true(worksheet.present(_projection()))
	_grid = worksheet.grid
	_grid.mode_changed.connect(func(mode): _modes.append(mode))
	await get_tree().process_frame
	assert_true(_grid.focus_cell(2))
	var retained: Dictionary = _grid.projection.duplicate(true)
	var scroll: Vector2i = worksheet.get_scroll()
	assert_true(worksheet.open_rules())
	assert_eq(_grid.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(worksheet.well.visible)
	assert_same(_surface.gui_get_focus_owner(), worksheet.information_sheet.rows[0])
	_key(KEY_F, true)
	assert_true(_modes.is_empty())
	_tap(KEY_ESCAPE)
	await get_tree().process_frame
	assert_null(worksheet.information_sheet, "native Back closes the real sheet")
	assert_true(worksheet.well.visible)
	assert_same(_surface.gui_get_focus_owner(), _grid)
	_key(KEY_F, true)
	assert_true(_modes.is_empty())
	_key(KEY_F, false)
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])
	assert_eq(_grid.focused_index, 2)
	assert_eq(_grid.projection, retained)
	assert_eq(worksheet.get_scroll(), scroll)

func test_interaction_and_projection_custody_preserve_release_frontier() -> void:
	await _mount()
	_grid.set_interaction_blocked(true)
	_key(KEY_F, true)
	_grid.set_interaction_blocked(false)
	assert_true(_grid.focus_cell(2))
	_key(KEY_F, true)
	assert_true(_modes.is_empty())
	_key(KEY_F, false)
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])
	assert_true(_grid.present(_projection(true)))
	_joy(JOY_BUTTON_X, true)
	assert_true(_grid.present(_projection()))
	assert_true(_grid.focus_cell(2))
	_joy(JOY_BUTTON_X, true)
	assert_eq(_modes, [&"flag"])
	_joy(JOY_BUTTON_X, false)
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_X, false)
	assert_eq(_modes, [&"flag", &"reveal"])

func test_pause_resume_requires_closing_contact_release_and_later_fresh_press() -> void:
	await _mount()
	assert_true(_input.begin_suspend(PAUSE_HANDLE).ok)
	get_tree().paused = true
	_key(KEY_F, true)
	assert_false(_input.is_source_input_admitted())
	assert_true(_modes.is_empty())
	assert_true(_input.resume(PAUSE_HANDLE).ok)
	get_tree().paused = false
	assert_true(_grid.focus_cell(2))
	await get_tree().process_frame
	_key(KEY_F, true)
	assert_true(_modes.is_empty())
	_key(KEY_F, false)
	await get_tree().process_frame
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])
	assert_true(_input.is_source_input_admitted())

func test_toggle_during_existing_pointer_contact_is_inert_and_keeps_original_gesture() -> void:
	await _mount()
	var point: Vector2 = _grid.position + Vector2(20, 20)
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_surface.push_input(press, true)
	_tap(KEY_F)
	assert_true(_modes.is_empty())
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	_surface.push_input(release, true)
	assert_eq(_commands, [[&"reveal", 0, 7]])
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])

func test_no_owner_is_inert_and_bound_owner_cannot_be_replaced() -> void:
	await _mount(false)
	_tap(KEY_F)
	_joy(JOY_BUTTON_X, true)
	_joy(JOY_BUTTON_X, false)
	assert_true(_modes.is_empty())
	assert_true(_grid.configure_input(_input))
	var other := INPUT.new()
	_surface.add_child(other)
	assert_true(other.initialize(_profile).ok)
	assert_false(_grid.configure_input(other))
	_tap(KEY_F)
	assert_eq(_modes, [&"flag"])
