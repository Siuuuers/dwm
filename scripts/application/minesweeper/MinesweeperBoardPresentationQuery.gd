extends RefCounted
## One-way projection of retained desktop board truth. Never pass the source snapshot to a Control.
## Terminal facts are public after the board command commits, but inspection stays locked until
## a separate, durable terminal-view owner exists. This query does not manufacture that owner.

const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")

static func desktop(snapshot: Dictionary, difficulty: String, entry_eligible: bool = false) -> Dictionary:
	if not STATE.new().prepare_restore(snapshot).get("ok", false):
		return _fail()
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
	if not (_keys(wrapper, ["board", "paid_start_receipt"]) or _keys(wrapper, ["board", "paid_start_receipt", "spec"])) or not wrapper.board is Dictionary or not wrapper.paid_start_receipt is Dictionary:
		return _fail()
	if wrapper.paid_start_receipt.is_empty(): return _fail()
	if wrapper.has("spec"):
		if not wrapper.spec is Dictionary or not SCHEMA.validate_spec(wrapper.spec).get("ok", false): return _fail()
	var validated := SCHEMA.validate_board(wrapper.board)
	if not validated.get("ok", false): return _fail()
	var board: Dictionary = validated.value.board
	if phase == "SETTLING" and (not board.terminal or snapshot.settlement.is_empty()): return _fail()
	# Retained dimensions remain literal, including older valid boards. Never reshape a save.
	var cells: Array[Dictionary] = []
	var inspectable: bool = phase == "ACTIVE_VISIBLE" and not board.terminal
	# dwm-634.1: one pass builds the index sets so each cell is a dictionary probe, not a scan.
	var revealed_set := _index_set(board.revealed_indices)
	var flagged_set := _index_set(board.flagged_indices)
	var mine_set := _index_set(board.mine_indices)
	for index in int(board.width) * int(board.height):
		var revealed: bool = revealed_set.has(index)
		var flagged: bool = flagged_set.has(index)
		var cell := _cell(index, inspectable)
		if inspectable: cell.actions = ["reveal", "flag"]
		if revealed:
			cell.face = "revealed"
			cell.number = int(board.adjacency_counts[index])
			cell.actions = ["chord"] if inspectable and cell.number > 0 and _adjacent_flags(index, board, flagged_set) == cell.number else []
		elif flagged:
			cell.mark = "flag"
			cell.actions = ["unflag"] if inspectable else []
		if board.terminal:
			if flagged:
				cell.mark = "correct_flag" if mine_set.has(index) else "incorrect_flag"
			elif mine_set.has(index):
				cell.face = "revealed"
				cell.number = 0
				cell.mark = "exploded" if index == board.exploded_index else "mine"
		cell.pressable = not cell.actions.is_empty()
		cells.append(cell)
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
	var validated_spec := SCHEMA.validate_spec(candidate.spec)
	if not validated_spec.get("ok", false): return _fail()
	var spec: Dictionary = validated_spec.value.spec
	if spec.board_kind != "desktop": return _fail()
	if not prepared:
		if not candidate.frontier is Dictionary: return _fail()
		return _covered(spec.width, spec.height, snapshot.revision, false, -1, null, true)
	if not candidate.layout is Dictionary: return _fail()
	var validated_layout := SCHEMA.validate_layout(candidate.layout, spec)
	if not validated_layout.get("ok", false): return _fail()
	var layout: Dictionary = validated_layout.value.layout
	if typeof(candidate.forced_cell) != TYPE_INT or candidate.forced_cell < 0 or candidate.forced_cell >= spec.width * spec.height: return _fail()
	if layout.mine_indices.has(candidate.forced_cell): return _fail()
	if candidate.proof_sha256 != null and typeof(candidate.proof_sha256) != TYPE_STRING: return _fail()
	var shell := {"flagged_indices": candidate.get("flagged_indices", []), "actions": candidate.get("actions", [])}
	var shell_valid := SCHEMA.validate_shell(shell, int(spec.width), int(spec.height))
	if not shell_valid.ok: return _fail()
	var result := _shell(spec.width, spec.height, snapshot.revision, shell_valid.value.shell.flagged_indices, true)
	result.value.mine_estimate = int(layout.mine_count) - shell_valid.value.shell.flagged_indices.size()
	for cell: Dictionary in result.value.cells:
		cell.bracketed = cell.index == candidate.forced_cell
		if cell.index != candidate.forced_cell: cell.actions.erase("reveal")
	return result


static func _covered(width: int, height: int, revision: int, actionable: bool, forced: int, estimate: Variant, custody: bool) -> Dictionary:
	var cells: Array[Dictionary] = []
	for index in width * height:
		var cell := _cell(index, actionable and (forced < 0 or forced == index))
		cell.bracketed = index == forced
		cell.actions = ["reveal"] if cell.inspectable else []
		cell.pressable = not cell.actions.is_empty()
		cells.append(cell)
	return _ok({"width": width, "height": height, "revision": revision, "mine_estimate": estimate,
		"terminal": false, "custody": custody, "cells": cells})

static func _cell(index: int, inspectable: bool) -> Dictionary:
	return {"index": index, "face": "covered", "mark": "none", "number": 0,
		"bracketed": false, "inspectable": inspectable, "pressable": false, "actions": []}

static func _adjacent_flags(index: int, board: Dictionary, flagged_set: Dictionary) -> int:
	var width: int = int(board.width)
	var column: int = index % width
	var row: int = index / width
	var count := 0
	for y in range(maxi(0, row - 1), mini(int(board.height), row + 2)):
		for x in range(maxi(0, column - 1), mini(width, column + 2)):
			if (x != column or y != row) and flagged_set.has(y * width + x): count += 1
	return count

static func _index_set(indices: Variant) -> Dictionary:
	var members := {}
	if indices is Array:
		for index: Variant in indices: members[int(index)] = true
	return members

static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: String in expected:
		if not value.has(key): return false
	return true

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _fail() -> Dictionary:
	# Do not echo an invalid source's values, paths, identities or schema diagnostic details.
	return {"ok": false, "code": &"invalid_minesweeper_presentation_source"}


static func _shell(width: int, height: int, revision: int, flags: Array, reveal_eligible: bool) -> Dictionary:
	var result := _covered(width, height, revision, true, -1, null, false)
	for cell: Dictionary in result.value.cells:
		if flags.has(cell.index):
			cell.mark = "flag"
			cell.actions = ["unflag"]
		else:
			cell.actions = ["reveal", "flag"] if reveal_eligible else ["flag"]
		cell.pressable = true
	return result
