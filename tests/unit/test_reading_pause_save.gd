extends GutTest
## Manual checkpoint admission/composition: the native suspension/resume contract remains
## covered by test_narrative_pause_frontier. This fixture never writes a player record.
const CONTROLLER := preload("res://scripts/application/lifecycle/ProductionPauseController.gd")
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const SURFACE := preload("res://scenes/overlay/PauseSurface.tscn")
const BACKUP_PORT := preload("res://scripts/application/lifecycle/PauseBackupPresentationPort.gd")
const HOSPITAL_FIXTURE := preload("res://tests/unit/test_reading_restore_admission.gd")
const CANON := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const HOSPITAL_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")

class BackupCommitOwner extends RefCounted:
	var calls: Array[String] = []
	func commit_backup_action(token: String) -> Dictionary:
		calls.append("commit:" + token)
		return {"ok": true}
	func cancel_backup_action(token: String) -> void: calls.append("cancel:" + token)

# Capability double only; the real Pause/Backup port owns route admission and tokens.
class QuickCapabilityOwner extends BackupCommitOwner:
	var prepares := 0
	func inspect_backup(_locator: String) -> Dictionary: return {"ok": true, "value": _record()}
	func get_backup_save_capability() -> Dictionary: return {"enabled": true}
	func prepare_backup_action(_action: String, _locator: String) -> Dictionary: return {"ok": true}
	func get_backup_quick_capability(action: String) -> Dictionary:
		return {"ok": true, "value": {"enabled": true, "condition": {"action": action}}}
	func is_quick_condition_current(_condition: Dictionary) -> bool: return true
	func prepare_quick_backup_action(action: String) -> Dictionary:
		prepares += 1
		return {"ok": true, "value": {"token": "quick:" + action, "record": _record(), "condition": {"action": action}}}
	func _record() -> Dictionary:
		return {"locator": "quick", "state": "valid", "day": 1, "saved_time": "fixture",
			"fallback": false, "load_day": 1, "load_saved_time": "fixture", "reason": "",
			"revision": "fixture-revision", "operation_allowed": true, "loadable": true}

class PausePreparation extends RefCounted:
	var owner: BackupCommitOwner
	var prepared := true
	func prepare_backup_save() -> Dictionary:
		owner.calls.append("prepare")
		return {"ok": prepared, "code": &"pause_source_changed"}
	func release_for_backup_load() -> Dictionary:
		owner.calls.append("release-load")
		return {"ok": true}
	func finish_backup_load(result: Dictionary) -> Dictionary:
		owner.calls.append("finish-load")
		return result

class Coordinator extends Node:
	var admitted := true
	func request_lifecycle_command(_command: StringName) -> Dictionary: return {"ok": admitted}
	func get_state() -> Dictionary: return {"ok": true, "value": {"state": &"Suspended"}}

class Bridge extends RefCounted:
	var qualified := true
	var retained := true
	var captures: Array[bool] = []
	var hospital_command: Dictionary = {}
	var checkpoint := {"timeline_id": "qualified.pre", "line_id": "qualified.first",
		"reading_session": {"version": 1, "session_id": "reading-session", "history": ["first"]}}
	func can_capture_reading_checkpoint() -> bool: return qualified
	func has_reading_session() -> bool: return retained
	func can_capture_hospital_reading_checkpoint(command: Dictionary) -> bool:
		return qualified and retained and not hospital_command.is_empty() and command == hospital_command
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

class HospitalOwner extends RefCounted:
	var physical: Dictionary = {}
	var snapshot: Dictionary = {}
	var session: Dictionary = {}
	var queries := 0
	func capture_pause_source() -> Dictionary:
		queries += 1
		return {"ok": true, "value": physical.duplicate(true)}
	func capture_run_snapshot_input() -> Dictionary: return snapshot.duplicate(true)
	func capture_live_session() -> Dictionary: return {"ok": true, "value": session.duplicate(true)}
	func validate_live_session(expected: Dictionary) -> Dictionary: return {"ok": expected == session}

class RailController extends "res://scripts/application/lifecycle/ProductionPauseController.gd":
	func _can_open_witnessed_surface(_caption: Node) -> bool: return true

class HospitalRouter extends Node:
	var route := "hospital"
	func get_current_route_id() -> String: return route

class HospitalSceneProbe extends Control:
	var command: Dictionary = {}
	func get_presentation_projection() -> Dictionary: return command.duplicate(true)

class RetirementBridge extends Node:
	var retired: Array[Dictionary] = []
	func retire_completed_hospital_reading(command: Dictionary) -> Dictionary:
		retired.append(command.duplicate(true))
		return {"ok": true}

class RetirementGame extends Node:
	var session := {"active": true, "run_id": "hospital-run", "generation": 1}
	func capture_live_session() -> Dictionary: return {"ok": true, "value": session.duplicate(true)}

class EndingRetirementLifecycle extends RefCounted:
	var state := "ENDING"
	func to_dict() -> Dictionary: return {"state": state, "run_id": "ending-run"}

class EndingRetirementGame extends RetirementGame:
	var _run_lifecycle := EndingRetirementLifecycle.new()

class EndingRetirementRouter extends HospitalRouter:
	var held := false
	func is_restore_publication_held() -> bool: return held

class EndingRetirementBridge extends Node:
	var retained := true
	var active := false
	var retirements := 0
	var anchor := {"reading_session": {"ledger": {"session_token": "ending-run:ending"}}}
	func has_active_playback() -> bool: return active
	func has_reading_session() -> bool: return retained
	func capture_ending_physical_checkpoint() -> Dictionary: return {"ok": true, "value": anchor.duplicate(true)}
	func retire_reading_session() -> void:
		retirements += 1
		retained = false

class RetirementBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}
	func _ready() -> void: pass
	func _target(key: StringName) -> Node: return targets.get(key)

var _controller: Node
var _coordinator: Coordinator
var _bridge: Bridge
var _caption: Node
var _native: DialogicNode_DialogText
var _dating: DatingOwner
var _inputs: Dictionary
var _provider_calls := 0
var _provider_effect := Callable()
var _prior_scene: Node
var _prior_tree_paused := false

func before_each() -> void:
	_prior_scene = get_tree().current_scene
	_prior_tree_paused = get_tree().paused
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
	get_tree().paused = _prior_tree_paused
	get_tree().current_scene = _prior_scene if is_instance_valid(_prior_scene) else null
	_controller.free()
	_caption.free()
	_native.free()

func _capture() -> Dictionary:
	_provider_calls += 1
	if _provider_effect.is_valid(): _provider_effect.call()
	return {"ok": true, "value": _inputs}

func _use_hospital() -> HospitalOwner:
	var fixture: Node = autofree(HOSPITAL_FIXTURE.new())
	fixture.gut = gut
	var snapshot: Dictionary = fixture._hospital_snapshot()
	var owner := HospitalOwner.new()
	owner.snapshot = snapshot.duplicate(true)
	owner.session = {"active": true, "run_id": snapshot.lifecycle.run_id, "generation": 1}
	var request: Dictionary = snapshot.gameplay.route_context.hospital_frozen_contexts_v1.requests[snapshot.lifecycle.active_resolution_plan.resolution_id]
	var command := request.duplicate(true)
	command["command_sha256"] = CANON.canonical_sha256(request).value.sha256
	command["physical_token"] = HOSPITAL_OWNER.derive_token(command.completion_transaction_id, command.command_sha256)
	_bridge.hospital_command = command.duplicate(true)
	_bridge.checkpoint = snapshot.narrative_checkpoint.duplicate(true)
	_controller._captured_source = {"route_id": "hospital", "command": command,
		"session": owner.session.duplicate(true), "frontier": {"event_index": 1, "generation": 1, "request_id": "hospital-native"}}
	owner.physical = {}
	for key: String in ["physical_token", "command_sha256", "completion_transaction_id", "timeline_id", "route_id"]:
		owner.physical[key] = command[key]
	owner.physical["frontier"] = _controller._captured_source.frontier.duplicate(true)
	_controller._services["game_state"] = owner
	_controller._services["hospital_physical"] = owner
	_inputs = {"route_id": "hospital", "dialogic_checkpoint": _bridge.checkpoint.duplicate(true),
		"snapshot_input": snapshot.duplicate(true), "active_app_id": null, "audio_context": {}, "content_version": 1}
	return owner

func test_hospital_manual_save_and_load_refuse_without_capture_or_reveal() -> void:
	var owner := _use_hospital()
	_native.revealing = true
	_native.visible_characters = 3
	var before: Dictionary = _inputs.duplicate(true)
	var source: Dictionary = _controller._captured_source.duplicate(true)
	assert_false(_controller.can_save_backup())
	assert_false(_controller.can_load_backup())
	assert_eq(_controller.capture_backup_checkpoint_inputs().get("code"), &"pause_save_unavailable")
	var load_result: Dictionary = await _controller.release_for_backup_load()
	assert_eq(load_result.get("code"), &"pause_load_unavailable")
	assert_true(_controller.prepare_backup_save().get("ok", false), "inspection-only Backup remains available")
	assert_eq(_provider_calls, 0)
	assert_eq(owner.queries, 0)
	assert_eq(_bridge.captures, [])
	assert_true(_native.revealing)
	assert_eq(_native.visible_characters, 3)
	assert_eq(_controller._captured_source, source)
	assert_eq(_inputs, before)

func test_hospital_live_rail_disables_save_load_but_preserves_history() -> void:
	_use_hospital()
	var rail: Node = autofree(RailController.new())
	add_child(rail)
	var router: Node = autofree(HospitalRouter.new())
	rail._router = router
	rail._services = _controller._services
	assert_false(rail.can_open_witnessed_backup_save(_caption))
	assert_false(rail.can_open_witnessed_backup_load(_caption))
	assert_true(rail.can_open_witnessed_history(_caption))
	assert_eq(_bridge.captures, [])
	assert_eq(_provider_calls, 0)
	# The restriction belongs to Hospital, not the shared rail or History.
	router.route = "dating"
	assert_true(rail.can_open_witnessed_backup_save(_caption))
	assert_true(rail.can_open_witnessed_backup_load(_caption))
	assert_true(rail.can_open_witnessed_history(_caption))

func test_hospital_pause_quick_commands_share_manual_restriction() -> void:
	var dating_source: Dictionary = _controller._captured_source.duplicate(true)
	_use_hospital()
	var owner := QuickCapabilityOwner.new()
	var port := BACKUP_PORT.new()
	assert_true(port.configure_pause(owner, _controller).get("ok", false))
	for action: String in ["save", "load"]:
		assert_false(port._quick_available(action), action)
		assert_false(port.get_quick_capability(action).get("value", {}).get("enabled", true), action)
		assert_false(port.prepare_quick_action(action).get("ok", true), action)
	assert_eq(owner.prepares, 0, "Hospital refuses before reaching the enabled SaveManager double")
	assert_eq(_bridge.captures, [])
	assert_eq(_provider_calls, 0)
	# The same configured port and dependencies admit both commands for ordinary Dating.
	_controller._captured_source = dating_source
	for action: String in ["save", "load"]:
		assert_true(port._quick_available(action), action)
		assert_true(port.get_quick_capability(action).get("value", {}).get("enabled", false), action)
		var prepared: Dictionary = port.prepare_quick_action(action)
		assert_true(prepared.get("ok", false), action)
		if prepared.get("ok", false): port.cancel_action(prepared.value.token)
	assert_eq(owner.prepares, 2)

func test_hospital_restriction_also_applies_without_a_reading_frontier() -> void:
	_use_hospital()
	_controller._captured_source.frontier = {}
	assert_false(_controller.can_save_backup())
	assert_false(_controller.can_load_backup())
	assert_eq(_controller.capture_backup_checkpoint_inputs().get("code"), &"pause_save_unavailable")
	assert_eq(_bridge.captures, [])
	assert_eq(_provider_calls, 0)

func test_hospital_save_manager_capture_accepts_only_qualified_line_without_mutation() -> void:
	_use_hospital()
	var manager: Node = autofree(preload("res://autoload/SaveManager.gd").new())
	var files := preload("res://tests/support/FakeFileOps.gd").new()
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("memory/hospital-reading-save", files)
	assert_true(manager.initialize(storage).get("ok", false))
	assert_true(manager.configure_backup_capture_provider(_capture).get("ok", false))
	var persisted: Dictionary = files.snapshot_persisted()
	var journal: Dictionary = manager._journal.capture_state()
	var qualified: Dictionary = _inputs.duplicate(true)
	var captured: Dictionary = manager._capture_backup_inputs()
	assert_true(captured.get("ok", false), str(captured))
	if not captured.get("ok", false): return
	assert_eq(captured.value, qualified)
	for field: String in ["empty", "downgraded", "foreign_family", "condition", "wrong_authority", "completed_boundary"]:
		_inputs = qualified.duplicate(true)
		if field == "empty": _inputs.dialogic_checkpoint = {}
		elif field == "downgraded": _inputs.dialogic_checkpoint.reading_session.schema_version = 1
		elif field == "foreign_family": _inputs.dialogic_checkpoint.reading_session.family = "solo"
		elif field == "condition":
			var checkpoint: Dictionary = _inputs.dialogic_checkpoint
			checkpoint.frozen_context.presentation.fields.qualifying_cause = "condition_hospital"
			checkpoint.reading_session.ledger.entry_contexts[checkpoint.entry_id] = checkpoint.frozen_context.duplicate(true)
		elif field == "wrong_authority": _inputs.snapshot_input.contacts.clear()
		else:
			_inputs.dialogic_checkpoint.reading_session.boundary = "between_entries"
			_inputs.dialogic_checkpoint.reading_session.frontier = {}
		assert_false(manager._capture_backup_inputs().get("ok", true), field)
		assert_eq(files.snapshot_persisted(), persisted, field)
		assert_eq(manager._journal.capture_state(), journal, field)
		assert_true(manager._backup_actions.is_empty(), field)
		assert_eq(manager._backup_action_sequence, 0, field)
		assert_false(manager._pending_deferred_save, field)

func test_bootstrap_hospital_provider_requires_paused_exact_registered_scene() -> void:
	_use_hospital()
	var bootstrap: Node = RetirementBootstrap.new()
	add_child_autofree(bootstrap)
	var prior := get_tree().current_scene
	var was_paused := get_tree().paused
	var scene := HospitalSceneProbe.new()
	get_tree().root.add_child(autofree(scene))
	scene.scene_file_path = "res://scenes/hospital/HospitalScene.tscn"
	scene.command = _bridge.hospital_command.duplicate(true)
	get_tree().current_scene = scene
	get_tree().paused = false
	assert_false(bootstrap._capture_dating_reading_checkpoint(_bridge, "hospital").get("ok", true))
	assert_eq(_bridge.captures, [])
	get_tree().paused = true
	var captured: Dictionary = bootstrap._capture_dating_reading_checkpoint(_bridge, "hospital")
	assert_true(captured.get("ok", false), str(captured))
	assert_eq(captured.get("value"), _bridge.checkpoint)
	assert_eq(_bridge.captures, [false])
	scene.command.physical_token = "foreign-source"
	assert_false(bootstrap._capture_dating_reading_checkpoint(_bridge, "hospital").get("ok", true))
	assert_eq(_bridge.captures, [false])
	get_tree().paused = was_paused
	get_tree().current_scene = prior

func test_hospital_completed_anchor_retires_only_after_actual_main_publication() -> void:
	var bootstrap: Node = RetirementBootstrap.new()
	add_child_autofree(bootstrap)
	var game: Node = autofree(RetirementGame.new())
	var bridge: Node = autofree(RetirementBridge.new())
	var router: Node = autofree(HospitalRouter.new())
	router.route = "main"
	bootstrap.targets = {&"GameState": game, &"DialogicBridge": bridge, &"SceneRouter": router}
	var prior := get_tree().current_scene
	var hospital := Control.new()
	get_tree().root.add_child(autofree(hospital))
	hospital.scene_file_path = "res://scenes/hospital/HospitalScene.tscn"
	get_tree().current_scene = hospital
	var command := {"completion_transaction_id": "completed-hospital"}
	bootstrap._retire_completed_hospital_after_main(command, game.session.duplicate(true))
	assert_eq(bridge.retired, [], "a route flag does not prove destination publication")
	var destination := Control.new()
	get_tree().root.add_child(autofree(destination))
	destination.scene_file_path = "res://scenes/main/MainGameScene.tscn"
	get_tree().current_scene = destination
	get_tree().scene_changed.emit()
	assert_eq(bridge.retired, [command])
	await bootstrap._retire_completed_hospital_after_main({}, game.session.duplicate(true))
	assert_eq(bridge.retired, [command, {}], "completed-stage restore can carry its validated anchor without reconstructing a physical command")
	get_tree().current_scene = prior

func test_hospital_anchor_retirement_refuses_replaced_live_session_after_publication() -> void:
	var bootstrap: Node = RetirementBootstrap.new()
	add_child_autofree(bootstrap)
	var game: Node = autofree(RetirementGame.new())
	var bridge: Node = autofree(RetirementBridge.new())
	var router: Node = autofree(HospitalRouter.new())
	router.route = "main"
	bootstrap.targets = {&"GameState": game, &"DialogicBridge": bridge, &"SceneRouter": router}
	var prior := get_tree().current_scene
	var destination := Control.new()
	get_tree().root.add_child(autofree(destination))
	destination.scene_file_path = "res://scenes/main/MainGameScene.tscn"
	get_tree().current_scene = destination
	var session: Dictionary = game.session.duplicate(true)
	game.session.generation += 1
	await bootstrap._retire_completed_hospital_after_main({"completion_transaction_id": "old-hospital"}, session)
	assert_eq(bridge.retired, [])
	get_tree().current_scene = prior

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

func test_partial_pause_capability_and_capture_are_available_without_finishing_literal_reveal() -> void:
	_native.revealing = true
	_native.visible_characters = 7
	var generation := _native.get_reveal_generation()
	var source: Dictionary = _controller._captured_source.duplicate(true)
	var held: Dictionary = _controller._handle.duplicate(true)
	for query in 100: assert_true(_controller.can_save_backup())
	assert_eq(_bridge.captures, [], "capability never serializes or finishes the partial line")
	assert_eq(_provider_calls, 0)
	var captured: Dictionary = _controller.capture_backup_checkpoint_inputs()
	assert_true(captured.get("ok", false), str(captured))
	assert_eq(_bridge.captures, [false, false])
	assert_eq(_provider_calls, 1)
	assert_true(_native.revealing, "SaveManager also calls providers for background capability")
	assert_eq(_native.visible_characters, 7)
	assert_eq(_native.get_reveal_generation(), generation)
	assert_eq(_controller._captured_source, source)
	assert_eq(_controller._handle, held)

func test_unregistered_reading_stays_unavailable_without_capture() -> void:
	_bridge.qualified = false
	assert_false(_controller.can_save_backup())
	assert_eq(_controller.capture_backup_checkpoint_inputs().get("code"), &"pause_save_unavailable")
	assert_eq(_bridge.captures, [])
	assert_eq(_provider_calls, 0)

func test_refused_explicit_preparation_cannot_capture_or_finish_partial_reading() -> void:
	_native.revealing = true
	_coordinator.admitted = false
	assert_false(_controller.prepare_backup_save().get("ok", true))
	assert_true(_native.revealing)
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
	assert_true(_controller.prepare_backup_save().get("ok", false))
	assert_eq(_bridge.captures, [], "explicit Backup preparation leaves an exact board alone")
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

func test_paused_save_commit_prepares_reveal_once_before_owner_commit_and_consumes_token() -> void:
	var owner := BackupCommitOwner.new()
	var pause := PausePreparation.new()
	pause.owner = owner
	var port := BACKUP_PORT.new()
	port._owner = owner
	port._pause = pause
	port._pending["quick-save"] = {"action": "save", "locator": "quick", "quick": true}
	var result: Dictionary = await port.commit_action("quick-save")
	assert_true(result.get("ok", false), str(result))
	assert_eq(owner.calls, ["prepare", "commit:quick-save"])
	assert_true(port._pending.is_empty())
	assert_false((await port.commit_action("quick-save")).get("ok", true))
	assert_eq(owner.calls, ["prepare", "commit:quick-save"], "stale activation cannot repeat reveal")

func test_refused_paused_save_preparation_cancels_exact_token_before_commit_and_load_stays_literal() -> void:
	var owner := BackupCommitOwner.new()
	var pause := PausePreparation.new()
	pause.owner = owner
	pause.prepared = false
	var port := BACKUP_PORT.new()
	port._owner = owner
	port._pause = pause
	port._pending["manual-save"] = {"action": "save", "locator": "slot:1"}
	var refused: Dictionary = await port.commit_action("manual-save")
	assert_eq(refused.get("code"), &"pause_source_changed")
	assert_eq(owner.calls, ["prepare", "cancel:manual-save"])
	assert_true(port._pending.is_empty())
	owner.calls.clear()
	port._pending["load"] = {"action": "load", "locator": "slot:1"}
	assert_true((await port.commit_action("load")).get("ok", false))
	assert_eq(owner.calls, ["release-load", "commit:load", "finish-load"], "Load never prepares reveal")

func test_ending_terminal_anchor_retires_only_for_completed_current_run_after_menu_publication() -> void:
	var bootstrap: Node = RetirementBootstrap.new()
	add_child_autofree(bootstrap)
	var game: Node = autofree(EndingRetirementGame.new())
	var bridge: Node = autofree(EndingRetirementBridge.new())
	var router: Node = autofree(EndingRetirementRouter.new())
	router.route = "menu"
	game.session = {"active": false, "run_id": "ending-run", "generation": 2}
	bootstrap.targets = {&"GameState": game, &"DialogicBridge": bridge, &"SceneRouter": router}
	var scene := Control.new()
	get_tree().root.add_child(autofree(scene))
	scene.scene_file_path = "res://scenes/ending/EndingScene.tscn"
	get_tree().current_scene = scene
	game._run_lifecycle.state = "COMPLETED"
	bootstrap._retire_completed_ending_after_menu()
	assert_eq(bridge.retirements, 0, "route intent alone cannot retire the terminal anchor")
	scene.scene_file_path = "res://scenes/menu/MenuScene.tscn"
	game._run_lifecycle.state = "ENDING"
	bootstrap._retire_completed_ending_after_menu()
	assert_eq(bridge.retirements, 0, "unfinished ending History stays available")
	game._run_lifecycle.state = "COMPLETED"
	game.session.active = true
	bootstrap._retire_completed_ending_after_menu()
	assert_eq(bridge.retirements, 0, "the committed owner must retire its live session first")
	game.session.active = false
	router.held = true
	bootstrap._retire_completed_ending_after_menu()
	assert_eq(bridge.retirements, 0, "restore publication custody is preserved")
	router.held = false
	bridge.anchor.reading_session.ledger.session_token = "other-run:ending"
	bootstrap._retire_completed_ending_after_menu()
	assert_eq(bridge.retirements, 0, "an old callback cannot retire another run's History")
	bridge.anchor.reading_session.ledger.session_token = "ending-run:ending"
	var anchor: Dictionary = bridge.anchor.duplicate(true)
	bootstrap._retire_completed_ending_after_menu()
	bootstrap._retire_completed_ending_after_menu()
	assert_eq(bridge.retirements, 1)
	assert_eq(bridge.anchor, anchor, "retirement clears live custody without modifying saved anchor bytes")
