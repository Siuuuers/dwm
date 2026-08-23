class_name MinesweeperGeneratorKernel
extends RefCounted

## The one pure candidate/search kernel for bounded certified board generation (Plan 02 Task 4,
## dwm-p2r13). Used identically by the runtime adapter (mode candidate_search), the certified
## fallback builder (mode fallback_construction), and the benchmark tool (mode candidate_search).
## No fallback input, manifest loader, file I/O, clock, environment read, default operation limit,
## or internal unbounded loop -- every draw comes from the three explicit RNG states the caller
## restores/threads through begin()/advance(), and every verifier call is bounded by a limit this
## kernel computes (per_candidate_cost, see advance()) so it can never itself receive
## generation_budget_exhausted.
##
## GeneratorKernelSpec is the exact pure projection of BoardSpec with no board token or issuer-
## receipt member; production and tooling both build it, but only production first validates the
## complete trusted BoardSpec/nonce receipts (MinesweeperBoardGenerator's job, not this kernel's --
## the kernel cannot distinguish or authorize production identity).
##
## Candidate construction: the pool is every cell except forced_cell (and, when capability_ids
## contains "first_cell_zero", forced_cell's neighbors too). At the current extra_tier, a partial
## Fisher-Yates selection of the pool is drawn from placement_rng_state and its first
## base_mine_count+extra_tier cells become mine_indices for one verifier call. A rule-application
## step in MinesweeperNoGuessVerifier can never revisit an already-decided cell (each step strictly
## shrinks the undetermined set), so trace length is bounded by width*height-1; this kernel always
## offers verify() a budget of exactly width*height, which is therefore always sufficient for a
## DEFINITIVE resolution (certified or guess_required) -- generation_budget_exhausted can never
## occur from an internal call, so "operations" are accounted as a flat, exact, deterministic
## width*height per candidate attempted, regardless of outcome. This is a per-attempt *budget
## consumed* accounting, not a measure of the verifier's own (smaller, outcome-dependent) trace
## length; see task-4-report.md for the rationale.
##
## Extra-tier descent: extra_tier starts at min(requested_mine_count-base_mine_count, the maximum
## extra that structurally fits outside the exclusions) and descends by one after every
## guess_required candidate, wrapping back to that same maximum once tier 0 also fails -- an
## unbounded, deterministic, ever-continuing descending sweep. advance() stops (returns status
## "searching") as soon as fewer than width*height operations remain in its own operation_limit,
## never mid-candidate, so a slice never wastes a partial, unresumable verify() call.

const _RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")
const _VERIFIER := preload("res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd")

const MODE_CANDIDATE_SEARCH := &"candidate_search"
const MODE_FALLBACK_CONSTRUCTION := &"fallback_construction"
const MODES: Array[StringName] = [MODE_CANDIDATE_SEARCH, MODE_FALLBACK_CONSTRUCTION]

const STATUS_SEARCHING := &"searching"
const STATUS_CERTIFIED := &"certified"
const STATUS_EXHAUSTED := &"exhausted"
const STATUSES: Array[StringName] = [STATUS_SEARCHING, STATUS_CERTIFIED, STATUS_EXHAUSTED]

const _DISPOSITIONS: Array[String] = ["hatred", "upset", "amused"]

const SPEC_KEYS := [
	"schema_version", "board_kind", "difficulty_id", "width", "height", "base_mine_count",
	"raw_extra_mines", "requested_mine_count", "capability_ids", "placement_stream_id",
	"placement_nonce", "debug_stream_id", "debug_nonce", "explosion_stream_id", "explosion_nonce",
	"generator_version", "verifier_version",
]
const _BLANK_CHECK_FIELDS := [
	"difficulty_id", "placement_nonce", "debug_nonce", "explosion_nonce",
]
const _BOARD_KINDS := ["desktop", "solo_challenge", "pair_challenge"]
const _PLACEMENT_STREAM_ID := "minesweeper_placement_v1"
const _DEBUG_STREAM_ID := "minesweeper_debug_v1"
const _EXPLOSION_STREAM_ID := "minesweeper_explosion_v1"
const _GENERATOR_VERSION := "dwm_generator_v1"
const _VERIFIER_VERSION := "visible_deduction_v1"

const FRONTIER_KEYS := [
	"status", "mode", "spec", "forced_cell", "placement_rng_state", "debug_rng_state",
	"explosion_rng_state", "extra_tier", "candidate_ordinal", "candidate_state", "operations_used",
	"slice_sequence", "last_failure_code",
]


static func begin(kernel_spec: Dictionary, forced_cell: int, mode: StringName,
		placement_rng_state: Dictionary, debug_rng_state: Dictionary,
		explosion_rng_state: Dictionary) -> Dictionary:
	var spec_check := validate_spec(kernel_spec)
	if not spec_check.get("ok", false):
		return spec_check
	var spec: Dictionary = (spec_check["value"] as Dictionary)["spec"]
	if not MODES.has(mode):
		return _fail(&"invalid_mode", "mode must be candidate_search or fallback_construction", {"mode": mode})

	var width: int = int(spec["width"])
	var height: int = int(spec["height"])
	var total_cells: int = width * height
	if typeof(forced_cell) != TYPE_INT or forced_cell < 0 or forced_cell >= total_cells:
		return _fail(&"cell_index_out_of_range", "forced_cell is out of range", {"forced_cell": forced_cell})

	var placement_restored := _restore_rng(StringName(spec["placement_stream_id"]), String(spec["placement_nonce"]), placement_rng_state)
	if not placement_restored.get("ok", false):
		return placement_restored
	var debug_restored := _restore_rng(StringName(spec["debug_stream_id"]), String(spec["debug_nonce"]), debug_rng_state)
	if not debug_restored.get("ok", false):
		return debug_restored
	var explosion_restored := _restore_rng(StringName(spec["explosion_stream_id"]), String(spec["explosion_nonce"]), explosion_rng_state)
	if not explosion_restored.get("ok", false):
		return explosion_restored

	var capability_ids: Array = spec["capability_ids"]
	var zero_mode: bool = capability_ids.has("first_cell_zero")
	var excluded := excluded_cells(forced_cell, zero_mode, width, height)
	var available_cells: int = total_cells - excluded.size()
	var base_mine_count: int = int(spec["base_mine_count"])
	if base_mine_count > available_cells:
		return _fail(&"base_mine_count_infeasible",
			"base_mine_count does not fit outside the forced cell and its exclusions",
			{"base_mine_count": base_mine_count, "available_cells": available_cells})

	var effective_max_extra := _effective_max_extra(spec, available_cells)

	var frontier := {
		"status": STATUS_SEARCHING,
		"mode": mode,
		"spec": spec,
		"forced_cell": forced_cell,
		"placement_rng_state": (placement_restored["value"] as Dictionary)["state"],
		"debug_rng_state": (debug_restored["value"] as Dictionary)["state"],
		"explosion_rng_state": (explosion_restored["value"] as Dictionary)["state"],
		"extra_tier": effective_max_extra,
		"candidate_ordinal": 0,
		"candidate_state": null,
		"operations_used": 0,
		"slice_sequence": 0,
		"last_failure_code": null,
	}
	return {"ok": true, "code": &"ok", "value": {"preparation": frontier}, "receipt": {}}


static func advance(frontier: Dictionary, operation_limit: int) -> Dictionary:
	var shape := _exact_keys(frontier, FRONTIER_KEYS, &"frontier_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(operation_limit) != TYPE_INT or operation_limit <= 0:
		return _fail(&"invalid_operation_limit", "operation_limit must be a positive integer", {"operation_limit": operation_limit})
	if StringName(frontier.get("status", &"")) != STATUS_SEARCHING:
		return _fail(&"frontier_not_searching", "advance() requires a frontier with status=searching",
			{"status": frontier.get("status")})
	if not (frontier["mode"] is StringName or frontier["mode"] is String) or not MODES.has(StringName(frontier["mode"])):
		return _fail(&"invalid_mode", "frontier mode must be candidate_search or fallback_construction", {})
	var mode: StringName = StringName(frontier["mode"])

	var spec_check := validate_spec(frontier["spec"])
	if not spec_check.get("ok", false):
		return spec_check
	var spec: Dictionary = (spec_check["value"] as Dictionary)["spec"]

	var width: int = int(spec["width"])
	var height: int = int(spec["height"])
	var total_cells: int = width * height
	var forced_cell: int = int(frontier["forced_cell"])
	if forced_cell < 0 or forced_cell >= total_cells:
		return _fail(&"cell_index_out_of_range", "forced_cell is out of range", {"forced_cell": forced_cell})

	var capability_ids: Array = spec["capability_ids"]
	var zero_mode: bool = capability_ids.has("first_cell_zero")
	var excluded := excluded_cells(forced_cell, zero_mode, width, height)
	var pool: Array[int] = []
	for index in range(total_cells):
		if not excluded.has(index):
			pool.append(index)
	var base_mine_count: int = int(spec["base_mine_count"])
	var available_cells: int = pool.size()
	if base_mine_count > available_cells:
		return _fail(&"base_mine_count_infeasible", "base_mine_count does not fit", {})
	var effective_max_extra := _effective_max_extra(spec, available_cells)

	var placement_restored := _restore_rng(StringName(spec["placement_stream_id"]), String(spec["placement_nonce"]), frontier["placement_rng_state"])
	if not placement_restored.get("ok", false):
		return placement_restored
	var placement_rng: RefCounted = (placement_restored["value"] as Dictionary)["rng"]

	var extra_tier: int = int(frontier["extra_tier"])
	if extra_tier > effective_max_extra or extra_tier < 0:
		extra_tier = effective_max_extra
	var candidate_ordinal: int = int(frontier["candidate_ordinal"])
	var operations_used: int = int(frontier["operations_used"])
	var last_failure_code: Variant = frontier["last_failure_code"]

	var per_candidate_cost: int = total_cells
	var operations_spent_this_call := 0

	while operation_limit - operations_spent_this_call >= per_candidate_cost:
		var mine_count: int = base_mine_count + extra_tier
		var mine_indices: Array[int] = sample_mine_indices(pool, mine_count, placement_rng)
		mine_indices.sort()
		var layout := {
			"schema_version": 1, "width": width, "height": height,
			"mine_indices": mine_indices, "mine_count": mine_indices.size(),
		}
		var verified: Dictionary = _VERIFIER.verify(layout, forced_cell, per_candidate_cost)
		candidate_ordinal += 1
		operations_spent_this_call += per_candidate_cost
		operations_used += per_candidate_cost

		if verified.get("ok", false):
			var explosion_restored := _restore_rng(StringName(spec["explosion_stream_id"]), String(spec["explosion_nonce"]), frontier["explosion_rng_state"])
			if not explosion_restored.get("ok", false):
				return explosion_restored
			var explosion_rng: RefCounted = (explosion_restored["value"] as Dictionary)["rng"]
			var dispositions: Array[String] = []
			for _i in range(mine_indices.size()):
				var sampled: Dictionary = explosion_rng.sample_bounded(_DISPOSITIONS.size())
				if not sampled.get("ok", false):
					return sampled
				dispositions.append(_DISPOSITIONS[int((sampled["value"] as Dictionary)["result"])])
			return {"ok": true, "code": &"ok", "value": {"preparation": {
				"status": STATUS_CERTIFIED, "mode": mode, "spec": spec, "forced_cell": forced_cell,
				"placement_rng_state": placement_rng.capture()["value"],
				"debug_rng_state": (frontier["debug_rng_state"] as Dictionary).duplicate(true),
				"explosion_rng_state": explosion_rng.capture()["value"],
				"extra_tier": extra_tier, "candidate_ordinal": candidate_ordinal,
				"candidate_state": {
					"mine_indices": mine_indices, "mine_count": mine_indices.size(),
					"mine_dispositions": dispositions,
				},
				"operations_used": operations_used,
				"slice_sequence": int(frontier["slice_sequence"]) + 1, "last_failure_code": null,
			}}, "receipt": {}}

		var failure_code: StringName = StringName(verified.get("code", &"unknown_failure"))
		if failure_code != &"guess_required":
			# A technical/invariant failure (should be unreachable given the fixed per_candidate_cost
			# bound and exclusion-respecting candidate construction above) always fails closed rather
			# than silently substituting a guessing board.
			return verified
		last_failure_code = failure_code
		extra_tier -= 1
		if extra_tier < 0:
			extra_tier = effective_max_extra

	return {"ok": true, "code": &"ok", "value": {"preparation": {
		"status": STATUS_SEARCHING, "mode": mode, "spec": spec, "forced_cell": forced_cell,
		"placement_rng_state": placement_rng.capture()["value"],
		"debug_rng_state": (frontier["debug_rng_state"] as Dictionary).duplicate(true),
		"explosion_rng_state": (frontier["explosion_rng_state"] as Dictionary).duplicate(true),
		"extra_tier": extra_tier, "candidate_ordinal": candidate_ordinal,
		"candidate_state": frontier["candidate_state"],
		"operations_used": operations_used,
		"slice_sequence": int(frontier["slice_sequence"]) + 1, "last_failure_code": last_failure_code,
	}}, "receipt": {}}


## The exact GeneratorKernelSpec projection validator, mirroring MinesweeperBoardSchema.validate_spec
## for the fields this projection shares with BoardSpec (same types/closed values), minus the
## pressure/penalty/board-token/receipt members this projection deliberately excludes.
static func validate_spec(spec: Dictionary) -> Dictionary:
	var shape := _exact_keys(spec, SPEC_KEYS, &"spec_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(spec["schema_version"]) != TYPE_INT or int(spec["schema_version"]) != 1:
		return _fail(&"spec_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})
	var board_kind: Variant = spec["board_kind"]
	if typeof(board_kind) != TYPE_STRING or not _BOARD_KINDS.has(String(board_kind)):
		return _fail(&"spec_field_invalid", "board_kind must be one of the frozen kinds", {"field": "board_kind"})
	for field: String in _BLANK_CHECK_FIELDS:
		var nonblank := _nonblank_string(spec.get(field), field)
		if not nonblank.get("ok", false):
			return nonblank

	var width_v: Variant = spec["width"]
	if typeof(width_v) != TYPE_INT or int(width_v) <= 0:
		return _fail(&"spec_field_invalid", "width must be a positive integer", {"field": "width"})
	var height_v: Variant = spec["height"]
	if typeof(height_v) != TYPE_INT or int(height_v) <= 0:
		return _fail(&"spec_field_invalid", "height must be a positive integer", {"field": "height"})
	var base_mine_count_v: Variant = spec["base_mine_count"]
	if typeof(base_mine_count_v) != TYPE_INT or int(base_mine_count_v) < 0:
		return _fail(&"spec_field_invalid", "base_mine_count must be a nonnegative integer", {"field": "base_mine_count"})
	var raw_extra_v: Variant = spec["raw_extra_mines"]
	if typeof(raw_extra_v) != TYPE_INT or int(raw_extra_v) < 0:
		return _fail(&"spec_field_invalid", "raw_extra_mines must be a nonnegative integer", {"field": "raw_extra_mines"})

	var requested_v: Variant = spec["requested_mine_count"]
	if typeof(requested_v) != TYPE_INT:
		return _fail(&"spec_field_invalid", "requested_mine_count must be an integer", {"field": "requested_mine_count"})
	var requested: int = int(requested_v)
	var base: int = int(base_mine_count_v)
	var raw_extra: int = int(raw_extra_v)
	if requested < base or requested > base + raw_extra:
		return _fail(&"spec_field_invalid",
			"requested_mine_count must be between base_mine_count and base_mine_count+raw_extra_mines",
			{"field": "requested_mine_count"})
	if requested > int(width_v) * int(height_v) - 1:
		return _fail(&"spec_field_invalid", "requested_mine_count must leave at least one safe cell",
			{"field": "requested_mine_count"})

	var capability_ids: Variant = spec["capability_ids"]
	if typeof(capability_ids) != TYPE_ARRAY:
		return _fail(&"spec_field_invalid", "capability_ids must be an array", {"field": "capability_ids"})
	for entry: Variant in (capability_ids as Array):
		if typeof(entry) != TYPE_STRING:
			return _fail(&"spec_field_invalid", "capability_ids must contain only strings", {"field": "capability_ids"})

	if String(spec["placement_stream_id"]) != _PLACEMENT_STREAM_ID:
		return _fail(&"spec_field_invalid", "placement_stream_id is frozen", {"field": "placement_stream_id"})
	if String(spec["debug_stream_id"]) != _DEBUG_STREAM_ID:
		return _fail(&"spec_field_invalid", "debug_stream_id is frozen", {"field": "debug_stream_id"})
	if String(spec["explosion_stream_id"]) != _EXPLOSION_STREAM_ID:
		return _fail(&"spec_field_invalid", "explosion_stream_id is frozen", {"field": "explosion_stream_id"})
	if String(spec["generator_version"]) != _GENERATOR_VERSION:
		return _fail(&"spec_field_invalid", "generator_version is frozen", {"field": "generator_version"})
	if String(spec["verifier_version"]) != _VERIFIER_VERSION:
		return _fail(&"spec_field_invalid", "verifier_version is frozen", {"field": "verifier_version"})

	return {"ok": true, "code": &"ok", "value": {"spec": spec.duplicate(true)}, "receipt": {}}


static func is_legal_status(status: Variant) -> bool:
	if not (status is StringName or status is String):
		return false
	return STATUSES.has(StringName(status))


# ---- shared helpers ----

static func _effective_max_extra(spec: Dictionary, available_cells: int) -> int:
	var base_mine_count: int = int(spec["base_mine_count"])
	var requested_extra: int = int(spec["requested_mine_count"]) - base_mine_count
	var max_fit_extra: int = available_cells - base_mine_count
	var effective: int = mini(requested_extra, max_fit_extra)
	return maxi(effective, 0)


static func _restore_rng(stream_id: StringName, nonce: String, state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return _fail(&"rng_state_shape_invalid", "rng state must be a dictionary", {})
	var rng: RefCounted = _RNG.new()
	var seeded: Dictionary = rng.seed(stream_id, nonce)
	if not seeded.get("ok", false):
		return seeded
	var restored: Dictionary = rng.prepare_restore(state)
	if not restored.get("ok", false):
		return restored
	return {"ok": true, "code": &"ok", "value": {"rng": rng, "state": restored["value"]}, "receipt": {}}


static func excluded_cells(forced_cell: int, zero_mode: bool, width: int, height: int) -> Dictionary:
	var excluded: Dictionary = {forced_cell: true}
	if zero_mode:
		for neighbor: int in _neighbors(forced_cell, width, height):
			excluded[neighbor] = true
	return excluded


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


## Partial Fisher-Yates selection of `mine_count` elements from `pool`, driven entirely by
## `rng.sample_bounded()`; `pool` itself is never mutated. Only min(mine_count, pool.size()-1)
## swaps are performed (not a full pool.size()-1 shuffle) -- the well-known partial-shuffle
## technique for drawing a uniform random k-subset in random order, load-bearing for expert-board
## performance where pool.size() can be ~475 but mine_count is far smaller. Every draw advances
## rng's own internal state (and therefore its draw_count), which is exactly the "mine
## permutations ... consume only minesweeper_placement_v1" law.
static func sample_mine_indices(pool: Array[int], mine_count: int, rng: RefCounted) -> Array[int]:
	var working: Array[int] = pool.duplicate()
	var n: int = working.size()
	var limit: int = mini(mine_count, n - 1)
	for i in range(limit):
		var drawn: Dictionary = rng.sample_bounded(n - i)
		var j: int = i + int((drawn["value"] as Dictionary)["result"])
		var tmp: int = working[i]
		working[i] = working[j]
		working[j] = tmp
	return working.slice(0, mine_count)


static func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(code, "value must be a dictionary", {})
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _nonblank_string(value: Variant, field: String) -> Dictionary:
	if typeof(value) != TYPE_STRING:
		return _fail(&"spec_field_invalid", "%s must be a string" % field, {"field": field})
	if String(value).strip_edges().is_empty():
		return _fail(&"spec_field_invalid", "%s must be nonblank" % field, {"field": field})
	return {"ok": true}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
