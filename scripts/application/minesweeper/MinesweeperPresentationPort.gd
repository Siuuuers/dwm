class_name MinesweeperPresentationPort
extends RefCounted
## Narrow UI command boundary. Owner identities and issuer receipts never leave this object.

const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const OWNER_METHODS := ["get_state", "get_entry_context", "reveal", "set_flag", "chord", "complete_round"]

var _owner: Object = null
var _issuer: Object = null
var _difficulty := ""
var _phase := ""
var _identity: Variant = null
var _revision := -1
var _projection: Dictionary = {}
var _configuration: Dictionary = {}
var _pending_configuration: Dictionary = {}
var _terminal_foresight: Variant = null
var _pending_settlement_request: Dictionary = {}
## dwm-634.1: the owner view of a terminal command whose settlement was deferred so the board
## could paint first. Consumed by settle_pending() or by the next entry into this port.
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
	if _owner == null or difficulty.strip_edges().is_empty():
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	if not _pending_settlement_view.is_empty():
		var deferred := settle_pending()
		if not deferred.get("ok", false): return deferred
		return _success(_projection.duplicate(true))
	# Source commit may already have cleared the board while the full save is pending.
	# Retry the exact retained settlement before reading NONE and losing that request.
	if not _pending_settlement_request.is_empty():
		var retried: Dictionary = _owner.call(&"complete_round", _pending_settlement_request.duplicate(true))
		if not retried.get("ok", false):
			return _failure(&"minesweeper_settlement_refused", _projection)
		_pending_settlement_request = {}
		if not _adopt_after_settlement().get("ok", false):
			return _failure(&"minesweeper_presentation_unavailable")
		return _success(_projection.duplicate(true))
	var refreshed := _read_owner(difficulty)
	if not refreshed.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(refreshed.value)
	var settled := _settle_terminal(refreshed.value)
	if not settled.get("ok", false):
		return _failure(&"minesweeper_settlement_refused", _projection)
	return _success(_projection.duplicate(true))


func dispatch(action: String, cell_index: int, expected_revision: int) -> Dictionary:
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
	var durable_first_reveal := action == "reveal" and _phase in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARED_UNSTARTED"]
	var issued: Dictionary = _mint_transaction(durable_first_reveal)
	if not issued.get("ok", false):
		return _failure(&"minesweeper_command_refused")
	var issued_value: Dictionary = issued.get("value", {})
	if not issued_value.has("token") or not issued_value.get("issuer_receipt") is Dictionary:
		return _failure(&"minesweeper_command_refused")
	var request := {
		"transaction_id": str(issued_value.token),
		"transaction_issuer_receipt": (issued_value.issuer_receipt as Dictionary).duplicate(true),
		"expected_identity": _identity.duplicate(true) if _identity is Dictionary else null,
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
	var after_commit := _read_owner(_difficulty)
	if not after_commit.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after_commit.value)
	if _defers_settlement(after_commit.value):
		# dwm-634.1: the terminal board is already committed and under custody. Publish it now so
		# the click paints, and run settlement from settle_pending() or the next entry into this port.
		_pending_settlement_view = after_commit.value
		return {"ok": true, "code": &"minesweeper_settlement_pending", "value": _projection.duplicate(true)}
	var settled := _settle_terminal(after_commit.value)
	if not settled.get("ok", false):
		return _failure(&"minesweeper_settlement_refused", _projection)
	return _success(_projection.duplicate(true))


func has_pending_settlement() -> bool:
	return not _pending_settlement_view.is_empty()


## Runs the settlement a terminal command deferred. A refusal keeps the exact completion request
## (never the deferral), so pull() retries it exactly as it always has.
func settle_pending() -> Dictionary:
	if _owner == null: return _failure(&"minesweeper_presentation_unavailable")
	if _pending_settlement_view.is_empty(): return _success(_projection.duplicate(true))
	var view := _pending_settlement_view
	_pending_settlement_view = {}
	var settled := _settle_terminal(view)
	if not settled.get("ok", false):
		return _failure(&"minesweeper_settlement_refused", _projection)
	return _success(_projection.duplicate(true))


func _settle_if_pending() -> Dictionary:
	if _pending_settlement_view.is_empty(): return {"ok": true}
	return settle_pending()


## Mirrors _settle_terminal()'s own gate: only a live, unsettled terminal board is deferred.
func _defers_settlement(owner_view: Dictionary) -> bool:
	var projection: Dictionary = owner_view["projection"]
	if not bool(projection.get("terminal", false)) or str(owner_view.get("phase", "")) != "ACTIVE_VISIBLE": return false
	if owner_view.configuration.get("settled_inspection", false): return false
	return typeof(owner_view["identity"]) == TYPE_DICTIONARY


## Explicit foreground work step. Pure pull never starts or advances a generator.
func advance_preparation(expected_revision: int) -> Dictionary:
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
			"transaction_id": str(value.token), "transaction_issuer_receipt": value.issuer_receipt.duplicate(true),
			"expected_identity": context.identity.duplicate(true) if context.identity is Dictionary else null,
			"expected_revision": _revision,
		}
		if context.action == "begin": _pending_preparation_request["difficulty_id"] = _difficulty
		_pending_preparation_context = context.duplicate(true)
	var result: Dictionary = _owner.call(method, _pending_preparation_request.duplicate(true))
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
	return _success(value.duplicate(true))


## Capability projection contains no owner identity. Legacy minimal owners expose no controls.
func get_configuration(projection: Dictionary) -> Dictionary:
	if _projection.is_empty() or projection != _projection:
		return _failure(&"stale_minesweeper_presentation")
	return _success({
		"difficulty_enabled": _configuration.get("difficulty_enabled", []).duplicate(),
		"new_board_enabled": bool(_configuration.get("new_board_enabled", false)),
	})


func select_difficulty(difficulty: String, expected_revision: int) -> Dictionary:
	return _configure_board(&"select_difficulty", difficulty, expected_revision)


func replace_board(expected_revision: int) -> Dictionary:
	return _configure_board(&"replace_board", _difficulty, expected_revision)


func _configure_board(method: StringName, difficulty: String, expected_revision: int) -> Dictionary:
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
	# These are view-level no-ops: no command, nonce, checkpoint, or new board is admitted.
	if method == &"select_difficulty" and difficulty == _difficulty:
		return _success(_projection.duplicate(true))
	if method == &"replace_board" and _phase in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARED_UNSTARTED"]:
		return _success(_projection.duplicate(true))
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
			"context": _configuration.duplicate(true), "request": {
				"transaction_id": str(value.token), "transaction_issuer_receipt": value.issuer_receipt.duplicate(true),
				"expected_identity": _configuration.identity.duplicate(true) if _configuration.identity is Dictionary else null,
				"expected_revision": _revision, "difficulty_id": difficulty,
			}}
	var result: Dictionary = _owner.call(method, _pending_configuration.request.duplicate(true))
	if result.get("ok", false): _pending_configuration = {}
	var after := _read_owner(difficulty if result.get("ok", false) else _difficulty)
	if not after.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after.value)
	if not result.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
	return _success(_projection.duplicate(true))


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
	return _success(value.duplicate(true))


## A terminal board is already committed and safe to render before settlement starts. Retain the
## exact completion request across transient failures so retry cannot allocate a second reward.
func _settle_terminal(owner_view: Dictionary) -> Dictionary:
	var projection: Dictionary = owner_view["projection"]
	# The canonical completion receipt already paid this terminal result. Cold inspection
	# must never issue a second completion command or repeat its consequences.
	if owner_view.configuration.get("settled_inspection", false): return {"ok": true}
	if not bool(projection["terminal"]) or str(owner_view["phase"]) != "ACTIVE_VISIBLE":
		if not bool(projection["terminal"]):
			_pending_settlement_request = {}
		return {"ok": true}
	if typeof(owner_view["identity"]) != TYPE_DICTIONARY:
		return {"ok": false}

	var identity: Dictionary = owner_view["identity"]
	var revision := int(owner_view["revision"])
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
			"transaction_issuer_receipt": (issued_value["issuer_receipt"] as Dictionary).duplicate(true),
			"expected_identity": identity.duplicate(true),
			"expected_revision": revision,
		}

	var completed: Dictionary = _owner.call(&"complete_round", _pending_settlement_request.duplicate(true))
	if not completed.get("ok", false):
		return completed
	_pending_settlement_request = {}
	var refreshed := _adopt_after_settlement()
	return completed if refreshed.get("ok", false) else refreshed


func _adopt_after_settlement() -> Dictionary:
	# Minimal legacy owners predate retained inspection and clear the board on completion.
	if not _owner.has_method("get_configuration_context"): return {"ok": true}
	var refreshed := _read_owner(_difficulty)
	if not refreshed.get("ok", false): return {"ok": false}
	_adopt(refreshed.value)
	return {"ok": true}


## Queried only for custody-bound Home admission, not by the per-frame idle pump.
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
	# An unsettled terminal is still under owner custody. Visibility cannot settle or bypass it.
	if _projection.terminal:
		if _configuration.get("settled_inspection", false):
			return _success(_projection.duplicate(true))
		return _failure(&"minesweeper_action_not_available", _projection)
	if _phase == "SETTLING":
		return _failure(&"minesweeper_action_not_available", _projection)
	# Between explicit slices the saved frontier is stable. Showing or parking it changes
	# visibility only; this boundary never issues a command or advances the search.
	if _phase == "PREPARING":
		if not _preparation_frontier_available():
			return _failure(&"minesweeper_action_not_available", _projection)
		return _success(_projection.duplicate(true))
	if _phase in ["NONE", "UNPAID_UNSTARTED", "PAID_UNSTARTED", "PREPARED_UNSTARTED"] \
			or foreground and _phase == "ACTIVE_VISIBLE" \
			or not foreground and _phase == "ACTIVE_SUSPENDED":
		return _success(_projection.duplicate(true))
	var method: StringName = &"resume" if foreground else &"suspend"
	if not _owner.has_method(method): return _failure(&"minesweeper_action_not_available", _projection)
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	if not issued.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
	var value: Dictionary = issued.get("value", {})
	if not value.has("token") or not value.get("issuer_receipt") is Dictionary:
		return _failure(&"minesweeper_command_refused", _projection)
	var result: Dictionary = _owner.call(method, {
		"transaction_id": str(value.token), "transaction_issuer_receipt": value.issuer_receipt.duplicate(true),
		"expected_identity": (_identity as Dictionary).duplicate(true), "expected_revision": _revision,
	})
	var after := _read_owner(_difficulty)
	if not after.ok:
		_clear()
		return _failure(&"minesweeper_presentation_unavailable")
	_adopt(after.value)
	if not result.get("ok", false): return _failure(&"minesweeper_command_refused", _projection)
	return _success(_projection.duplicate(true))


## Read the derived metric bound to this exact final public projection. Settlement may
## already have cleared the canonical board; retain no hidden layout or second history here.
func get_terminal_foresight(projection: Dictionary) -> Dictionary:
	if not _terminal_foresight is int or projection != _projection or not projection.get("terminal", false):
		return {"ok": false}
	return {"ok": true, "value": _terminal_foresight}


## Routine board commands leave the board in memory, so their receipts stay in memory too
## (dwm-634.1); the ledger is written whenever the board is. First Reveal consumes a round and
## commits a durable checkpoint, so its receipt is durable before the command runs.
func _mint_transaction(durable: bool) -> Dictionary:
	if durable or not _issuer.has_method("issue_deferred"):
		return _issuer.call(&"issue", &"transaction_id")
	return _issuer.call(&"issue_deferred", &"transaction_id")


func _read_owner(difficulty: String) -> Dictionary:
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
	return {"ok": true, "value": {
		"difficulty": difficulty, "phase": str(snapshot.phase),
		"identity": identity.duplicate(true) if identity is Dictionary else null,
		"revision": int(snapshot.revision), "projection": projected.value.duplicate(true),
		"terminal_foresight": terminal_foresight, "configuration": configuration.value,
	}}


func _adopt(value: Dictionary) -> void:
	_difficulty = value.difficulty
	_phase = value.phase
	_identity = value.identity.duplicate(true) if value.identity is Dictionary else null
	_revision = value.revision
	_projection = value.projection.duplicate(true)
	_configuration = value.configuration.duplicate(true)
	_terminal_foresight = value.terminal_foresight


func _clear() -> void:
	_difficulty = ""
	_phase = ""
	_identity = null
	_revision = -1
	_projection = {}
	_configuration = {}
	_terminal_foresight = null


func _success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


func _failure(code: StringName, projection: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "code": code}
	if not projection.is_empty(): result["value"] = projection.duplicate(true)
	return result
