class_name CausalDayAdvanceIdentityPort
extends RefCounted

## Shared causal-day allocator used by schedule completion and condition-hospital advance.
##
## Plan 02 (`dwm-p2r.16`) keeps this port deterministic: request/receipt shapes are
## exact, prepare is mutation-free, and all persistence is delegated to the external
## identity issuer's day-advance root methods.

const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const DISPOSITION_ALLOCATED := "causal_day_advance_identity_allocated"
const SCHEMA_VERSION := 1

const REQUEST_KEYS: Array[String] = [
	"branch_id",
	"desktop_timeline_generation",
	"resolution_kind",
	"run_id",
	"source_causal_day_instance",
	"source_causal_day_instance_issuer_receipt",
	"source_day",
	"source_resolution_receipt",
]

const RECEIPT_KEYS: Array[String] = [
	"schema_version",
	"allocation_key",
	"resolution_kind",
	"source_resolution_receipt_id",
	"source_resolution_receipt_provenance",
	"source_resolution_receipt_sha256",
	"run_id",
	"branch_id",
	"desktop_timeline_generation",
	"source_day",
	"target_day",
	"source_causal_day_instance",
	"source_causal_day_instance_receipt_id",
	"source_causal_day_instance_issuer_receipt",
	"target_causal_day_instance",
	"target_causal_day_instance_issuer_receipt",
	"request_sha256",
	"root_before_fingerprint",
	"counter_start",
	"counter_end",
	"disposition",
]

const CANDIDATE_KEYS: Array[String] = ["day_advance_identity_receipt"]

const EXPECTED_RESOLUTION_CHILD_KIND: Dictionary = {
	"schedule_done": "day_resolution_stage",
	"condition_hospital": "hospital_resolution",
}

const ALLOWED_RESOLUTION_KIND: Array[String] = ["schedule_done", "condition_hospital"]

var _identity_issuer: Object = null


func configure(identity_issuer: Object) -> Dictionary:
	var was_configured := _identity_issuer != null
	if identity_issuer == null:
		return _failed(
			&"causal_day_advance_identity_not_configured",
			"configure(identity_issuer) requires an identity issuer")
	if _identity_issuer != null and _identity_issuer != identity_issuer:
		return _failed(
			&"causal_day_advance_identity_already_configured",
			"configure may not replace an already-retained identity issuer")
	_identity_issuer = identity_issuer
	return {
		"ok": true,
		"code": &"ok",
		"value": {"already_configured": was_configured},
	}


func prepare_advance(request: Dictionary) -> Dictionary:
	var ready := _require_configured("prepare_advance")
	if not ready.get("ok", false):
		return ready

	var shaped := _exact_keys(request, REQUEST_KEYS)
	if not shaped.get("ok", false):
		return shaped

	var validated := _validate_request(request)
	if not validated.get("ok", false):
		return validated

	var source_day := int(request["source_day"])
	var source_day_parent_id := str(request["source_causal_day_instance"])
	var resolution_kind := str(request["resolution_kind"])
	var source_resolution_receipt_id := str(
		(request["source_resolution_receipt"] as Dictionary).get("receipt_id", "")
	)
	var source_receipt: Dictionary = request["source_causal_day_instance_issuer_receipt"]
	var source_resolution_receipt: Dictionary = request["source_resolution_receipt"]

	var ancestry := _validate_resolution_ancestry(
		resolution_kind,
		source_resolution_receipt
	)
	if not ancestry.get("ok", false):
		return ancestry

	if str((source_receipt as Dictionary).get("token", "")) != source_day_parent_id:
		return _failed(
			&"causal_day_advance_source_token_mismatch",
			str(source_day_parent_id))

	if source_resolution_receipt_id.is_empty():
		return _failed(
			&"causal_day_advance_source_resolution_receipt_id_invalid",
			"source_resolution_receipt.receipt_id")

	var before := _capture_root()
	if not before.get("ok", false):
		return before
	var before_root: Dictionary = before["value"]
	var tuple_ok := _ensure_source_tuple_uniqueness(request, before_root)
	if not tuple_ok.get("ok", false):
		return tuple_ok

	var source_verification_receipt: Dictionary = _verification_receipt(source_receipt)
	var verified_source: Dictionary = _identity_issuer.call(
		&"verify_issued",
		source_verification_receipt,
		&"causal_day_instance"
	)
	if not verified_source.get("ok", false):
		return _map_verify_source_receipt(verified_source)
	var request_sha256 := _sha256(request)
	if not request_sha256.get("ok", false):
		return request_sha256
	var allocation_key := _day_advance_key(resolution_kind, source_resolution_receipt_id)
	var existing: Dictionary = before_root.get("day_advance_allocation_receipts", {})
	if existing.has(allocation_key):
		var recorded: Dictionary = existing[allocation_key]
		if str(recorded.get("request_sha256", "")) != str(request_sha256["value"]):
			return _failed(&"causal_day_advance_identity_conflict", allocation_key)
		var recorded_shape := _exact_keys(recorded, RECEIPT_KEYS)
		if not recorded_shape.get("ok", false):
			return _failed(&"causal_day_advance_identity_conflict", allocation_key)
		return _prepared_result(recorded)

	var root_request := {
		"resolution_kind": resolution_kind,
		"source_resolution_receipt_id": source_resolution_receipt_id,
		"source_causal_day_instance_issuer_receipt": source_receipt.duplicate(true),
	}

	var prepared: Dictionary = _identity_issuer.call(&"prepare_causal_day_advance", root_request)
	if not prepared.get("ok", false):
		return _map_prepare_failure(prepared)

	var root_candidate: Dictionary = prepared["value"]
	if typeof(root_candidate) != TYPE_DICTIONARY:
		return _failed(&"causal_day_advance_identity_prepare_invalid", "root candidate must be a Dictionary")
	if not root_candidate.has("target_causal_day_instance_issuer_receipt"):
		return _failed(
			&"causal_day_advance_target_receipt_missing",
			"target_causal_day_instance_issuer_receipt")
	var target_receipt: Dictionary = root_candidate.get(
		"target_causal_day_instance_issuer_receipt", {}
	) as Dictionary
	if target_receipt.is_empty():
		return _failed(&"causal_day_advance_target_receipt_missing",
			"target receipt was empty")

	var source_receipt_id := str((source_receipt as Dictionary).get("receipt_id", ""))
	var source_resolution_sha256 := _sha256(source_resolution_receipt)
	if not source_resolution_sha256.get("ok", false):
		return source_resolution_sha256

	var source_resolution_provenance: Dictionary = (source_resolution_receipt.get("provenance", {}) as Dictionary)
	if typeof(source_resolution_provenance) != TYPE_DICTIONARY:
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt.provenance")

	var counter_start := int(root_candidate.get("root_next_counter", 0))
	var target_day := source_day + 1
	var requested_receipt := {
		"schema_version": SCHEMA_VERSION,
		"allocation_key": str(
			root_candidate.get(
				"allocation_key",
				_day_advance_key(resolution_kind, source_resolution_receipt_id),
			),
		),
		"resolution_kind": resolution_kind,
		"source_resolution_receipt_id": source_resolution_receipt_id,
		"source_resolution_receipt_provenance": (source_resolution_provenance as Dictionary).duplicate(true),
		"source_resolution_receipt_sha256": str(source_resolution_sha256["value"]),
		"run_id": str(request["run_id"]),
		"branch_id": str(request["branch_id"]),
		"desktop_timeline_generation": int(request["desktop_timeline_generation"]),
		"source_day": source_day,
		"target_day": target_day,
		"source_causal_day_instance": source_day_parent_id,
		"source_causal_day_instance_receipt_id": source_receipt_id,
		"source_causal_day_instance_issuer_receipt": source_receipt.duplicate(true),
		"target_causal_day_instance": str(target_receipt.get("token", "")),
		"target_causal_day_instance_issuer_receipt": target_receipt.duplicate(true),
		"request_sha256": str(request_sha256["value"]),
		"root_before_fingerprint": _root_fingerprint(before_root),
		"counter_start": counter_start,
		"counter_end": counter_start + 1,
		"disposition": DISPOSITION_ALLOCATED,
	}

	return _prepared_result(requested_receipt)


func commit_advance(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured("commit_advance")
	if not ready.get("ok", false):
		return ready

	var shaped := _exact_keys(candidate, CANDIDATE_KEYS)
	if not shaped.get("ok", false):
		return shaped

	var receipt: Dictionary = candidate.get("day_advance_identity_receipt", {})
	var same_shape := _exact_keys(receipt, RECEIPT_KEYS)
	if not same_shape.get("ok", false):
		return same_shape

	var committed: Dictionary = _identity_issuer.call(
		&"commit_causal_day_advance",
		receipt.duplicate(true)
	)
	if not committed.get("ok", false):
		return _map_commit_failure(committed)

	return {
		"ok": true,
		"code": &"ok",
		"value": {"day_advance_identity_receipt": (receipt as Dictionary).duplicate(true)},
	}


func _validate_request(request: Dictionary) -> Dictionary:
	for key in ["run_id", "branch_id", "source_causal_day_instance"]:
		if typeof(request[key]) != TYPE_STRING or str(request[key]).strip_edges().is_empty():
			return _failed(&"causal_day_advance_request_field_invalid", str(key))

	var resolution_kind := str(request["resolution_kind"])
	if not ALLOWED_RESOLUTION_KIND.has(resolution_kind):
		return _failed(&"causal_day_advance_resolution_kind_invalid", resolution_kind)
	if typeof(request["source_day"]) != TYPE_INT:
		return _failed(&"causal_day_advance_source_day_invalid", str(request["source_day"]))
	if int(request["source_day"]) < 1 or int(request["source_day"]) > 6:
		return _failed(&"causal_day_advance_source_day_invalid", str(request["source_day"]))

	if typeof(request["desktop_timeline_generation"]) != TYPE_INT or int(request["desktop_timeline_generation"]) < 0:
		return _failed(&"causal_day_advance_generation_invalid", str(request["desktop_timeline_generation"]))

	var source_receipt: Dictionary = request["source_causal_day_instance_issuer_receipt"]
	if typeof(source_receipt) != TYPE_DICTIONARY:
		return _failed(&"causal_day_advance_source_receipt_invalid",
			"source_causal_day_instance_issuer_receipt must be an object")

	var source_resolution_receipt: Dictionary = request["source_resolution_receipt"]
	if typeof(source_resolution_receipt) != TYPE_DICTIONARY:
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt must be an object")
	if not source_resolution_receipt.has("receipt_id"):
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt.receipt_id")
	if typeof(source_resolution_receipt.get("receipt_id")) != TYPE_STRING:
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt.receipt_id")
	if not source_resolution_receipt.has("provenance"):
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt.provenance")

	return {"ok": true}


func _validate_resolution_ancestry(resolution_kind: String, source_resolution_receipt: Dictionary) -> Dictionary:
	var expected: String = EXPECTED_RESOLUTION_CHILD_KIND.get(resolution_kind, "")
	if expected.is_empty():
		return {"ok": true}

	var provenance: Dictionary = source_resolution_receipt.get("provenance", {})
	if typeof(provenance) != TYPE_DICTIONARY:
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt.provenance must be a Dictionary")
	var proven: Dictionary = _identity_issuer.call(&"validate_child", provenance, StringName(expected))
	if not proven.get("ok", false):
		return proven
	if str(provenance.get("child_id", "")) != str(source_resolution_receipt.get("receipt_id", "")):
		return _failed(&"causal_day_advance_source_resolution_invalid",
			"source_resolution_receipt.receipt_id does not match its provenance")
	return {"ok": true}


func _ensure_source_tuple_uniqueness(request: Dictionary, document: Dictionary) -> Dictionary:
	var existing: Dictionary = document.get("day_advance_allocation_receipts", {})
	var tuple := _source_tuple_key(request)
	var current_key := _day_advance_key(
		str(request["resolution_kind"]),
		str((request["source_resolution_receipt"] as Dictionary).get("receipt_id", ""))
	)
	for key in existing.keys():
		if str(key) == current_key:
			continue
		var recorded := existing[key] as Dictionary
		if _tuple_equals(tuple, _tuple_from_receipt(recorded)):
			return _failed(&"causal_day_advance_identity_conflict", str(key))
	return {"ok": true}


func _source_tuple_key(request: Dictionary) -> Array:
	return [
		str(request["run_id"]),
		str(request["branch_id"]),
		int(request["desktop_timeline_generation"]),
		str(request["source_causal_day_instance"]),
		int(request["source_day"]),
	]


func _tuple_from_receipt(receipt: Dictionary) -> Array:
	return [
		str(receipt.get("run_id", "")),
		str(receipt.get("branch_id", "")),
		int(receipt.get("desktop_timeline_generation", 0)),
		str(receipt.get("source_causal_day_instance", "")),
		int(receipt.get("source_day", 0)),
	]


func _tuple_equals(a: Array, b: Array) -> bool:
	return a.size() == b.size() and a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]


func _map_prepare_failure(prepared: Dictionary) -> Dictionary:
	if str(prepared.get("code", "")) == "causal_day_advance_conflict":
		return _failed(&"causal_day_advance_identity_conflict", str(prepared.get("message", "")))
	return prepared


func _map_commit_failure(committed: Dictionary) -> Dictionary:
	var code := str(committed.get("code", ""))
	match code:
		"allocation_counter_superseded", "allocation_root_namespace_mismatch", "allocation_candidate_not_reproducible":
			return _failed(&"causal_day_advance_identity_stale", str(committed.get("message", "")))
		"causal_day_advance_conflict":
			return _failed(&"causal_day_advance_identity_conflict", str(committed.get("message", "")))
	return _failed(&"causal_day_advance_identity_commit_rejected", str(committed.get("message", code)))


func _capture_root() -> Dictionary:
	return _identity_issuer.call(&"capture_root")


func _root_fingerprint(document: Dictionary) -> String:
	var emitted := CANONICAL_JSON.stringify(document)
	if not emitted.get("ok", false):
		return ""
	return String(emitted["value"]).sha256_text()


func _prepared_result(receipt: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"code": &"ok",
		"value": {
			"day_advance_identity_candidate": {
				"day_advance_identity_receipt": receipt.duplicate(true),
			},
			"day_advance_identity_receipt": receipt.duplicate(true),
		},
	}


func _sha256(value: Variant) -> Dictionary:
	var emitted := CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return emitted
	return {"ok": true, "value": String(emitted["value"]).sha256_text()}


func _exact_keys(value: Dictionary, expected: Array[String]) -> Dictionary:
	if value.size() != expected.size():
		return _failed(&"causal_day_advance_request_member_set_invalid",
			"expected %d members, saw %d" % [expected.size(), value.size()])
	for key in expected:
		if not value.has(key):
			return _failed(&"causal_day_advance_request_member_set_invalid", "missing " + str(key))
	return {"ok": true}


func _day_advance_key(resolution_kind: String, source_resolution_receipt_id: String) -> String:
	return "%s:%s" % [resolution_kind, source_resolution_receipt_id]


func _verification_receipt(receipt: Dictionary) -> Dictionary:
	var filtered := receipt.duplicate(true)
	if filtered.has("provenance"):
		filtered.erase("provenance")
	return filtered


func _require_configured(method: String) -> Dictionary:
	if _identity_issuer == null:
		return _failed(&"causal_day_advance_identity_not_configured",
			"CausalDayAdvanceIdentityPort.%s before configure" % method)
	return {"ok": true}


func _map_verify_source_receipt(result: Dictionary) -> Dictionary:
	var reason: String = str(result.get("message", "source receipt verification rejected"))
	return _failed(&"causal_day_advance_source_receipt_invalid", reason)


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "CausalDayAdvanceIdentityPort: " + message}
