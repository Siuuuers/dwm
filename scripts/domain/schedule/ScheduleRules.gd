class_name ScheduleRules
extends RefCounted

## Pure schedule validation (dwm-p2r.7, plan-04 Task 4).
##
## Candidate-add validation and existing-schedule validation are deliberately DIFFERENT
## questions. `validate_candidate` asks "may this entry be added right now?", so it
## rejects anything that collides with what is already scheduled. `validate_existing`
## asks "is the schedule valid as it stands?", where an entry must never invalidate
## itself. Adding rejects at add time; Done re-validates the whole schedule.
##
## Both return the frozen CommandResult shape and never mutate their inputs.

## Exact schedule-entry keys; anything more or less is malformed.
const ENTRY_KEYS: Array[String] = [
	"action_id", "day", "effect_ids", "entry_id", "friend_ids",
	"route_id", "slot_index", "type", "unlock_receipt_id",
]
## A schedulable entry is a non-date action or a date. `twofriends` is NOT schedulable:
## it is a deferred route produced by day-end resolution, never placed by the player.
const ENTRY_TYPES: Array[String] = ["action", "solo", "group"]
const DATE_TYPES: Array[String] = ["solo", "group"]

static func max_dates_for_day(day: int) -> int:
	# Days 1-6 allow two dates; Day 7 allows the single ending date.
	return 2 if day >= 1 and day <= 6 else 1

static func validate_existing(schedule: Array, day: int) -> Dictionary:
	var seen_slots: Dictionary = {}
	var seen_entry_ids: Dictionary = {}
	var date_count: int = 0
	for entry: Dictionary in schedule:
		var shape_error := _entry_shape_error(entry, day)
		if not shape_error.is_empty():
			return _fail(&"invalid_entry", shape_error)
		var entry_id := str(entry["entry_id"])
		if seen_entry_ids.has(entry_id):
			return _fail(&"duplicate_entry_id", entry_id)
		seen_entry_ids[entry_id] = true
		var slot: int = int(entry["slot_index"])
		if seen_slots.has(slot):
			return _fail(&"duplicate_slot_index", "slot %d is used twice" % slot)
		seen_slots[slot] = true
		if str(entry["type"]) in DATE_TYPES:
			date_count += 1
	if date_count > max_dates_for_day(day):
		return _fail(&"too_many_dates", "%d dates exceed the day-%d allowance" % [date_count, day])
	return {"ok": true, "code": &"ok"}

static func validate_candidate(existing: Array, candidate: Dictionary, day: int, motivation: int, eligibility: Dictionary) -> Dictionary:
	if motivation <= 0:
		return _fail(&"no_motivation", "adding a schedule entry costs motivation")
	var shape_error := _entry_shape_error(candidate, day)
	if not shape_error.is_empty():
		return _fail(&"invalid_entry", shape_error)
	var action_id := str(candidate.get("action_id", ""))
	var registered: Array = eligibility.get("registered_action_ids", [])
	if action_id.is_empty() or action_id not in registered:
		return _fail(&"unregistered_action", action_id)
	if day == 7:
		# Shape validation already guaranteed a nonempty receipt id; now the candidate, the
		# day7_candidate, and the indexed unlock receipt must agree exactly. No ID naming
		# convention is ever treated as proof.
		var desync := _day7_desync_reason(candidate, eligibility)
		if not desync.is_empty():
			return _fail(&"day7_candidate_not_synchronized", desync)
	for entry: Dictionary in existing:
		if str(entry.get("action_id", "")) == action_id:
			return _fail(&"duplicate_entry", action_id)
		if int(entry.get("slot_index", -1)) == int(candidate.get("slot_index", -1)):
			return _fail(&"duplicate_slot_index", str(candidate.get("slot_index", -1)))
	var candidate_type := str(candidate["type"])
	if candidate_type in DATE_TYPES:
		# Preserved legacy rule: Day-4 Priscilla only lands in the first slot.
		if day == 4 and candidate_type == "solo" and "priscilla" in candidate["friend_ids"] \
				and not existing.is_empty():
			return _fail(&"priscilla_first_slot_required", "Day 4 seats Priscilla first")
		# Preserved legacy rule: one date per friend (solo) / per pair (group) each day.
		for entry: Dictionary in existing:
			if str(entry["type"]) != candidate_type:
				continue
			if _same_friend_set(entry["friend_ids"], candidate["friend_ids"]):
				return _fail(&"duplicate_friend_date", str(candidate["friend_ids"]))
		var date_count: int = 0
		for entry: Dictionary in existing:
			if str(entry["type"]) in DATE_TYPES:
				date_count += 1
		if date_count + 1 > max_dates_for_day(day):
			return _fail(&"too_many_dates", "day %d allows %d date(s)" % [day, max_dates_for_day(day)])
	return {"ok": true, "code": &"ok"}


## Pure add-time validation of one date candidate against the OTHER entries already scheduled
## (the caller excludes the candidate from `existing`). Loose date shape: `type` in DATE_TYPES;
## friends from `friend_ids`, or `friend_id` for the minimal {type, friend_id} candidate GameState
## builds. Returns a specific reason code so a Done warning can render a helpful message.
## twofriends is never routed here.
static func validate_date_candidate(existing: Array, candidate: Dictionary, day: int) -> Dictionary:
	var candidate_type := str(candidate.get("type", ""))
	if candidate_type not in DATE_TYPES:
		return _fail(&"not_a_date", "validate_date_candidate handles only " + str(DATE_TYPES))
	var candidate_friends := _friend_set(candidate)
	# Day 4 seats Priscilla first: a solo Priscilla date cannot follow another entry.
	if day == 4 and candidate_type == "solo" and "priscilla" in candidate_friends and not existing.is_empty():
		return _fail(&"priscilla_first_slot_required", "Day 4 seats Priscilla first")
	# One date per friend (solo) / per pair (group) each day; then the daily date cap.
	var date_count: int = 0
	for entry: Dictionary in existing:
		if str(entry.get("type", "")) not in DATE_TYPES:
			continue
		date_count += 1
		if str(entry.get("type", "")) == candidate_type and _same_friend_set(_friend_set(entry), candidate_friends):
			return _fail(&"duplicate_friend_date", str(candidate_friends))
	if date_count >= max_dates_for_day(day):
		return _fail(&"too_many_dates", "day %d allows %d date(s)" % [day, max_dates_for_day(day)])
	return {"ok": true, "code": &"ok"}

static func _friend_set(entry: Dictionary) -> Array:
	var ids: Array = entry.get("friend_ids", [])
	if not ids.is_empty():
		return ids
	var single := str(entry.get("friend_id", ""))
	return [single] if not single.is_empty() else []


static func _same_friend_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for friend_id: Variant in left:
		if friend_id not in right:
			return false
	return true

static func _entry_shape_error(entry: Dictionary, day: int) -> String:
	# Returns "" when the entry carries exactly the contracted keys with sane values.
	var keys: Array = entry.keys()
	keys.sort()
	var expected: Array = ENTRY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "entry keys must be exactly " + str(expected) + ", got " + str(keys)
	if str(entry["entry_id"]).is_empty():
		return "entry_id must be nonempty"
	if str(entry["type"]) not in ENTRY_TYPES:
		return "type must be one of " + str(ENTRY_TYPES)
	if typeof(entry["slot_index"]) != TYPE_INT or int(entry["slot_index"]) < 0:
		return "slot_index must be a non-negative integer"
	if int(entry["day"]) != day:
		return "entry day %d does not match the validated day %d" % [int(entry["day"]), day]
	if typeof(entry["friend_ids"]) != TYPE_ARRAY:
		return "friend_ids must be an array"
	if typeof(entry["effect_ids"]) != TYPE_ARRAY:
		return "effect_ids must be an array"
	# Unlock receipts belong only to a Day-7 solo (ending) date; days 1-6 carry null.
	var receipt: Variant = entry["unlock_receipt_id"]
	if day == 7 and str(entry["type"]) == "solo":
		if typeof(receipt) != TYPE_STRING or str(receipt).is_empty():
			return "a Day-7 solo date requires a nonempty unlock_receipt_id"
	elif receipt != null:
		return "only a Day-7 solo date carries an unlock_receipt_id"
	return ""


static func _day7_desync_reason(candidate: Dictionary, eligibility: Dictionary) -> String:
	# Returns "" when every link of the Day-7 evidence chain matches, else why it broke.
	var day7: Variant = eligibility.get("day7_candidate")
	if typeof(day7) != TYPE_DICTIONARY:
		return "day 7 requires a day7_candidate"
	var receipt_id := str(candidate.get("unlock_receipt_id", ""))
	if receipt_id.is_empty():
		return "a Day-7 date requires an unlock receipt id"
	var friend_ids: Array = candidate.get("friend_ids", [])
	if friend_ids.size() != 1:
		return "a Day-7 date names exactly one friend"
	var friend_id := str(friend_ids[0])
	var action_id := str(candidate.get("action_id", ""))
	var offered := day7 as Dictionary
	if str(offered.get("action_id", "")) != action_id \
			or str(offered.get("friend_id", "")) != friend_id \
			or str(offered.get("unlock_receipt_id", "")) != receipt_id:
		return "candidate does not match the offered day7_candidate"
	var index: Variant = eligibility.get("receipt_index")
	if typeof(index) != TYPE_DICTIONARY or not (index as Dictionary).has(receipt_id):
		return "no indexed unlock receipt for " + receipt_id
	var raw: Variant = (index as Dictionary)[receipt_id]
	if typeof(raw) != TYPE_DICTIONARY:
		return "malformed receipt record"
	var record := raw as Dictionary
	if str(record.get("receipt_id", "")) != receipt_id:
		return "receipt map key must equal receipt_id"
	if str(record.get("kind", "")) != "day7_unlock":
		return "receipt kind must be day7_unlock"
	if int(record.get("day", -1)) != 7:
		return "receipt day must be 7"
	if record.get("previous_receipt_id") != null:
		return "an unlock receipt starts the chain"
	if str(record.get("action_id", "")) != action_id or str(record.get("friend_id", "")) != friend_id:
		return "receipt record does not match the candidate"
	return ""


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
