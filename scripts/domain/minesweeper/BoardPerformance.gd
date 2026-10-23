extends RefCounted
## Derived from a validated saved board; no metric or parallel action history is persisted.
## Current August-13 rules use >=100% and floor for display. Version 1 preserves
## the earlier >100% classification/rounded display when validating historical attempts.

static func click_count(board: Dictionary) -> int:
	return board.actions.size() + 1

static func foresight_percent(board: Dictionary) -> float:
	return float(three_bv(board)) / float(click_count(board)) * 100.0

static func display_percent(board: Dictionary, rule_version: int = 2) -> int:
	var percentage := foresight_percent(board)
	return roundi(percentage) if rule_version == 1 else floori(percentage)

static func perfect_reasons(board: Dictionary, rule_version: int = 2) -> Array:
	if not bool(board.terminal) or str(board.outcome) != "cleared": return []
	var reasons: Array = []
	# The first reveal is implicit in reducer revision zero; subsequent accepted cell commands
	# are the action ledger. Count flags too (the recovered contract says total clicks).
	if rule_version == 1:
		if three_bv(board) > click_count(board): reasons.append("efficiency_gt_100")
	elif three_bv(board) >= click_count(board):
		reasons.append("efficiency_gte_100")
	var flagged: bool = false
	for action: Dictionary in board.actions:
		if str(action.kind) == "set_flag" and bool(action.get("flagged", false)): flagged = true
	if not flagged: reasons.append("no_flag")
	return reasons

static func three_bv(board: Dictionary) -> int:
	# Each connected zero opening costs one reveal; its border numbers cost none. Every remaining
	# numbered safe cell costs one. Chords may clear several such cells with one later input.
	var width: int = int(board.width)
	var height: int = int(board.height)
	var seen: Dictionary = {}
	var result: int = 0
	for index in width * height:
		if board.mine_indices.has(index) or int(board.adjacency_counts[index]) != 0 or seen.has(index): continue
		result += 1
		var queue: Array = [index]
		seen[index] = true
		while not queue.is_empty():
			var cell: int = int(queue.pop_back())
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var x: int = cell % width + dx
					var y: int = cell / width + dy
					if x < 0 or x >= width or y < 0 or y >= height: continue
					var neighbor: int = y * width + x
					if seen.has(neighbor) or board.mine_indices.has(neighbor): continue
					seen[neighbor] = true
					if int(board.adjacency_counts[neighbor]) == 0: queue.append(neighbor)
	for index in width * height:
		if not board.mine_indices.has(index) and not seen.has(index): result += 1
	return result
