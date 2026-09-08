extends SceneTree

## Builds data/manifests/minesweeper_generator_budget.v1.json (Plan 02 Task 4, dwm-p2r13).
##
## Runs via `-s`, so this extends SceneTree and works in `_init()`. CONSEQUENCE FOR TESTS: probe
## this file with DynamicScriptProbe.load_script() and NEVER instantiate(). The pure helpers below
## (nonce_for(), search_case_id(), fallback_case_id(), nearest_rank_p99(), next_power_of_two(),
## slice_operation_budget(), search_operation_budget(), reserved_fallback_operation_budget(),
## hard_operation_budget(), corpus_projection(), parse_arguments()) are exercised directly by
## tests/unit/tooling/test_minesweeper_generator_artifacts.gd with tiny synthetic inputs, never by
## calling _init() or run_full_corpus() (which drives the real 3,072-case search corpus plus every
## fallback revalidation and is not something a fast unit suite should run).
##
## If DWM_LOWEST_TARGET_WINDOWS_DEVICE=1 is absent, write/check stops before any generation and
## cannot write or freeze budgets. Drives MinesweeperGeneratorKernel directly (mode=candidate_search
## for search rows) and MinesweeperNoGuessVerifier directly (one verify() call per fallback row);
## never imports the tooling-limits ceiling into MinesweeperBoardGenerator.gd and never calls it.

const _KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
const _VERIFIER := preload("res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd")
const _TOOLING_LIMITS := preload("res://tools/minesweeper/MinesweeperGeneratorToolingLimits.gd")
const _FALLBACK_BUILDER := preload("res://tools/minesweeper/BuildCertifiedFallbacks.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const ARTIFACT_PATH := "res://data/manifests/minesweeper_generator_budget.v1.json"
const _BUDGET_SCHEMA_PATH := "res://data/schemas/minesweeper-generator-budget.schema.json"
const _RNG_SOURCE_PATH := "res://scripts/domain/minesweeper/DeterministicRng32.gd"
const _REDUCER_SOURCE_PATH := "res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd"
const _KERNEL_SOURCE_PATH := "res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd"
const _VERIFIER_SOURCE_PATH := "res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd"
const _TOOLING_LIMITS_SOURCE_PATH := "res://tools/minesweeper/MinesweeperGeneratorToolingLimits.gd"
const _FALLBACK_BUILDER_SOURCE_PATH := "res://tools/minesweeper/BuildCertifiedFallbacks.gd"
const _BENCHMARK_TOOL_SOURCE_PATH := "res://tools/minesweeper/BenchmarkMinesweeperGenerator.gd"

const _NONCE_PREFIX := "minesweeper_benchmark_nonce_v1"
const _DIFFICULTY_ORDER := ["beginner", "intermediate", "expert"]
const _CAPABILITY_GROUPS := ["default", "lucky", "debug", "lucky_debug"]
const _CAPABILITY_IDS := {
	"default": ["first_cell_safe"],
	"lucky": ["first_cell_safe", "first_cell_zero"],
	"debug": ["first_cell_safe", "forced_no_guess"],
	"lucky_debug": ["first_cell_safe", "first_cell_zero", "forced_no_guess"],
}
const _NONCE_ORDINAL_COUNT := 256
const _GODOT_VERSION := "4.6.3.stable.mono"
const _DEVICE_ENV_VAR := "DWM_LOWEST_TARGET_WINDOWS_DEVICE"
const _MODE_FLAGS := {"write": ["path"], "check": ["path"]}
const _ADVANCE_CHUNK := 200_000
const _BOARD_KIND := "desktop"
## Soft internal deadline for one process invocation, well under the ~50-minute host process
## lifetime observed empirically for this tool (see task-4-report.md) so a checkpoint always lands
## before an external kill.
const _WALL_CLOCK_SOFT_DEADLINE_MSEC := 35 * 60 * 1000


# ---- pure, directly-testable helpers ----

static func nonce_for(difficulty_id: String, capability_ids: Array, nonce_ordinal: int, stream_id: String) -> Dictionary:
	var capability_json: Dictionary = _CANONICAL_JSON.stringify(capability_ids)
	if not capability_json.get("ok", false):
		return capability_json
	var composed: String = "%s\n%s\n%s\n%d\n%s" % [
		_NONCE_PREFIX, difficulty_id, String(capability_json["value"]), nonce_ordinal, stream_id,
	]
	return {"ok": true, "value": composed.sha256_text()}


static func search_case_id(difficulty_id: String, capability_group: String, nonce_ordinal: int) -> String:
	return "search:%s:%s:%03d" % [difficulty_id, capability_group, nonce_ordinal]


static func fallback_case_id(difficulty_id: String, first_cell_zero: bool, forced_cell: int) -> String:
	return "fallback:%s:%s:%d" % [difficulty_id, ("zero" if first_cell_zero else "safe"), forced_cell]


## nearest-rank p99 over ascending-sorted `values`: one-based rank = (99*n+99)/100 (integer
## division), zero-based element = rank-1.
static func nearest_rank_p99(sorted_ascending_values: Array) -> Dictionary:
	var n: int = sorted_ascending_values.size()
	if n == 0:
		return {"ok": false, "code": &"empty_series", "message": "p99 requires at least one value", "details": {}}
	var rank: int = (99 * n + 99) / 100
	if rank < 1 or rank > n:
		return {"ok": false, "code": &"rank_out_of_range", "message": "computed rank is out of range", "details": {}}
	return {"ok": true, "value": int(sorted_ascending_values[rank - 1])}


static func ceil_div8(value: int) -> int:
	return (value + 7) / 8


## Least positive 2^n >= x. Rejects nonpositive input or signed-64 overflow.
static func next_power_of_two(x: int) -> Dictionary:
	if x <= 0:
		return {"ok": false, "code": &"nonpositive_input", "message": "next_power_of_two requires a positive input", "details": {}}
	var value: int = 1
	while value < x:
		if value >= (1 << 62):
			# Doubling a value >= 2^62 would reach or exceed 2^63, outside signed 64-bit range.
			return {"ok": false, "code": &"overflow", "message": "next_power_of_two overflowed signed 64-bit range", "details": {}}
		value = value << 1
	return {"ok": true, "value": value}


static func slice_operation_budget(p99_candidate_operations: int) -> Dictionary:
	return next_power_of_two(maxi(1024, ceil_div8(p99_candidate_operations)))


static func search_operation_budget(maximum_observed_search_operations: int) -> Dictionary:
	return next_power_of_two(2 * maximum_observed_search_operations)


static func reserved_fallback_operation_budget(maximum_fallback_validation_operations: int) -> Dictionary:
	return next_power_of_two(maximum_fallback_validation_operations + 1)


## The ordered projection of one row's seven input fields (through first_cell_zero), used both to
## build the rows array skeleton before measurement and to compute benchmark_corpus_sha256.
static func row_projection(kind: String, case_id: String, difficulty_id: String, capability_ids: Array,
		nonce_ordinal: Variant, forced_cell: int, first_cell_zero: bool) -> Dictionary:
	return {
		"kind": kind, "case_id": case_id, "difficulty_id": difficulty_id,
		"capability_ids": capability_ids, "nonce_ordinal": nonce_ordinal,
		"forced_cell": forced_cell, "first_cell_zero": first_cell_zero,
	}


static func corpus_sha256(projections: Array) -> Dictionary:
	var stringified: Dictionary = _CANONICAL_JSON.stringify(projections)
	if not stringified.get("ok", false):
		return stringified
	return {"ok": true, "value": String(stringified["value"]).sha256_text()}


static func digest_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func parse_arguments(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _fail(&"generator_argument_count_invalid",
			"exactly one of --write=<path> or --check=<path> is required", {})
	var argument: String = String(args[0])
	for mode: String in _MODE_FLAGS.keys():
		var prefix: String = "--%s=" % mode
		if argument.begins_with(prefix):
			var path: String = argument.substr(prefix.length())
			if path.is_empty():
				return _fail(&"generator_argument_blank", "a flag value is never blank", {"mode": mode})
			return {"ok": true, "value": {"mode": mode, "path": path}}
	return _fail(&"generator_argument_unknown",
		"only --write=<res://path> or --check=<res://path> are legal (no bare mode, no --verify alias)",
		{"argument": argument})


static func canonical_bytes(artifact: Dictionary) -> Dictionary:
	var stringified: Dictionary = _CANONICAL_JSON.stringify(artifact)
	if not stringified.get("ok", false):
		return stringified
	return {"ok": true, "value": {"bytes": String(stringified["value"]).to_utf8_buffer()}}


static func _rng_capture(stream_id: StringName, nonce: String) -> Dictionary:
	var rng := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd").new()
	var seeded: Dictionary = rng.seed(stream_id, nonce)
	if not seeded.get("ok", false):
		return seeded
	return {"ok": true, "value": rng.capture()["value"]}


static func _sampled_forced_cell(stream_id: StringName, nonce: String, total_cells: int) -> Dictionary:
	var rng := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd").new()
	var seeded: Dictionary = rng.seed(stream_id, nonce)
	if not seeded.get("ok", false):
		return seeded
	var sampled: Dictionary = rng.sample_bounded(total_cells)
	if not sampled.get("ok", false):
		return sampled
	return {"ok": true, "value": {"forced_cell": int((sampled["value"] as Dictionary)["result"]),
		"debug_rng_state": rng.capture()["value"]}}


## Runs one search case through the kernel to a definitive conclusion (certified or the tooling
## ceiling), returning the measured {candidate_operations, search_operations, forced_cell} plus the
## row's case_id/nonce fields already filled in. Directly testable with tiny width/height/
## base_mine_count arguments.
static func run_search_case(difficulty_id: String, width: int, height: int, base_mine_count: int,
		capability_group: String, nonce_ordinal: int, ceiling: int) -> Dictionary:
	var capability_ids: Array = _CAPABILITY_IDS[capability_group]
	var total_cells: int = width * height
	var placement_nonce := nonce_for(difficulty_id, capability_ids, nonce_ordinal, "minesweeper_placement_v1")
	var debug_nonce := nonce_for(difficulty_id, capability_ids, nonce_ordinal, "minesweeper_debug_v1")
	var explosion_nonce := nonce_for(difficulty_id, capability_ids, nonce_ordinal, "minesweeper_explosion_v1")
	if not (placement_nonce.get("ok", false) and debug_nonce.get("ok", false) and explosion_nonce.get("ok", false)):
		return {"ok": false, "code": &"nonce_derivation_failed", "message": "a per-stream nonce could not be derived", "details": {}}

	var forced_cell: int
	var debug_rng_state: Dictionary
	if capability_group == "debug" or capability_group == "lucky_debug":
		var drawn := _sampled_forced_cell(&"minesweeper_debug_v1", String(debug_nonce["value"]), total_cells)
		if not drawn.get("ok", false):
			return drawn
		forced_cell = int((drawn["value"] as Dictionary)["forced_cell"])
		debug_rng_state = (drawn["value"] as Dictionary)["debug_rng_state"]
	else:
		forced_cell = nonce_ordinal % total_cells
		var captured := _rng_capture(&"minesweeper_debug_v1", String(debug_nonce["value"]))
		if not captured.get("ok", false):
			return captured
		debug_rng_state = captured["value"]

	var placement_state := _rng_capture(&"minesweeper_placement_v1", String(placement_nonce["value"]))
	if not placement_state.get("ok", false):
		return placement_state
	var explosion_state := _rng_capture(&"minesweeper_explosion_v1", String(explosion_nonce["value"]))
	if not explosion_state.get("ok", false):
		return explosion_state

	var spec := {
		"schema_version": 1, "board_kind": _BOARD_KIND, "difficulty_id": difficulty_id,
		"width": width, "height": height, "base_mine_count": base_mine_count,
		"raw_extra_mines": 0, "requested_mine_count": base_mine_count, "capability_ids": capability_ids,
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": String(placement_nonce["value"]),
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": String(debug_nonce["value"]),
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": String(explosion_nonce["value"]),
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}
	var begun: Dictionary = _KERNEL.begin(spec, forced_cell, _KERNEL.MODE_CANDIDATE_SEARCH,
		placement_state["value"], debug_rng_state, explosion_state["value"])
	if not begun.get("ok", false):
		return {"ok": false, "code": &"kernel_rejected", "message": "kernel.begin() rejected the spec", "details": begun}
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]
	var max_candidate_operations: int = total_cells

	while StringName(frontier["status"]) == _KERNEL.STATUS_SEARCHING:
		if int(frontier["operations_used"]) >= ceiling:
			return {"ok": false, "code": &"tooling_safety_ceiling_reached",
				"message": "the tooling safety ceiling was reached before certification",
				"details": {"difficulty_id": difficulty_id, "capability_group": capability_group,
					"nonce_ordinal": nonce_ordinal, "operations_used": frontier["operations_used"]}}
		var remaining: int = ceiling - int(frontier["operations_used"])
		# Never offer less than one candidate's worth (total_cells): a smaller operation_limit
		# would make advance() a guaranteed no-op (searching, operations_used unchanged), which
		# would starve the operations_used>=ceiling check above forever. This can overshoot the
		# ceiling by at most one candidate's cost on the final call, which is acceptable for a
		# safety bound this many orders of magnitude below TOOLING_SAFETY_OPERATION_CEILING.
		var call_limit: int = maxi(mini(_ADVANCE_CHUNK, remaining), total_cells)
		var advanced: Dictionary = _KERNEL.advance(frontier, call_limit)
		if not advanced.get("ok", false):
			return {"ok": false, "code": &"kernel_rejected", "message": "kernel.advance() rejected the frontier", "details": advanced}
		frontier = (advanced["value"] as Dictionary)["preparation"]

	if StringName(frontier["status"]) != _KERNEL.STATUS_CERTIFIED:
		return {"ok": false, "code": &"kernel_exhausted", "message": "the kernel search exhausted without certifying", "details": {}}

	return {"ok": true, "code": &"ok", "value": {
		"case_id": search_case_id(difficulty_id, capability_group, nonce_ordinal),
		"difficulty_id": difficulty_id, "capability_ids": capability_ids, "nonce_ordinal": nonce_ordinal,
		"forced_cell": forced_cell, "first_cell_zero": capability_ids.has("first_cell_zero"),
		"candidate_operations": max_candidate_operations,
		"search_operations": int(frontier["operations_used"]),
		"fallback_validation_operations": 0,
	}, "receipt": {}}


## Re-verifies one already-certified fallback record and returns its measured operation_count.
## Directly testable with a tiny synthetic layout, independent of the real fallback manifest.
static func run_fallback_case(difficulty_id: String, width: int, height: int, forced_cell: int,
		first_cell_zero: bool, mine_indices: Array) -> Dictionary:
	var layout := {"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices, "mine_count": (mine_indices as Array).size()}
	var verified: Dictionary = _VERIFIER.verify(layout, forced_cell, width * height)
	if not verified.get("ok", false):
		return {"ok": false, "code": &"fallback_revalidation_failed",
			"message": "a certified fallback record failed independent revalidation", "details": verified}
	var capability_ids: Array = ["first_cell_safe", "forced_no_guess"]
	if first_cell_zero:
		capability_ids = ["first_cell_safe", "first_cell_zero", "forced_no_guess"]
	return {"ok": true, "code": &"ok", "value": {
		"case_id": fallback_case_id(difficulty_id, first_cell_zero, forced_cell),
		"difficulty_id": difficulty_id, "capability_ids": capability_ids, "nonce_ordinal": null,
		"forced_cell": forced_cell, "first_cell_zero": first_cell_zero,
		"candidate_operations": 0, "search_operations": 0,
		"fallback_validation_operations": int((verified["value"] as Dictionary)["operation_count"]),
	}, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


# ---- expensive, real-corpus orchestration (never called by the fast unit suite) ----

## CHECKPOINT/RESUME (dwm-p2r13 Task 4 Phase 2): same rationale and mechanism as
## BuildCertifiedFallbacks.build_all_records() -- the observed host process lifetime (~50 minutes)
## is well short of the full 3,072-search-row-plus-every-fallback-revalidation corpus's wall-clock,
## and the frozen CLI law admits no extra flag, so resume is automatic: search rows (fully ordered,
## deterministic) come first, then fallback rows (also fully ordered, deterministic) -- "already
## have N rows" unambiguously identifies the resume point across that single concatenated
## enumeration. Checkpointed after every row; soft-deadline-stopped like the fallback builder.
static func run_full_corpus(ceiling: int) -> Dictionary:
	var difficulties := _FALLBACK_BUILDER.read_difficulty_manifest()
	if not difficulties.get("ok", false):
		return difficulties
	var difficulty_rows: Array = (difficulties["value"] as Dictionary)["records"]
	var by_id: Dictionary = {}
	for entry: Variant in difficulty_rows:
		by_id[String((entry as Dictionary)["difficulty_id"])] = entry
	for host: String in ["canonical_solo", "canonical_pair"]:
		var fixed: Dictionary = preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd").lookup(host)
		if not fixed.get("ok", false): return fixed
		by_id[host] = fixed.value

	if not FileAccess.file_exists(_FALLBACK_BUILDER.ARTIFACT_PATH):
		return _fail(&"fallback_manifest_missing",
			"the certified fallback manifest must exist before benchmarking fallback revalidation", {})
	var fallback_parsed: Dictionary = _STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(_FALLBACK_BUILDER.ARTIFACT_PATH).get_string_from_utf8())
	if not fallback_parsed.get("ok", false):
		return _fail(&"fallback_manifest_unparsable", "the fallback manifest is not strict JSON", {})
	var fallback_records: Array = (fallback_parsed["value"] as Dictionary)["records"]

	var total_rows: int = _DIFFICULTY_ORDER.size() * _CAPABILITY_GROUPS.size() * _NONCE_ORDINAL_COUNT + fallback_records.size()
	var rows: Array = []
	var resume_from: int = 0
	var checkpoint_loaded := _read_checkpoint()
	if checkpoint_loaded.get("ok", false):
		rows = (checkpoint_loaded["value"] as Dictionary)["rows"]
		resume_from = rows.size()

	var started_msec: int = Time.get_ticks_msec()
	var ordinal := 0
	for difficulty_id: String in _DIFFICULTY_ORDER:
		var record: Dictionary = by_id[difficulty_id]
		var width: int = int(record["width"])
		var height: int = int(record["height"])
		var base_mine_count: int = int(record["base_mine_count"])
		for capability_group: String in _CAPABILITY_GROUPS:
			for nonce_ordinal in range(_NONCE_ORDINAL_COUNT):
				if ordinal < resume_from:
					ordinal += 1
					continue
				var case_result := run_search_case(difficulty_id, width, height, base_mine_count,
					capability_group, nonce_ordinal, ceiling)
				if not case_result.get("ok", false):
					return case_result
				rows.append(case_result["value"])
				ordinal += 1
				var checkpointed := _write_checkpoint(rows)
				if not checkpointed.get("ok", false):
					return checkpointed
				if Time.get_ticks_msec() - started_msec > _WALL_CLOCK_SOFT_DEADLINE_MSEC:
					return {"ok": true, "value": {"complete": false, "rows_done": rows.size(), "rows_total": total_rows}}

	for entry: Variant in fallback_records:
		if ordinal < resume_from:
			ordinal += 1
			continue
		var fallback_record: Dictionary = entry
		var difficulty_id: String = String(fallback_record["difficulty_id"])
		var width: int = int((by_id[difficulty_id] as Dictionary)["width"])
		var height: int = int((by_id[difficulty_id] as Dictionary)["height"])
		var case_result := run_fallback_case(difficulty_id, width, height,
			int(fallback_record["forced_cell"]), bool(fallback_record["first_cell_zero"]),
			fallback_record["mine_indices"])
		if not case_result.get("ok", false):
			return case_result
		rows.append(case_result["value"])
		ordinal += 1
		var checkpointed := _write_checkpoint(rows)
		if not checkpointed.get("ok", false):
			return checkpointed
		if Time.get_ticks_msec() - started_msec > _WALL_CLOCK_SOFT_DEADLINE_MSEC:
			return {"ok": true, "value": {"complete": false, "rows_done": rows.size(), "rows_total": total_rows}}

	var composed := _compose_corpus_result(rows)
	if not composed.get("ok", false):
		return composed
	_delete_checkpoint()
	var composed_value: Dictionary = composed["value"]
	composed_value["complete"] = true
	return {"ok": true, "value": composed_value}


static func _checkpoint_path() -> String:
	return ARTIFACT_PATH + ".build-checkpoint.json"


static func _read_checkpoint() -> Dictionary:
	var path: String = _checkpoint_path()
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_bytes(path).get_string_from_utf8())
	if not parsed.get("ok", false):
		return {"ok": false}
	var checkpoint: Dictionary = parsed["value"]
	if not checkpoint.has("rows") or typeof(checkpoint["rows"]) != TYPE_ARRAY:
		return {"ok": false}
	return {"ok": true, "value": {"rows": (checkpoint["rows"] as Array).duplicate(true)}}


static func _write_checkpoint(rows: Array) -> Dictionary:
	var canonical: Dictionary = canonical_bytes({"rows": rows})
	if not canonical.get("ok", false):
		return canonical
	var bytes: PackedByteArray = (canonical["value"] as Dictionary)["bytes"]
	var absolute: String = ProjectSettings.globalize_path(_checkpoint_path())
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": &"checkpoint_open_failed", "message": scratch, "details": {}}
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		return {"ok": false, "code": &"checkpoint_rename_failed", "message": str(rename_error), "details": {}}
	return {"ok": true}


static func _delete_checkpoint() -> void:
	var absolute: String = ProjectSettings.globalize_path(_checkpoint_path())
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


## Composes the final corpus result (rows projection, corpus hash, the four budget values) from
## the measured rows. Named to avoid colliding with SceneTree's own inherited _finalize() virtual.
static func _compose_corpus_result(rows: Array) -> Dictionary:
	var projections: Array = []
	var search_candidate_operations: Array = []
	var max_search_operations := 0
	var max_fallback_validation_operations := 0
	for entry: Variant in rows:
		var row: Dictionary = entry
		var kind: String = "search" if row["nonce_ordinal"] != null else "fallback"
		projections.append(row_projection(kind, String(row["case_id"]), String(row["difficulty_id"]),
			row["capability_ids"], row["nonce_ordinal"], int(row["forced_cell"]), bool(row["first_cell_zero"])))
		if row["nonce_ordinal"] != null:
			search_candidate_operations.append(int(row["candidate_operations"]))
			max_search_operations = maxi(max_search_operations, int(row["search_operations"]))
		else:
			max_fallback_validation_operations = maxi(max_fallback_validation_operations, int(row["fallback_validation_operations"]))
	search_candidate_operations.sort()
	var p99 := nearest_rank_p99(search_candidate_operations)
	if not p99.get("ok", false):
		return p99
	var slice_budget := slice_operation_budget(int(p99["value"]))
	if not slice_budget.get("ok", false):
		return slice_budget
	var search_budget := search_operation_budget(max_search_operations)
	if not search_budget.get("ok", false):
		return search_budget
	var reserved_budget := reserved_fallback_operation_budget(max_fallback_validation_operations)
	if not reserved_budget.get("ok", false):
		return reserved_budget
	var hard_budget: int = int(search_budget["value"]) + int(reserved_budget["value"])

	var corpus_hash := corpus_sha256(projections)
	if not corpus_hash.get("ok", false):
		return corpus_hash

	var typed_rows: Array = []
	for entry: Variant in rows:
		var row: Dictionary = entry
		typed_rows.append({
			"kind": "search" if row["nonce_ordinal"] != null else "fallback",
			"case_id": row["case_id"], "difficulty_id": row["difficulty_id"],
			"capability_ids": row["capability_ids"], "nonce_ordinal": row["nonce_ordinal"],
			"forced_cell": row["forced_cell"], "first_cell_zero": row["first_cell_zero"],
			"candidate_operations": row["candidate_operations"], "search_operations": row["search_operations"],
			"fallback_validation_operations": row["fallback_validation_operations"],
		})

	return {"ok": true, "value": {
		"rows": typed_rows, "benchmark_corpus_sha256": corpus_hash["value"],
		"slice_operation_budget": slice_budget["value"], "search_operation_budget": search_budget["value"],
		"reserved_fallback_operation_budget": reserved_budget["value"], "hard_operation_budget": hard_budget,
	}}


static func _device_evidence() -> Dictionary:
	return {
		"declaration": "lowest_target_windows_v1",
		"os_version": OS.get_distribution_name() + " " + OS.get_version(),
		"cpu_model": OS.get_processor_name(),
		"logical_processor_count": OS.get_processor_count(),
		"godot_version": _GODOT_VERSION,
	}


static func _source_sha256() -> Dictionary:
	for path: String in [_RNG_SOURCE_PATH, _REDUCER_SOURCE_PATH, _KERNEL_SOURCE_PATH, _VERIFIER_SOURCE_PATH,
			_TOOLING_LIMITS_SOURCE_PATH, _FALLBACK_BUILDER_SOURCE_PATH, _FALLBACK_BUILDER.ARTIFACT_PATH,
			_BENCHMARK_TOOL_SOURCE_PATH, _BUDGET_SCHEMA_PATH, _FALLBACK_BUILDER.DIFFICULTY_MANIFEST_PATH]:
		if not FileAccess.file_exists(path):
			return _fail(&"source_missing", "a hashed source is absent", {"path": path})
	return {"ok": true, "value": {
		"difficulty_manifest": digest_bytes(FileAccess.get_file_as_bytes(_FALLBACK_BUILDER.DIFFICULTY_MANIFEST_PATH)),
		"rng": digest_bytes(FileAccess.get_file_as_bytes(_RNG_SOURCE_PATH)),
		"reducer": digest_bytes(FileAccess.get_file_as_bytes(_REDUCER_SOURCE_PATH)),
		"kernel": digest_bytes(FileAccess.get_file_as_bytes(_KERNEL_SOURCE_PATH)),
		"verifier": digest_bytes(FileAccess.get_file_as_bytes(_VERIFIER_SOURCE_PATH)),
		"tooling_limits": digest_bytes(FileAccess.get_file_as_bytes(_TOOLING_LIMITS_SOURCE_PATH)),
		"fallback_builder": digest_bytes(FileAccess.get_file_as_bytes(_FALLBACK_BUILDER_SOURCE_PATH)),
		"fallback_manifest": digest_bytes(FileAccess.get_file_as_bytes(_FALLBACK_BUILDER.ARTIFACT_PATH)),
		"benchmark_tool": digest_bytes(FileAccess.get_file_as_bytes(_BENCHMARK_TOOL_SOURCE_PATH)),
		"budget_schema": digest_bytes(FileAccess.get_file_as_bytes(_BUDGET_SCHEMA_PATH)),
	}}


static func build_artifact() -> Dictionary:
	var corpus := run_full_corpus(_TOOLING_LIMITS.TOOLING_SAFETY_OPERATION_CEILING)
	if not corpus.get("ok", false):
		return corpus
	var corpus_value: Dictionary = corpus["value"]
	if not bool(corpus_value.get("complete", false)):
		return {"ok": true, "value": {
			"complete": false, "rows_done": corpus_value["rows_done"], "rows_total": corpus_value["rows_total"],
		}}
	var sources := _source_sha256()
	if not sources.get("ok", false):
		return sources
	return {"ok": true, "value": {"complete": true, "artifact": {
		"schema_version": 1,
		"benchmark_corpus_sha256": corpus_value["benchmark_corpus_sha256"],
		"device_evidence": _device_evidence(),
		"source_sha256": sources["value"],
		"rows": corpus_value["rows"],
		"slice_operation_budget": corpus_value["slice_operation_budget"],
		"search_operation_budget": corpus_value["search_operation_budget"],
		"reserved_fallback_operation_budget": corpus_value["reserved_fallback_operation_budget"],
		"hard_operation_budget": corpus_value["hard_operation_budget"],
	}}}


# ---- CLI entry point ----

func _init() -> void:
	if OS.get_environment(_DEVICE_ENV_VAR) != "1":
		_reject("DEVICE", {"code": &"lowest_target_device_not_declared",
			"message": "%s=1 is required before any generation" % _DEVICE_ENV_VAR})
		return
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		_reject("ARGUMENTS", parsed)
		return
	var arguments: Dictionary = parsed["value"] as Dictionary
	var mode: String = String(arguments["mode"])
	var path: String = String(arguments["path"])

	var built: Dictionary = build_artifact()
	if not built.get("ok", false):
		_reject("BUILD", built)
		return
	var built_value: Dictionary = built["value"]
	if not bool(built_value.get("complete", false)):
		print("MINESWEEPER_GENERATOR_BUDGET: RESUME_NEEDED %d/%d rows checkpointed -- rerun the same command to continue" % [
			int(built_value["rows_done"]), int(built_value["rows_total"])])
		quit(0)
		return
	var artifact: Dictionary = built_value["artifact"]
	var canonical: Dictionary = canonical_bytes(artifact)
	if not canonical.get("ok", false):
		_reject("SERIALIZE", canonical)
		return
	var bytes: PackedByteArray = (canonical["value"] as Dictionary)["bytes"]

	if mode == "check":
		_run_check(path, bytes)
		return
	_run_write(path, bytes)


func _run_check(path: String, bytes: PackedByteArray) -> void:
	if not FileAccess.file_exists(path):
		_reject("CHECK", {"code": &"target_missing", "message": path})
		return
	var on_disk: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if on_disk != bytes:
		_reject("CHECK", {"code": &"byte_mismatch", "message": "regenerated bytes differ from the target"})
		return
	print("MINESWEEPER_GENERATOR_BUDGET: CHECK_PASS %s" % path)
	quit(0)


func _run_write(path: String, bytes: PackedByteArray) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		_reject("WRITE", {"code": &"output_directory_failed", "message": str(directory_error)})
		return
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		_reject("WRITE", {"code": &"output_open_failed", "message": scratch})
		return
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var reread: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	if reread != bytes:
		DirAccess.remove_absolute(scratch)
		_reject("WRITE", {"code": &"output_reread_mismatch", "message": "staged bytes differ"})
		return
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		_reject("WRITE", {"code": &"output_rename_failed", "message": str(rename_error)})
		return
	print("MINESWEEPER_GENERATOR_BUDGET: WRITE_PASS %s" % path)
	quit(0)


func _reject(stage: String, envelope: Dictionary) -> void:
	printerr("MINESWEEPER_GENERATOR_BUDGET_%s_REJECTED: %s: %s" % [
		stage, str(envelope.get("code", &"")), str(envelope.get("message", "")),
	])
	quit(1)
