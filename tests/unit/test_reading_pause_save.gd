extends GutTest
## Checkpoint composition only: the native suspension/resume contract remains covered
## by test_narrative_pause_frontier. This fixture never writes a player record.
const CONTROLLER := preload("res://scripts/application/lifecycle/ProductionPauseController.gd")
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const SURFACE := preload("res://scenes/overlay/PauseSurface.tscn")

class Coordinator extends Node:
	var admitted := true
	func request_lifecycle_command(_command: StringName) -> Dictionary: return {"ok": admitted}
	func get_state() -> Dictionary: return {"ok": true, "value": {"state": &"Suspended"}}

class Bridge extends RefCounted:
	var qualified := true
	var retained := true
	var captures: Array[bool] = []
	var checkpoint := {"timeline_id": "qualified.pre", "line_id": "qualified.first",
		"reading_session": {"version": 1, "session_id": "reading-session", "history": ["first"]}}
	func can_capture_reading_checkpoint() -> bool: return qualified
	func has_reading_session() -> bool: return retained
	func capture_reading_checkpoint(complete_reveal: bool = false) -> Dictionary:
		captures.append(complete_reveal)
		return {"ok": true, "value": checkpoint.duplicate(true)} if qualified else {"ok": false}

class BackupHost extends Control:
	var mode := &""
	var allow_entry := true
	var entry: Button
	func _ready() -> void:
		entry = Button.new()
		entry.text = "Slot 1"
		add_child(entry)
	func can_return_home() -> bool: return true
	func focus_entry(requested: StringName) -> bool:
		if not allow_entry: return false
		mode = requested
		entry.grab_focus()
		return true

class DatingOwner extends RefCounted:
	var record := {"physical_token": "reading-physical", "command_sha256": "reading-command",
		"completion_transaction_id": "reading-completion", "context": {"kind": "solo"}, "phase": "pre_challenge"}
	func capture_dating_challenge_state() -> Dictionary: return {"ok": true, "value": record.duplicate(true)}
	func pull_physical(_command: Dictionary) -> Dictionary: return {"ok": true, "value": {"phase": record.phase}}

var _controller: Node
var _coordinator: Coordinator
var _bridge: Bridge
var _caption: Node
var _native: DialogicNode_DialogText
var _dating: DatingOwner
var _inputs: Dictionary
var _provider_calls := 0
var _provider_effect := Callable()

func before_each() -> void:
	_provider_calls = 0
	_provider_effect = Callable()
	_controller = CONTROLLER.new()
	add_child(_controller)
	_coordinator = Coordinator.new()
	_controller.add_child(_coordinator)
	_controller.coordinator = _coordinator
	_bridge = Bridge.new()
	_dating = DatingOwner.new()
	_caption = CAPTION.new()
	_native = DialogicNode_DialogText.new()
	_caption.caption_text = _native
	_native.revealing = false
	_controller._caption = _caption
	_controller._handle = {"handle_id": "retained-reading-handle"}
	_controller._captured_source = {"route_id": "dating", "session": {"run_id": "retained-run"},
		"command": _dating.record.duplicate(true),
		"frontier": {"event_index": 7, "generation": 1, "request_id": "retained-request"}}
	_controller._services = {"bridge": _bridge, "backup_capture": _capture,
		"dating_presentation": _dating, "game_state": _dating}
	_inputs = {"snapshot_input": {"lifecycle": {"run_id": "retained-run"},
		"gameplay": {"route_context": {"active_dating_challenge": _dating.record.duplicate(true)}}},
		"route_id": "dating", "dialogic_checkpoint": _bridge.checkpoint.duplicate(true)}

func after_each() -> void:
	_controller.free()
	_caption.free()
	_native.free()

func _capture() -> Dictionary:
	_provider_calls += 1
	if _provider_effect.is_valid(): _provider_effect.call()
	return {"ok": true, "value": _inputs}

func test_qualified_full_line_save_captures_same_semantics_without_revealing_or_releasing() -> void:
	var held: Dictionary = _controller._handle.duplicate(true)
	var source: Dictionary = _controller._captured_source.duplicate(true)
	for query in 100: assert_true(_controller.can_save_backup())
	assert_eq(_bridge.captures, [], "capability never serializes the reading session")
	assert_eq(_provider_calls, 0)
	var result: Dictionary = _controller.capture_backup_checkpoint_inputs()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value, _inputs)
	assert_eq(_bridge.captures, [false, false], "suspended capture never completes live reveal")
	assert_eq(_provider_calls, 1)
	assert_eq(_controller._handle, held)
	assert_eq(_controller._captured_source, source)
	result.value.dialogic_checkpoint.reading_session.history.append("copy-only")
	assert_eq(_inputs.dialogic_checkpoint.reading_session.history, ["first"])

func test_partial_pause_and_unregistered_reading_remain_unavailable_without_capture() -> void:
	_native.revealing = true
	assert_false(_controller.can_save_backup())
	assert_eq(_controller.capture_backup_checkpoint_inputs().get("code"), &"pause_save_unavailable")
	_native.revealing = false
	_bridge.qualified = false
	assert_false(_controller.can_save_backup())
	assert_eq(_controller.capture_backup_checkpoint_inputs().get("code"), &"pause_save_unavailable")
	assert_eq(_bridge.captures, [])
	assert_eq(_provider_calls, 0)

func test_reading_capture_rejects_changed_route_run_checkpoint_or_semantic_source() -> void:
	var held: Dictionary = _controller._handle.duplicate(true)
	var initial: Dictionary = _inputs.duplicate(true)
	for field: String in ["route", "run", "checkpoint", "record", "live_record", "live", "admission"]:
		_inputs = initial.duplicate(true)
		_bridge.checkpoint = initial.dialogic_checkpoint.duplicate(true)
		_dating.record = initial.snapshot_input.gameplay.route_context.active_dating_challenge.duplicate(true)
		_coordinator.admitted = true
		_provider_effect = Callable()
		if field == "route": _inputs.route_id = "main"
		elif field == "run": _inputs.snapshot_input.lifecycle.run_id = "foreign-run"
		elif field == "checkpoint": _inputs.dialogic_checkpoint.line_id = "foreign-line"
		elif field == "record": _inputs.snapshot_input.gameplay.route_context.active_dating_challenge.physical_token = "foreign-command"
		elif field == "live_record":
			_provider_effect = func() -> void: _dating.record.physical_token = "foreign-command"
		elif field == "live":
			_provider_effect = func() -> void: _bridge.checkpoint.line_id = "foreign-line"
		else:
			_provider_effect = func() -> void: _coordinator.admitted = false
		var refused: Dictionary = _controller.capture_backup_checkpoint_inputs()
		assert_eq(refused.get("code"), &"pause_source_changed", field)
		assert_eq(_controller._handle, held, "failure preserves the exact suspension")
		assert_false(_native.revealing)

func test_history_custody_blocks_backup_and_quick_without_discarding_pause_handle() -> void:
	var held: Dictionary = _controller._handle.duplicate(true)
	_controller._history_caption = _caption
	assert_true(_controller.is_witnessed_history_open(_caption))
	assert_false(_controller._quick_input_admitted())
	assert_false(_controller.can_save_backup())
	assert_false(_controller.can_load_backup())
	assert_eq(_controller._backup_admission().get("code"), &"pause_backup_unavailable")
	assert_eq(_controller._handle, held)
	assert_eq(_provider_calls, 0)
	_controller._history_caption = null
	assert_true(_controller.can_save_backup())

func _use_paused_board() -> void:
	_controller._captured_source.frontier = {}
	_controller._caption = null
	_dating.record.phase = "challenge"
	_dating.record["board"] = {"revision": 9, "flags": [2, 7], "revealed": [0, 1]}
	_bridge.checkpoint.reading_session["boundary"] = "between_entries"
	_bridge.checkpoint.reading_session["frontier"] = {}
	_inputs.dialogic_checkpoint = _bridge.checkpoint.duplicate(true)
	_inputs.snapshot_input.gameplay.route_context.active_dating_challenge = _dating.record.duplicate(true)

func test_paused_board_save_retains_earlier_reading_history_and_exact_board_without_reveal() -> void:
	_use_paused_board()
	var held: Dictionary = _controller._handle.duplicate(true)
	var record: Dictionary = _dating.record.duplicate(true)
	assert_true(_controller.can_save_backup())
	var saved: Dictionary = _controller.capture_backup_checkpoint_inputs()
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false): return
	assert_eq(saved.value.dialogic_checkpoint, _bridge.checkpoint)
	assert_eq(saved.value.dialogic_checkpoint.reading_session.history, ["first"])
	assert_eq(saved.value.snapshot_input.gameplay.route_context.active_dating_challenge, record)
	assert_eq(_dating.record, record)
	assert_eq(_controller._handle, held)
	assert_eq(_bridge.captures, [false, false])

func test_paused_board_refuses_reading_history_drift_or_a_live_line_boundary() -> void:
	_use_paused_board()
	var held: Dictionary = _controller._handle.duplicate(true)
	_provider_effect = func() -> void: _bridge.checkpoint.reading_session.history.append("foreign")
	var refused: Dictionary = _controller.capture_backup_checkpoint_inputs()
	assert_eq(refused.get("code"), &"pause_source_changed")
	assert_eq(_controller._handle, held)
	_provider_calls = 0
	_provider_effect = Callable()
	_bridge.checkpoint.reading_session.boundary = "line"
	refused = _controller.capture_backup_checkpoint_inputs()
	assert_eq(refused.get("code"), &"pause_source_changed")
	assert_eq(_provider_calls, 0, "a retained live line cannot masquerade as an idle board checkpoint")

func test_router_reading_facades_refuse_without_a_production_owner() -> void:
	var router: Node = preload("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)
	assert_false(router.can_open_witnessed_backup_save(_caption))
	assert_false((await router.open_witnessed_backup_save(_caption)).get("ok", true))
	assert_false(router.can_open_witnessed_history(_caption))
	assert_false((await router.open_witnessed_history(_caption)).get("ok", true))
	assert_false(router.is_witnessed_history_open(_caption))
	assert_false((await router.close_witnessed_history(_caption)).get("ok", true))

func test_direct_backup_save_uses_save_mode_and_failed_entry_keeps_continue_focus() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var surface: Control = SURFACE.instantiate()
	viewport.add_child(surface)
	var host := BackupHost.new()
	assert_true(surface.set_host(&"backup", host))
	surface.open_surface()
	host.allow_entry = false
	assert_false(surface.open_backup_save())
	assert_eq(surface.entered_action, &"")
	assert_true(surface.rows[&"continue"].has_focus())
	host.allow_entry = true
	assert_true(surface.open_backup_save())
	assert_eq(surface.entered_action, &"backup")
	assert_eq(host.mode, &"save")
	assert_true(host.entry.has_focus())
	assert_false(surface.open_backup_save(), "duplicate activation cannot reenter Backup")
	assert_false(surface.open_backup_load(), "another mode cannot displace the hosted Save")
