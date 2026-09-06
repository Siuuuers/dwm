extends "res://addons/gut/test.gd"
## Transactional custody tests. Port doubles expose mutations and asynchronous frontiers;
## installed Dialogic coverage lives in test_narrative_pause_frontier.gd.

const COORDINATOR := preload("res://scripts/application/lifecycle/ApplicationLifecycleCoordinator.gd")

class SourceOwner extends RefCounted:
	var source := {"route_id": "hospital", "timeline_id": "hospital.faint", "physical_token": "fixture-token",
		"command_sha256": "c".repeat(64), "completion_transaction_id": "fixture-completion", "revision": 1,
		"frontier": {"generation": 1, "event_index": 0, "request_id": "fixture-request"}}
	func capture_pause_source() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": source.duplicate(true)}

class SourceScene extends Control:
	var projection: Dictionary
	func get_presentation_projection() -> Dictionary:
		return projection.duplicate(true)

class SourceView extends Node:
	var calls: Array = []
	var covered := false
	var restore_ok := true
	var cover_ok := true
	var on_cover := Callable()
	var on_restore := Callable()
	var anchor := {"focus": "fixture-current", "scroll": 73.0}
	func capture_pause_view(_source: Dictionary) -> Dictionary:
		calls.append("capture")
		return {"ok": true, "code": &"ok", "value": anchor.duplicate(true)}
	func cover_pause_view(value: Dictionary) -> bool:
		calls.append("cover")
		if on_cover.is_valid(): on_cover.call()
		if not cover_ok or value != anchor: return false
		covered = true
		return true
	func restore_pause_view(value: Dictionary) -> bool:
		calls.append("restore")
		if on_restore.is_valid(): on_restore.call()
		if not restore_ok or value != anchor: return false
		covered = false
		return true

class Gate extends RefCounted:
	var allowed := true
	func guard_external(_command: StringName) -> Dictionary:
		return {"ok": allowed, "code": &"ok" if allowed else &"gate_busy", "value": {}}

class Router extends RefCounted:
	var route := "hospital"
	func get_current_route_id() -> String:
		return route

class Port extends RefCounted:
	var label := ""
	var log: Array
	var tree: SceneTree
	var state := &"Active"
	var held: Dictionary = {}
	var begin_ok := true
	var state_after_begin := &"Suspended"
	var state_readable := true
	var resume_ok := true
	var state_after_resume := &"Active"
	var on_begin := Callable()
	var on_resume := Callable()
	var yield_begin := false
	var yield_resume := false
	func begin_suspend(handle: Dictionary) -> Dictionary:
		log.append("begin:" + label)
		held = handle.duplicate(true)
		state = state_after_begin
		if on_begin.is_valid(): on_begin.call()
		if yield_begin: await tree.process_frame
		return {"ok": begin_ok, "code": &"ok" if begin_ok else &"fixture_begin_failed", "value": {"frontier_id": "fixture:" + label}}
	func resume(handle: Dictionary) -> Dictionary:
		log.append("resume:" + label)
		if on_resume.is_valid(): on_resume.call()
		if yield_resume: await tree.process_frame
		if not resume_ok or handle != held:
			return {"ok": false, "code": &"fixture_resume_failed", "value": null}
		state = state_after_resume
		if state == &"Active": held.clear()
		return {"ok": true, "code": &"ok", "value": {"resumed": true}}
	func get_state() -> Dictionary:
		return {"ok": state_readable, "code": &"ok" if state_readable else &"fixture_state_unknown", "value": {"state": state}}

var _coordinator: Node
var _owner: SourceOwner
var _scene: SourceScene
var _view: SourceView
var _gate: Gate
var _router: Router
var _input: Port
var _dialogic: Port
var _audio: Port
var _log: Array
var _original_scene: Node
var _old_process_mode: int
var _async_result: Dictionary

func before_each() -> void:
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_scene = get_tree().current_scene
	_log = []
	_async_result = {}
	_owner = SourceOwner.new()
	_gate = Gate.new()
	_router = Router.new()
	_scene = SourceScene.new()
	_scene.projection = _owner.source.duplicate(true)
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_view = SourceView.new()
	_scene.add_child(_view)
	_input = _port("input")
	_dialogic = _port("dialogic")
	_audio = _port("audio")
	_coordinator = COORDINATOR.new()
	add_child(_coordinator)
	assert_true(_coordinator.configure(_owner, _dialogic, _input, _audio, _gate, _router).ok)
	assert_true(_coordinator.bind_source(_scene, _view).ok)
	watch_signals(_coordinator)

func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _original_scene
	_coordinator.free()
	_scene.free()
	process_mode = _old_process_mode

func _port(label: String) -> Port:
	var port := Port.new()
	port.label = label
	port.log = _log
	port.tree = get_tree()
	return port

func _open_async() -> void:
	_async_result = await _coordinator.request_pause(&"pause_fixture")

func _resume_async(handle: Dictionary) -> void:
	_async_result = await _coordinator.request_resume(handle)

func test_source_qualification_refuses_wrong_scene_route_projection_and_gate_without_port_calls() -> void:
	_router.route = "desktop"
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	_router.route = "hospital"
	_scene.projection.physical_token = "foreign"
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	_scene.projection = _owner.source.duplicate(true)
	_gate.allowed = false
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	_gate.allowed = true
	get_tree().current_scene = _original_scene
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	get_tree().current_scene = _scene
	assert_eq(_log, [])
	assert_eq(_view.calls, [])
	assert_true(_coordinator.is_foreground_admitted())
	assert_false(get_tree().paused)
	assert_false(_coordinator.configure(_owner, _dialogic, _input, _audio, _gate, _router).ok)

func test_acquisition_and_release_order_hold_tree_until_every_port_is_active() -> void:
	var handle: Dictionary = (await _coordinator.request_pause(&"pause_fixture")).value
	assert_eq(_log, ["begin:input", "begin:dialogic", "begin:audio"])
	assert_eq(_input.held, handle)
	assert_eq(_dialogic.held, handle)
	assert_eq(_audio.held, handle)
	assert_true(get_tree().paused)
	assert_true(_view.covered)
	assert_false(_coordinator.is_foreground_admitted())
	assert_signal_emit_count(_coordinator, "pause_opened", 1)
	var paused_during_release: Array = []
	for port: Port in [_audio, _dialogic, _input]:
		port.on_resume = func(): paused_during_release.append(get_tree().paused)
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_eq(_log, ["begin:input", "begin:dialogic", "begin:audio", "resume:audio", "resume:dialogic", "resume:input"])
	assert_eq(paused_during_release, [true, true, true])
	assert_eq(_view.calls, ["capture", "cover", "restore"])
	assert_false(_view.covered)
	assert_false(get_tree().paused)
	assert_true(_coordinator.is_foreground_admitted())
	assert_signal_emit_count(_coordinator, "pause_closed", 1)

func test_failed_but_suspended_port_is_compensated_before_prior_ports() -> void:
	_dialogic.begin_ok = false
	var result: Dictionary = await _coordinator.request_pause(&"pause_fixture")
	assert_false(result.ok)
	assert_eq(_log, ["begin:input", "begin:dialogic", "resume:dialogic", "resume:input"])
	assert_eq(_dialogic.state, &"Active")
	assert_eq(_input.state, &"Active")
	assert_true(_coordinator.is_foreground_admitted())
	assert_false(get_tree().paused)
	assert_eq(_coordinator.get_state().value.handle, {})
	assert_signal_not_emitted(_coordinator, "pause_opened")

func test_unknown_failed_acquisition_cannot_drop_mutated_port_or_publish_active() -> void:
	_dialogic.begin_ok = false
	_dialogic.state_after_begin = &"Unknown"
	_dialogic.on_begin = func(): _dialogic.state_readable = false
	_dialogic.resume_ok = false
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	assert_eq(_log, ["begin:input", "begin:dialogic"], "uncertain mutation retains prior custody until explicit recovery")
	assert_eq(_input.state, &"Suspended")
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	assert_false(_coordinator.get_state().value.handle.is_empty(), "retain exact custody for recovery/retry")
	assert_false(_coordinator.is_foreground_admitted())
	assert_false(_coordinator.request_lifecycle_command(&"pause.settings").ok)
	assert_signal_not_emitted(_coordinator, "pause_opened")
	assert_signal_not_emitted(_coordinator, "pause_closed")
	assert_signal_emit_count(_coordinator, "pause_recovery_required", 1)
	_dialogic.state_readable = true
	_dialogic.resume_ok = true
	var handle: Dictionary = _coordinator.get_state().value.handle
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_eq(_dialogic.state, &"Active")
	assert_eq(_input.state, &"Active")
	assert_true(_coordinator.is_foreground_admitted())

func test_source_mutation_during_acquire_keeps_recovery_until_exact_source_returns() -> void:
	_dialogic.on_begin = func(): _owner.source.revision += 1
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	assert_eq(_log, ["begin:input", "begin:dialogic", "resume:dialogic"])
	assert_true(get_tree().paused)
	assert_signal_not_emitted(_coordinator, "pause_opened")
	assert_false(_coordinator.is_foreground_admitted())
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	var handle: Dictionary = _coordinator.get_state().value.handle
	assert_false(handle.is_empty())
	_owner.source.revision = 1
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_eq(_log, ["begin:input", "begin:dialogic", "resume:dialogic", "resume:input"])
	assert_false(get_tree().paused)
	assert_true(_coordinator.is_foreground_admitted())

func test_partial_resume_failure_keeps_tree_paused_and_retries_only_unreleased_ports() -> void:
	var handle: Dictionary = (await _coordinator.request_pause(&"pause_fixture")).value
	_dialogic.resume_ok = false
	assert_false((await _coordinator.request_resume(handle)).ok)
	assert_eq(_log.slice(3), ["resume:audio", "resume:dialogic"])
	assert_eq(_audio.state, &"Active")
	assert_eq(_input.state, &"Suspended")
	assert_true(get_tree().paused)
	assert_true(_view.covered)
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	assert_false(_coordinator.is_foreground_admitted())
	assert_signal_not_emitted(_coordinator, "pause_closed")
	_dialogic.resume_ok = true
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_eq(_log.slice(3), ["resume:audio", "resume:dialogic", "resume:dialogic", "resume:input"])
	assert_false(get_tree().paused)
	assert_signal_emit_count(_coordinator, "pause_closed", 1)

func test_source_change_before_resume_keeps_custody_until_original_source_returns() -> void:
	var handle: Dictionary = (await _coordinator.request_pause(&"pause_fixture")).value
	_owner.source.frontier.event_index = 1
	assert_false((await _coordinator.request_resume(handle)).ok)
	assert_eq(_log.size(), 3)
	assert_true(get_tree().paused)
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	_owner.source.frontier.event_index = 0
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_false(get_tree().paused)

func test_source_change_during_awaited_release_cannot_close_or_unpause_wrong_source() -> void:
	var handle: Dictionary = (await _coordinator.request_pause(&"pause_fixture")).value
	_audio.yield_resume = true
	_audio.on_resume = func(): _owner.source.revision += 1
	_resume_async(handle)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_async_result.get("ok", true))
	assert_true(get_tree().paused)
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	assert_false(_coordinator.is_foreground_admitted())
	assert_signal_not_emitted(_coordinator, "pause_closed")
	_audio.on_resume = Callable()
	_owner.source.revision = 1
	assert_true((await _coordinator.request_resume(handle)).ok, "retry recognizes the already Active released port")
	assert_eq(_log.count("resume:audio"), 1, "a successful non-idempotent release is not called again")
	assert_false(get_tree().paused)

func test_busy_acquire_release_and_recovery_refuse_commands_and_rebinding() -> void:
	_input.yield_begin = true
	_open_async()
	assert_eq(_coordinator.get_state().value.state, &"Acquiring")
	assert_false(_coordinator.request_lifecycle_command(&"pause.settings").ok)
	assert_false(_coordinator.bind_source(_scene, _view).ok)
	assert_false(_coordinator.is_foreground_admitted())
	assert_false((await _coordinator.request_pause(&"other_holder")).ok)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_async_result.get("ok", false))
	var handle: Dictionary = _async_result.value
	assert_true(_coordinator.request_lifecycle_command(&"pause.settings").ok)
	assert_false(_coordinator.request_lifecycle_command(&"invented.command").ok)
	var wrong := handle.duplicate(true)
	wrong.generation += 1
	assert_false((await _coordinator.request_resume(wrong)).ok)
	_audio.yield_resume = true
	_audio.resume_ok = false
	_async_result = {}
	_resume_async(handle)
	assert_eq(_coordinator.get_state().value.state, &"Releasing")
	assert_false(_coordinator.request_lifecycle_command(&"pause.backup").ok)
	assert_false(_coordinator.bind_source(_scene, _view).ok)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_async_result.get("ok", true))
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	assert_false(_coordinator.request_lifecycle_command(&"pause.return").ok)
	assert_false(_coordinator.bind_source(_scene, _view).ok)

func test_view_restore_failure_releases_no_port_and_is_retryable() -> void:
	var handle: Dictionary = (await _coordinator.request_pause(&"pause_fixture")).value
	_view.restore_ok = false
	assert_false((await _coordinator.request_resume(handle)).ok)
	assert_eq(_log.size(), 3)
	assert_true(get_tree().paused)
	assert_true(_view.covered)
	_view.restore_ok = true
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_false(get_tree().paused)

func test_failed_but_proven_active_port_only_compensates_prior_owners() -> void:
	_dialogic.begin_ok = false
	_dialogic.state_after_begin = &"Active"
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	assert_eq(_log, ["begin:input", "begin:dialogic", "resume:input"])
	assert_true(_coordinator.is_foreground_admitted())
	assert_false(get_tree().paused)

func test_foreign_suspended_port_is_never_acquired_or_released() -> void:
	_dialogic.state = &"Suspended"
	_dialogic.held = {"foreign": true}
	assert_false((await _coordinator.request_pause(&"pause_fixture")).ok)
	assert_eq(_log, ["begin:input", "resume:input"])
	assert_eq(_dialogic.held, {"foreign": true})
	assert_eq(_dialogic.state, &"Suspended")
	assert_true(_coordinator.is_foreground_admitted())
	assert_false(get_tree().paused)

func test_cover_callback_source_change_enters_recovery_without_publishing_pause() -> void:
	_view.on_cover = func(): _owner.source.revision = 2
	var refused: Dictionary = await _coordinator.request_pause(&"pause_fixture")
	assert_false(refused.ok)
	assert_eq(refused.code, &"pause_source_changed")
	assert_eq(_log, ["begin:input", "begin:dialogic", "begin:audio"], "cover mutation cannot release any acquired owner")
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	var handle: Dictionary = _coordinator.get_state().value.handle
	assert_false(handle.is_empty())
	assert_true(get_tree().paused)
	assert_true(_view.covered)
	assert_false(_coordinator.is_foreground_admitted())
	assert_signal_not_emitted(_coordinator, "pause_opened")
	assert_signal_not_emitted(_coordinator, "pause_closed")
	_view.on_cover = Callable()
	_owner.source.revision = 1
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_false(get_tree().paused)
	assert_true(_coordinator.is_foreground_admitted())

func test_restore_callback_source_change_retains_tree_and_all_ports_before_retry() -> void:
	var handle: Dictionary = (await _coordinator.request_pause(&"pause_fixture")).value
	_view.on_restore = func(): _owner.source.revision = 2
	var refused: Dictionary = await _coordinator.request_resume(handle)
	assert_false(refused.ok)
	assert_eq(refused.code, &"pause_source_changed")
	assert_eq(_log, ["begin:input", "begin:dialogic", "begin:audio"], "requalification happens before the first release")
	for port: Port in [_input, _dialogic, _audio]:
		assert_eq(port.state, &"Suspended")
		assert_eq(port.held, handle)
	assert_true(get_tree().paused)
	assert_true(_view.covered)
	assert_eq(_coordinator.get_state().value.state, &"Recovery")
	assert_eq(_coordinator.get_state().value.handle, handle)
	assert_signal_not_emitted(_coordinator, "pause_closed")
	_view.on_restore = Callable()
	_owner.source.revision = 1
	assert_true((await _coordinator.request_resume(handle)).ok)
	assert_false(get_tree().paused)
	assert_signal_emit_count(_coordinator, "pause_closed", 1)
