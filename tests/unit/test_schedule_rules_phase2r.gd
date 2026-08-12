extends "res://addons/gut/test.gd"

# ScheduleRules.validate_date_candidate: the PROVISIONAL loose-shape date adapter.
#
# Plan 01 Task 1 (dwm-p2r.12) retired the nine-key strict surface this file used to exercise --
# validate_existing, validate_candidate, and the (schedule, day) route projection. Those rules were
# reimplemented against the accepted draft/committed schemas in
# tests/unit/test_schedule_strict_validation.gd and tests/unit/test_schedule_route_plan.gd, so the
# tests that pinned the retired transport were removed rather than mechanically translated.
#
# What remains below is deliberate: validate_date_candidate is kept byte-compatible while the legacy
# GameState facade still calls it (autoload/GameState.gd). Task 5 removes the method, its last
# caller, and these tests together, in the atomic v3 cutover, after `rg` proves no caller remains.
# Do not route any accepted-schema path through this adapter.

const SCHEDULE_RULES_PATH := "res://scripts/domain/schedule/ScheduleRules.gd"

func _rules() -> Script:
	return load(SCHEDULE_RULES_PATH)


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
	# The accepted schema retires this rule (Priscilla may take any legal Day-4 slot), but the
	# legacy adapter must keep it byte-compatible until its caller is removed in Task 5.
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

func test_the_retired_nine_key_surface_is_gone() -> void:
	# Guards the Step 1.6 disposition: the retired transport must not quietly return.
	var rules: Script = _rules()
	if rules == null:
		return
	var probe: Object = rules.new()
	for retired: String in ["validate_existing", "validate_candidate"]:
		assert_false(probe.has_method(retired),
			retired + " was retired by the accepted schema and must not come back")
