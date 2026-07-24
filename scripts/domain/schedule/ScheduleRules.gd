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

const DATE_TYPES: Array[String] = ["solo", "group", "twofriends"]

static func max_dates_for_day(day: int) -> int:
	# Days 1-6 allow two dates; Day 7 allows the single ending date.
	return 2 if day >= 1 and day <= 6 else 1

static func validate_existing(schedule: Array, day: int) -> Dictionary:
	var seen_slots: Dictionary = {}
	var date_count: int = 0
	for entry: Dictionary in schedule:
		var slot: int = int(entry.get("slot_index", -1))
		if seen_slots.has(slot):
			return _fail(&"duplicate_slot_index", "slot %d is used twice" % slot)
		seen_slots[slot] = true
		if str(entry.get("type", "")) in DATE_TYPES:
			date_count += 1
	if date_count > max_dates_for_day(day):
		return _fail(&"too_many_dates", "%d dates exceed the day-%d allowance" % [date_count, day])
	return {"ok": true, "code": &"ok"}

static func validate_candidate(existing: Array, candidate: Dictionary, day: int, motivation: int, eligibility: Dictionary) -> Dictionary:
	if motivation <= 0:
		return _fail(&"no_motivation", "adding a schedule entry costs motivation")
	var action_id := str(candidate.get("action_id", ""))
	var registered: Array = eligibility.get("registered_action_ids", [])
	if action_id.is_empty() or action_id not in registered:
		return _fail(&"unregistered_action", action_id)
	for entry: Dictionary in existing:
		if str(entry.get("action_id", "")) == action_id:
			return _fail(&"duplicate_entry", action_id)
		if int(entry.get("slot_index", -1)) == int(candidate.get("slot_index", -1)):
			return _fail(&"duplicate_slot_index", str(candidate.get("slot_index", -1)))
	if str(candidate.get("type", "")) in DATE_TYPES:
		var date_count: int = 0
		for entry: Dictionary in existing:
			if str(entry.get("type", "")) in DATE_TYPES:
				date_count += 1
		if date_count + 1 > max_dates_for_day(day):
			return _fail(&"too_many_dates", "day %d allows %d date(s)" % [day, max_dates_for_day(day)])
	return {"ok": true, "code": &"ok"}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
