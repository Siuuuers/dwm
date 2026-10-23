class_name FakeScheduleDepartureViewPort
extends RefCounted

## Task-8 contract fake matching the exact ACTION subset of Plan-03's frozen
## `ScheduleDepartureViewPort` surface (plan02-frozen-contracts.md lines 368-381):
## `prepare_condition_departure(request)` / `commit_condition_departure(candidate)`. "Plan 02 supplies
## only FakeScheduleDepartureViewPort; Plan 03's sole production ScheduleDepartureViewPort implements
## this surface against its one ScheduleView owner" -- this double exercises the coordinator's
## recovery/idempotency law without representing any real ScheduleView content.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Opaque view content -- primitive transport as far as Plan 02 is concerned.
var live_view: Dictionary = {"schema_version": 1, "state": "before"}
## Keyed by source_condition_receipt_id -> {"before":Dictionary,"after":Dictionary,"receipt":Dictionary}.
var _retained: Dictionary = {}
var prepare_calls := 0
var commit_calls := 0


func prepare_condition_departure(request: Dictionary) -> Dictionary:
	prepare_calls += 1
	var keys: Array = request.keys()
	keys.sort()
	if keys != ["causal_sequence_receipt", "condition_receipt"]:
		return {"ok": false, "code": &"invalid_request", "message": "", "details": {}}
	var schedule_view_after: Dictionary = live_view.duplicate(true)
	schedule_view_after["state"] = "condition_departed"
	schedule_view_after["source_condition_receipt_id"] = str((request["condition_receipt"] as Dictionary).get("receipt_id", ""))
	return {"ok": true, "code": &"ok", "value": {
		"schedule_view_before": live_view.duplicate(true), "schedule_view_after": schedule_view_after,
	}, "receipt": {}}


func commit_condition_departure(candidate: Dictionary) -> Dictionary:
	var keys: Array = candidate.keys()
	keys.sort()
	var expected: Array = ["condition_receipt", "schedule_view_after", "schedule_view_after_sha256",
		"schedule_view_before", "schedule_view_before_sha256"]
	expected.sort()
	if keys != expected:
		return {"ok": false, "code": &"invalid_request", "message": "", "details": {}}
	var condition_receipt: Dictionary = candidate["condition_receipt"]
	var before: Dictionary = candidate["schedule_view_before"]
	var after: Dictionary = candidate["schedule_view_after"]
	if _canonical_sha256(before) != str(candidate["schedule_view_before_sha256"]) \
			or _canonical_sha256(after) != str(candidate["schedule_view_after_sha256"]):
		return {"ok": false, "code": &"schedule_view_hash_mismatch", "message": "", "details": {}}
	var source_condition_receipt_id := str(condition_receipt.get("receipt_id", ""))

	if _retained.has(source_condition_receipt_id):
		var retained: Dictionary = _retained[source_condition_receipt_id]
		if retained["before"] == before and retained["after"] == after:
			return {"ok": true, "code": &"ok", "value": {"committed": true},
				"receipt": (retained["receipt"] as Dictionary).duplicate(true)}
		return {"ok": false, "code": &"schedule_view_conflict", "message": "", "details": {}}

	if live_view == before:
		live_view = after.duplicate(true)
	elif live_view != after:
		return {"ok": false, "code": &"schedule_view_state_conflict", "message": "", "details": {}}
	commit_calls += 1

	var receipt := {
		"source_condition_receipt_id": source_condition_receipt_id,
		"source_condition_receipt_provenance": (condition_receipt.get("receipt_provenance", {}) as Dictionary).duplicate(true),
		"schedule_view_before_sha256": str(candidate["schedule_view_before_sha256"]),
		"schedule_view_after_sha256": str(candidate["schedule_view_after_sha256"]),
		"disposition": "condition_departure_view_committed",
	}
	_retained[source_condition_receipt_id] = {
		"before": before.duplicate(true), "after": after.duplicate(true), "receipt": receipt.duplicate(true),
	}
	return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": receipt.duplicate(true)}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()
