extends "res://addons/gut/test.gd"

# Board truth suite (Plan 02 Task 3, dwm-p2r13): MinesweeperBoardSchema validation AND
# MinesweeperBoardReducer behavioral coverage live together here per the task brief (downstream
# gates name suites by exact path -- this is the one named home for reducer cases).

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")

const VALID_SPEC := {
	"schema_version": 1,
	"board_kind": "desktop",
	"board_token": "board-token-1",
	"board_token_receipt_id": "board-token-receipt-1",
	"difficulty_id": "beginner",
	"width": 8,
	"height": 8,
	"base_mine_count": 10,
	"pressure": 3,
	"penalty_points_today": 1,
	"raw_extra_mines": 2,
	"requested_mine_count": 11,
	"capability_ids": ["first_cell_safe"],
	"placement_stream_id": "minesweeper_placement_v1",
	"placement_nonce": "placement-nonce-1",
	"placement_nonce_receipt_id": "placement-nonce-receipt-1",
	"debug_stream_id": "minesweeper_debug_v1",
	"debug_nonce": "debug-nonce-1",
	"debug_nonce_receipt_id": "debug-nonce-receipt-1",
	"explosion_stream_id": "minesweeper_explosion_v1",
	"explosion_nonce": "explosion-nonce-1",
	"explosion_nonce_receipt_id": "explosion-nonce-receipt-1",
	"generator_version": "dwm_generator_v1",
	"verifier_version": "visible_deduction_v1",
}

# 4x4 layout; cross-checked in Python (see task-3-report.md). Raw neighbor-mine counts are
# [0,1,1,1, 0,2,3,3, 0,1,0,1, 0,1,1,1], but a materialized board's adjacency_counts stores 0 for
# mine cells themselves (indices 2,3,10), giving [0,1,0,0, 0,2,3,3, 0,1,0,1, 0,1,1,1].
const LAYOUT_4X4 := {
	"schema_version": 1, "width": 4, "height": 4, "mine_indices": [2, 3, 10], "mine_count": 3,
}


# ---- Step 3.1 parse proof ----

func test_schema_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
	assert_true(loaded.get("ok", false), "MinesweeperBoardSchema.gd must load")


func test_reducer_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
	assert_true(loaded.get("ok", false), "MinesweeperBoardReducer.gd must load")


# ==== MinesweeperBoardSchema.validate_spec ====

func test_validate_spec_accepts_the_frozen_shape() -> void:
	var result: Dictionary = SCHEMA.validate_spec(VALID_SPEC)
	assert_true(result.get("ok", false), JSON.stringify(result))


func test_validate_spec_rejects_extra_and_missing_keys() -> void:
	var extra: Dictionary = VALID_SPEC.duplicate(true)
	extra["extra_field"] = "nope"
	assert_false(SCHEMA.validate_spec(extra).get("ok", true), "extra key rejects")
	for key: String in VALID_SPEC.keys():
		var missing: Dictionary = VALID_SPEC.duplicate(true)
		missing.erase(key)
		assert_false(SCHEMA.validate_spec(missing).get("ok", true), "missing %s must reject" % key)


func test_validate_spec_recomputes_raw_extra_mines() -> void:
	var bad: Dictionary = VALID_SPEC.duplicate(true)
	bad["raw_extra_mines"] = 99
	var result: Dictionary = SCHEMA.validate_spec(bad)
	assert_false(result.get("ok", true), "raw_extra_mines must equal floor(pressure/3)+penalty_points_today")


func test_validate_spec_rejects_requested_mine_count_below_base() -> void:
	var bad: Dictionary = VALID_SPEC.duplicate(true)
	bad["requested_mine_count"] = 5
	assert_false(SCHEMA.validate_spec(bad).get("ok", true), "requested_mine_count must never be below base_mine_count")


func test_validate_spec_rejects_requested_mine_count_above_raw_ceiling() -> void:
	var bad: Dictionary = VALID_SPEC.duplicate(true)
	bad["requested_mine_count"] = 13
	assert_false(SCHEMA.validate_spec(bad).get("ok", true), "requested_mine_count must never exceed base+raw_extra_mines")


func test_validate_spec_rejects_frozen_stream_and_version_literals() -> void:
	for field: String in ["placement_stream_id", "debug_stream_id", "explosion_stream_id",
			"generator_version", "verifier_version"]:
		var bad: Dictionary = VALID_SPEC.duplicate(true)
		bad[field] = "tampered"
		assert_false(SCHEMA.validate_spec(bad).get("ok", true), "%s is frozen and must reject a tampered value" % field)


func test_validate_spec_rejects_unknown_board_kind() -> void:
	var bad: Dictionary = VALID_SPEC.duplicate(true)
	bad["board_kind"] = "unknown_kind"
	assert_false(SCHEMA.validate_spec(bad).get("ok", true))


func test_validate_spec_rejects_blank_receipt_and_nonce_fields() -> void:
	for field: String in ["board_token", "board_token_receipt_id", "difficulty_id",
			"placement_nonce", "placement_nonce_receipt_id", "debug_nonce",
			"debug_nonce_receipt_id", "explosion_nonce", "explosion_nonce_receipt_id"]:
		var bad: Dictionary = VALID_SPEC.duplicate(true)
		bad[field] = "   "
		assert_false(SCHEMA.validate_spec(bad).get("ok", true), "%s must reject a blank value" % field)


# ==== MinesweeperBoardSchema.validate_layout ====

func test_validate_layout_accepts_a_matching_layout() -> void:
	var result: Dictionary = SCHEMA.validate_layout(LAYOUT_4X4, VALID_SPEC_4X4())
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["layout"]["mine_indices"], [2, 3, 10])


func test_validate_layout_rejects_dimension_mismatch() -> void:
	var bad: Dictionary = LAYOUT_4X4.duplicate(true)
	bad["width"] = 5
	assert_false(SCHEMA.validate_layout(bad, VALID_SPEC_4X4()).get("ok", true))


func test_validate_layout_rejects_mine_count_not_matching_spec() -> void:
	var spec: Dictionary = VALID_SPEC_4X4()
	spec["requested_mine_count"] = 4
	assert_false(SCHEMA.validate_layout(LAYOUT_4X4, spec).get("ok", true))


func test_validate_layout_rejects_duplicate_and_out_of_range_mine_indices() -> void:
	var duplicate: Dictionary = LAYOUT_4X4.duplicate(true)
	duplicate["mine_indices"] = [2, 2, 10]
	assert_false(SCHEMA.validate_layout(duplicate, VALID_SPEC_4X4()).get("ok", true), "duplicate mine index rejects")

	var out_of_range: Dictionary = LAYOUT_4X4.duplicate(true)
	out_of_range["mine_indices"] = [2, 3, 99]
	assert_false(SCHEMA.validate_layout(out_of_range, VALID_SPEC_4X4()).get("ok", true), "out-of-range mine index rejects")


func test_validate_layout_recomputes_mine_count_rather_than_trusting_it() -> void:
	var bad: Dictionary = LAYOUT_4X4.duplicate(true)
	bad["mine_count"] = 999
	assert_false(SCHEMA.validate_layout(bad, VALID_SPEC_4X4()).get("ok", true),
		"a tampered redundant mine_count must be caught by recomputation, not trusted")


func test_validate_layout_canonicalizes_mine_index_order() -> void:
	var reordered: Dictionary = LAYOUT_4X4.duplicate(true)
	reordered["mine_indices"] = [10, 2, 3]
	var result: Dictionary = SCHEMA.validate_layout(reordered, VALID_SPEC_4X4())
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["layout"]["mine_indices"], [2, 3, 10], "mine_indices must canonicalize to row-major sorted order")


func VALID_SPEC_4X4() -> Dictionary:
	var spec: Dictionary = VALID_SPEC.duplicate(true)
	spec["width"] = 4
	spec["height"] = 4
	spec["base_mine_count"] = 3
	spec["pressure"] = 0
	spec["penalty_points_today"] = 0
	spec["raw_extra_mines"] = 0
	spec["requested_mine_count"] = 3
	return spec


# ==== MinesweeperBoardSchema.validate_board ====

func test_validate_board_accepts_a_board_produced_by_first_reveal() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = SCHEMA.validate_board(board)
	assert_true(result.get("ok", false), JSON.stringify(result))


func test_validate_board_rejects_revealed_flagged_overlap() -> void:
	var board: Dictionary = _first_reveal_board()
	board["flagged_indices"] = [6]
	board["revealed_indices"] = (board["revealed_indices"] as Array) + [6]
	assert_false(SCHEMA.validate_board(board).get("ok", true), "a cell cannot be both revealed and flagged")


func test_validate_board_recomputes_adjacency_rather_than_trusting_it() -> void:
	var board: Dictionary = _first_reveal_board()
	var tampered: Array = (board["adjacency_counts"] as Array).duplicate()
	tampered[0] = 7
	board["adjacency_counts"] = tampered
	assert_false(SCHEMA.validate_board(board).get("ok", true), "tampered adjacency_counts must be caught by recomputation")


func test_validate_board_recomputes_terminal_and_outcome_truth() -> void:
	var board: Dictionary = _first_reveal_board()
	board["terminal"] = true
	board["outcome"] = &"cleared"
	assert_false(SCHEMA.validate_board(board).get("ok", true), "phase truth is recomputed, never trusted from the caller")


func test_validate_board_rejects_a_non_sequential_action_ledger() -> void:
	var board: Dictionary = _first_reveal_board()
	board["actions"] = [{"transaction_id": "tx-a", "kind": &"reveal", "cell_index": 6, "revision": 5}]
	board["revision"] = 1
	assert_false(SCHEMA.validate_board(board).get("ok", true), "action revisions must be sequential starting at 1")


# ==== MinesweeperBoardReducer.first_reveal: corner/edge/interior zero flood ====

func test_first_reveal_corner_zero_flood_clears_an_isolated_single_mine_board() -> void:
	var layout := {"schema_version": 1, "width": 5, "height": 5, "mine_indices": [24], "mine_count": 1}
	var result: Dictionary = REDUCER.first_reveal(layout, 0)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var board: Dictionary = result["value"]["board"]
	assert_eq(board["revealed_indices"].size(), 24)
	assert_true(board["terminal"])
	assert_eq(board["outcome"], &"cleared")


func test_first_reveal_edge_zero_flood_clears_an_isolated_single_mine_board() -> void:
	var layout := {"schema_version": 1, "width": 5, "height": 5, "mine_indices": [24], "mine_count": 1}
	var result: Dictionary = REDUCER.first_reveal(layout, 2)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["board"]["revealed_indices"].size(), 24)


func test_first_reveal_interior_zero_flood_clears_an_isolated_single_mine_board() -> void:
	var layout := {"schema_version": 1, "width": 5, "height": 5, "mine_indices": [24], "mine_count": 1}
	var result: Dictionary = REDUCER.first_reveal(layout, 12)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["board"]["revealed_indices"].size(), 24)


func test_first_reveal_every_first_cell_is_safe() -> void:
	var result: Dictionary = REDUCER.first_reveal(LAYOUT_4X4, 10)
	assert_false(result.get("ok", true), "first_reveal must reject a forced cell that lands on a mine")
	assert_eq(result.get("code"), &"forced_cell_is_mine")


func test_first_reveal_partial_flood_leaves_boundary_cells_hidden() -> void:
	var board: Dictionary = _first_reveal_board()
	assert_eq(board["revealed_indices"], [0, 1, 4, 5, 8, 9, 12, 13])
	assert_eq(board["adjacency_counts"], [0, 1, 0, 0, 0, 2, 3, 3, 0, 1, 0, 1, 0, 1, 1, 1])
	assert_false(board["terminal"])
	assert_eq(board["revision"], 0)
	assert_eq(board["actions"], [])


# ==== MinesweeperBoardReducer.reveal ====

func test_reveal_a_hidden_safe_cell_without_cascade() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = REDUCER.reveal(board, 14, "tx-reveal-14")
	assert_true(result.get("ok", false), JSON.stringify(result))
	var updated: Dictionary = result["value"]["board"]
	assert_true(updated["revealed_indices"].has(14))
	assert_eq(updated["revision"], 1)
	assert_false(updated["terminal"])


func test_reveal_a_mine_explodes() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = REDUCER.reveal(board, 10, "tx-explode")
	assert_true(result.get("ok", false), JSON.stringify(result))
	var updated: Dictionary = result["value"]["board"]
	assert_eq(updated["exploded_index"], 10)
	assert_true(updated["terminal"])
	assert_eq(updated["outcome"], &"exploded")


func test_reveal_every_remaining_safe_cell_clears_the_board() -> void:
	var board: Dictionary = _first_reveal_board()
	for cell_index: int in [6, 7, 11, 14, 15]:
		var result: Dictionary = REDUCER.reveal(board, cell_index, "tx-clear-%d" % cell_index)
		assert_true(result.get("ok", false), JSON.stringify(result))
		board = result["value"]["board"]
	assert_true(board["terminal"])
	assert_eq(board["outcome"], &"cleared")
	assert_eq(board["revision"], 5)


func test_reveal_rejects_an_already_revealed_cell() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = REDUCER.reveal(board, 0, "tx-again")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"cell_already_revealed")


func test_reveal_rejects_a_flagged_cell() -> void:
	var board: Dictionary = _first_reveal_board()
	board = REDUCER.set_flag(board, 10, true, "tx-flag-10")["value"]["board"]
	var result: Dictionary = REDUCER.reveal(board, 10, "tx-reveal-flagged")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"cell_is_flagged")


# ==== MinesweeperBoardReducer.set_flag ====

func test_set_flag_flags_and_unflags() -> void:
	var board: Dictionary = _first_reveal_board()
	var flagged_result: Dictionary = REDUCER.set_flag(board, 10, true, "tx-flag")
	assert_true(flagged_result.get("ok", false), JSON.stringify(flagged_result))
	var flagged_board: Dictionary = flagged_result["value"]["board"]
	assert_eq(flagged_board["flagged_indices"], [10])

	var unflagged_result: Dictionary = REDUCER.set_flag(flagged_board, 10, false, "tx-unflag")
	assert_true(unflagged_result.get("ok", false), JSON.stringify(unflagged_result))
	assert_eq(unflagged_result["value"]["board"]["flagged_indices"], [])


func test_set_flag_rejects_a_revealed_cell() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = REDUCER.set_flag(board, 0, true, "tx-flag-revealed")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"cell_already_revealed")


# ==== MinesweeperBoardReducer.chord ====

func test_chord_with_matching_flags_reveals_the_remaining_hidden_neighbors() -> void:
	var board: Dictionary = _first_reveal_board()
	board = REDUCER.set_flag(board, 10, true, "tx-flag-10")["value"]["board"]
	var result: Dictionary = REDUCER.chord(board, 9, "tx-chord-9")
	assert_true(result.get("ok", false), JSON.stringify(result))
	var updated: Dictionary = result["value"]["board"]
	assert_true(updated["revealed_indices"].has(6))
	assert_true(updated["revealed_indices"].has(14))
	assert_false(updated["terminal"])


func test_chord_rejects_a_flag_count_mismatch() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = REDUCER.chord(board, 9, "tx-chord-mismatch")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"chord_flag_count_mismatch")


func test_chord_with_a_misflagged_neighbor_explodes() -> void:
	var board: Dictionary = _first_reveal_board()
	board = REDUCER.set_flag(board, 6, true, "tx-flag-wrong")["value"]["board"]
	var result: Dictionary = REDUCER.chord(board, 1, "tx-chord-explode")
	assert_true(result.get("ok", false), JSON.stringify(result))
	var updated: Dictionary = result["value"]["board"]
	assert_eq(updated["exploded_index"], 2)
	assert_true(updated["terminal"])
	assert_eq(updated["outcome"], &"exploded")


func test_chord_rejects_a_zero_count_cell() -> void:
	var board: Dictionary = _first_reveal_board()
	var result: Dictionary = REDUCER.chord(board, 0, "tx-chord-zero")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"chord_not_applicable")


# ==== duplicate transaction / stale action ====

func test_duplicate_transaction_id_with_the_same_action_is_idempotent() -> void:
	var board: Dictionary = _first_reveal_board()
	var first_result: Dictionary = REDUCER.reveal(board, 14, "tx-dup")
	var second_result: Dictionary = REDUCER.reveal(first_result["value"]["board"], 14, "tx-dup")
	assert_true(second_result.get("ok", false), JSON.stringify(second_result))
	assert_eq(second_result["value"]["board"], first_result["value"]["board"],
		"replaying the same transaction_id must return the unchanged board, never re-apply it")


func test_duplicate_transaction_id_with_a_different_action_rejects() -> void:
	var board: Dictionary = _first_reveal_board()
	var first_result: Dictionary = REDUCER.reveal(board, 14, "tx-reused")
	var conflicting: Dictionary = REDUCER.reveal(first_result["value"]["board"], 15, "tx-reused")
	assert_false(conflicting.get("ok", true))
	assert_eq(conflicting.get("code"), &"transaction_id_reused")


func test_stale_action_on_a_terminal_board_rejects() -> void:
	var board: Dictionary = _first_reveal_board()
	var exploded: Dictionary = REDUCER.reveal(board, 10, "tx-explode")["value"]["board"]
	var stale_reveal: Dictionary = REDUCER.reveal(exploded, 14, "tx-after-explosion")
	assert_false(stale_reveal.get("ok", true))
	assert_eq(stale_reveal.get("code"), &"board_terminal")
	var stale_flag: Dictionary = REDUCER.set_flag(exploded, 6, true, "tx-flag-after-explosion")
	assert_false(stale_flag.get("ok", true))
	assert_eq(stale_flag.get("code"), &"board_terminal")


# ==== exact round-trip ====

func test_board_round_trips_exactly_through_json() -> void:
	var board: Dictionary = _first_reveal_board()
	board = REDUCER.reveal(board, 14, "tx-round-trip")["value"]["board"]
	var stringified: String = JSON.stringify(board)
	var round_tripped: Dictionary = JSON.parse_string(stringified)
	var original_validated: Dictionary = SCHEMA.validate_board(board)
	var round_tripped_validated: Dictionary = SCHEMA.validate_board(round_tripped)
	assert_true(original_validated.get("ok", false), JSON.stringify(original_validated))
	assert_true(round_tripped_validated.get("ok", false), JSON.stringify(round_tripped_validated))
	# JSON has no int/float distinction, so a round-tripped Dictionary's whole numbers come back
	# as TYPE_FLOAT; validate_board() accepts that (see _is_int_like()) but does not itself
	# re-canonicalize the values, so compare the semantic (int-cast) content here.
	assert_eq(_as_int_array(round_tripped_validated["value"]["board"]["revealed_indices"]),
		_as_int_array(original_validated["value"]["board"]["revealed_indices"]))
	assert_eq(_as_int_array(round_tripped_validated["value"]["board"]["adjacency_counts"]),
		_as_int_array(original_validated["value"]["board"]["adjacency_counts"]))


# ==== helpers ====

func _first_reveal_board() -> Dictionary:
	var result: Dictionary = REDUCER.first_reveal(LAYOUT_4X4, 4)
	return result["value"]["board"]


func _as_int_array(source: Array) -> Array[int]:
	var result: Array[int] = []
	for entry: Variant in source:
		result.append(int(entry))
	return result
