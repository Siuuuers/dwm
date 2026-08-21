class_name MinesweeperBoardSchema
extends RefCounted

## Frozen BoardSpec / layout / board schema validation (Plan 02 Task 3, dwm-p2r13). Every
## validator recomputes derived truth (raw_extra_mines, mine_count, adjacency_counts, revealed/
## flagged disjointness, terminal/outcome, the action-ledger sequence) rather than trusting a
## redundant caller-supplied field; a mismatch always rejects.

const _SPEC_KEYS := [
	"schema_version", "board_kind", "board_token", "board_token_receipt_id", "difficulty_id",
	"width", "height", "base_mine_count", "pressure", "penalty_points_today", "raw_extra_mines",
	"requested_mine_count", "capability_ids", "placement_stream_id", "placement_nonce",
	"placement_nonce_receipt_id", "debug_stream_id", "debug_nonce", "debug_nonce_receipt_id",
	"explosion_stream_id", "explosion_nonce", "explosion_nonce_receipt_id", "generator_version",
	"verifier_version",
]
const _BLANK_CHECK_FIELDS := [
	"board_token", "board_token_receipt_id", "difficulty_id", "placement_nonce",
	"placement_nonce_receipt_id", "debug_nonce", "debug_nonce_receipt_id", "explosion_nonce",
	"explosion_nonce_receipt_id",
]
const _BOARD_KINDS := ["desktop", "solo_challenge", "pair_challenge"]
const _PLACEMENT_STREAM_ID := "minesweeper_placement_v1"
const _DEBUG_STREAM_ID := "minesweeper_debug_v1"
const _EXPLOSION_STREAM_ID := "minesweeper_explosion_v1"
const _GENERATOR_VERSION := "dwm_generator_v1"
const _VERIFIER_VERSION := "visible_deduction_v1"

const _LAYOUT_KEYS := ["schema_version", "width", "height", "mine_indices", "mine_count"]
const _BOARD_KEYS := [
	"schema_version", "width", "height", "mine_indices", "mine_count", "revealed_indices",
	"flagged_indices", "adjacency_counts", "exploded_index", "terminal", "outcome", "revision",
	"actions",
]
const _ACTION_KINDS: Array[StringName] = [&"reveal", &"set_flag", &"chord"]


static func validate_spec(spec: Dictionary) -> Dictionary:
	var shape := _exact_keys(spec, _SPEC_KEYS, &"spec_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(spec["schema_version"]) != TYPE_INT or int(spec["schema_version"]) != 1:
		return _fail(&"spec_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})
	var board_kind: Variant = spec["board_kind"]
	if typeof(board_kind) != TYPE_STRING or not _BOARD_KINDS.has(String(board_kind)):
		return _fail(&"spec_field_invalid", "board_kind must be one of the frozen kinds", {"field": "board_kind"})
	for field: String in _BLANK_CHECK_FIELDS:
		var nonblank := _nonblank_string(spec.get(field), field)
		if not nonblank.get("ok", false):
			return nonblank

	var width_v: Variant = spec["width"]
	if typeof(width_v) != TYPE_INT or int(width_v) <= 0:
		return _fail(&"spec_field_invalid", "width must be a positive integer", {"field": "width"})
	var height_v: Variant = spec["height"]
	if typeof(height_v) != TYPE_INT or int(height_v) <= 0:
		return _fail(&"spec_field_invalid", "height must be a positive integer", {"field": "height"})
	var base_mine_count_v: Variant = spec["base_mine_count"]
	if typeof(base_mine_count_v) != TYPE_INT or int(base_mine_count_v) < 0:
		return _fail(&"spec_field_invalid", "base_mine_count must be a nonnegative integer", {"field": "base_mine_count"})
	var pressure_v: Variant = spec["pressure"]
	if typeof(pressure_v) != TYPE_INT or int(pressure_v) < 0:
		return _fail(&"spec_field_invalid", "pressure must be a nonnegative integer", {"field": "pressure"})
	var penalty_v: Variant = spec["penalty_points_today"]
	if typeof(penalty_v) != TYPE_INT or int(penalty_v) < 0:
		return _fail(&"spec_field_invalid", "penalty_points_today must be a nonnegative integer",
			{"field": "penalty_points_today"})

	var expected_raw_extra: int = floori(float(pressure_v) / 3.0) + int(penalty_v)
	var raw_extra_v: Variant = spec["raw_extra_mines"]
	if typeof(raw_extra_v) != TYPE_INT or int(raw_extra_v) != expected_raw_extra:
		return _fail(&"spec_field_invalid",
			"raw_extra_mines must equal floor(pressure/3)+penalty_points_today",
			{"field": "raw_extra_mines", "expected": expected_raw_extra, "actual": raw_extra_v})

	var requested_v: Variant = spec["requested_mine_count"]
	if typeof(requested_v) != TYPE_INT:
		return _fail(&"spec_field_invalid", "requested_mine_count must be an integer", {"field": "requested_mine_count"})
	var requested: int = int(requested_v)
	var base: int = int(base_mine_count_v)
	if requested < base or requested > base + expected_raw_extra:
		return _fail(&"spec_field_invalid",
			"requested_mine_count must be between base_mine_count and base_mine_count+raw_extra_mines",
			{"field": "requested_mine_count"})
	if requested > int(width_v) * int(height_v) - 1:
		return _fail(&"spec_field_invalid", "requested_mine_count must leave at least one safe cell",
			{"field": "requested_mine_count"})

	var capability_ids: Variant = spec["capability_ids"]
	if typeof(capability_ids) != TYPE_ARRAY:
		return _fail(&"spec_field_invalid", "capability_ids must be an array", {"field": "capability_ids"})
	for entry: Variant in (capability_ids as Array):
		if typeof(entry) != TYPE_STRING:
			return _fail(&"spec_field_invalid", "capability_ids must contain only strings", {"field": "capability_ids"})

	if String(spec["placement_stream_id"]) != _PLACEMENT_STREAM_ID:
		return _fail(&"spec_field_invalid", "placement_stream_id is frozen", {"field": "placement_stream_id"})
	if String(spec["debug_stream_id"]) != _DEBUG_STREAM_ID:
		return _fail(&"spec_field_invalid", "debug_stream_id is frozen", {"field": "debug_stream_id"})
	if String(spec["explosion_stream_id"]) != _EXPLOSION_STREAM_ID:
		return _fail(&"spec_field_invalid", "explosion_stream_id is frozen", {"field": "explosion_stream_id"})
	if String(spec["generator_version"]) != _GENERATOR_VERSION:
		return _fail(&"spec_field_invalid", "generator_version is frozen", {"field": "generator_version"})
	if String(spec["verifier_version"]) != _VERIFIER_VERSION:
		return _fail(&"spec_field_invalid", "verifier_version is frozen", {"field": "verifier_version"})

	return {"ok": true, "code": &"ok", "value": {"spec": spec.duplicate(true)}, "receipt": {}}


static func validate_layout(layout: Dictionary, spec: Dictionary) -> Dictionary:
	var spec_check := validate_spec(spec)
	if not spec_check.get("ok", false):
		return spec_check
	var shape := _exact_keys(layout, _LAYOUT_KEYS, &"layout_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(layout["schema_version"]) != TYPE_INT or int(layout["schema_version"]) != 1:
		return _fail(&"layout_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})

	var width_v: Variant = layout["width"]
	var height_v: Variant = layout["height"]
	if typeof(width_v) != TYPE_INT or int(width_v) != int(spec["width"]):
		return _fail(&"layout_field_invalid", "width must match the spec", {"field": "width"})
	if typeof(height_v) != TYPE_INT or int(height_v) != int(spec["height"]):
		return _fail(&"layout_field_invalid", "height must match the spec", {"field": "height"})
	var width: int = int(width_v)
	var height: int = int(height_v)
	var total_cells: int = width * height

	var indices := _sorted_unique_indices(layout.get("mine_indices"), total_cells)
	if not indices.get("ok", false):
		return _fail(&"layout_field_invalid", "mine_indices invalid: %s" % indices.get("message", ""),
			{"field": "mine_indices"})
	var mine_indices: Array[int] = indices["value"]
	var actual_mine_count: int = mine_indices.size()
	if actual_mine_count != int(spec["requested_mine_count"]):
		return _fail(&"layout_mine_count_mismatch",
			"the actual mine count does not match the spec's requested_mine_count",
			{"expected": spec["requested_mine_count"], "actual": actual_mine_count})

	var claimed_mine_count: Variant = layout["mine_count"]
	if typeof(claimed_mine_count) != TYPE_INT or int(claimed_mine_count) != actual_mine_count:
		return _fail(&"layout_mine_count_mismatch", "mine_count does not match mine_indices",
			{"expected": actual_mine_count, "actual": claimed_mine_count})

	var canonical: Dictionary = {
		"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices, "mine_count": actual_mine_count,
	}
	return {"ok": true, "code": &"ok", "value": {"layout": canonical}, "receipt": {}}


## board dictionaries round-trip through JSON.stringify()/JSON.parse_string() elsewhere in the
## pipeline (e.g. save data); JSON has no int/float distinction so every whole number comes back
## as TYPE_FLOAT. validate_board therefore accepts a whole-number float anywhere an integer field
## is expected -- see _is_int_like() -- while still rejecting fractional values and every other
## type. A caller that wants strictly-typed ints back should re-derive them via first_reveal()/
## reveal()/etc rather than trust the raw round-tripped dictionary.
static func validate_board(board: Dictionary) -> Dictionary:
	var shape := _exact_keys(board, _BOARD_KEYS, &"board_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if not _is_int_like(board["schema_version"]) or int(board["schema_version"]) != 1:
		return _fail(&"board_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})

	var width_v: Variant = board["width"]
	var height_v: Variant = board["height"]
	if not _is_int_like(width_v) or int(width_v) <= 0:
		return _fail(&"board_field_invalid", "width must be a positive integer", {"field": "width"})
	if not _is_int_like(height_v) or int(height_v) <= 0:
		return _fail(&"board_field_invalid", "height must be a positive integer", {"field": "height"})
	var width: int = int(width_v)
	var height: int = int(height_v)
	var total_cells: int = width * height

	var mine_check := _sorted_unique_indices(board.get("mine_indices"), total_cells)
	if not mine_check.get("ok", false):
		return _fail(&"board_field_invalid", "mine_indices invalid: %s" % mine_check.get("message", ""),
			{"field": "mine_indices"})
	var mines: Array[int] = mine_check["value"]
	var mine_set: Dictionary = {}
	for m: int in mines:
		mine_set[m] = true
	if not _is_int_like(board["mine_count"]) or int(board["mine_count"]) != mines.size():
		return _fail(&"board_mine_count_mismatch", "mine_count does not match mine_indices", {})

	var revealed_check := _sorted_unique_indices(board.get("revealed_indices"), total_cells)
	if not revealed_check.get("ok", false):
		return _fail(&"board_field_invalid", "revealed_indices invalid: %s" % revealed_check.get("message", ""),
			{"field": "revealed_indices"})
	var revealed: Array[int] = revealed_check["value"]
	var revealed_set: Dictionary = {}
	for r: int in revealed:
		revealed_set[r] = true

	var flagged_check := _sorted_unique_indices(board.get("flagged_indices"), total_cells)
	if not flagged_check.get("ok", false):
		return _fail(&"board_field_invalid", "flagged_indices invalid: %s" % flagged_check.get("message", ""),
			{"field": "flagged_indices"})
	var flagged: Array[int] = flagged_check["value"]
	for f: int in flagged:
		if revealed_set.has(f):
			return _fail(&"board_revealed_flagged_overlap",
				"a cell cannot be both revealed and flagged", {"cell_index": f})

	var adjacency_v: Variant = board["adjacency_counts"]
	if typeof(adjacency_v) != TYPE_ARRAY or (adjacency_v as Array).size() != total_cells:
		return _fail(&"board_field_invalid", "adjacency_counts must have width*height entries",
			{"field": "adjacency_counts"})
	var expected_adjacency := _recompute_adjacency(mine_set, width, height)
	var adjacency_array: Array = adjacency_v
	for index in range(total_cells):
		if not _is_int_like(adjacency_array[index]) or int(adjacency_array[index]) != expected_adjacency[index]:
			return _fail(&"board_adjacency_mismatch",
				"adjacency_counts does not match the hidden mine layout", {"cell_index": index})

	var exploded_v: Variant = board["exploded_index"]
	if not _is_int_like(exploded_v) or int(exploded_v) < -1 or int(exploded_v) >= total_cells:
		return _fail(&"board_field_invalid", "exploded_index must be -1 or a valid cell index", {"field": "exploded_index"})
	var exploded_index: int = int(exploded_v)
	if exploded_index != -1 and not (revealed_set.has(exploded_index) and mine_set.has(exploded_index)):
		return _fail(&"board_field_invalid", "exploded_index must be a revealed mine cell", {"field": "exploded_index"})

	var safe_cells_total: int = total_cells - mines.size()
	var non_mine_revealed_count := 0
	for r: int in revealed:
		if not mine_set.has(r):
			non_mine_revealed_count += 1
	var expected_terminal: bool
	var expected_outcome: StringName
	if exploded_index != -1:
		expected_terminal = true
		expected_outcome = &"exploded"
	elif non_mine_revealed_count == safe_cells_total:
		expected_terminal = true
		expected_outcome = &"cleared"
	else:
		expected_terminal = false
		expected_outcome = &"active"

	if typeof(board["terminal"]) != TYPE_BOOL or bool(board["terminal"]) != expected_terminal:
		return _fail(&"board_terminal_mismatch", "terminal does not match the recomputed truth", {})
	if StringName(board["outcome"]) != expected_outcome:
		return _fail(&"board_outcome_mismatch", "outcome does not match the recomputed truth",
			{"expected": expected_outcome, "actual": board["outcome"]})

	var actions_v: Variant = board["actions"]
	if typeof(actions_v) != TYPE_ARRAY:
		return _fail(&"board_field_invalid", "actions must be an array", {"field": "actions"})
	var actions: Array = actions_v
	var seen_transactions: Dictionary = {}
	for order in range(actions.size()):
		var action: Variant = actions[order]
		if typeof(action) != TYPE_DICTIONARY:
			return _fail(&"board_action_invalid", "each action must be a dictionary", {"index": order})
		var entry: Dictionary = action
		if not (entry.has("transaction_id") and entry.has("kind") and entry.has("cell_index") and entry.has("revision")):
			return _fail(&"board_action_invalid", "action is missing required members", {"index": order})
		var transaction_id: Variant = entry["transaction_id"]
		if typeof(transaction_id) != TYPE_STRING or String(transaction_id).strip_edges().is_empty():
			return _fail(&"board_action_invalid", "transaction_id must be nonblank", {"index": order})
		if seen_transactions.has(transaction_id):
			return _fail(&"board_action_invalid", "duplicate transaction_id in the action ledger",
				{"transaction_id": transaction_id})
		seen_transactions[transaction_id] = true
		if not _ACTION_KINDS.has(StringName(entry["kind"])):
			return _fail(&"board_action_invalid", "unknown action kind", {"index": order})
		if not _is_int_like(entry.get("cell_index")) or int(entry["cell_index"]) < 0 or int(entry["cell_index"]) >= total_cells:
			return _fail(&"board_action_invalid", "action cell_index must be a valid cell index", {"index": order})
		if not _is_int_like(entry["revision"]) or int(entry["revision"]) != order + 1:
			return _fail(&"board_action_sequence_invalid",
				"action revisions must be sequential starting at 1", {"index": order})

	if not _is_int_like(board["revision"]) or int(board["revision"]) != actions.size():
		return _fail(&"board_revision_mismatch", "revision must equal the number of applied actions", {})

	return {"ok": true, "code": &"ok", "value": {"board": board.duplicate(true)}, "receipt": {}}


# ---- shared helpers ----

static func _is_int_like(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and float(value) == floor(float(value))


static func _sorted_unique_indices(value: Variant, total_cells: int) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false, "message": "must be an array"}
	var seen: Dictionary = {}
	var indices: Array[int] = []
	for entry: Variant in (value as Array):
		if not _is_int_like(entry):
			return {"ok": false, "message": "must contain only integers"}
		var index: int = int(entry)
		if index < 0 or index >= total_cells:
			return {"ok": false, "message": "index out of range: %d" % index}
		if seen.has(index):
			return {"ok": false, "message": "duplicate index: %d" % index}
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


static func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _nonblank_string(value: Variant, field: String) -> Dictionary:
	if typeof(value) != TYPE_STRING:
		return _fail(&"spec_field_invalid", "%s must be a string" % field, {"field": field})
	if String(value).strip_edges().is_empty():
		return _fail(&"spec_field_invalid", "%s must be nonblank" % field, {"field": field})
	return {"ok": true}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
