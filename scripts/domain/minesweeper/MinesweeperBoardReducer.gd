class_name MinesweeperBoardReducer
extends RefCounted

## Deterministic minesweeper board reducer (Plan 02 Task 3, dwm-p2r13). Every method recomputes
## adjacency from the hidden mine_indices and re-derives the revealed/flagged/terminal truth
## itself; no caller-supplied redundant field (adjacency_counts, terminal, outcome, mine_count)
## is ever trusted. Replaying a transaction_id already present in the ledger with the identical
## action is a no-op that returns the unchanged board; reusing a transaction_id for a different
## action, or acting on a terminal board, always rejects.

const _ACTIVE := &"active"
const _EXPLODED := &"exploded"
const _CLEARED := &"cleared"


static func first_reveal(layout: Dictionary, cell_index: int) -> Dictionary:
	var parsed := _parse_layout(layout)
	if not parsed.get("ok", false):
		return parsed
	var width: int = parsed["width"]
	var height: int = parsed["height"]
	var mine_set: Dictionary = parsed["mine_set"]
	var mine_indices: Array[int] = parsed["mine_indices"]
	var total_cells: int = width * height

	if cell_index < 0 or cell_index >= total_cells:
		return _fail(&"cell_index_out_of_range", "cell_index is out of range", {"cell_index": cell_index})
	if mine_set.has(cell_index):
		return _fail(&"forced_cell_is_mine", "the forced first-reveal cell must never be a mine",
			{"cell_index": cell_index})

	var adjacency := _recompute_adjacency(mine_set, width, height)
	var revealed_set := _flood_reveal([cell_index], {}, mine_set, adjacency, width, height)
	var revealed: Array[int] = []
	revealed.assign(revealed_set.keys())
	revealed.sort()

	var board := _build_board(width, height, mine_indices, revealed, [], adjacency, -1, [])
	return {"ok": true, "code": &"ok", "value": {"board": board}, "receipt": {}}


static func reveal(board: Dictionary, cell_index: int, transaction_id: String) -> Dictionary:
	var parsed := _parse_board(board)
	if not parsed.get("ok", false):
		return parsed
	var gate := _check_transaction(parsed, transaction_id, &"reveal", cell_index, board)
	if gate.get("terminate", false):
		return gate["result"]

	var width: int = parsed["width"]
	var height: int = parsed["height"]
	var total_cells: int = width * height
	var mine_set: Dictionary = parsed["mine_set"]
	var mine_indices: Array[int] = parsed["mine_indices"]
	var revealed_set: Dictionary = parsed["revealed_set"]
	var flagged_set: Dictionary = parsed["flagged_set"]
	var adjacency: Array[int] = parsed["adjacency"]

	if cell_index < 0 or cell_index >= total_cells:
		return _fail(&"cell_index_out_of_range", "cell_index is out of range", {"cell_index": cell_index})
	if flagged_set.has(cell_index):
		return _fail(&"cell_is_flagged", "a flagged cell must be unflagged before it can be revealed",
			{"cell_index": cell_index})
	if revealed_set.has(cell_index):
		return _fail(&"cell_already_revealed", "cell is already revealed", {"cell_index": cell_index})

	var flagged: Array[int] = []
	flagged.assign(flagged_set.keys())
	flagged.sort()

	var new_revealed_set: Dictionary
	var exploded_index: int = -1
	if mine_set.has(cell_index):
		new_revealed_set = revealed_set.duplicate()
		new_revealed_set[cell_index] = true
		exploded_index = cell_index
	else:
		new_revealed_set = _flood_reveal([cell_index], revealed_set, mine_set, adjacency, width, height)

	var revealed: Array[int] = []
	revealed.assign(new_revealed_set.keys())
	revealed.sort()
	var actions: Array = (parsed["actions"] as Array).duplicate(true)
	actions.append({"transaction_id": transaction_id, "kind": &"reveal", "cell_index": cell_index,
		"revision": actions.size() + 1})

	var board_out := _build_board(width, height, mine_indices, revealed, flagged, adjacency,
		exploded_index, actions)
	return {"ok": true, "code": &"ok", "value": {"board": board_out}, "receipt": {}}


static func set_flag(board: Dictionary, cell_index: int, flagged: bool,
		transaction_id: String) -> Dictionary:
	var parsed := _parse_board(board)
	if not parsed.get("ok", false):
		return parsed
	var gate := _check_transaction(parsed, transaction_id, &"set_flag", cell_index, board, {"flagged": flagged})
	if gate.get("terminate", false):
		return gate["result"]

	var width: int = parsed["width"]
	var height: int = parsed["height"]
	var total_cells: int = width * height
	var mine_indices: Array[int] = parsed["mine_indices"]
	var revealed_set: Dictionary = parsed["revealed_set"]
	var flagged_set: Dictionary = (parsed["flagged_set"] as Dictionary).duplicate()
	var adjacency: Array[int] = parsed["adjacency"]

	if cell_index < 0 or cell_index >= total_cells:
		return _fail(&"cell_index_out_of_range", "cell_index is out of range", {"cell_index": cell_index})
	if revealed_set.has(cell_index):
		return _fail(&"cell_already_revealed", "a revealed cell cannot be flagged", {"cell_index": cell_index})

	if flagged:
		flagged_set[cell_index] = true
	else:
		flagged_set.erase(cell_index)

	var revealed: Array[int] = []
	revealed.assign(revealed_set.keys())
	revealed.sort()
	var flagged_list: Array[int] = []
	flagged_list.assign(flagged_set.keys())
	flagged_list.sort()
	var actions: Array = (parsed["actions"] as Array).duplicate(true)
	actions.append({"transaction_id": transaction_id, "kind": &"set_flag", "cell_index": cell_index,
		"flagged": flagged, "revision": actions.size() + 1})

	var board_out := _build_board(width, height, mine_indices, revealed, flagged_list, adjacency,
		int(parsed["exploded_index"]), actions)
	return {"ok": true, "code": &"ok", "value": {"board": board_out}, "receipt": {}}


static func chord(board: Dictionary, cell_index: int, transaction_id: String) -> Dictionary:
	var parsed := _parse_board(board)
	if not parsed.get("ok", false):
		return parsed
	var gate := _check_transaction(parsed, transaction_id, &"chord", cell_index, board)
	if gate.get("terminate", false):
		return gate["result"]

	var width: int = parsed["width"]
	var height: int = parsed["height"]
	var total_cells: int = width * height
	var mine_set: Dictionary = parsed["mine_set"]
	var mine_indices: Array[int] = parsed["mine_indices"]
	var revealed_set: Dictionary = parsed["revealed_set"]
	var flagged_set: Dictionary = parsed["flagged_set"]
	var adjacency: Array[int] = parsed["adjacency"]

	if cell_index < 0 or cell_index >= total_cells:
		return _fail(&"cell_index_out_of_range", "cell_index is out of range", {"cell_index": cell_index})
	if not revealed_set.has(cell_index):
		return _fail(&"cell_not_revealed", "chord requires an already-revealed cell", {"cell_index": cell_index})
	var count: int = adjacency[cell_index]
	if count == 0:
		return _fail(&"chord_not_applicable", "chord requires a revealed cell with a nonzero count",
			{"cell_index": cell_index})

	var neighbors := _neighbors(cell_index, width, height)
	var flagged_neighbor_count := 0
	var hidden_unflagged: Array[int] = []
	for neighbor: int in neighbors:
		if flagged_set.has(neighbor):
			flagged_neighbor_count += 1
		elif not revealed_set.has(neighbor):
			hidden_unflagged.append(neighbor)
	if flagged_neighbor_count != count:
		return _fail(&"chord_flag_count_mismatch",
			"flagged neighbor count must exactly match the revealed cell's number",
			{"cell_index": cell_index, "expected": count, "actual": flagged_neighbor_count})

	var flagged: Array[int] = []
	flagged.assign(flagged_set.keys())
	flagged.sort()
	var actions: Array = (parsed["actions"] as Array).duplicate(true)
	actions.append({"transaction_id": transaction_id, "kind": &"chord", "cell_index": cell_index,
		"revision": actions.size() + 1})

	if hidden_unflagged.is_empty():
		var unchanged_revealed: Array[int] = []
		unchanged_revealed.assign(revealed_set.keys())
		unchanged_revealed.sort()
		var board_noop := _build_board(width, height, mine_indices, unchanged_revealed, flagged,
			adjacency, int(parsed["exploded_index"]), actions)
		return {"ok": true, "code": &"ok", "value": {"board": board_noop}, "receipt": {}}

	var hit_mines: Array[int] = []
	var safe_seeds: Array[int] = []
	for neighbor: int in hidden_unflagged:
		if mine_set.has(neighbor):
			hit_mines.append(neighbor)
		else:
			safe_seeds.append(neighbor)

	var new_revealed_set: Dictionary
	var exploded_index: int = -1
	if not hit_mines.is_empty():
		hit_mines.sort()
		exploded_index = hit_mines[0]
		new_revealed_set = revealed_set.duplicate()
		for m: int in hidden_unflagged:
			new_revealed_set[m] = true
	elif not safe_seeds.is_empty():
		new_revealed_set = _flood_reveal(safe_seeds, revealed_set, mine_set, adjacency, width, height)
	else:
		new_revealed_set = revealed_set.duplicate()

	var revealed: Array[int] = []
	revealed.assign(new_revealed_set.keys())
	revealed.sort()
	var board_out := _build_board(width, height, mine_indices, revealed, flagged, adjacency,
		exploded_index, actions)
	return {"ok": true, "code": &"ok", "value": {"board": board_out}, "receipt": {}}


# ---- shared helpers ----

static func _parse_layout(layout: Dictionary) -> Dictionary:
	if not (layout.has("width") and layout.has("height") and layout.has("mine_indices")):
		return _fail(&"layout_field_invalid", "layout must include width, height, mine_indices", {})
	var width_v: Variant = layout["width"]
	var height_v: Variant = layout["height"]
	if typeof(width_v) != TYPE_INT or int(width_v) <= 0:
		return _fail(&"layout_field_invalid", "width must be a positive integer", {"field": "width"})
	if typeof(height_v) != TYPE_INT or int(height_v) <= 0:
		return _fail(&"layout_field_invalid", "height must be a positive integer", {"field": "height"})
	var width: int = int(width_v)
	var height: int = int(height_v)
	var total_cells: int = width * height
	var mine_indices_v: Variant = layout["mine_indices"]
	if typeof(mine_indices_v) != TYPE_ARRAY:
		return _fail(&"layout_field_invalid", "mine_indices must be an array", {"field": "mine_indices"})
	var seen: Dictionary = {}
	var mine_indices: Array[int] = []
	for entry: Variant in (mine_indices_v as Array):
		if typeof(entry) != TYPE_INT:
			return _fail(&"layout_field_invalid", "mine_indices must contain only integers", {})
		var index: int = int(entry)
		if index < 0 or index >= total_cells:
			return _fail(&"layout_field_invalid", "mine_indices entry out of range", {"value": index})
		if seen.has(index):
			return _fail(&"layout_field_invalid", "mine_indices must not repeat", {"value": index})
		seen[index] = true
		mine_indices.append(index)
	mine_indices.sort()
	var mine_set: Dictionary = {}
	for m: int in mine_indices:
		mine_set[m] = true
	return {"ok": true, "width": width, "height": height, "mine_indices": mine_indices, "mine_set": mine_set}


static func _parse_board(board: Dictionary) -> Dictionary:
	var required := ["width", "height", "mine_indices", "revealed_indices", "flagged_indices",
		"exploded_index", "terminal", "actions"]
	for key: String in required:
		if not board.has(key):
			return _fail(&"board_field_invalid", "board is missing member: %s" % key, {"missing": key})
	var layout_parsed := _parse_layout(board)
	if not layout_parsed.get("ok", false):
		return layout_parsed
	var width: int = layout_parsed["width"]
	var height: int = layout_parsed["height"]
	var total_cells: int = width * height
	var mine_set: Dictionary = layout_parsed["mine_set"]
	var mine_indices: Array[int] = layout_parsed["mine_indices"]
	var adjacency := _recompute_adjacency(mine_set, width, height)

	var revealed_indices := _index_array(board["revealed_indices"], total_cells)
	if not revealed_indices.get("ok", false):
		return _fail(&"board_field_invalid", "revealed_indices invalid", {})
	var revealed_set: Dictionary = {}
	for r: int in (revealed_indices["value"] as Array):
		revealed_set[r] = true

	var flagged_indices := _index_array(board["flagged_indices"], total_cells)
	if not flagged_indices.get("ok", false):
		return _fail(&"board_field_invalid", "flagged_indices invalid", {})
	var flagged_set: Dictionary = {}
	for f: int in (flagged_indices["value"] as Array):
		if revealed_set.has(f):
			return _fail(&"board_revealed_flagged_overlap", "a cell cannot be both revealed and flagged", {"cell_index": f})
		flagged_set[f] = true

	var exploded_v: Variant = board["exploded_index"]
	if typeof(exploded_v) != TYPE_INT or int(exploded_v) < -1 or int(exploded_v) >= total_cells:
		return _fail(&"board_field_invalid", "exploded_index invalid", {})
	var exploded_index: int = int(exploded_v)
	if exploded_index != -1 and not (revealed_set.has(exploded_index) and mine_set.has(exploded_index)):
		return _fail(&"board_field_invalid", "exploded_index must be a revealed mine cell", {})

	var terminal: bool = exploded_index != -1
	if not terminal:
		var non_mine_revealed := 0
		for r: int in revealed_set.keys():
			if not mine_set.has(r):
				non_mine_revealed += 1
		terminal = non_mine_revealed == total_cells - mine_indices.size()

	var actions_v: Variant = board["actions"]
	if typeof(actions_v) != TYPE_ARRAY:
		return _fail(&"board_field_invalid", "actions must be an array", {})

	return {
		"ok": true, "width": width, "height": height, "mine_indices": mine_indices, "mine_set": mine_set,
		"revealed_set": revealed_set, "flagged_set": flagged_set, "adjacency": adjacency,
		"exploded_index": exploded_index, "terminal": terminal, "actions": actions_v,
	}


static func _check_transaction(parsed: Dictionary, transaction_id: String, kind: StringName,
		cell_index: int, original_board: Dictionary, extra_fields: Dictionary = {}) -> Dictionary:
	if transaction_id.strip_edges().is_empty():
		return {"terminate": true, "result": _fail(&"invalid_transaction_id", "transaction_id must be nonblank", {})}
	if bool(parsed["terminal"]):
		return {"terminate": true, "result": _fail(&"board_terminal", "no action may be applied to a terminal board", {})}
	for action: Variant in (parsed["actions"] as Array):
		var entry: Dictionary = action
		if String(entry.get("transaction_id", "")) != transaction_id:
			continue
		var matches: bool = StringName(entry.get("kind", &"")) == kind and int(entry.get("cell_index", -1)) == cell_index
		if matches:
			for key: String in extra_fields.keys():
				if entry.get(key) != extra_fields[key]:
					matches = false
					break
		if matches:
			return {"terminate": true, "result": {"ok": true, "code": &"ok",
				"value": {"board": original_board.duplicate(true)}, "receipt": {}}}
		return {"terminate": true, "result": _fail(&"transaction_id_reused",
			"transaction_id was already used for a different action", {"transaction_id": transaction_id})}
	return {"terminate": false}


static func _build_board(width: int, height: int, mine_indices: Array[int], revealed: Array[int],
		flagged: Array[int], adjacency: Array[int], exploded_index: int, actions: Array) -> Dictionary:
	var total_cells: int = width * height
	var mine_set: Dictionary = {}
	for m: int in mine_indices:
		mine_set[m] = true
	var non_mine_revealed := 0
	for r: int in revealed:
		if not mine_set.has(r):
			non_mine_revealed += 1
	var terminal: bool = exploded_index != -1 or non_mine_revealed == total_cells - mine_indices.size()
	var outcome: StringName = _ACTIVE
	if exploded_index != -1:
		outcome = _EXPLODED
	elif terminal:
		outcome = _CLEARED
	return {
		"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices.duplicate(), "mine_count": mine_indices.size(),
		"revealed_indices": revealed.duplicate(), "flagged_indices": flagged.duplicate(),
		"adjacency_counts": adjacency.duplicate(), "exploded_index": exploded_index,
		"terminal": terminal, "outcome": outcome, "revision": actions.size(),
		"actions": actions.duplicate(true),
	}


static func _flood_reveal(seeds: Array[int], already_revealed: Dictionary, mine_set: Dictionary,
		adjacency: Array[int], width: int, height: int) -> Dictionary:
	var revealed: Dictionary = already_revealed.duplicate()
	var queue: Array[int] = seeds.duplicate()
	while not queue.is_empty():
		var idx: int = queue.pop_front()
		if revealed.has(idx) or mine_set.has(idx):
			continue
		revealed[idx] = true
		if adjacency[idx] == 0:
			for neighbor: int in _neighbors(idx, width, height):
				if not revealed.has(neighbor) and not mine_set.has(neighbor):
					queue.append(neighbor)
	return revealed


static func _index_array(value: Variant, total_cells: int) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false}
	var seen: Dictionary = {}
	var indices: Array[int] = []
	for entry: Variant in (value as Array):
		if typeof(entry) != TYPE_INT:
			return {"ok": false}
		var index: int = int(entry)
		if index < 0 or index >= total_cells or seen.has(index):
			return {"ok": false}
		seen[index] = true
		indices.append(index)
	indices.sort()
	return {"ok": true, "value": indices}


static func _recompute_adjacency(mine_set: Dictionary, width: int, height: int) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(width * height)
	for index in range(width * height):
		if mine_set.has(index):
			counts[index] = 0
			continue
		var count := 0
		for neighbor: int in _neighbors(index, width, height):
			if mine_set.has(neighbor):
				count += 1
		counts[index] = count
	return counts


static func _neighbors(index: int, width: int, height: int) -> Array[int]:
	var x: int = index % width
	var y: int = index / width
	var result: Array[int] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				result.append(ny * width + nx)
	result.sort()
	return result


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
