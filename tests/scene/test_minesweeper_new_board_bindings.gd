extends "res://addons/gut/test.gd"
## Real Profile/InputManager bindings through a SubViewport and the desktop Panel.

const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const ACTION := &"game_new_board"
const PAUSE_HANDLE := {"generation": 1, "handle_id": "new-board-pause", "holder": &"new_board_test", "reason": &"universal_pause"}

class BoardPort extends RefCounted:
	var view: Dictionary
	var dispatches: Array[Dictionary] = []
	func _init(initial: Dictionary) -> void:
		view = initial.duplicate(true)
	func pull() -> Dictionary:
		return {"ok": true, "value": view.duplicate(true)}
	func dispatch(action: String, index: int, revision: int) -> Dictionary:
		dispatches.append({"action": action, "index": index, "revision": revision})
		var next: Dictionary = view.duplicate(true)
		next.board.revision += 1
		next.board.terminal = false
		next.board.custody = false
		next.register.custody = false
		next.actions = ["reveal", "flag", "drag", "assignments", "rules"]
		next.settled = false
		for cell: Dictionary in next.board.cells:
			cell.face = "covered"
			cell.mark = "none"
			cell.number = 0
			cell.bracketed = false
			cell.inspectable = true
			cell.pressable = true
			cell.actions = ["reveal", "flag"]
		view = next
		return {"ok": true, "value": view.duplicate(true)}

var _surface: SubViewport
var _profile: Node
var _input: Node
var _panel: Control
var _port: BoardPort
var _map_backup: Dictionary = {}
var _prior_process_mode: int

func before_each() -> void:
	_prior_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: StringName in InputMap.get_actions():
		_map_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.handle_input_locally = true
	_surface.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_surface)
	_profile = PROFILE.new()
	_surface.add_child(_profile)
	assert_true(_profile.initialize(STORAGE.new("new-board.memory", FILES.new())).ok)
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

func _view(settled: bool, new_board: bool = true) -> Dictionary:
	var board: Dictionary = QUERY.desktop(STATE.new().capture(), "beginner", true).value
	if settled:
		board.terminal = true
		board.custody = true
		for cell: Dictionary in board.cells:
			cell.inspectable = false
			cell.pressable = false
			cell.actions = []
	elif new_board:
		board.cells[0].face = "revealed"
		board.cells[0].pressable = false
		board.cells[0].actions = []
	return {"board": board,
		"register": {"difficulty": "beginner", "rounds": 2, "mine_estimate": board.mine_estimate,
			"foresight": null, "no_flag": "intact", "custody": settled, "difficulty_enabled": []},
		"assignments": [false, false, false, false, false, false, false, false, false],
		"actions": ["new_board", "assignments", "rules"] if settled else
			(["reveal", "flag", "drag", "assignments", "rules", "new_board"] if new_board else
			["reveal", "flag", "drag", "assignments", "rules"]),
		"settled": settled}

func _mount(settled: bool, new_board: bool = true) -> void:
	_panel = PANEL.new()
	_surface.add_child(_panel)
	assert_true(_panel.worksheet.grid.configure_input(_input))
	_port = BoardPort.new(_view(settled, new_board))
	assert_true(_panel.bind(_port))
	assert_true(_panel.configure())
	assert_true(_panel.refresh())
	await get_tree().process_frame
	if not settled:
		assert_true(_panel.worksheet.grid.focus_cell(0))

func _key(code: int, pressed: bool, echo: bool = false, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = ctrl
	_surface.push_input(event, true)

func _joy(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = 0
	event.pressed = pressed
	_surface.push_input(event, true)

func _tap(code: int) -> void:
	_key(code, true)
	_key(code, false)

func _rebind_key(code: int) -> void:
	var records: Array[Dictionary] = [{"kind": "key", "physical_keycode": code, "keycode": 0,
		"shift": false, "alt": false, "ctrl": false, "meta": false}]
	assert_true(_profile.set_input_mapping(ACTION, records).ok)

func _rebind_joy(button: int) -> void:
	var records: Array[Dictionary] = [{"kind": "joypad_button", "button_index": button, "device": -1}]
	assert_true(_profile.set_input_mapping(ACTION, records).ok)

func test_default_and_saved_bindings_dispatch_only_published_active_new_board() -> void:
	await _mount(false)
	_tap(KEY_SPACE)
	assert_eq(_port.dispatches.size(), 1)
	if _port.dispatches.is_empty(): return
	assert_eq(_port.dispatches[0], {"action": "new_board", "index": -1, "revision": 0})
	assert_false("new_board" in _panel.public_view.actions, "The returned untouched board no longer offers New Board.")
	_tap(KEY_SPACE)
	assert_eq(_port.dispatches.size(), 1)
	assert_true(_panel.present(_view(false)))
	_rebind_key(KEY_G)
	_rebind_joy(JOY_BUTTON_PADDLE1)
	assert_true(_panel.worksheet.grid.focus_cell(0))
	_tap(KEY_SPACE)
	_key(KEY_G, true, false, true)
	_key(KEY_G, false, false, true)
	assert_eq(_port.dispatches.size(), 1, "Old binding and extra modifier are inert.")
	_tap(KEY_G)
	assert_eq(_port.dispatches.size(), 2)
	assert_true(_panel.present(_view(false)))
	assert_true(_panel.worksheet.grid.focus_cell(0))
	_joy(JOY_BUTTON_PADDLE1, true)
	_joy(JOY_BUTTON_PADDLE1, false)
	assert_eq(_port.dispatches.size(), 3)

func test_settled_board_accepts_keyboard_and_controller_without_grid_focus() -> void:
	await _mount(true)
	assert_false(_panel.worksheet.grid.has_focus())
	_tap(KEY_SPACE)
	assert_eq(_port.dispatches.size(), 1)
	if _port.dispatches.is_empty(): return
	assert_eq(_port.dispatches[0].action, "new_board")
	assert_true(_panel.present(_view(true)))
	_rebind_key(KEY_G)
	_rebind_joy(JOY_BUTTON_PADDLE1)
	_tap(KEY_SPACE)
	assert_eq(_port.dispatches.size(), 1)
	_tap(KEY_G)
	assert_eq(_port.dispatches.size(), 2)
	assert_true(_panel.present(_view(true)))
	_joy(JOY_BUTTON_PADDLE1, true)
	_joy(JOY_BUTTON_PADDLE1, false)
	assert_eq(_port.dispatches.size(), 3)

func test_held_key_cannot_become_new_board_after_rebind_focus_sheet_or_pause() -> void:
	await _mount(false)
	_key(KEY_G, true)
	_rebind_key(KEY_G)
	_key(KEY_G, true)
	assert_true(_port.dispatches.is_empty())
	_key(KEY_G, false)
	assert_true(_panel.worksheet.grid.focus_cell(0))
	_tap(KEY_G)
	assert_eq(_port.dispatches.size(), 1)
	assert_true(_panel.present(_view(false)))
	assert_true(_panel.worksheet.grid.focus_cell(0))
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 2)
	assert_true(_panel.present(_view(false)), "Republish availability while the same physical key remains held.")
	_panel.worksheet.grid.release_focus()
	assert_true(_panel.worksheet.grid.focus_cell(0))
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 2, "The held key cannot dispatch again after focus return.")
	_key(KEY_G, false)
	assert_true(_panel.worksheet.open_rules())
	_key(KEY_G, true)
	_panel.worksheet.close_information()
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 2, "A key begun inside the sheet stays quarantined.")
	_key(KEY_G, false)
	assert_true(_input.begin_suspend(PAUSE_HANDLE).ok)
	get_tree().paused = true
	_key(KEY_G, true)
	assert_true(_input.resume(PAUSE_HANDLE).ok)
	get_tree().paused = false
	await get_tree().process_frame
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 2, "Resume does not reinterpret the held key.")
	_key(KEY_G, false)
	await get_tree().process_frame
	_tap(KEY_G)
	assert_eq(_port.dispatches.size(), 3)

func test_settled_board_does_not_replay_held_key_across_focus_or_pause() -> void:
	await _mount(true)
	_rebind_key(KEY_G)
	var source := Button.new()
	_surface.add_child(source)
	source.grab_focus()
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 1)
	assert_true(_panel.present(_view(true)))
	_source_focus_cycle(source)
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 1)
	_key(KEY_G, false)
	assert_true(_input.begin_suspend(PAUSE_HANDLE).ok)
	get_tree().paused = true
	_key(KEY_G, true)
	assert_true(_input.resume(PAUSE_HANDLE).ok)
	get_tree().paused = false
	await get_tree().process_frame
	_key(KEY_G, true)
	assert_eq(_port.dispatches.size(), 1)
	_key(KEY_G, false)
	await get_tree().process_frame
	_tap(KEY_G)
	assert_eq(_port.dispatches.size(), 2)

func test_canonical_challenge_hosts_do_not_offer_new_board_even_with_a_saved_binding() -> void:
	_rebind_key(KEY_G)
	for host: String in ["canonical_solo", "canonical_pair"]:
		var dock: Control = DOCK.new()
		_surface.add_child(dock)
		assert_true(dock.configure(host))
		assert_false(dock.buttons.has("new_board"))
		assert_true(dock.present(&"reveal", ["reveal", "flag", "drag", "rules", "pause"]))
		assert_false(dock.present(&"reveal", ["new_board"]),
			"Canonical challenge presentation rejects the desktop-only New Board action.")

func _source_focus_cycle(source: Button) -> void:
	source.release_focus()
	source.grab_focus()
