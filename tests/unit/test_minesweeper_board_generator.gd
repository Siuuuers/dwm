extends "res://addons/gut/test.gd"

# MinesweeperBoardGenerator / MinesweeperPreparationState suite (Plan 02 Task 4, dwm-p2r13).
#
# All four MinesweeperBoardGenerator functions are implemented. begin_debug()/run_debug_slice()
# depend on the two generated manifests; while those are absent, both correctly return
# generator_budget_unavailable before any runtime RNG draw (never a substituted default budget) --
# see task-4-report.md for the Phase 1/Phase 2 history. Once the manifests exist, the corresponding
# integration tests below exercise them against the real frozen data.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")
const PREPARATION := preload("res://scripts/domain/minesweeper/MinesweeperPreparationState.gd")
const KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
const RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")


# ---- Step 4.1 parse proof ----

func test_generator_and_preparation_scripts_load() -> void:
	for path: String in [
		"res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd",
		"res://scripts/domain/minesweeper/MinesweeperPreparationState.gd",
	]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "%s must load" % path)


# ---- shared BoardSpec / kernel-spec builders ----

func _board_spec(width: int, height: int, base_mine_count: int, pressure: int, penalty: int,
		capability_ids: Array[String], nonce_suffix: String, board_kind: String = "solo_challenge") -> Dictionary:
	var raw_extra: int = floori(float(pressure) / 3.0) + penalty
	return {
		"schema_version": 1, "board_kind": board_kind, "board_token": "token-" + nonce_suffix,
		"board_token_receipt_id": "receipt-token-" + nonce_suffix, "difficulty_id": "bg_test",
		"width": width, "height": height, "base_mine_count": base_mine_count,
		"pressure": pressure, "penalty_points_today": penalty, "raw_extra_mines": raw_extra,
		"requested_mine_count": base_mine_count + raw_extra, "capability_ids": capability_ids,
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "bg-placement-" + nonce_suffix,
		"placement_nonce_receipt_id": "receipt-placement-" + nonce_suffix,
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "bg-debug-" + nonce_suffix,
		"debug_nonce_receipt_id": "receipt-debug-" + nonce_suffix,
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "bg-explosion-" + nonce_suffix,
		"explosion_nonce_receipt_id": "receipt-explosion-" + nonce_suffix,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}


# ---- materialize_first_reveal(): validation ----

func test_materialize_first_reveal_rejects_malformed_spec() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "malformed")
	spec.erase("board_token")
	var result: Dictionary = GENERATOR.materialize_first_reveal(spec, 12)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"spec_member_set_invalid")


func test_materialize_first_reveal_rejects_out_of_range_first_cell() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "oob")
	var result: Dictionary = GENERATOR.materialize_first_reveal(spec, 99)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"cell_index_out_of_range")


# ---- materialize_first_reveal(): happy path ----

func test_materialize_first_reveal_never_places_a_mine_on_first_cell_and_reveals_it() -> void:
	var spec := _board_spec(6, 6, 4, 0, 0, ["first_cell_safe"], "happy-path")
	var result: Dictionary = GENERATOR.materialize_first_reveal(spec, 14)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var layout: Dictionary = value["layout"]
	assert_false((layout["mine_indices"] as Array).has(14))
	assert_eq(layout["mine_count"], 4)
	var board: Dictionary = value["board"]
	assert_true((board["revealed_indices"] as Array).has(14))
	assert_eq(value["mine_dispositions"].size(), 4)
	for entry: Variant in (value["mine_dispositions"] as Array):
		assert_true(["hatred", "upset", "amused"].has(String(entry)))


func test_materialize_first_reveal_reduces_extras_only_when_insufficient_capacity() -> void:
	# 4x4 board, first_cell_zero, forced corner (3 neighbors excluded) -> available=12, base=1,
	# pressure/penalty drive raw_extra_mines high enough that requested_mine_count would want more
	# extras than fit outside the exclusions.
	var spec := _board_spec(4, 4, 1, 42, 0, ["first_cell_safe", "first_cell_zero"], "extras-reduction")
	# raw_extra_mines = floor(42/3) = 14; requested_mine_count = 1+14 = 15 (the schema-valid ceiling).
	assert_eq(spec["requested_mine_count"], 15)
	var result: Dictionary = GENERATOR.materialize_first_reveal(spec, 0)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var layout: Dictionary = (result["value"] as Dictionary)["layout"]
	assert_eq(layout["mine_count"], 12, "1 base + 11 available extra (12 available - 1 base)")


func test_materialize_first_reveal_is_deterministic_for_the_same_spec_and_cell() -> void:
	var spec := _board_spec(6, 6, 4, 0, 0, ["first_cell_safe"], "determinism")
	var a: Dictionary = GENERATOR.materialize_first_reveal(spec, 14)
	var b: Dictionary = GENERATOR.materialize_first_reveal(spec, 14)
	assert_eq(a, b)


# ---- begin_debug() / run_debug_slice(): schema validators and absent-manifest law ----

func _hex64(seed: String) -> String:
	return seed.sha256_text()


func _valid_budget_fixture() -> Dictionary:
	return {
		"schema_version": 1, "benchmark_corpus_sha256": _hex64("corpus"),
		"device_evidence": {
			"declaration": "lowest_target_windows_v1", "os_version": "Windows 11",
			"cpu_model": "Test CPU", "logical_processor_count": 8, "godot_version": "4.6.3.stable.mono",
		},
		"source_sha256": {
			"difficulty_manifest": _hex64("dm"), "rng": _hex64("rng"), "reducer": _hex64("reducer"),
			"kernel": _hex64("kernel"), "verifier": _hex64("verifier"), "tooling_limits": _hex64("tl"),
			"fallback_builder": _hex64("fb"), "fallback_manifest": _hex64("fm"),
			"benchmark_tool": _hex64("bt"), "budget_schema": _hex64("bs"),
		},
		"rows": [{
			"kind": "search", "case_id": "search:beginner:default:000", "difficulty_id": "beginner",
			"capability_ids": ["first_cell_safe"], "nonce_ordinal": 0, "forced_cell": 0,
			"first_cell_zero": false, "candidate_operations": 64, "search_operations": 64,
			"fallback_validation_operations": 0,
		}, {
			"kind": "fallback", "case_id": "fallback:beginner:safe:0", "difficulty_id": "beginner",
			"capability_ids": ["first_cell_safe", "forced_no_guess"], "nonce_ordinal": null,
			"forced_cell": 0, "first_cell_zero": false, "candidate_operations": 0,
			"search_operations": 0, "fallback_validation_operations": 5,
		}],
		"slice_operation_budget": 1024, "search_operation_budget": 2048,
		"reserved_fallback_operation_budget": 512, "hard_operation_budget": 2560,
	}


func _valid_fallback_manifest_fixture() -> Dictionary:
	return {
		"schema_version": 1, "kind": "minesweeper_certified_fallbacks",
		"registry_version": "minesweeper_certified_fallbacks_v1", "generator_version": "dwm_generator_v1",
		"verifier_version": "visible_deduction_v1",
		"records": [{"difficulty_id": "beginner", "forced_cell": 0, "first_cell_zero": false,
			"mine_indices": [1, 2, 3], "mine_count": 3}],
	}


func test_validate_budget_schema_accepts_a_well_formed_fixture() -> void:
	var result: Dictionary = GENERATOR.validate_budget_schema(_valid_budget_fixture())
	assert_true(result.get("ok", false), JSON.stringify(result))


func test_validate_budget_schema_rejects_hard_budget_not_matching_the_exact_sum() -> void:
	var tampered := _valid_budget_fixture()
	tampered["hard_operation_budget"] = 9999
	var result: Dictionary = GENERATOR.validate_budget_schema(tampered)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"budget_formula_invalid")


func test_validate_budget_schema_rejects_a_non_sha256_source_hash() -> void:
	var tampered := _valid_budget_fixture()
	var sources: Dictionary = (tampered["source_sha256"] as Dictionary).duplicate(true)
	sources["kernel"] = "not-a-hash"
	tampered["source_sha256"] = sources
	var result: Dictionary = GENERATOR.validate_budget_schema(tampered)
	assert_false(result.get("ok", true))


func test_validate_budget_schema_rejects_a_search_row_missing_nonce_ordinal() -> void:
	var tampered := _valid_budget_fixture()
	var rows: Array = (tampered["rows"] as Array).duplicate(true)
	var row: Dictionary = (rows[0] as Dictionary).duplicate(true)
	row["nonce_ordinal"] = null
	rows[0] = row
	tampered["rows"] = rows
	var result: Dictionary = GENERATOR.validate_budget_schema(tampered)
	assert_false(result.get("ok", true))


func test_validate_budget_schema_rejects_an_extra_top_level_member() -> void:
	var tampered := _valid_budget_fixture()
	tampered["unexpected"] = 1
	var result: Dictionary = GENERATOR.validate_budget_schema(tampered)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"budget_member_set_invalid")


func test_validate_fallback_schema_accepts_a_well_formed_fixture() -> void:
	var result: Dictionary = GENERATOR.validate_fallback_schema(_valid_fallback_manifest_fixture())
	assert_true(result.get("ok", false), JSON.stringify(result))


func test_validate_fallback_schema_rejects_mine_count_mismatch() -> void:
	var tampered := _valid_fallback_manifest_fixture()
	var records: Array = (tampered["records"] as Array).duplicate(true)
	var record: Dictionary = (records[0] as Dictionary).duplicate(true)
	record["mine_count"] = 99
	records[0] = record
	tampered["records"] = records
	var result: Dictionary = GENERATOR.validate_fallback_schema(tampered)
	assert_false(result.get("ok", true))


func test_validate_fallback_schema_rejects_wrong_kind() -> void:
	var tampered := _valid_fallback_manifest_fixture()
	tampered["kind"] = "something_else"
	var result: Dictionary = GENERATOR.validate_fallback_schema(tampered)
	assert_false(result.get("ok", true))


func test_begin_debug_returns_generator_budget_unavailable_while_the_budget_manifest_is_absent() -> void:
	if FileAccess.file_exists(GENERATOR.BUDGET_MANIFEST_PATH):
		pending("this proof only applies while the generated budget manifest is absent")
		return
	var result: Dictionary = GENERATOR.begin_debug({})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"generator_budget_unavailable")


func test_run_debug_slice_returns_generator_budget_unavailable_while_the_budget_manifest_is_absent() -> void:
	if FileAccess.file_exists(GENERATOR.BUDGET_MANIFEST_PATH):
		pending("this proof only applies while the generated budget manifest is absent")
		return
	var result: Dictionary = GENERATOR.run_debug_slice({})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"generator_budget_unavailable")


# ---- validate_prepared(): drives a real kernel search, then re-validates its projection ----

func _kernel_spec_from_board_spec(board_spec: Dictionary) -> Dictionary:
	var projected: Dictionary = {}
	for key: String in KERNEL.SPEC_KEYS:
		projected[key] = board_spec[key]
	return projected


func _rng_state(stream_id: StringName, nonce: String) -> Dictionary:
	var rng := RNG.new()
	rng.seed(stream_id, nonce)
	return rng.capture()["value"]


func _certified_preparation(board_spec: Dictionary, forced_cell: int) -> Dictionary:
	var kernel_spec := _kernel_spec_from_board_spec(board_spec)
	var placement := _rng_state(StringName(kernel_spec["placement_stream_id"]), String(kernel_spec["placement_nonce"]))
	var debug := _rng_state(StringName(kernel_spec["debug_stream_id"]), String(kernel_spec["debug_nonce"]))
	var explosion := _rng_state(StringName(kernel_spec["explosion_stream_id"]), String(kernel_spec["explosion_nonce"]))
	var begun: Dictionary = KERNEL.begin(kernel_spec, forced_cell, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var total_cells: int = int(kernel_spec["width"]) * int(kernel_spec["height"])
	var slices := 0
	while frontier["status"] == KERNEL.STATUS_SEARCHING:
		var advanced: Dictionary = KERNEL.advance(frontier, total_cells)
		assert_true(advanced.get("ok", false), JSON.stringify(advanced))
		frontier = (advanced["value"] as Dictionary)["preparation"]
		slices += 1
		assert_lt(slices, 2000, "bounded tiny-board search must terminate")
	assert_eq(frontier["status"], KERNEL.STATUS_CERTIFIED)
	return frontier


func test_validate_prepared_accepts_a_correctly_projected_certified_preparation() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "validate-happy")
	var preparation := _certified_preparation(spec, 12)
	var result: Dictionary = GENERATOR.validate_prepared(preparation, spec)
	assert_true(result.get("ok", false), JSON.stringify(result))


func test_validate_prepared_rejects_a_non_certified_preparation() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "validate-not-certified")
	var kernel_spec := _kernel_spec_from_board_spec(spec)
	var placement := _rng_state(StringName(kernel_spec["placement_stream_id"]), String(kernel_spec["placement_nonce"]))
	var debug := _rng_state(StringName(kernel_spec["debug_stream_id"]), String(kernel_spec["debug_nonce"]))
	var explosion := _rng_state(StringName(kernel_spec["explosion_stream_id"]), String(kernel_spec["explosion_nonce"]))
	var begun: Dictionary = KERNEL.begin(kernel_spec, 12, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var result: Dictionary = GENERATOR.validate_prepared(frontier, spec)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"preparation_not_certified")


func test_validate_prepared_rejects_a_tampered_kernel_spec_projection() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "validate-tampered")
	var preparation := _certified_preparation(spec, 12)
	var tampered: Dictionary = preparation.duplicate(true)
	var tampered_spec: Dictionary = (tampered["spec"] as Dictionary).duplicate(true)
	# Tamper a field MinesweeperPreparationState.validate() does not itself cross-check (unlike the
	# nonce/stream_id fields, which its own rng-state-vs-spec matching would already catch), so this
	# proves validate_prepared()'s OWN projection-equality check is independently load-bearing.
	tampered_spec["difficulty_id"] = "a-different-difficulty"
	tampered["spec"] = tampered_spec
	var result: Dictionary = GENERATOR.validate_prepared(tampered, spec)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"preparation_spec_projection_mismatch")


# ---- MinesweeperPreparationState ----

func test_preparation_state_make_matches_kernel_begin() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "state-make")
	var kernel_spec := _kernel_spec_from_board_spec(spec)
	var placement := _rng_state(StringName(kernel_spec["placement_stream_id"]), String(kernel_spec["placement_nonce"]))
	var debug := _rng_state(StringName(kernel_spec["debug_stream_id"]), String(kernel_spec["debug_nonce"]))
	var explosion := _rng_state(StringName(kernel_spec["explosion_stream_id"]), String(kernel_spec["explosion_nonce"]))
	var made: Dictionary = PREPARATION.make(kernel_spec, 12, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	var begun: Dictionary = KERNEL.begin(kernel_spec, 12, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	assert_eq(made, begun)


func test_preparation_state_validate_rejects_wrong_member_set() -> void:
	var result: Dictionary = PREPARATION.validate({"status": KERNEL.STATUS_SEARCHING})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"preparation_member_set_invalid")


func test_preparation_state_validate_rejects_rng_state_belonging_to_a_different_nonce() -> void:
	var spec := _board_spec(5, 5, 3, 0, 0, ["first_cell_safe"], "state-nonce-mismatch")
	var kernel_spec := _kernel_spec_from_board_spec(spec)
	var placement := _rng_state(StringName(kernel_spec["placement_stream_id"]), String(kernel_spec["placement_nonce"]))
	var debug := _rng_state(StringName(kernel_spec["debug_stream_id"]), String(kernel_spec["debug_nonce"]))
	var explosion := _rng_state(StringName(kernel_spec["explosion_stream_id"]), String(kernel_spec["explosion_nonce"]))
	var begun: Dictionary = KERNEL.begin(kernel_spec, 12, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var forged: Dictionary = frontier.duplicate(true)
	var forged_placement: Dictionary = (forged["placement_rng_state"] as Dictionary).duplicate(true)
	forged_placement["nonce"] = "a-different-nonce"
	forged["placement_rng_state"] = forged_placement
	var result: Dictionary = PREPARATION.validate(forged)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"preparation_rng_state_nonce_mismatch")


func test_preparation_state_advance_accepts_a_real_kernel_slice_result() -> void:
	var spec := _board_spec(6, 6, 4, 0, 0, ["first_cell_safe"], "state-advance-happy")
	var kernel_spec := _kernel_spec_from_board_spec(spec)
	var placement := _rng_state(StringName(kernel_spec["placement_stream_id"]), String(kernel_spec["placement_nonce"]))
	var debug := _rng_state(StringName(kernel_spec["debug_stream_id"]), String(kernel_spec["debug_nonce"]))
	var explosion := _rng_state(StringName(kernel_spec["explosion_stream_id"]), String(kernel_spec["explosion_nonce"]))
	var begun: Dictionary = KERNEL.begin(kernel_spec, 12, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var slice_result: Dictionary = KERNEL.advance(frontier, 36)
	var result: Dictionary = PREPARATION.advance(frontier, slice_result)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq((result["value"] as Dictionary)["preparation"], (slice_result["value"] as Dictionary)["preparation"])


func test_preparation_state_advance_rejects_a_slice_result_with_a_drifted_spec() -> void:
	var spec := _board_spec(6, 6, 4, 0, 0, ["first_cell_safe"], "state-advance-drift")
	var kernel_spec := _kernel_spec_from_board_spec(spec)
	var placement := _rng_state(StringName(kernel_spec["placement_stream_id"]), String(kernel_spec["placement_nonce"]))
	var debug := _rng_state(StringName(kernel_spec["debug_stream_id"]), String(kernel_spec["debug_nonce"]))
	var explosion := _rng_state(StringName(kernel_spec["explosion_stream_id"]), String(kernel_spec["explosion_nonce"]))
	var begun: Dictionary = KERNEL.begin(kernel_spec, 12, KERNEL.MODE_CANDIDATE_SEARCH, placement, debug, explosion)
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var slice_result: Dictionary = KERNEL.advance(frontier, 36)
	var tampered_result: Dictionary = slice_result.duplicate(true)
	var tampered_value: Dictionary = (tampered_result["value"] as Dictionary).duplicate(true)
	var tampered_preparation: Dictionary = (tampered_value["preparation"] as Dictionary).duplicate(true)
	var tampered_spec: Dictionary = (tampered_preparation["spec"] as Dictionary).duplicate(true)
	# Tamper a field that keeps the spec independently valid (so the drift check itself is what
	# catches this, not an earlier structural-validity rejection) and untouched by rng-state
	# cross-checking.
	tampered_spec["difficulty_id"] = "a-different-difficulty"
	tampered_preparation["spec"] = tampered_spec
	tampered_value["preparation"] = tampered_preparation
	tampered_result["value"] = tampered_value
	var result: Dictionary = PREPARATION.advance(frontier, tampered_result)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"preparation_spec_drifted")


# ---- begin_debug() / run_debug_slice(): integration against the real frozen manifests ----
# (Task-4 Step 4.6, Phase 2. These self-skip via pending() until both generated manifests exist.)

func _both_generated_manifests_present() -> bool:
	return FileAccess.file_exists(GENERATOR.BUDGET_MANIFEST_PATH) and FileAccess.file_exists(GENERATOR.FALLBACK_MANIFEST_PATH)


func _real_debug_board_spec(nonce_suffix: String) -> Dictionary:
	return {
		"schema_version": 1, "board_kind": "solo_challenge", "board_token": "token-" + nonce_suffix,
		"board_token_receipt_id": "receipt-token-" + nonce_suffix, "difficulty_id": "beginner",
		"width": 8, "height": 8, "base_mine_count": 10, "pressure": 0, "penalty_points_today": 0,
		"raw_extra_mines": 0, "requested_mine_count": 10,
		"capability_ids": ["first_cell_safe", "forced_no_guess"],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "bg-real-placement-" + nonce_suffix,
		"placement_nonce_receipt_id": "receipt-placement-" + nonce_suffix,
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "bg-real-debug-" + nonce_suffix,
		"debug_nonce_receipt_id": "receipt-debug-" + nonce_suffix,
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "bg-real-explosion-" + nonce_suffix,
		"explosion_nonce_receipt_id": "receipt-explosion-" + nonce_suffix,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}


func test_begin_debug_and_run_debug_slice_reach_certified_against_the_real_beginner_difficulty() -> void:
	if not _both_generated_manifests_present():
		pending("requires both generated manifests")
		return
	var spec := _real_debug_board_spec("reach-certified")
	var begun: Dictionary = GENERATOR.begin_debug(spec)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var preparation: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var forced_cell: int = int(preparation["forced_cell"])
	var slices := 0
	while preparation["status"] == KERNEL.STATUS_SEARCHING:
		var stepped: Dictionary = GENERATOR.run_debug_slice(preparation)
		assert_true(stepped.get("ok", false), JSON.stringify(stepped))
		preparation = (stepped["value"] as Dictionary)["preparation"]
		assert_eq(int(preparation["forced_cell"]), forced_cell, "forced_cell must never drift")
		slices += 1
		assert_lt(slices, 5000, "beginner difficulty must certify well within 5000 slices")
	assert_eq(preparation["status"], KERNEL.STATUS_CERTIFIED)
	var candidate: Dictionary = preparation["candidate_state"]
	assert_eq(int(candidate["mine_count"]), 10)
	assert_false((candidate["mine_indices"] as Array).has(forced_cell))
	# A certified preparation must also pass validate_prepared() against the same trusted spec.
	var revalidated: Dictionary = GENERATOR.validate_prepared(preparation, spec)
	assert_true(revalidated.get("ok", false), JSON.stringify(revalidated))


func test_run_debug_slice_falls_back_once_the_search_budget_has_no_room_left() -> void:
	if not _both_generated_manifests_present():
		pending("requires both generated manifests")
		return
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GENERATOR.BUDGET_MANIFEST_PATH))
	var search_budget: int = int(budget["search_operation_budget"])
	var spec := _real_debug_board_spec("force-fallback")
	var begun: Dictionary = GENERATOR.begin_debug(spec)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var preparation: Dictionary = (begun["value"] as Dictionary)["preparation"]
	# Force the search budget to appear exhausted (fewer than total_cells operations of room left),
	# regardless of how quickly this specific forced cell would otherwise certify, to deterministically
	# exercise the fallback path.
	var forced: Dictionary = preparation.duplicate(true)
	forced["operations_used"] = search_budget - 1
	var stepped: Dictionary = GENERATOR.run_debug_slice(forced)
	assert_true(stepped.get("ok", false), JSON.stringify(stepped))
	var next_preparation: Dictionary = (stepped["value"] as Dictionary)["preparation"]
	assert_eq(next_preparation["status"], KERNEL.STATUS_CERTIFIED, "an exhausted search budget must adopt the certified fallback")
	assert_eq(int(next_preparation["forced_cell"]), int(preparation["forced_cell"]))
	var candidate: Dictionary = next_preparation["candidate_state"]
	assert_eq(int(candidate["mine_count"]), 10)
	assert_false((candidate["mine_indices"] as Array).has(int(preparation["forced_cell"])))


func test_run_debug_slice_rejects_once_the_hard_operation_budget_is_already_reached() -> void:
	if not _both_generated_manifests_present():
		pending("requires both generated manifests")
		return
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GENERATOR.BUDGET_MANIFEST_PATH))
	var hard_budget: int = int(budget["hard_operation_budget"])
	var spec := _real_debug_board_spec("hard-budget-exceeded")
	var begun: Dictionary = GENERATOR.begin_debug(spec)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var preparation: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var forced: Dictionary = preparation.duplicate(true)
	forced["operations_used"] = hard_budget
	var result: Dictionary = GENERATOR.run_debug_slice(forced)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"hard_operation_budget_exceeded")


func test_begin_debug_and_run_debug_slice_are_deterministic_for_the_same_spec() -> void:
	if not _both_generated_manifests_present():
		pending("requires both generated manifests")
		return
	var spec := _real_debug_board_spec("determinism")
	var a: Dictionary = GENERATOR.begin_debug(spec)
	var b: Dictionary = GENERATOR.begin_debug(spec)
	assert_eq(a, b)
