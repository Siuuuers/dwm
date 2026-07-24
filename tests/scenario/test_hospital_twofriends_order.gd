extends "res://addons/gut/test.gd"

# Hospital outcome seam (dwm-p2r.7, plan-04 Task 5 / req.flow.hospital_order).
# Hospital consequences resolve as a PURE result: recovery values plus the count of
# Sylvia solo dates lost to fainting. It never advances the day and never mutates input.

const RULES_PATH := "res://scripts/domain/ending/DatingEndingRules.gd"

func test_hospital_outcome_is_pure_and_records_skipped_sylvia() -> void:
	var rules: Script = load(RULES_PATH)
	assert_not_null(rules)
	if rules == null:
		return
	var input := {
		"day": 7,
		"health": 0,
		"pressure": 6,
		"condition_effect_ids": ["condition.danger"],
		"scheduled_date_outcomes": [{
			"action_id": "ending-date:sylvia:day7",
			"friend_ids": ["sylvia"],
			"outcome": "prevented_by_fainting",
		}],
		"transaction_id": "hospital:run-1:day7",
	}
	var before: Dictionary = input.duplicate(true)
	var result: Dictionary = rules.resolve_hospital_outcome(input)
	assert_true(result.get("ok", false))
	assert_eq(input, before, "resolve_hospital_outcome never mutates its input")
	assert_eq(result["value"]["health"], 6)
	assert_eq(result["value"]["pressure"], 3)
	assert_eq(result["value"]["condition_effect_ids"], [])
	assert_eq(result["value"]["hospital_skipped_sylvia_solo_count_delta"], 1)
	assert_eq(result["receipt"]["transaction_id"], "hospital:run-1:day7")
	assert_eq(result["receipt"]["kind"], "hospital_outcome")
	assert_eq(int(result["receipt"]["day"]), 7, "hospital never changes the day")

func test_hospital_accepts_group_outcome_but_counts_only_sylvia_solo() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var result: Dictionary = rules.resolve_hospital_outcome({
		"day": 3,
		"health": 0,
		"pressure": 6,
		"condition_effect_ids": ["condition.danger"],
		"scheduled_date_outcomes": [
			{
				"action_id": "solo:sylvia:day3",
				"friend_ids": ["sylvia"],
				"outcome": "prevented_by_fainting",
			},
			{
				"action_id": "group:priscilla_lavinia:day2",
				"friend_ids": ["priscilla", "lavinia"],
				"outcome": "cancelled_by_fainting",
			},
		],
		"transaction_id": "hospital:run-1:day3",
	})
	assert_true(result.get("ok", false))
	assert_eq(result["value"]["hospital_skipped_sylvia_solo_count_delta"], 1,
		"a group loss never feeds the Sylvia solo counter")
	assert_eq(result["receipt"]["skipped_action_ids"], ["solo:sylvia:day3"])

func test_hospital_ignores_attended_dates_and_other_friends() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var result: Dictionary = rules.resolve_hospital_outcome({
		"day": 5,
		"health": -2,
		"pressure": 12,
		"condition_effect_ids": ["condition.danger", "sequela"],
		"scheduled_date_outcomes": [
			{"action_id": "solo:sylvia:day5", "friend_ids": ["sylvia"], "outcome": "attended"},
			{"action_id": "solo:lavinia:day5", "friend_ids": ["lavinia"], "outcome": "prevented_by_fainting"},
		],
		"transaction_id": "hospital:run-1:day5",
	})
	assert_true(result.get("ok", false))
	assert_eq(result["value"]["hospital_skipped_sylvia_solo_count_delta"], 0,
		"an attended Sylvia date and a lost Lavinia date both count zero")
	assert_eq(result["receipt"]["skipped_action_ids"], [])

func test_hospital_rejects_an_unknown_outcome() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var result: Dictionary = rules.resolve_hospital_outcome({
		"day": 3,
		"health": 0,
		"pressure": 6,
		"condition_effect_ids": [],
		"scheduled_date_outcomes": [
			{"action_id": "solo:sylvia:day3", "friend_ids": ["sylvia"], "outcome": "ghosted"},
		],
		"transaction_id": "hospital:run-1:day3",
	})
	assert_false(result.get("ok", true), "outcome must be a registered value")
