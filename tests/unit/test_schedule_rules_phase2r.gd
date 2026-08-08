extends "res://addons/gut/test.gd"

# ScheduleRules (dwm-p2r.7, plan-04 Task 4): candidate-add validation is a DIFFERENT
# question from existing-schedule validation. Adding an entry asks "may this be added
# now?"; Done re-validates the schedule as it stands, where each entry must not
# invalidate itself.

const SCHEDULE_RULES_PATH := "res://scripts/domain/schedule/ScheduleRules.gd"

func _rules() -> Script:
	return load(SCHEDULE_RULES_PATH)

func _solo_entry(friend_id: String, day: int, slot_index: int = 0) -> Dictionary:
	return {
		"entry_id": "solo-%s-d%d" % [friend_id, day],
		"slot_index": slot_index,
		"day": day,
		"type": "solo",
		"friend_ids": [friend_id],
		"action_id": "solo:%s:day%d" % [friend_id, day],
		"route_id": "dating",
		"effect_ids": [],
		"unlock_receipt_id": null,
	}

func _eligibility(action_ids: Array) -> Dictionary:
	return {
		"registered_action_ids": action_ids,
		"day7_candidate": null,
		"receipt_index": {},
	}

func test_existing_entry_does_not_invalidate_itself() -> void:
	var rules: Script = _rules()
	assert_not_null(rules, "ScheduleRules must exist")
	if rules == null:
		return
	var existing: Array = [_solo_entry("priscilla", 3)]
	assert_true(rules.validate_existing(existing, 3).get("ok", false),
		"a one-entry schedule is valid as it stands")
	assert_false(rules.validate_candidate(existing, existing[0], 3, 6,
			_eligibility(["solo:priscilla:day3"])).get("ok", false),
		"the same entry re-offered as a NEW candidate is a duplicate")

func test_candidate_accepts_a_distinct_friend() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var existing: Array = [_solo_entry("priscilla", 3)]
	var candidate: Dictionary = _solo_entry("lavinia", 3, 1)
	assert_true(rules.validate_candidate(existing, candidate, 3, 6,
			_eligibility(["solo:priscilla:day3", "solo:lavinia:day3"])).get("ok", false),
		"a different friend on the same day is addable")

func test_duplicate_slot_index_fails_existing_validation() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var clashing: Array = [_solo_entry("priscilla", 3, 0), _solo_entry("lavinia", 3, 0)]
	var result: Dictionary = rules.validate_existing(clashing, 3)
	assert_false(result.get("ok", true), "duplicate slot indexes are invalid")
	assert_eq(str(result.get("code", "")), "duplicate_slot_index")

func test_candidate_rejected_without_motivation() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var candidate: Dictionary = _solo_entry("priscilla", 3)
	assert_false(rules.validate_candidate([], candidate, 3, 0,
			_eligibility(["solo:priscilla:day3"])).get("ok", false),
		"no motivation blocks the add")

func test_candidate_rejected_for_unregistered_action() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var candidate: Dictionary = _solo_entry("priscilla", 3)
	assert_false(rules.validate_candidate([], candidate, 3, 6, _eligibility([])).get("ok", false),
		"an action id outside the registered set is rejected")

func test_day7_candidate_requires_matching_unlock_receipt_record() -> void:
	# Day 7 accepts a date only when the candidate, the day7_candidate, and the indexed
	# unlock receipt agree exactly. No ID naming convention counts as proof.
	var rules: Script = _rules()
	if rules == null:
		return
	var candidate: Dictionary = {
		"entry_id": "ending-sylvia-d7",
		"slot_index": 0,
		"day": 7,
		"type": "solo",
		"friend_ids": ["sylvia"],
		"action_id": "ending-date:sylvia:day7",
		"route_id": "dating",
		"effect_ids": [],
		"unlock_receipt_id": "unlock:sylvia:day7",
	}
	var eligibility: Dictionary = {
		"registered_action_ids": ["ending-date:sylvia:day7"],
		"day7_candidate": {
			"action_id": "ending-date:sylvia:day7",
			"friend_id": "sylvia",
			"unlock_receipt_id": "unlock:sylvia:day7",
		},
		"receipt_index": {
			"unlock:sylvia:day7": {
				"receipt_id": "unlock:sylvia:day7",
				"kind": "day7_unlock",
				"action_id": "ending-date:sylvia:day7",
				"friend_id": "sylvia",
				"day": 7,
				"previous_receipt_id": null,
			}
		},
	}
	assert_true(rules.validate_candidate([], candidate, 7, 6, eligibility).get("ok", false),
		"a fully synchronized day-7 candidate is addable")
	var mismatched: Dictionary = eligibility.duplicate(true)
	mismatched["receipt_index"]["unlock:sylvia:day7"]["friend_id"] = "lavinia"
	var rejected: Dictionary = rules.validate_candidate([], candidate, 7, 6, mismatched)
	assert_false(rejected.get("ok", false), "a receipt naming a different friend is not proof")
	assert_eq(rejected.get("code"), &"day7_candidate_not_synchronized")

func test_days_one_to_six_reject_an_unlock_receipt() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var candidate: Dictionary = _solo_entry("priscilla", 3)
	candidate["unlock_receipt_id"] = "unlock:priscilla:day3"
	assert_false(rules.validate_candidate([], candidate, 3, 6,
			_eligibility(["solo:priscilla:day3"])).get("ok", false),
		"only day 7 carries an unlock receipt")

func test_entry_shape_rejects_unknown_or_missing_keys() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var elig: Dictionary = _eligibility(["solo:priscilla:day3"])
	var extra: Dictionary = _solo_entry("priscilla", 3)
	extra["surprise"] = true
	assert_false(rules.validate_candidate([], extra, 3, 6, elig).get("ok", false), "unknown keys reject")
	var missing: Dictionary = _solo_entry("priscilla", 3)
	missing.erase("route_id")
	assert_false(rules.validate_candidate([], missing, 3, 6, elig).get("ok", false), "missing keys reject")

func test_entry_shape_rejects_bad_type_and_negative_slot() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var elig: Dictionary = _eligibility(["solo:priscilla:day3"])
	var bad_type: Dictionary = _solo_entry("priscilla", 3)
	bad_type["type"] = "twofriends"
	assert_false(rules.validate_candidate([], bad_type, 3, 6, elig).get("ok", false),
		"twofriends is a deferred route, not a schedulable entry type")
	var negative: Dictionary = _solo_entry("priscilla", 3)
	negative["slot_index"] = -1
	assert_false(rules.validate_candidate([], negative, 3, 6, elig).get("ok", false), "negative slot rejects")

func test_entry_day_must_match_the_validated_day() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var candidate: Dictionary = _solo_entry("priscilla", 3)
	assert_false(rules.validate_candidate([], candidate, 4, 6,
			_eligibility(["solo:priscilla:day3"])).get("ok", false),
		"an entry stamped day 3 cannot be added on day 4")

func test_duplicate_entry_id_fails_existing_validation() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var duplicated: Array = [_solo_entry("priscilla", 3, 0), _solo_entry("priscilla", 3, 1)]
	var result: Dictionary = rules.validate_existing(duplicated, 3)
	assert_false(result.get("ok", true), "the same entry_id twice is invalid")
	assert_eq(str(result.get("code", "")), "duplicate_entry_id")

func _action_entry(action_id: String, day: int, slot_index: int) -> Dictionary:
	return {
		"entry_id": "%s-d%d" % [action_id, day],
		"slot_index": slot_index,
		"day": day,
		"type": "action",
		"friend_ids": [],
		"action_id": action_id,
		"route_id": "none",
		"effect_ids": [],
		"unlock_receipt_id": null,
	}

func test_day4_priscilla_solo_must_take_the_first_slot() -> void:
	# Preserved legacy rule: on Day 4 a Priscilla solo date is only addable as the first entry.
	var rules: Script = _rules()
	if rules == null:
		return
	var elig: Dictionary = _eligibility(["solo:priscilla:day4", "study"])
	var occupied: Array = [_action_entry("study", 4, 0)]
	assert_false(rules.validate_candidate(occupied, _solo_entry("priscilla", 4, 1), 4, 6, elig).get("ok", false),
		"Priscilla cannot follow another entry on Day 4")
	assert_true(rules.validate_candidate([], _solo_entry("priscilla", 4, 0), 4, 6, elig).get("ok", false),
		"Priscilla is addable as the first Day-4 entry")

func test_duplicate_friend_across_dates_is_rejected() -> void:
	# Preserved legacy rule: no two solo dates with the same friend on one day, even when
	# the action ids differ.
	var rules: Script = _rules()
	if rules == null:
		return
	var existing: Array = [_solo_entry("priscilla", 3, 0)]
	var again: Dictionary = _solo_entry("priscilla", 3, 1)
	again["entry_id"] = "solo-priscilla-d3-second"
	again["action_id"] = "makeup-date:priscilla:day3"
	var elig: Dictionary = _eligibility(["solo:priscilla:day3", "makeup-date:priscilla:day3"])
	assert_false(rules.validate_candidate(existing, again, 3, 6, elig).get("ok", false),
		"the same friend cannot be dated twice in a day")

func test_two_dates_fill_the_allowance_and_a_third_rejects() -> void:
	# Days 1-6 allow two dates; a third is too_many_dates.
	var rules: Script = _rules()
	if rules == null:
		return
	var existing: Array = [_solo_entry("priscilla", 3, 0), _solo_entry("lavinia", 3, 1)]
	var third: Dictionary = _solo_entry("sylvia", 3, 2)
	var elig: Dictionary = _eligibility(["solo:priscilla:day3", "solo:lavinia:day3", "solo:sylvia:day3"])
	var result: Dictionary = rules.validate_candidate(existing, third, 3, 6, elig)
	assert_false(result.get("ok", true), "a third date exceeds the day 1-6 allowance")
	assert_eq(str(result.get("code", "")), "too_many_dates")

func test_a_non_date_action_never_consumes_a_date_slot() -> void:
	# Two dates already fill the allowance, yet a non-date action is still addable.
	var rules: Script = _rules()
	if rules == null:
		return
	var existing: Array = [_solo_entry("priscilla", 3, 0), _solo_entry("lavinia", 3, 1)]
	var action: Dictionary = _action_entry("study", 3, 2)
	var elig: Dictionary = _eligibility(["solo:priscilla:day3", "solo:lavinia:day3", "study"])
	assert_true(rules.validate_candidate(existing, action, 3, 6, elig).get("ok", false),
		"actions do not count toward the date allowance")

func test_day7_allows_only_a_single_date() -> void:
	# Day 7 allows exactly one (ending) date; validate_existing rejects two.
	var rules: Script = _rules()
	if rules == null:
		return
	var two_dates: Array = [
		{
			"entry_id": "ending-priscilla-d7", "slot_index": 0, "day": 7, "type": "solo",
			"friend_ids": ["priscilla"], "action_id": "ending-date:priscilla:day7",
			"route_id": "dating", "effect_ids": [], "unlock_receipt_id": "unlock:p:d7",
		},
		{
			"entry_id": "ending-lavinia-d7", "slot_index": 1, "day": 7, "type": "solo",
			"friend_ids": ["lavinia"], "action_id": "ending-date:lavinia:day7",
			"route_id": "dating", "effect_ids": [], "unlock_receipt_id": "unlock:l:d7",
		},
	]
	var result: Dictionary = rules.validate_existing(two_dates, 7)
	assert_false(result.get("ok", true), "day 7 allows only one date")
	assert_eq(str(result.get("code", "")), "too_many_dates")

func test_existing_rejects_a_days_one_to_six_unlock_receipt() -> void:
	# The unlock-receipt rule is a shape rule, so validate_existing enforces it too.
	var rules: Script = _rules()
	if rules == null:
		return
	var bad: Dictionary = _solo_entry("priscilla", 3)
	bad["unlock_receipt_id"] = "unlock:priscilla:day3"
	var result: Dictionary = rules.validate_existing([bad], 3)
	assert_false(result.get("ok", true), "days 1-6 entries carry a null unlock_receipt_id")

func test_existing_requires_a_day7_solo_unlock_receipt() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	var no_receipt: Dictionary = {
		"entry_id": "ending-priscilla-d7", "slot_index": 0, "day": 7, "type": "solo",
		"friend_ids": ["priscilla"], "action_id": "ending-date:priscilla:day7",
		"route_id": "dating", "effect_ids": [], "unlock_receipt_id": null,
	}
	var result: Dictionary = rules.validate_existing([no_receipt], 7)
	assert_false(result.get("ok", true), "a day-7 solo date requires a nonempty unlock receipt")

# ---- validate_date_candidate: the loose-shape date rules (dwm-p2r.7 Task 4) ----
func _loose_solo(friend_id: String) -> Dictionary:
	return {"type": "solo", "friend_id": friend_id, "friend_ids": [friend_id]}

func _loose_group(a: String, b: String) -> Dictionary:
	return {"type": "group", "friend_ids": [a, b]}

func test_validate_date_candidate_accepts_a_distinct_friend() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_true(rules.validate_date_candidate([_loose_solo("priscilla")], _loose_solo("lavinia"), 3).get("ok", false),
		"a distinct-friend date is addable")

func test_validate_date_candidate_rejects_a_duplicate_friend() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("priscilla")], _loose_solo("priscilla"), 3).get("code"),
		&"duplicate_friend_date")

func test_validate_date_candidate_rejects_a_duplicate_group_pair_any_order() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_group("priscilla", "lavinia")], _loose_group("lavinia", "priscilla"), 3).get("code"),
		&"duplicate_friend_date", "the same pair in any order is a duplicate")

func test_validate_date_candidate_enforces_the_two_date_max() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("priscilla"), _loose_solo("lavinia")], _loose_solo("sylvia"), 3).get("code"),
		&"too_many_dates", "days 1-6 allow two dates")

func test_validate_date_candidate_day4_seats_priscilla_first() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("lavinia")], _loose_solo("priscilla"), 4).get("code"),
		&"priscilla_first_slot_required", "Day 4 Priscilla cannot follow another entry")
	assert_true(rules.validate_date_candidate([], _loose_solo("priscilla"), 4).get("ok", false),
		"Priscilla first on an empty schedule is fine")

func test_validate_date_candidate_reads_a_minimal_friend_id_candidate() -> void:
	# GameState.can_add_schedule_action passes {type, friend_id} with no friend_ids.
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([_loose_solo("priscilla")], {"type": "solo", "friend_id": "priscilla"}, 3).get("code"),
		&"duplicate_friend_date", "a {type, friend_id} candidate still resolves its friend")

func test_validate_date_candidate_rejects_a_non_date_type() -> void:
	var rules: Script = _rules()
	if rules == null:
		return
	assert_eq(rules.validate_date_candidate([], {"type": "training"}, 3).get("code"), &"not_a_date")
