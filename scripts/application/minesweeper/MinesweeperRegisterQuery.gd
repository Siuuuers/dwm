class_name MinesweeperRegisterQuery
extends RefCounted
## Partial register projection of retained owner facts. No new metric or command authority.

const BOARD_QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const DIFFICULTIES := ["beginner", "intermediate", "expert"]


static func desktop(snapshot: Dictionary, game_state: Object) -> Dictionary:
	if not is_instance_valid(game_state): return _unavailable()
	var rounds: Variant = game_state.get("minesweeper_rounds_left")
	if not rounds is int: return _unavailable()
	var difficulty: Variant = null
	match snapshot.get("phase"):
		"NONE": difficulty = game_state.get("minesweeper_selected_difficulty")
		"PREPARING", "PREPARED_UNSTARTED":
			var candidate: Variant = snapshot.get("candidate")
			if not candidate is Dictionary or not candidate.get("spec") is Dictionary: return _unavailable()
			difficulty = candidate.spec.get("difficulty_id")
		"ACTIVE_VISIBLE", "ACTIVE_SUSPENDED", "SETTLING":
			var wrapper: Variant = snapshot.get("board")
			if not wrapper is Dictionary or not wrapper.get("paid_start_receipt") is Dictionary: return _unavailable()
			difficulty = wrapper.paid_start_receipt.get("difficulty_id")
		_: return _unavailable()
	if not difficulty is String or not DIFFICULTIES.has(difficulty): return _unavailable()
	var projected: Dictionary = BOARD_QUERY.desktop(snapshot, difficulty)
	if not projected.get("ok", false): return _unavailable()
	var no_flag := "intact"
	if snapshot.board != null:
		var board: Dictionary = snapshot.board.board
		var flags := {}
		for action: Dictionary in board.actions:
			if StringName(action.kind) != &"set_flag": continue
			if not action.get("flagged") is bool: return _unavailable()
			if action.flagged:
				flags[int(action.cell_index)] = true
				no_flag = "lost"
			else:
				flags.erase(int(action.cell_index))
		if flags.size() != board.flagged_indices.size(): return _unavailable()
		for index: int in board.flagged_indices:
			if not flags.has(index): return _unavailable()
	# NONE/prepared owners cannot retain Flags yet. The existing ledger also excludes first
	# Reveal; no versioned 3BV exists. Do not invent Foresight or enable absent tier/replacement APIs.
	return {"ok": true, "value": {
		"difficulty": difficulty, "rounds": rounds, "mine_estimate": projected.value.mine_estimate,
		"foresight": null, "no_flag": no_flag, "custody": projected.value.custody,
		"difficulty_enabled": [],
	}}


static func _unavailable() -> Dictionary:
	return {"ok": false, "code": &"minesweeper_register_unavailable"}
