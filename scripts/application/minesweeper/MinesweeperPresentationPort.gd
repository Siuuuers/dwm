class_name MinesweeperPresentationPort
extends RefCounted
## Narrow UI command boundary. Owner identities and issuer receipts never leave this object.

const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const OWNER_METHODS := ["get_state", "get_entry_context", "reveal", "set_flag", "chord"]

var _owner: Object = null
var _issuer: Object = null
var _difficulty := ""
var _phase := ""
var _identity: Variant = null
var _revision := -1
var _projection: Dictionary = {}


func configure(owner: Object, issuer: Object) -> Dictionary:
	if owner == null or issuer == null or not issuer.has_method("issue") \
			or not issuer.has_method("verify_issued"):
		return _failure(&"minesweeper_presentation_unavailable")
	for method: String in OWNER_METHODS:
		if not owner.has_method(method): return _failure(&"minesweeper_presentation_unavailable")
	if _owner != null:
		if _owner == owner and _issuer == issuer: return _success({"already_configured": true})
		return _failure(&"minesweeper_presentation_already_configured")
	_owner = owner
	_issuer = issuer
	return _success({"already_configured": false})


func pull(difficulty: String) -> Dictionary:
	if _owner == null or difficulty.strip_edges().is_empty():
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	var refreshed := _read_owner(difficulty)
	if not refreshed.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(refreshed.value)
	return _success(_projection.duplicate(true))


func dispatch(action: String, cell_index: int, expected_revision: int) -> Dictionary:
	if _owner == null or _projection.is_empty():
		return _failure(&"minesweeper_presentation_unavailable")
	if action not in ["reveal", "flag", "unflag", "chord"]:
		return _failure(&"minesweeper_action_not_available")
	if expected_revision != _revision:
		return _failure(&"stale_minesweeper_presentation")
	if cell_index < 0 or cell_index >= (_projection.cells as Array).size():
		return _failure(&"minesweeper_action_not_available")
	var cell: Dictionary = _projection.cells[cell_index]
	if not (cell.actions as Array).has(action):
		return _failure(&"minesweeper_action_not_available")

	# Re-read immediately before allocation. Revision alone is insufficient across a restored owner.
	var current := _read_owner(_difficulty)
	if not current.ok or int(current.value.revision) != _revision \
			or current.value.identity != _identity or current.value.phase != _phase:
		if current.ok: _adopt(current.value)
		else: _clear()
		return _failure(&"stale_minesweeper_presentation", _projection)
	var current_projection: Dictionary = current.value.projection
	if cell_index >= (current_projection.cells as Array).size() \
			or not (((current_projection.cells as Array)[cell_index] as Dictionary).actions as Array).has(action):
		_adopt(current.value)
		return _failure(&"minesweeper_action_not_available", _projection)
	if current_projection != _projection:
		_adopt(current.value)
		return _failure(&"stale_minesweeper_presentation", _projection)
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	if not issued.get("ok", false):
		return _failure(&"minesweeper_command_refused")
	var issued_value: Dictionary = issued.get("value", {})
	if not issued_value.has("token") or not issued_value.get("issuer_receipt") is Dictionary:
		return _failure(&"minesweeper_command_refused")
	var request := {
		"transaction_id": str(issued_value.token),
		"transaction_issuer_receipt": (issued_value.issuer_receipt as Dictionary).duplicate(true),
		"expected_identity": (_identity as Dictionary).duplicate(true),
		"expected_revision": _revision,
		"cell_index": cell_index,
	}
	var result: Dictionary
	match action:
		"reveal":
			if _phase in ["NONE", "PREPARED_UNSTARTED"]: request["difficulty_id"] = _difficulty
			result = _owner.call(&"reveal", request)
		"flag", "unflag":
			request["flagged"] = action == "flag"
			result = _owner.call(&"set_flag", request)
		"chord": result = _owner.call(&"chord", request)
		_: return _failure(&"minesweeper_action_not_available")
	if not result.get("ok", false):
		var after_refusal := _read_owner(_difficulty)
		if after_refusal.ok: _adopt(after_refusal.value)
		else: _clear()
		return _failure(&"minesweeper_command_refused", _projection)
	var after_commit := _read_owner(_difficulty)
	if not after_commit.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after_commit.value)
	return _success(_projection.duplicate(true))


func _read_owner(difficulty: String) -> Dictionary:
	var state_result: Dictionary = _owner.call(&"get_state")
	if not state_result.get("ok", false) or not state_result.get("value") is Dictionary:
		return {"ok": false}
	var snapshot: Dictionary = state_result.value
	if snapshot.get("phase") == "PREPARED_UNSTARTED":
		var candidate_value: Variant = snapshot.get("candidate")
		if not candidate_value is Dictionary:
			return {"ok": false}
		var candidate: Dictionary = candidate_value
		var spec_value: Variant = candidate.get("spec")
		if not spec_value is Dictionary or str((spec_value as Dictionary).get("difficulty_id", "")) != difficulty:
			return {"ok": false}
	var eligible := false
	var identity: Variant = snapshot.get("identity")
	if snapshot.get("phase") == "NONE":
		var entry: Dictionary = _owner.call(&"get_entry_context", difficulty)
		if not entry.get("ok", false) or not entry.get("value") is Dictionary:
			return {"ok": false}
		var context: Dictionary = entry.value
		if context.get("difficulty_id") != difficulty or int(context.get("revision", -1)) != int(snapshot.get("revision", -2)):
			return {"ok": false}
		eligible = bool(context.get("eligible", false))
		identity = context.get("identity")
		if eligible and not identity is Dictionary: return {"ok": false}
	var projected: Dictionary = QUERY.desktop(snapshot, difficulty, eligible)
	if not projected.get("ok", false): return {"ok": false}
	return {"ok": true, "value": {
		"difficulty": difficulty, "phase": str(snapshot.phase),
		"identity": identity.duplicate(true) if identity is Dictionary else null,
		"revision": int(snapshot.revision), "projection": projected.value.duplicate(true),
	}}


func _adopt(value: Dictionary) -> void:
	_difficulty = value.difficulty
	_phase = value.phase
	_identity = value.identity.duplicate(true) if value.identity is Dictionary else null
	_revision = value.revision
	_projection = value.projection.duplicate(true)


func _clear() -> void:
	_difficulty = ""
	_phase = ""
	_identity = null
	_revision = -1
	_projection = {}


func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


func _failure(code: StringName, projection: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "code": code}
	if not projection.is_empty(): result["value"] = projection.duplicate(true)
	return result
