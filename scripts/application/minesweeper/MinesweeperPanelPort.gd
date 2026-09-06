class_name MinesweeperPanelPort
extends RefCounted
## Composes public board, register and assignment facts without exposing domain snapshots.

const BOARD_PORT := preload("res://scripts/application/minesweeper/MinesweeperPresentationPort.gd")
const REGISTER := preload("res://scripts/application/minesweeper/MinesweeperRegisterQuery.gd")
const ASSIGNMENTS := preload("res://scripts/application/minesweeper/MinesweeperAssignmentsQuery.gd")

var _owner: Object = null
var _issuer: Object = null
var _game_state: Object = null
var _catalog: Object = null
var _board_port: Object = null
var _presented := false
var _presented_difficulty := ""


func configure(owner: Object, issuer: Object, game_state: Object, catalog: Object) -> Dictionary:
	if _board_port != null:
		if _owner == owner and _issuer == issuer and _game_state == game_state and _catalog == catalog:
			return {"ok": true, "value": {"already_configured": true}}
		return {"ok": false, "code": &"minesweeper_panel_already_configured"}
	if not is_instance_valid(owner) or not is_instance_valid(issuer) \
			or not is_instance_valid(game_state) or not is_instance_valid(catalog) \
			or not catalog.has_method("get_minesweeper_tasks"):
		return _unavailable()
	var candidate := BOARD_PORT.new()
	if not candidate.configure(owner, issuer).get("ok", false): return _unavailable()
	_owner = owner
	_issuer = issuer
	_game_state = game_state
	_catalog = catalog
	_board_port = candidate
	return {"ok": true, "value": {"already_configured": false}}


func pull() -> Dictionary:
	_presented = false
	_presented_difficulty = ""
	if _board_port == null or not is_instance_valid(_owner) \
			or not is_instance_valid(_issuer) or not is_instance_valid(_game_state) \
			or not is_instance_valid(_catalog):
		return _unavailable()
	var initial: Variant = _owner.call(&"get_state")
	if not initial is Dictionary or not initial.get("ok", false) or not initial.get("value") is Dictionary:
		return _unavailable()
	var snapshot: Dictionary = initial.value
	var register: Dictionary = REGISTER.desktop(snapshot, _game_state)
	if not register.get("ok", false): return _unavailable()
	var board: Dictionary = _board_port.call(&"pull", register.value.difficulty)
	if not board.get("ok", false): return _unavailable()
	if board.value.revision != snapshot.revision or board.value.custody != register.value.custody \
			or board.value.mine_estimate != register.value.mine_estimate:
		return _unavailable()
	var assignments: Dictionary = ASSIGNMENTS.from_sources(_game_state, _catalog)
	if not assignments.get("ok", false): return _unavailable()
	# Refuse a torn read, including a restored identity at the same visible revision.
	var final_state: Variant = _owner.call(&"get_state")
	if not final_state is Dictionary or not final_state.get("ok", false) \
			or final_state.get("value") != snapshot:
		return _unavailable()
	if REGISTER.desktop(snapshot, _game_state) != register \
			or ASSIGNMENTS.from_sources(_game_state, _catalog) != assignments:
		return _unavailable()
	var actions: Array[String] = []
	if not register.value.custody:
		actions.assign(["reveal", "flag", "drag", "assignments", "rules"])
	_presented = true
	_presented_difficulty = register.value.difficulty
	return {"ok": true, "value": {
		"board": board.value.duplicate(true), "register": register.value.duplicate(true),
		"assignments": assignments.value.duplicate(), "actions": actions,
	}}


func dispatch(action: String, index: int, revision: int) -> Dictionary:
	if not _presented or not is_instance_valid(_owner) or not is_instance_valid(_issuer):
		return _refused()
	# The unpaid tier can change without a board revision. Read it without adopting a new
	# board-port identity: that port must still reject commands from a stale presentation.
	var current: Variant = _owner.call(&"get_state")
	if not current is Dictionary or not current.get("ok", false) or not current.get("value") is Dictionary:
		return _refused()
	var register: Dictionary = REGISTER.desktop(current.value, _game_state)
	if not register.get("ok", false) or register.value.difficulty != _presented_difficulty:
		return _refused()
	var result: Dictionary = _board_port.call(&"dispatch", action, index, revision)
	if not result.get("ok", false): return _refused()
	return pull()


func _refused() -> Dictionary:
	var refreshed := pull()
	var result := {"ok": false, "code": &"minesweeper_panel_command_refused"}
	if refreshed.get("ok", false): result["value"] = refreshed.value
	return result


func _unavailable() -> Dictionary:
	return {"ok": false, "code": &"minesweeper_panel_unavailable"}
