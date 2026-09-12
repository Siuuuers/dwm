class_name MinesweeperPanelPort
extends RefCounted
## Composes public board, register and assignment facts without exposing domain snapshots.
## A successfully settled terminal board remains a detached application view until New Board.

const BOARD_PORT := preload("res://scripts/application/minesweeper/MinesweeperPresentationPort.gd")
const REGISTER := preload("res://scripts/application/minesweeper/MinesweeperRegisterQuery.gd")
const ASSIGNMENTS := preload("res://scripts/application/minesweeper/MinesweeperAssignmentsQuery.gd")
const PLAY_ACTIONS: Array[String] = ["reveal", "flag", "drag", "assignments", "rules"]
const SETTLED_ACTIONS: Array[String] = ["new_board", "assignments", "rules"]

var _owner: Object = null
var _issuer: Object = null
var _game_state: Object = null
var _catalog: Object = null
var _board_port: Object = null
var _presented := false
var _presented_difficulty := ""
var _presented_view: Dictionary = {}
var _presented_session: Dictionary = {}
var _held_terminal: Dictionary = {}
var _held_session: Dictionary = {}


func configure(owner: Object, issuer: Object, game_state: Object, catalog: Object) -> Dictionary:
	if _board_port != null:
		if _owner == owner and _issuer == issuer and _game_state == game_state and _catalog == catalog:
			return {"ok": true, "value": {"already_configured": true}}
		return {"ok": false, "code": &"minesweeper_panel_already_configured"}
	if not is_instance_valid(owner) or not is_instance_valid(issuer) \
			or not is_instance_valid(game_state) or not game_state.has_method("capture_live_session") \
			or not is_instance_valid(catalog) or not catalog.has_method("get_minesweeper_tasks"):
		return _unavailable()
	var candidate := BOARD_PORT.new()
	if not candidate.configure(owner, issuer).get("ok", false): return _unavailable()
	_owner = owner
	_issuer = issuer
	_game_state = game_state
	_catalog = catalog
	_board_port = candidate
	for signal_name: StringName in [&"day_changed", &"daily_state_reset"]:
		if game_state.has_signal(signal_name) \
				and not game_state.is_connected(signal_name, _on_game_state_day_changed):
			game_state.connect(signal_name, _on_game_state_day_changed)
	return {"ok": true, "value": {"already_configured": false}}


func pull() -> Dictionary:
	_presented = false
	_presented_difficulty = ""
	_presented_view = {}
	if _board_port == null or not is_instance_valid(_owner) \
			or not is_instance_valid(_issuer) or not is_instance_valid(_game_state) \
			or not is_instance_valid(_catalog):
		return _unavailable()
	_discard_stale_terminal()
	if not _held_terminal.is_empty():
		if not _owner.has_method("get_configuration_context"):
			return _present_success(_held_terminal)
		# Production retains the board and completion receipt in the canonical owner.
		# Refresh from that owner; this cache is never authority for a completed result.
		_clear_held_terminal()
	var initial: Variant = _owner.call(&"get_state")
	if not initial is Dictionary or not initial.get("ok", false) \
			or not initial.get("value") is Dictionary:
		return _unavailable()
	var snapshot: Dictionary = initial.value
	var register: Dictionary = REGISTER.desktop(snapshot, _game_state)
	if not register.get("ok", false): return _unavailable()
	var board: Dictionary = _board_port.call(&"pull", register.value.difficulty)
	var assignments: Dictionary = ASSIGNMENTS.from_sources(_game_state, _catalog)
	if not assignments.get("ok", false): return _unavailable()
	if board.get("value") is Dictionary and bool(board.value.get("terminal", false)):
		var terminal := _terminal_view(board.value, register.value, assignments.value,
			board.get("ok", false))
		if terminal.is_empty(): return _unavailable()
		if board.get("ok", false):
			return _hold_terminal(terminal)
		_present_failure(terminal)
		return {"ok": false, "code": &"minesweeper_panel_command_refused",
			"value": terminal.duplicate(true)}
	if not board.get("ok", false): return _unavailable()
	if board.value.revision != snapshot.revision or board.value.custody != register.value.custody \
			or board.value.mine_estimate != register.value.mine_estimate:
		return _unavailable()
	# Nonterminal reads remain a strict before/after snapshot transaction.
	var final_state: Variant = _owner.call(&"get_state")
	if not final_state is Dictionary or not final_state.get("ok", false) \
			or final_state.get("value") != snapshot:
		return _unavailable()
	if REGISTER.desktop(snapshot, _game_state) != register \
			or ASSIGNMENTS.from_sources(_game_state, _catalog) != assignments:
		return _unavailable()
	var configuration: Dictionary = _board_port.get_configuration(board.value)
	if not configuration.get("ok", false): return _unavailable()
	var actions: Array[String] = []
	if not register.value.custody:
		actions.assign(PLAY_ACTIONS)
		if configuration.value.new_board_enabled: actions.append("new_board")
		register.value.difficulty_enabled = configuration.value.difficulty_enabled.duplicate()
	return _present_success({
		"board": board.value.duplicate(true), "register": register.value.duplicate(true),
		"assignments": assignments.value.duplicate(), "actions": actions, "settled": false,
	})


func dispatch(action: String, index: int, revision: int) -> Dictionary:
	_discard_stale_terminal()
	if not _held_terminal.is_empty():
		if action != "new_board" or revision != int(_held_terminal.board.revision):
			return {"ok": false, "code": &"minesweeper_panel_command_refused",
				"value": _held_terminal.duplicate(true)}
		if _owner.has_method("get_configuration_context"):
			if not _has_fresh_difficulty(): return _refused()
			var dismissed: Dictionary = _board_port.replace_board(revision)
			if not dismissed.get("ok", false): return _refused()
		_clear_held_terminal()
		return pull()
	if not _has_fresh_difficulty(): return _refused()
	var result: Dictionary
	if action == "new_board":
		result = _board_port.replace_board(revision)
	else:
		result = _board_port.call(&"dispatch", action, index, revision)
	if result.get("value") is Dictionary and bool(result.value.get("terminal", false)):
		var assignments: Dictionary = ASSIGNMENTS.from_sources(_game_state, _catalog)
		if not assignments.get("ok", false) or _presented_view.is_empty(): return _unavailable()
		# dwm-634.1: a pending settlement publishes the terminal board unsettled; the pump settles it.
		var settled_now: bool = result.get("ok", false) and result.get("code") != &"minesweeper_settlement_pending"
		var terminal := _terminal_view(result.value, _presented_view.register,
			assignments.value, settled_now)
		if terminal.is_empty(): return _unavailable()
		if result.get("ok", false):
			return _hold_terminal(terminal)
		_present_failure(terminal)
		return {"ok": false, "code": &"minesweeper_panel_command_refused",
			"value": terminal.duplicate(true)}
	if not result.get("ok", false): return _refused()
	return pull()


func advance_preparation(expected_revision: int) -> Dictionary:
	_discard_stale_terminal()
	if not _held_terminal.is_empty():
		if has_pending_settlement():
			var unsettled: Dictionary = _held_terminal.duplicate(true)
			var settled: Dictionary = _board_port.settle_pending()
			var assignments: Dictionary = ASSIGNMENTS.from_sources(_game_state, _catalog)
			if not assignments.get("ok", false): return _unavailable()
			if not settled.get("ok", false) or not settled.get("value") is Dictionary:
				_clear_held_terminal()
				_present_failure(unsettled)
				return {"ok": false, "code": &"minesweeper_panel_command_refused", "value": unsettled}
			var terminal := _terminal_view(settled.value, unsettled.register, assignments.value, true)
			if terminal.is_empty(): return _unavailable()
			var published := _hold_terminal(terminal)
			if published.get("ok", false): published["advanced"] = true
			return published
		return {"ok": true, "advanced": false}
	if not _presented or _presented_session.is_empty() or _session_marker() != _presented_session:
		return _refused()
	var result: Dictionary = _board_port.advance_preparation(expected_revision)
	if not result.get("ok", false): return _refused()
	if not result.get("advanced", false): return {"ok": true, "advanced": false}
	var refreshed := pull()
	if refreshed.get("ok", false): refreshed["advanced"] = true
	return refreshed


## dwm-634.1: true while a terminal click's settlement still has to run on a later frame.
func has_pending_settlement() -> bool:
	return not _held_terminal.is_empty() and not bool(_held_terminal.get("settled", true)) \
			and _board_port != null and _board_port.has_method("has_pending_settlement") \
			and _board_port.has_pending_settlement()


func select_difficulty(difficulty: String, expected_revision: int) -> Dictionary:
	_discard_stale_terminal()
	if not _held_terminal.is_empty() and (expected_revision != int(_held_terminal.board.revision) \
			or difficulty not in _held_terminal.register.difficulty_enabled): return _refused_without_refresh()
	if not _has_fresh_difficulty(): return _refused()
	var result: Dictionary = _board_port.select_difficulty(difficulty, expected_revision)
	if not result.get("ok", false): return _refused()
	_clear_held_terminal()
	return pull()


func can_park_preparation(expected_revision: int) -> bool:
	if _board_port == null or not _held_terminal.is_empty() or not _presented \
			or _presented_session.is_empty() or _session_marker() != _presented_session:
		return false
	return _board_port.can_park_preparation(expected_revision)


func set_foreground(foreground: bool, expected_revision: int) -> Dictionary:
	_discard_stale_terminal()
	if not _held_terminal.is_empty():
		if expected_revision != int(_held_terminal.board.revision):
			return {"ok": false, "code": &"minesweeper_panel_command_refused",
				"value": _held_terminal.duplicate(true)}
		if _owner.has_method("get_configuration_context"):
			var retained: Dictionary = _board_port.set_foreground(foreground, expected_revision)
			if not retained.get("ok", false): return _refused()
			return pull()
		return _present_success(_held_terminal)
	if not _has_fresh_difficulty(): return _refused()
	var result: Dictionary = _board_port.call(&"set_foreground", foreground, expected_revision)
	if not result.get("ok", false): return _refused()
	return pull()


func _terminal_view(board: Dictionary, prior_register: Dictionary, assignments: Array,
		settled: bool) -> Dictionary:
	if not bool(board.get("terminal", false)) or not bool(board.get("custody", false)):
		return {}
	var final_metric: Dictionary = _board_port.get_terminal_foresight(board)
	if not final_metric.get("ok", false): return {}
	var register := prior_register.duplicate(true)
	register["foresight"] = final_metric.value
	var rounds: Variant = _game_state.get("minesweeper_rounds_left")
	if typeof(rounds) != TYPE_INT: return {}
	register["rounds"] = rounds
	register["mine_estimate"] = board.get("mine_estimate")
	register["custody"] = true
	register["difficulty_enabled"] = []
	if settled:
		var configuration: Dictionary = _board_port.get_configuration(board)
		if not configuration.get("ok",false): return {}
		register["difficulty_enabled"] = configuration.value.difficulty_enabled.duplicate()
	return {
		"board": board.duplicate(true), "register": register,
		"assignments": assignments.duplicate(),
		"actions": SETTLED_ACTIONS.duplicate() if settled else [],
		"settled": settled,
	}


func _hold_terminal(value: Dictionary) -> Dictionary:
	var marker := _session_marker()
	if marker.is_empty(): return _unavailable()
	_held_terminal = value.duplicate(true)
	_held_session = marker
	return _present_success(_held_terminal)


func _present_success(value: Dictionary) -> Dictionary:
	_presented = true
	_presented_difficulty = str(value.register.difficulty)
	_presented_view = value.duplicate(true)
	_presented_session = _session_marker()
	return {"ok": true, "value": value.duplicate(true)}


func _present_failure(value: Dictionary) -> void:
	_presented = true
	_presented_difficulty = str(value.register.difficulty)
	_presented_view = value.duplicate(true)
	_presented_session = _session_marker()


func _session_marker() -> Dictionary:
	if not is_instance_valid(_game_state): return {}
	var day: Variant = _game_state.get("day")
	var session: Variant = _game_state.call(&"capture_live_session")
	if typeof(day) != TYPE_INT or typeof(session) != TYPE_DICTIONARY \
			or not (session as Dictionary).get("ok", false) \
			or typeof((session as Dictionary).get("value")) != TYPE_DICTIONARY:
		return {}
	return {"day": int(day), "session": ((session as Dictionary)["value"] as Dictionary).duplicate(true)}


func _discard_stale_terminal() -> void:
	if not _held_terminal.is_empty() and _session_marker() != _held_session:
		_clear_held_terminal()


func _clear_held_terminal() -> void:
	_held_terminal = {}
	_held_session = {}


func _on_game_state_day_changed(_day: int = -1) -> void:
	_clear_held_terminal()
	_presented = false
	_presented_difficulty = ""
	_presented_view = {}


func _has_fresh_difficulty() -> bool:
	if not _presented or not is_instance_valid(_owner) or not is_instance_valid(_issuer) \
			or _presented_session.is_empty() or _session_marker() != _presented_session:
		return false
	# The unpaid tier can change without a board revision. Read it without adopting a new
	# board-port identity: that port must still reject commands from a stale presentation.
	var current: Variant = _owner.call(&"get_state")
	if not current is Dictionary or not current.get("ok", false) \
			or not current.get("value") is Dictionary:
		return false
	var register: Dictionary = REGISTER.desktop(current.value, _game_state)
	return register.get("ok", false) and register.value.difficulty == _presented_difficulty


func _refused() -> Dictionary:
	var refreshed := pull()
	var result := {"ok": false, "code": &"minesweeper_panel_command_refused"}
	if refreshed.get("ok", false): result["value"] = refreshed.value
	elif refreshed.get("value") is Dictionary: result["value"] = refreshed.value
	return result


func _refused_without_refresh() -> Dictionary:
	var result := {"ok": false, "code": &"minesweeper_panel_command_refused"}
	if not _presented_view.is_empty(): result["value"] = _presented_view.duplicate(true)
	return result


func _unavailable() -> Dictionary:
	return {"ok": false, "code": &"minesweeper_panel_unavailable"}
