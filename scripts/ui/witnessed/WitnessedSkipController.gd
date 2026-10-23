extends Node
## Session-owned Skip pump. DialogicBridge owns every narrative mutation.

signal state_changed

const AUTO_ENABLED := &"preferences.reading.auto_enabled"

var _profile: Object
var _bridge: Object
var _admission: Callable
var _skip_active := false
var _auto_enabled := false
var _generation := 0
var _configuration_generation := 0
var _step_in_progress := false
var _last_step_frame := -1


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(_skip_active)


func configure(profile: Object, bridge: Object, admission: Callable) -> bool:
	if profile == null or not profile.has_method("get_preference") \
			or not profile.has_method("set_preference"):
		return false
	if bridge == null or not bridge.has_method("request_skip_step") or not admission.is_valid():
		return false
	_configuration_generation += 1
	stop_skip()
	_disconnect_profile()
	_profile = profile
	_bridge = bridge
	_admission = admission
	_auto_enabled = bool(_profile.call("get_preference", AUTO_ENABLED, false))
	if _profile.has_signal("preference_changed"):
		_profile.connect("preference_changed", _on_preference_changed)
	if _profile.has_signal("profile_restored"):
		_profile.connect("profile_restored", _on_profile_restored)
	return true


func toggle_skip() -> Dictionary:
	return set_skip_active(not _skip_active)


func set_skip_active(target: bool) -> Dictionary:
	if not target:
		stop_skip()
		return _success()
	if _skip_active:
		return _success()
	if not _is_configured():
		return _failure(&"not_configured")
	if not _is_admitted():
		return _failure(&"not_admitted")
	var start_generation := _generation
	var command_generation := _configuration_generation
	var command_profile := _profile
	if _auto_enabled:
		var committed: Variant = command_profile.call("set_preference", AUTO_ENABLED, false)
		if not committed is Dictionary or not committed.get("ok", false):
			return committed if committed is Dictionary else _failure(&"auto_disable_failed")
		if command_generation != _configuration_generation or not _is_configured():
			return _failure(&"skip_start_retired")
		_sync_auto_enabled()
		if _auto_enabled:
			return _failure(&"auto_disable_not_committed")
	if command_generation != _configuration_generation \
			or start_generation != _generation or not _is_configured():
		return _failure(&"skip_start_retired")
	if not _is_admitted():
		return _failure(&"not_admitted")
	if start_generation != _generation:
		return _failure(&"skip_start_retired")
	_start_skip()
	return _success()


func stop_skip() -> void:
	_generation += 1
	if not _skip_active:
		return
	_skip_active = false
	set_process(false)
	state_changed.emit()


func is_skip_active() -> bool:
	return _skip_active


func is_auto_enabled() -> bool:
	return _auto_enabled


func _process(_delta: float) -> void:
	if not _skip_active or _step_in_progress:
		return
	if not _is_configured() or not _is_admitted():
		stop_skip()
		return
	if not _skip_active:
		return
	var frame := Engine.get_process_frames()
	if frame == _last_step_frame:
		return
	_last_step_frame = frame
	var generation := _generation
	_step_in_progress = true
	var result: Variant = _bridge.call("request_skip_step")
	_step_in_progress = false
	if generation != _generation or not _skip_active:
		return
	if not _is_configured() or not _is_admitted():
		stop_skip()
		return
	if generation != _generation or not _skip_active:
		return
	if not result is Dictionary or not result.get("ok", false):
		stop_skip()
		return
	var value: Variant = result.get("value", {})
	if not value is Dictionary or not value.get("advance", false) \
			or value.get("stop_before_boundary", false):
		stop_skip()


func _start_skip() -> void:
	_skip_active = true
	_generation += 1
	set_process(true)
	state_changed.emit()


func _sync_auto_enabled() -> void:
	if _profile == null or not is_instance_valid(_profile):
		return
	var enabled := bool(_profile.call("get_preference", AUTO_ENABLED, false))
	if enabled == _auto_enabled:
		return
	var was_active := _skip_active
	_auto_enabled = enabled
	if enabled:
		stop_skip()
	if not enabled or not was_active:
		state_changed.emit()


func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == AUTO_ENABLED:
		_sync_auto_enabled()


func _on_profile_restored(_restored_profile: Dictionary) -> void:
	var previous_auto := _auto_enabled
	var was_active := _skip_active
	_auto_enabled = bool(_profile.call("get_preference", AUTO_ENABLED, false))
	stop_skip()
	if previous_auto != _auto_enabled and not was_active:
		state_changed.emit()


func _is_configured() -> bool:
	return _profile != null and is_instance_valid(_profile) \
		and _bridge != null and is_instance_valid(_bridge) and _admission.is_valid()


func _is_admitted() -> bool:
	return _admission.is_valid() and bool(_admission.call())


func _disconnect_profile() -> void:
	if _profile == null or not is_instance_valid(_profile):
		return
	if _profile.has_signal("preference_changed") \
			and _profile.is_connected("preference_changed", _on_preference_changed):
		_profile.disconnect("preference_changed", _on_preference_changed)
	if _profile.has_signal("profile_restored") \
			and _profile.is_connected("profile_restored", _on_profile_restored):
		_profile.disconnect("profile_restored", _on_profile_restored)


func _success() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"skip_active": _skip_active, "auto_enabled": _auto_enabled}, "receipt": {}}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": {}, "receipt": {}}
