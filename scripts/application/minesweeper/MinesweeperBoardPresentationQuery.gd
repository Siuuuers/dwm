extends RefCounted

const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")

static func desktop(snapshot: Dictionary, difficulty: String, entry_eligible: bool = false) -> Dictionary:
	if not STATE.new().check_snapshot(snapshot).ok: return _fail()
	var phase: String = snapshot.phase
	if phase == "NONE":
		var catalog := CATALOG.lookup("desktop_app", difficulty)
		if not catalog.ok: return _fail()
		var dimensions: Dictionary = catalog.value
		return _shell(dimensions.width, dimensions.height, snapshot.revision, [], entry_eligible)
	if phase == "UNPAID_UNSTARTED":
		var candidate: Dictionary = snapshot.candidate
		return _shell(candidate.width, candidate.height, snapshot.revision, candidate.flagged_indices, entry_eligible)
	if phase == "PAID_UNSTARTED":
		var candidate: Dictionary = snapshot.candidate
		return _shell(candidate.spec.width, candidate.spec.height, snapshot.revision, candidate.flagged_indices, true)
	if phase in ["PREPARING", "PREPARED_UNSTARTED"]:
		return _candidate(snapshot)
	var wrapper: Dictionary = snapshot.board
	if snapshot.has("round_paid"):
		if not _keys(wrapper, ["board", "spec"]): return _fail()
	else:
		if not (_keys(wrapper, ["board", "paid_start_receipt"]) or _keys(wrapper, ["board", "paid_start_receipt", "spec"])) or not wrapper.board is Dictionary or not wrapper.paid_start_receipt is Dictionary:
			return _fail()
		if wrapper.paid_start_receipt.is_empty(): return _fail()
	if wrapper.has("spec"):
		if not wrapper.spec is Dictionary or not SCHEMA.check_spec(wrapper.spec).get("ok", false): return _fail()
	var board: Dictionary = wrapper.board
	if not SCHEMA.check_board(board).ok: return _fail()
	if phase == "SETTLING" and (not board.terminal or snapshot.settlement.is_empty()): return _fail()
	var cells: Array[Dictionary] = []
	var terminal: bool = board.terminal
	var inspectable: bool = phase == "ACTIVE_VISIBLE" and not terminal
	var revealed_set := _index_set(board.revealed_indices)
	var flagged_set := _index_set(board.flagged_indices)
	var mine_set: Dictionary = _index_set(board.mine_indices) if terminal else {}
	var adjacent_flags: Dictionary = _adjacent_flag_counts(board, flagged_set) if inspectable else {}
	var adjacency: Array = board.adjacency_counts
	var exploded: Variant = board.exploded_index
	for index in int(board.width) * int(board.height):
		var revealed: bool = revealed_set.has(index)
		var flagged: bool = flagged_set.has(index)
		var face := "covered"
		var mark := "none"
		var number := 0
		var actions: Array = []
		if revealed:
			face = "revealed"
			number = int(adjacency[index])
			if inspectable and number > 0 and int(adjacent_flags.get(index, 0)) == number: actions = ["chord"]
		elif flagged:
			mark = "flag"
			if inspectable: actions = ["unflag"]
		elif inspectable:
			actions = ["reveal", "flag"]
		if terminal:
			if flagged:
				mark = "correct_flag" if mine_set.has(index) else "incorrect_flag"
			elif mine_set.has(index):
				face = "revealed"
				number = 0
				mark = "exploded" if index == exploded else "mine"
		cells.append({"index": index, "face": face, "mark": mark, "number": number,
			"bracketed": false, "inspectable": inspectable, "pressable": not actions.is_empty(), "actions": actions})
	return _ok({"width": int(board.width), "height": int(board.height), "revision": snapshot.revision,
		"mine_estimate": int(board.mine_count) - board.flagged_indices.size(), "terminal": board.terminal,
		"custody": phase != "ACTIVE_VISIBLE" or board.terminal, "cells": cells})

static func _candidate(snapshot: Dictionary) -> Dictionary:
	var candidate: Dictionary = snapshot.candidate
	var prepared: bool = snapshot.phase == "PREPARED_UNSTARTED"
	var keys: Array = ["spec", "layout", "forced_cell", "proof_sha256"] if prepared else ["spec", "frontier"]
	for extra: String in ["flagged_indices", "actions", "paid_start_receipt"]:
		if candidate.has(extra): keys.append(extra)
	if not _keys(candidate, keys) or not candidate.spec is Dictionary: return _fail()
	var spec: Dictionary = candidate.spec
	if not SCHEMA.check_spec(spec).ok: return _fail()
	if spec.board_kind != "desktop": return _fail()
	if not prepared:
		if not candidate.frontier is Dictionary: return _fail()
		return _shell(spec.width, spec.height, snapshot.revision, [], false, true)
	if not candidate.layout is Dictionary: return _fail()
	var validated_layout := SCHEMA.validate_layout(candidate.layout, spec)
	if not validated_layout.get("ok", false): return _fail()
	var layout: Dictionary = validated_layout.value.layout
	if typeof(candidate.forced_cell) != TYPE_INT or candidate.forced_cell < 0 or candidate.forced_cell >= spec.width * spec.height: return _fail()
	if layout.mine_indices.has(candidate.forced_cell): return _fail()
	if candidate.proof_sha256 != null and typeof(candidate.proof_sha256) != TYPE_STRING: return _fail()
	var result := _shell(spec.width, spec.height, snapshot.revision, [], true, false, candidate.forced_cell)
	result.value.mine_estimate = int(layout.mine_count)
	return result


static func _adjacent_flag_counts(board: Dictionary, flagged_set: Dictionary) -> Dictionary:
	var width: int = int(board.width)
	var height: int = int(board.height)
	var counts := {}
	for flag: int in flagged_set.keys():
		var column: int = flag % width
		var row: int = flag / width
		for y in range(maxi(0, row - 1), mini(height, row + 2)):
			for x in range(maxi(0, column - 1), mini(width, column + 2)):
				if x == column and y == row: continue
				var neighbor: int = y * width + x
				counts[neighbor] = int(counts.get(neighbor, 0)) + 1
	return counts

static func _index_set(indices: Variant) -> Dictionary:
	var members := {}
	if indices is Array:
		for index: Variant in indices: members[int(index)] = true
	return members

static func _keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() and value.has_all(expected)

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _fail() -> Dictionary:
	return {"ok": false, "code": &"invalid_minesweeper_presentation_source"}


static func _shell(width: int, height: int, revision: int, flags: Array, reveal_eligible: bool,
		custody: bool = false, forced_cell: int = -1) -> Dictionary:
	var cells: Array[Dictionary] = []
	for index in width * height:
		var bracketed := index == forced_cell
		var actionable := not custody and (forced_cell < 0 or bracketed)
		var flagged := flags.has(index)
		var cell := {"index": index, "face": "covered", "mark": "flag" if flagged else "none", "number": 0,
			"bracketed": bracketed, "inspectable": actionable, "pressable": actionable, "actions": []}
		if actionable:
			if flagged:
				cell.actions = ["unflag"]
			elif bracketed:
				cell.actions = ["reveal"]
			else:
				cell.actions = ["reveal", "flag"] if reveal_eligible else ["flag"]
		cells.append(cell)
	return _ok({"width": width, "height": height, "revision": revision, "mine_estimate": null,
		"terminal": false, "custody": custody, "cells": cells})
