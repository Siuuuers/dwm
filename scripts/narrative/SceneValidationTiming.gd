extends RefCounted
## Opt-in process-local observations. Never a validation proof or saved state.
## Configuration includes compilation: these inclusive totals must not be summed.
static var _active := false
static var _record: Dictionary = {}
static var _started_us := 0

static func begin_scope(operation: String, state: String, stage: String, step: int) -> bool:
	if _active or OS.get_environment("DWM_SCENE_VALIDATION_PROFILE") != "1": return false
	_record = {"operation": operation, "lifecycle_state": state, "playback_stage": stage,
		"next_step_index": step, "configuration_calls": 0, "configuration_us": 0,
		"configuration_failures": 0, "compilation_calls": 0, "compilation_us": 0,
		"compilation_failures": 0, "physical_proof_calls": 0, "physical_proof_us": 0,
		"physical_proof_failures": 0, "receipt_validation_calls": 0, "receipt_validation_us": 0,
		"receipt_validation_failures": 0, "bundle_validation_calls": 0, "bundle_validation_us": 0,
		"bundle_validation_failures": 0, "inclusive_nested": true, "snapshot_validations": []}
	_started_us = Time.get_ticks_usec()
	_active = true
	return true

static func start_sample() -> int:
	return Time.get_ticks_usec() if _active else -1

static func finish_sample(kind: String, started_us: int, ok: bool) -> void:
	if started_us < 0 or not _active: return
	_record[kind + "_calls"] += 1
	_record[kind + "_us"] += Time.get_ticks_usec() - started_us
	if not ok: _record[kind + "_failures"] += 1

## Snapshot phases are inclusive children of the existing operation scope.
## This helper has no dependency on the schema whose calls it observes.
static func snapshot_phase(observation: Dictionary, phase: String, started_us: int) -> int:
	if observation.is_empty(): return 0
	var now: int = Time.get_ticks_usec()
	observation[phase] = now - started_us
	return now

static func finish_snapshot(started_us: int, observation: Dictionary, ok: bool) -> void:
	if started_us < 0 or not _active: return
	var records: Array = _record["snapshot_validations"]
	observation["elapsed_us"] = Time.get_ticks_usec() - started_us
	observation["ok"] = ok
	# Ordinal is completion order; an interrupted call emits no fabricated record.
	observation["ordinal"] = records.size()
	records.append(observation)

static func end_scope(ok: bool) -> void:
	if not _active: return
	_record["elapsed_us"] = Time.get_ticks_usec() - _started_us
	_record["ok"] = ok
	_active = false
	print("DWM_SCENE_VALIDATION_PROFILE " + JSON.stringify(_record))
	_record = {}
	_started_us = 0
