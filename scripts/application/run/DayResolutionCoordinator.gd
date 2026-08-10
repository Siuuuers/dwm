class_name DayResolutionCoordinator
extends RefCounted

## Atomic day-resolution completion engine behind the GameState facade
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).

const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const GATE_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const STATE_PORT_METHODS: Array[String] = [
	"begin_or_resume", "inspect_next_stage", "begin_next_stage",
	"prepare_completion", "capture", "commit", "rollback", "publish",
]
const CHECKPOINT_PORT_METHODS: Array[String] = [
	"preview_checkpoint_id", "capture", "prepare", "commit", "rollback",
]

const STAGE_CONTRACTS := {
	"lock_day": {"owner_id": "day_resolution_coordinator", "kind": "day_lock",
		"value": {"locked": "const_true"}},
	"validate_schedule": {"owner_id": "schedule_rules", "kind": "schedule_validation",
		"value": {"schedule_digest": "string", "ordered_entry_ids": "array_string"}},
	"execute_schedule_entries": {"owner_id": "schedule_rules", "kind": "schedule_entries_complete",
		"value": {"entry_receipt_ids": "array_string"}},
	"commit_outcomes": {"owner_id": "game_state", "kind": "outcomes_commit",
		"value": {"outcome_ids": "array_string", "effect_transaction_ids": "array_string"}},
	"hospital_if_triggered": {"owner_id": "dating_ending_rules", "kind": "hospital_resolution",
		"value": {"required": "bool", "route_receipt_id": "string_or_null", "prevented_entry_id": "string_or_null"}},
	"twofriends_if_deferred": {"owner_id": "contact_invitation_state", "kind": "twofriends_resolution",
		"value": {"required": "bool", "route_receipt_id": "string_or_null", "message_transaction_ids": "array_string"}},
	"invitation_rollover": {"owner_id": "contact_invitation_state", "kind": "invitation_rollover",
		"value": {"target_day": "int", "message_transaction_ids": "array_string"}},
	"increment_day": {"owner_id": "run_lifecycle", "kind": "day_increment",
		"value": {"source_day": "int", "target_day": "int"}},
	"reset_day_scope": {"owner_id": "game_state", "kind": "day_scope_reset",
		"value": {"target_day": "int", "reset_ids": "array_string"}},
	"new_day_autosave": {"owner_id": "save_manager", "kind": "disk_checkpoint_request",
		"value": {"save_kind": "const_autosave", "save_reason": "const_day_start"}},
	"unlock_day": {"owner_id": "day_resolution_coordinator", "kind": "day_unlock",
		"value": {"locked": "const_false"}},
	"close_invitations_run_end": {"owner_id": "contact_invitation_state", "kind": "run_end_close",
		"value": {"resolved_action_ids": "array_string"}},
	"resolve_ending_plan": {"owner_id": "dating_ending_rules", "kind": "ending_resolution",
		"value": {"ending_plan": "dictionary"}},
	"enter_ending": {"owner_id": "run_lifecycle", "kind": "enter_ending",
		"value": {"state": "const_ending_state", "primary_id": "string", "epilogue_id": "string_or_null"}},
	"ending_autosave": {"owner_id": "save_manager", "kind": "disk_checkpoint_request",
		"value": {"save_kind": "const_autosave", "save_reason": "const_ending"}},
}

const SUBSTAGE_CONTRACTS := {
	"route_complete": {"owner_id": "scene_router", "value": {"route_receipt_id": "string"}},
	"schedule_entry_complete": {"owner_id": "schedule_rules",
		"value": {"entry_receipt_id": "string", "outcome_ids": "array_string"}},
	"effect_transaction": {"owner_id": "effect_resolver",
		"value": {"transaction_id": "string", "effect_ids": "array_string"}},
}

var _gate: Object = null
var _state_port: Object = null
var _checkpoint_port: Object = null
var _run_id := ""
var _awaiting: Dictionary = {}
var _registered_history: Dictionary = {}

func configure_fatal_latch(gate: Object) -> Dictionary:
	if not _is_valid_gate(gate):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	if _gate != null:
		if gate == _gate:
			return _gate_identity_result(true)
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	_gate = gate
	return _gate_identity_result(false)

## Read-only accessor so Bootstrap can inject the day-resolution checkpoint providers into the
## exact configured state port (dwm-7e6). It exposes no mutation and creates nothing.
func get_state_port() -> Object:
	return _state_port

func configure(state_port: Object, checkpoint_port: Object) -> Dictionary:
	if _gate == null:
		return {"ok": false, "code": &"fatal_latch_not_configured", "message": ""}
	if state_port == null or not _has_all_methods(state_port, STATE_PORT_METHODS):
		return {"ok": false, "code": &"invalid_state_port", "message": ""}
	if checkpoint_port == null or not _has_all_methods(checkpoint_port, CHECKPOINT_PORT_METHODS):
		return {"ok": false, "code": &"invalid_checkpoint_port", "message": ""}
	_state_port = state_port
	_checkpoint_port = checkpoint_port
	return {"ok": true, "code": &"ok"}

func request_schedule_done(command_id: String) -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	if _state_port == null or _checkpoint_port == null:
		return {"ok": false, "code": &"ports_not_configured", "message": ""}
	if command_id.is_empty():
		return {"ok": false, "code": &"invalid_command_id", "message": ""}
	var begun: Dictionary = _state_port.begin_or_resume(command_id)
	if not begun.get("ok", false):
		return begun
	_run_id = str((begun.get("value", {}) as Dictionary).get("run_id", _run_id))
	return resume()

func resume() -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	if _state_port == null or _checkpoint_port == null:
		return {"ok": false, "code": &"ports_not_configured", "message": ""}
	while true:
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false):
			return cursor
		if not cursor["value"]["has_stage"]:
			var preview: Dictionary = _checkpoint_port.preview_checkpoint_id(_run_id)
			if not preview.get("ok", false):
				return preview
			return {"ok": true, "code": &"plan_complete",
				"value": {"checkpoint_id": str(preview["value"]["checkpoint_id"])}}
		var begun: Dictionary = _state_port.begin_next_stage()
		if not begun.get("ok", false):
			return begun
		var mode: StringName = begun["value"]["mode"]
		var stage: Dictionary = begun["value"]["stage"]
		if mode == &"await_registered_command":
			var command: Dictionary = begun["value"]["command"]
			_awaiting = command.duplicate(true)
			_registered_history[str(command["transaction_id"])] = command.duplicate(true)
			return {"ok": true, "code": &"await_registered_command",
				"value": {"stage": stage, "command": command}}
		var completed := _commit_completion(stage, begun["value"]["receipt"])
		if not completed.get("ok", false):
			return completed
	return {"ok": false, "code": &"unreachable", "message": ""}

func complete_route_stage(transaction_id: String, receipt: Dictionary) -> Dictionary:
	var fatal := _fatal_guard()
	if not fatal.is_empty():
		return fatal
	var command: Dictionary = {}
	if not _awaiting.is_empty() and str(_awaiting.get("transaction_id", "")) == transaction_id:
		command = _awaiting
	elif _registered_history.has(transaction_id):
		command = _registered_history[transaction_id]
	else:
		return {"ok": false, "code": &"unknown_transaction", "message": transaction_id}
	var stage_id := str(command["stage_id"])
	var envelope_error := _validate_envelope(stage_id, receipt)
	if envelope_error != "":
		return {"ok": false, "code": &"invalid_receipt", "message": envelope_error}
	var completed := _commit_completion(
		{"stage_id": stage_id, "transaction_id": transaction_id}, receipt)
	if not completed.get("ok", false):
		return completed
	if completed.get("code") == &"duplicate_transaction":
		return completed
	_awaiting = {}
	return resume()

func _commit_completion(stage: Dictionary, receipt: Dictionary) -> Dictionary:
	var stage_id := str(stage["stage_id"])
	var transaction_id := str(stage["transaction_id"])
	var envelope_error := _validate_envelope(stage_id, receipt)
	if envelope_error != "":
		return {"ok": false, "code": &"invalid_receipt", "message": envelope_error}
	var state_capture: Dictionary = _state_port.capture()
	if not state_capture.get("ok", false):
		return state_capture
	var state_backup: Dictionary = state_capture["value"]["backup"]
	var checkpoint_capture: Dictionary = _checkpoint_port.capture()
	if not checkpoint_capture.get("ok", false):
		return checkpoint_capture
	var checkpoint_backup: Dictionary = checkpoint_capture["value"]["backup"]
	var prepared: Dictionary = _state_port.prepare_completion(transaction_id, receipt)
	if not prepared.get("ok", false):
		return prepared
	if bool(prepared["value"].get("duplicate", false)):
		var current_id := "%s:%d" % [str(checkpoint_backup.get("run_id", _run_id)),
			int(checkpoint_backup.get("sequence", 0))]
		return {"ok": true, "code": &"duplicate_transaction", "value": {
			"receipt": prepared["value"].get("stored_receipt"),
			"checkpoint_id": current_id,
		}}
	var checkpoint_kind: StringName = &"day_start" if stage_id == "new_day_autosave" else &"day_resolution_stage"
	var prepared_checkpoint: Dictionary = _checkpoint_port.prepare(
		prepared["value"]["snapshot_input"], checkpoint_kind, _disk_write_for(stage_id))
	if not prepared_checkpoint.get("ok", false):
		return prepared_checkpoint
	var checkpoint_commit: Dictionary = _checkpoint_port.commit(prepared_checkpoint["value"]["candidate"])
	if not checkpoint_commit.get("ok", false):
		var checkpoint_rollback: Dictionary = _checkpoint_port.rollback(checkpoint_backup)
		if not checkpoint_rollback.get("ok", false):
			return _fatal_rollback("checkpoint_commit", transaction_id, stage_id, [
				_raw_diagnostic("checkpoint_port", "rollback", checkpoint_rollback),
			])
		return checkpoint_commit
	var state_commit: Dictionary = _state_port.commit(prepared["value"]["run_candidate"])
	if not state_commit.get("ok", false):
		return _recover_both("state_commit", transaction_id, stage_id,
			state_backup, checkpoint_backup, state_commit)
	var published: Dictionary = _state_port.publish(prepared["value"]["publication"])
	if not published.get("ok", false):
		return _recover_both("publish", transaction_id, stage_id,
			state_backup, checkpoint_backup, published)
	return {"ok": true, "code": &"stage_completed", "value": {
		"receipt": receipt.duplicate(true),
		"checkpoint_id": str(checkpoint_commit["value"]["checkpoint_id"]),
	}}

func _recover_both(
		phase: String, transaction_id: String, stage_id: String,
		state_backup: Dictionary, checkpoint_backup: Dictionary,
		original_failure: Dictionary
) -> Dictionary:
	var state_rollback: Dictionary = _state_port.rollback(state_backup)
	var checkpoint_rollback: Dictionary = _checkpoint_port.rollback(checkpoint_backup)
	if state_rollback.get("ok", false) and checkpoint_rollback.get("ok", false):
		return original_failure
	return _fatal_rollback(phase, transaction_id, stage_id, [
		_raw_diagnostic("state_port", "rollback", state_rollback),
		_raw_diagnostic("checkpoint_port", "rollback", checkpoint_rollback),
	])

func _fatal_rollback(
		phase: String, transaction_id: String, stage_id: String,
		raw_diagnostics: Array
) -> Dictionary:
	var already_retained := false
	for diagnostic: Dictionary in raw_diagnostics:
		var result: Dictionary = diagnostic.get("result", {})
		if str(result.get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			"day_resolution", phase, "fatal_rollback_failed",
			{"transaction_id": transaction_id, "stage_id": stage_id},
			raw_diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false):
			var failure: Dictionary = projected["value"]["failure"]
			if PROJECTOR.validate_failure(failure).get("ok", false):
				candidate = failure
		_gate.latch_fatal(candidate)
	return _gate.guard_external(&"day_resolution_recovery")

func _fatal_guard() -> Dictionary:
	if _gate != null and _gate.is_fatal_latched():
		return _gate.guard_external(&"day_resolution_recovery")
	return {}

static func _raw_diagnostic(owner_id: String, operation: String, result: Dictionary) -> Dictionary:
	return {"owner_id": owner_id, "operation": operation, "result": result}

static func _disk_write_for(stage_id: String) -> Dictionary:
	match stage_id:
		"new_day_autosave":
			return {"kind": &"autosave", "reason": &"day_start"}
		"ending_autosave":
			return {"kind": &"autosave", "reason": &"ending"}
	return {"kind": &"none", "reason": &"stage"}

static func _validate_envelope(stage_id: String, receipt: Dictionary) -> String:
	var keys := receipt.keys()
	keys.sort()
	if keys != ["kind", "owner_id", "value"]:
		return "receipt must have exactly owner_id/kind/value"
	if not STAGE_CONTRACTS.has(stage_id):
		return "unknown stage: " + stage_id
	var contract: Dictionary = STAGE_CONTRACTS[stage_id]
	if str(receipt["owner_id"]) != str(contract["owner_id"]):
		return "owner mismatch for " + stage_id
	if str(receipt["kind"]) != str(contract["kind"]):
		return "kind mismatch for " + stage_id
	if typeof(receipt["value"]) != TYPE_DICTIONARY:
		return "value must be a Dictionary"
	var value: Dictionary = receipt["value"]
	var value_keys := value.keys()
	value_keys.sort()
	var spec: Dictionary = contract["value"]
	var spec_keys := spec.keys()
	spec_keys.sort()
	if value_keys != spec_keys:
		return "value keys mismatch for " + stage_id
	for key: String in spec:
		var error := _validate_spec_value(value[key], str(spec[key]))
		if error != "":
			return key + ": " + error
	return ""

static func _validate_spec_value(value: Variant, spec: String) -> String:
	match spec:
		"bool":
			return "" if typeof(value) == TYPE_BOOL else "expected bool"
		"int":
			return "" if typeof(value) == TYPE_INT else "expected int"
		"string":
			return "" if typeof(value) == TYPE_STRING and not str(value).is_empty() else "expected nonempty String"
		"string_or_null":
			if value == null or typeof(value) == TYPE_STRING:
				return ""
			return "expected String or null"
		"array_string":
			if typeof(value) != TYPE_ARRAY:
				return "expected Array of String"
			for element: Variant in value:
				if typeof(element) != TYPE_STRING:
					return "expected Array of String"
			return ""
		"dictionary":
			return "" if typeof(value) == TYPE_DICTIONARY else "expected Dictionary"
		"const_true":
			return "" if value == true else "expected true"
		"const_false":
			return "" if value == false else "expected false"
		"const_autosave":
			return "" if str(value) == "autosave" else "expected \"autosave\""
		"const_day_start":
			return "" if str(value) == "day_start" else "expected \"day_start\""
		"const_ending":
			return "" if str(value) == "ending" else "expected \"ending\""
		"const_ending_state":
			return "" if str(value) == "ENDING" else "expected \"ENDING\""
	return "unknown spec"

func _gate_identity_result(already_configured: bool) -> Dictionary:
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": already_configured},
		"receipt": {}}

static func _is_valid_gate(gate: Object) -> bool:
	if gate == null or not gate.has_signal("capability_changed"):
		return false
	return _has_all_methods(gate, GATE_METHODS)

static func _has_all_methods(target: Object, methods: Array[String]) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true
