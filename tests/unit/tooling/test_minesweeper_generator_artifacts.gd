extends "res://addons/gut/test.gd"

# Tooling suite for the bounded certified board generator (Plan 02 Task 4, dwm-p2r13): tooling
# limits, the fallback builder, and the benchmark tool. Exercises only the pure, directly-testable
# helper functions of BuildCertifiedFallbacks.gd/BenchmarkMinesweeperGenerator.gd against tiny
# synthetic boards -- never build_all_records()/run_full_corpus()/_init(), which drive the real
# frozen difficulty manifest and are BLOCKED (see task-4-report.md for the empirically measured
# wall-clock evidence).
#
# PARSE HAZARD: BuildCertifiedFallbacks.gd and BenchmarkMinesweeperGenerator.gd extend SceneTree.
# They are probed with load_script() and NEVER instantiated -- instantiating one would construct a
# SceneTree and execute the tool's _init().

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const TOOLING_LIMITS := preload("res://tools/minesweeper/MinesweeperGeneratorToolingLimits.gd")
const FALLBACK_BUILDER := preload("res://tools/minesweeper/BuildCertifiedFallbacks.gd")
const BENCHMARK := preload("res://tools/minesweeper/BenchmarkMinesweeperGenerator.gd")

const _KERNEL_PATH := "res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd"
const _GENERATOR_PATH := "res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd"
const _TOOLING_LIMITS_PATH := "res://tools/minesweeper/MinesweeperGeneratorToolingLimits.gd"
const _FALLBACK_BUILDER_PATH := "res://tools/minesweeper/BuildCertifiedFallbacks.gd"
const _BENCHMARK_PATH := "res://tools/minesweeper/BenchmarkMinesweeperGenerator.gd"


# ---- Step 4.1 parse proof ----

func test_all_tooling_and_generator_scripts_load() -> void:
	for path: String in [_KERNEL_PATH, _GENERATOR_PATH,
			"res://scripts/domain/minesweeper/MinesweeperPreparationState.gd",
			_TOOLING_LIMITS_PATH, _FALLBACK_BUILDER_PATH, _BENCHMARK_PATH]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "%s must load; RED=%s" % [path, JSON.stringify(loaded)])


func test_tooling_safety_operation_ceiling_is_exactly_frozen() -> void:
	assert_eq(TOOLING_LIMITS.TOOLING_SAFETY_OPERATION_CEILING, 16_777_216)


# ---- static dependency scan (source text, never behavior) ----

func test_runtime_generator_never_imports_tooling_limits_or_the_raw_ceiling_literal() -> void:
	var source: String = FileAccess.get_file_as_string(_GENERATOR_PATH)
	assert_false(source.contains("MinesweeperGeneratorToolingLimits"),
		"MinesweeperBoardGenerator.gd must never import the tooling-limits script")
	assert_false(source.contains("16_777_216") or source.contains("16777216"),
		"MinesweeperBoardGenerator.gd must never hardcode the tooling safety ceiling")


func test_runtime_generator_preloads_the_shared_kernel() -> void:
	var source: String = FileAccess.get_file_as_string(_GENERATOR_PATH)
	assert_true(source.contains("MinesweeperGeneratorKernel.gd"),
		"MinesweeperBoardGenerator.gd must preload the shared kernel")


func test_both_tools_preload_the_shared_kernel() -> void:
	for path: String in [_FALLBACK_BUILDER_PATH, _BENCHMARK_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		assert_true(source.contains("MinesweeperGeneratorKernel.gd"), "%s must preload the shared kernel" % path)


func test_neither_tool_preloads_or_calls_the_runtime_generator() -> void:
	# Checks for the literal resource path a preload()/load() would use, not the bare class name --
	# both tools' doc comments mention MinesweeperBoardGenerator.gd in prose (explaining the
	# boundary), which must not itself be mistaken for a dependency.
	for path: String in [_FALLBACK_BUILDER_PATH, _BENCHMARK_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.contains(_GENERATOR_PATH),
			"%s must never preload or call the runtime generator" % path)


# ---- BuildCertifiedFallbacks: nonce derivation ----

func test_fallback_nonce_matches_the_frozen_sha256_formula() -> void:
	var expected: String = "minesweeper_fallback_v1\nbeginner\n7\n1\nminesweeper_placement_v1".sha256_text()
	var actual: String = FALLBACK_BUILDER.nonce_for("beginner", 7, true, "minesweeper_placement_v1")
	assert_eq(actual, expected)


func test_fallback_nonce_is_domain_separated_by_zero_flag_and_stream_id() -> void:
	var safe_nonce := FALLBACK_BUILDER.nonce_for("beginner", 7, false, "minesweeper_placement_v1")
	var zero_nonce := FALLBACK_BUILDER.nonce_for("beginner", 7, true, "minesweeper_placement_v1")
	var other_stream := FALLBACK_BUILDER.nonce_for("beginner", 7, false, "minesweeper_debug_v1")
	assert_ne(safe_nonce, zero_nonce)
	assert_ne(safe_nonce, other_stream)


# ---- BuildCertifiedFallbacks: argument parsing ----

func test_fallback_builder_parse_arguments_accepts_write_and_check() -> void:
	var write_result: Dictionary = FALLBACK_BUILDER.parse_arguments(PackedStringArray(["--write=res://x.json"]))
	assert_true(write_result.get("ok", false))
	assert_eq((write_result["value"] as Dictionary)["mode"], "write")
	var check_result: Dictionary = FALLBACK_BUILDER.parse_arguments(PackedStringArray(["--check=res://x.json"]))
	assert_true(check_result.get("ok", false))
	assert_eq((check_result["value"] as Dictionary)["mode"], "check")


func test_fallback_builder_parse_arguments_rejects_bare_mode_and_verify_alias_and_both_modes() -> void:
	assert_false(FALLBACK_BUILDER.parse_arguments(PackedStringArray([])).get("ok", true))
	assert_false(FALLBACK_BUILDER.parse_arguments(PackedStringArray(["--write"])).get("ok", true))
	assert_false(FALLBACK_BUILDER.parse_arguments(PackedStringArray(["--verify=res://x.json"])).get("ok", true))
	assert_false(FALLBACK_BUILDER.parse_arguments(
		PackedStringArray(["--write=res://a.json", "--check=res://b.json"])).get("ok", true))


# ---- BuildCertifiedFallbacks: per-cell certification on a tiny synthetic board ----

func test_build_one_record_certifies_a_tiny_board_and_never_mines_the_forced_cell() -> void:
	var built: Dictionary = FALLBACK_BUILDER.build_one_record("tiny", 5, 5, 3, 12, false, 5_000_000)
	assert_true(built.get("ok", false), JSON.stringify(built))
	var record: Dictionary = (built["value"] as Dictionary)["record"]
	assert_eq(record["difficulty_id"], "tiny")
	assert_eq(record["forced_cell"], 12)
	assert_eq(record["first_cell_zero"], false)
	assert_eq(record["mine_count"], 3)
	assert_false((record["mine_indices"] as Array).has(12))


func test_build_one_record_first_cell_zero_yields_a_forced_cell_with_zero_mine_neighbors() -> void:
	var built: Dictionary = FALLBACK_BUILDER.build_one_record("tiny", 5, 5, 2, 12, true, 5_000_000)
	assert_true(built.get("ok", false), JSON.stringify(built))
	var record: Dictionary = (built["value"] as Dictionary)["record"]
	var mine_set: Dictionary = {}
	for m: Variant in (record["mine_indices"] as Array):
		mine_set[int(m)] = true
	for neighbor: int in [6, 7, 8, 11, 13, 16, 17, 18]:
		assert_false(mine_set.has(neighbor))


func test_build_one_record_reports_ceiling_reached_for_an_unreasonably_tiny_ceiling() -> void:
	# ceiling=0 is checked before any candidate is even attempted, so this is deterministic
	# regardless of how quickly this particular board/forced_cell would otherwise certify.
	var built: Dictionary = FALLBACK_BUILDER.build_one_record("tiny", 5, 5, 3, 12, false, 0)
	assert_false(built.get("ok", true))
	assert_eq(built.get("code"), &"tooling_safety_ceiling_reached")


func test_fallback_builder_reads_the_real_frozen_difficulty_manifest_in_order() -> void:
	var read: Dictionary = FALLBACK_BUILDER.read_difficulty_manifest()
	assert_true(read.get("ok", false), JSON.stringify(read))
	var records: Array = (read["value"] as Dictionary)["records"]
	assert_eq(records.size(), 3)
	assert_eq(String((records[0] as Dictionary)["difficulty_id"]), "beginner")
	assert_eq(String((records[1] as Dictionary)["difficulty_id"]), "intermediate")
	assert_eq(String((records[2] as Dictionary)["difficulty_id"]), "expert")


# ---- generated manifests stay absent until their tool steps create them ----

## Both generated manifests are frozen (Task-4 Phase 2 completed the build the earlier BLOCKED
## report describes); this proves they exist and independently pass MinesweeperBoardGenerator's own
## schema validators -- the same gate the runtime relies on before its first RNG draw.
func test_both_generated_manifests_exist_and_pass_their_own_schema_validators() -> void:
	# StrictJson, not the built-in JSON class: JSON.parse_string() has no int/float distinction and
	# would coerce every integer field to a float, tripping the schema validators' strict TYPE_INT
	# checks -- exactly the same reader MinesweeperBoardGenerator itself uses on these files.
	var strict_json := load("res://scripts/validation/StrictJson.gd")
	var generator := load("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")
	assert_true(FileAccess.file_exists("res://data/manifests/minesweeper_certified_fallbacks.v1.json"))
	assert_true(FileAccess.file_exists("res://data/manifests/minesweeper_generator_budget.v1.json"))
	var fallback_parsed: Dictionary = strict_json.parse_object(
		FileAccess.get_file_as_bytes("res://data/manifests/minesweeper_certified_fallbacks.v1.json").get_string_from_utf8())
	assert_true(fallback_parsed.get("ok", false), JSON.stringify(fallback_parsed))
	var fallback: Dictionary = fallback_parsed["value"]
	var fallback_check: Dictionary = generator.validate_fallback_schema(fallback)
	assert_true(fallback_check.get("ok", false), JSON.stringify(fallback_check))
	assert_eq((fallback["records"] as Array).size(), 1608 + 1296)
	var budget_parsed: Dictionary = strict_json.parse_object(
		FileAccess.get_file_as_bytes("res://data/manifests/minesweeper_generator_budget.v1.json").get_string_from_utf8())
	assert_true(budget_parsed.get("ok", false), JSON.stringify(budget_parsed))
	var budget: Dictionary = budget_parsed["value"]
	var budget_check: Dictionary = generator.validate_budget_schema(budget)
	assert_true(budget_check.get("ok", false), JSON.stringify(budget_check))
	assert_true((budget["rows"] as Array).size() in [4680, 4680 + 1296],
		"the original measured desktop corpus or its complete canonical fallback extension")


# ---- BenchmarkMinesweeperGenerator: nonce derivation and case IDs ----

func test_benchmark_nonce_matches_the_frozen_sha256_formula() -> void:
	var capability_ids: Array[String] = ["first_cell_safe", "first_cell_zero"]
	var canonical_capabilities: Dictionary = preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(capability_ids)
	var expected: String = ("minesweeper_benchmark_nonce_v1\nbeginner\n%s\n7\nminesweeper_placement_v1" %
		String(canonical_capabilities["value"])).sha256_text()
	var actual: Dictionary = BENCHMARK.nonce_for("beginner", capability_ids, 7, "minesweeper_placement_v1")
	assert_true(actual.get("ok", false))
	assert_eq(actual["value"], expected)


func test_benchmark_search_and_fallback_case_ids_match_the_frozen_format() -> void:
	assert_eq(BENCHMARK.search_case_id("beginner", "lucky_debug", 7), "search:beginner:lucky_debug:007")
	assert_eq(BENCHMARK.search_case_id("expert", "default", 255), "search:expert:default:255")
	assert_eq(BENCHMARK.fallback_case_id("intermediate", true, 42), "fallback:intermediate:zero:42")
	assert_eq(BENCHMARK.fallback_case_id("intermediate", false, 0), "fallback:intermediate:safe:0")


# ---- BenchmarkMinesweeperGenerator: budget math ----

func test_nearest_rank_p99_matches_the_frozen_formula_for_a_known_series() -> void:
	# n=3072 (the real corpus size): rank = (99*3072+99)/100 = 3042 (integer division) -> zero-based
	# index 3041.
	var values: Array = []
	values.resize(3072)
	for i in range(3072):
		values[i] = i
	var result: Dictionary = BENCHMARK.nearest_rank_p99(values)
	assert_true(result.get("ok", false))
	assert_eq(result["value"], 3041)


func test_nearest_rank_p99_small_series() -> void:
	var result: Dictionary = BENCHMARK.nearest_rank_p99([10, 20, 30, 40, 50])
	# rank = (99*5+99)/100 = 594/100 = 5 (integer division) -> zero-based index 4 -> value 50.
	assert_true(result.get("ok", false))
	assert_eq(result["value"], 50)


func test_nearest_rank_p99_rejects_empty_series() -> void:
	assert_false(BENCHMARK.nearest_rank_p99([]).get("ok", true))


func test_ceil_div8_matches_integer_ceiling_division() -> void:
	assert_eq(BENCHMARK.ceil_div8(0), 0)
	assert_eq(BENCHMARK.ceil_div8(1), 1)
	assert_eq(BENCHMARK.ceil_div8(8), 1)
	assert_eq(BENCHMARK.ceil_div8(9), 2)
	assert_eq(BENCHMARK.ceil_div8(484), 61)


func test_next_power_of_two_exact_and_rounded_cases() -> void:
	assert_eq(BENCHMARK.next_power_of_two(1)["value"], 1)
	assert_eq(BENCHMARK.next_power_of_two(2)["value"], 2)
	assert_eq(BENCHMARK.next_power_of_two(3)["value"], 4)
	assert_eq(BENCHMARK.next_power_of_two(1024)["value"], 1024)
	assert_eq(BENCHMARK.next_power_of_two(1025)["value"], 2048)


func test_next_power_of_two_rejects_nonpositive_input() -> void:
	assert_false(BENCHMARK.next_power_of_two(0).get("ok", true))
	assert_false(BENCHMARK.next_power_of_two(-5).get("ok", true))


func test_next_power_of_two_rejects_signed_64_overflow() -> void:
	var result: Dictionary = BENCHMARK.next_power_of_two(9223372036854775807)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"overflow")


func test_slice_operation_budget_floors_at_1024() -> void:
	assert_eq(BENCHMARK.slice_operation_budget(1)["value"], 1024)
	assert_eq(BENCHMARK.slice_operation_budget(484)["value"], 1024)


func test_search_operation_budget_is_next_power_of_two_of_double_the_maximum() -> void:
	assert_eq(BENCHMARK.search_operation_budget(500)["value"], 1024)
	assert_eq(BENCHMARK.search_operation_budget(513)["value"], 2048)


func test_reserved_fallback_operation_budget_is_next_power_of_two_of_max_plus_one() -> void:
	assert_eq(BENCHMARK.reserved_fallback_operation_budget(483)["value"], 512)
	assert_eq(BENCHMARK.reserved_fallback_operation_budget(511)["value"], 512)
	assert_eq(BENCHMARK.reserved_fallback_operation_budget(512)["value"], 1024)


func test_hard_operation_budget_is_the_exact_sum() -> void:
	var search_budget: int = BENCHMARK.search_operation_budget(500)["value"]
	var reserved_budget: int = BENCHMARK.reserved_fallback_operation_budget(400)["value"]
	assert_eq(search_budget, 1024, "search_operation_budget(500) must be next_power_of_two(1000)")
	assert_eq(reserved_budget, 512, "reserved_fallback_operation_budget(400) must be next_power_of_two(401)")
	assert_eq(search_budget + reserved_budget, 1536, "hard_operation_budget is the exact sum")


# ---- BenchmarkMinesweeperGenerator: argument parsing (same law as the fallback builder) ----

func test_benchmark_parse_arguments_accepts_write_and_check_only() -> void:
	assert_true(BENCHMARK.parse_arguments(PackedStringArray(["--write=res://x.json"])).get("ok", false))
	assert_true(BENCHMARK.parse_arguments(PackedStringArray(["--check=res://x.json"])).get("ok", false))
	assert_false(BENCHMARK.parse_arguments(PackedStringArray(["--verify=res://x.json"])).get("ok", true))
	assert_false(BENCHMARK.parse_arguments(PackedStringArray([])).get("ok", true))


# ---- BenchmarkMinesweeperGenerator: search/fallback case measurement on tiny boards ----

func test_run_search_case_default_uses_nonce_ordinal_modulo_cell_count_as_forced_cell() -> void:
	var result: Dictionary = BENCHMARK.run_search_case("tiny", 5, 5, 3, "default", 27, 5_000_000)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var row: Dictionary = result["value"]
	assert_eq(row["forced_cell"], 27 % 25)
	assert_eq(row["first_cell_zero"], false)
	assert_eq(row["candidate_operations"], 25)
	assert_true(int(row["search_operations"]) >= 25)
	assert_eq(row["fallback_validation_operations"], 0)
	assert_eq(row["case_id"], "search:tiny:default:027")


func test_run_search_case_debug_draws_forced_cell_from_the_debug_stream() -> void:
	var result: Dictionary = BENCHMARK.run_search_case("tiny", 5, 5, 3, "debug", 3, 5_000_000)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var row: Dictionary = result["value"]
	assert_true(int(row["forced_cell"]) >= 0 and int(row["forced_cell"]) < 25)
	assert_eq(row["capability_ids"], ["first_cell_safe", "forced_no_guess"])


func test_run_search_case_lucky_capability_ids_include_first_cell_zero() -> void:
	var result: Dictionary = BENCHMARK.run_search_case("tiny", 5, 5, 2, "lucky", 1, 5_000_000)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq((result["value"] as Dictionary)["capability_ids"], ["first_cell_safe", "first_cell_zero"])
	assert_eq((result["value"] as Dictionary)["first_cell_zero"], true)


func test_run_search_case_reports_ceiling_reached_for_an_unreasonably_tiny_ceiling() -> void:
	# ceiling=0 is checked before any candidate is even attempted, so this is deterministic
	# regardless of how quickly this particular board/forced_cell would otherwise certify.
	var result: Dictionary = BENCHMARK.run_search_case("tiny", 5, 5, 3, "default", 0, 0)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"tooling_safety_ceiling_reached")


func test_run_fallback_case_measures_a_single_cheap_verifier_call() -> void:
	var built: Dictionary = FALLBACK_BUILDER.build_one_record("tiny", 5, 5, 3, 12, false, 5_000_000)
	assert_true(built.get("ok", false), JSON.stringify(built))
	var record: Dictionary = (built["value"] as Dictionary)["record"]
	var result: Dictionary = BENCHMARK.run_fallback_case("tiny", 5, 5, 12, false, record["mine_indices"])
	assert_true(result.get("ok", false), JSON.stringify(result))
	var row: Dictionary = result["value"]
	assert_eq(row["search_operations"], 0)
	assert_eq(row["candidate_operations"], 0)
	assert_true(int(row["fallback_validation_operations"]) > 0)
	assert_eq(row["case_id"], "fallback:tiny:safe:12")
	assert_eq(row["nonce_ordinal"], null)


# ---- benchmark_corpus_sha256 / row_projection ----

func test_row_projection_has_exactly_the_seven_frozen_input_fields() -> void:
	var projection: Dictionary = BENCHMARK.row_projection("search", "search:tiny:default:000", "tiny",
		["first_cell_safe"], 0, 5, false)
	assert_eq(projection.keys(), ["kind", "case_id", "difficulty_id", "capability_ids", "nonce_ordinal",
		"forced_cell", "first_cell_zero"])


func test_corpus_sha256_is_deterministic_and_order_sensitive() -> void:
	var a := [BENCHMARK.row_projection("search", "a", "tiny", ["first_cell_safe"], 0, 0, false)]
	var b := [BENCHMARK.row_projection("search", "a", "tiny", ["first_cell_safe"], 0, 0, false)]
	assert_eq(BENCHMARK.corpus_sha256(a)["value"], BENCHMARK.corpus_sha256(b)["value"])
	var reordered := [BENCHMARK.row_projection("search", "b", "tiny", ["first_cell_safe"], 1, 0, false),
		BENCHMARK.row_projection("search", "a", "tiny", ["first_cell_safe"], 0, 0, false)]
	assert_ne(BENCHMARK.corpus_sha256(a + [reordered[0]])["value"], BENCHMARK.corpus_sha256([reordered[0]] + a)["value"])
