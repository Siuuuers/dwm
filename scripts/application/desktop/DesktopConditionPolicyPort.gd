class_name DesktopConditionPolicyPort
extends RefCounted

## Production condition policy (Plan 03 Task 7 lines 874-878, created ahead of the full task under
## the dwm-oyo.3 slice authority recorded 2026-08-24 on dwm-p2r.21 / dwm-oyo.3).
##
## THE FROZEN SURFACE is Plan 02's contract exactly: `configure(context_port)` and
## `evaluate({action_receipt, causal_sequence_receipt})` -- the same two methods
## `FakeDesktopConditionPolicyPort` freezes for the coordinator suites, now with the real predicate
## behind them instead of an armed script.
##
## THE PREDICATE (plan line 878, verbatim): `danger = pressure >= 10 or health <= 0`, then
## `trigger = carried_sequela and danger`. No trigger yields only the notification intent. A
## Days 1-6 trigger yields Hospital. On Day 7 an active Dark-mode flag yields `dark_mode_alone`
## first; otherwise a qualifying pre-action Sylvia receipt while Done is still open yields
## `sylvia_special`; otherwise the trigger yields `hospital_alone`. Departure and notification are
## mutually exclusive, and `committed | resolving` rejects a new action rather than creating a
## post-Done faint.
##
## STATELESS BY DESIGN. Everything read arrives through the configured context port's snapshot, and
## every persisted child derives through that same port's issuer seam (rows `P03.condition.decision`
## / `.destination` / `.notification`), so a caller-supplied ID or provenance is never input and a
## replay reproduces byte-identical children.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _CONTEXT_PORT_METHODS: Array[String] = ["snapshot_for", "derive_child", "validate_child"]
const _REQUEST_KEYS: Array[String] = ["action_receipt", "causal_sequence_receipt"]
const _DAY7_CAUSE := {
	"day7_dark_alone": "dark_mode_alone",
	"day7_sylvia_special": "sylvia_special",
	"day7_hospital_alone": "hospital_alone",
}

var _context_port: Object = null


func configure(context_port: Object) -> Dictionary:
	if context_port == null or not _has_methods(context_port, _CONTEXT_PORT_METHODS):
		return {"ok": false, "code": &"invalid_context_port",
			"message": "an exact snapshot/derive/validate context capability is required",
			"details": {}}
	if _context_port != null:
		if _context_port != context_port:
			return {"ok": false, "code": &"port_already_configured",
				"message": "a configured policy never adopts a replacement context", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_context_port = context_port
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


func evaluate(request: Dictionary) -> Dictionary:
	if _context_port == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var keys: Array = request.keys()
	keys.sort()
	if keys != _REQUEST_KEYS:
		return {"ok": false, "code": &"condition_request_invalid",
			"message": "the request is exactly {action_receipt, causal_sequence_receipt}",
			"details": {}}
	var snapshot: Variant = _context_port.call(&"snapshot_for", request)
	if typeof(snapshot) != TYPE_DICTIONARY or not (snapshot as Dictionary).get("ok", false):
		return snapshot if typeof(snapshot) == TYPE_DICTIONARY else {
			"ok": false, "code": &"context_unavailable", "message": "", "details": {}}
	var context: Dictionary = ((snapshot as Dictionary)["value"] as Dictionary)["context"]
	var done_state := str(context["schedule_done_state"])
	if done_state == "committed" or done_state == "resolving":
		return {"ok": false, "code": &"condition_post_done_action",
			"message": "a committed or resolving Schedule rejects a new action", "details": {}}

	var action_receipt: Dictionary = request["action_receipt"]
	var sequence_receipt: Dictionary = request["causal_sequence_receipt"]
	var condition_after: Dictionary = context["condition_after"]
	var danger: bool = int(condition_after["pressure"]) >= 10 or int(condition_after["health"]) <= 0
	var trigger: bool = bool(condition_after["carried_sequela"]) and danger
	var decision := _decision(trigger, int(context["day"]), bool(context["dark_mode"]),
		context["sylvia_read_source_receipt"] != null)

	var accepted: Array = context["accepted_unfulfilled_sources"]
	var source_receipt_ids: Array = []
	if decision != "no_departure":
		for source: Variant in accepted:
			source_receipt_ids.append(str((source as Dictionary)["receipt_id"]))
		source_receipt_ids.sort()
	var sylvia: Variant = context["sylvia_read_source_receipt"]

	var condition_derived := _derive("condition", action_receipt, [
		_projection("action_commit_receipt_id", str(action_receipt["commit_receipt_id"])),
		_projection("causal_sequence_receipt_id", str(sequence_receipt["receipt_id"])),
	])
	if not condition_derived.get("ok", false):
		return condition_derived
	var condition_receipt := {
		"receipt_id": str((condition_derived["value"] as Dictionary)["child_id"]),
		"receipt_provenance":
			((condition_derived["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
		"action_commit_receipt_id": str(action_receipt["commit_receipt_id"]),
		"action_commit_receipt_provenance":
			(action_receipt["commit_receipt_provenance"] as Dictionary).duplicate(true),
		"causal_sequence_receipt_id": str(sequence_receipt["receipt_id"]),
		"causal_sequence_receipt_provenance":
			(sequence_receipt["receipt_provenance"] as Dictionary).duplicate(true),
		"causal_sequence": int(sequence_receipt["causal_sequence"]),
		"day": int(context["day"]),
		"causal_day_instance": str(context["causal_day_instance"]),
		"condition_after": condition_after.duplicate(true),
		"danger": danger,
		"trigger": trigger,
		"decision": decision,
		"source_receipt_ids": source_receipt_ids,
		"sylvia_read_receipt_id":
			str((sylvia as Dictionary)["receipt_id"]) if sylvia != null else null,
	}

	var destination_intent: Variant = null
	var notification_intent: Variant = null
	if decision == "no_departure":
		var notification_derived := _derive("notification_intent", action_receipt, [
			_projection("condition_receipt_id", str(condition_receipt["receipt_id"])),
			_projection("action_commit_receipt_id", str(action_receipt["commit_receipt_id"])),
			_projection("action_kind", str(action_receipt["action_kind"])),
		])
		if not notification_derived.get("ok", false):
			return notification_derived
		notification_intent = {
			"intent_id": str((notification_derived["value"] as Dictionary)["child_id"]),
			"intent_id_provenance":
				((notification_derived["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
			"action_kind": str(action_receipt["action_kind"]),
			"action_commit_receipt_id": str(action_receipt["commit_receipt_id"]),
			"action_commit_receipt_provenance":
				(action_receipt["commit_receipt_provenance"] as Dictionary).duplicate(true),
			"source_condition_receipt_id": str(condition_receipt["receipt_id"]),
			"source_condition_receipt_provenance":
				(condition_receipt["receipt_provenance"] as Dictionary).duplicate(true),
		}
	else:
		var destination_derived := _derive("destination_intent", action_receipt, [
			_projection("condition_receipt_id", str(condition_receipt["receipt_id"])),
			_projection("action_commit_receipt_id", str(action_receipt["commit_receipt_id"])),
		])
		if not destination_derived.get("ok", false):
			return destination_derived
		var prerequisite_receipt_ids: Array = [
			str(condition_receipt["receipt_id"]), str(action_receipt["commit_receipt_id"])]
		prerequisite_receipt_ids.sort()
		destination_intent = {
			"intent_id": str((destination_derived["value"] as Dictionary)["child_id"]),
			"intent_id_provenance":
				((destination_derived["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
			"kind": "hospital_day" if decision == "hospital_day" else "day7_terminal",
			"day": int(context["day"]),
			"causal_day_instance": str(context["causal_day_instance"]),
			"source_condition_receipt_id": str(condition_receipt["receipt_id"]),
			"source_condition_receipt_provenance":
				(condition_receipt["receipt_provenance"] as Dictionary).duplicate(true),
			# A condition-driven Day 7 intent carries an EMPTY accepted-source array (plan line 874);
			# only Hospital consumes the day's frozen sources.
			"accepted_unfulfilled_sources":
				accepted.duplicate(true) if decision == "hospital_day" else [],
			"terminal_cause": _DAY7_CAUSE.get(decision),
			"terminal_provenance": null,
			"prerequisite_receipt_ids": prerequisite_receipt_ids,
		}

	return {"ok": true, "code": &"ok", "value": {
		"condition_receipt": condition_receipt.duplicate(true),
		"destination_intent": destination_intent,
		"notification_intent": notification_intent,
	}, "receipt": condition_receipt.duplicate(true)}


static func _decision(trigger: bool, day: int, dark_mode: bool, sylvia_read: bool) -> String:
	if not trigger:
		return "no_departure"
	if day <= 6:
		return "hospital_day"
	if dark_mode:
		return "day7_dark_alone"
	if sylvia_read:
		return "day7_sylvia_special"
	return "day7_hospital_alone"


## One row of the Plan-03 child-identity table: projections are `P(name,value)` strings, rejected
## blank/duplicate by the issuer, sorted by ordinal code point before issuance (plan line 103).
func _derive(child_kind: String, action_receipt: Dictionary, projections: Array) -> Dictionary:
	var source_ids: Array = projections.duplicate()
	source_ids.sort()
	var derived: Variant = _context_port.call(&"derive_child", {
		"child_kind": child_kind, "ordinal": 0,
		"parent_receipt_id":
			str((action_receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": source_ids,
	})
	if typeof(derived) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"condition_child_unavailable", "message": child_kind,
			"details": {}}
	var envelope: Dictionary = derived
	return envelope if not envelope.get("ok", false) else _revalidated(child_kind, envelope)


## Plan line 874: every persisted child id validates through `validate_child` BEFORE it is written
## into a receipt or an intent. Derivation alone is not proof, which is why `validate_child` is a
## configure-time requirement -- this is the same derive-then-revalidate shape every sibling producer
## uses (`DayResolutionStartPort`, `HospitalPresentationPort`, `DatingPresentationPort`,
## `GameStateScheduleCommitPort`, `Day7ScheduleProvenance`, `GameStateDayResolutionPort`). The
## context port is duck-typed at `configure`, so without this a seam answering with an id the one
## `.16` issuer never minted would be copied verbatim into the day's condition receipt, into both
## intents, and thence into the durable `recovery_payload.condition_candidate`.
func _revalidated(child_kind: String, envelope: Dictionary) -> Dictionary:
	var child: Variant = envelope.get("value")
	if typeof(child) != TYPE_DICTIONARY:
		return _unverified("the derivation carried no child", child_kind)
	var provenance: Variant = (child as Dictionary).get("provenance")
	if typeof(provenance) != TYPE_DICTIONARY:
		return _unverified("the derived child carried no provenance", child_kind)
	var child_id := str((child as Dictionary).get("child_id", ""))
	if child_id.is_empty() or str((provenance as Dictionary).get("child_id", "")) != child_id:
		return _unverified("the derived identity disagrees with its provenance", child_kind)
	var revalidated: Variant = _context_port.call(&"validate_child",
		(provenance as Dictionary).duplicate(true), StringName(child_kind))
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _unverified("the issuer refused to revalidate its own child", child_kind)
	return envelope


static func _unverified(reason: String, child_kind: String) -> Dictionary:
	return {"ok": false, "code": &"condition_child_unverified",
		"message": reason + ": " + child_kind, "details": {}}


static func _projection(name: String, value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	return name + "=" + str(emitted["value"])


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true
