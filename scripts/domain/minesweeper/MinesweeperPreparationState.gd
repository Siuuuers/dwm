class_name MinesweeperPreparationState
extends RefCounted

## State-transition guard around MinesweeperGeneratorKernel's frontier (Plan 02 Task 4, dwm-p2r13).
## The kernel is the one pure search algorithm; this class independently RE-VALIDATES every
## preparation dictionary it is handed (never trusting a caller-supplied transition at face value)
## so a round-tripped/persisted/save-restored frontier -- or a slice_result forged by a
## non-kernel caller -- can never smuggle in an inconsistent spec, a rewound slice_sequence, or an
## illegal status. No preparation state may be derived from another except by walking through
## make()/advance() in order; each call recomputes/re-checks the full shape rather than patching.

const _KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")


## Begins a new preparation by delegating to the kernel and then independently re-validating its
## own output before returning it.
static func make(kernel_spec: Dictionary, forced_cell: int, mode: StringName,
		placement_rng_state: Dictionary, debug_rng_state: Dictionary,
		explosion_rng_state: Dictionary) -> Dictionary:
	var begun: Dictionary = _KERNEL.begin(kernel_spec, forced_cell, mode,
		placement_rng_state, debug_rng_state, explosion_rng_state)
	if not begun.get("ok", false):
		return begun
	return validate((begun["value"] as Dictionary)["preparation"])


## Standalone structural/semantic validation of a preparation dictionary: exact frontier shape,
## a spec that itself passes the kernel's GeneratorKernelSpec validation, a legal status, a
## forced_cell in range, and (for a certified preparation) a well-formed candidate_state whose
## mine_indices/mine_dispositions agree in size and stay inside the board and outside the forced
## cell/its zero-mode exclusions.
static func validate(state: Dictionary) -> Dictionary:
	var shape := _exact_keys(state, _KERNEL.FRONTIER_KEYS, &"preparation_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if not _KERNEL.is_legal_status(state.get("status")):
		return _fail(&"preparation_status_invalid", "status must be searching, certified, or exhausted",
			{"status": state.get("status")})
	var status: StringName = StringName(state["status"])

	if not (state["mode"] is StringName or state["mode"] is String) or not _KERNEL.MODES.has(StringName(state["mode"])):
		return _fail(&"preparation_mode_invalid", "mode must be candidate_search or fallback_construction", {})

	var spec_check: Dictionary = _KERNEL.validate_spec(state["spec"])
	if not spec_check.get("ok", false):
		return spec_check
	var spec: Dictionary = (spec_check["value"] as Dictionary)["spec"]
	var width: int = int(spec["width"])
	var height: int = int(spec["height"])
	var total_cells: int = width * height

	var forced_cell_v: Variant = state["forced_cell"]
	if typeof(forced_cell_v) != TYPE_INT or int(forced_cell_v) < 0 or int(forced_cell_v) >= total_cells:
		return _fail(&"preparation_forced_cell_invalid", "forced_cell must be a valid cell index", {})
	var forced_cell: int = int(forced_cell_v)

	for field: String in ["placement_rng_state", "debug_rng_state", "explosion_rng_state"]:
		if typeof(state[field]) != TYPE_DICTIONARY:
			return _fail(&"preparation_rng_state_invalid", "%s must be a dictionary" % field, {"field": field})
	var placement_ok := _rng_state_matches(spec, "placement_stream_id", "placement_nonce", state["placement_rng_state"])
	if not placement_ok.get("ok", false):
		return placement_ok
	var debug_ok := _rng_state_matches(spec, "debug_stream_id", "debug_nonce", state["debug_rng_state"])
	if not debug_ok.get("ok", false):
		return debug_ok
	var explosion_ok := _rng_state_matches(spec, "explosion_stream_id", "explosion_nonce", state["explosion_rng_state"])
	if not explosion_ok.get("ok", false):
		return explosion_ok

	if typeof(state["extra_tier"]) != TYPE_INT or int(state["extra_tier"]) < 0:
		return _fail(&"preparation_extra_tier_invalid", "extra_tier must be a nonnegative integer", {})
	if typeof(state["candidate_ordinal"]) != TYPE_INT or int(state["candidate_ordinal"]) < 0:
		return _fail(&"preparation_candidate_ordinal_invalid", "candidate_ordinal must be a nonnegative integer", {})
	if typeof(state["operations_used"]) != TYPE_INT or int(state["operations_used"]) < 0:
		return _fail(&"preparation_operations_used_invalid", "operations_used must be a nonnegative integer", {})
	if typeof(state["slice_sequence"]) != TYPE_INT or int(state["slice_sequence"]) < 0:
		return _fail(&"preparation_slice_sequence_invalid", "slice_sequence must be a nonnegative integer", {})

	var last_failure_code: Variant = state["last_failure_code"]
	if last_failure_code != null and not (last_failure_code is StringName or last_failure_code is String):
		return _fail(&"preparation_last_failure_code_invalid",
			"last_failure_code must be null or a string/StringName", {})

	var candidate_state: Variant = state["candidate_state"]
	if status == _KERNEL.STATUS_CERTIFIED:
		var candidate_check := _validate_candidate_state(candidate_state, spec, forced_cell, width, height)
		if not candidate_check.get("ok", false):
			return candidate_check
	elif candidate_state != null and typeof(candidate_state) != TYPE_DICTIONARY:
		return _fail(&"preparation_candidate_state_invalid",
			"candidate_state must be null or a dictionary while not certified", {})

	return {"ok": true, "code": &"ok", "value": {"preparation": state.duplicate(true)}, "receipt": {}}


## Validates that `slice_result` (the envelope MinesweeperGeneratorKernel.advance() returned) is a
## legal continuation of `state`: both independently validate, the spec/mode/forced_cell are
## byte-identical, slice_sequence increments by exactly one, and status only ever transitions
## searching->searching, searching->certified, or searching->exhausted (never out of a terminal
## status, and never a rewind).
static func advance(state: Dictionary, slice_result: Dictionary) -> Dictionary:
	var current_check := validate(state)
	if not current_check.get("ok", false):
		return current_check
	var current: Dictionary = (current_check["value"] as Dictionary)["preparation"]
	if StringName(current["status"]) != _KERNEL.STATUS_SEARCHING:
		return _fail(&"preparation_not_searching", "advance() requires a searching preparation", {})

	if not slice_result.get("ok", false):
		return _fail(&"preparation_slice_result_failed", "slice_result did not succeed",
			{"code": slice_result.get("code", &"")})
	var slice_value: Variant = slice_result.get("value")
	if typeof(slice_value) != TYPE_DICTIONARY or not (slice_value as Dictionary).has("preparation"):
		return _fail(&"preparation_slice_result_shape_invalid",
			"slice_result.value.preparation is required", {})
	var next_check := validate((slice_value as Dictionary)["preparation"])
	if not next_check.get("ok", false):
		return next_check
	var next_state: Dictionary = (next_check["value"] as Dictionary)["preparation"]

	if next_state["spec"] != current["spec"]:
		return _fail(&"preparation_spec_drifted", "spec must not change across a slice", {})
	if StringName(next_state["mode"]) != StringName(current["mode"]):
		return _fail(&"preparation_mode_drifted", "mode must not change across a slice", {})
	if int(next_state["forced_cell"]) != int(current["forced_cell"]):
		return _fail(&"preparation_forced_cell_drifted", "forced_cell must not change across a slice", {})
	if int(next_state["slice_sequence"]) != int(current["slice_sequence"]) + 1:
		return _fail(&"preparation_slice_sequence_invalid",
			"slice_sequence must advance by exactly one", {})
	if int(next_state["operations_used"]) < int(current["operations_used"]):
		return _fail(&"preparation_operations_used_regressed",
			"operations_used must never decrease across a slice", {})
	var next_status: StringName = StringName(next_state["status"])
	if next_status != _KERNEL.STATUS_SEARCHING and next_status != _KERNEL.STATUS_CERTIFIED \
			and next_status != _KERNEL.STATUS_EXHAUSTED:
		return _fail(&"preparation_status_invalid", "illegal status transition", {})

	return {"ok": true, "code": &"ok", "value": {"preparation": next_state}, "receipt": {}}


# ---- shared helpers ----

static func _rng_state_matches(spec: Dictionary, stream_id_field: String, nonce_field: String,
		state: Dictionary) -> Dictionary:
	if not (state.has("stream_id") and state.has("nonce")):
		return _fail(&"preparation_rng_state_invalid", "rng state must declare stream_id and nonce",
			{"field": stream_id_field})
	if StringName(state["stream_id"]) != StringName(spec[stream_id_field]):
		return _fail(&"preparation_rng_state_stream_mismatch",
			"rng state stream_id does not match the frozen projection", {"field": stream_id_field})
	if String(state["nonce"]) != String(spec[nonce_field]):
		return _fail(&"preparation_rng_state_nonce_mismatch",
			"rng state nonce does not match the frozen projection", {"field": nonce_field})
	return {"ok": true}


static func _validate_candidate_state(candidate_state: Variant, spec: Dictionary, forced_cell: int,
		width: int, height: int) -> Dictionary:
	if typeof(candidate_state) != TYPE_DICTIONARY:
		return _fail(&"preparation_candidate_state_invalid",
			"a certified preparation must carry a candidate_state dictionary", {})
	var candidate: Dictionary = candidate_state
	var expected_keys := ["mine_indices", "mine_count", "mine_dispositions"]
	if candidate.size() != expected_keys.size():
		return _fail(&"preparation_candidate_state_invalid", "candidate_state has the wrong member set", {})
	for key: String in expected_keys:
		if not candidate.has(key):
			return _fail(&"preparation_candidate_state_invalid", "candidate_state is missing %s" % key, {})

	var total_cells: int = width * height
	var mine_indices_v: Variant = candidate["mine_indices"]
	if typeof(mine_indices_v) != TYPE_ARRAY:
		return _fail(&"preparation_candidate_state_invalid", "mine_indices must be an array", {})
	var seen: Dictionary = {}
	var capability_ids: Array = spec["capability_ids"]
	var zero_mode: bool = capability_ids.has("first_cell_zero")
	var excluded := _KERNEL.excluded_cells(forced_cell, zero_mode, width, height)
	for entry: Variant in (mine_indices_v as Array):
		if typeof(entry) != TYPE_INT:
			return _fail(&"preparation_candidate_state_invalid", "mine_indices must contain only integers", {})
		var index: int = int(entry)
		if index < 0 or index >= total_cells or excluded.has(index):
			return _fail(&"preparation_candidate_state_invalid",
				"mine_indices may never contain the forced cell or its exclusions", {"cell_index": index})
		if seen.has(index):
			return _fail(&"preparation_candidate_state_invalid", "mine_indices must not repeat", {})
		seen[index] = true
	if typeof(candidate["mine_count"]) != TYPE_INT or int(candidate["mine_count"]) != (mine_indices_v as Array).size():
		return _fail(&"preparation_candidate_state_invalid", "mine_count must equal mine_indices.size()", {})
	var dispositions_v: Variant = candidate["mine_dispositions"]
	if typeof(dispositions_v) != TYPE_ARRAY or (dispositions_v as Array).size() != (mine_indices_v as Array).size():
		return _fail(&"preparation_candidate_state_invalid",
			"mine_dispositions must have exactly one entry per mine", {})
	for entry: Variant in (dispositions_v as Array):
		if typeof(entry) != TYPE_STRING or not ["hatred", "upset", "amused"].has(String(entry)):
			return _fail(&"preparation_candidate_state_invalid", "an unknown mine disposition was recorded", {})
	return {"ok": true}


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
