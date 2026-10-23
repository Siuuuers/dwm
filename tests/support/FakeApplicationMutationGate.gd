class_name FakeApplicationMutationGate
extends RefCounted

signal capability_changed(capability: Dictionary)

static var _token_counter := 0
var _active_owner: Variant = null
var _active_token := ""
var _fatal_failure: Dictionary = {}
var _calls: Array[Dictionary] = []

func acquire(owner: StringName) -> Dictionary:
	_record(&"acquire", {"owner": owner})
	if not _fatal_failure.is_empty(): return guard_external(&"acquire")
	if owner not in [&"restore", &"new_run"]: return _failure(&"INVALID_OWNER")
	if _active_owner != null: return _failure(&"MUTATION_ALREADY_ACTIVE")
	_token_counter += 1
	_active_owner = owner
	_active_token = "fake-gate-%d" % _token_counter
	capability_changed.emit({"enabled": false, "code": &"MUTATION_ACTIVE", "active_owner": owner, "fatal_latched": false}.duplicate(true))
	return _success({"owner": owner, "token": _active_token})

func release(owner: StringName, token: String) -> Dictionary:
	_record(&"release", {"owner": owner, "token": token})
	if not _fatal_failure.is_empty(): return guard_external(&"release")
	if owner != _active_owner or token != _active_token: return _failure(&"MUTATION_RELEASE_MISMATCH")
	_active_owner = null
	_active_token = ""
	capability_changed.emit({"enabled": true, "code": &"ok", "active_owner": null, "fatal_latched": false}.duplicate(true))
	return _success({"released": true})

func guard_external(operation_id: StringName) -> Dictionary:
	_record(&"guard_external", {"operation_id": operation_id})
	if not _fatal_failure.is_empty(): return _failure(&"APPLICATION_FATAL", {"failure": _fatal_failure.duplicate(true)})
	if _active_owner != null: return _failure(&"MUTATION_ACTIVE", {"active_owner": _active_owner})
	return _success({"allowed": true})

func is_active() -> bool:
	_record(&"is_active", {})
	return _active_owner != null

func get_active_owner() -> Variant:
	_record(&"get_active_owner", {})
	return _active_owner

func is_internal_owner_active(owner: StringName, token: String = "") -> bool:
	_record(&"is_internal_owner_active", {"owner": owner, "token": token})
	return _fatal_failure.is_empty() and owner == _active_owner and (token.is_empty() or token == _active_token)

func latch_fatal(failure: Dictionary) -> Dictionary:
	_record(&"latch_fatal", {"failure": failure.duplicate(true)})
	if not _valid_failure(failure): return _failure(&"INVALID_FATAL_FAILURE")
	var detached := failure.duplicate(true)
	if not _fatal_failure.is_empty():
		if _fatal_failure == detached: return {"ok": true, "code": &"ok", "value": {"fatal_latched": true, "already_latched": true}, "receipt": {"failure": _fatal_failure.duplicate(true)}}
		return _failure(&"APPLICATION_FATAL_CONFLICT", {"latched_failure": _fatal_failure.duplicate(true), "requested_failure": detached})
	_fatal_failure = detached
	capability_changed.emit({"enabled": false, "code": &"APPLICATION_FATAL", "active_owner": _active_owner, "fatal_latched": true, "failure": detached.duplicate(true)})
	return {"ok": true, "code": &"ok", "value": {"fatal_latched": true, "already_latched": false}, "receipt": {"failure": detached.duplicate(true)}}

func is_fatal_latched() -> bool:
	_record(&"is_fatal_latched", {})
	return not _fatal_failure.is_empty()

func get_call_log() -> Array[Dictionary]:
	return _calls.duplicate(true)

func _valid_failure(value: Dictionary) -> bool:
	if value.size() != 4:
		return false
	for key in ["source", "phase", "code", "details"]:
		if not value.has(key): return false
	return typeof(value["source"]) == TYPE_STRING and not value["source"].strip_edges().is_empty() and typeof(value["phase"]) == TYPE_STRING and not value["phase"].strip_edges().is_empty() and typeof(value["code"]) == TYPE_STRING and not value["code"].strip_edges().is_empty() and typeof(value["details"]) == TYPE_DICTIONARY

func _record(method: StringName, arguments: Dictionary) -> void:
	_calls.append({"method": method, "arguments": arguments.duplicate(true)})

func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value.duplicate(true), "receipt": {}}

func _failure(code: StringName, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "details": details.duplicate(true), "receipt": {}}
