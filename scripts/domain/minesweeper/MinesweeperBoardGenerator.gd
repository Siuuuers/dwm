class_name MinesweeperBoardGenerator
extends RefCounted

## The manifest-validating runtime adapter over MinesweeperGeneratorKernel (Plan 02 Task 4,
## dwm-p2r13). This is the ONLY place runtime fallback selection lives: after ordinary kernel
## search exhausts the frozen search_operation_budget, this adapter looks up the exact certified
## fallback manifest key and spends only reserved_fallback_operation_budget revalidating/adopting
## those bytes -- it never passes a fallback into the kernel, never calls fallback_construction,
## never reads the benchmark rows as control input, and has no dependency of any kind (import or
## literal constant) on the tools-only per-request safety ceiling script under tools/minesweeper/
## -- proven by a static source-text scan in tests/unit/tooling/test_minesweeper_generator_artifacts.gd.
##
## All four functions are implemented. Both generated manifests are loaded and validated -- exact
## schema shape, plus a freshness cross-check of the budget manifest's recorded source hashes for
## the files this adapter itself depends on (kernel/verifier/reducer/rng/difficulty-manifest/
## budget-schema/fallback-manifest) -- before the first runtime RNG draw. Missing or invalid data returns
## generator_budget_unavailable; this adapter never substitutes a constant/default budget. The
## three purely-tooling source hashes the budget manifest also records (for the safety-ceiling
## script, the fallback-builder tool, and the benchmark tool) are validated structurally (present,
## correctly-shaped SHA-256 hex) but not independently re-derived here, since doing so would
## require this file to reference the tools-only scripts' own paths -- exactly what the static
## scan above forbids. That freshness proof belongs to the offline tools' own check mode (Task-4
## Steps 4.4/4.5), not this runtime hot path.

const _KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
const _PREPARATION := preload("res://scripts/domain/minesweeper/MinesweeperPreparationState.gd")
const _BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const _REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const _VERIFIER := preload("res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd")
const _RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const _DISPOSITIONS: Array[String] = ["hatred", "upset", "amused"]

const BUDGET_MANIFEST_PATH := "res://data/manifests/minesweeper_generator_budget.v1.json"
const FALLBACK_MANIFEST_PATH := "res://data/manifests/minesweeper_certified_fallbacks.v1.json"
const _DIFFICULTY_MANIFEST_PATH := "res://data/manifests/minesweeper_difficulties.v1.json"
const _BUDGET_SCHEMA_PATH := "res://data/schemas/minesweeper-generator-budget.schema.json"
const _RNG_SOURCE_PATH := "res://scripts/domain/minesweeper/DeterministicRng32.gd"
const _REDUCER_SOURCE_PATH := "res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd"
const _KERNEL_SOURCE_PATH := "res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd"
const _VERIFIER_SOURCE_PATH := "res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd"

const _BUDGET_KEYS := [
	"schema_version", "benchmark_corpus_sha256", "device_evidence", "source_sha256", "rows",
	"slice_operation_budget", "search_operation_budget", "reserved_fallback_operation_budget",
	"hard_operation_budget",
]
const _DEVICE_EVIDENCE_KEYS := ["declaration", "os_version", "cpu_model", "logical_processor_count", "godot_version"]
const _SOURCE_SHA256_KEYS := [
	"difficulty_manifest", "rng", "reducer", "kernel", "verifier", "tooling_limits",
	"fallback_builder", "fallback_manifest", "benchmark_tool", "budget_schema",
]
const _FRESHNESS_CHECKED_SOURCES := {
	"rng": _RNG_SOURCE_PATH, "reducer": _REDUCER_SOURCE_PATH, "kernel": _KERNEL_SOURCE_PATH,
	"verifier": _VERIFIER_SOURCE_PATH, "difficulty_manifest": _DIFFICULTY_MANIFEST_PATH,
	"budget_schema": _BUDGET_SCHEMA_PATH, "fallback_manifest": FALLBACK_MANIFEST_PATH,
}
const _ROW_KEYS := [
	"kind", "case_id", "difficulty_id", "capability_ids", "nonce_ordinal", "forced_cell",
	"first_cell_zero", "candidate_operations", "search_operations", "fallback_validation_operations",
]
const _FALLBACK_MANIFEST_KEYS := [
	"schema_version", "kind", "registry_version", "generator_version", "verifier_version", "records",
]
const _FALLBACK_RECORD_KEYS := ["difficulty_id", "forced_cell", "first_cell_zero", "mine_indices", "mine_count"]


## Default/Lucky: validates the complete trusted BoardSpec, rejection-samples a Fisher-Yates
## candidate order (no search, no verifier call -- Default/Lucky never require no-guess
## certification), reduces extras only when the requested total does not fit outside first_cell
## (and its neighbors, when first_cell_zero is owned), adopts the exact layout, draws the isolated
## explosion-stream mine dispositions, and performs the first reveal, all in one pure result.
static func materialize_first_reveal(spec: Dictionary, first_cell: int) -> Dictionary:
	var spec_check: Dictionary = _BOARD_SCHEMA.validate_spec(spec)
	if not spec_check.get("ok", false):
		return spec_check
	var validated_spec: Dictionary = (spec_check["value"] as Dictionary)["spec"]

	var width: int = int(validated_spec["width"])
	var height: int = int(validated_spec["height"])
	var total_cells: int = width * height
	if typeof(first_cell) != TYPE_INT or first_cell < 0 or first_cell >= total_cells:
		return _fail(&"cell_index_out_of_range", "first_cell is out of range", {"first_cell": first_cell})

	var capability_ids: Array = validated_spec["capability_ids"]
	var zero_mode: bool = capability_ids.has("first_cell_zero")
	var excluded := _KERNEL.excluded_cells(first_cell, zero_mode, width, height)
	var pool: Array[int] = []
	for index in range(total_cells):
		if not excluded.has(index):
			pool.append(index)
	var base_mine_count: int = int(validated_spec["base_mine_count"])
	if base_mine_count > pool.size():
		return _fail(&"base_mine_count_infeasible",
			"base_mine_count does not fit outside the first cell and its exclusions",
			{"base_mine_count": base_mine_count, "available_cells": pool.size()})
	var requested_extra: int = int(validated_spec["requested_mine_count"]) - base_mine_count
	var max_fit_extra: int = pool.size() - base_mine_count
	var effective_extra: int = maxi(mini(requested_extra, max_fit_extra), 0)
	var mine_count: int = base_mine_count + effective_extra

	var placement_seeded := _seed(StringName(validated_spec["placement_stream_id"]), String(validated_spec["placement_nonce"]))
	if not placement_seeded.get("ok", false):
		return placement_seeded
	var placement_rng: RefCounted = placement_seeded["value"]
	var mine_indices: Array[int] = _KERNEL.sample_mine_indices(pool, mine_count, placement_rng)
	mine_indices.sort()

	var layout := {"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices, "mine_count": mine_indices.size()}
	var layout_check: Dictionary = _BOARD_SCHEMA.validate_layout(layout, _requested_count_spec(validated_spec, mine_count))
	if not layout_check.get("ok", false):
		return layout_check

	var explosion_seeded := _seed(StringName(validated_spec["explosion_stream_id"]), String(validated_spec["explosion_nonce"]))
	if not explosion_seeded.get("ok", false):
		return explosion_seeded
	var explosion_rng: RefCounted = explosion_seeded["value"]
	var dispositions: Array[String] = []
	for _i in range(mine_indices.size()):
		var sampled: Dictionary = explosion_rng.sample_bounded(_DISPOSITIONS.size())
		if not sampled.get("ok", false):
			return sampled
		dispositions.append(_DISPOSITIONS[int((sampled["value"] as Dictionary)["result"])])

	var revealed: Dictionary = _REDUCER.first_reveal(layout, first_cell)
	if not revealed.get("ok", false):
		return revealed

	return {"ok": true, "code": &"ok", "value": {
		"layout": layout, "board": (revealed["value"] as Dictionary)["board"],
		"mine_dispositions": dispositions,
		"placement_rng_state": placement_rng.capture()["value"],
		"explosion_rng_state": explosion_rng.capture()["value"],
	}, "receipt": {}}


## Debug: validates the trusted BoardSpec, loads+validates both frozen generated manifests, draws
## the forced cell exactly once from the debug stream, projects the exact GeneratorKernelSpec, and
## begins a candidate_search preparation over the kernel. Returns a searching (or, in the
## degenerate case, already-terminal) preparation; the caller may not commit story-attempt entry
## until MinesweeperPreparationState/run_debug_slice report status=certified.
static func begin_debug(spec: Dictionary) -> Dictionary:
	var budget_loaded := _read_budget_manifest()
	if not budget_loaded.get("ok", false):
		return budget_loaded
	var fallback_loaded := _read_fallback_manifest()
	if not fallback_loaded.get("ok", false):
		return fallback_loaded

	var spec_check: Dictionary = _BOARD_SCHEMA.validate_spec(spec)
	if not spec_check.get("ok", false):
		return spec_check
	var validated_spec: Dictionary = (spec_check["value"] as Dictionary)["spec"]
	var total_cells: int = int(validated_spec["width"]) * int(validated_spec["height"])

	var debug_seeded := _seed(StringName(validated_spec["debug_stream_id"]), String(validated_spec["debug_nonce"]))
	if not debug_seeded.get("ok", false):
		return debug_seeded
	var debug_rng: RefCounted = debug_seeded["value"]
	var drawn: Dictionary = debug_rng.sample_bounded(total_cells)
	if not drawn.get("ok", false):
		return drawn
	var forced_cell: int = int((drawn["value"] as Dictionary)["result"])
	var debug_state: Dictionary = debug_rng.capture()["value"]

	var placement_seeded := _seed(StringName(validated_spec["placement_stream_id"]), String(validated_spec["placement_nonce"]))
	if not placement_seeded.get("ok", false):
		return placement_seeded
	var placement_state: Dictionary = (placement_seeded["value"] as RefCounted).capture()["value"]

	var explosion_seeded := _seed(StringName(validated_spec["explosion_stream_id"]), String(validated_spec["explosion_nonce"]))
	if not explosion_seeded.get("ok", false):
		return explosion_seeded
	var explosion_state: Dictionary = (explosion_seeded["value"] as RefCounted).capture()["value"]

	var kernel_spec := _project_kernel_spec(validated_spec)
	var begun: Dictionary = _KERNEL.begin(kernel_spec, forced_cell, _KERNEL.MODE_CANDIDATE_SEARCH,
		placement_state, debug_state, explosion_state)
	if not begun.get("ok", false):
		return begun
	return _PREPARATION.validate((begun["value"] as Dictionary)["preparation"])


## Advances one bounded slice of an in-progress Debug preparation using slice_operation_budget,
## enforcing cumulative search_operation_budget (the kernel is never offered more of the search
## budget than remains, and is never offered a call so small it could only stall), then falling
## back to the exact certified manifest entry (spending only reserved_fallback_operation_budget on
## one independent verifier revalidation) once search_operation_budget has no room left for even
## one more candidate, and rejecting any path whose total would exceed hard_operation_budget.
static func run_debug_slice(preparation: Dictionary) -> Dictionary:
	var budget_loaded := _read_budget_manifest()
	if not budget_loaded.get("ok", false):
		return budget_loaded
	var budget: Dictionary = budget_loaded["value"]

	var preparation_check: Dictionary = _PREPARATION.validate(preparation)
	if not preparation_check.get("ok", false):
		return preparation_check
	var current: Dictionary = (preparation_check["value"] as Dictionary)["preparation"]
	if StringName(current["status"]) != _KERNEL.STATUS_SEARCHING:
		return _fail(&"preparation_not_searching", "run_debug_slice requires a searching preparation", {})

	var spec: Dictionary = current["spec"]
	var total_cells: int = int(spec["width"]) * int(spec["height"])
	var operations_used: int = int(current["operations_used"])
	var search_budget: int = int(budget["search_operation_budget"])
	var hard_budget: int = int(budget["hard_operation_budget"])
	if operations_used >= hard_budget:
		return _fail(&"hard_operation_budget_exceeded", "cumulative operations already reached the hard budget", {})

	var remaining_search: int = search_budget - operations_used
	if remaining_search >= total_cells:
		var slice_budget: int = int(budget["slice_operation_budget"])
		var call_limit: int = mini(slice_budget, remaining_search)
		var advanced: Dictionary = _KERNEL.advance(current, call_limit)
		if not advanced.get("ok", false):
			return advanced
		return _PREPARATION.advance(current, advanced)

	var fallback_loaded := _read_fallback_manifest()
	if not fallback_loaded.get("ok", false):
		return fallback_loaded
	return _adopt_fallback(current, budget, (fallback_loaded["value"] as Dictionary)["records"])


## Re-validates a certified preparation against the trusted BoardSpec it must have been projected
## from, before the caller may commit it: the full BoardSpec passes its own validation, the
## preparation independently passes MinesweeperPreparationState.validate() and is certified, and
## re-deriving the GeneratorKernelSpec projection from `spec` byte-for-byte matches the
## preparation's own embedded spec (proving production projection never drifts from the trusted
## receipt-bearing source).
static func validate_prepared(candidate: Dictionary, spec: Dictionary) -> Dictionary:
	var spec_check: Dictionary = _BOARD_SCHEMA.validate_spec(spec)
	if not spec_check.get("ok", false):
		return spec_check
	var validated_spec: Dictionary = (spec_check["value"] as Dictionary)["spec"]

	var preparation_check: Dictionary = _PREPARATION.validate(candidate)
	if not preparation_check.get("ok", false):
		return preparation_check
	var preparation: Dictionary = (preparation_check["value"] as Dictionary)["preparation"]
	if StringName(preparation["status"]) != _KERNEL.STATUS_CERTIFIED:
		return _fail(&"preparation_not_certified", "validate_prepared requires a certified preparation", {})

	var expected_projection := _project_kernel_spec(validated_spec)
	if preparation["spec"] != expected_projection:
		return _fail(&"preparation_spec_projection_mismatch",
			"the preparation's kernel spec is not the exact projection of the trusted BoardSpec", {})

	return {"ok": true, "code": &"ok", "value": {"preparation": preparation.duplicate(true)}, "receipt": {}}


# ---- fallback adoption ----

static func _adopt_fallback(current: Dictionary, budget: Dictionary, fallback_records: Array) -> Dictionary:
	var spec: Dictionary = current["spec"]
	var difficulty_id: String = String(spec["difficulty_id"])
	var forced_cell: int = int(current["forced_cell"])
	var capability_ids: Array = spec["capability_ids"]
	var first_cell_zero: bool = capability_ids.has("first_cell_zero")

	var record: Variant = null
	for entry: Variant in fallback_records:
		var candidate_record: Dictionary = entry
		if String(candidate_record["difficulty_id"]) == difficulty_id \
				and int(candidate_record["forced_cell"]) == forced_cell \
				and bool(candidate_record["first_cell_zero"]) == first_cell_zero:
			record = candidate_record
			break
	if record == null:
		return _fail(&"fallback_entry_missing", "no certified fallback entry matches this forced cell",
			{"difficulty_id": difficulty_id, "forced_cell": forced_cell, "first_cell_zero": first_cell_zero})
	var fallback_record: Dictionary = record

	var reserved_budget: int = int(budget["reserved_fallback_operation_budget"])
	var hard_budget: int = int(budget["hard_operation_budget"])
	var operations_used: int = int(current["operations_used"])
	if operations_used + reserved_budget > hard_budget:
		return _fail(&"hard_operation_budget_exceeded",
			"adopting the certified fallback would exceed the hard operation budget", {})

	var width: int = int(spec["width"])
	var height: int = int(spec["height"])
	var mine_indices: Array = fallback_record["mine_indices"]
	var layout := {"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices, "mine_count": mine_indices.size()}
	var revalidated: Dictionary = _VERIFIER.verify(layout, forced_cell, reserved_budget)
	if not revalidated.get("ok", false):
		return _fail(&"fallback_revalidation_failed",
			"the certified fallback entry failed independent revalidation", {"cause": revalidated.get("code", &"")})
	var operation_count: int = int((revalidated["value"] as Dictionary)["operation_count"])

	var explosion_rng: RefCounted = _RNG.new()
	var explosion_seed_result: Dictionary = explosion_rng.seed(
		StringName(spec["explosion_stream_id"]), String(spec["explosion_nonce"]))
	if not explosion_seed_result.get("ok", false):
		return explosion_seed_result
	var explosion_restore: Dictionary = explosion_rng.prepare_restore(current["explosion_rng_state"])
	if not explosion_restore.get("ok", false):
		return explosion_restore
	var dispositions: Array[String] = []
	for _i in range(mine_indices.size()):
		var sampled: Dictionary = explosion_rng.sample_bounded(_DISPOSITIONS.size())
		if not sampled.get("ok", false):
			return sampled
		dispositions.append(_DISPOSITIONS[int((sampled["value"] as Dictionary)["result"])])

	var certified_preparation := {
		"status": _KERNEL.STATUS_CERTIFIED, "mode": current["mode"], "spec": spec,
		"forced_cell": forced_cell, "placement_rng_state": current["placement_rng_state"],
		"debug_rng_state": current["debug_rng_state"],
		"explosion_rng_state": explosion_rng.capture()["value"],
		"extra_tier": current["extra_tier"], "candidate_ordinal": current["candidate_ordinal"],
		"candidate_state": {
			"mine_indices": mine_indices, "mine_count": mine_indices.size(), "mine_dispositions": dispositions,
		},
		"operations_used": operations_used + operation_count,
		"slice_sequence": int(current["slice_sequence"]) + 1, "last_failure_code": current["last_failure_code"],
	}
	var wrapped := {"ok": true, "code": &"ok", "value": {"preparation": certified_preparation}, "receipt": {}}
	return _PREPARATION.advance(current, wrapped)


# ---- generated-manifest loading and validation ----

## Reads, strict-parses, exact-schema-validates, and freshness-cross-checks the frozen budget
## manifest. Returns generator_budget_unavailable (never a substituted default) for anything
## short of a fully valid, fresh manifest -- absence included.
static func _read_budget_manifest() -> Dictionary:
	if not FileAccess.file_exists(BUDGET_MANIFEST_PATH):
		return _fail(&"generator_budget_unavailable", "the generator budget manifest is absent", {})
	var parsed: Dictionary = _STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(BUDGET_MANIFEST_PATH).get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"generator_budget_unavailable", "the generator budget manifest is not strict JSON", {})
	var budget: Dictionary = parsed["value"]
	var schema_check := validate_budget_schema(budget)
	if not schema_check.get("ok", false):
		return _fail(&"generator_budget_unavailable", "the generator budget manifest failed schema validation",
			{"cause": schema_check.get("code", &"")})
	var freshness_check := _validate_budget_freshness(budget)
	if not freshness_check.get("ok", false):
		return _fail(&"generator_budget_unavailable", "the generator budget manifest is stale",
			{"cause": freshness_check.get("code", &"")})
	return {"ok": true, "value": budget}


## Pure structural schema validation of a budget manifest dictionary -- exact member set at every
## level, closed values, and one derived-field cross-check: `hard_operation_budget` must equal
## `search_operation_budget + reserved_fallback_operation_budget`. It does NOT independently
## recompute `slice_operation_budget`/`search_operation_budget`/`reserved_fallback_operation_budget`
## from the rows -- those formulas (percentile/power-of-two math over the benchmark corpus) live
## only in the offline `tools/minesweeper/BenchmarkMinesweeperGenerator.gd`. This adapter does not
## import or otherwise depend on that tool -- every `preload()` at the top of this file names a
## `scripts/` sibling, and the only mention of the tool anywhere in here is this sentence's own
## prose -- but that is an UNGUARDED FACT, not a proven one: no test asserts it. The two static
## scans that do exist in `tests/unit/tooling/test_minesweeper_generator_artifacts.gd` cover
## NEIGHBOURING claims. `test_runtime_generator_never_imports_tooling_limits_or_the_raw_ceiling_literal`
## scans this file for the tools-only per-request safety-ceiling script and its raw ceiling
## constant -- a DIFFERENT file, and the only one this file's class-level doc claims independence
## from -- while `test_neither_tool_preloads_or_calls_the_runtime_generator` scans the benchmark
## tool for a reference back to this file, i.e. the OPPOSITE direction. Nothing scans this file
## for a reference to the benchmark tool.
##
## Nor does it recompute `benchmark_corpus_sha256` from the rows: a hand-edited row is undetectable by this
## check alone unless a bound source file also changes and trips the freshness cross-check.
## Directly testable with a hand-built dictionary, independent of disk.
static func validate_budget_schema(budget: Dictionary) -> Dictionary:
	var shape := _exact_keys(budget, _BUDGET_KEYS, &"budget_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(budget["schema_version"]) != TYPE_INT or int(budget["schema_version"]) != 1:
		return _fail(&"budget_field_invalid", "schema_version must be exactly 1", {})
	if not _is_sha256_hex(budget.get("benchmark_corpus_sha256")):
		return _fail(&"budget_field_invalid", "benchmark_corpus_sha256 must be 64 lowercase hex characters", {})

	var device: Variant = budget["device_evidence"]
	if typeof(device) != TYPE_DICTIONARY:
		return _fail(&"budget_field_invalid", "device_evidence must be an object", {})
	var device_shape := _exact_keys(device, _DEVICE_EVIDENCE_KEYS, &"budget_device_evidence_invalid")
	if not device_shape.get("ok", false):
		return device_shape
	if String((device as Dictionary).get("declaration", "")) != "lowest_target_windows_v1":
		return _fail(&"budget_field_invalid", "device_evidence.declaration is frozen", {})
	if String((device as Dictionary).get("godot_version", "")) != "4.6.3.stable.mono":
		return _fail(&"budget_field_invalid", "device_evidence.godot_version is frozen", {})
	for text_field: String in ["os_version", "cpu_model"]:
		if typeof((device as Dictionary)[text_field]) != TYPE_STRING or String((device as Dictionary)[text_field]).strip_edges().is_empty():
			return _fail(&"budget_field_invalid", "device_evidence.%s must be nonblank" % text_field, {})
	if typeof((device as Dictionary)["logical_processor_count"]) != TYPE_INT or int((device as Dictionary)["logical_processor_count"]) < 1:
		return _fail(&"budget_field_invalid", "device_evidence.logical_processor_count must be >= 1", {})

	var sources: Variant = budget["source_sha256"]
	if typeof(sources) != TYPE_DICTIONARY:
		return _fail(&"budget_field_invalid", "source_sha256 must be an object", {})
	var sources_shape := _exact_keys(sources, _SOURCE_SHA256_KEYS, &"budget_source_sha256_invalid")
	if not sources_shape.get("ok", false):
		return sources_shape
	for key: String in _SOURCE_SHA256_KEYS:
		if not _is_sha256_hex((sources as Dictionary)[key]):
			return _fail(&"budget_field_invalid", "source_sha256.%s must be 64 lowercase hex characters" % key, {})

	var rows: Variant = budget["rows"]
	if typeof(rows) != TYPE_ARRAY:
		return _fail(&"budget_field_invalid", "rows must be an array", {})
	for entry: Variant in (rows as Array):
		var row_check := _validate_row_shape(entry)
		if not row_check.get("ok", false):
			return row_check

	for budget_field: String in ["slice_operation_budget", "search_operation_budget",
			"reserved_fallback_operation_budget", "hard_operation_budget"]:
		if typeof(budget[budget_field]) != TYPE_INT or int(budget[budget_field]) < 1:
			return _fail(&"budget_field_invalid", "%s must be a positive integer" % budget_field, {})
	if int(budget["hard_operation_budget"]) != int(budget["search_operation_budget"]) + int(budget["reserved_fallback_operation_budget"]):
		return _fail(&"budget_formula_invalid", "hard_operation_budget must equal the exact sum", {})

	return {"ok": true, "code": &"ok", "value": {"budget": budget.duplicate(true)}, "receipt": {}}


static func _validate_row_shape(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return _fail(&"budget_row_invalid", "each row must be an object", {})
	var row: Dictionary = entry
	var shape := _exact_keys(row, _ROW_KEYS, &"budget_row_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if not (String(row["kind"]) == "search" or String(row["kind"]) == "fallback"):
		return _fail(&"budget_row_invalid", "kind must be search or fallback", {})
	if typeof(row["case_id"]) != TYPE_STRING or String(row["case_id"]).is_empty():
		return _fail(&"budget_row_invalid", "case_id must be nonblank", {})
	if typeof(row["capability_ids"]) != TYPE_ARRAY:
		return _fail(&"budget_row_invalid", "capability_ids must be an array", {})
	var nonce_ordinal: Variant = row["nonce_ordinal"]
	if nonce_ordinal != null and (typeof(nonce_ordinal) != TYPE_INT or int(nonce_ordinal) < 0 or int(nonce_ordinal) > 255):
		return _fail(&"budget_row_invalid", "nonce_ordinal must be null or 0..255", {})
	if String(row["kind"]) == "search" and nonce_ordinal == null:
		return _fail(&"budget_row_invalid", "a search row must carry a nonce_ordinal", {})
	if String(row["kind"]) == "fallback" and nonce_ordinal != null:
		return _fail(&"budget_row_invalid", "a fallback row must not carry a nonce_ordinal", {})
	if typeof(row["forced_cell"]) != TYPE_INT or int(row["forced_cell"]) < 0:
		return _fail(&"budget_row_invalid", "forced_cell must be a nonnegative integer", {})
	if typeof(row["first_cell_zero"]) != TYPE_BOOL:
		return _fail(&"budget_row_invalid", "first_cell_zero must be a boolean", {})
	for op_field: String in ["candidate_operations", "search_operations", "fallback_validation_operations"]:
		if typeof(row[op_field]) != TYPE_INT or int(row[op_field]) < 0:
			return _fail(&"budget_row_invalid", "%s must be a nonnegative integer" % op_field, {})
	return {"ok": true}


static func _validate_budget_freshness(budget: Dictionary) -> Dictionary:
	var sources: Dictionary = budget["source_sha256"]
	for key: String in _FRESHNESS_CHECKED_SOURCES.keys():
		var path: String = _FRESHNESS_CHECKED_SOURCES[key]
		if not FileAccess.file_exists(path):
			return _fail(&"budget_source_missing", "a source this budget was computed against is absent", {"path": path})
		var actual: String = _digest_bytes(FileAccess.get_file_as_bytes(path))
		if actual != String(sources[key]):
			return _fail(&"budget_source_stale",
				"a source this budget was computed against has changed", {"field": key})
	return {"ok": true}


static func _read_fallback_manifest() -> Dictionary:
	if not FileAccess.file_exists(FALLBACK_MANIFEST_PATH):
		return _fail(&"generator_budget_unavailable", "the certified fallback manifest is absent", {})
	var parsed: Dictionary = _STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(FALLBACK_MANIFEST_PATH).get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"generator_budget_unavailable", "the certified fallback manifest is not strict JSON", {})
	var artifact: Dictionary = parsed["value"]
	var schema_check := validate_fallback_schema(artifact)
	if not schema_check.get("ok", false):
		return _fail(&"generator_budget_unavailable", "the certified fallback manifest failed schema validation",
			{"cause": schema_check.get("code", &"")})
	return {"ok": true, "value": {"records": artifact["records"]}}


## Pure structural schema validation of a fallback manifest dictionary. Directly testable with a
## hand-built dictionary, independent of disk.
static func validate_fallback_schema(artifact: Dictionary) -> Dictionary:
	var shape := _exact_keys(artifact, _FALLBACK_MANIFEST_KEYS, &"fallback_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(artifact["schema_version"]) != TYPE_INT or int(artifact["schema_version"]) != 1:
		return _fail(&"fallback_field_invalid", "schema_version must be exactly 1", {})
	if String(artifact["kind"]) != "minesweeper_certified_fallbacks":
		return _fail(&"fallback_field_invalid", "kind is frozen", {})
	if String(artifact["registry_version"]) != "minesweeper_certified_fallbacks_v1":
		return _fail(&"fallback_field_invalid", "registry_version is frozen", {})
	if String(artifact["generator_version"]) != "dwm_generator_v1":
		return _fail(&"fallback_field_invalid", "generator_version is frozen", {})
	if String(artifact["verifier_version"]) != "visible_deduction_v1":
		return _fail(&"fallback_field_invalid", "verifier_version is frozen", {})
	var records: Variant = artifact["records"]
	if typeof(records) != TYPE_ARRAY:
		return _fail(&"fallback_field_invalid", "records must be an array", {})
	for entry: Variant in (records as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"fallback_record_invalid", "each record must be an object", {})
		var record: Dictionary = entry
		var record_shape := _exact_keys(record, _FALLBACK_RECORD_KEYS, &"fallback_record_member_set_invalid")
		if not record_shape.get("ok", false):
			return record_shape
		if typeof(record["difficulty_id"]) != TYPE_STRING or String(record["difficulty_id"]).is_empty():
			return _fail(&"fallback_record_invalid", "difficulty_id must be nonblank", {})
		if typeof(record["forced_cell"]) != TYPE_INT or int(record["forced_cell"]) < 0:
			return _fail(&"fallback_record_invalid", "forced_cell must be a nonnegative integer", {})
		if typeof(record["first_cell_zero"]) != TYPE_BOOL:
			return _fail(&"fallback_record_invalid", "first_cell_zero must be a boolean", {})
		if typeof(record["mine_indices"]) != TYPE_ARRAY:
			return _fail(&"fallback_record_invalid", "mine_indices must be an array", {})
		if typeof(record["mine_count"]) != TYPE_INT or int(record["mine_count"]) != (record["mine_indices"] as Array).size():
			return _fail(&"fallback_record_invalid", "mine_count must equal mine_indices.size()", {})
	return {"ok": true, "code": &"ok", "value": {"artifact": artifact.duplicate(true)}, "receipt": {}}


# ---- shared helpers ----

## Projects the exact GeneratorKernelSpec fields out of a complete, already-validated BoardSpec --
## no board token, no issuer-receipt member, no coercion.
static func _project_kernel_spec(board_spec: Dictionary) -> Dictionary:
	var projected: Dictionary = {}
	for key: String in _KERNEL.SPEC_KEYS:
		projected[key] = board_spec[key]
	return projected


static func _requested_count_spec(validated_spec: Dictionary, mine_count: int) -> Dictionary:
	# MinesweeperBoardSchema.validate_layout() cross-checks mine_indices.size() against the spec's
	# own requested_mine_count; after extras reduction the true adopted count can be smaller than
	# the spec's original requested_mine_count, so validate the adopted layout against a
	# requested_mine_count that reflects what was actually adopted.
	var adjusted: Dictionary = validated_spec.duplicate(true)
	adjusted["requested_mine_count"] = mine_count
	return adjusted


static func _seed(stream_id: StringName, nonce: String) -> Dictionary:
	var rng: RefCounted = _RNG.new()
	var seeded: Dictionary = rng.seed(stream_id, nonce)
	if not seeded.get("ok", false):
		return seeded
	return {"ok": true, "value": rng}


static func _digest_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _is_sha256_hex(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text: String = value
	if text.length() != 64:
		return false
	for i in range(text.length()):
		var c := text.unicode_at(i)
		var is_digit: bool = c >= 0x30 and c <= 0x39
		var is_lower_hex: bool = c >= 0x61 and c <= 0x66
		if not (is_digit or is_lower_hex):
			return false
	return true


static func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(code, "value must be a dictionary", {})
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
