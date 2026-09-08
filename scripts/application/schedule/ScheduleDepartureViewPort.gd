class_name ScheduleDepartureViewPort
extends RefCounted

## The sole production ScheduleView condition-departure participant -- the exact action-only subset
## frozen at plan02-frozen-contracts.md lines 369-381, created under the dwm-oyo.3 slice authority
## recorded 2026-08-24 on dwm-p2r.21 / dwm-oyo.3.
##
## Production binds the existing saved ScheduleViewController. It owns both the view and its
## append-only departure receipts, so restore and forward replay never depend on a second view.
## The small unbound representation remains for legacy domain-only compositions.
##
## THE LEASE LAW. Commit verifies bytes only while the shared `causal_transaction` owner is active
## (the coordinator holds it across the whole departure span); prepare is pure and holds nothing.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _GATE_OWNER := &"causal_transaction"
const _PREPARE_KEYS: Array[String] = ["causal_sequence_receipt", "condition_receipt"]
const _COMMIT_KEYS: Array[String] = [
	"condition_receipt", "schedule_view_after", "schedule_view_after_sha256",
	"schedule_view_before", "schedule_view_before_sha256",
]

var _mutation_gate: Object = null
var _view_controller: Object = null
## Legacy unbound composition only; production reads and commits the configured controller.
var _live_view: Dictionary = {"schema_version": 1, "state": "empty"}
## source_condition_receipt_id -> {"before":Dictionary,"after":Dictionary,"receipt":Dictionary}.
## Legacy unbound composition only; production receipts live inside the saved controller view.
var _retained: Dictionary = {}


func configure(mutation_gate: Object) -> Dictionary:
	if mutation_gate == null or not mutation_gate.has_method("is_internal_owner_active"):
		return {"ok": false, "code": &"invalid_mutation_gate",
			"message": "the one shared application gate is required", "details": {}}
	if _mutation_gate != null:
		if _mutation_gate != mutation_gate:
			return {"ok": false, "code": &"schedule_view_port_conflict",
				"message": "a configured view port never adopts a replacement gate", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_mutation_gate = mutation_gate
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


func configure_view_controller(controller: Object) -> Dictionary:
	if controller == null:
		return _failure(&"invalid_schedule_view_controller", "the saved view owner is required")
	for method: String in ["snapshot", "lookup_condition_departure_receipt", "commit_condition_departure_transition"]:
		if not controller.has_method(method):
			return _failure(&"invalid_schedule_view_controller", "missing method: " + method)
	if _view_controller != null and _view_controller != controller:
		return _failure(&"schedule_view_port_conflict", "a configured port never adopts a replacement view owner")
	if _view_controller == null and not _retained.is_empty():
		return _failure(&"schedule_view_port_conflict", "bind the saved owner before legacy departures")
	_view_controller = controller
	return {"ok": true, "code": &"ok"}


## Pure projection: the exact current live view, and its canonical departed replacement naming the
## departing condition receipt. No mutation on any path.
func prepare_condition_departure(request: Dictionary) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var keys: Array = request.keys()
	keys.sort()
	if keys != _PREPARE_KEYS:
		return {"ok": false, "code": &"schedule_view_request_invalid",
			"message": "the request is exactly {condition_receipt, causal_sequence_receipt}",
			"details": {}}
	var condition_check := _validate_condition_receipt(request["condition_receipt"])
	if not condition_check.get("ok", false):
		return condition_check
	var condition_receipt: Dictionary = request["condition_receipt"]
	if _view_controller != null:
		var captured: Dictionary = _view_controller.snapshot()
		if not captured.get("ok", false): return captured
		var before: Dictionary = captured["value"]["view"]
		var sequence: Variant = request["causal_sequence_receipt"]
		if not sequence is Dictionary or condition_receipt.get("day") != before["day"] \
				or condition_receipt.get("causal_day_instance") != before["causal_day_instance"] \
				or sequence.get("causal_day_instance") != before["causal_day_instance"] \
				or condition_receipt.get("causal_sequence_receipt_id") != sequence.get("receipt_id"):
			return _failure(&"schedule_view_state_conflict", "the condition must name this exact source-day view and sequence")
		return {"ok": true, "code": &"ok", "value": {
			"schedule_view_before": before.duplicate(true),
			"schedule_view_after": _departed_projection(before),
		}, "receipt": {}}
	var schedule_view_after := {
		"schema_version": 1, "state": "condition_departed",
		"source_condition_receipt_id": str(condition_receipt["receipt_id"]),
	}
	return {"ok": true, "code": &"ok", "value": {
		"schedule_view_before": _live_view.duplicate(true),
		"schedule_view_after": schedule_view_after,
	}, "receipt": {}}


## Applies ONE frozen before/after pair atomically, retains the deterministic receipt keyed by
## `source_condition_receipt_id`, and answers every retry from those retained bytes.
func commit_condition_departure(candidate: Dictionary) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	if not bool(_mutation_gate.call(&"is_internal_owner_active", _GATE_OWNER)):
		return {"ok": false, "code": &"causal_transaction_lease_required",
			"message": "commit_condition_departure runs only under the retained departure lease",
			"details": {}}
	var keys: Array = candidate.keys()
	keys.sort()
	if keys != _COMMIT_KEYS:
		return {"ok": false, "code": &"schedule_view_request_invalid",
			"message": "the candidate carries exactly the five frozen members", "details": {}}
	var condition_check := _validate_condition_receipt(candidate["condition_receipt"])
	if not condition_check.get("ok", false):
		return condition_check
	if typeof(candidate["schedule_view_before"]) != TYPE_DICTIONARY \
			or typeof(candidate["schedule_view_after"]) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"schedule_view_request_invalid",
			"message": "both view members must be objects", "details": {}}
	var before: Dictionary = candidate["schedule_view_before"]
	var after: Dictionary = candidate["schedule_view_after"]
	if _canonical_sha256(before) != str(candidate["schedule_view_before_sha256"]) \
			or _canonical_sha256(after) != str(candidate["schedule_view_after_sha256"]):
		return {"ok": false, "code": &"schedule_view_hash_mismatch",
			"message": "a frozen view member no longer matches its recorded hash", "details": {}}
	var condition_receipt: Dictionary = candidate["condition_receipt"]
	var source_condition_receipt_id := str(condition_receipt["receipt_id"])

	# NO MINTED IDENTITY: every member is a projection of the candidate, so a crash-retry of the
	# same frozen bytes reproduces this exact receipt (the contract's idempotent-retry law).
	var receipt := {
		"source_condition_receipt_id": source_condition_receipt_id,
		"source_condition_receipt_provenance":
			(condition_receipt["receipt_provenance"] as Dictionary).duplicate(true),
		"schedule_view_before_sha256": str(candidate["schedule_view_before_sha256"]),
		"schedule_view_after_sha256": str(candidate["schedule_view_after_sha256"]),
		"disposition": "condition_departure_view_committed",
	}
	if _view_controller != null:
		return _commit_controller_transition(candidate, receipt)


	if _retained.has(source_condition_receipt_id):
		var retained: Dictionary = _retained[source_condition_receipt_id]
		if retained["before"] == before and retained["after"] == after:
			return {"ok": true, "code": &"ok", "value": {"committed": true},
				"receipt": (retained["receipt"] as Dictionary).duplicate(true)}
		return {"ok": false, "code": &"schedule_view_conflict",
			"message": "this source condition already departed with different bytes", "details": {}}

	if _live_view == before:
		_live_view = after.duplicate(true)
	elif _live_view != after:
		return {"ok": false, "code": &"schedule_view_state_conflict",
			"message": "the live view is neither the frozen before nor the frozen after bytes",
			"details": {}}

	_retained[source_condition_receipt_id] = {
		"before": before.duplicate(true), "after": after.duplicate(true),
		"receipt": receipt.duplicate(true),
	}
	return {"ok": true, "code": &"ok", "value": {"committed": true},
		"receipt": receipt.duplicate(true)}


static func _validate_condition_receipt(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY \
			or str((value as Dictionary).get("receipt_id", "")).strip_edges().is_empty() \
			or typeof((value as Dictionary).get("receipt_provenance")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"schedule_view_request_invalid",
			"message": "condition_receipt must carry receipt_id and receipt_provenance",
			"details": {}}
	return {"ok": true}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()

## A departure drops the uncommitted docket and closes its pending warning. Same-day
## date evidence, consumed warnings and every older departure receipt remain unchanged.
func _departed_projection(before: Dictionary) -> Dictionary:
	var after := before.duplicate(true)
	after["entries"] = []
	after["pending_warning"] = null
	return after


func _commit_controller_transition(candidate: Dictionary, receipt: Dictionary) -> Dictionary:
	var source_id := str(receipt["source_condition_receipt_id"])
	var retained: Dictionary = _view_controller.lookup_condition_departure_receipt(source_id)
	if retained.get("ok", false):
		if _canonical_sha256(retained["value"]["receipt"]) != _canonical_sha256(receipt):
			return _failure(&"schedule_view_conflict", "this source condition already departed with different bytes")
		return {"ok": true, "code": &"ok", "value": {"committed": true},
			"receipt": (retained["value"]["receipt"] as Dictionary).duplicate(true)}
	if retained.get("code") != &"condition_departure_receipt_not_found": return retained
	if _canonical_sha256(_departed_projection(candidate["schedule_view_before"])) \
			!= str(candidate["schedule_view_after_sha256"]):
		return _failure(&"schedule_view_conflict", "the frozen after-view must be the canonical departure projection")
	var committed: Dictionary = _view_controller.commit_condition_departure_transition({
		"schedule_view_before": candidate["schedule_view_before"].duplicate(true),
		"schedule_view_after": candidate["schedule_view_after"].duplicate(true),
		"schedule_view_commit_receipt": receipt.duplicate(true),
	})
	if not committed.get("ok", false):
		if committed.get("code") == &"condition_departure_receipt_conflict":
			return _failure(&"schedule_view_state_conflict", "the live view matches neither frozen view")
		return committed
	return {"ok": true, "code": &"ok", "value": {"committed": true},
		"receipt": (committed["value"]["receipt"] as Dictionary).duplicate(true)}


static func _failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
