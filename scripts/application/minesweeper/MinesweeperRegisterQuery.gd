class_name MinesweeperRegisterQuery
extends RefCounted
## Partial register projection of retained owner facts. No new metric or command authority.

const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")
const BOARD_QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const IDENTITY := preload("res://scripts/domain/desktop/DesktopIdentity.gd")
const DIFFICULTIES := ["beginner", "intermediate", "expert"]


static func desktop(snapshot: Dictionary, game_state: Object) -> Dictionary:
	if not is_instance_valid(game_state): return _unavailable()
	var rounds: Variant = game_state.get("minesweeper_rounds_left")
	if not rounds is int: return _unavailable()
	var difficulty: Variant = difficulty_of(snapshot, game_state)
	if difficulty == null: return _unavailable()
	var projected: Dictionary = BOARD_QUERY.desktop(snapshot, difficulty)
	if not projected.get("ok", false): return _unavailable()
	var metrics := retained_metrics(snapshot)
	if not metrics.get("ok", false): return _unavailable()
	return {"ok": true, "value": {
		"difficulty": difficulty, "rounds": rounds, "mine_estimate": projected.value.mine_estimate,
		"foresight": metrics.value.foresight, "no_flag": metrics.value.no_flag,
		"custody": projected.value.custody, "difficulty_enabled": [],
	}}


## Derives the history-backed register facts without constructing another board projection.
## Presentation may retain this narrow result beside the exact owner projection it already read.
static func retained_metrics(snapshot: Dictionary) -> Dictionary:
	var no_flag := "intact"
	var foresight: Variant = null
	var history: Dictionary = {}
	if snapshot.board != null:
		history = snapshot.board.board
		foresight = PERFORMANCE.display_percent(history)
	elif snapshot.candidate is Dictionary and snapshot.candidate.has("actions"):
		history = snapshot.candidate
	if not history.is_empty():
		var flags := {}
		for action: Dictionary in history.actions:
			if StringName(action.kind) != &"set_flag": continue
			if not action.get("flagged") is bool: return _unavailable()
			if action.flagged:
				flags[int(action.cell_index)] = true
				no_flag = "lost"
			else:
				flags.erase(int(action.cell_index))
		if flags.size() != history.flagged_indices.size(): return _unavailable()
		for index: int in history.flagged_indices:
			if not flags.has(index): return _unavailable()
	# Unmaterialized shells have no Foresight. Display uses the same versioned performance
	# rule as completion, with no arbitrary upper cap.
	return {"ok": true, "value": {
		"foresight": foresight, "no_flag": no_flag,
	}}


## The register's difficulty, resolved from the same retained facts desktop() uses and nothing
## else (dwm-634.1). Returns null when the snapshot names no legal difficulty.
static func difficulty_of(snapshot: Dictionary, game_state: Object) -> Variant:
	if not is_instance_valid(game_state): return null
	var difficulty: Variant = null
	match snapshot.get("phase"):
		"NONE": difficulty = game_state.get("minesweeper_selected_difficulty")
		"UNPAID_UNSTARTED":
			var candidate: Variant = snapshot.get("candidate")
			if not candidate is Dictionary: return _unavailable()
			difficulty = candidate.get("difficulty_id")
		"PREPARING", "PREPARED_UNSTARTED", "PAID_UNSTARTED":
			var candidate: Variant = snapshot.get("candidate")
			if not candidate is Dictionary or not candidate.get("spec") is Dictionary: return _unavailable()
			difficulty = candidate.spec.get("difficulty_id")
		"ACTIVE_VISIBLE", "ACTIVE_SUSPENDED", "SETTLING":
			var wrapper: Variant = snapshot.get("board")
			if not wrapper is Dictionary or not wrapper.get("paid_start_receipt") is Dictionary: return _unavailable()
			if wrapper.has("spec"):
				if not wrapper.spec is Dictionary: return _unavailable()
				difficulty = wrapper.spec.get("difficulty_id")
			else:
				difficulty = wrapper.paid_start_receipt.get("difficulty_id")
				if not wrapper.paid_start_receipt.has("difficulty_id"):
					difficulty = _journal_difficulty(snapshot, wrapper)
		_: return null
	if not difficulty is String or not DIFFICULTIES.has(difficulty): return null
	return difficulty


static func _journal_difficulty(snapshot: Dictionary, wrapper: Dictionary) -> Variant:
	# The retained coordinator stores a checkpoint-only board marker; its full paid receipt
	# lives in the first-Reveal command result. Resolve that evidence without changing the save.
	var marker: Dictionary = wrapper.paid_start_receipt
	if marker.size() != 1 or not marker.get("checkpoint_id") is String \
			or marker.checkpoint_id.strip_edges().is_empty(): return null
	if not snapshot.get("identity") is Dictionary or not snapshot.get("command_receipts") is Dictionary \
			or not snapshot.get("revision") is int or not wrapper.get("board") is Dictionary: return null
	var fingerprint: Dictionary = IDENTITY.fingerprint(snapshot.identity)
	if not fingerprint.get("ok", false): return null
	var board: Dictionary = wrapper.board
	if not board.get("revealed_indices") is Array or not board.get("mine_indices") is Array: return null
	var difficulty: Variant = null
	for transaction_id: Variant in snapshot.command_receipts:
		var entry: Variant = snapshot.command_receipts[transaction_id]
		if not entry is Dictionary: return null
		if entry.get("command_kind") != "first_reveal": continue
		var result: Variant = entry.get("result")
		if not result is Dictionary or not result.get("value") is Dictionary: return null
		var receipt: Variant = result.value.get("receipt")
		if not receipt is Dictionary: return null
		if receipt.get("checkpoint_id") != marker.checkpoint_id: continue
		if difficulty != null or not transaction_id is String or transaction_id.is_empty(): return null
		if result.get("ok") != true or result.get("code") != &"first_reveal_committed" \
				or receipt.get("transaction_id") != transaction_id or receipt.get("identity") != snapshot.identity \
				or entry.get("identity_fingerprint") != fingerprint.value.fingerprint: return null
		if not entry.get("pre_revision") is int or not entry.get("post_revision") is int \
				or entry.pre_revision < 0 or entry.post_revision != entry.pre_revision + 1 \
				or entry.post_revision > snapshot.revision: return null
		if not receipt.get("board_revision") is int or receipt.board_revision < 0 \
				or receipt.board_revision > int(board.revision) \
				or not receipt.get("first_cell") is int or not board.revealed_indices.has(receipt.first_cell) \
				or board.mine_indices.has(receipt.first_cell): return null
		# First Reveal retains the already accepted shell marks. Only that exact Flag/Unflag
		# prefix may precede the paid-start receipt; later Reveal/Chord history cannot stand in.
		for index in range(receipt.board_revision):
			var action: Dictionary = board.actions[index]
			if str(action.get("kind", "")) != "set_flag" or int(action.get("revision", -1)) != index + 1:
				return null
		difficulty = receipt.get("difficulty_id")
		if not difficulty is String or not DIFFICULTIES.has(difficulty): return null
	return difficulty


static func _unavailable() -> Dictionary:
	return {"ok": false, "code": &"minesweeper_register_unavailable"}
