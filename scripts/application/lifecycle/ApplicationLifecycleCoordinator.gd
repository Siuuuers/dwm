extends Node
## Universal Pause owns only transient suspension and source-view custody.
## Save/Load/Return commands remain with their application owners.

signal pause_opened(source: Dictionary)
signal pause_closed
signal pause_recovery_required(result: Dictionary)

var _source_owner: Object
var _router: Object
var _gate: Object
var _ports: Array[Object] = []
var _source_scene: WeakRef
var _source_view: WeakRef
var _source: Dictionary = {}
var _anchor: Dictionary = {}
var _handle: Dictionary = {}
var _suspended: Array[Object] = []
var _generation := 0
var _phase := &"Active"
var _owns_tree_pause := false
var _restore_destination: Dictionary = {}
var _restore_input_released := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(source_owner: Object, dialogic: Object, input: Object, audio: Object,
		gate: Object, router: Object) -> Dictionary:
	if _source_owner != null: return _failure(&"lifecycle_already_configured")
	if source_owner == null or not source_owner.has_method("capture_pause_source") \
		or gate == null or not gate.has_method("guard_external") \
		or router == null or not router.has_method("get_current_route_id"):
		return _failure(&"invalid_pause_dependency")
	for port: Object in [input, dialogic, audio]:
		if port == null: return _failure(&"invalid_pause_dependency")
		for method: String in ["begin_suspend", "resume", "get_state"]:
			if not port.has_method(method): return _failure(&"invalid_pause_dependency")
	_source_owner = source_owner
	_gate = gate
	_router = router
	_ports.assign([input, dialogic, audio])
	return _success({"configured": true})

func bind_source(scene: Control, view: Node) -> Dictionary:
	if _phase != &"Active": return _failure(&"pause_busy")
	if scene == null or view == null or (not scene.has_method("get_presentation_projection") \
		and not _source_owner.has_method("capture_scene_projection")):
		return _failure(&"invalid_pause_source")
	for method: String in ["capture_pause_view", "cover_pause_view", "restore_pause_view"]:
		if not view.has_method(method): return _failure(&"invalid_pause_source")
	_source_scene = weakref(scene)
	_source_view = weakref(view)
	return _success({"bound": true})

func request_pause(holder_id: StringName) -> Dictionary:
	if _phase != &"Active" or String(holder_id).strip_edges().is_empty():
		return _failure(&"pause_busy")
	if not is_inside_tree() or get_tree().paused:
		return _failure(&"pause_frontier_unavailable")
	var captured := _capture_source()
	if not captured.get("ok", false): return captured
	var view: Object = _source_view.get_ref()
	var anchor: Dictionary = view.capture_pause_view(captured.value)
	if not anchor.get("ok", false): return anchor
	_generation += 1
	_handle = {"generation": _generation, "handle_id": "pause:%d:%d" % [get_instance_id(), _generation],
		"holder": holder_id, "reason": &"universal_pause"}
	_source = captured.value.duplicate(true)
	_anchor = anchor.value.duplicate(true)
	_phase = &"Acquiring"
	for port: Object in _ports:
		var prior: Dictionary = port.get_state()
		if not prior.get("ok", false) or prior.get("value", {}).get("state") != &"Active":
			return await _cancel_acquire(_failure(&"pause_port_unavailable"))
		var begun: Dictionary = await port.begin_suspend(_handle.duplicate(true))
		var state: Dictionary = port.get_state()
		var port_state: StringName = state.get("value", {}).get("state", &"") if state.get("ok", false) else &""
		if port_state != &"Active":
			_suspended.append(port)
		if port_state not in [&"Active", &"Suspended"]:
			return _recover(_failure(&"pause_suspend_unproven"))
		if not begun.get("ok", false) or not _suspended.has(port):
			return await _cancel_acquire(begun if not begun.get("ok", false) else _failure(&"pause_suspend_unproven"))
		var current := _capture_source()
		if not current.get("ok", false) or current.value != _source:
			return await _cancel_acquire(_failure(&"pause_source_changed"))
	view = _source_view.get_ref()
	if view == null or not view.cover_pause_view(_anchor):
		return await _cancel_acquire(_failure(&"pause_view_unavailable"))
	var covered_source := _capture_source()
	if not covered_source.get("ok", false) or covered_source.value != _source:
		return _recover(_failure(&"pause_source_changed"))
	get_tree().paused = true
	_owns_tree_pause = true
	_phase = &"Suspended"
	pause_opened.emit(_source.duplicate(true))
	return _success(_handle.duplicate(true))

func request_resume(handle: Dictionary) -> Dictionary:
	if _phase not in [&"Suspended", &"Recovery"] or _handle.is_empty() or handle != _handle:
		return _failure(&"invalid_suspension_handle")
	var current := _capture_source()
	if not current.get("ok", false) or current.value != _source:
		return _recover(_failure(&"pause_source_changed"))
	_phase = &"Releasing"
	var view: Object = _source_view.get_ref()
	if view == null or not view.restore_pause_view(_anchor):
		return _recover(_failure(&"pause_view_unavailable"))
	current = _capture_source()
	if not current.get("ok", false) or current.value != _source:
		return _recover(_failure(&"pause_source_changed"))
	var released := await _resume_ports()
	if not released.get("ok", false):
		if is_instance_valid(view): view.cover_pause_view(_anchor)
		return _recover(released)
	if _owns_tree_pause:
		get_tree().paused = false
	_owns_tree_pause = false
	_reset_pause()
	pause_closed.emit()
	return _success({"resumed": true})

## Called only after the session owner retires the exact source. Never resume discarded prose.
func retire_suspended_source(handle: Dictionary) -> Dictionary:
	if _phase == &"Retired" and handle == _handle: return _success({"retired": true})
	if _phase not in [&"Suspended", &"Retiring"] or handle != _handle \
		or not _gate.has_method("is_internal_owner_active") \
		or not _gate.is_internal_owner_active(&"session_abandonment"):
		return _failure(&"invalid_suspension_retirement")
	var scene: Object = _source_scene.get_ref() if _source_scene != null else null
	if not is_instance_valid(scene) or get_tree().current_scene != scene:
		return _failure(&"pause_source_changed")
	_phase = &"Retiring"
	while not _suspended.is_empty():
		var port: Object = _suspended.back()
		var result: Dictionary = port.retire_suspended_source(handle) if port.has_method("retire_suspended_source") else port.resume(handle)
		if not result.get("ok", false): return result
		_suspended.pop_back()
	_phase = &"Retired"
	return _success({"retired": true})

## Title is physically published before the old tree pause can be released.
func finish_retirement(handle: Dictionary) -> Dictionary:
	if _phase != &"Retired" or handle != _handle: return _failure(&"invalid_suspension_retirement")
	if _owns_tree_pause: get_tree().paused = false
	_owns_tree_pause = false
	_reset_pause()
	pause_closed.emit()
	return _success({"retired": true})

## A witnessed Load releases only audio so its existing restore participant can run.
## Input, the caption, SceneTree pause and the native text coroutine remain held.
func begin_restore_handoff(handle: Dictionary) -> Dictionary:
	if _phase != &"Suspended" or handle != _handle: return _failure(&"invalid_suspension_handle")
	var current := _capture_source()
	if not current.get("ok", false) or current.value != _source: return _failure(&"pause_source_changed")
	var narrative: Object = _ports[1]
	for method: String in ["begin_restore", "cancel_restore", "complete_restore"]:
		if not narrative.has_method(method): return _failure(&"pause_load_unavailable")
	var held: Dictionary = _router.begin_restore_publication_hold(handle)
	if not held.get("ok", false): return held
	var staged: Dictionary = narrative.begin_restore(handle)
	if not staged.get("ok", false):
		_router.cancel_restore_publication_hold(handle)
		return staged
	var audio: Object = _ports[2]
	var released: Dictionary = audio.resume(handle)
	if not released.get("ok", false):
		narrative.cancel_restore(handle)
		_router.cancel_restore_publication_hold(handle)
		return _recover(released)
	_suspended.erase(audio)
	_restore_destination.clear()
	_restore_input_released = false
	_phase = &"Restoring"
	return _success({"staged": true})


func cancel_restore_handoff(handle: Dictionary) -> Dictionary:
	if _phase != &"Restoring" or handle != _handle: return _failure(&"invalid_suspension_handle")
	var current := _capture_source()
	if not current.get("ok", false) or current.value != _source: return _failure(&"pause_source_changed")
	var cancelled: Dictionary = _ports[1].cancel_restore(handle)
	if not cancelled.get("ok", false): return cancelled
	cancelled = _router.cancel_restore_publication_hold(handle)
	if not cancelled.get("ok", false): return _recover(cancelled)
	var audio: Object = _ports[2]
	var suspended: Dictionary = audio.begin_suspend(handle)
	if not suspended.get("ok", false): return _recover(suspended)
	_suspended.append(audio)
	_phase = &"Suspended"
	return _success({"cancelled": true})


func complete_restore_handoff(handle: Dictionary) -> Dictionary:
	if _phase not in [&"Restoring", &"RestoreCommitted"] or handle != _handle:
		return _failure(&"invalid_suspension_handle")
	var destination: Dictionary = _source_owner.capture_restore_destination_session()
	if not destination.get("ok", false) or destination.value == _source.get("session"):
		return _failure(&"pause_restore_not_activated")
	if not _restore_destination.is_empty() and destination.value != _restore_destination:
		return _failure(&"pause_source_changed")
	_restore_destination = destination.value.duplicate(true)
	_phase = &"RestoreCommitted"
	var acquired: Dictionary = _gate.acquire(&"restore")
	if not acquired.get("ok", false): return acquired
	var restored: Dictionary = await _ports[1].complete_restore(handle)
	if restored.get("ok", false):
		destination = _source_owner.capture_restore_destination_session()
		if not destination.get("ok", false) or destination.value != _restore_destination:
			restored = _failure(&"pause_source_changed")
	if restored.get("ok", false): restored = _router.publish_restore_publication_hold(handle)
	if restored.get("ok", false) and not _restore_input_released:
		restored = _ports[0].resume(handle)
		_restore_input_released = restored.get("ok", false)
	if restored.get("ok", false): restored = _router.release_restore_publication_hold(handle)
	_gate.release(&"restore", acquired.value.token)
	if not restored.get("ok", false): return restored
	_suspended.clear()
	if _owns_tree_pause: get_tree().paused = false
	_owns_tree_pause = false
	_reset_pause()
	pause_closed.emit()
	return _success({"restored": true})


func request_lifecycle_command(command_id: StringName) -> Dictionary:
	if _phase != &"Suspended": return _failure(&"pause_busy")
	if command_id not in [&"pause.resume", &"pause.backup", &"pause.settings", &"pause.return"]:
		return _failure(&"unknown_pause_command")
	var current := _capture_source()
	if not current.get("ok", false) or current.value != _source:
		return _failure(&"pause_source_changed")
	return _success({"admitted": true})

func get_state() -> Dictionary:
	return _success({"state": _phase, "handle": _handle.duplicate(true)})

func is_foreground_admitted() -> bool:
	return _phase == &"Active"

func _capture_source() -> Dictionary:
	if _source_owner == null or _source_scene == null or _source_view == null:
		return _failure(&"pause_source_unavailable")
	var scene: Object = _source_scene.get_ref()
	var view: Object = _source_view.get_ref()
	if scene == null or view == null or not scene.is_inside_tree() or not view.is_inside_tree() \
		or get_tree().current_scene != scene:
		return _failure(&"pause_source_unavailable")
	var guarded: Dictionary = _gate.guard_external(&"universal_pause")
	if not guarded.get("ok", false): return guarded
	var source: Dictionary = _source_owner.capture_pause_source()
	if not source.get("ok", false): return source
	var command: Dictionary = _source_owner.capture_scene_projection(scene) if _source_owner.has_method("capture_scene_projection") else scene.get_presentation_projection()
	for key: String in ["route_id", "timeline_id", "physical_token", "command_sha256", "completion_transaction_id"]:
		if command.get(key) != source.value.get(key): return _failure(&"pause_source_mismatch")
	if _router.get_current_route_id() != source.value.route_id:
		return _failure(&"pause_source_mismatch")
	return _success(source.value.duplicate(true))

func _cancel_acquire(cause: Dictionary) -> Dictionary:
	var compensated := await _resume_ports()
	if not compensated.get("ok", false): return _recover(compensated)
	_reset_pause()
	return cause

func _resume_ports() -> Dictionary:
	while not _suspended.is_empty():
		var port: Object = _suspended.back()
		var state: Dictionary = port.get_state()
		# A prior resume can have completed before a source-change callback. Its
		# proven Active state is sufficient; a consumed handle must not be replayed.
		if not state.get("ok", false) or state.get("value", {}).get("state") != &"Active":
			var resumed: Dictionary = await port.resume(_handle.duplicate(true))
			state = port.get_state()
			if not resumed.get("ok", false) or not state.get("ok", false) \
				or state.get("value", {}).get("state") != &"Active":
				return _failure(&"pause_resume_unproven")
		var current := _capture_source()
		if not current.get("ok", false) or current.value != _source:
			return _failure(&"pause_source_changed")
		_suspended.pop_back()
	return _success({"resumed": true})

func _recover(cause: Dictionary) -> Dictionary:
	# A partial acquire can already own input/audio. Keep its source inert until
	# an exact retry proves every release; never advertise foreground readiness.
	if not get_tree().paused:
		get_tree().paused = true
		_owns_tree_pause = true
	var view: Object = _source_view.get_ref() if _source_view != null else null
	if is_instance_valid(view) and not _anchor.is_empty(): view.cover_pause_view(_anchor)
	_phase = &"Recovery"
	pause_recovery_required.emit(cause.duplicate(true))
	return cause

func _reset_pause() -> void:
	_handle = {}
	_source = {}
	_anchor = {}
	_phase = &"Active"

static func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": null}
