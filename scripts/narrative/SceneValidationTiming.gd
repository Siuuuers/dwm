extends RefCounted
## Opt-in process-local observations. Never a validation proof or saved state.
## Configuration includes compilation: these inclusive totals must not be summed.
static var _active := false
static var _record: Dictionary = {}
static var _started_us := 0

static func begin_scope(operation: String, state: String, stage: String, step: int) -> bool:
	if _active or OS.get_environment("DWM_SCENE_VALIDATION_PROFILE") != "1": return false
	_terminal_scope_ordinal += 1
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

# Controller-only terminal ledger diagnostics. Never merge into product source.
static var _terminal_scope_ordinal := 0
static var _terminal_diagnostic_ordinal := 0
static var _terminal_physical_proof_calls := 0

static func _terminal_diagnostic_enabled() -> bool:
	return OS.get_environment("DWM_TERMINAL_LEDGER_DIAGNOSTIC") == "1"

static func _terminal_physical_proof() -> void:
	if _terminal_diagnostic_enabled(): _terminal_physical_proof_calls += 1

static func _terminal_diagnostic_inputs(receipts: Dictionary, contacts: Dictionary) -> String:
	var writer: Script = load("res://scripts/validation/CanonicalJsonWriter.gd")
	var encoded: Dictionary = writer.stringify({"receipts": receipts, "contacts": contacts})
	return str(encoded.value).sha256_text() if encoded.get("ok", false) else "canonical_encoding_failed"

static func _terminal_diagnostic_owners(issuer: Object, creation_owner: Object) -> Dictionary:
	var root: Object = issuer.get("_root") if is_instance_valid(issuer) else null
	return {"issuer": issuer.get_instance_id() if is_instance_valid(issuer) else 0,
		"creation_owner": creation_owner.get_instance_id() if is_instance_valid(creation_owner) else 0,
		"issuer_root": root.get_instance_id() if is_instance_valid(root) else 0}

static func _terminal_diagnostic_begin(phase: String, receipts: Dictionary, contacts: Dictionary,
		issuer: Object, creation_owner: Object, context: Dictionary = {}) -> Dictionary:
	if not _terminal_diagnostic_enabled(): return {}
	_terminal_diagnostic_ordinal += 1
	# Hashing, caller discovery and identity reads precede the measured interval.
	var row := {"phase": phase, "ordinal": _terminal_diagnostic_ordinal,
		"process_id": OS.get_process_id(), "scope_ordinal": _terminal_scope_ordinal,
		"scope_active": _active, "operation": str(_record.get("operation", "outside_scope")),
		"completed_snapshot_count": _record.get("snapshot_validations", []).size(), "input_before": _terminal_diagnostic_inputs(receipts, contacts),
		"context_before": _terminal_diagnostic_inputs(context, {}),
		"owners_before": _terminal_diagnostic_owners(issuer, creation_owner), "callers": get_stack(),
		"physical_proof_before": _terminal_physical_proof_calls,
		"receipt_validation_before": int(_record.get("receipt_validation_calls", 0)),
		"diagnostic_only": true, "nested_inclusive": true}
	row["started_us"] = Time.get_ticks_usec()
	return row

static func _terminal_diagnostic_end(row: Dictionary, receipts: Dictionary, contacts: Dictionary,
		issuer: Object, creation_owner: Object, result: Dictionary, context: Dictionary = {}) -> void:
	var finished_us := Time.get_ticks_usec()
	if row.is_empty(): return
	row["elapsed_us"] = finished_us - int(row.started_us)
	row["physical_proof_attempts"] = _terminal_physical_proof_calls - int(row.physical_proof_before)
	row["receipt_validation_calls"] = int(_record.get("receipt_validation_calls", 0)) - int(row.receipt_validation_before)
	row["input_after"] = _terminal_diagnostic_inputs(receipts, contacts)
	row["context_after"] = _terminal_diagnostic_inputs(context, {})
	row["owners_after"] = _terminal_diagnostic_owners(issuer, creation_owner)
	row["ok"] = bool(result.get("ok", false))
	row["code"] = str(result.get("code", ""))
	print("DWM_TERMINAL_LEDGER_DIAGNOSTIC " + JSON.stringify(row))
