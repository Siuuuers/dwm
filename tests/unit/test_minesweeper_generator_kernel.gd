extends "res://addons/gut/test.gd"

# MinesweeperGeneratorKernel suite (Plan 02 Task 4, dwm-p2r13). All test boards are tiny (<=36
# cells) so the suite runs fast; realistic-scale (beginner/intermediate/expert) behavior is proven
# empirically in task-4-report.md via a throwaway calibration probe (deleted before commit), not by
# iterating every cell of every real difficulty inside this GUT suite.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
const RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")

const FIXTURE_PATH := "res://tests/fixtures/minesweeper/generator_cases.v1.json"

var _fixture: Dictionary


func before_each() -> void:
	_fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))


# ---- Step 4.1 parse proof ----

func test_kernel_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
	assert_true(loaded.get("ok", false), "MinesweeperGeneratorKernel.gd must load")


# ---- shared spec/state builders ----

func _spec(width: int, height: int, base_mine_count: int, raw_extra_mines: int, requested_mine_count: int,
		capability_ids: Array[String], nonce_suffix: String, board_kind: String = "solo_challenge") -> Dictionary:
	return {
		"schema_version": 1, "board_kind": board_kind, "difficulty_id": "kernel_test",
		"width": width, "height": height, "base_mine_count": base_mine_count,
		"raw_extra_mines": raw_extra_mines, "requested_mine_count": requested_mine_count,
		"capability_ids": capability_ids,
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "kt-placement-" + nonce_suffix,
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "kt-debug-" + nonce_suffix,
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "kt-explosion-" + nonce_suffix,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}


func _rng_state(stream_id: StringName, nonce: String) -> Dictionary:
	var rng := RNG.new()
	rng.seed(stream_id, nonce)
	return rng.capture()["value"]


func _fresh_states(spec: Dictionary) -> Dictionary:
	return {
		"placement": _rng_state(StringName(spec["placement_stream_id"]), String(spec["placement_nonce"])),
		"debug": _rng_state(StringName(spec["debug_stream_id"]), String(spec["debug_nonce"])),
		"explosion": _rng_state(StringName(spec["explosion_stream_id"]), String(spec["explosion_nonce"])),
	}


func _begin(spec: Dictionary, forced_cell: int, mode: StringName) -> Dictionary:
	var states := _fresh_states(spec)
	return KERNEL.begin(spec, forced_cell, mode, states["placement"], states["debug"], states["explosion"])


# ---- begin(): spec/mode/forced_cell validation ----

func test_begin_rejects_missing_spec_member() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "missing-member")
	spec.erase("raw_extra_mines")
	var result: Dictionary = KERNEL.begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH, {}, {}, {})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"spec_member_set_invalid")


func test_begin_rejects_extra_spec_member() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "extra-member")
	spec["unexpected"] = 1
	var result: Dictionary = KERNEL.begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH, {}, {}, {})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"spec_member_set_invalid")


func test_begin_rejects_unknown_mode() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "unknown-mode")
	var states := _fresh_states(spec)
	var result: Dictionary = KERNEL.begin(spec, 0, &"guessing", states["placement"], states["debug"], states["explosion"])
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"invalid_mode")


func test_begin_rejects_out_of_range_forced_cell() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "oob-forced")
	var result := _begin(spec, 25, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"cell_index_out_of_range")


func test_begin_rejects_invalid_board_kind() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "bad-kind", "not_a_kind")
	var result := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"spec_field_invalid")


func test_begin_base_count_impossibility_fails() -> void:
	# 3x3 board, forced_cell=4 (center) with first_cell_zero excludes all 8 neighbors too, leaving
	# zero available cells for base_mine_count=1.
	var spec := _spec(3, 3, 1, 0, 1, ["first_cell_safe", "first_cell_zero"], "base-impossible")
	var result := _begin(spec, 4, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"base_mine_count_infeasible")


# ---- begin(): success shape ----

func test_begin_returns_exact_frontier_shape_and_status_searching() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "shape")
	var result := _begin(spec, 12, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var frontier: Dictionary = (result["value"] as Dictionary)["preparation"]
	assert_eq(frontier.keys(), KERNEL.FRONTIER_KEYS)
	assert_eq(frontier["status"], KERNEL.STATUS_SEARCHING)
	assert_eq(frontier["forced_cell"], 12)
	assert_eq(frontier["candidate_ordinal"], 0)
	assert_eq(frontier["operations_used"], 0)
	assert_eq(frontier["slice_sequence"], 0)
	assert_null(frontier["candidate_state"])
	assert_null(frontier["last_failure_code"])


func test_begin_insufficient_extra_capacity_clamps_effective_max_extra() -> void:
	# Without first_cell_zero, available_cells always equals exactly width*height-1, which is also
	# validate_spec's own ceiling on requested_mine_count -- so extras can never structurally
	# overflow. first_cell_zero shrinks available_cells further (excluding neighbors too), which is
	# the only way to observe real clamping: 4x4=16 cells, forced_cell=0 (a corner, 3 neighbors),
	# excluded={0,1,4,5}, available=12, base=1 -> max_fit_extra=11, strictly less than the requested
	# extras of 14.
	var spec := _spec(4, 4, 1, 14, 15, ["first_cell_safe", "first_cell_zero"], "insufficient-extra")
	var result := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var frontier: Dictionary = (result["value"] as Dictionary)["preparation"]
	assert_eq(frontier["extra_tier"], 11, "extra_tier must clamp to the structurally available maximum")


func test_begin_odd_extras_effective_max_extra_matches_requested() -> void:
	var spec := _spec(6, 6, 2, 5, 7, ["first_cell_safe"], "odd-extras")
	var result := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var frontier: Dictionary = (result["value"] as Dictionary)["preparation"]
	assert_eq(frontier["extra_tier"], 5)


# ---- advance(): input validation ----

func test_advance_rejects_nonpositive_operation_limit() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "nonpositive-limit")
	var begun := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	assert_false(KERNEL.advance(frontier, 0).get("ok", true))
	assert_false(KERNEL.advance(frontier, -1).get("ok", true))


func test_advance_rejects_malformed_frontier_shape() -> void:
	var result: Dictionary = KERNEL.advance({"status": KERNEL.STATUS_SEARCHING}, 100)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"frontier_member_set_invalid")


func test_advance_rejects_non_searching_frontier() -> void:
	var spec := _spec(5, 5, 3, 0, 3, ["first_cell_safe"], "non-searching")
	var begun := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var certified := _run_to_conclusion(frontier, 25, 500)
	assert_eq(certified["status"], KERNEL.STATUS_CERTIFIED, "5x5/3 should certify quickly")
	var result: Dictionary = KERNEL.advance(certified, 100)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"frontier_not_searching")


# ---- advance(): exact per-candidate operation accounting ----

func test_advance_operations_used_equals_candidate_ordinal_times_total_cells() -> void:
	var spec := _spec(4, 4, 6, 0, 6, ["first_cell_safe"], "op-accounting")
	var begun := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var total_cells := 16
	for _i in range(5):
		if frontier["status"] != KERNEL.STATUS_SEARCHING:
			break
		var advanced: Dictionary = KERNEL.advance(frontier, total_cells * 3)
		assert_true(advanced.get("ok", false), JSON.stringify(advanced))
		frontier = (advanced["value"] as Dictionary)["preparation"]
		assert_eq(int(frontier["operations_used"]), int(frontier["candidate_ordinal"]) * total_cells,
			"operations_used must equal candidate_ordinal*total_cells exactly")


# ---- extras descent: full-to-zero order, one candidate per call ----

func test_extra_tier_descends_by_one_per_failed_candidate_and_wraps_to_max() -> void:
	# Dense 4x4 board (base=1, extras up to 5 -> up to 6/15 mines, ~40% density) with exactly one
	# candidate tried per advance() call (operation_limit == total_cells), so extra_tier's sequence
	# is directly observable call-by-call for as long as the frontier keeps searching. The descent
	# invariant (each step is either previous-1, or a wrap back to the effective max exactly when
	# the previous tier was 0) is checked unconditionally; whether this particular random search
	# happens to certify before reaching tier 0 is not asserted either way, since that depends on
	# the specific candidates drawn.
	var spec := _spec(4, 4, 1, 5, 6, ["first_cell_safe"], "extra-descent")
	var begun := _begin(spec, 0, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	assert_eq(frontier["extra_tier"], 5)
	var total_cells := 16
	var previous_tier: int = int(frontier["extra_tier"])
	var observed_wrap := false
	for _i in range(400):
		if frontier["status"] != KERNEL.STATUS_SEARCHING:
			break
		var advanced: Dictionary = KERNEL.advance(frontier, total_cells)
		assert_true(advanced.get("ok", false), JSON.stringify(advanced))
		frontier = (advanced["value"] as Dictionary)["preparation"]
		if frontier["status"] != KERNEL.STATUS_SEARCHING:
			break
		var tier: int = int(frontier["extra_tier"])
		if previous_tier == 0:
			assert_eq(tier, 5, "after tier 0 fails the search must wrap back to the effective max")
			observed_wrap = true
		else:
			assert_eq(tier, previous_tier - 1, "extra_tier must descend by exactly one after a failed candidate")
		previous_tier = tier
	gut.p("extra_tier wrap observed within 400 candidates: %s" % observed_wrap)


# ---- determinism: same-seed byte equality ----

func test_begin_is_byte_identical_for_the_same_inputs() -> void:
	var spec := _spec(6, 6, 4, 2, 6, ["first_cell_safe"], "same-seed")
	var a := _begin(spec, 10, KERNEL.MODE_CANDIDATE_SEARCH)
	var b := _begin(spec, 10, KERNEL.MODE_CANDIDATE_SEARCH)
	assert_eq(a, b)


func test_advance_is_byte_identical_for_equal_frontiers_and_limits() -> void:
	var spec := _spec(6, 6, 4, 2, 6, ["first_cell_safe"], "advance-same-seed")
	var begun := _begin(spec, 10, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var a: Dictionary = KERNEL.advance(frontier.duplicate(true), 36)
	var b: Dictionary = KERNEL.advance(frontier.duplicate(true), 36)
	assert_eq(a, b)


func test_calling_advance_twice_from_the_same_restored_frontier_reproduces_the_same_next_step() -> void:
	var spec := _spec(6, 6, 4, 2, 6, ["first_cell_safe"], "restore-same-step")
	var begun := _begin(spec, 10, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var stepped_once: Dictionary = KERNEL.advance(frontier, 36)
	# "Restore" here means an independently-constructed, deep-equal copy of the frontier (the shape
	# a checkpoint/reload path would hand back) -- not a literal JSON text round-trip, since
	# DeterministicRng32.prepare_restore() requires its state/draw_count fields to stay TYPE_INT and
	# JSON.parse_string() would coerce them to floats.
	var restored_frontier: Dictionary = frontier.duplicate(true)
	var stepped_again: Dictionary = KERNEL.advance(restored_frontier, 36)
	assert_eq((stepped_once["value"] as Dictionary)["preparation"], (stepped_again["value"] as Dictionary)["preparation"])


# ---- RNG stream isolation ----

func test_searching_result_leaves_debug_and_explosion_states_untouched() -> void:
	var spec := _spec(6, 6, 4, 2, 6, ["first_cell_safe"], "stream-isolation")
	var begun := _begin(spec, 10, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var advanced: Dictionary = KERNEL.advance(frontier, 36)
	assert_true(advanced.get("ok", false), JSON.stringify(advanced))
	var next_frontier: Dictionary = (advanced["value"] as Dictionary)["preparation"]
	if next_frontier["status"] == KERNEL.STATUS_SEARCHING:
		assert_eq(next_frontier["debug_rng_state"], frontier["debug_rng_state"],
			"advancing placement/search must never advance the debug stream")
		assert_eq(next_frontier["explosion_rng_state"], frontier["explosion_rng_state"],
			"advancing placement/search must never advance the explosion stream before certification")
		assert_ne(next_frontier["placement_rng_state"], frontier["placement_rng_state"],
			"at least one candidate attempt must have advanced the placement stream")


func test_forced_cell_persists_across_failed_candidates_slices_and_restore() -> void:
	var spec := _spec(4, 4, 1, 5, 6, ["first_cell_safe"], "forced-cell-persist")
	var begun := _begin(spec, 3, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	assert_eq(frontier["forced_cell"], 3)
	var total_cells := 16
	for _i in range(50):
		if frontier["status"] != KERNEL.STATUS_SEARCHING:
			break
		var restored_frontier: Dictionary = frontier.duplicate(true)
		var advanced: Dictionary = KERNEL.advance(restored_frontier, total_cells)
		assert_true(advanced.get("ok", false), JSON.stringify(advanced))
		frontier = (advanced["value"] as Dictionary)["preparation"]
		assert_eq(frontier["forced_cell"], 3, "forced_cell must never drift")


# ---- certification: layout excludes forced cell (and neighbors under first_cell_zero) ----

func test_certified_candidate_never_places_a_mine_on_the_forced_cell() -> void:
	var record: Dictionary = (_fixture["tiny_boards"] as Array)[0]
	var spec := _spec(int(record["width"]), int(record["height"]), int(record["base_mine_count"]), 0,
		int(record["base_mine_count"]), ["first_cell_safe"], "no-mine-on-forced")
	var begun := _begin(spec, int(record["forced_cell"]), KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var final_state := _run_to_conclusion(frontier, int(record["width"]) * int(record["height"]), 2000)
	assert_eq(final_state["status"], KERNEL.STATUS_CERTIFIED, "tiny sparse board should certify")
	var mine_indices: Array = (final_state["candidate_state"] as Dictionary)["mine_indices"]
	assert_false(mine_indices.has(int(record["forced_cell"])))


func test_first_cell_zero_excludes_neighbors_from_the_mine_pool() -> void:
	var spec := _spec(5, 5, 2, 0, 2, ["first_cell_safe", "first_cell_zero"], "zero-mode-exclusion")
	var begun := _begin(spec, 12, KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var final_state := _run_to_conclusion(frontier, 25, 2000)
	assert_eq(final_state["status"], KERNEL.STATUS_CERTIFIED)
	var mine_indices: Array = (final_state["candidate_state"] as Dictionary)["mine_indices"]
	for neighbor: int in [6, 7, 8, 11, 13, 16, 17, 18]:
		assert_false(mine_indices.has(neighbor), "first_cell_zero must exclude every neighbor of the forced cell")


func test_certified_candidate_state_has_one_disposition_per_mine_from_allowed_vocabulary() -> void:
	var record: Dictionary = (_fixture["tiny_boards"] as Array)[0]
	var spec := _spec(int(record["width"]), int(record["height"]), int(record["base_mine_count"]), 0,
		int(record["base_mine_count"]), ["first_cell_safe"], "dispositions")
	var begun := _begin(spec, int(record["forced_cell"]), KERNEL.MODE_CANDIDATE_SEARCH)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var final_state := _run_to_conclusion(frontier, int(record["width"]) * int(record["height"]), 2000)
	assert_eq(final_state["status"], KERNEL.STATUS_CERTIFIED)
	var candidate: Dictionary = final_state["candidate_state"]
	var mine_indices: Array = candidate["mine_indices"]
	var dispositions: Array = candidate["mine_dispositions"]
	assert_eq(dispositions.size(), mine_indices.size())
	for entry: Variant in dispositions:
		assert_true(["hatred", "upset", "amused"].has(String(entry)))


# ---- fallback_construction mode works with both generated manifests absent ----

## The kernel has no file I/O of any kind (see its class doc comment): fallback_construction mode
## works identically whether or not either generated manifest exists on disk, because it never
## reads them. Originally written while both were absent (Task-4 Phase 2 was still BLOCKED); now
## that both exist and are frozen, the same assertion proves the same thing from the other side --
## the kernel's behavior here is unaffected by their presence, exactly as its "no manifest loader,
## no file I/O" law requires.
func test_fallback_construction_mode_has_no_dependency_on_the_generated_manifests() -> void:
	var record: Dictionary = (_fixture["tiny_boards"] as Array)[0]
	var spec := _spec(int(record["width"]), int(record["height"]), int(record["base_mine_count"]), 0,
		int(record["base_mine_count"]), ["first_cell_safe"], "fallback-construction-absent-manifests")
	var begun := _begin(spec, int(record["forced_cell"]), KERNEL.MODE_FALLBACK_CONSTRUCTION)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var final_state := _run_to_conclusion(frontier, int(record["width"]) * int(record["height"]), 2000)
	assert_eq(final_state["status"], KERNEL.STATUS_CERTIFIED)


# ---- is_legal_status() ----

func test_is_legal_status_accepts_only_the_three_frozen_values() -> void:
	assert_true(KERNEL.is_legal_status(&"searching"))
	assert_true(KERNEL.is_legal_status(&"certified"))
	assert_true(KERNEL.is_legal_status(&"exhausted"))
	assert_false(KERNEL.is_legal_status(&"pending"))
	assert_false(KERNEL.is_legal_status(123))
	assert_false(KERNEL.is_legal_status(null))


# ---- shared test helper ----

func _run_to_conclusion(frontier: Dictionary, operation_limit: int, max_slices: int) -> Dictionary:
	var current := frontier
	var slices := 0
	while current["status"] == KERNEL.STATUS_SEARCHING:
		var advanced: Dictionary = KERNEL.advance(current, operation_limit)
		assert_true(advanced.get("ok", false), JSON.stringify(advanced))
		current = (advanced["value"] as Dictionary)["preparation"]
		slices += 1
		assert_lt(slices, max_slices, "bounded tiny-board search must terminate well under the slice cap")
	return current
