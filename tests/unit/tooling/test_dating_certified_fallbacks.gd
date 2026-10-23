extends GutTest
const BUILDER := preload("res://tools/minesweeper/BuildCertifiedFallbacks.gd")
const GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")
const KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
const READER := preload("res://scripts/validation/StrictJson.gd")
const FALLBACK_PATH := "res://data/manifests/minesweeper_certified_fallbacks.v1.json"
const BUDGET_PATH := "res://data/manifests/minesweeper_generator_budget.v1.json"

func test_fixed_edge_band_is_certified_at_edge_and_middle_for_both_real_hosts() -> void:
	for host: String in ["canonical_solo", "canonical_pair"]:
		for zero: bool in [false, true]:
			for forced in [0, 17, 36, 53, 54, 161, 323]:
				var built: Dictionary = BUILDER.build_canonical_record(host, forced, zero)
				assert_true(built.get("ok", false), str(built))
				if not built.get("ok", false): return
				assert_eq(built.value.record.mine_count, 36)
				assert_eq(built.value.record.difficulty_id, host)
				assert_lte(int(built.value.operation_count), 324)
	assert_false(BUILDER.build_canonical_record("expert", 0, false).ok)
	assert_false(BUILDER.build_canonical_record("canonical_solo", 324, false).ok)

func test_artifact_keeps_desktop_prefix_and_has_every_exact_canonical_fallback_key() -> void:
	var read: Dictionary = READER.parse_object(FileAccess.get_file_as_string(FALLBACK_PATH))
	assert_true(read.ok)
	if not read.ok: return
	var records: Array = read.value.records
	assert_eq(records.size(), 1608 + 1296)
	if records.size() != 2904: return
	var expected_keys: Array = []
	var actual_keys: Array = []
	var desktop: Dictionary = BUILDER.read_difficulty_manifest()
	for row: Dictionary in desktop.value.records:
		for zero: bool in [false, true]:
			for forced in range(int(row.width) * int(row.height)):
				expected_keys.append([row.difficulty_id, forced, zero, row.base_mine_count])
	for host: String in ["canonical_solo", "canonical_pair"]:
		for zero: bool in [false, true]:
			for forced in 324: expected_keys.append([host, forced, zero, 36])
	for row: Dictionary in records:
		actual_keys.append([row.difficulty_id, row.forced_cell, row.first_cell_zero, row.mine_count])
	assert_eq(actual_keys, expected_keys, "exact complete ordered coverage; no duplicate or missing host/cell/mode")
	var solo_layouts: Array = []
	var pair_layouts: Array = []
	for ordinal in range(1608, 1608 + 648): solo_layouts.append(records[ordinal].mine_indices)
	for ordinal in range(1608 + 648, 2904): pair_layouts.append(records[ordinal].mine_indices)
	assert_eq(pair_layouts, solo_layouts, "both fixed hosts reuse the exact independently certified layout")

func test_exhausted_runtime_search_adopts_exact_fixed_host_and_reduces_only_extras() -> void:
	var budget_read: Dictionary = READER.parse_object(FileAccess.get_file_as_string(BUDGET_PATH))
	assert_true(budget_read.ok)
	if not budget_read.ok: return
	var budget: Dictionary = budget_read.value
	for host: String in ["canonical_solo", "canonical_pair"]:
		for zero: bool in [false, true]:
			var forced := 81
			var spec: Dictionary = BUILDER._spec_for(host, 18, 18, 36, zero, forced)
			spec.board_kind = "solo_challenge" if host == "canonical_solo" else "pair_challenge"
			spec.capability_ids.append("forced_no_guess")
			spec.raw_extra_mines = 12
			spec.requested_mine_count = 42 if zero else 48
			var placement: Dictionary = BUILDER._rng_capture(&"minesweeper_placement_v1", spec.placement_nonce)
			var debug: Dictionary = BUILDER._rng_capture(&"minesweeper_debug_v1", spec.debug_nonce)
			var explosion: Dictionary = BUILDER._rng_capture(&"minesweeper_explosion_v1", spec.explosion_nonce)
			var begun: Dictionary = KERNEL.begin(spec, forced, KERNEL.MODE_CANDIDATE_SEARCH,
				placement.value, debug.value, explosion.value)
			assert_true(begun.get("ok", false), str(begun))
			if not begun.get("ok", false): return
			var frontier: Dictionary = begun.value.preparation
			frontier.operations_used = int(budget.search_operation_budget)
			var adopted: Dictionary = GENERATOR.run_debug_slice(frontier)
			assert_true(adopted.get("ok", false), str(adopted))
			if not adopted.get("ok", false): return
			var final: Dictionary = adopted.value.preparation
			assert_eq(str(final.status), "certified")
			assert_eq(final.spec, spec)
			assert_eq(final.forced_cell, forced)
			assert_eq(final.candidate_state.mine_count, 36)
			assert_eq(final.candidate_state.mine_indices, BUILDER.build_canonical_record(host, forced, zero).value.record.mine_indices)
			assert_lte(int(final.operations_used), int(budget.hard_operation_budget))
