class_name MinesweeperNoGuessVerifier
extends RefCounted

## Deterministic visible-deduction ("no guess") verifier (Plan 02 Task 3, dwm-p2r13). Applies
## only four rules to a fixpoint: adjacent_zero, adjacent_full, subset_difference, and
## global_remaining. Cells are sorted row-major and constraints by canonical serialized bytes
## before each pass, so the result is identical regardless of input dictionary/array ordering.
##
## The hidden layout is consulted only to VALIDATE a deduction already reached by pure logic --
## to reveal a cell's true number once it has been independently proven safe, or to defensively
## cross-check a cell proven to be a mine -- never to originate a deduction or mark a player fact.
## The one exception is global_remaining's total mine count, which is public information (the
## on-screen mine counter derived from BoardSpec.requested_mine_count), not a hidden fact, so it
## may be read from the layout directly as a "truthful" constant.
##
## Success requires every safe cell to be deduced/revealed; a fixpoint that stalls with unsolved
## safe cells remaining means the layout requires guessing (code guess_required). Exhausting the
## caller's operation_budget before either outcome returns generation_budget_exhausted with no
## partial proof in `value`.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _RULE_ADJACENT_ZERO := &"adjacent_zero"
const _RULE_ADJACENT_FULL := &"adjacent_full"
const _RULE_SUBSET_DIFFERENCE := &"subset_difference"
const _RULE_GLOBAL_REMAINING := &"global_remaining"


static func verify(layout: Dictionary, forced_cell: int, operation_budget: int) -> Dictionary:
	if typeof(operation_budget) != TYPE_INT or operation_budget < 0:
		return _fail(&"invalid_operation_budget", "operation_budget must be a nonnegative integer", {})
	var parsed := _parse_layout(layout)
	if not parsed.get("ok", false):
		return parsed
	var width: int = parsed["width"]
	var height: int = parsed["height"]
	var mine_set: Dictionary = parsed["mine_set"]
	var total_cells: int = width * height
	var total_mines: int = mine_set.size()

	if forced_cell < 0 or forced_cell >= total_cells:
		return _fail(&"cell_index_out_of_range", "forced_cell is out of range", {"forced_cell": forced_cell})
	if mine_set.has(forced_cell):
		return _fail(&"forced_cell_is_mine", "the forced cell must never be a mine", {"forced_cell": forced_cell})

	var revealed: Dictionary = {}
	var deduced_mine: Dictionary = {}
	var trace: Array = []

	revealed[forced_cell] = _true_count(forced_cell, mine_set, width, height)

	while true:
		if revealed.size() == total_cells - total_mines:
			return _certified_result(trace)

		var constraints := _build_constraints(revealed, deduced_mine, width, height)
		var deduction := _apply_rules(constraints, total_mines, deduced_mine.size(), total_cells, revealed, deduced_mine)

		if deduction.is_empty():
			return _fail(&"guess_required",
				"no allowed rule can make further progress; the layout requires guessing beyond this point", {})

		if trace.size() + 1 > operation_budget:
			return _fail(&"generation_budget_exhausted",
				"the verifier exhausted its operation budget before certifying the layout", {})

		trace.append(deduction)
		for cell: Variant in (deduction["proven_safe"] as Array):
			var idx: int = int(cell)
			if mine_set.has(idx):
				return _fail(&"internal_deduction_unsound",
					"a cell proven safe by an allowed rule was actually a mine", {"cell_index": idx})
			revealed[idx] = _true_count(idx, mine_set, width, height)
		for cell: Variant in (deduction["proven_mine"] as Array):
			var idx: int = int(cell)
			if not mine_set.has(idx):
				return _fail(&"internal_deduction_unsound",
					"a cell proven mine by an allowed rule was actually safe", {"cell_index": idx})
			deduced_mine[idx] = true
	return _fail(&"unreachable", "the verification fixpoint loop must always return from within the loop", {})


static func _certified_result(trace: Array) -> Dictionary:
	var trace_text := _CANONICAL_JSON.stringify(trace)
	if not trace_text.get("ok", false):
		return _fail(&"proof_trace_not_canonicalizable", "the proof trace could not be canonicalized", {})
	return {"ok": true, "code": &"ok", "value": {
		"certified": true, "operation_count": trace.size(),
		"proof_trace": trace.duplicate(true),
		"proof_trace_sha256": String(trace_text["value"]).sha256_text(),
	}, "receipt": {}}


## Builds one constraint per revealed, informative cell (cells with no remaining hidden neighbor
## are fully discharged and dropped). Cells are visited row-major; the resulting constraint list
## is then sorted by canonical serialized bytes so pass order never depends on Dictionary/Array
## insertion order.
static func _build_constraints(revealed: Dictionary, deduced_mine: Dictionary, width: int, height: int) -> Array:
	var cell_indices: Array = revealed.keys()
	cell_indices.sort()
	var constraints: Array = []
	for cell: Variant in cell_indices:
		var idx: int = int(cell)
		var true_count: int = int(revealed[cell])
		var hidden: Array[int] = []
		var known_mine_neighbors := 0
		for neighbor: int in _neighbors(idx, width, height):
			if revealed.has(neighbor):
				continue
			if deduced_mine.has(neighbor):
				known_mine_neighbors += 1
				continue
			hidden.append(neighbor)
		if hidden.is_empty():
			continue
		hidden.sort()
		constraints.append({"id": "cell:%d" % idx, "cells": hidden, "count": true_count - known_mine_neighbors})
	constraints.sort_custom(_by_canonical_bytes)
	return constraints


static func _by_canonical_bytes(a: Dictionary, b: Dictionary) -> bool:
	var a_text: String = String(_CANONICAL_JSON.stringify(a)["value"])
	var b_text: String = String(_CANONICAL_JSON.stringify(b)["value"])
	var a_bytes := a_text.to_utf8_buffer()
	var b_bytes := b_text.to_utf8_buffer()
	var shared: int = mini(a_bytes.size(), b_bytes.size())
	for i in range(shared):
		if a_bytes[i] != b_bytes[i]:
			return a_bytes[i] < b_bytes[i]
	return a_bytes.size() < b_bytes.size()


## Applies the four allowed rules in a fixed priority (zero, full, subset-difference, global) and
## returns the first deduction found, or an empty Dictionary if the fixpoint has stalled.
static func _apply_rules(constraints: Array, total_mines: int, deduced_mine_count: int,
		total_cells: int, revealed: Dictionary, deduced_mine: Dictionary) -> Dictionary:
	for constraint: Variant in constraints:
		var entry: Dictionary = constraint
		var cells: Array = entry["cells"]
		if int(entry["count"]) == 0:
			return {"rule": _RULE_ADJACENT_ZERO, "source_constraint_ids": [entry["id"]],
				"proven_safe": cells.duplicate(), "proven_mine": []}
	for constraint: Variant in constraints:
		var entry: Dictionary = constraint
		var cells: Array = entry["cells"]
		if int(entry["count"]) == cells.size():
			return {"rule": _RULE_ADJACENT_FULL, "source_constraint_ids": [entry["id"]],
				"proven_safe": [], "proven_mine": cells.duplicate()}

	for a: Variant in constraints:
		var a_entry: Dictionary = a
		var a_cells: Array = a_entry["cells"]
		var a_set := _as_set(a_cells)
		for b: Variant in constraints:
			var b_entry: Dictionary = b
			if a_entry["id"] == b_entry["id"]:
				continue
			var b_cells: Array = b_entry["cells"]
			if a_cells.size() >= b_cells.size():
				continue
			var is_subset := true
			for cell: Variant in a_cells:
				if not b_cells.has(cell):
					is_subset = false
					break
			if not is_subset:
				continue
			var diff: Array = []
			for cell: Variant in b_cells:
				if not a_set.has(cell):
					diff.append(cell)
			diff.sort()
			var diff_count: int = int(b_entry["count"]) - int(a_entry["count"])
			var source_ids: Array = [a_entry["id"], b_entry["id"]]
			source_ids.sort()
			if diff_count == 0:
				return {"rule": _RULE_SUBSET_DIFFERENCE, "source_constraint_ids": source_ids,
					"proven_safe": diff, "proven_mine": []}
			if diff_count == diff.size():
				return {"rule": _RULE_SUBSET_DIFFERENCE, "source_constraint_ids": source_ids,
					"proven_safe": [], "proven_mine": diff}

	var remaining_mines: int = total_mines - deduced_mine_count
	var undetermined: Array[int] = []
	for index in range(total_cells):
		if not revealed.has(index) and not deduced_mine.has(index):
			undetermined.append(index)
	if not undetermined.is_empty():
		if remaining_mines == 0:
			return {"rule": _RULE_GLOBAL_REMAINING, "source_constraint_ids": ["global"],
				"proven_safe": undetermined, "proven_mine": []}
		if remaining_mines == undetermined.size():
			return {"rule": _RULE_GLOBAL_REMAINING, "source_constraint_ids": ["global"],
				"proven_safe": [], "proven_mine": undetermined}

	return {}


# ---- shared helpers ----

static func _as_set(array: Array) -> Dictionary:
	var set: Dictionary = {}
	for item: Variant in array:
		set[item] = true
	return set


static func _true_count(index: int, mine_set: Dictionary, width: int, height: int) -> int:
	var count := 0
	for neighbor: int in _neighbors(index, width, height):
		if mine_set.has(neighbor):
			count += 1
	return count


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


static func _parse_layout(layout: Dictionary) -> Dictionary:
	if not (layout.has("width") and layout.has("height") and layout.has("mine_indices")):
		return _fail(&"layout_field_invalid", "layout must include width, height, mine_indices", {})
	var width_v: Variant = layout["width"]
	var height_v: Variant = layout["height"]
	if typeof(width_v) != TYPE_INT or int(width_v) <= 0:
		return _fail(&"layout_field_invalid", "width must be a positive integer", {})
	if typeof(height_v) != TYPE_INT or int(height_v) <= 0:
		return _fail(&"layout_field_invalid", "height must be a positive integer", {})
	var width: int = int(width_v)
	var height: int = int(height_v)
	var total_cells: int = width * height
	var mine_indices_v: Variant = layout["mine_indices"]
	if typeof(mine_indices_v) != TYPE_ARRAY:
		return _fail(&"layout_field_invalid", "mine_indices must be an array", {})
	var seen: Dictionary = {}
	var mine_set: Dictionary = {}
	for entry: Variant in (mine_indices_v as Array):
		if typeof(entry) != TYPE_INT:
			return _fail(&"layout_field_invalid", "mine_indices must contain only integers", {})
		var index: int = int(entry)
		if index < 0 or index >= total_cells:
			return _fail(&"layout_field_invalid", "mine_indices entry out of range", {"value": index})
		if seen.has(index):
			return _fail(&"layout_field_invalid", "mine_indices must not repeat", {"value": index})
		seen[index] = true
		mine_set[index] = true
	return {"ok": true, "width": width, "height": height, "mine_set": mine_set}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
