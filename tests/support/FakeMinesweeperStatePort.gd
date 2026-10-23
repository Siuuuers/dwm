class_name FakeMinesweeperStatePort
extends RefCounted

# Test double for the Minesweeper coordinator's state port. Implements the exact
# frozen method set and records per-method call counts so coordinator tests can
# prove phase-only retry rather than inferring it from final state.

const METHODS: Array[String] = [
	"capture", "prepare_begin", "prepare_complete", "finalize_complete",
	"prepare_abort", "commit", "rollback", "publish", "latch_fatal",
	"is_fatal_latched", "guard_external",
]

var _gate: RefCounted = null
var _calls := {}
var _failures := {}

# Trusted dating evidence. The untrusted request never carries friend/entry identifiers, so the
# state port is the only source; mirrors GameStateMinesweeperPort._resolve_dating_evidence().
var dating_evidence := {
	"entry_id": "entry-1",
	"route_transaction_id": "rtx-1",
	"friend_ids": ["priscilla"],
}
# When false, a dating start fails exactly as the production port does with no active substage.
var dating_route_active := true
# Lets a test drive one exact domain-availability verdict out of prepare_begin.
var prepare_begin_failure_code: StringName = &""


func _init(gate: RefCounted = null) -> void:
	_gate = gate
	_reset_counters()


func configure_gate(gate: RefCounted) -> void:
	_gate = gate


func _reset_counters() -> void:
	_calls = {}
	for m in METHODS:
		_calls[m] = 0


func reset_call_counts() -> void:
	_reset_counters()


func get_call_counts() -> Dictionary:
	return _calls.duplicate()


func set_failure(method: StringName, remaining_failures: int = 1) -> void:
	_failures[method] = remaining_failures


func _maybe_fail(method: StringName) -> bool:
	if _failures.has(method) and _failures[method] > 0:
		_failures[method] -= 1
		return true
	return false


func capture() -> Dictionary:
	_calls.capture += 1
	if _maybe_fail(&"capture"):
		return {"ok": false, "code": &"capture_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok",
		"value": {"backup": {"run_id": "run-1", "day": 1, "next_ordinal": 1, "state": "backup"}}}


func prepare_begin(request: Dictionary, round_id: String) -> Dictionary:
	_calls.prepare_begin += 1
	if _maybe_fail(&"prepare_begin"):
		return {"ok": false, "code": &"prepare_begin_failed", "message": "fake failure", "details": {}}
	var context: Variant = request.get("context", &"app")
	# Domain availability is the state port's call, exactly as in production.
	if prepare_begin_failure_code != &"":
		return {"ok": false, "code": prepare_begin_failure_code,
			"message": "fake domain verdict", "details": {}}
	if context == &"dating" and not dating_route_active:
		return {"ok": false, "code": &"DATING_ROUTE_NOT_ACTIVE",
			"message": "no active route substage", "details": {}}
	var active_round := {
		"round_id": round_id,
		"run_id": request.get("run_id", "run-1"),
		"context": context,
		"difficulty": request.get("difficulty", &"beginner"),
		"day": request.get("day", 1),
		"ordinal": request.get("ordinal", 1),
		# Stamped from TRUSTED port state, never from the untrusted request.
		"dating_evidence": dating_evidence.duplicate(true) if context == &"dating" else null,
	}
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"active_round": active_round},
		"active_round": active_round,
		"pre_board_checkpoint_inputs": {"snapshot_input": {}, "run_id": request.get("run_id", "run-1")},
	}}


func prepare_complete(active_round: Dictionary, result: Dictionary, transaction_id: String) -> Dictionary:
	_calls.prepare_complete += 1
	if _maybe_fail(&"prepare_complete"):
		return {"ok": false, "code": &"prepare_complete_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"prepared_candidate": {"active_round": active_round, "result": result},
		"prepared_domain_receipt": {"transaction_id": transaction_id, "round_id": active_round.get("round_id", ""), "checkpoint_id": ""},
		"domain_events": [{"event_id": "round_completed", "round_id": active_round.get("round_id", "")}],
		"checkpoint_input_template": {"snapshot_input": {}},
	}}


func finalize_complete(prepared_completion: Dictionary, checkpoint_id: String) -> Dictionary:
	_calls.finalize_complete += 1
	if _maybe_fail(&"finalize_complete"):
		return {"ok": false, "code": &"finalize_complete_failed", "message": "fake failure", "details": {}}
	var inner: Dictionary = prepared_completion.get("value", {}) as Dictionary
	var candidate: Variant = (inner.get("prepared_candidate", {}) as Dictionary).duplicate(true)
	var receipt: Variant = (inner.get("prepared_domain_receipt", {}) as Dictionary).duplicate(true)
	receipt["checkpoint_id"] = checkpoint_id
	var events: Variant = (inner.get("domain_events", []) as Array).duplicate(true)
	var post: Variant = (inner.get("checkpoint_input_template", {}) as Dictionary).duplicate(true)
	post["checkpoint_id"] = checkpoint_id
	return {"ok": true, "code": &"ok", "value": {
		"candidate": candidate, "domain_receipt": receipt, "domain_events": events,
		"post_result_checkpoint_inputs": post}}


func prepare_abort(active_round: Dictionary, reason: StringName, transaction_id: String) -> Dictionary:
	_calls.prepare_abort += 1
	if _maybe_fail(&"prepare_abort"):
		return {"ok": false, "code": &"prepare_abort_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"active_round": active_round, "reason": reason},
		"abort_receipt": {"round_id": active_round.get("round_id", ""), "reason": reason, "transaction_id": transaction_id},
	}}


func commit(candidate: Dictionary) -> Dictionary:
	_calls.commit += 1
	if _maybe_fail(&"commit"):
		return {"ok": false, "code": &"commit_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"committed": true}}


func rollback(backup: Dictionary) -> Dictionary:
	_calls.rollback += 1
	if _maybe_fail(&"rollback"):
		return {"ok": false, "code": &"rollback_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"rolled_back": true}}


func publish(receipt: Dictionary, domain_events: Array) -> Dictionary:
	_calls.publish += 1
	if _maybe_fail(&"publish"):
		return {"ok": false, "code": &"publish_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"published": true}}


func latch_fatal(failure: Dictionary) -> Dictionary:
	_calls.latch_fatal += 1
	if _gate != null:
		return _gate.latch_fatal(failure)
	return {"ok": true, "code": &"ok", "value": {"fatal_latched": true, "already_latched": false},
		"receipt": {"failure": failure}}


func is_fatal_latched() -> bool:
	_calls.is_fatal_latched += 1
	if _gate != null:
		return _gate.is_fatal_latched()
	return false


func guard_external(operation_id: StringName) -> Dictionary:
	_calls.guard_external += 1
	if _gate != null:
		return _gate.guard_external(operation_id)
	return {"ok": true, "code": &"ok"}
