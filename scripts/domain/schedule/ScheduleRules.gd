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
## MASTER COMMAND RESULT (frozen 2026-08-11, plan-author ruling). Every strict method returns
## exactly one of:
##
## [codeblock]
## {"ok": true,  "code": &"ok", "value": Dictionary, "receipt": Dictionary}
## {"ok": false, "code": StringName, "message": String, "details": Dictionary}
## [/codeblock]
##
## A failure NEVER carries a partial `value` or `receipt`, and a success never carries `message`
## or `details`. Each code pins exact `details` keys so a consumer branches on data, never on
## prose. `validate_date_candidate` is the single deliberate exception: it keeps the legacy bare
## `{ok, code, message}` shape until Step 4.2b retires it.
##
## Nothing here mutates its inputs, and no caller-owned value is ever retained by reference.

## Exact schedule-entry keys; anything more or less is malformed.
const ENTRY_KEYS: Array[String] = [
	"action_id", "day", "effect_ids", "entry_id", "friend_ids",
	"route_id", "slot_index", "type", "unlock_receipt_id",
]
## A schedulable entry is a non-date action or a date. `twofriends` is NOT schedulable:
## it is a deferred route produced by day-end resolution, never placed by the player.
const ENTRY_TYPES: Array[String] = ["action", "solo", "group"]
const DATE_TYPES: Array[String] = ["solo", "group"]
## The single registered semantic route a scheduled date may carry. Mirrored by
## data/manifests/routes.json, whose keys are SceneRouter._SCENE_PATHS.
const DATE_ROUTE_ID := "dating"
## Arity is part of the entry type. A group date is the distinct Priscilla-Lavinia pair
## (ContactInvitationState.GROUP_PAIR), never one friend and never three.
const FRIENDS_PER_TYPE := {"action": 0, "solo": 1, "group": 2}
## The seven-day run. A day outside this range is a caller fault, not entry data.
const FIRST_DAY := 1
const LAST_DAY := 7

static func max_dates_for_day(day: int) -> int:
	# Days 1-6 allow two dates; Day 7 allows the single ending date.
	return 2 if day >= 1 and day <= 6 else 1

static func validate_existing(schedule: Array, day: int) -> Dictionary:
	# Entries only have to MATCH the validated day, so without this an all-day-9 schedule validated
	# against day 9 passed cleanly. validate_candidate inherits the check through the board stage.
	if day < FIRST_DAY or day > LAST_DAY:
		return _fail(&"invalid_day", "day %d is outside the seven-day run" % day, {"day": day})
	# PHASE 1 -- per-entry shape. Every entry is well formed before any two entries are compared.
	var date_count: int = 0
	for entry: Dictionary in schedule:
		var shape_error := _entry_shape_error(entry, day)
		if not shape_error.is_empty():
			return _shape_failure(shape_error)
		if str(entry["type"]) in DATE_TYPES:
			date_count += 1
	# PHASE 2 -- the daily allowance, BEFORE any collision or placement check. Two well-shaped
	# Day-7 endings are one ending too many, not a slot problem: reporting duplicate_slot_index or
	# a nonzero-slot invalid_entry would name a symptom and hide the cause. The phases are
	# day-INDEPENDENT, so a Days 1-6 schedule that is both over the allowance and colliding also
	# reports the allowance.
	var allowed := max_dates_for_day(day)
	if date_count > allowed:
		return _fail(&"too_many_dates", "%d dates exceed the day-%d allowance" % [date_count, day],
			{"day": day, "date_count": date_count, "allowed": allowed})
	# PHASE 3 -- collisions and placement.
	var seen_slots: Dictionary = {}
	var seen_entry_ids: Dictionary = {}
	var seen_action_ids: Dictionary = {}
	for entry: Dictionary in schedule:
		var entry_id := str(entry["entry_id"])
		if seen_entry_ids.has(entry_id):
			return _fail(&"duplicate_entry_id", "entry_id %s is used twice" % entry_id,
				{"entry_id": entry_id})
		seen_entry_ids[entry_id] = true
		# One action per day: distinct entry_ids in distinct slots can still name the same
		# underlying action, which no other rule here catches (Plan-04 Task 4 audit, 2026-08-10).
		var action_id := str(entry["action_id"])
		if seen_action_ids.has(action_id):
			return _fail(&"duplicate_action_id", "action %s is scheduled twice" % action_id,
				{"action_id": action_id})
		seen_action_ids[action_id] = true
		var slot: int = int(entry["slot_index"])
		if seen_slots.has(slot):
			return _fail(&"duplicate_slot_index", "slot %d is used twice" % slot,
				{"slot_index": slot})
		seen_slots[slot] = true
		# The single Day-7 ending seats first. Checked here rather than in shape validation so the
		# allowance is judged before placement.
		if day == LAST_DAY and slot != 0:
			return _shape_failure(_shape_error(entry, "slot_index",
				"the Day-7 ending seats at slot 0, got %d" % slot))
	# One date per friend (solo) or per pair (group) each day. Each unordered pair is compared
	# exactly once and never with itself. A joined-string key would have been O(n) but any delimiter
	# can collide with a friend id, and the schedule is two or three entries.
	for left_index: int in range(schedule.size()):
		var left: Dictionary = schedule[left_index]
		var left_type := left["type"] as String
		if left_type not in DATE_TYPES:
			continue
		for right_index: int in range(left_index + 1, schedule.size()):
			var right: Dictionary = schedule[right_index]
			# Same-type only: solo compares to solo, group to group. Cross-type participant overlap
			# is deliberate canon, not an oversight.
			if str(right["type"]) != left_type:
				continue
			if _same_friend_set(left["friend_ids"], right["friend_ids"]):
				return _fail(&"duplicate_friend_date",
					"%s is already dated today" % str(right["friend_ids"]),
					{"type": left_type,
						"friend_ids": (right["friend_ids"] as Array).duplicate(true)})
	return _ok()

static func validate_candidate(existing: Array, candidate: Dictionary, day: int, motivation: int, eligibility: Dictionary) -> Dictionary:
	# THE ADD/DONE LAW: if Add accepts a candidate, the resulting schedule must pass Done
	# validation. The board is therefore judged FIRST and its failure propagates byte-for-byte --
	# a corrupt board is a more fundamental fault than a bad new entry, and it must not be masked
	# by the cheaper checks below.
	var board := validate_existing(existing, day)
	if not board.get("ok", false):
		return board
	if motivation <= 0:
		return _fail(&"no_motivation", "adding a schedule entry costs motivation",
			{"motivation": motivation})
	var shape_error := _entry_shape_error(candidate, day)
	if not shape_error.is_empty():
		return _shape_failure(shape_error)
	var action_id := str(candidate.get("action_id", ""))
	var registered: Array = eligibility.get("registered_action_ids", [])
	if action_id.is_empty() or action_id not in registered:
		return _fail(&"unregistered_action", "action %s is not registered" % action_id,
			{"action_id": action_id})
	if day == 7:
		# Shape validation already guaranteed a nonempty receipt id; now the candidate, the
		# day7_candidate, and the indexed unlock receipt must agree exactly. No ID naming
		# convention is ever treated as proof.
		var desync := _day7_desync_reason(candidate, eligibility)
		if not desync.is_empty():
			return _fail(&"day7_candidate_not_synchronized", desync, {"reason": desync})
	var candidate_slot := int(candidate.get("slot_index", -1))
	var candidate_type := str(candidate["type"])
	if candidate_type in DATE_TYPES:
		# Preserved legacy rule: Day-4 Priscilla only lands in the first slot.
		if day == 4 and candidate_type == "solo" and "priscilla" in candidate["friend_ids"] \
				and not existing.is_empty():
			return _fail(&"priscilla_first_slot_required", "Day 4 seats Priscilla first",
				{"slot_index": candidate_slot})
		# Preserved legacy rule: one date per friend (solo) / per pair (group) each day.
		for entry: Dictionary in existing:
			if str(entry["type"]) != candidate_type:
				continue
			if _same_friend_set(entry["friend_ids"], candidate["friend_ids"]):
				return _fail(&"duplicate_friend_date",
					"%s is already dated today" % str(candidate["friend_ids"]),
					{"type": candidate_type,
						"friend_ids": (candidate["friend_ids"] as Array).duplicate(true)})
		var date_count: int = 0
		for entry: Dictionary in existing:
			if str(entry["type"]) in DATE_TYPES:
				date_count += 1
		var allowed := max_dates_for_day(day)
		if date_count + 1 > allowed:
			return _fail(&"too_many_dates", "day %d allows %d date(s)" % [day, allowed],
				{"day": day, "date_count": date_count + 1, "allowed": allowed})
	# Collisions between the candidate and the board are the SAME question Done asks, so they are
	# answered by the same code path rather than by a parallel loop that could drift from it. This
	# is what retired the ambiguous `duplicate_entry`: entry_id, slot_index, action_id and
	# friend-set collisions now all report validate_existing's standardized codes.
	var prospective: Array = existing.duplicate()
	prospective.append(candidate.duplicate(true))
	var prospective_result := validate_existing(prospective, day)
	if not prospective_result.get("ok", false):
		return prospective_result
	return _ok()


## Pure add-time validation of one date candidate against the OTHER entries already scheduled
## (the caller excludes the candidate from `existing`). Loose date shape: `type` in DATE_TYPES;
## friends from `friend_ids`, or `friend_id` for the minimal {type, friend_id} candidate GameState
## builds. Returns a specific reason code so a Done warning can render a helpful message.
## twofriends is never routed here.
## Pure routing projection of a validated schedule (Plan-04 Task 4, contract amended 2026-08-10).
##
## Routing is CLOSED: `action` carries no route and is omitted entirely; `solo` and `group` both
## route to the registered `dating` scene; `twofriends` is never schedulable and can never reach
## here, because it is not an ENTRY_TYPE and validate_existing rejects it first. `"none"` and
## `"advance"` are retired control sentinels, not route IDs.
##
## Transaction IDs, resolution IDs and presentation context are deliberately absent; the day
## resolution coordinator adds those later.
static func build_route_plan(schedule: Array, day: int) -> Dictionary:
	var validated := validate_existing(schedule, day)
	if not validated.get("ok", false):
		return validated
	var routed: Array[Dictionary] = []
	for entry: Dictionary in schedule:
		# DEFENSIVE INVARIANT (retained by plan-author ruling, commit E2): since route semantics
		# moved into _entry_shape_error, validate_existing above rejects every routing
		# contradiction first, so neither branch below can be reached through the public API. They
		# stay as an assertion that routing never emits a plan the schedule did not license.
		var entry_type := str(entry["type"])
		var route: Variant = entry["route_id"]
		if entry_type not in DATE_TYPES:
			if route != null:
				return _fail(&"invalid_route",
					"%s entries carry no route, got %s" % [entry_type, str(route)],
					_route_details(entry, entry_type, route))
			continue
		if typeof(route) != TYPE_STRING or str(route) != DATE_ROUTE_ID:
			return _fail(&"invalid_route",
				"%s entries route to %s, got %s" % [entry_type, DATE_ROUTE_ID, str(route)],
				_route_details(entry, entry_type, route))
		routed.append({
			"entry_id": str(entry["entry_id"]),
			"slot_index": int(entry["slot_index"]),
			"route_id": DATE_ROUTE_ID,
		})
	routed.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["slot_index"]) < int(right["slot_index"]))
	return _ok({"route_plan": routed})

static func validate_date_candidate(existing: Array, candidate: Dictionary, day: int) -> Dictionary:
	var candidate_type := str(candidate.get("type", ""))
	if candidate_type not in DATE_TYPES:
		return _legacy_fail(&"not_a_date", "validate_date_candidate handles only " + str(DATE_TYPES))
	var candidate_friends := _friend_set(candidate)
	# Day 4 seats Priscilla first: a solo Priscilla date cannot follow another entry.
	if day == 4 and candidate_type == "solo" and "priscilla" in candidate_friends and not existing.is_empty():
		return _legacy_fail(&"priscilla_first_slot_required", "Day 4 seats Priscilla first")
	# One date per friend (solo) / per pair (group) each day; then the daily date cap.
	var date_count: int = 0
	for entry: Dictionary in existing:
		if str(entry.get("type", "")) not in DATE_TYPES:
			continue
		date_count += 1
		if str(entry.get("type", "")) == candidate_type and _same_friend_set(_friend_set(entry), candidate_friends):
			return _legacy_fail(&"duplicate_friend_date", str(candidate_friends))
	if date_count >= max_dates_for_day(day):
		return _legacy_fail(&"too_many_dates", "day %d allows %d date(s)" % [day, max_dates_for_day(day)])
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
	# Sorted DETACHED copies: the caller's arrays keep their order, and set equality never depends
	# on the order a schedule happened to be written in. The previous membership test also called
	# ["a","a"] equal to ["a","b"], since every element of the left was "in" the right.
	var left_sorted: Array = left.duplicate(true)
	var right_sorted: Array = right.duplicate(true)
	left_sorted.sort()
	right_sorted.sort()
	return left_sorted == right_sorted

static func _entry_shape_error(entry: Dictionary, day: int) -> Dictionary:
	# Returns {} when the entry carries exactly the contracted keys with sane values, else a
	# failure-ready {code, message, details}. Shape validation owns its own CODE rather than always
	# meaning `invalid_entry`, so commits E1/E2 can reject a bad route or a repeated effect from
	# here under their own typed codes without a second validation pass.
	var keys: Array = entry.keys()
	keys.sort()
	var expected: Array = ENTRY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _shape_error(entry, "keys",
			"entry keys must be exactly " + str(expected) + ", got " + str(keys))
	if typeof(entry["entry_id"]) != TYPE_STRING or (entry["entry_id"] as String).is_empty():
		return _shape_error(entry, "entry_id", "entry_id must be a nonempty String")
	if typeof(entry["type"]) != TYPE_STRING or entry["type"] not in ENTRY_TYPES:
		return _shape_error(entry, "type", "type must be one of " + str(ENTRY_TYPES))
	var entry_type := entry["type"] as String
	# Day 7 schedules the single solo ending date or nothing at all (the Alone state). No ordinary
	# action and no group date belongs on the last day.
	if day == LAST_DAY and entry_type != "solo":
		return _shape_error(entry, "type",
			"day 7 schedules only the solo ending date, got " + entry_type)
	if typeof(entry["action_id"]) != TYPE_STRING or (entry["action_id"] as String).is_empty():
		return _shape_error(entry, "action_id", "action_id must be a nonempty String")
	if typeof(entry["slot_index"]) != TYPE_INT or int(entry["slot_index"]) < 0:
		return _shape_error(entry, "slot_index", "slot_index must be a non-negative integer")
	# No coercion: int("3") == 3 silently matched the validated day, so a persisted string passed.
	if typeof(entry["day"]) != TYPE_INT or int(entry["day"]) != day:
		return _shape_error(entry, "day",
			"entry day %s does not match the validated day %d" % [str(entry["day"]), day])
	var friend_error := _friend_ids_error(entry, entry_type)
	if not friend_error.is_empty():
		return friend_error
	var effect_error := _effect_ids_error(entry)
	if not effect_error.is_empty():
		return effect_error
	var route_error := _route_id_error(entry, entry_type)
	if not route_error.is_empty():
		return route_error
	# Unlock receipts belong only to a Day-7 solo (ending) date; days 1-6 carry null.
	var receipt: Variant = entry["unlock_receipt_id"]
	if day == 7 and entry_type == "solo":
		if typeof(receipt) != TYPE_STRING or str(receipt).is_empty():
			return _shape_error(entry, "unlock_receipt_id",
				"a Day-7 solo date requires a nonempty unlock_receipt_id")
	elif receipt != null:
		return _shape_error(entry, "unlock_receipt_id",
			"only a Day-7 solo date carries an unlock_receipt_id")
	return {}


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


static func _friend_ids_error(entry: Dictionary, entry_type: String) -> Dictionary:
	# Arity is part of the type: an action has no friends, a solo date is one friend, and a group
	# date is the distinct pair. Membership is checked against the canonical DataCatalog roster
	# rather than a fourth copy of the same three names.
	if typeof(entry["friend_ids"]) != TYPE_ARRAY:
		return _shape_error(entry, "friend_ids", "friend_ids must be an array")
	var friends := entry["friend_ids"] as Array
	var required: int = FRIENDS_PER_TYPE.get(entry_type, 0)
	if friends.size() != required:
		return _shape_error(entry, "friend_ids",
			"a %s entry names exactly %d friend(s), got %d" % [entry_type, required, friends.size()])
	var seen: Dictionary = {}
	for friend: Variant in friends:
		if typeof(friend) != TYPE_STRING or (friend as String).is_empty():
			return _shape_error(entry, "friend_ids", "friend ids must be nonempty Strings")
		if friend not in DataCatalog.FRIEND_IDS:
			return _shape_error(entry, "friend_ids", "unknown friend " + str(friend))
		if seen.has(friend):
			return _shape_error(entry, "friend_ids", "a date names distinct friends")
		seen[friend] = true
	return {}


static func _route_id_error(entry: Dictionary, entry_type: String) -> Dictionary:
	# Routing is CLOSED and it is a property of the SCHEDULE, not only of the routing projection:
	# an unroutable schedule must not be a "valid" schedule that fails later at Done.
	# "none" and "advance" are retired control sentinels, never route ids.
	var route: Variant = entry["route_id"]
	if entry_type in DATE_TYPES:
		# Type first, then value, as two statements: `route as String != DATE_ROUTE_ID` does not
		# group the way it reads and casts before the typeof guard can short-circuit it.
		if typeof(route) != TYPE_STRING:
			return _shape_error(entry, "route_id",
				"%s entries route to %s, got %s" % [entry_type, DATE_ROUTE_ID, str(route)],
				&"invalid_route", _route_details(entry, entry_type, route))
		if str(route) != DATE_ROUTE_ID:
			return _shape_error(entry, "route_id",
				"%s entries route to %s, got %s" % [entry_type, DATE_ROUTE_ID, str(route)],
				&"invalid_route", _route_details(entry, entry_type, route))
		return {}
	if route != null:
		return _shape_error(entry, "route_id",
			"%s entries carry no route, got %s" % [entry_type, str(route)],
			&"invalid_route", _route_details(entry, entry_type, route))
	return {}


static func _effect_ids_error(entry: Dictionary) -> Dictionary:
	if typeof(entry["effect_ids"]) != TYPE_ARRAY:
		return _shape_error(entry, "effect_ids", "effect_ids must be an array")
	var seen: Dictionary = {}
	for effect: Variant in entry["effect_ids"] as Array:
		if typeof(effect) != TYPE_STRING or (effect as String).is_empty():
			return _shape_error(entry, "effect_ids", "effect ids must be nonempty Strings")
		if seen.has(effect):
			# A repeated id APPLIES THE EFFECT TWICE. Silently deduplicating would change the
			# gameplay outcome of an already-saved schedule, so this rejects instead. Order is
			# otherwise preserved: nothing here sorts or rewrites the caller's array.
			return _shape_error(entry, "effect_ids", "effect %s is listed twice" % str(effect),
				&"duplicate_effect_id",
				{"entry_id": str(entry.get("entry_id", "")), "effect_id": str(effect)})
		seen[effect] = true
	return {}


## A shape violation, failure-ready. Defaults to `invalid_entry` reporting which field failed;
## commits E1/E2 pass their own code and details for routes and repeated effects.
static func _shape_error(entry: Dictionary, field: String, message: String,
		code := &"invalid_entry", extra_details: Dictionary = {}) -> Dictionary:
	var details: Dictionary = {"entry_id": str(entry.get("entry_id", "")), "field": field}
	if not extra_details.is_empty():
		details = extra_details
	return {"code": code, "message": message, "details": details}


static func _shape_failure(shape_error: Dictionary) -> Dictionary:
	return _fail(shape_error["code"], str(shape_error["message"]), shape_error["details"])


static func _route_details(entry: Dictionary, entry_type: String, route: Variant) -> Dictionary:
	return {"entry_id": str(entry.get("entry_id", "")), "type": entry_type, "route_id": route}


static func _ok(value: Dictionary = {}) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


## Legacy bare result for `validate_date_candidate` only, retired by Step 4.2b.
static func _legacy_fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
