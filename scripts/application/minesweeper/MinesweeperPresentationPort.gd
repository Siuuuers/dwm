class_name MinesweeperPresentationPort
extends RefCounted

const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const REGISTER := preload("res://scripts/application/minesweeper/MinesweeperRegisterQuery.gd")
const OWNER_METHODS := ["get_state", "get_entry_context", "reveal", "set_flag", "chord", "complete_round"]

var _owner: Object = null
var _issuer: Object = null
var _difficulty := ""
var _phase := ""
var _identity: Variant = null
var _revision := -1
var _active_board_token: RefCounted
var _projection: Dictionary = {}
var _configuration: Dictionary = {}
var _pending_configuration: Dictionary = {}
var _terminal_foresight: Variant = null
var _accepted_routine_context: Dictionary = {}
var _accepted_routine_snapshot: Dictionary = {}
var _pending_settlement_request: Dictionary = {}
var _pending_settlement_view: Dictionary = {}
var _pending_preparation_request: Dictionary = {}
var _pending_preparation_context: Dictionary = {}


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
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if _owner == null or difficulty.strip_edges().is_empty():
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	if not _pending_settlement_view.is_empty():
		return settle_pending()
	if not _pending_settlement_request.is_empty():
		var retried: Dictionary = _owner.call(&"complete_round", _pending_settlement_request)
		if not retried.get("ok", false):
			return _failure(&"minesweeper_settlement_refused", _projection)
		_pending_settlement_request = {}
		if not _adopt_after_settlement().get("ok", false):
			return _failure(&"minesweeper_presentation_unavailable")
		return _published_projection()
	var refreshed := _read_owner(difficulty)
	if not refreshed.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(refreshed.value)
	var settled := _settle_terminal(refreshed.value)
	if not settled.get("ok", false):
		return _failure(&"minesweeper_settlement_refused", _projection)
	return _published_projection()


func dispatch(action: String, cell_index: int, expected_revision: int) -> Dictionary:
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if _owner == null or _projection.is_empty():
		return _failure(&"minesweeper_presentation_unavailable")
	var deferred := _settle_if_pending()
	if not deferred.get("ok", false): return deferred
	if action not in ["reveal", "flag", "unflag", "chord"]:
		return _failure(&"minesweeper_action_not_available")
	if expected_revision != _revision:
		return _failure(&"stale_minesweeper_presentation")
	if cell_index < 0 or cell_index >= (_projection.cells as Array).size():
		return _failure(&"minesweeper_action_not_available")
	var cell: Dictionary = _projection.cells[cell_index]
	if not (cell.actions as Array).has(action):
		return _failure(&"minesweeper_action_not_available")

	var routine_command := _phase == "ACTIVE_VISIBLE" and not bool(_projection.terminal)
	if not has_current_active_board():
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
	var issued: Dictionary = _mint_transaction()
	if not issued.get("ok", false):
		return _failure(&"minesweeper_command_refused")
	var issued_value: Dictionary = issued.get("value", {})
	if not issued_value.has("token") or not issued_value.get("issuer_receipt") is Dictionary:
		return _failure(&"minesweeper_command_refused")
	var request := {
		"transaction_id": str(issued_value.token),
		"transaction_issuer_receipt": issued_value.issuer_receipt,
		"expected_identity": _identity,
		"expected_revision": _revision,
		"cell_index": cell_index,
	}
	var result: Dictionary
	match action:
		"reveal":
			if _phase in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARED_UNSTARTED"]:
				request["difficulty_id"] = _difficulty
			result = _owner.call(&"reveal", request)
		"flag", "unflag":
			if _phase in ["NONE", "UNPAID_UNSTARTED"]: request["expected_identity"] = null
			request["flagged"] = action == "flag"
			result = _owner.call(&"set_flag", request)
		"chord": result = _owner.call(&"chord", request)
		_: return _failure(&"minesweeper_action_not_available")
	if not result.get("ok", false):
		var after_refusal := _read_owner(_difficulty)
		if after_refusal.ok: _adopt(after_refusal.value)
		else: _clear()
		return _failure(&"minesweeper_command_refused", _projection)
	var after_commit := _read_owner(_difficulty, routine_command)
	if not after_commit.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after_commit.value)
	if routine_command and not bool(_projection.get("terminal", false)):
		_accepted_routine_context = after_commit.value.routine_context
		_accepted_routine_snapshot = after_commit.value.routine_snapshot
	if _defers_settlement(after_commit.value):
		_pending_settlement_view = after_commit.value
		return {"ok": true, "code": &"minesweeper_settlement_pending", "value": _projection.duplicate(true)}
	var settled := _settle_terminal(after_commit.value)
	if not settled.get("ok", false):
		return _failure(&"minesweeper_settlement_refused", _projection)
	return _published_projection()


func has_pending_settlement() -> bool:
	return not _pending_settlement_view.is_empty()


func settle_pending() -> Dictionary:
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if _owner == null: return _failure(&"minesweeper_presentation_unavailable")
	if _pending_settlement_view.is_empty(): return _published_projection()
	var view := _pending_settlement_view
	_pending_settlement_view = {}
	var settled := _settle_terminal(view)
	if not settled.get("ok", false):
		return _failure(&"minesweeper_settlement_refused", _projection)
	return _published_projection()


func _settle_if_pending() -> Dictionary:
	if _pending_settlement_view.is_empty(): return {"ok": true}
	return settle_pending()


func _defers_settlement(owner_view: Dictionary) -> bool:
	var projection: Dictionary = owner_view["projection"]
	if not bool(projection.get("terminal", false)) or str(owner_view.get("phase", "")) != "ACTIVE_VISIBLE": return false
	if owner_view.configuration.get("settled_inspection", false): return false
	return typeof(owner_view["identity"]) == TYPE_DICTIONARY


func advance_preparation(expected_revision: int) -> Dictionary:
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if _owner == null or _projection.is_empty(): return _failure(&"minesweeper_presentation_unavailable")
	var deferred := _settle_if_pending()
	if not deferred.get("ok", false): return deferred
	if _phase not in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARING"]:
		return {"ok": true, "advanced": false}
	if not _owner.has_method("get_preparation_context"):
		return {"ok": true, "advanced": false}
	var prepared := _read_preparation_context()
	if not prepared.get("ok", false): return _failure(&"minesweeper_preparation_refused", _projection)
	var context: Dictionary = prepared.value
	if expected_revision != _revision or context.revision != _revision:
		return _failure(&"stale_minesweeper_presentation", _projection)
	if context.action == "none": return {"ok": true, "advanced": false}
	context = context.duplicate(true)
	var current := _read_owner(_difficulty)
	var checked := _read_preparation_context()
	if not current.ok or not checked.get("ok", false) or checked.value != context \
			or context.identity != _identity or context.difficulty_id != _difficulty \
			or current.value.revision != _revision or current.value.identity != _identity \
			or current.value.phase != _phase or current.value.projection != _projection:
		if current.ok: _adopt(current.value)
		return _failure(&"stale_minesweeper_presentation", _projection)
	var method: StringName = &"begin_debug_preparation" if context.action == "begin" else &"run_debug_preparation_slice"
	if not _owner.has_method(method): return _failure(&"minesweeper_preparation_refused", _projection)
	if _pending_preparation_context != context:
		_pending_preparation_request = {}
		_pending_preparation_context = {}
	if _pending_preparation_request.is_empty():
		var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
		if not issued.get("ok", false): return _failure(&"minesweeper_preparation_refused", _projection)
		var value: Dictionary = issued.get("value", {})
		if not value.has("token") or not value.get("issuer_receipt") is Dictionary:
			return _failure(&"minesweeper_preparation_refused", _projection)
		_pending_preparation_request = {
			"transaction_id": str(value.token), "transaction_issuer_receipt": value.issuer_receipt,
			"expected_identity": context.identity,
			"expected_revision": _revision,
		}
		if context.action == "begin": _pending_preparation_request["difficulty_id"] = _difficulty
		_pending_preparation_context = context
	var result: Dictionary = _owner.call(method, _pending_preparation_request)
	if not result.get("ok", false): return _failure(&"minesweeper_preparation_refused", _projection)
	_pending_preparation_request = {}
	_pending_preparation_context = {}
	var after := _read_owner(_difficulty)
	if not after.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after.value)
	return {"ok": true, "advanced": true, "value": _projection.duplicate(true)}


func _read_preparation_context() -> Dictionary:
	var result: Dictionary = _owner.call(&"get_preparation_context")
	if not result.get("ok", false) or not result.get("value") is Dictionary: return {"ok": false}
	var value: Dictionary = result.value
	if value.size() != 4: return {"ok": false}
	for key: String in ["action", "difficulty_id", "identity", "revision"]:
		if not value.has(key): return {"ok": false}
	if value.action not in ["none", "begin", "slice"] or not value.difficulty_id is String \
			or not value.revision is int or (value.identity != null and not value.identity is Dictionary):
		return {"ok": false}
	return result


func get_configuration(projection: Dictionary) -> Dictionary:
	if _projection.is_empty() or projection != _projection:
		return _failure(&"stale_minesweeper_presentation")
	return _success({
		"difficulty_enabled": _configuration.get("difficulty_enabled", []).duplicate(),
		"new_board_enabled": bool(_configuration.get("new_board_enabled", false)),
	})


func get_accepted_routine_context(projection: Dictionary) -> Dictionary:
	if _accepted_routine_context.is_empty() \
			or projection != _projection \
			or bool(projection.get("terminal", false)):
		_accepted_routine_context = {}
		_accepted_routine_snapshot = {}
		return {"ok": false}
	var retained_context := _accepted_routine_context
	var retained_snapshot: Dictionary = _accepted_routine_snapshot
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if _active_board_token != null:
		if not has_current_active_board(): return {"ok": false}
	else:
		var current: Variant = _owner.call(&"get_state")
		if not current is Dictionary or not current.get("ok", false) \
				or not current.get("value") is Dictionary or current.value != retained_snapshot:
			return {"ok": false}
	return {"ok": true, "value": retained_context}


func select_difficulty(difficulty: String, expected_revision: int) -> Dictionary:
	return _configure_board(&"select_difficulty", difficulty, expected_revision)


func replace_board(expected_revision: int) -> Dictionary:
	return _configure_board(&"replace_board", _difficulty, expected_revision)


func _configure_board(method: StringName, difficulty: String, expected_revision: int) -> Dictionary:
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if _owner == null or _projection.is_empty() or _configuration.is_empty() \
			or not _owner.has_method(method):
		return _failure(&"minesweeper_action_not_available", _projection)
	var current := _read_owner(_difficulty)
	if not current.ok or expected_revision != _revision \
			or current.value.revision != _revision or current.value.identity != _identity \
			or current.value.phase != _phase or current.value.projection != _projection \
			or current.value.configuration != _configuration:
		if current.ok: _adopt(current.value)
		else: _clear()
		return _failure(&"stale_minesweeper_presentation", _projection)
	if method == &"select_difficulty" and difficulty == _difficulty:
		return _published_projection()
	if method == &"replace_board" and _phase in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARED_UNSTARTED"]:
		return _published_projection()
	if (method == &"select_difficulty" and difficulty not in _configuration.difficulty_enabled) \
			or (method == &"replace_board" and not _configuration.new_board_enabled):
		return _failure(&"minesweeper_action_not_available", _projection)
	if not _pending_configuration.is_empty():
		var source: Dictionary = _pending_configuration.context
		if source.phase != _configuration.phase or source.identity != _configuration.identity \
				or source.revision != _configuration.revision or source.difficulty_id != _configuration.difficulty_id:
			_pending_configuration = {}
		elif _pending_configuration.method != method or _pending_configuration.difficulty != difficulty:
			return _failure(&"minesweeper_command_refused", _projection)
	if _pending_configuration.is_empty():
		var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
		if not issued.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
		var value: Dictionary = issued.get("value", {})
		if not value.has("token") or not value.get("issuer_receipt") is Dictionary:
			return _failure(&"minesweeper_command_refused", _projection)
		_pending_configuration = {"method": method, "difficulty": difficulty,
			"context": _configuration, "request": {
				"transaction_id": str(value.token), "transaction_issuer_receipt": value.issuer_receipt,
				"expected_identity": _configuration.identity,
				"expected_revision": _revision, "difficulty_id": difficulty,
			}}
	var result: Dictionary = _owner.call(method, _pending_configuration.request)
	if result.get("ok", false): _pending_configuration = {}
	var after := _read_owner(difficulty if result.get("ok", false) else _difficulty)
	if not after.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after.value)
	if not result.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
	return _published_projection()


func _read_configuration(snapshot: Dictionary, difficulty: String) -> Dictionary:
	if not _owner.has_method("get_configuration_context"):
		return _success({})
	var result: Dictionary = _owner.call(&"get_configuration_context")
	if not result.get("ok", false) or not result.get("value") is Dictionary:
		return {"ok": false}
	var value: Dictionary = result.value
	var keys := ["phase", "identity", "revision", "difficulty_id", "difficulty_enabled", "new_board_enabled", "settled_inspection"]
	if value.size() != keys.size(): return {"ok": false}
	for key: String in keys:
		if not value.has(key): return {"ok": false}
	if value.phase != snapshot.phase or value.identity != snapshot.identity \
			or value.revision != snapshot.revision or value.difficulty_id != difficulty \
			or not value.difficulty_enabled is Array or not value.new_board_enabled is bool \
			or not value.settled_inspection is bool:
		return {"ok": false}
	var seen: Array[String] = []
	for tier: Variant in value.difficulty_enabled:
		if not tier is String or tier not in ["beginner", "intermediate", "expert"] or tier in seen:
			return {"ok": false}
		seen.append(tier)
	var configuration := value.duplicate()
	configuration.identity = snapshot.identity
	configuration.difficulty_enabled = value.difficulty_enabled.duplicate()
	return _success(configuration)


func _settle_terminal(owner_view: Dictionary) -> Dictionary:
	var projection: Dictionary = owner_view["projection"]
	if owner_view.configuration.get("settled_inspection", false): return {"ok": true}
	if not bool(projection["terminal"]) or str(owner_view["phase"]) != "ACTIVE_VISIBLE":
		if not bool(projection["terminal"]):
			_pending_settlement_request = {}
		return {"ok": true}
	if typeof(owner_view["identity"]) != TYPE_DICTIONARY:
		return {"ok": false}

	var identity: Dictionary = owner_view["identity"]
	var revision := int(owner_view["revision"])
	if _owner.has_method("scene_round_completion_active") and _owner.scene_round_completion_active():
		var completed: Dictionary = _owner.complete_round({"expected_identity": identity, "expected_revision": revision})
		if not completed.get("ok", false): return completed
		return _adopt_after_settlement()
	if (
			_pending_settlement_request.is_empty()
			or _pending_settlement_request.get("expected_identity") != identity
			or int(_pending_settlement_request.get("expected_revision", -1)) != revision
	):
		var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
		if not issued.get("ok", false):
			return {"ok": false}
		var issued_value: Dictionary = issued.get("value", {})
		if not issued_value.has("token") or not issued_value.get("issuer_receipt") is Dictionary:
			return {"ok": false}
		_pending_settlement_request = {
			"transaction_id": str(issued_value["token"]),
			"transaction_issuer_receipt": issued_value["issuer_receipt"],
			"expected_identity": identity,
			"expected_revision": revision,
		}

	var completed: Dictionary = _owner.call(&"complete_round", _pending_settlement_request)
	if not completed.get("ok", false):
		return completed
	_pending_settlement_request = {}
	var refreshed := _adopt_after_settlement()
	return completed if refreshed.get("ok", false) else refreshed


func _adopt_after_settlement() -> Dictionary:
	if not _owner.has_method("get_configuration_context"): return {"ok": true}
	var refreshed := _read_owner(_difficulty)
	if not refreshed.get("ok", false): return {"ok": false}
	_adopt(refreshed.value)
	return {"ok": true}


func can_park_preparation(expected_revision: int) -> bool:
	if not is_instance_valid(_owner) or _phase != "PREPARING" or expected_revision != _revision:
		return false
	var current := _read_owner(_difficulty)
	return current.get("ok", false) and current.value.revision == _revision \
		and current.value.identity == _identity and current.value.phase == _phase \
		and current.value.projection == _projection and _preparation_frontier_available()


func _preparation_frontier_available() -> bool:
	if not _owner.has_method("get_preparation_context"): return false
	var checked := _read_preparation_context()
	return checked.get("ok", false) and checked.value.action == "slice" \
		and checked.value.revision == _revision and checked.value.identity == _identity \
		and checked.value.difficulty_id == _difficulty


func set_foreground(foreground: bool, expected_revision: int) -> Dictionary:
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	if not is_instance_valid(_owner) or not is_instance_valid(_issuer) or _projection.is_empty():
		return _failure(&"minesweeper_presentation_unavailable")
	var current := _read_owner(_difficulty)
	if not current.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	if expected_revision != _revision or int(current.value.revision) != _revision \
			or current.value.identity != _identity or current.value.phase != _phase \
			or current.value.projection != _projection:
		_adopt(current.value)
		return _failure(&"stale_minesweeper_presentation", _projection)
	if _projection.terminal:
		if _configuration.get("settled_inspection", false):
			return _published_projection()
		return _failure(&"minesweeper_action_not_available", _projection)
	if _phase == "SETTLING":
		return _failure(&"minesweeper_action_not_available", _projection)
	if _phase == "PREPARING":
		if not _preparation_frontier_available():
			return _failure(&"minesweeper_action_not_available", _projection)
		return _published_projection()
	if _phase in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARED_UNSTARTED"] \
			or foreground and _phase == "ACTIVE_VISIBLE" \
			or not foreground and _phase == "ACTIVE_SUSPENDED":
		return _published_projection()
	var method: StringName = &"resume" if foreground else &"suspend"
	if not _owner.has_method(method): return _failure(&"minesweeper_action_not_available", _projection)
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	if not issued.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
	var value: Dictionary = issued.get("value", {})
	if not value.has("token") or not value.get("issuer_receipt") is Dictionary:
		return _failure(&"minesweeper_command_refused", _projection)
	var result: Dictionary = _owner.call(method, {
		"transaction_id": str(value.token), "transaction_issuer_receipt": value.issuer_receipt,
		"expected_identity": _identity, "expected_revision": _revision,
	})
	var after := _read_owner(_difficulty)
	if not after.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after.value)
	if not result.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
	return _published_projection()


func get_terminal_foresight(projection: Dictionary) -> Dictionary:
	if not _terminal_foresight is int or projection != _projection or not projection.get("terminal", false):
		return {"ok": false}
	return {"ok": true, "value": _terminal_foresight}


func _mint_transaction() -> Dictionary:
	if not _issuer.has_method("issue_deferred"):
		return _issuer.call(&"issue", &"transaction_id")
	return _issuer.call(&"issue_deferred", &"transaction_id")


func has_current_active_board(difficulty: String = "") -> bool:
	return _active_board_token != null and (difficulty.is_empty() or difficulty == _difficulty) \
		and not _projection.terminal and _owner.get_active_board_token() == _active_board_token


func _read_owner(difficulty: String, include_routine_context: bool = false) -> Dictionary:
	var active_board_token: RefCounted = _owner.get_active_board_token() if _owner.has_method("get_active_board_token") else null
	var state_result: Dictionary = _owner.call(&"get_state")
	if not state_result.get("ok", false) or not state_result.get("value") is Dictionary:
		return {"ok": false}
	var snapshot: Dictionary = state_result.value
	if snapshot.get("phase") in ["PREPARED_UNSTARTED", "PAID_UNSTARTED"]:
		var candidate_value: Variant = snapshot.get("candidate")
		if not candidate_value is Dictionary:
			return {"ok": false}
		var candidate: Dictionary = candidate_value
		var spec_value: Variant = candidate.get("spec")
		if not spec_value is Dictionary or str((spec_value as Dictionary).get("difficulty_id", "")) != difficulty:
			return {"ok": false}
	var eligible := false
	var identity: Variant = snapshot.get("identity")
	if snapshot.get("phase") in ["NONE", "UNPAID_UNSTARTED"]:
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
	var configuration := _read_configuration(snapshot, difficulty)
	if not configuration.get("ok", false): return {"ok": false}
	var terminal_foresight: Variant = null
	if projected.value.terminal:
		terminal_foresight = PERFORMANCE.display_percent(snapshot.board.board)
	var routine_context: Dictionary = {}
	if include_routine_context and snapshot.phase == "ACTIVE_VISIBLE" and not projected.value.terminal:
		var derived := _derive_routine_context(snapshot, difficulty, configuration.value)
		if not derived.get("ok", false): return {"ok": false}
		routine_context = derived.value
	return {"ok": true, "value": {
		"difficulty": difficulty, "phase": str(snapshot.phase), "active_board_token": active_board_token,
		"identity": identity.duplicate() if identity is Dictionary else null,
		"revision": int(snapshot.revision), "projection": projected.value,
		"terminal_foresight": terminal_foresight, "configuration": configuration.value,
		"routine_context": routine_context,
		"routine_snapshot": snapshot if not routine_context.is_empty() and active_board_token == null else {},
	}}


func _derive_routine_context(snapshot: Dictionary, difficulty: String,
		configuration: Dictionary) -> Dictionary:
	var metrics := REGISTER.retained_metrics(snapshot)
	if not metrics.get("ok", false) or not metrics.value.foresight is int:
		return {"ok": false}
	return _success({
		"difficulty": difficulty,
		"foresight": metrics.value.foresight,
		"no_flag": metrics.value.no_flag,
		"configuration": {
			"difficulty_enabled": configuration.get("difficulty_enabled", []).duplicate(),
			"new_board_enabled": bool(configuration.get("new_board_enabled", false)),
		},
	})


func _adopt(value: Dictionary) -> void:
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}
	_active_board_token = value.active_board_token
	_difficulty = value.difficulty
	_phase = value.phase
	_identity = value.identity
	_revision = value.revision
	_projection = value.projection
	_configuration = value.configuration
	_terminal_foresight = value.terminal_foresight


func _clear() -> void:
	_active_board_token = null
	_difficulty = ""
	_phase = ""
	_identity = null
	_revision = -1
	_projection = {}
	_configuration = {}
	_terminal_foresight = null
	_accepted_routine_context = {}
	_accepted_routine_snapshot = {}


func _published_projection() -> Dictionary:
	return _success(_projection.duplicate(true))


func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


func _failure(code: StringName, projection: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "code": code}
	if not projection.is_empty(): result["value"] = projection.duplicate(true)
	return result
