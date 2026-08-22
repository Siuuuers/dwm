class_name ApplicationMutationGate
extends RefCounted

## The sole production mutation gate and irreversible process-fatal fence
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).

signal capability_changed(capability: Dictionary)

const VALID_OWNERS: Array[StringName] = [&"restore", &"new_run", &"causal_transaction"]
const FAILURE_KEYS: Array[String] = ["code", "details", "phase", "source"]
const DETAIL_DEPTH_BUDGET := 32

var _active_owner: StringName = &""
var _active_token := ""
var _token_counter := 0
var _fatal_latched := false
var _fatal_failure: Dictionary = {}

func acquire(owner_id: StringName) -> Dictionary:
	if _fatal_latched:
		return _fatal_result()
	if owner_id not in VALID_OWNERS:
		return {"ok": false, "code": &"INVALID_OWNER", "message": String(owner_id)}
	if _active_owner != &"":
		return {"ok": false, "code": &"TRANSACTION_ACTIVE", "message": String(_active_owner)}
	_token_counter += 1
	_active_owner = owner_id
	_active_token = "gate-token-%d" % _token_counter
	return {"ok": true, "code": &"ok", "value": {"token": _active_token}}

func release(owner_id: StringName, token: String) -> Dictionary:
	if _fatal_latched:
		return _fatal_result()
	if owner_id != _active_owner or token != _active_token or _active_owner == &"":
		return {"ok": false, "code": &"RELEASE_MISMATCH", "message": String(owner_id)}
	_active_owner = &""
	_active_token = ""
	return {"ok": true, "code": &"ok", "value": {"released": true}}

func guard_external(_operation_id: StringName) -> Dictionary:
	if _fatal_latched:
		return _fatal_result()
	if _active_owner != &"":
		return {"ok": false, "code": &"TRANSACTION_ACTIVE", "message": String(_active_owner)}
	return {"ok": true, "code": &"ok"}

func is_active() -> bool:
	return _active_owner != &""

func get_active_owner() -> StringName:
	return _active_owner

func is_internal_owner_active(owner_id: StringName) -> bool:
	if _fatal_latched:
		return false
	return _active_owner != &"" and owner_id == _active_owner

func latch_fatal(failure: Dictionary) -> Dictionary:
	var normalized := _normalize_failure(failure)
	if normalized.is_empty():
		return {"ok": false, "code": &"INVALID_FATAL_FAILURE", "message": "malformed fatal failure"}
	if _fatal_latched:
		if _fatal_failure == normalized:
			return {
				"ok": true, "code": &"ok",
				"value": {"fatal_latched": true, "already_latched": true},
				"receipt": {"failure": _fatal_failure.duplicate(true)},
			}
		return {
			"ok": false, "code": &"APPLICATION_FATAL_CONFLICT",
			"details": {
				"latched_failure": _fatal_failure.duplicate(true),
				"requested_failure": normalized,
			},
		}
	_fatal_latched = true
	_fatal_failure = normalized
	capability_changed.emit({
		"enabled": false,
		"code": &"APPLICATION_FATAL",
		"active_owner": _active_owner if _active_owner != &"" else null,
		"fatal_latched": true,
		"failure": _fatal_failure.duplicate(true),
	})
	return {
		"ok": true, "code": &"ok",
		"value": {"fatal_latched": true, "already_latched": false},
		"receipt": {"failure": _fatal_failure.duplicate(true)},
	}

func is_fatal_latched() -> bool:
	return _fatal_latched

func _fatal_result() -> Dictionary:
	return {
		"ok": false, "code": &"APPLICATION_FATAL",
		"details": {"failure": _fatal_failure.duplicate(true)},
	}

static func _normalize_failure(failure: Dictionary) -> Dictionary:
	var keys := failure.keys()
	var string_keys: Array[String] = []
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			return {}
		string_keys.append(str(key))
	string_keys.sort()
	if string_keys != FAILURE_KEYS:
		return {}
	var normalized := {}
	for field: String in ["source", "phase", "code"]:
		var value: Variant = failure[field]
		if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
			return {}
		var text := str(value)
		if text.is_empty():
			return {}
		normalized[field] = text
	if typeof(failure["details"]) != TYPE_DICTIONARY:
		return {}
	if not _details_valid(failure["details"], DETAIL_DEPTH_BUDGET):
		return {}
	normalized["details"] = (failure["details"] as Dictionary).duplicate(true)
	return normalized

static func _details_valid(value: Variant, depth: int) -> bool:
	if depth <= 0:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for element: Variant in value:
				if not _details_valid(element, depth - 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in (value as Dictionary):
				if typeof(key) != TYPE_STRING:
					return false
				if not _details_valid(value[key], depth - 1):
					return false
			return true
	return false
