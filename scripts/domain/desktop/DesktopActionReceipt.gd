class_name DesktopActionReceipt
extends RefCounted

## Frozen desktop action receipt shape (Plan 02 Task 7, dwm-p2r.32.7, req.desktop
## .cross_app_actions), plan02-frozen-contracts.md brief lines 56-76. This is the exact record every
## successfully prepared `minesweeper_round`/`shop_purchase` action produces; it becomes committed
## only after causal admission (Task 8). This file is a pure structural law -- validate/fingerprint
## only -- and never touches live state, an issuer, or a checkpoint port.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _KEYS: Array[String] = [
	"schema_version", "action_id", "action_id_provenance", "action_kind", "run_id", "branch_id",
	"desktop_timeline_generation", "causal_day_instance", "day", "transaction_id",
	"transaction_issuer_receipt", "source_commit_receipt_id", "source_commit_receipt_provenance",
	"condition_before", "condition_after", "unlock_receipt_ids", "commit_receipt_id",
	"commit_receipt_provenance",
]
const ACTION_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]
const _CONDITION_KEYS: Array[String] = ["health", "pressure", "carried_sequela"]
## Mirrors DesktopIdentityNonceIssuer.PROVENANCE_KEYS exactly: every anchored-child provenance in
## this codebase (issuer-minted or remapped) carries precisely these six members.
const _PROVENANCE_KEYS: Array[String] = [
	"child_id", "child_kind", "ordinal", "parent_receipt_id", "schema_version", "source_ids",
]
const _NONBLANK_STRING_FIELDS: Array[String] = [
	"action_id", "run_id", "branch_id", "causal_day_instance", "transaction_id",
	"source_commit_receipt_id", "commit_receipt_id",
]
const _DICTIONARY_FIELDS: Array[String] = [
	"action_id_provenance", "transaction_issuer_receipt", "source_commit_receipt_provenance",
	"commit_receipt_provenance",
]


static func validate(receipt: Dictionary) -> Dictionary:
	var shape := _exact_keys(receipt, _KEYS, &"action_receipt_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(receipt["schema_version"]) != TYPE_INT or int(receipt["schema_version"]) != 1:
		return _fail(&"action_receipt_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})
	for field: String in _NONBLANK_STRING_FIELDS:
		if typeof(receipt[field]) != TYPE_STRING or str(receipt[field]).strip_edges().is_empty():
			return _fail(&"action_receipt_field_invalid", field + " must be a nonblank string", {"field": field})
	if str(receipt["action_kind"]) not in ACTION_KINDS:
		return _fail(&"action_receipt_field_invalid",
			"action_kind must be minesweeper_round or shop_purchase", {"field": "action_kind"})
	if typeof(receipt["desktop_timeline_generation"]) != TYPE_INT or int(receipt["desktop_timeline_generation"]) < 0:
		return _fail(&"action_receipt_field_invalid",
			"desktop_timeline_generation must be a nonnegative integer", {"field": "desktop_timeline_generation"})
	if typeof(receipt["day"]) != TYPE_INT:
		return _fail(&"action_receipt_field_invalid", "day must be an integer", {"field": "day"})
	for field: String in _DICTIONARY_FIELDS:
		if typeof(receipt[field]) != TYPE_DICTIONARY:
			return _fail(&"action_receipt_field_invalid", field + " must be an object", {"field": field})
	var action_id_provenance_shape := _exact_keys(
		receipt["action_id_provenance"], _PROVENANCE_KEYS, &"action_receipt_field_invalid")
	if not action_id_provenance_shape.get("ok", false):
		return action_id_provenance_shape
	var commit_receipt_provenance_shape := _exact_keys(
		receipt["commit_receipt_provenance"], _PROVENANCE_KEYS, &"action_receipt_field_invalid")
	if not commit_receipt_provenance_shape.get("ok", false):
		return commit_receipt_provenance_shape
	var condition_before_check := _validate_condition(receipt["condition_before"])
	if not condition_before_check.get("ok", false):
		return condition_before_check
	var condition_after_check := _validate_condition(receipt["condition_after"])
	if not condition_after_check.get("ok", false):
		return condition_after_check
	if typeof(receipt["unlock_receipt_ids"]) != TYPE_ARRAY:
		return _fail(&"action_receipt_field_invalid", "unlock_receipt_ids must be an array", {"field": "unlock_receipt_ids"})
	var sorted_unique_check := _validate_sorted_unique_nonblank_strings(receipt["unlock_receipt_ids"])
	if not sorted_unique_check.get("ok", false):
		return sorted_unique_check
	return {"ok": true, "code": &"ok", "value": {"receipt": receipt.duplicate(true)}, "receipt": {}}


## Lowercase SHA-256 of the canonical detached receipt, used by callers as the receipt's own
## content-identity anchor (e.g. `action_candidate_sha256` in the recovery payload). Only ever
## fingerprints an already-`validate()`d receipt.
static func fingerprint(receipt: Dictionary) -> Dictionary:
	var validated := validate(receipt)
	if not validated.get("ok", false):
		return validated
	var emitted: Dictionary = _CANONICAL_JSON.stringify((validated["value"] as Dictionary)["receipt"])
	if not emitted.get("ok", false):
		return _fail(&"action_receipt_not_canonicalizable", "receipt is not canonically representable", {})
	return {"ok": true, "code": &"ok", "value": {"fingerprint": str(emitted["value"]).sha256_text()}, "receipt": {}}


static func _validate_condition(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(&"action_receipt_field_invalid", "condition must be an object", {})
	var shape := _exact_keys(value, _CONDITION_KEYS, &"action_receipt_field_invalid")
	if not shape.get("ok", false):
		return shape
	var condition: Dictionary = value
	if typeof(condition["health"]) != TYPE_INT:
		return _fail(&"action_receipt_field_invalid", "condition.health must be an integer", {})
	if typeof(condition["pressure"]) != TYPE_INT:
		return _fail(&"action_receipt_field_invalid", "condition.pressure must be an integer", {})
	if typeof(condition["carried_sequela"]) != TYPE_BOOL:
		return _fail(&"action_receipt_field_invalid", "condition.carried_sequela must be a boolean", {})
	return {"ok": true}


static func _validate_sorted_unique_nonblank_strings(values: Array) -> Dictionary:
	var previous := ""
	for index in range(values.size()):
		if typeof(values[index]) != TYPE_STRING:
			return _fail(&"action_receipt_field_invalid", "unlock_receipt_ids must contain only strings", {})
		var current := str(values[index])
		if current.strip_edges().is_empty():
			return _fail(&"action_receipt_field_invalid", "unlock_receipt_ids must be nonblank", {})
		if index > 0 and current <= previous:
			return _fail(&"action_receipt_field_invalid", "unlock_receipt_ids must be sorted and unique", {})
		previous = current
	return {"ok": true}


static func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
