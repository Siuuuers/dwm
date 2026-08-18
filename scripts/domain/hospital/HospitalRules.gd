class_name HospitalRules
extends RefCounted

## Pure Schedule-Done Hospital law (Plan 01 Task 7 Step 7.3, dwm-p2r.14).
##
## OWNS: the exact Hospital completion envelope and the immutable Sylvia witness/care receipt.
##
## DOES NOT OWN: identity. This module derives no child, reads no issuer, and touches no owner. It
## returns the ordered derivation PLAN that the Hospital transaction turns into
## `P01.hospital.resolution` -> `P01.hospital.miss[]` -> optional `P01.hospital.sylvia_witness`.
## Miss ordinals here are exactly the ordinals that matrix requires, so no producer owns a local
## ordinal builder.
##
## EMITS NO APPLICATION COMMAND. Plan 01 changes no affection, dark, attitude, tier, caring-message
## history, board/challenge result, or mastery. The witness record CARRIES those deltas as frozen
## facts for `dwm-oyo.4` to apply later; nothing here applies them.

const REQUEST_KEYS: Array[String] = ["committed_entries", "required", "source_day"]

## Every Hospital supersession has exactly one reason.
const MISS_REASON := "prevented_by_fainting"

## Frozen witness facts. These are recorded, never applied, by Plan 01.
const WITNESS_KIND := "sylvia_hospital_witness"
const WITNESS_RESOLUTION_KIND := "schedule_done"
const WITNESS_FRIEND_ID := "sylvia"
const WITNESS_AFFECTION_DELTA := 2
const WITNESS_DARK_DELTA := 1
const WITNESS_ATTITUDE := "fixated"
const WITNESS_TIER_TRANSITION := "advance_one_or_stay_love"

## The registry-owned kinds that are dates. `ordinary` entries are never dates, whatever their
## action id happens to read.
const DATE_KINDS: Array[String] = ["solo", "group"]

const FIRST_DAY := 1
const LAST_DAY := 7


## Returns the exact ordered Hospital derivation plan for one Schedule-Done resolution.
##
## `value` is exactly `{required, date_schedule_entry_ids, misses, witness}`:
##   * `date_schedule_entry_ids` is every committed date in committed slot order, INCLUDING when
##     Hospital did not trigger -- the date stage needs that order either way, and `[]` is explicit.
##   * `misses` is empty unless Hospital triggered. When it did, every committed date is superseded
##     exactly once, ordinals zero-based over that filtered slot-ordered list.
##   * `witness` is null, or the single record for the first committed, sourced Sylvia date that
##     Hospital superseded.
static func plan_resolution(request: Dictionary) -> Dictionary:
	if typeof(request) != TYPE_DICTIONARY:
		return _fail(&"invalid_hospital_request", "the request must be a dictionary")
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUEST_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _fail(&"invalid_hospital_request", "unexpected request keys: " + str(keys))
	if typeof(request["required"]) != TYPE_BOOL:
		return _fail(&"invalid_hospital_request", "required must be a strict bool")
	if typeof(request["source_day"]) != TYPE_INT:
		return _fail(&"invalid_hospital_request", "source_day must be a strict int")
	var source_day := int(request["source_day"])
	if source_day < FIRST_DAY or source_day > LAST_DAY:
		return _fail(&"invalid_hospital_request", "source_day must be 1..7: %d" % source_day)
	if typeof(request["committed_entries"]) != TYPE_ARRAY:
		return _fail(&"invalid_hospital_request", "committed_entries must be an array")

	var dates := _dates_in_slot_order(request["committed_entries"] as Array)
	if not dates.get("ok", false):
		return dates
	var ordered: Array[Dictionary] = (dates["value"] as Dictionary)["dates"]

	var date_ids: Array[String] = []
	for entry: Dictionary in ordered:
		date_ids.append(str(entry["schedule_entry_id"]))

	var required := bool(request["required"])
	var misses: Array[Dictionary] = []
	var witness: Variant = null
	if required:
		# Hospital supersedes EVERY committed date before any dating board runs, and records each
		# supersession exactly once. The ordinal is the position in this filtered, slot-ordered
		# list -- never the raw slot index and never completion order.
		for ordinal: int in range(ordered.size()):
			var entry: Dictionary = ordered[ordinal]
			misses.append({
				"ordinal": ordinal,
				"schedule_entry_id": str(entry["schedule_entry_id"]),
				"action_id": str(entry["action_id"]),
				"source_receipt_id": entry["source_receipt_id"],
				"reason": MISS_REASON,
			})
		witness = _witness_for(ordered, misses, source_day)

	return {"ok": true, "code": &"ok", "value": {
		"required": required,
		"date_schedule_entry_ids": date_ids,
		"misses": misses,
		"witness": witness,
	}}


## The committed date entries, ascending by slot index. Ordinary entries are filtered out by the
## registry-owned `action_kind` alone.
static func _dates_in_slot_order(committed_entries: Array) -> Dictionary:
	var dates: Array[Dictionary] = []
	for entry_value: Variant in committed_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			return _fail(&"invalid_hospital_request", "committed entries must be objects")
		var entry := entry_value as Dictionary
		if typeof(entry.get("slot_index")) != TYPE_INT:
			return _fail(&"invalid_hospital_request", "each committed entry needs an int slot_index")
		if str(entry.get("schedule_entry_id", "")).is_empty():
			return _fail(&"invalid_hospital_request", "each committed entry needs a schedule_entry_id")
		if str(entry.get("action_kind", "")) in DATE_KINDS:
			dates.append(entry.duplicate(true))
	dates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["slot_index"]) < int(right["slot_index"]))
	return {"ok": true, "code": &"ok", "value": {"dates": dates}}


## The single Sylvia witness, or null.
##
## A witness requires a date that Hospital actually superseded, whose sole participant is Sylvia,
## and which carries the exact source receipt that proves it was an accepted, read offer. An
## unsourced, uncommitted, other-friend, or non-date entry cannot witness, and neither can any
## entry when Hospital did not trigger.
static func _witness_for(ordered_dates: Array[Dictionary], misses: Array[Dictionary],
		source_day: int) -> Variant:
	for ordinal: int in range(ordered_dates.size()):
		var entry: Dictionary = ordered_dates[ordinal]
		if str(entry.get("action_kind", "")) != "solo":
			continue
		var participants: Array = entry.get("participants", []) as Array
		if participants.size() != 1 or str(participants[0]) != WITNESS_FRIEND_ID:
			continue
		var source_receipt_id: Variant = entry.get("source_receipt_id")
		if typeof(source_receipt_id) != TYPE_STRING or str(source_receipt_id).is_empty():
			continue
		var care_day := source_day + 1
		return {
			"kind": WITNESS_KIND,
			"resolution_kind": WITNESS_RESOLUTION_KIND,
			"schedule_entry_id": str(entry["schedule_entry_id"]),
			"action_id": str(entry["action_id"]),
			"source_receipt_id": str(source_receipt_id),
			"hospital_miss_ordinal": int(misses[ordinal]["ordinal"]),
			"care_followup_day": care_day,
			"care_followup_entry_id": "care.%s.day%d" % [WITNESS_FRIEND_ID, care_day],
			"affection_delta": WITNESS_AFFECTION_DELTA,
			"dark_delta": WITNESS_DARK_DELTA,
			"attitude": WITNESS_ATTITUDE,
			"tier_transition": WITNESS_TIER_TRANSITION,
		}
	return null


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
