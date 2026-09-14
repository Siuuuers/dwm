extends Node
## Profile-owned Auto state with one session-local, presentation-bound delay.
## DialogicBridge remains the sole owner of narrative advancement.

signal state_changed

const AUTO_ENABLED := &"preferences.reading.auto_enabled"
const AUTO_DELAY := &"preferences.reading.auto_delay"
const DELAYS := {"short": 1.0, "normal": 2.0, "long": 4.0}

var _profile: Object
var _bridge: Object
var _admission: Callable
var _auto_enabled := false
var _delay := 2.0
var _delay_key := "normal"
var _frontier: Dictionary = {}
var _last_frontier: Dictionary = {}
var _remaining := 0.0
var _armed := false
var _eligible_last_tick := false
var _generation := 0
var _configuration_generation := 0
var _request_in_progress := false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(_armed)


func _exit_tree() -> void:
	_disconnect_profile()


func configure(profile: Object, bridge: Object, admission: Callable) -> bool:
	if profile == null or not profile.has_method("get_preference") \
			or not profile.has_method("set_preference"):
		return false
	if bridge == null or not bridge.has_method("capture_current_line_presentation_frontier") \
			or not bridge.has_method("can_auto_advance_current_line") \
			or not bridge.has_method("request_auto_step") or not admission.is_valid():
		return false
	_configuration_generation += 1
	retire_current()
	_last_frontier.clear()
	_disconnect_profile()
	_profile = profile
	_bridge = bridge
	_admission = admission
	var configured_delay: Variant = _profile.call("get_preference", AUTO_DELAY, "normal")
	if typeof(configured_delay) != TYPE_STRING or not DELAYS.has(configured_delay):
		_profile = null
		_bridge = null
		_admission = Callable()
		return false
	_delay_key = str(configured_delay)
	_delay = float(DELAYS[_delay_key])
	_auto_enabled = bool(_profile.call("get_preference", AUTO_ENABLED, false))
	if _profile.has_signal("preference_changed"):
		_profile.connect("preference_changed", _on_preference_changed)
	if _profile.has_signal("profile_restored"):
		_profile.connect("profile_restored", _on_profile_restored)
	_try_arm_current()
	return true


func toggle_auto() -> Dictionary:
	return set_auto_enabled(not _auto_enabled)


func set_auto_enabled(target: bool) -> Dictionary:
	if not _is_configured():
		return _failure(&"not_configured")
	if target == _auto_enabled:
		return _success()
	if not _is_admitted():
		return _failure(&"not_admitted")
	var command_generation := _configuration_generation
	var command_profile := _profile
	var committed: Variant = command_profile.call("set_preference", AUTO_ENABLED, target)
	if not committed is Dictionary or not committed.get("ok", false):
		return committed if committed is Dictionary else _failure(&"auto_commit_failed")
	if command_generation != _configuration_generation or not _is_configured():
		return _failure(&"auto_set_retired")
	_sync_preferences(true)
	if _auto_enabled != target:
		return _failure(&"auto_not_committed")
	return _success()


func is_auto_enabled() -> bool:
	return _auto_enabled


func arm_after_reveal(frontier: Dictionary) -> void:
	if not _auto_enabled or not _is_configured() or not frontier.get("ok", false):
		return
	if frontier == _last_frontier:
		return
	var current: Variant = _bridge.call("capture_current_line_presentation_frontier")
	if not current is Dictionary or current != frontier \
			or not bool(_bridge.call("can_auto_advance_current_line")):
		_retire_without_rearm()
		return
	_generation += 1
	_frontier = frontier.duplicate(true)
	_last_frontier = frontier.duplicate(true)
	_remaining = _delay
	_armed = true
	_eligible_last_tick = false
	set_process(true)


func retire_current() -> void:
	_retire_without_rearm()
	_last_frontier.clear()


func suspend_current() -> void:
	_eligible_last_tick = false


func _retire_without_rearm() -> void:
	_generation += 1
	_frontier.clear()
	_remaining = 0.0
	_armed = false
	_eligible_last_tick = false
	set_process(false)


func _process(delta: float) -> void:
	if not _armed or _request_in_progress:
		return
	if not _is_configured():
		_retire_without_rearm()
		return
	if not _is_admitted():
		_eligible_last_tick = false
		return
	if not _eligible_last_tick:
		_eligible_last_tick = true
		return
	var current: Variant = _bridge.call("capture_current_line_presentation_frontier")
	if not current is Dictionary or current != _frontier \
			or not bool(_bridge.call("can_auto_advance_current_line")):
		_retire_without_rearm()
		return
	_remaining -= maxf(delta, 0.0)
	if _remaining > 0.0:
		return
	var expected := _frontier.duplicate(true)
	var request_generation := _generation
	_armed = false
	_frontier.clear()
	_remaining = 0.0
	set_process(false)
	_request_in_progress = true
	_bridge.call("request_auto_step", expected)
	_request_in_progress = false
	# A synchronous publication may already have armed the next exact source.
	if request_generation == _generation:
		_eligible_last_tick = false


func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == AUTO_ENABLED or path == AUTO_DELAY:
		_sync_preferences(true)


func _on_profile_restored(_restored_profile: Dictionary) -> void:
	_sync_preferences(true, true)


func _sync_preferences(allow_arm: bool, force_reset: bool = false) -> void:
	if not _is_configured():
		return
	var next_enabled := bool(_profile.call("get_preference", AUTO_ENABLED, false))
	var next_delay: Variant = _profile.call("get_preference", AUTO_DELAY, "normal")
	var valid_delay: bool = typeof(next_delay) == TYPE_STRING and DELAYS.has(next_delay)
	var changed: bool = next_enabled != _auto_enabled
	var delay_changed: bool = valid_delay and str(next_delay) != _delay_key
	if changed or delay_changed or force_reset:
		retire_current()
		_last_frontier.clear()
	_auto_enabled = next_enabled
	if valid_delay:
		_delay_key = str(next_delay)
		_delay = float(DELAYS[_delay_key])
	else:
		retire_current()
	if changed or delay_changed or force_reset:
		state_changed.emit()
	if allow_arm and _auto_enabled and valid_delay and (changed or delay_changed or force_reset):
		_try_arm_current()


func _try_arm_current() -> void:
	if not _auto_enabled or not _is_configured() or not _is_admitted() \
			or not bool(_bridge.call("can_auto_advance_current_line")):
		return
	var current: Variant = _bridge.call("capture_current_line_presentation_frontier")
	if current is Dictionary:
		arm_after_reveal(current)


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
	return {"ok": true, "code": &"ok", "value": {"auto_enabled": _auto_enabled}, "receipt": {}}


func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": {}, "receipt": {}}
