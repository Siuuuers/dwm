class_name ScheduleStateSchema
extends RefCounted

## The canonical committed-Schedule state schema (Plan 01 Task 4, dwm-p2r.13).
##
## This module owns the exact top-level `committed_schedule` aggregate frozen at plan lines 324-353:
## its member set, its committed entry records, its embedded commit receipt, and the equalities that
## bind the three together. It is pure: no registry, no GameState, no Contacts, no files, no signal,
## no mutation of any input.
##
## It owns NO registry law. Route, effects, motivation cost, allowed days, kind and participants
## come only from `ScheduleActionRegistry` through `ScheduleRules`; a caller-authored `route_id`,
## `effect_ids` or `motivation_cost` is rejected here purely as an unknown member.
##
## RECORDED DIVERGENCE. A receipt-backed EMPTY Done aggregate (`entries == []` with a non-null
## `empty_schedule_done` commit receipt) is legal under the frozen contract and is validated here.
## `ScheduleRules._committed_structure` still rejects that shape, so Task 4 never routes a
## receipt-backed empty aggregate through `ScheduleRules`; Task 5 reconciles the two when
## `RunSnapshotSchema` delegates committed validation to this module.

const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const SCHEMA_VERSION := 1
const FIRST_DAY := 1
const LAST_DAY := 7
const ENDING_DAY := 7
const DAY_BOXES := 7
const DAY7_SLOT := 0
const COMMITTED_STATE := "committed"
const FINGERPRINT_LENGTH := 64

## Exact aggregate members (sorted).
const AGGREGATE_KEYS: Array[String] = [
	"commit_receipt", "day", "entries", "registry_fingerprint", "schema_version",
]
## Exact committed entry members (sorted).
const ENTRY_KEYS: Array[String] = [
	"action_id", "action_kind", "commit_transaction_id", "day", "participants",
	"schedule_entry_id", "schedule_entry_provenance", "slot_index", "source_receipt_id", "state",
]
## Exact commit receipt members (sorted).
const COMMIT_RECEIPT_KEYS: Array[String] = [
	"causal_day_instance", "day", "motivation_charged", "receipt_id", "receipt_provenance",
	"registry_fingerprint", "schedule_entry_ids", "source_receipt_ids", "transaction_id",
	"transaction_issuer_receipt", "view_fingerprint",
]
## Exact issuer child provenance members (sorted); identical to the `.16` issuer contract.
const PROVENANCE_KEYS: Array[String] = [
	"child_id", "child_kind", "ordinal", "parent_receipt_id", "schema_version", "source_ids",
]
## Exact root issuer receipt members (sorted).
const ISSUER_RECEIPT_KEYS: Array[String] = [
	"counter", "namespace", "numeric_value", "purpose", "receipt_id", "token",
]

const ACTION_KINDS: Array[String] = ["ordinary", "solo", "group"]
const ENTRY_CHILD_KIND := "schedule_entry"
const COMMIT_CHILD_KIND := "schedule_commit"
const EMPTY_DONE_CHILD_KIND := "empty_schedule_done"
const ROOT_PURPOSE := "transaction_id"


# ---- construction ----

## The canonical empty aggregate. `registry_fingerprint` is the current fingerprint for a fresh
## logical day, or null for the migrated form; nothing else may omit it.
static func empty_aggregate(day: int, registry_fingerprint: Variant) -> Dictionary:
	if typeof(day) != TYPE_INT or day < FIRST_DAY or day > LAST_DAY:
		return _fail(&"invalid_day", "day must be an int in %d..%d" % [FIRST_DAY, LAST_DAY],
			{"day": day})
	if registry_fingerprint != null and not _is_fingerprint(registry_fingerprint):
		return _fail(&"invalid_committed_schedule",
			"registry_fingerprint is lowercase 64-hex or null",
			{"field": "registry_fingerprint"})
	return _ok({"committed_schedule": {
		"schema_version": SCHEMA_VERSION,
		"day": day,
		"registry_fingerprint": registry_fingerprint,
		"entries": [],
		"commit_receipt": null,
	}})


# ---- validation ----

static func validate_aggregate(aggregate: Variant) -> Dictionary:
	if typeof(aggregate) != TYPE_DICTIONARY:
		return _fail(&"invalid_committed_schedule", "the aggregate must be a dictionary", {})
	var value: Dictionary = aggregate
	var members := _exact_keys(value, AGGREGATE_KEYS, &"invalid_committed_schedule")
	if not members.is_empty():
		return members
	if typeof(value["schema_version"]) != TYPE_INT or int(value["schema_version"]) != SCHEMA_VERSION:
		return _fail(&"invalid_committed_schedule", "unsupported schema_version",
			{"field": "schema_version"})
	var day_value: Variant = value["day"]
	if typeof(day_value) != TYPE_INT or int(day_value) < FIRST_DAY or int(day_value) > LAST_DAY:
		return _fail(&"invalid_day", "day must be an int in %d..%d" % [FIRST_DAY, LAST_DAY],
			{"day": day_value})
	var day := int(day_value)
	if typeof(value["entries"]) != TYPE_ARRAY:
		return _fail(&"invalid_committed_schedule", "entries must be an array", {"field": "entries"})
	var entries: Array = value["entries"]
	var receipt: Variant = value["commit_receipt"]
	if receipt != null and typeof(receipt) != TYPE_DICTIONARY:
		return _fail(&"invalid_committed_schedule",
			"commit_receipt is a dictionary or null", {"field": "commit_receipt"})
	if not entries.is_empty() and receipt == null:
		return _fail(&"invalid_committed_schedule",
			"a nonempty aggregate embeds its exact commit receipt", {"field": "commit_receipt"})
	var fingerprint: Variant = value["registry_fingerprint"]
	if fingerprint == null:
		# Legal only for the migrated empty, uncommitted aggregate.
		if not entries.is_empty() or receipt != null:
			return _fail(&"invalid_committed_schedule",
				"only an empty, uncommitted aggregate may omit the registry fingerprint",
				{"field": "registry_fingerprint"})
	elif not _is_fingerprint(fingerprint):
		return _fail(&"invalid_committed_schedule",
			"registry_fingerprint is lowercase 64-hex or null", {"field": "registry_fingerprint"})

	var transaction_id: Variant = null
	if receipt != null:
		var receipt_result := validate_commit_receipt(receipt)
		if not receipt_result.get("ok", false):
			return receipt_result
		transaction_id = str((receipt as Dictionary)["transaction_id"])

	var seen_ids: Dictionary = {}
	var previous_slot := -1
	for index: int in range(entries.size()):
		var entry_error := _entry_error(entries[index], index, day, transaction_id, seen_ids,
			previous_slot)
		if not entry_error.is_empty():
			return entry_error
		previous_slot = int((entries[index] as Dictionary)["slot_index"])
		seen_ids[str((entries[index] as Dictionary)["schedule_entry_id"])] = true

	if receipt != null:
		var binding := _receipt_binding_error(receipt as Dictionary, entries, day, fingerprint)
		if not binding.is_empty():
			return binding
	return _ok({"committed_schedule": _detach(value)})


static func validate_commit_receipt(receipt: Variant) -> Dictionary:
	if typeof(receipt) != TYPE_DICTIONARY:
		return _fail(&"invalid_commit_receipt", "the commit receipt must be a dictionary", {})
	var value: Dictionary = receipt
	var members := _exact_keys(value, COMMIT_RECEIPT_KEYS, &"invalid_commit_receipt")
	if not members.is_empty():
		return members
	for field: String in ["receipt_id", "transaction_id", "causal_day_instance", "view_fingerprint"]:
		if not _is_nonblank_string(value[field]):
			return _fail(&"invalid_commit_receipt", field + " must be a nonblank String",
				{"field": field})
	if typeof(value["day"]) != TYPE_INT or int(value["day"]) < FIRST_DAY \
			or int(value["day"]) > LAST_DAY:
		return _fail(&"invalid_commit_receipt", "day must be an int in 1..7", {"field": "day"})
	if not _is_fingerprint(value["registry_fingerprint"]):
		return _fail(&"invalid_commit_receipt", "registry_fingerprint is lowercase 64-hex",
			{"field": "registry_fingerprint"})
	var issuer := _issuer_receipt_error(value["transaction_issuer_receipt"],
		str(value["transaction_id"]))
	if not issuer.is_empty():
		return issuer
	if typeof(value["schedule_entry_ids"]) != TYPE_ARRAY \
			or typeof(value["source_receipt_ids"]) != TYPE_ARRAY:
		return _fail(&"invalid_commit_receipt", "the two ordered ID arrays are arrays",
			{"field": "schedule_entry_ids"})
	var entry_ids: Array = value["schedule_entry_ids"]
	var source_ids: Array = value["source_receipt_ids"]
	if entry_ids.size() != source_ids.size():
		return _fail(&"invalid_commit_receipt", "the two ordered ID arrays align element-wise",
			{"field": "source_receipt_ids"})
	var seen: Dictionary = {}
	for entry_id: Variant in entry_ids:
		if not _is_nonblank_string(entry_id):
			return _fail(&"invalid_commit_receipt", "a schedule entry id is a nonblank String",
				{"field": "schedule_entry_ids"})
		if seen.has(str(entry_id)):
			return _fail(&"invalid_commit_receipt", "schedule entry ids are unique",
				{"field": "schedule_entry_ids"})
		seen[str(entry_id)] = true
	for source_id: Variant in source_ids:
		if source_id != null and not _is_nonblank_string(source_id):
			return _fail(&"invalid_commit_receipt", "a source receipt id is a nonblank String or null",
				{"field": "source_receipt_ids"})
	if typeof(value["motivation_charged"]) != TYPE_INT \
			or int(value["motivation_charged"]) != entry_ids.size():
		return _fail(&"invalid_commit_receipt",
			"motivation_charged is exactly one per committed entry",
			{"field": "motivation_charged"})
	var expected_kind := EMPTY_DONE_CHILD_KIND if entry_ids.is_empty() else COMMIT_CHILD_KIND
	var provenance := _provenance_error(value["receipt_provenance"], expected_kind, 0,
		str(value["receipt_id"]), &"invalid_commit_receipt")
	if not provenance.is_empty():
		return provenance
	return _ok({"commit_receipt": _detach(value)})


# ---- canonical projection (the plan's exact J/H notation) ----

static func canonical_json(value: Variant) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_WRITER.stringify(value)
	if not emitted.get("ok", false):
		return _fail(&"noncanonical_value", "the value is not canonically representable",
			{"cause": emitted.get("code", &"")})
	return _ok({"text": str(emitted["value"])})


static func canonical_sha256(value: Variant) -> Dictionary:
	var canonical := canonical_json(value)
	if not canonical.get("ok", false):
		return canonical
	return _ok({"sha256": _sha256_hex(str((canonical["value"] as Dictionary)["text"]))})


# ---- entry / receipt law ----

static func _entry_error(raw: Variant, index: int, day: int, transaction_id: Variant,
		seen_ids: Dictionary, previous_slot: int) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(&"invalid_committed_entry", "a committed entry must be a dictionary",
			{"index": index})
	var entry: Dictionary = raw
	var members := _exact_keys(entry, ENTRY_KEYS, &"invalid_committed_entry")
	if not members.is_empty():
		return members
	for field: String in ["schedule_entry_id", "action_id", "commit_transaction_id"]:
		if not _is_nonblank_string(entry[field]):
			return _fail(&"invalid_committed_entry", field + " must be a nonblank String",
				{"index": index, "field": field})
	if typeof(entry["action_kind"]) != TYPE_STRING or str(entry["action_kind"]) not in ACTION_KINDS:
		return _fail(&"invalid_committed_entry", "action_kind must be one of " + str(ACTION_KINDS),
			{"index": index, "field": "action_kind"})
	if typeof(entry["day"]) != TYPE_INT or int(entry["day"]) != day:
		return _fail(&"invalid_committed_entry", "entry day must equal the aggregate day",
			{"index": index, "field": "day"})
	if typeof(entry["slot_index"]) != TYPE_INT:
		return _fail(&"invalid_committed_entry", "slot_index must be a strict int, never coerced",
			{"index": index, "field": "slot_index"})
	var slot := int(entry["slot_index"])
	if day == ENDING_DAY:
		if slot != DAY7_SLOT:
			return _fail(&"invalid_committed_entry", "the Day-7 destination sits at slot zero",
				{"index": index, "field": "slot_index"})
	elif slot < 0 or slot >= DAY_BOXES:
		return _fail(&"invalid_committed_entry", "Days 1-6 expose slots 0..%d" % (DAY_BOXES - 1),
			{"index": index, "field": "slot_index"})
	if slot <= previous_slot:
		return _fail(&"invalid_committed_entry",
			"committed entries ascend by slot_index and hold one entry per slot",
			{"index": index, "field": "slot_index"})
	if typeof(entry["participants"]) != TYPE_ARRAY:
		return _fail(&"invalid_committed_entry", "participants must be an array",
			{"index": index, "field": "participants"})
	for participant: Variant in entry["participants"] as Array:
		if not _is_nonblank_string(participant):
			return _fail(&"invalid_committed_entry", "participants are nonblank Strings",
				{"index": index, "field": "participants"})
	var source: Variant = entry["source_receipt_id"]
	if source != null and not _is_nonblank_string(source):
		return _fail(&"invalid_committed_entry", "source_receipt_id is a nonblank String or null",
			{"index": index, "field": "source_receipt_id"})
	if str(entry["state"]) != COMMITTED_STATE or typeof(entry["state"]) != TYPE_STRING:
		return _fail(&"invalid_committed_entry", "a committed entry is in the committed state",
			{"index": index, "field": "state"})
	if seen_ids.has(str(entry["schedule_entry_id"])):
		return _fail(&"invalid_committed_entry", "committed entry ids are unique",
			{"index": index, "field": "schedule_entry_id"})
	if transaction_id != null and str(entry["commit_transaction_id"]) != str(transaction_id):
		return _fail(&"invalid_committed_entry", "every entry names its own commit transaction",
			{"index": index, "field": "commit_transaction_id"})
	return _provenance_error(entry["schedule_entry_provenance"], ENTRY_CHILD_KIND, index,
		str(entry["schedule_entry_id"]), &"invalid_committed_entry")


static func _receipt_binding_error(receipt: Dictionary, entries: Array, day: int,
		fingerprint: Variant) -> Dictionary:
	if int(receipt["day"]) != day:
		return _fail(&"invalid_commit_receipt", "receipt day must equal the aggregate day",
			{"field": "day"})
	if fingerprint == null or str(receipt["registry_fingerprint"]) != str(fingerprint):
		return _fail(&"invalid_commit_receipt",
			"receipt registry_fingerprint must equal the aggregate fingerprint",
			{"field": "registry_fingerprint"})
	var entry_ids: Array = receipt["schedule_entry_ids"]
	var source_ids: Array = receipt["source_receipt_ids"]
	if entry_ids.size() != entries.size():
		return _fail(&"invalid_commit_receipt", "every committed entry appears in the receipt",
			{"field": "schedule_entry_ids"})
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if str(entry_ids[index]) != str(entry["schedule_entry_id"]):
			return _fail(&"invalid_commit_receipt",
				"the receipt ID array follows committed slot order",
				{"field": "schedule_entry_ids", "index": index})
		if source_ids[index] != entry["source_receipt_id"]:
			return _fail(&"invalid_commit_receipt",
				"the source array aligns element-wise with the committed entries",
				{"field": "source_receipt_ids", "index": index})
	return {}


static func _provenance_error(raw: Variant, child_kind: String, ordinal: int, child_id: String,
		code: StringName) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(code, "the child provenance must be a dictionary", {"field": "provenance"})
	var provenance: Dictionary = raw
	var members := _exact_keys(provenance, PROVENANCE_KEYS, code)
	if not members.is_empty():
		return members
	if typeof(provenance["schema_version"]) != TYPE_INT \
			or int(provenance["schema_version"]) != SCHEMA_VERSION:
		return _fail(code, "unexpected provenance schema_version", {"field": "provenance"})
	if not _is_nonblank_string(provenance["parent_receipt_id"]):
		return _fail(code, "the provenance names its parent receipt", {"field": "provenance"})
	if typeof(provenance["child_kind"]) != TYPE_STRING or str(provenance["child_kind"]) != child_kind:
		return _fail(code, "the provenance child_kind is exactly " + child_kind,
			{"field": "provenance"})
	if typeof(provenance["ordinal"]) != TYPE_INT or int(provenance["ordinal"]) != ordinal:
		return _fail(code, "the provenance ordinal is %d" % ordinal, {"field": "provenance"})
	if typeof(provenance["source_ids"]) != TYPE_ARRAY:
		return _fail(code, "the provenance source_ids must be an array", {"field": "provenance"})
	var sources: Array = provenance["source_ids"]
	if sources.is_empty():
		return _fail(code, "a Plan-01 row projects at least one source token",
			{"field": "provenance"})
	var previous := ""
	for index: int in range(sources.size()):
		if not _is_nonblank_string(sources[index]):
			return _fail(code, "source tokens are nonblank Strings", {"field": "provenance"})
		if index > 0 and str(sources[index]) <= previous:
			return _fail(code, "source tokens are sorted and unique", {"field": "provenance"})
		previous = str(sources[index])
	if str(provenance["child_id"]) != child_id:
		return _fail(code, "the provenance child_id equals the identity it proves",
			{"field": "provenance"})
	return {}


static func _issuer_receipt_error(raw: Variant, transaction_id: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(&"invalid_commit_receipt",
			"the full transaction issuer receipt is required", {"field": "transaction_issuer_receipt"})
	var receipt: Dictionary = raw
	var members := _exact_keys(receipt, ISSUER_RECEIPT_KEYS, &"invalid_commit_receipt")
	if not members.is_empty():
		return members
	for field: String in ["receipt_id", "namespace", "purpose", "token"]:
		if not _is_nonblank_string(receipt[field]):
			return _fail(&"invalid_commit_receipt", "issuer receipt " + field + " is a nonblank String",
				{"field": "transaction_issuer_receipt"})
	if str(receipt["purpose"]) != ROOT_PURPOSE:
		return _fail(&"invalid_commit_receipt", "the commit root has purpose " + ROOT_PURPOSE,
			{"field": "transaction_issuer_receipt"})
	if str(receipt["token"]) != transaction_id:
		return _fail(&"invalid_commit_receipt", "the issuer receipt token equals transaction_id",
			{"field": "transaction_issuer_receipt"})
	if typeof(receipt["counter"]) != TYPE_INT or int(receipt["counter"]) < 0:
		return _fail(&"invalid_commit_receipt", "the issuer counter is a nonnegative int",
			{"field": "transaction_issuer_receipt"})
	if receipt["numeric_value"] != null:
		return _fail(&"invalid_commit_receipt", "a transaction root carries no numeric value",
			{"field": "transaction_issuer_receipt"})
	return {}


# ---- helpers ----

static func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(code, "the member set is exactly " + str(expected), {"members": keys})
	return {}


static func _is_nonblank_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty()


static func _is_fingerprint(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != FINGERPRINT_LENGTH:
		return false
	for codepoint: int in (value as String).to_ascii_buffer():
		if not (codepoint >= 0x30 and codepoint <= 0x39) \
				and not (codepoint >= 0x61 and codepoint <= 0x66):
			return false
	return true


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _detach(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
