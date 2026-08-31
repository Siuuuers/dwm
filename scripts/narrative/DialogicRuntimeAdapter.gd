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

const CLEAR_KEEP_VARIABLES := 1
const REQUIRED_METHODS := ["start", "start_timeline", "end_timeline", "handle_next_event", "handle_event", "clear", "has_subsystem", "get_subsystem"]
const REQUIRED_SIGNALS := ["timeline_started", "timeline_ended", "event_handled", "signal_event"]
const REQUIRED_SUBSYSTEMS := {
	"Text": {"signals": ["text_started", "text_finished"], "methods": ["skip_text_reveal"]},
	"Choices": {"signals": ["question_shown", "choice_selected"], "methods": ["select_choice"]},
}

var _dialogic: Node = null
var _bound := false


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
	_dialogic = dialogic
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
	_dialogic.clear(CLEAR_KEEP_VARIABLES)
	preference_reapply_requested.emit()
	_dialogic.start(path, label_or_index)
	return {"ok": true, "code": &"ok", "value": {"path": path, "label_or_index": label_or_index}}


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
	if _bound and _dialogic.current_timeline != null:
		_dialogic.end_timeline(true)
	return {"ok": false, "code": &"runtime_halted", "message": "timeline halted", "details": result.duplicate(true)}


func set_paused(value: bool) -> Dictionary:
	# Used by the before_event restore position to suspend the staged successor.
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	_dialogic.paused = value
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
	timeline_started_signal.emit()


func _on_timeline_ended() -> void:
	timeline_ended_signal.emit()


func _on_event_handled(resource: Variant) -> void:
	event_handled_signal.emit(resource)


func _on_signal_event(argument: Variant) -> void:
	runtime_signal_event.emit(argument)


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
