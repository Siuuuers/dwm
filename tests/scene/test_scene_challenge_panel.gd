extends "res://addons/gut/test.gd"
## Injected view-only integration: real physical/Profile owners behind a TEST
## command adapter and native SubViewport input. This does not prove production
## Bridge binding, captions, pause custody, durable Save9, or rendered acceptance.

const PANEL := preload("res://scripts/ui/SceneChallengePanel.gd")
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const INPUT_FIXTURE := preload("res://tests/support/MinesweeperInputFixture.gd")

class InjectedPort extends RefCounted:
	var fixture: RefCounted
	var calls: Array[Dictionary] = []
	var pulls := 0
	var refuse_pull := false
	var refuse_action := false
	var malformed := false
	func pull_scene_panel(command: Dictionary) -> Dictionary:
		pulls += 1
		if command != fixture.command: return {"ok": false, "code": &"TEST.command_mismatch"}
		if refuse_pull: return {"ok": false, "code": &"TEST.pull_refused"}
		if malformed: return {"ok": true, "value": {"host": "canonical_solo", "board": {}, "actions": []}}
		return fixture.owner.pull_scene_panel(fixture.token)
	func dispatch_scene_panel_action(command: Dictionary, action: String, index: int, revision: int) -> Dictionary:
		calls.append({"command": command.duplicate(true), "action": action, "index": index, "revision": revision})
		if command != fixture.command: return {"ok": false, "code": &"TEST.command_mismatch"}
		if refuse_action: return {"ok": false, "code": &"TEST.action_refused"}
		return fixture.owner.dispatch_scene_panel_action(fixture.token, action, index, revision)

var _fixture: RefCounted
var _inputs: RefCounted
var _port: InjectedPort
var _panel: Control
var _viewport: SubViewport

func before_each() -> void:
	_fixture = FIXTURE.new()
	assert_true(_fixture.setup("TEST.scene.panel").ok)
	var mines: Array = []
	for index in 33: mines.append(index)
	mines.append_array([288, 289, 307])
	_fixture.generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
		"mine_indices": mines, "mine_count": 36})
	assert_true(_fixture.begin().ok)
	_inputs = INPUT_FIXTURE.new()
	_port = InjectedPort.new()
	_port.fixture = _fixture
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child(_viewport)
	_panel = PANEL.new()
	_viewport.add_child(_panel)
	assert_true(_inputs.bind_grid(_panel.worksheet.grid, _viewport))
	assert_true(_panel.bind(_port, _fixture.command))
	assert_true(_panel.open_panel())
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(_viewport): _viewport.free()
	if _inputs != null: _inputs.restore_map()
	if _fixture != null: _fixture.dispose()

func _pointer(index: int, pressed: bool) -> void:
	var cell: Control = _panel.worksheet.grid.cell_nodes[index]
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = cell.get_global_transform_with_canvas() * (cell.size / 2.0)
	event.pressed = pressed
	_viewport.push_input(event, true)

func _click(index: int) -> void:
	_pointer(index, true)
	_pointer(index, false)

func test_opening_and_refreshing_present_unstarted_owner_board_without_start() -> void:
	assert_eq(_panel.public_view.phase, "never_started")
	assert_eq(_panel.public_view.actions, ["reveal"])
	assert_eq(_panel.worksheet.grid.projection.revision, 0)
	assert_eq(_panel.worksheet.grid.cell_nodes.size(), 18 * 18)
	assert_eq(_panel.public_view.host, "canonical_solo")
	assert_true(_panel.refresh())
	assert_true(_fixture.record().is_empty())
	assert_true(_port.calls.is_empty())
	assert_true(_fixture.authority.checkpoints.is_empty())
	assert_eq(_fixture.state.effects, 0)

func test_modes_rules_and_view_preferences_do_not_start_or_dispatch() -> void:
	_panel.dock.action_requested.emit(&"flag")
	assert_eq(_panel.worksheet.grid.mode, &"flag")
	_panel.dock.action_requested.emit(&"drag")
	assert_eq(_panel.worksheet.grid.mode, &"drag")
	assert_true(_panel.worksheet.set_always_fit(true))
	_panel.dock.action_requested.emit(&"rules")
	assert_not_null(_panel.worksheet.information_sheet)
	_panel.worksheet.information_sheet.return_button.pressed.emit()
	assert_null(_panel.worksheet.information_sheet)
	assert_eq(_panel.worksheet.grid.mode, &"drag")
	assert_true(_port.calls.is_empty())
	assert_true(_fixture.record().is_empty())

func test_native_grid_release_forwards_exact_command_cell_and_revision_then_repulls() -> void:
	assert_true(_panel.worksheet.set_always_fit(true))
	var pulls_before := _port.pulls
	_pointer(200, true)
	assert_true(_port.calls.is_empty(), "Press alone is not a reveal.")
	_pointer(200, false)
	assert_eq(_port.calls.size(), 1)
	if _port.calls.size() != 1: return
	assert_eq(_port.calls[0], {"command": _fixture.command, "action": "reveal", "index": 200, "revision": 0})
	assert_gt(_port.pulls, pulls_before, "Dispatch response has no panel host; refresh uses the public pull.")
	assert_false(_fixture.record().is_empty())
	assert_eq(_panel.public_view.host, "canonical_solo")
	assert_eq(_fixture.state.effects, 0)

func test_blocking_cancels_held_pointer_and_suppresses_modes_and_dispatch() -> void:
	assert_true(_panel.worksheet.set_always_fit(true))
	_pointer(200, true)
	_panel.set_interaction_blocked(true)
	_pointer(200, false)
	_panel.dock.action_requested.emit(&"flag")
	assert_eq(_panel.worksheet.grid.mode, &"reveal")
	_panel.worksheet.cell_action_requested.emit(&"reveal", 200, 0)
	assert_true(_port.calls.is_empty())
	assert_true(_fixture.record().is_empty())
	_panel.set_interaction_blocked(false)
	await get_tree().process_frame
	assert_true(_port.calls.is_empty(), "Unblocking cannot replay the cancelled press.")

func test_refused_pull_retains_display_but_removes_input_until_successful_refresh() -> void:
	var before: Dictionary = _panel.worksheet.grid.projection.duplicate(true)
	_port.refuse_pull = true
	watch_signals(_panel)
	assert_false(_panel.refresh())
	assert_signal_emitted_with_parameters(_panel, "presentation_failed", [&"TEST.pull_refused"])
	_panel.worksheet.cell_action_requested.emit(&"reveal", 200, 0)
	assert_true(_port.calls.is_empty())
	assert_eq(_panel.worksheet.grid.projection, before)
	_port.refuse_pull = false
	assert_true(_panel.refresh())
	assert_true(_fixture.record().is_empty())

func test_malformed_pull_and_refused_action_fail_closed_without_starting() -> void:
	_port.malformed = true
	assert_false(_panel.refresh())
	_panel.worksheet.cell_action_requested.emit(&"reveal", 200, 0)
	assert_true(_port.calls.is_empty())
	_port.malformed = false
	assert_true(_panel.refresh())
	_port.refuse_action = true
	_panel.worksheet.cell_action_requested.emit(&"reveal", 200, 0)
	assert_eq(_port.calls.size(), 1)
	_panel.worksheet.cell_action_requested.emit(&"reveal", 201, 0)
	assert_eq(_port.calls.size(), 1, "Failure disables later actions.")
	assert_true(_fixture.record().is_empty())

func test_close_and_reopen_preserve_projection_mode_and_absence_without_dispatch() -> void:
	_panel.dock.action_requested.emit(&"drag")
	var before: Dictionary = _panel.worksheet.grid.projection.duplicate(true)
	_panel.close_panel()
	assert_false(_panel.is_visible_in_tree())
	_panel.worksheet.cell_action_requested.emit(&"reveal", 200, 0)
	assert_true(_port.calls.is_empty())
	assert_true(_panel.open_panel())
	assert_eq(_panel.worksheet.grid.projection, before)
	assert_eq(_panel.worksheet.grid.mode, &"drag")
	assert_true(_fixture.record().is_empty())
	assert_true(_port.calls.is_empty())

func test_started_board_reopens_from_owner_and_fixed_chrome_has_no_start_or_new_board() -> void:
	_panel.worksheet.cell_action_requested.emit(&"reveal", 323, 0)
	assert_eq(_port.calls.size(), 1)
	assert_eq(_fixture.record().phase, "active")
	var before: Dictionary = _panel.worksheet.grid.projection.duplicate(true)
	_panel.close_panel()
	assert_true(_panel.open_panel())
	assert_eq(_panel.worksheet.grid.projection, before)
	assert_eq(_port.calls.size(), 1)
	assert_eq(_panel.size, Vector2(960, 656))
	assert_eq(_panel.dock.position.y + _panel.dock.size.y, 656.0)
	assert_false(_panel.dock.buttons.has("start"))
	assert_false(_panel.dock.buttons.has("new_board"))

func test_pause_stays_available_after_pull_refusal_but_obeys_host_blocking() -> void:
	_port.refuse_pull = true
	assert_false(_panel.refresh())
	watch_signals(_panel)
	assert_false(_panel.dock.buttons.pause.disabled)
	_panel.dock.buttons.pause.pressed.emit()
	assert_signal_emit_count(_panel, "pause_requested", 1)
	_panel.set_interaction_blocked(true)
	assert_true(_panel.dock.buttons.pause.disabled)
	_panel.dock.action_requested.emit(&"pause")
	assert_signal_emit_count(_panel, "pause_requested", 1)
