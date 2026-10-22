class_name HospitalFrozenContext
extends RefCounted

## Presentation records refer to the accepted sources that Hospital prevents. An
## eligible Sylvia scene may precede its witness; eligibility never mints one.
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CONTEXT_KEYS := ["day", "kind", "miss_receipt_ids", "presentation", "source_entry_ids"]
const REQUEST_KEYS := ["completion_transaction_id", "completion_transaction_provenance", "context",
	"resolution_id", "resolution_issuer_receipt", "route_id", "stage_id", "substage_id", "timeline_id"]

static func validate_request(request: Variant) -> Dictionary:
	if not request is Dictionary or request.size() != REQUEST_KEYS.size():
		return _fail(&"hospital_frozen_request_invalid")
	for key: String in REQUEST_KEYS:
		if not request.has(key): return _fail(&"hospital_frozen_request_invalid")
	for key: String in ["completion_transaction_id", "resolution_id", "stage_id", "substage_id"]:
		if not request[key] is String or request[key].strip_edges().is_empty():
			return _fail(&"hospital_frozen_request_invalid")
	if request.route_id != "hospital" or request.timeline_id != "hospital.faint" \
			or not request.resolution_issuer_receipt is Dictionary \
			or not request.completion_transaction_provenance is Dictionary:
		return _fail(&"hospital_frozen_request_invalid")
	var checked := validate(request.context)
	if not checked.ok: return checked
	return {"ok": true, "value": request.duplicate(true)}

static func from_schedule(context: Dictionary, contacts: Dictionary, entries: Array) -> Dictionary:
	var accepted: Array[String] = []
	var sylvia_sources: Array[String] = []
	for schedule_id: String in context.source_entry_ids:
		var found := {}
		for entry: Dictionary in entries:
			if entry.get("schedule_entry_id") == schedule_id:
				if not found.is_empty(): return _fail(&"hospital_frozen_source_ambiguous")
				found = entry
		if found.is_empty() or not found.get("source_receipt_id") is String:
			return _fail(&"hospital_frozen_source_missing")
		var source: Dictionary = CONTACTS.get_schedule_source_receipt(contacts, found.source_receipt_id)
		if not source.get("ok", false): return source
		var receipt: Dictionary = source.value.receipt
		if receipt.get("day") != context.day or receipt.get("action_id") != found.get("action_id") \
				or receipt.get("participants") != found.get("participants"):
			return _fail(&"hospital_frozen_source_mismatch")
		if found.source_receipt_id not in accepted: accepted.append(found.source_receipt_id)
		if receipt.participants == ["sylvia"]: sylvia_sources.append(found.source_receipt_id)
	var witness_id: Variant = null
	for id: String in contacts.get("sylvia_hospital_witness_receipts", {}):
		var witness: Dictionary = contacts.sylvia_hospital_witness_receipts[id]
		if witness.get("resolution_kind") != "schedule_done" \
				or witness.get("schedule_entry_id") not in context.source_entry_ids \
				or witness.get("source_receipt_id") not in sylvia_sources \
				or int(witness.get("care_followup_day", -1)) != int(context.day) + 1: continue
		if witness_id != null: return _fail(&"hospital_frozen_witness_ambiguous")
		witness_id = id
	return _build(context, "schedule_done", accepted, not sylvia_sources.is_empty(), witness_id)

static func from_condition(context: Dictionary, contacts: Dictionary, closure: Dictionary) -> Dictionary:
	if context.source_entry_ids != closure.get("source_receipt_ids") \
			or context.miss_receipt_ids != closure.get("miss_receipt_ids"):
		return _fail(&"hospital_frozen_source_mismatch")
	var accepted: Array[String] = []
	var sylvia_sources: Array[String] = []
	for source_id: String in context.source_entry_ids:
		var source: Dictionary = CONTACTS.get_schedule_source_receipt(contacts, source_id)
		if not source.get("ok", false): return source
		if source.value.receipt.get("day") != context.day:
			return _fail(&"hospital_frozen_source_mismatch")
		accepted.append(source_id)
		if source.value.receipt.get("participants") == ["sylvia"]: sylvia_sources.append(source_id)
	var witness: Variant = closure.get("sylvia_witness")
	var witness_id: Variant = null
	if witness != null:
		if not witness is Dictionary or not witness.get("receipt_id") is String \
				or witness.get("resolution_kind") != "condition_hospital" \
				or witness.get("source_receipt_id") not in sylvia_sources \
				or witness.get("hospital_miss_receipt_id") not in context.miss_receipt_ids \
				or contacts.get("sylvia_hospital_witness_receipts", {}).get(witness.receipt_id) != witness:
			return _fail(&"hospital_frozen_witness_mismatch")
		witness_id = witness.receipt_id
	if not sylvia_sources.is_empty() and witness_id == null:
		return _fail(&"hospital_frozen_witness_missing")
	return _build(context, "condition_hospital", accepted, not sylvia_sources.is_empty(), witness_id)

static func _build(context: Dictionary, cause: String, accepted: Array[String],
		eligible: bool, witness_id: Variant) -> Dictionary:
	accepted.sort()
	var entry_id := "hospital.faint.day%d" % int(context.day)
	var built := FROZEN.build(entry_id, {"entry_id": entry_id, "entry_role": "hospital",
		"day": int(context.day), "qualifying_cause": cause,
		"accepted_record_ids": accepted, "unfulfilled_record_ids": accepted.duplicate(),
		"sylvia_eligible": eligible, "sylvia_witness_receipt_id": witness_id})
	if not built.ok: return built
	var result := context.duplicate(true)
	result["presentation"] = built.value
	return validate(result)

static func validate(context: Variant) -> Dictionary:
	if not context is Dictionary or context.size() != CONTEXT_KEYS.size():
		return _fail(&"hospital_frozen_context_required")
	for key: String in CONTEXT_KEYS:
		if not context.has(key): return _fail(&"hospital_frozen_context_required")
	if context.kind != "hospital" or typeof(context.day) != TYPE_INT or context.day not in range(1, 8):
		return _fail(&"hospital_frozen_context_invalid")
	for key: String in ["source_entry_ids", "miss_receipt_ids"]:
		if not _sorted_ids(context[key]): return _fail(&"hospital_frozen_context_invalid")
	var entry_id := "hospital.faint.day%d" % int(context.day)
	var checked := FROZEN.validate(entry_id, context.presentation)
	if not checked.ok: return checked
	var fields: Dictionary = checked.value.fields
	if not _sorted_ids(fields.accepted_record_ids) or not _sorted_ids(fields.unfulfilled_record_ids):
		return _fail(&"hospital_frozen_context_invalid")
	for id: String in fields.unfulfilled_record_ids:
		if id not in fields.accepted_record_ids: return _fail(&"hospital_frozen_source_mismatch")
	if fields.qualifying_cause == "condition_hospital" and fields.accepted_record_ids != context.source_entry_ids:
		return _fail(&"hospital_frozen_source_mismatch")
	if (fields.sylvia_eligible and fields.accepted_record_ids.is_empty()) \
			or (fields.sylvia_witness_receipt_id != null and not fields.sylvia_eligible) \
			or (fields.qualifying_cause == "condition_hospital" and fields.sylvia_eligible \
				and fields.sylvia_witness_receipt_id == null):
		return _fail(&"hospital_frozen_witness_mismatch")
	return {"ok": true, "value": context.duplicate(true)}

static func _sorted_ids(value: Variant) -> bool:
	if not value is Array: return false
	var prior := ""
	for id: Variant in value:
		if not id is String or id.strip_edges().is_empty() or (not prior.is_empty() and id <= prior): return false
		prior = id
	return true

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": str(code)}
