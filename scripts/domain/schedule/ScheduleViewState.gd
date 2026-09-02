class_name ScheduleViewState
extends RefCounted

## The saved, uncommitted Schedule day view (Amendment Plan 03 Task 2, dwm-oyo.3).
##
## Exact frozen static surface from the plan (Task 2 Step 3). The top-level view is EXACTLY
## the seven-key shape; each entry is exactly the seven-key draft entry ScheduleRules owns;
## the condition-departure receipt index is an append-only Dictionary keyed by exact
## source_condition_receipt_id with the exact five-key value shape.
##
## LAW ROUTING. This module owns only what `.7` does not: the view envelope shape, the
## condition-departure ledger value law, the optimistic fingerprint, and detachment. Every
## entry/day/date/repeat law routes through the consumed ScheduleRules.validate_draft --
## never rebuilt here. Because the view level holds no Contacts receipt index, validate()
## rechecks the source-receipt CLASS only: it fabricates a class-shaped receipt index from
## the registry records it resolves through ScheduleActionRegistry.lookup() at the expected
## fingerprint, so ScheduleRules' source law degenerates to the class check. True acceptance
## ancestry stays where `.7` put it: the Schedule commit port.
##
## validate() never treats a fingerprint string alone as proof -- the expected fingerprint
## must equal the live registry's own, and every action ID must resolve. A null fingerprint
## is legal ONLY for an empty view during accepted legacy-empty restore. The optimistic
## fingerprint is lowercase SHA-256 of canonical JSON over exactly {day, causal_day_instance,
## entries, date_entry_seen, pending_warning, consumed_warning_receipts} plus the expected
## registry fingerprint; it deliberately excludes condition_departure_receipts (appending
## recovery evidence cannot stale an already-issued view expectation), while validate()'s
## schema pass still checks that ledger byte-for-byte.

const _RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Exact top-level view keys (sorted).
const VIEW_KEYS: Array = [
	"causal_day_instance", "condition_departure_receipts", "consumed_warning_receipts",
	"date_entry_seen", "day", "entries", "pending_warning",
]
## Exact condition-departure receipt value keys (sorted).
const CONDITION_RECEIPT_KEYS: Array = [
	"disposition", "schedule_view_after_sha256", "schedule_view_before_sha256",
	"source_condition_receipt_id", "source_condition_receipt_provenance",
]
const CONDITION_DISPOSITION := "condition_departure_view_committed"
const FIRST_DAY := 1
const LAST_DAY := 7
const _HEX := "0123456789abcdef"


static func make_empty(day: int, causal_day_instance: String) -> Dictionary:
	if day < FIRST_DAY or day > LAST_DAY:
		return _fail(&"invalid_day", "day must be an int in %d..%d" % [FIRST_DAY, LAST_DAY],
			{"day": day})
	if causal_day_instance.is_empty():
		return _fail(&"invalid_causal_day_instance",
			"a nonempty causal day instance is required", {})
	return _ok({"view": {
		"day": day,
		"causal_day_instance": causal_day_instance,
		"entries": [],
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}})


static func validate(view: Dictionary, action_registry: Object,
		expected_registry_fingerprint: Variant) -> Dictionary:
	var shape := _view_shape_error(view)
	if not shape.is_empty():
		return shape
	if action_registry == null or not action_registry.has_method("fingerprint") \
			or not action_registry.has_method("lookup"):
		return _fail(&"invalid_registry",
			"an injected registry with lookup() and fingerprint() is required", {})
	var entries: Array = view["entries"]
	var expected := ""
	if expected_registry_fingerprint == null:
		# Legal only for the empty view an accepted legacy-empty restore produces.
		if not entries.is_empty():
			return _fail(&"invalid_expected_fingerprint",
				"a null fingerprint is legal only for an empty legacy-restored view",
				{"entry_count": entries.size()})
		expected = str(action_registry.fingerprint())
	elif typeof(expected_registry_fingerprint) != TYPE_STRING \
			or str(expected_registry_fingerprint).is_empty():
		return _fail(&"invalid_expected_fingerprint",
			"an expected registry fingerprint must be a nonempty String",
			{"expected": expected_registry_fingerprint})
	else:
		expected = str(expected_registry_fingerprint)
		var actual := str(action_registry.fingerprint())
		if expected != actual:
			return _fail(&"stale_registry_fingerprint",
				"the registry no longer matches the expected fingerprint",
				{"expected": expected, "actual": actual})
	var ledger := _ledger_error(view["condition_departure_receipts"])
	if not ledger.is_empty():
		return ledger
	var drafted: Dictionary = _RULES.validate_draft(int(view["day"]), entries, action_registry,
		expected, _source_class_index(entries, action_registry, expected))
	if not drafted.get("ok", false):
		return drafted
	return _ok({"view": view.duplicate(true)})


static func fingerprint(view: Dictionary, action_registry: Object,
		expected_registry_fingerprint: Variant) -> Dictionary:
	var validated := validate(view, action_registry, expected_registry_fingerprint)
	if not validated.get("ok", false):
		return validated
	var preimage := {
		"day": view["day"],
		"causal_day_instance": view["causal_day_instance"],
		"entries": (view["entries"] as Array).duplicate(true),
		"date_entry_seen": view["date_entry_seen"],
		"pending_warning": view["pending_warning"],
		"consumed_warning_receipts":
			(view["consumed_warning_receipts"] as Dictionary).duplicate(true),
		"expected_registry_fingerprint": expected_registry_fingerprint,
	}
	var canonical: Dictionary = _CANONICAL_JSON.stringify(preimage)
	if not canonical.get("ok", false):
		return _fail(&"noncanonical_schedule_view", "the view is not canonicalizable",
			{"cause": canonical.get("code", &"")})
	return _ok({"fingerprint": _digest(str(canonical["value"]))})


static func detached(view: Dictionary) -> Dictionary:
	return _ok({"view": view.duplicate(true)})


# ---- the view-envelope law this module owns ----

static func _view_shape_error(view: Dictionary) -> Dictionary:
	var keys: Array = view.keys()
	keys.sort()
	if keys != VIEW_KEYS:
		return _view_fault("the view carries exactly " + str(VIEW_KEYS), "keys")
	if typeof(view["day"]) != TYPE_INT:
		return _view_fault("day is a strict int, never coerced", "day")
	if typeof(view["causal_day_instance"]) != TYPE_STRING \
			or str(view["causal_day_instance"]).is_empty():
		return _view_fault("causal_day_instance is a nonempty String", "causal_day_instance")
	if typeof(view["entries"]) != TYPE_ARRAY:
		return _view_fault("entries is an Array", "entries")
	if typeof(view["date_entry_seen"]) != TYPE_BOOL:
		return _view_fault("date_entry_seen is a strict bool", "date_entry_seen")
	if typeof(view["consumed_warning_receipts"]) != TYPE_DICTIONARY:
		return _view_fault("consumed_warning_receipts is a Dictionary",
			"consumed_warning_receipts")
	if typeof(view["condition_departure_receipts"]) != TYPE_DICTIONARY:
		return _view_fault("condition_departure_receipts is a Dictionary",
			"condition_departure_receipts")
	return {}


static func _ledger_error(ledger: Dictionary) -> Dictionary:
	for key: Variant in ledger:
		if typeof(key) != TYPE_STRING:
			return _receipt_fault(str(key),
				"the index key is a String, never a StringName alias", "key")
		var raw: Variant = ledger[key]
		if typeof(raw) != TYPE_DICTIONARY:
			return _receipt_fault(str(key), "a retained receipt is a Dictionary", "value")
		var receipt := raw as Dictionary
		var keys: Array = receipt.keys()
		keys.sort()
		if keys != CONDITION_RECEIPT_KEYS:
			return _receipt_fault(str(key),
				"a retained receipt carries exactly " + str(CONDITION_RECEIPT_KEYS), "keys")
		var source_id: Variant = receipt["source_condition_receipt_id"]
		if typeof(source_id) != TYPE_STRING or str(source_id).is_empty() \
				or str(key) != str(source_id):
			return _receipt_fault(str(key),
				"the index key equals the receipt's nonempty source id",
				"source_condition_receipt_id")
		var provenance: Variant = receipt["source_condition_receipt_provenance"]
		if typeof(provenance) != TYPE_DICTIONARY or (provenance as Dictionary).is_empty():
			return _receipt_fault(str(key), "provenance is a nonempty Dictionary",
				"source_condition_receipt_provenance")
		for field: String in ["schedule_view_before_sha256", "schedule_view_after_sha256"]:
			if not _is_lower_sha256(receipt[field]):
				return _receipt_fault(str(key),
					field + " is 64 lowercase sha256 hex characters", field)
		var disposition: Variant = receipt["disposition"]
		if typeof(disposition) != TYPE_STRING \
				or str(disposition) != CONDITION_DISPOSITION:
			return _receipt_fault(str(key),
				"the disposition is exactly the String " + CONDITION_DISPOSITION,
				"disposition")
		# An Object anywhere in a retained receipt is a live aliasing channel that
		# duplicate(true) cannot detach; canonicalizability is the byte-for-byte law.
		var canonical: Dictionary = _CANONICAL_JSON.stringify(receipt)
		if not canonical.get("ok", false):
			return _receipt_fault(str(key),
				"a retained receipt canonicalizes byte-for-byte; it carries no Object",
				"value")
	return {}


## The class-shaped receipt index validate() hands ScheduleRules. Built from the registry
## records themselves (resolved through lookup() at the verified expected fingerprint), so
## the consumed source law degenerates to the source-receipt CLASS check the view level
## owns. Entries that are malformed or unregistered are skipped here on purpose: the
## delegated ScheduleRules pass reports them with its own typed codes.
static func _source_class_index(entries: Array, action_registry: Object,
		expected: String) -> Dictionary:
	var index: Dictionary = {}
	for raw: Variant in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry := raw as Dictionary
		var action_id: Variant = entry.get("action_id")
		var source_id: Variant = entry.get("source_receipt_id")
		var day: Variant = entry.get("day")
		if typeof(action_id) != TYPE_STRING or typeof(source_id) != TYPE_STRING \
				or str(source_id).is_empty() or typeof(day) != TYPE_INT:
			continue
		var found: Dictionary = action_registry.lookup(str(action_id), expected)
		if not found.get("ok", false):
			continue
		var record: Dictionary = (found["value"] as Dictionary)["record"]
		if record["source_receipt_kind"] == null:
			continue
		index[str(source_id)] = {
			"receipt_id": str(source_id),
			"receipt_provenance": {"origin": "schedule_view_source_class_recheck"},
			"kind": str(record["source_receipt_kind"]),
			"action_id": str(action_id),
			"day": int(day),
			"participants": (record["participants"] as Array).duplicate(true),
			"previous_receipt_id": "schedule_view:offer_resolved_at_commit_port",
		}
	return index


# ---- helpers ----

static func _is_lower_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.length() != 64:
		return false
	for index: int in range(text.length()):
		if not _HEX.contains(text[index]):
			return false
	return true


static func _digest(canonical: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


static func _view_fault(message: String, field: String) -> Dictionary:
	return _fail(&"invalid_schedule_view", message, {"field": field})


static func _receipt_fault(key: String, message: String, field: String) -> Dictionary:
	return _fail(&"invalid_condition_departure_receipt", message,
		{"source_condition_receipt_id": key, "field": field})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
