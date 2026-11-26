class_name MinesweeperGeneratorKernel
extends RefCounted


const _SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
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

const SPEC_KEYS := _SCHEMA.GENERATOR_SPEC_KEYS
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
	var shape := _SCHEMA.check_keys(frontier, FRONTIER_KEYS, &"frontier_member_set_invalid")
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
				"debug_rng_state": (frontier["debug_rng_state"] as Dictionary).duplicate(),
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
			return verified
		last_failure_code = failure_code
		extra_tier -= 1
		if extra_tier < 0:
			extra_tier = effective_max_extra

	return {"ok": true, "code": &"ok", "value": {"preparation": {
		"status": STATUS_SEARCHING, "mode": mode, "spec": spec, "forced_cell": forced_cell,
		"placement_rng_state": placement_rng.capture()["value"],
		"debug_rng_state": (frontier["debug_rng_state"] as Dictionary).duplicate(),
		"explosion_rng_state": (frontier["explosion_rng_state"] as Dictionary).duplicate(),
		"extra_tier": extra_tier, "candidate_ordinal": candidate_ordinal,
		"candidate_state": null,
		"operations_used": operations_used,
		"slice_sequence": int(frontier["slice_sequence"]) + 1, "last_failure_code": last_failure_code,
	}}, "receipt": {}}


static func validate_spec(spec: Dictionary) -> Dictionary:
	var checked := _SCHEMA.check_spec(spec, true)
	if not checked.ok: return checked
	var detached := spec.duplicate()
	detached["capability_ids"] = spec.capability_ids.duplicate()
	return {"ok": true, "code": &"ok", "value": {"spec": detached}, "receipt": {}}


static func is_legal_status(status: Variant) -> bool:
	if not (status is StringName or status is String):
		return false
	return STATUSES.has(StringName(status))



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
		for neighbor: int in _SCHEMA.neighbors(forced_cell, width, height):
			excluded[neighbor] = true
	return excluded


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


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
