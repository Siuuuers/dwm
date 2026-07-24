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
