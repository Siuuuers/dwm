class_name FakeDesktopConditionPolicyPort
extends RefCounted

## Task-8 contract fake for Plan 03's production `DesktopConditionPolicyPort` -- the exact frozen
## surface (plan02-frozen-contracts.md brief lines 126-128): `configure(context_port)`,
## `evaluate(request)`. "The fake uses explicit contract fixtures only; it never reads production
## GameState or proves those decisions... Plan 03's read-only context adapter and production port
## alone own the predicates and receipt ancestry" -- so this double is purely programmable: tests
## `arm()` a scripted decision per action `transaction_id`; an unarmed transaction defaults to
## `no_departure` so tests that do not exercise condition-departure law need no setup.
##
## `context_port` is accepted duck-typed (any non-null Object) and never read: Plan 03 alone defines
## its real shape, and this fake's whole point is to bypass it with fixtures.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _context_port: Object = null
## Keyed by action transaction_id. Each armed entry is exactly the free-form fields this fake
## projects into `condition_receipt`/`destination_intent`/`notification_intent`.
var _armed: Dictionary = {}
var evaluate_calls: Array[Dictionary] = []


func configure(context_port: Object) -> Dictionary:
	if context_port == null:
		return {"ok": false, "code": &"invalid_context_port", "message": "", "details": {}}
	if _context_port != null:
		if _context_port == context_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return {"ok": false, "code": &"port_already_configured", "message": "", "details": {}}
	_context_port = context_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Arms one scripted `evaluate()` outcome for the given action `transaction_id`.
## `destination_intent`/`notification_intent`, when nonnull, must already be exactly the frozen
## shapes -- this fake performs no further shaping of them.
func arm(transaction_id: String, decision: String, danger: bool = false, trigger: bool = false,
		condition_after: Dictionary = {}, source_receipt_ids: Array = [],
		sylvia_read_receipt_id: Variant = null, destination_intent: Variant = null,
		notification_intent: Variant = null) -> void:
	_armed[transaction_id] = {
		"decision": decision, "danger": danger, "trigger": trigger, "condition_after": condition_after,
		"source_receipt_ids": source_receipt_ids, "sylvia_read_receipt_id": sylvia_read_receipt_id,
		"destination_intent": destination_intent, "notification_intent": notification_intent,
	}


func evaluate(request: Dictionary) -> Dictionary:
	if _context_port == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	var keys: Array = request.keys()
	keys.sort()
	if keys != ["action_receipt", "causal_sequence_receipt"]:
		return {"ok": false, "code": &"condition_request_invalid", "message": "", "details": {}}
	evaluate_calls.append(request.duplicate(true))
	var action_receipt: Dictionary = request["action_receipt"]
	var causal_sequence_receipt: Dictionary = request["causal_sequence_receipt"]
	var transaction_id := str(action_receipt.get("transaction_id", ""))
	var script: Dictionary = _armed.get(transaction_id, {
		"decision": "no_departure", "danger": false, "trigger": false, "condition_after": {},
		"source_receipt_ids": [], "sylvia_read_receipt_id": null, "destination_intent": null,
		"notification_intent": null,
	})

	var condition_receipt := {
		"receipt_id": "",
		"receipt_provenance": {"schema_version": 1, "parent_receipt_id": str(action_receipt.get("transaction_issuer_receipt", {}).get("receipt_id", "")),
			"child_kind": "condition", "ordinal": 0, "source_ids": [transaction_id], "child_id": ""},
		"action_commit_receipt_id": str(action_receipt.get("commit_receipt_id", "")),
		"action_commit_receipt_provenance": (action_receipt.get("commit_receipt_provenance", {}) as Dictionary).duplicate(true),
		"causal_sequence_receipt_id": str(causal_sequence_receipt.get("receipt_id", "")),
		"causal_sequence_receipt_provenance": {"kind": "causal_sequence_receipt_fake"},
		"causal_sequence": int(causal_sequence_receipt.get("causal_sequence", 0)),
		"day": int(action_receipt.get("day", 0)),
		"causal_day_instance": str(causal_sequence_receipt.get("causal_day_instance", "")),
		"condition_after": (script["condition_after"] as Dictionary).duplicate(true),
		"danger": bool(script["danger"]), "trigger": bool(script["trigger"]),
		"decision": str(script["decision"]),
		"source_receipt_ids": (script["source_receipt_ids"] as Array).duplicate(true),
		"sylvia_read_receipt_id": script["sylvia_read_receipt_id"],
	}
	var receipt_id := "condition.fake." + _canonical_sha256(condition_receipt)
	condition_receipt["receipt_id"] = receipt_id
	(condition_receipt["receipt_provenance"] as Dictionary)["child_id"] = receipt_id

	return {"ok": true, "code": &"ok", "value": {
		"condition_receipt": condition_receipt.duplicate(true),
		"destination_intent": script["destination_intent"],
		"notification_intent": script["notification_intent"],
	}, "receipt": condition_receipt.duplicate(true)}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()
