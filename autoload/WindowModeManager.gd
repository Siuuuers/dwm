extends Node
## Owns physical window output. Shared Settings transactions own persistence;
## ProfileRestoreParticipant composes this output with silent Profile restoration.

const PORT := preload("res://scripts/display/WindowModePort.gd")
const PATH := &"preferences.display.window_mode"

var _port: RefCounted
var _profile: Node
var _transactions: RefCounted
var _mutation_gate: Object
var _initialized := false
var _binding_retained := false
var _available := false
var _fatal := false
var _applying := false
var _mode := ""

func _init(port: RefCounted = null) -> void:
	_port = PORT.new() if port == null else port

func configure_mutation_gate(gate: Object) -> Dictionary:
	if not is_instance_valid(gate) or not gate.has_signal("capability_changed"): return _failure(&"invalid_mutation_gate")
	for method: StringName in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return _failure(&"invalid_mutation_gate")
	if _mutation_gate != null and _mutation_gate != gate: return _failure(&"mutation_gate_already_configured")
	var already := _mutation_gate != null
	_mutation_gate = gate
	return _success({"gate_instance_id": gate.get_instance_id(), "already_configured": already})

func initialize(profile: Node, transactions: RefCounted) -> Dictionary:
	if _initialized: return _failure(&"already_initialized")
	if _binding_retained and (profile != _profile or transactions != _transactions):
		return _failure(&"settings_output_owner_already_bound")
	if not is_instance_valid(profile) or not profile.has_method("get_preference") \
		or not is_instance_valid(transactions) or not transactions.has_method("bind_window_output"):
		return _failure(&"invalid_settings_output_owner")
	for method: StringName in [&"get_profile_snapshot", &"get_profile_revision"]:
		if not profile.has_method(method): return _failure(&"invalid_settings_output_owner")
	if not profile.has_signal("preference_changed") or not transactions.has_method("is_busy") \
		or not transactions.has_method("commit_settings_window_preference"):
		return _failure(&"invalid_settings_output_owner")
	_profile = profile
	_transactions = transactions
	var prepared := prepare_restore(_profile.get_profile_snapshot().preferences)
	if not prepared.ok: return prepared
	var captured: Dictionary = _port.capture_output()
	_available = captured.get("ok", false)
	# Headless has no physical window. It retains an explicit unavailable capability;
	# a production native refusal is never converted into a successful mode change.
	if not _available and captured.get("code") != &"window_output_unavailable": return captured
	_initialized = true
	var bound: Dictionary = _transactions.bind_window_output(self)
	if not bound.get("ok", false):
		_initialized = false
		return bound
	_binding_retained = true
	if _available:
		var applied := apply_restore_silent(prepared.value)
		if not applied.ok:
			_initialized = false
			return applied
	else:
		_mode = prepared.value.window_mode
	_profile.preference_changed.connect(_on_preference_changed)
	return _success({"available": _available})

func get_settings_window_capability() -> Dictionary:
	return _success({"available": _initialized and _available and not _fatal})

func is_output_initialized() -> bool:
	return _initialized and not _fatal

func get_settings_output_transactions() -> RefCounted:
	return _transactions

func get_applied_mode() -> String:
	return _mode

func commit_settings_window_preference(holder_id: Variant, value: Variant) -> Dictionary:
	if not get_settings_window_capability().value.available: return _failure(&"window_output_unavailable")
	return _transactions.commit_settings_window_preference(holder_id, value)

func prepare_restore(preferences: Dictionary) -> Dictionary:
	var display: Variant = preferences.get("display")
	if typeof(display) != TYPE_DICTIONARY: return _failure(&"invalid_window_preferences")
	var mode: Variant = display.get("window_mode")
	if typeof(mode) != TYPE_STRING or mode not in ["windowed", "borderless"]:
		return _failure(&"invalid_window_mode")
	return _success({"window_mode": mode})

func capture_restore_state() -> Dictionary:
	if _fatal: return _failure(&"window_output_indeterminate")
	if not _available: return _failure(&"window_output_unavailable")
	var captured: Dictionary = _port.capture_output()
	if not captured.get("ok", false): return captured
	return _success({"output": captured.value, "mode": _mode})

func apply_restore_silent(plan: Dictionary) -> Dictionary:
	if plan.size() != 1 or not plan.has("window_mode") \
		or typeof(plan.window_mode) != TYPE_STRING or plan.window_mode not in ["windowed", "borderless"]:
		return _failure(&"invalid_window_restore_plan")
	if _fatal: return _failure(&"window_output_indeterminate")
	if not _available: return _failure(&"window_output_unavailable")
	var captured: Dictionary = _port.capture_output()
	if not captured.get("ok", false): return captured
	_applying = true
	var applied: Dictionary = _port.apply_mode(plan.window_mode)
	if applied.get("ok", false) and not _port.output_matches(plan.window_mode):
		applied = _failure(&"window_output_unproven")
	if not applied.get("ok", false):
		var restored: Dictionary = _port.restore_output(captured.value)
		_applying = false
		if not restored.get("ok", false):
			latch_output_failure(&"window_output_rollback", restored)
			return _failure(&"window_output_indeterminate")
		return applied
	_mode = plan.window_mode
	_applying = false
	return _success({})

func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	if backup.size() != 2 or not backup.has_all(["output", "mode"]) \
		or typeof(backup.output) != TYPE_DICTIONARY or typeof(backup.mode) != TYPE_STRING \
		or backup.mode not in ["windowed", "borderless"]:
		return _failure(&"invalid_window_restore_backup")
	_applying = true
	var restored: Dictionary = _port.restore_output(backup.output)
	_applying = false
	if not restored.get("ok", false):
		latch_output_failure(&"window_output_rollback", restored)
		return _failure(&"window_output_indeterminate")
	_mode = backup.mode
	return _success({})

func finalize_restore() -> Dictionary:
	return _failure(&"window_output_indeterminate") if _fatal else _success({})

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path != PATH or _applying or _transactions.is_busy() or not _available or _fatal: return
	for _attempt: int in range(8):
		var revision: int = _profile.get_profile_revision()
		var mode: String = _profile.get_preference(PATH)
		if mode != _mode:
			var applied := apply_restore_silent({"window_mode": mode})
			if not applied.ok:
				latch_output_failure(&"committed_window_preference", applied)
				return
		if _profile.get_profile_revision() == revision: return
	latch_output_failure(&"window_settlement", _failure(&"window_preference_conflict"))

func latch_output_failure(phase: StringName, cause: Dictionary) -> void:
	_fatal = true
	if is_instance_valid(_mutation_gate):
		_mutation_gate.latch_fatal({"source": "WindowModeManager", "phase": String(phase),
			"code": String(cause.get("code", &"window_output_indeterminate")), "details": {}})

func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
