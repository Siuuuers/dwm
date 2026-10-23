class_name ConditionHospitalPlan
extends RefCounted

## The persisted pre-Done condition-Hospital resolution plan value
## (Amendment Plan 03 Task 4, dwm-oyo.3).
##
## Static-only, like ScheduleViewState. The stored value is the exact strict primitive Dictionary
## (plan:908) and never a live object; ConditionHospitalState is the sole plan-state mutation seam
## (plan:936), so nothing here mutates anything. Every static returns the master four-key envelope
## -- {ok, code, value, receipt} on success, {ok, code, message, details} on failure -- so a caller
## reads one shape from every one of them.
##
## LAW ROUTING. This module owns the plan value's own shape: the exact seventeen-key envelope, the
## six immutable stage ids and their records, the cursor/prefix relation, the stage-key spelling and
## the retirement-history record. It deliberately does NOT own the identity-split matrix or the
## lifecycle couplings -- those are RunLifecycle._validate_condition_lifecycle, the single owner the
## snapshot schema delegates to. It also stops at every Task-7 boundary: the per-stage `output`
## schemas, the stage_input_receipt_ids projections, the identity derivation of the
## P03.condition_hospital.* rows, the contact_source element interior, and ledger/ancestry validation
## of the issuer receipts all belong to Task 7. Where a member's interior belongs to a Task-7 port,
## this module requires the container type and only the cross-references it can see, then stops.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const SCHEMA_VERSION := 1
const RESOLUTION_KIND := "condition_hospital"

## Exact top-level plan keys (sorted).
const PLAN_KEYS: Array[String] = [
	"accepted_sources", "action_receipt", "branch_id", "causal_day_instance",
	"causal_day_instance_issuer_receipt", "condition_receipt", "cursor",
	"desktop_timeline_generation", "destination_record", "resolution_kind", "resolution_receipt",
	"run_id", "schema_version", "source_day", "stages", "transaction_id",
	"transaction_issuer_receipt",
]

## The six stages in their IMMUTABLE order. Stages are never removed or renumbered, so a stage's
## index in this array is its permanent ordinal.
const STAGE_IDS: Array[String] = [
	"close_invitation_sources", "present_hospital", "resolve_deferred_pair",
	"present_deferred_pair", "advance_day", "autosave_new_day",
]

## Exact stage-record keys (sorted). The name deliberately mirrors DayResolutionPlan.STAGE_KEYS.
const STAGE_KEYS: Array[String] = [
	"prepared", "receipt", "stage_id", "stage_identity", "stage_key", "state",
]
const STAGE_STATES: Array[String] = ["pending", "active", "completed"]
const STAGE_COUNT := 6
const FIRST_SOURCE_DAY := 1
const LAST_SOURCE_DAY := 6
## `advance_day` is the only stage whose activity legalises a source/target identity split.
const ADVANCE_DAY_STAGE_INDEX := 4

## Member sets this module has to check but does not own. Private on purpose: the public surface is
## the six statics plus the frozen constants above, and nothing else.
## Byte-identical to RunLifecycle._ISSUER_RECEIPT_KEYS, the single owner of the issuer shape.
const _ISSUER_RECEIPT_KEYS: Array[String] = [
	"counter", "namespace", "numeric_value", "purpose", "receipt_id", "token",
]
const _HISTORY_RECORD_KEYS: Array[String] = ["completed_plan", "retirement_receipt"]
const _RETIREMENT_RECEIPT_KEYS: Array[String] = [
	"autosave_stage_receipt_id", "completed_plan_sha256", "disposition", "receipt_id",
	"receipt_provenance", "resolution_kind", "resolution_receipt_id", "source_day",
	"target_causal_day_instance", "target_day",
]
const _RETIREMENT_DISPOSITION := "condition_hospital_plan_retired"


## Validates the exact strict primitive plan value. Value is {}.
static func validate(plan: Dictionary) -> Dictionary:
	var keys: Array = plan.keys()
	keys.sort()
	if keys != PLAN_KEYS:
		return _fault(&"invalid_plan_shape", "keys",
			"the plan carries exactly the seventeen keys " + str(PLAN_KEYS))
	# The closed world is a TYPE law before it is a member law: a Callable, an Object or a
	# StringName alias anywhere inside is a live channel duplicate(true) cannot detach.
	var impure := _impure_member(plan, "plan")
	if impure != "":
		return _fail(&"impure_value",
			impure + " is not one of Dictionary/Array/String/int/bool/null/float",
			{"member": impure})
	var members := _member_error(plan)
	if not members.is_empty():
		return members
	var identity := _issuer_receipt_error(plan)
	if not identity.is_empty():
		return identity
	var sources := _sources_error(plan)
	if not sources.is_empty():
		return sources
	var destination := _destination_error(plan)
	if not destination.is_empty():
		return destination
	var stages := _stages_error(plan)
	if not stages.is_empty():
		return stages
	return _ok({})


## Answers whether the plan is the complete cursor-6 all-completed shape.
## Value is {complete: bool}.
static func is_complete(plan: Dictionary) -> Dictionary:
	var validated := validate(plan)
	if not validated.get("ok", false):
		return validated
	return _ok({"complete": _is_complete_shape(plan)})


## The cursor record and its index. Value is {index: int, stage: Dictionary|null}.
static func cursor_stage(plan: Dictionary) -> Dictionary:
	var validated := validate(plan)
	if not validated.get("ok", false):
		return validated
	var cursor := int(plan["cursor"])
	if cursor == STAGE_COUNT:
		return _ok({"index": cursor, "stage": null})
	var record: Dictionary = (plan["stages"] as Array)[cursor]
	return _ok({"index": cursor, "stage": record.duplicate(true)})


## The frozen lookup spelling `resolution_receipt_id + ":" + stage_id` -- never a transaction id, an
## issuer root, a receipt id or a checkpoint identity. Value is {stage_key: String}.
static func stage_key(resolution_receipt_id: String, stage_id: String) -> Dictionary:
	if resolution_receipt_id.strip_edges().is_empty():
		return _fault(&"invalid_plan_shape", "resolution_receipt_id",
			"a stage key is spelled from a nonblank resolution receipt id")
	if not STAGE_IDS.has(stage_id):
		return _fault(&"invalid_stage", "stage_id",
			"stage_id is one of the six immutable stages " + str(STAGE_IDS))
	return _ok({"stage_key": resolution_receipt_id + ":" + stage_id})


## The one canonical plan digest, shared by the retirement receipt's completed_plan_sha256 and by
## Task 7's row projection so the two can never diverge. Value is {sha256: String}.
## Deliberately unvalidated: the history digest is taken over whatever bytes are stored.
static func canonical_sha256(plan: Dictionary) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(plan)
	if not emitted.get("ok", false):
		return _fail(&"noncanonical_plan", "the plan does not canonicalize byte-for-byte",
			{"cause": emitted.get("code", &"")})
	return _ok({"sha256": str(emitted["value"]).sha256_text()})


## Validates one condition_hospital_history record against the map key that indexes it.
## Value is {}.
static func validate_history_record(record: Variant, resolution_receipt_id: String) -> Dictionary:
	if typeof(record) != TYPE_DICTIONARY:
		return _fault(&"invalid_history_record", "record", "a history record is a Dictionary")
	var history := record as Dictionary
	var keys: Array = history.keys()
	keys.sort()
	if keys != _HISTORY_RECORD_KEYS:
		return _fault(&"invalid_history_record", "record",
			"a history record carries exactly " + str(_HISTORY_RECORD_KEYS))
	if typeof(history["completed_plan"]) != TYPE_DICTIONARY:
		return _fault(&"invalid_history_record", "completed_plan",
			"completed_plan is a Dictionary")
	var completed_plan: Dictionary = history["completed_plan"]
	var validated := validate(completed_plan)
	if not validated.get("ok", false):
		return _fail(&"invalid_history_record",
			"completed_plan is not a valid condition-Hospital plan: "
				+ str(validated.get("message", "")),
			{"member": "completed_plan", "cause": validated.get("code", &"")})
	if not _is_complete_shape(completed_plan):
		return _fault(&"invalid_history_record", "completed_plan",
			"a retired plan has cursor %d and all six stages completed" % STAGE_COUNT)
	if str((completed_plan["resolution_receipt"] as Dictionary)["receipt_id"]) \
			!= resolution_receipt_id:
		return _fault(&"invalid_history_record", "completed_plan.resolution_receipt.receipt_id",
			"the history key is the completed plan's own resolution receipt id")
	var retirement := _retirement_receipt_error(history["retirement_receipt"], completed_plan,
		resolution_receipt_id)
	if not retirement.is_empty():
		return retirement
	return _ok({})


# ---- the seventeen members this module owns ----

static func _member_error(plan: Dictionary) -> Dictionary:
	if typeof(plan["schema_version"]) != TYPE_INT \
			or int(plan["schema_version"]) != SCHEMA_VERSION:
		return _fault(&"invalid_plan_shape", "schema_version",
			"schema_version is the strict int %d" % SCHEMA_VERSION)
	if typeof(plan["resolution_kind"]) != TYPE_STRING \
			or str(plan["resolution_kind"]) != RESOLUTION_KIND:
		return _fault(&"invalid_plan_shape", "resolution_kind",
			"resolution_kind is exactly the String " + RESOLUTION_KIND)
	for member: String in ["branch_id", "causal_day_instance", "run_id", "transaction_id"]:
		if typeof(plan[member]) != TYPE_STRING or str(plan[member]).strip_edges().is_empty():
			return _fault(&"invalid_plan_shape", member, member + " is a nonblank String")
	if typeof(plan["desktop_timeline_generation"]) != TYPE_INT \
			or int(plan["desktop_timeline_generation"]) < 0:
		return _fault(&"invalid_plan_shape", "desktop_timeline_generation",
			"desktop_timeline_generation is a nonnegative int")
	if typeof(plan["source_day"]) != TYPE_INT or int(plan["source_day"]) < FIRST_SOURCE_DAY \
			or int(plan["source_day"]) > LAST_SOURCE_DAY:
		return _fault(&"invalid_plan_shape", "source_day",
			"source_day is an int in %d..%d" % [FIRST_SOURCE_DAY, LAST_SOURCE_DAY])
	# Each of these is a Task-7 port's own value: the container type and the cross-references this
	# module can see are the whole Task-4 law, and the interiors are never pinned here.
	for member: String in ["action_receipt", "condition_receipt", "destination_record",
			"resolution_receipt", "transaction_issuer_receipt"]:
		if typeof(plan[member]) != TYPE_DICTIONARY:
			return _fault(&"invalid_plan_shape", member, member + " is a Dictionary")
	var receipt_id: Variant = (plan["resolution_receipt"] as Dictionary).get("receipt_id")
	if typeof(receipt_id) != TYPE_STRING or str(receipt_id).strip_edges().is_empty():
		return _fault(&"invalid_plan_shape", "resolution_receipt.receipt_id",
			"resolution_receipt.receipt_id is a nonblank String")
	return {}


## The causal-day allocation and its FULL issuer receipt travel as one inseparable pair: an ID-only
## reference and a receipt minted for another allocation are both illegal.
static func _issuer_receipt_error(plan: Dictionary) -> Dictionary:
	var member := "causal_day_instance_issuer_receipt"
	if typeof(plan[member]) != TYPE_DICTIONARY:
		return _fault(&"invalid_identity_receipt", member,
			member + " is a full receipt Dictionary, never an ID-only reference")
	var receipt: Dictionary = plan[member]
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != _ISSUER_RECEIPT_KEYS:
		return _fault(&"invalid_identity_receipt", member,
			member + " carries exactly " + str(_ISSUER_RECEIPT_KEYS))
	if typeof(receipt["purpose"]) != TYPE_STRING \
			or str(receipt["purpose"]) != "causal_day_instance":
		return _fault(&"invalid_identity_receipt", member + ".purpose",
			member + ".purpose is the String causal_day_instance")
	if typeof(receipt["token"]) != TYPE_STRING \
			or str(receipt["token"]) != str(plan["causal_day_instance"]):
		return _fault(&"invalid_identity_receipt", member + ".token",
			member + ".token is the sibling causal_day_instance it authorizes")
	return {}


## Sorted once, ascending by (action_id, receipt_id), with no duplicate pair. The seven-key
## contact_source interior and its Contacts-index validation are Task 7's, not this module's.
static func _sources_error(plan: Dictionary) -> Dictionary:
	if typeof(plan["accepted_sources"]) != TYPE_ARRAY:
		return _fault(&"invalid_sources", "accepted_sources", "accepted_sources is an Array")
	var sources: Array = plan["accepted_sources"]
	var previous: Array = []
	for index: int in range(sources.size()):
		var member := "accepted_sources[%d]" % index
		if typeof(sources[index]) != TYPE_DICTIONARY:
			return _fault(&"invalid_sources", member, member + " is a Dictionary")
		var source: Dictionary = sources[index]
		var pair: Array = []
		for field: String in ["action_id", "receipt_id"]:
			var value: Variant = source.get(field)
			if typeof(value) != TYPE_STRING or str(value).strip_edges().is_empty():
				return _fault(&"invalid_sources", member + "." + field,
					member + "." + field + " is a nonblank String")
			pair.append(str(value))
		if index > 0 and not _sorts_before(previous, pair):
			return _fault(&"invalid_sources", member,
				"accepted_sources is sorted once by (action_id, receipt_id) with no duplicate")
		previous = pair
	return {}


static func _sorts_before(left: Array, right: Array) -> bool:
	if str(left[0]) != str(right[0]):
		return str(left[0]) < str(right[0])
	return str(left[1]) < str(right[1])


## The exact unpublished hospital_day outbox intent from this same transaction. The payload interior
## beyond the two members this module can cross-check belongs to Task 7.
static func _destination_error(plan: Dictionary) -> Dictionary:
	var record: Dictionary = plan["destination_record"]
	if str(record.get("status", "")) != "pending":
		return _fault(&"invalid_destination_record", "destination_record.status",
			"destination_record.status is pending; a published record is never a plan member")
	if typeof(record.get("payload")) != TYPE_DICTIONARY:
		return _fault(&"invalid_destination_record", "destination_record.payload",
			"destination_record.payload is a Dictionary")
	var payload: Dictionary = record["payload"]
	if str(payload.get("kind", "")) != "hospital_day":
		return _fault(&"invalid_destination_record", "destination_record.payload.kind",
			"destination_record.payload.kind is hospital_day")
	var member := "destination_record.payload.accepted_unfulfilled_sources"
	if typeof(payload.get("accepted_unfulfilled_sources")) != TYPE_ARRAY:
		return _fault(&"invalid_destination_record", member, member + " is an Array")
	if payload["accepted_unfulfilled_sources"] != plan["accepted_sources"]:
		return _fault(&"invalid_destination_record", member,
			member + " is byte-equal to accepted_sources")
	return {}


# ---- the six immutable stages, the cursor and the prefix ----

static func _stages_error(plan: Dictionary) -> Dictionary:
	if typeof(plan["stages"]) != TYPE_ARRAY:
		return _fault(&"invalid_stage", "stages", "stages is an Array")
	var stages: Array = plan["stages"]
	if stages.size() != STAGE_COUNT:
		return _fault(&"invalid_stage", "stages",
			"stages carries exactly the %d immutable stage records" % STAGE_COUNT)
	if typeof(plan["cursor"]) != TYPE_INT or int(plan["cursor"]) < 0 \
			or int(plan["cursor"]) > STAGE_COUNT:
		return _fault(&"invalid_cursor", "cursor", "cursor is an int in 0..%d" % STAGE_COUNT)
	var cursor := int(plan["cursor"])
	var receipt_id := str((plan["resolution_receipt"] as Dictionary)["receipt_id"])
	for index: int in range(STAGE_COUNT):
		var record_error := _stage_error(stages[index], index, cursor, receipt_id)
		if not record_error.is_empty():
			return record_error
	return {}


static func _stage_error(raw: Variant, index: int, cursor: int,
		resolution_receipt_id: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _stage_fault(index, "the stage record is a Dictionary")
	var record: Dictionary = raw
	var keys: Array = record.keys()
	keys.sort()
	if keys != STAGE_KEYS:
		return _stage_fault(index, "the stage record carries exactly " + str(STAGE_KEYS))
	var stage_id := str(STAGE_IDS[index])
	if typeof(record["stage_id"]) != TYPE_STRING or str(record["stage_id"]) != stage_id:
		return _stage_fault(index,
			"stage %d is immutably %s; stages are never reordered, removed or renamed"
				% [index, stage_id])
	if typeof(record["stage_key"]) != TYPE_STRING \
			or str(record["stage_key"]) != resolution_receipt_id + ":" + stage_id:
		return _stage_fault(index,
			"stage_key is resolution_receipt.receipt_id + ':' + stage_id and nothing else")
	if typeof(record["state"]) != TYPE_STRING or not STAGE_STATES.has(str(record["state"])):
		return _stage_fault(index, "state is one of " + str(STAGE_STATES))
	var state := str(record["state"])
	if index < cursor and state != "completed":
		return _cursor_fault(index, "every record before the cursor is completed")
	if index > cursor and state != "pending":
		return _cursor_fault(index,
			"every record after the cursor is pending; the states are a prefix, never a gap")
	if index == cursor and state == "completed":
		return _cursor_fault(index,
			"the cursor is the count of the completed prefix, so its own record is not completed")
	return _stage_member_error(record, index, state, stage_id)


## The tri-state nullability law. The interiors of stage_identity, prepared and receipt.output are
## Task 7's; only the container types and the identity cross-references are Task 4's.
static func _stage_member_error(record: Dictionary, index: int, state: String,
		stage_id: String) -> Dictionary:
	if state == "pending":
		for member: String in ["prepared", "receipt", "stage_identity"]:
			if record[member] != null:
				return _stage_fault(index, "a pending record has a null " + member)
		return {}
	for member: String in ["prepared", "stage_identity"]:
		if typeof(record[member]) != TYPE_DICTIONARY:
			return _stage_fault(index, "a %s record carries a Dictionary %s" % [state, member])
	if state == "active":
		if record["receipt"] != null:
			return _stage_fault(index, "an active record has a null receipt until it completes")
		return {}
	if typeof(record["receipt"]) != TYPE_DICTIONARY:
		return _stage_fault(index, "a completed record carries a Dictionary receipt")
	var identity: Dictionary = record["stage_identity"]
	var receipt: Dictionary = record["receipt"]
	# Presence first: two absent members compare null == null and would pass vacuously.
	for field: String in ["child_id", "provenance"]:
		if not identity.has(field):
			return _stage_fault(index, "a completed stage_identity carries " + field)
	for field: String in ["receipt_id", "receipt_provenance"]:
		if not receipt.has(field):
			return _stage_fault(index, "a completed receipt carries " + field)
	if receipt["receipt_id"] != identity["child_id"]:
		return _stage_fault(index,
			"a completed receipt.receipt_id is the stage_identity.child_id it was minted under")
	if receipt["receipt_provenance"] != identity["provenance"]:
		return _stage_fault(index,
			"a completed receipt.receipt_provenance is byte-equal to stage_identity.provenance")
	if str(receipt.get("stage_id", "")) != stage_id:
		return _stage_fault(index, "a completed receipt names its own stage_id " + stage_id)
	return {}


static func _is_complete_shape(plan: Dictionary) -> bool:
	if int(plan["cursor"]) != STAGE_COUNT:
		return false
	for raw: Variant in (plan["stages"] as Array):
		if str((raw as Dictionary)["state"]) != "completed":
			return false
	return true


# ---- the retirement history record ----

static func _retirement_receipt_error(raw: Variant, completed_plan: Dictionary,
		resolution_receipt_id: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fault(&"invalid_retirement_receipt", "retirement_receipt",
			"the retirement receipt is a Dictionary")
	var receipt: Dictionary = raw
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != _RETIREMENT_RECEIPT_KEYS:
		return _fault(&"invalid_retirement_receipt", "retirement_receipt",
			"the retirement receipt carries exactly " + str(_RETIREMENT_RECEIPT_KEYS))
	if typeof(receipt["resolution_kind"]) != TYPE_STRING \
			or str(receipt["resolution_kind"]) != RESOLUTION_KIND:
		return _fault(&"invalid_retirement_receipt", "retirement_receipt.resolution_kind",
			"retirement_receipt.resolution_kind is " + RESOLUTION_KIND)
	if typeof(receipt["disposition"]) != TYPE_STRING \
			or str(receipt["disposition"]) != _RETIREMENT_DISPOSITION:
		return _fault(&"invalid_retirement_receipt", "retirement_receipt.disposition",
			"retirement_receipt.disposition is " + _RETIREMENT_DISPOSITION)
	if typeof(receipt["resolution_receipt_id"]) != TYPE_STRING \
			or str(receipt["resolution_receipt_id"]) != resolution_receipt_id:
		return _fault(&"invalid_retirement_receipt", "retirement_receipt.resolution_receipt_id",
			"retirement_receipt.resolution_receipt_id is the history key that indexes it")
	if typeof(receipt["receipt_id"]) != TYPE_STRING \
			or str(receipt["receipt_id"]).strip_edges().is_empty():
		return _fault(&"invalid_retirement_receipt", "retirement_receipt.receipt_id",
			"retirement_receipt.receipt_id is a nonblank String")
	if typeof(receipt["receipt_provenance"]) != TYPE_DICTIONARY:
		return _fault(&"invalid_retirement_receipt", "retirement_receipt.receipt_provenance",
			"retirement_receipt.receipt_provenance is a Dictionary")
	# RULING T4-P: the two advance projections and the autosave reference are TYPED here and
	# VALUED by Task 7's stage-4 output, so this layer stops at their container types.
	for member: String in ["autosave_stage_receipt_id", "target_causal_day_instance"]:
		if typeof(receipt[member]) != TYPE_STRING:
			return _fault(&"invalid_retirement_receipt", "retirement_receipt." + member,
				"retirement_receipt." + member + " is a String")
	for member: String in ["source_day", "target_day"]:
		if typeof(receipt[member]) != TYPE_INT:
			return _fault(&"invalid_retirement_receipt", "retirement_receipt." + member,
				"retirement_receipt." + member + " is an int")
	var digest := canonical_sha256(completed_plan)
	if not digest.get("ok", false):
		return _fail(&"invalid_retirement_receipt",
			"the sibling completed_plan has no canonical digest: " + str(digest.get("message", "")),
			{"member": "retirement_receipt.completed_plan_sha256", "cause": digest.get("code", &"")})
	if typeof(receipt["completed_plan_sha256"]) != TYPE_STRING \
			or str(receipt["completed_plan_sha256"]) \
			!= str((digest["value"] as Dictionary)["sha256"]):
		return _fault(&"invalid_retirement_receipt", "retirement_receipt.completed_plan_sha256",
			"retirement_receipt.completed_plan_sha256 is the canonical digest of its sibling plan")
	return {}


# ---- helpers ----

## The closed world as a TYPE law, recursively: only Dictionary / Array / String / int / bool /
## null / float, under String keys. Returns "" or the path of the first offending member.
static func _impure_member(value: Variant, path: String) -> String:
	var value_type := typeof(value)
	if value_type == TYPE_DICTIONARY:
		var members: Dictionary = value
		for key: Variant in members:
			if typeof(key) != TYPE_STRING:
				return "%s[%s]" % [path, str(key)]
			var nested := _impure_member(members[key], path + "." + str(key))
			if nested != "":
				return nested
		return ""
	if value_type == TYPE_ARRAY:
		var items: Array = value
		for index: int in range(items.size()):
			var found := _impure_member(items[index], "%s[%d]" % [path, index])
			if found != "":
				return found
		return ""
	if value_type != TYPE_NIL and value_type != TYPE_BOOL and value_type != TYPE_INT \
			and value_type != TYPE_FLOAT and value_type != TYPE_STRING:
		return path
	return ""


static func _fault(code: StringName, member: String, message: String) -> Dictionary:
	return _fail(code, message, {"member": member})


static func _stage_fault(index: int, message: String) -> Dictionary:
	return _fail(&"invalid_stage", "stages[%d]: %s" % [index, message], {"stage_index": index})


static func _cursor_fault(index: int, message: String) -> Dictionary:
	return _fail(&"invalid_cursor", "stages[%d]: %s" % [index, message], {"stage_index": index})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
