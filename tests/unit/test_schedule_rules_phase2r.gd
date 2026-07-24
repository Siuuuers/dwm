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
