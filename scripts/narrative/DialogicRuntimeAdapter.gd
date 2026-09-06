class_name DialogicRuntimeAdapter
extends RefCounted
## Low-level wrapper over ONLY the physically-audited Dialogic API (dwm-p2r.8, Plan-05 Task 2).
##
## Connects each audited signal exactly once, never serializes full addon state, and preserves the
## installed-version ordering `clear -> preference reapply -> first event` in start_timeline. It
## owns no semantic-checkpoint logic; the bridge builds those from the manifest. Restore-flow
## methods (prepare_runtime_restore/apply_restore/classify/advance) carry the minimal contract the
## Task-2 restore state machine wires and deepens.

signal timeline_started_signal
signal timeline_ended_signal
signal event_handled_signal(resource)
signal runtime_signal_event(argument)
signal preference_reapply_requested
signal playback_start_failed(result: Dictionary)

const CLEAR_KEEP_VARIABLES := 1
const REQUIRED_METHODS := ["start", "start_timeline", "end_timeline", "handle_next_event", "handle_event", "clear", "has_subsystem", "get_subsystem"]
const REQUIRED_SIGNALS := ["timeline_started", "timeline_ended", "event_handled", "signal_event"]
const REQUIRED_SUBSYSTEMS := {
	"Text": {"signals": ["text_started", "text_finished"], "methods": ["skip_text_reveal"]},
	"Choices": {"signals": ["question_shown", "choice_selected"], "methods": ["select_choice"]},
}

var _dialogic: Node = null
var _bound := false
var _activity_phase := ""
var _start_generation := 0
var _pending_layout: Node
var _pending_start: Callable
var _requested_path := ""
var _runtime_generation := 0
var _qualified_runtime := false
var _request_id := ""


func bind_runtime(dialogic: Node) -> Dictionary:
	if _bound:
		if dialogic == _dialogic:
			return {"ok": true, "code": &"ok", "value": {"already_bound": true}}
		return _fail(&"runtime_already_bound", "adapter is already bound to a runtime")
	if dialogic == null:
		return _fail(&"invalid_runtime", "dialogic runtime is null")
	for method in REQUIRED_METHODS:
		if not dialogic.has_method(method):
			return _fail(&"invalid_runtime", "missing method " + method)
	for signal_name in REQUIRED_SIGNALS:
		if not dialogic.has_signal(signal_name):
			return _fail(&"invalid_runtime", "missing signal " + signal_name)
	for subsystem_name in REQUIRED_SUBSYSTEMS:
		if not dialogic.has_subsystem(subsystem_name):
			return _fail(&"missing_subsystem", subsystem_name)
		var subsystem: Object = dialogic.get_subsystem(subsystem_name)
		if subsystem == null:
			return _fail(&"missing_subsystem", subsystem_name)
		for signal_name in REQUIRED_SUBSYSTEMS[subsystem_name]["signals"]:
			if not subsystem.has_signal(signal_name):
				return _fail(&"missing_subsystem", "%s.%s" % [subsystem_name, signal_name])
		for method in REQUIRED_SUBSYSTEMS[subsystem_name]["methods"]:
			if not subsystem.has_method(method):
				return _fail(&"missing_subsystem", "%s.%s" % [subsystem_name, method])
	if dialogic.has_signal("timeline_started_with_generation") or dialogic.has_signal("timeline_ended_with_generation"):
		if not (dialogic.has_signal("timeline_started_with_generation") and dialogic.has_signal("timeline_ended_with_generation") \
			and dialogic.has_method("get_timeline_generation") and dialogic.has_method("is_ending_timeline")):
			return _fail(&"invalid_runtime", "qualified lifecycle requires both signals and generation queries")
		_qualified_runtime = true
	_dialogic = dialogic
	_activity_phase = "live" if _dialogic.get("current_timeline") != null else ""
	if _qualified_runtime:
		_runtime_generation = int(dialogic.get_timeline_generation())
		if dialogic.is_ending_timeline(): _activity_phase = "stopping"
		_connect_once(dialogic, "timeline_started_with_generation", _on_qualified_timeline_started)
		_connect_once(dialogic, "timeline_ended_with_generation", _on_qualified_timeline_ended)
	else:
		_connect_once(dialogic, "timeline_started", _on_timeline_started)
		_connect_once(dialogic, "timeline_ended", _on_timeline_ended)
	_connect_once(dialogic, "event_handled", _on_event_handled)
	_connect_once(dialogic, "signal_event", _on_signal_event)
	_bound = true
	return {"ok": true, "code": &"ok", "value": {"already_bound": false}}


## Task 5 (dwm-oyo.2 R-BB): widened to Dialogic's own two-argument vocabulary - the second
## argument is a String label to jump to or an int event index, exactly like
## DialogicGameHandler.start(timeline, label_or_idx). The default stays 0 so every existing int
## caller (the restore state machine) is byte-compatible.
func start_timeline(path: String, label_or_index: Variant = 0) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	if path.is_empty():
		return _fail(&"invalid_timeline_path", "path is required")
	if has_active_playback():
		return _fail(&"runtime_playback_active", "complete or cancel the standing playback first")
	_start_generation += 1
	var generation := _start_generation
	_request_id = "%d:%d" % [get_instance_id(), generation]
	_activity_phase = "starting"
	_requested_path = path
	_runtime_generation = 0
	_dialogic.clear(CLEAR_KEEP_VARIABLES)
	preference_reapply_requested.emit()
	if generation != _start_generation:
		return _fail(&"runtime_start_cancelled", "playback was cancelled during startup")
	var layout: Variant = _dialogic.start(path, label_or_index, _request_id) if _qualified_runtime else _dialogic.start(path, label_or_index)
	if generation != _start_generation:
		return _fail(&"runtime_start_cancelled", "playback was cancelled during startup")
	if _activity_phase == "starting":
		if is_instance_valid(layout) and layout is Node:
			_pending_layout = layout
			_pending_start = Callable(_dialogic, "start_timeline").bind(path, label_or_index)
			if _qualified_runtime: _pending_start = Callable(_dialogic, "start_timeline").bind(path, label_or_index, _request_id)
		if not is_instance_valid(layout) or not layout is Node or layout.is_node_ready():
			_activity_phase = ""
			_requested_path = ""
			_discard_pending_layout()
			return _fail(&"runtime_start_failed", "runtime did not start or admit a deferred layout")
		_pending_layout.ready.connect(_verify_pending_start.bind(generation),CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		_pending_layout.tree_exited.connect(_pending_layout_exited.bind(generation),CONNECT_ONE_SHOT)
	return {"ok": true, "code": &"ok", "value": {"path": path, "label_or_index": label_or_index}}


func has_active_playback() -> bool:
	return _activity_phase != ""


func is_bound_to_runtime(runtime: Node) -> bool:
	return _bound and runtime == _dialogic


## Ephemeral reading frontier only. Startup, cleanup and non-text events cannot open Pause.
func capture_pause_frontier() -> Dictionary:
	if not _bound or not _qualified_runtime or _activity_phase != "live" \
		or _request_id.is_empty() or _requested_path.is_empty() or _dialogic.current_timeline == null \
		or _dialogic.is_ending_timeline():
		return _fail(&"pause_frontier_unavailable", "no admitted live reading frontier")
	var index := int(_dialogic.current_event_idx)
	if index < 0 or index >= _dialogic.current_timeline_events.size() \
		or not _dialogic.current_timeline_events[index] is DialogicTextEvent \
		or _dialogic.current_state not in [DialogicGameHandler.States.IDLE, DialogicGameHandler.States.REVEALING_TEXT]:
		return _fail(&"pause_frontier_unavailable", "the current event has no reading frontier")
	return {"ok": true, "code": &"ok", "value": {
		"generation": _runtime_generation, "event_index": index,
		"request_id": _request_id, "paused": bool(_dialogic.paused),
	}}


func _verify_pending_start(generation: int) -> void:
	if generation != _start_generation or _activity_phase != "starting":
		return
	_activity_phase = ""
	_requested_path = ""
	_discard_pending_layout()
	playback_start_failed.emit(_fail(&"runtime_start_failed", "ready layout did not start its timeline"))


func _pending_layout_exited(generation: int) -> void:
	_verify_pending_start(generation)


func _discard_pending_layout() -> void:
	if is_instance_valid(_pending_layout):
		if _pending_layout.ready.is_connected(_pending_start):
			_pending_layout.ready.disconnect(_pending_start)
		var clear_call := Callable(_dialogic,"clear").bind(CLEAR_KEEP_VARIABLES)
		if _pending_layout.ready.is_connected(clear_call):
			_pending_layout.ready.disconnect(clear_call)
		# A failure observer may retry synchronously. Styles must not reuse this layout.
		var tree := _dialogic.get_tree() if _dialogic.is_inside_tree() else null
		if tree != null and tree.get_meta("dialogic_layout_node", null) == _pending_layout:
			tree.remove_meta("dialogic_layout_node")
		# Styles already queued add_child. Let that mount finish before deletion.
		_pending_layout.call_deferred("queue_free")
	_pending_layout = null
	_pending_start = Callable()


func capture_checkpoint() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	# Semantic cursor only; never Dialogic.get_full_state().
	return {"ok": true, "code": &"ok", "value": {
		"timeline_active": _dialogic.current_timeline != null,
		"current_event_idx": int(_dialogic.current_event_idx),
	}}


func capture_restore_state() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"timeline_active": _dialogic.current_timeline != null,
		"current_event_idx": int(_dialogic.current_event_idx),
		"paused": bool(_dialogic.paused) if "paused" in _dialogic else false,
	}}}


func restore_captured_state(backup: Dictionary) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	if typeof(backup) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup must be a dictionary")
	if "paused" in _dialogic:
		_dialogic.paused = bool(backup.get("paused", false))
	return {"ok": true, "code": &"ok", "value": {}}


func halt_with_error(result: Dictionary) -> Dictionary:
	_start_generation += 1
	if _activity_phase == "starting":
		# Cancel only the queued native start this adapter admitted. No prose ran.
		_discard_pending_layout()
		_activity_phase = ""
	_requested_path = ""
	if _bound and _dialogic.current_timeline != null:
		_activity_phase = "stopping"
		_dialogic.end_timeline(true)
	return {"ok": false, "code": &"runtime_halted", "message": "timeline halted", "details": result.duplicate(true)}


func set_paused(value: bool) -> Dictionary:
	# Used by the before_event restore position to suspend the staged successor.
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	_dialogic.paused = value
	if bool(_dialogic.paused) != value:
		return _fail(&"runtime_pause_not_applied", "runtime pause readback did not match")
	return {"ok": true, "code": &"ok", "value": {"paused": value}}


func reveal_current_line() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	var text: Object = _dialogic.get_subsystem("Text")
	if text == null:
		return _fail(&"missing_subsystem", "Text")
	# Literal reveal count/tween state is intentionally not restored; finish the reveal instantly.
	if text.has_method("skip_text_reveal"):
		text.skip_text_reveal()
	return {"ok": true, "code": &"ok", "value": {}}


func classify_next_event() -> StringName:
	if not _bound or _dialogic.current_timeline == null:
		return &"none"
	return &"unknown"


func advance_one_event() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	_dialogic.handle_next_event()
	return {"ok": true, "code": &"ok", "value": {"current_event_idx": int(_dialogic.current_event_idx)}}


func prepare_runtime_restore(checkpoint: Dictionary, manifest: Dictionary) -> Dictionary:
	# Pure: copies a detached restore plan. The participant state machine (Step 2.4) stages it.
	if typeof(checkpoint) != TYPE_DICTIONARY or checkpoint.is_empty():
		return _fail(&"invalid_checkpoint", "checkpoint is required")
	if typeof(manifest) != TYPE_DICTIONARY:
		return _fail(&"invalid_manifest", "manifest record is required")
	return {"ok": true, "code": &"ok", "value": {"plan": checkpoint.duplicate(true)}}


func apply_restore(plan: Dictionary) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	if typeof(plan) != TYPE_DICTIONARY:
		return _fail(&"invalid_plan", "plan is required")
	return {"ok": true, "code": &"ok", "value": {}}


func _connect_once(source: Object, signal_name: String, callable: Callable) -> void:
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_timeline_started() -> void:
	_activity_phase = "live"
	_pending_layout = null
	timeline_started_signal.emit()


func _on_timeline_ended() -> void:
	_activity_phase = ""
	_runtime_generation = 0
	_pending_layout = null
	_requested_path = ""
	timeline_ended_signal.emit()


func _on_qualified_timeline_started(generation: int, request_id: String) -> void:
	var replaced := not _requested_path.is_empty() and (_activity_phase != "starting" \
		or request_id != _request_id or str(_dialogic.current_timeline.resource_path) != _requested_path)
	_runtime_generation = generation
	if replaced:
		_start_generation += 1
		_requested_path = ""
		# Never delete a layout now used by foreign native playback.
		if is_instance_valid(_pending_layout) and _pending_layout.ready.is_connected(_pending_start):
			_pending_layout.ready.disconnect(_pending_start)
		var clear_call := Callable(_dialogic, "clear").bind(CLEAR_KEEP_VARIABLES)
		if is_instance_valid(_pending_layout) and _pending_layout.ready.is_connected(clear_call):
			_pending_layout.ready.disconnect(clear_call)
		_pending_layout = null
		_pending_start = Callable()
		_activity_phase = "live"
		playback_start_failed.emit(_fail(&"runtime_playback_replaced", "native playback replaced the admitted timeline"))
		return
	_on_timeline_started()


func _on_qualified_timeline_ended(generation: int) -> void:
	if generation == _runtime_generation:
		_on_timeline_ended()


func _on_event_handled(resource: Variant) -> void:
	event_handled_signal.emit(resource)


func _on_signal_event(argument: Variant) -> void:
	runtime_signal_event.emit(argument)


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
