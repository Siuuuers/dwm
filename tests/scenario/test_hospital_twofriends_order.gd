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

func test_hospital_rejects_a_group_outcome_with_a_non_canonical_pair() -> void:
	# plan-04 Task 5: a group outcome must name the canonical sorted priscilla+lavinia pair.
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var wrong_pair: Dictionary = rules.resolve_hospital_outcome({
		"day": 2, "health": 0, "pressure": 6, "condition_effect_ids": [],
		"scheduled_date_outcomes": [
			{"action_id": "group:day2", "friend_ids": ["priscilla", "sylvia"], "outcome": "cancelled_by_fainting"},
		],
		"transaction_id": "hospital:run-1:day2",
	})
	assert_false(wrong_pair.get("ok", true), "a non-canonical group pair is rejected")
	var unsorted: Dictionary = rules.resolve_hospital_outcome({
		"day": 2, "health": 0, "pressure": 6, "condition_effect_ids": [],
		"scheduled_date_outcomes": [
			{"action_id": "group:day2", "friend_ids": ["lavinia", "priscilla"], "outcome": "cancelled_by_fainting"},
		],
		"transaction_id": "hospital:run-1:day2",
	})
	assert_false(unsorted.get("ok", true), "the pair must be canonically sorted")

func test_hospital_rejects_three_friends_in_one_outcome() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var result: Dictionary = rules.resolve_hospital_outcome({
		"day": 2, "health": 0, "pressure": 6, "condition_effect_ids": [],
		"scheduled_date_outcomes": [
			{"action_id": "trio:day2", "friend_ids": ["priscilla", "lavinia", "sylvia"], "outcome": "attended"},
		],
		"transaction_id": "hospital:run-1:day2",
	})
	assert_false(result.get("ok", true), "an outcome names one friend (solo) or the pair (group)")


# -------------------------------------------------------------------------------------------------
# Plan 01 Task 8 Step 8.4 (dwm-p2r.14): what Plan-01 composition may NOT reach.
#
# The tests above exercise DatingEndingRules.resolve_hospital_outcome directly, which is legitimate
# for the RULE. What Task 8 adds is the composition-level claim: the Plan-01 Schedule-Done flow never
# calls DatingEndingRules to freeze a final plan, and leaves the completed interim ending foundation
# byte-for-byte unchanged. dwm-oyo.6 owns the final ordered plan and its forms.
# -------------------------------------------------------------------------------------------------

const COORDINATOR_PATH := "res://scripts/application/run/DayResolutionCoordinator.gd"
const STATE_PORT_PATH := "res://scripts/application/run/GameStateDayResolutionPort.gd"
const PLAN_PATH := "res://scripts/domain/run/DayResolutionPlan.gd"
const HOSPITAL_PORT_PATH := "res://scripts/application/run/HospitalPresentationPort.gd"
const DATING_PORT_PATH := "res://scripts/application/run/DatingPresentationPort.gd"
const OWNER_ADAPTER_PATH := "res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd"


func test_no_plan_01_presentation_component_reaches_dating_ending_rules() -> void:
	# A presentation port that could reach the ending rules would be one refactor away from letting
	# a scene select an ending, which is precisely the ownership Task 8 removes.
	for path: String in [HOSPITAL_PORT_PATH, DATING_PORT_PATH, OWNER_ADAPTER_PATH]:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("DatingEndingRules"),
			path + " must not reference DatingEndingRules")
		assert_false(source.contains("ending_plan"),
			path + " must not construct or carry an ending plan")


func test_the_day7_branch_owns_no_ending_stage() -> void:
	# Task 7 removed resolve_ending_plan / enter_ending / ending_autosave from the frozen Day-7
	# array; Task 8 pins that they did not quietly return alongside the provenance handoff.
	var plan: Script = load(PLAN_PATH)
	var day7: Array = plan.DAY_7_STAGES
	for forbidden: String in ["resolve_ending_plan", "enter_ending", "ending_autosave",
			"increment_day", "reset_day_scope", "execute_schedule_dates"]:
		assert_false(day7.has(forbidden), "Day 7 must not carry " + forbidden)
	assert_eq(day7[day7.size() - 1], "checkpoint_day7_provenance",
		"Day 7 ends AT the provenance handoff")


func test_the_hospital_stage_is_owned_by_hospital_rules_not_the_ending_rules() -> void:
	# Task 7 moved this ownership; Task 8's presentation layer must not have moved it back.
	var coordinator: Script = load(COORDINATOR_PATH)
	var contracts: Dictionary = coordinator.STAGE_CONTRACTS
	assert_eq(str((contracts["hospital_if_triggered"] as Dictionary)["owner_id"]), "hospital_rules")
	assert_eq(str((contracts["checkpoint_day7_provenance"] as Dictionary)["owner_id"]),
		"day7_schedule_provenance")


func test_the_state_port_never_calls_the_ending_rules_for_a_day7_handoff() -> void:
	var source := FileAccess.get_file_as_string(STATE_PORT_PATH)
	var day7_section := source.substr(source.find("func _day7_handoff"))
	assert_false(day7_section.contains("DATING_ENDING_RULES"),
		"the Day-7 handoff derives its cause from the committed aggregate, never from ending rules")
	assert_false(day7_section.contains("date_completed"),
		"date_completed is not Day-7 proof")
