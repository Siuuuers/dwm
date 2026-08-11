extends "res://addons/gut/test.gd"
# Strict ScheduleRules validation (Plan-04 Task 4, audit list dated 2026-08-10).
#
# The audit found eight validations missing from the shipped module. They are added one at a time,
# each with RED coverage first, because every one changes what validate_candidate/validate_existing
# REJECT -- and a rule that is subtly too strict breaks schedules that used to load.
#
# Landed before this sequence:
#   [x] Duplicate action_id detection                                    (49947e5)
#   [x] build_route_plan projection                                      (1c25aba)
#
# Execution sequence, ruled by the plan author on 2026-08-11 (11 commits):
#   [x] A  Freeze the master command-result contracts             refactor
#   [x] B  Validate existing AND prospective schedule at add time  audit 3
#   [x] D  Return typed codes from entry shape validation          refactor
#   [x] E1 Entry element types, arity and day range                audit 7a
#   [x] C  Duplicate solo/group friend sets in validate_existing   audit 2
#   [x] E2 Semantic route validation in both strict validators     audit 7b
#   [x] F  Day 7 restricted to one solo entry at slot zero         audit 6
#   [x] G  Exact eligibility graph validation                      audit 4
#   [x] H  Day-7 evidence rejected outside Day 7                   audit 5
#   [x] I  Day-4 Priscilla seated by slot index                    new
#   [ ] J  Detached validated candidate in successful results      audit 8
#
# This sequence completes the PURE-VALIDATOR slice only. Task 4 stays open: Step 4.2a receipt
# ownership, Step 4.2b GameState delegation, and snapshot/migration/restore validation remain.

const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")


func _friends_for(type: String) -> Array:
	# A group date is the Priscilla-Lavinia pair (ContactInvitationState.GROUP_PAIR), never one
	# friend. Fixed in commit E1, which makes group arity a validated rule.
	if type == "action":
		return []
	if type == "group":
		return ["priscilla", "lavinia"]
	return ["priscilla"]


func _entry(entry_id: String, slot: int, type: String, action_id: String, day := 3) -> Dictionary:
	return {
		"entry_id": entry_id,
		"slot_index": slot,
		"day": day,
		"type": type,
		"action_id": action_id,
		"friend_ids": _friends_for(type),
		"route_id": "dating" if type != "action" else null,
		"effect_ids": [],
		"unlock_receipt_id": null,
	}


func _with(entry_id: String, field: String, value: Variant, type := "action") -> Dictionary:
	var entry := _entry(entry_id, 0, type, "rest")
	entry[field] = value
	return entry


# ---- duplicate action_id ----

func test_two_entries_sharing_an_action_id_are_rejected() -> void:
	# Distinct entry_ids and distinct slots, but the same underlying action: scheduling the same
	# action twice in one day is not a legal schedule, and nothing else in validate_existing
	# catches it.
	var schedule := [
		_entry("a", 0, "action", "rest"),
		_entry("b", 1, "action", "rest"),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_false(result.get("ok", false), "the same action cannot be scheduled twice")
	assert_eq(result.get("code"), &"duplicate_action_id", "typed rejection")


func test_distinct_action_ids_remain_valid() -> void:
	var schedule := [
		_entry("a", 0, "action", "rest"),
		_entry("b", 1, "action", "training"),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_true(result.get("ok", false), "distinct actions coexist: " + str(result))


func test_a_single_entry_is_never_a_duplicate_of_itself() -> void:
	# The self-comparison trap: a one-entry schedule must not reject on its own action_id.
	var result: Dictionary = SCHEDULE_RULES.validate_existing([_entry("a", 0, "action", "rest")], 3)
	assert_true(result.get("ok", false), "one entry is not a duplicate: " + str(result))


func test_duplicate_action_ids_are_caught_across_types() -> void:
	var schedule := [
		_entry("solo-p", 0, "solo", "solo:priscilla:day3"),
		_entry("dupe", 1, "action", "solo:priscilla:day3"),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_false(result.get("ok", false), "an action_id collision is a collision regardless of type")
	assert_eq(result.get("code"), &"duplicate_action_id", "typed rejection")


# ---- master command-result contract (commit A) ----
#
# Success is EXACTLY {ok, code, value, receipt}. Failure is EXACTLY {ok, code, message, details}.
# A failure never leaks a partial value or receipt, and every code pins its exact details keys, so a
# future consumer can branch on data instead of parsing prose. validate_date_candidate is the one
# deliberate exception: it keeps the legacy bare shape until Step 4.2b retires it.

const _SUCCESS_KEYS := ["code", "ok", "receipt", "value"]
const _FAILURE_KEYS := ["code", "details", "message", "ok"]
const _LEGACY_KEYS := ["code", "message", "ok"]


func _date_entry(entry_id: String, slot: int, type: String, action_id: String, friends: Array,
		day := 3) -> Dictionary:
	var entry := _entry(entry_id, slot, type, action_id, day)
	entry["friend_ids"] = friends
	return entry


func _day7_entry() -> Dictionary:
	var entry := _entry("ending-sylvia-d7", 0, "solo", "ending-date:sylvia:day7", 7)
	entry["friend_ids"] = ["sylvia"]
	entry["unlock_receipt_id"] = "unlock:sylvia:day7"
	return entry


func _eligibility(action_ids: Array) -> Dictionary:
	return {
		"registered_action_ids": action_ids,
		"day7_candidate": null,
		"receipt_index": {},
	}


func _shape_of(result: Dictionary) -> Array:
	var keys: Array = result.keys()
	keys.sort()
	return keys


# ---- envelope ----

func test_validate_existing_success_is_the_master_envelope() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing([_entry("a", 0, "action", "rest")], 3)
	assert_eq(_shape_of(result), _SUCCESS_KEYS, "success is exactly the four contract keys")
	assert_eq(result["value"], {}, "a predicate produces no value")
	assert_eq(result["receipt"], {}, "a predicate issues no receipt")


func test_validate_candidate_success_is_the_master_envelope() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _entry("a", 0, "action", "rest"), 3, 6, _eligibility(["rest"]))
	assert_eq(_shape_of(result), _SUCCESS_KEYS, "success is exactly the four contract keys")
	assert_eq(result["value"], {}, "the detached candidate arrives in commit J, not before")


func test_build_route_plan_success_is_the_master_envelope() -> void:
	var result: Dictionary = SCHEDULE_RULES.build_route_plan(
		[_entry("solo-p", 0, "solo", "solo:priscilla:day3")], 3)
	assert_eq(_shape_of(result), _SUCCESS_KEYS, "success is exactly the four contract keys")


func test_no_failure_from_any_strict_method_leaks_a_value_or_receipt() -> void:
	var collided := [_entry("a", 0, "action", "rest"), _entry("b", 1, "action", "rest")]
	var failures: Array = [
		SCHEDULE_RULES.validate_existing(collided, 3),
		SCHEDULE_RULES.validate_candidate([], _entry("a", 0, "action", "rest"), 3, 0,
			_eligibility(["rest"])),
		SCHEDULE_RULES.build_route_plan(collided, 3),
	]
	for result: Dictionary in failures:
		assert_eq(_shape_of(result), _FAILURE_KEYS,
			"failure is exactly the four contract keys: " + str(result))


func test_validate_date_candidate_keeps_the_legacy_bare_shape() -> void:
	# Deliberate exception, retired by Step 4.2b once rg proves zero callers.
	var result: Dictionary = SCHEDULE_RULES.validate_date_candidate([], {"type": "action"}, 3)
	assert_eq(_shape_of(result), _LEGACY_KEYS, "the legacy adapter keeps {ok, code, message}")


# ---- exact details per code ----

func test_details_for_invalid_entry() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_entry("a", 0, "twofriends", "x")], 3)
	assert_eq(result.get("code"), &"invalid_entry", "typed rejection")
	assert_eq(result.get("details"), {"entry_id": "a", "field": "type"}, "exact details keys")


func test_details_for_duplicate_entry_id() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_entry("a", 0, "action", "rest"), _entry("a", 1, "action", "training")], 3)
	assert_eq(result.get("code"), &"duplicate_entry_id", "typed rejection")
	assert_eq(result.get("details"), {"entry_id": "a"}, "exact details keys")


func test_details_for_duplicate_action_id() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_entry("a", 0, "action", "rest"), _entry("b", 1, "action", "rest")], 3)
	assert_eq(result.get("details"), {"action_id": "rest"}, "exact details keys")


func test_details_for_duplicate_slot_index() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_entry("a", 0, "action", "rest"), _entry("b", 0, "action", "training")], 3)
	assert_eq(result.get("code"), &"duplicate_slot_index", "typed rejection")
	assert_eq(result.get("details"), {"slot_index": 0}, "exact details keys")


func test_details_for_too_many_dates() -> void:
	# Distinct friends so this fixture survives commit C's friend-set rule and E1's roster check.
	var schedule := [
		_date_entry("d1", 0, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("d2", 1, "solo", "solo:lavinia:day3", ["lavinia"]),
		_date_entry("d3", 2, "solo", "solo:sylvia:day3", ["sylvia"]),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_eq(result.get("code"), &"too_many_dates", "typed rejection")
	assert_eq(result.get("details"), {"day": 3, "date_count": 3, "allowed": 2}, "exact details keys")


func test_details_for_no_motivation() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _entry("a", 0, "action", "rest"), 3, 0, _eligibility(["rest"]))
	assert_eq(result.get("code"), &"no_motivation", "typed rejection")
	assert_eq(result.get("details"), {"motivation": 0}, "exact details keys")


func test_details_for_unregistered_action() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _entry("a", 0, "action", "unknown"), 3, 6, _eligibility(["rest"]))
	assert_eq(result.get("code"), &"unregistered_action", "typed rejection")
	assert_eq(result.get("details"), {"action_id": "unknown"}, "exact details keys")


func test_duplicate_entry_is_retired_in_favour_of_the_standard_collision_codes() -> void:
	# `duplicate_entry` was ambiguous: it fired for an action collision but read like an entry_id
	# collision. Collisions now report exactly one of duplicate_entry_id / duplicate_slot_index /
	# duplicate_action_id / duplicate_friend_date, from validate_existing, for Add and Done alike.
	var existing := [_entry("a", 0, "action", "rest")]
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		existing, _entry("b", 1, "action", "rest"), 3, 6, _eligibility(["rest"]))
	assert_eq(result.get("code"), &"duplicate_action_id", "the standardized collision code")
	assert_eq(result.get("details"), {"action_id": "rest"}, "exact details keys")


# ---- the Add/Done law (commit B) ----
#
# If Add accepts a candidate, the resulting schedule MUST pass Done validation. validate_candidate
# therefore validates the existing schedule first, then the candidate, then the PROSPECTIVE
# schedule (existing + candidate). An existing-schedule failure always wins and propagates
# byte-for-byte, because a corrupt board is a more fundamental fault than a bad new entry.

func test_a_candidate_reusing_an_existing_entry_id_is_rejected() -> void:
	# The gap the prospective-schedule stage exists to close: nothing in validate_candidate ever
	# compared entry_ids, so Add accepted a candidate that Done would immediately reject.
	var existing := [_entry("a", 0, "action", "rest")]
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		existing, _entry("a", 1, "action", "training"), 3, 6, _eligibility(["training"]))
	assert_false(result.get("ok", false), "an entry_id cannot be reused")
	assert_eq(result.get("code"), &"duplicate_entry_id", "typed rejection")


func test_whatever_add_accepts_done_also_accepts() -> void:
	# The law itself, asserted over the accepting cases rather than a single example.
	var existing := [_date_entry("d1", 0, "solo", "solo:priscilla:day3", ["priscilla"])]
	var candidates: Array = [
		_entry("a1", 1, "action", "rest"),
		_date_entry("d2", 2, "solo", "solo:lavinia:day3", ["lavinia"]),
	]
	for candidate: Dictionary in candidates:
		var added: Dictionary = SCHEDULE_RULES.validate_candidate(
			existing, candidate, 3, 6, _eligibility(["rest", "solo:lavinia:day3"]))
		if not added.get("ok", false):
			continue
		var prospective: Array = existing.duplicate()
		prospective.append(candidate)
		assert_true(SCHEDULE_RULES.validate_existing(prospective, 3).get("ok", false),
			"Add accepted a candidate Done rejects: " + str(candidate))


func test_a_broken_existing_schedule_is_rejected_before_the_candidate() -> void:
	var broken := [_entry("a", 0, "action", "rest"), _entry("b", 1, "action", "rest")]
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		broken, _entry("c", 2, "action", "training"), 3, 6, _eligibility(["training"]))
	assert_eq(result.get("code"), &"duplicate_action_id", "the existing schedule's own failure")
	assert_eq(result.get("details"), {"action_id": "rest"},
		"propagated byte-for-byte, naming the EXISTING collision and not the candidate")


func test_an_existing_schedule_failure_outranks_insufficient_motivation() -> void:
	# A corrupt board is the more fundamental fault, so it must not be masked by the cheap check.
	var broken := [_entry("a", 0, "action", "rest"), _entry("b", 1, "action", "rest")]
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		broken, _entry("c", 2, "action", "training"), 3, 0, _eligibility(["training"]))
	assert_eq(result.get("code"), &"duplicate_action_id", "the board is judged before the wallet")


func test_a_valid_add_against_a_valid_board_still_succeeds() -> void:
	var existing := [_date_entry("d1", 0, "solo", "solo:priscilla:day3", ["priscilla"])]
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		existing, _entry("a1", 1, "action", "rest"), 3, 6, _eligibility(["rest"]))
	assert_true(result.get("ok", false), "three new stages must not reject a legal add: " + str(result))


func test_details_for_duplicate_friend_date() -> void:
	var existing := [_date_entry("s1", 0, "solo", "solo:priscilla:day3", ["priscilla"])]
	var candidate := _date_entry("s2", 1, "solo", "picnic:priscilla:day3", ["priscilla"])
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		existing, candidate, 3, 6, _eligibility(["picnic:priscilla:day3"]))
	assert_eq(result.get("code"), &"duplicate_friend_date", "typed rejection")
	assert_eq(result.get("details"), {"type": "solo", "friend_ids": ["priscilla"]},
		"exact details keys")


func test_details_for_priscilla_first_slot_required() -> void:
	var existing := [_entry("x", 0, "action", "rest", 4)]
	var candidate := _date_entry("s1", 1, "solo", "solo:priscilla:day4", ["priscilla"], 4)
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		existing, candidate, 4, 6, _eligibility(["solo:priscilla:day4", "rest"]))
	assert_eq(result.get("code"), &"priscilla_first_slot_required", "typed rejection")
	assert_eq(result.get("details"), {"slot_index": 1}, "exact details keys")


func test_details_for_day7_candidate_not_synchronized() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _day7_entry(), 7, 6, _eligibility(["ending-date:sylvia:day7"]))
	assert_eq(result.get("code"), &"day7_candidate_not_synchronized", "typed rejection")
	assert_eq((result.get("details") as Dictionary).keys(), ["reason"], "exact details keys")
	assert_false(str((result.get("details") as Dictionary)["reason"]).is_empty(),
		"the reason names which link of the evidence chain broke")


func test_details_for_invalid_route() -> void:
	var strayed := _entry("rest", 0, "action", "rest")
	strayed["route_id"] = "dating"
	var result: Dictionary = SCHEDULE_RULES.build_route_plan([strayed], 3)
	assert_eq(result.get("code"), &"invalid_route", "typed rejection")
	assert_eq(result.get("details"), {"entry_id": "rest", "type": "action", "route_id": "dating"},
		"exact details keys")


# ---- strict element types, arity and day range (commit E1) ----
#
# No str() or int() coercion anywhere: a value of the wrong TYPE is wrong, not something to be
# quietly converted. Coercion is how "3" reaches a field contracted as int and how a null becomes
# the string "<null>", and both survive persistence to fail somewhere far from the cause.

func _field_of(result: Dictionary) -> String:
	return str((result.get("details", {}) as Dictionary).get("field", ""))


func test_the_validated_day_must_be_a_real_day() -> void:
	for day: int in [0, 8, -1]:
		var result: Dictionary = SCHEDULE_RULES.validate_existing([], day)
		assert_false(result.get("ok", false), "day %d is not a day" % day)
		assert_eq(result.get("code"), &"invalid_day", "typed rejection for day %d" % day)
		assert_eq(result.get("details"), {"day": day}, "exact details keys")


func test_every_real_day_is_accepted() -> void:
	for day: int in [1, 2, 3, 4, 5, 6, 7]:
		assert_true(SCHEDULE_RULES.validate_existing([], day).get("ok", false),
			"day %d is a real day" % day)


func test_a_stringy_day_is_not_coerced() -> void:
	# int("3") == 3 silently matched the validated day, so a persisted string survived validation.
	var result: Dictionary = SCHEDULE_RULES.validate_existing([_with("a", "day", "3")], 3)
	assert_eq(result.get("code"), &"invalid_entry", "typed rejection")
	assert_eq(_field_of(result), "day", "the day field is named")


func test_a_nonstring_entry_id_is_not_coerced() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing([_with("a", "entry_id", 42)], 3)
	assert_eq(result.get("code"), &"invalid_entry", "typed rejection")
	assert_eq(_field_of(result), "entry_id", "the entry_id field is named")


func test_a_nonstring_or_empty_action_id_is_rejected() -> void:
	for bad: Variant in [7, "", null]:
		var result: Dictionary = SCHEDULE_RULES.validate_existing([_with("a", "action_id", bad)], 3)
		assert_eq(result.get("code"), &"invalid_entry", "typed rejection for " + str(bad))
		assert_eq(_field_of(result), "action_id", "the action_id field is named")


func test_an_action_entry_carries_no_friends() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_with("a", "friend_ids", ["priscilla"])], 3)
	assert_eq(result.get("code"), &"invalid_entry", "typed rejection")
	assert_eq(_field_of(result), "friend_ids", "the friend_ids field is named")


func test_a_solo_date_names_exactly_one_friend() -> void:
	for friends: Array in [[], ["priscilla", "lavinia"]]:
		var entry := _date_entry("s", 0, "solo", "solo:x:day3", friends)
		var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 3)
		assert_eq(result.get("code"), &"invalid_entry", "a solo date is one friend: " + str(friends))
		assert_eq(_field_of(result), "friend_ids", "the friend_ids field is named")


func test_a_group_date_names_exactly_two_distinct_friends() -> void:
	for friends: Array in [["priscilla"], ["priscilla", "priscilla"],
			["priscilla", "lavinia", "sylvia"]]:
		var entry := _date_entry("g", 0, "group", "group:x:day3", friends)
		var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 3)
		assert_eq(result.get("code"), &"invalid_entry", "a group is a distinct pair: " + str(friends))
		assert_eq(_field_of(result), "friend_ids", "the friend_ids field is named")


func test_a_valid_group_pair_is_accepted() -> void:
	var entry := _date_entry("g", 0, "group", "group:x:day3", ["lavinia", "priscilla"])
	assert_true(SCHEDULE_RULES.validate_existing([entry], 3).get("ok", false),
		"either order of the pair is the same pair")


func test_friend_ids_must_name_known_friends() -> void:
	# Membership against the canonical DataCatalog.FRIEND_IDS roster, not a fourth copied list.
	for bad: Variant in ["gandalf", "", 3] :
		var entry := _date_entry("s", 0, "solo", "solo:x:day3", [bad])
		var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 3)
		assert_eq(result.get("code"), &"invalid_entry", "unknown friend: " + str(bad))
		assert_eq(_field_of(result), "friend_ids", "the friend_ids field is named")


func test_effect_ids_must_be_nonempty_strings() -> void:
	for bad: Variant in [[""], [5], [null]]:
		var result: Dictionary = SCHEDULE_RULES.validate_existing([_with("a", "effect_ids", bad)], 3)
		assert_eq(result.get("code"), &"invalid_entry", "bad effect element: " + str(bad))
		assert_eq(_field_of(result), "effect_ids", "the effect_ids field is named")


func test_a_repeated_effect_id_is_rejected_rather_than_deduplicated() -> void:
	# Repeated IDs currently APPLY THE EFFECT TWICE. Silently deduplicating would change the
	# gameplay outcome of a saved schedule, so this rejects instead.
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_with("a", "effect_ids", ["mood_up", "mood_up"])], 3)
	assert_eq(result.get("code"), &"duplicate_effect_id", "its own typed code, not invalid_entry")
	assert_eq(result.get("details"), {"entry_id": "a", "effect_id": "mood_up"}, "exact details keys")


func test_distinct_effect_ids_keep_their_order() -> void:
	var entry := _with("a", "effect_ids", ["b", "a", "c"])
	assert_true(SCHEDULE_RULES.validate_existing([entry], 3).get("ok", false),
		"distinct effects are valid")
	assert_eq(entry["effect_ids"], ["b", "a", "c"], "validation never reorders the caller's array")


# ---- duplicate solo/group friend sets in validate_existing (commit C) ----
#
# Every fixture here differs in entry_id, slot_index AND action_id, so no other rule can mask the
# one under test. Two solo dates with the same friend normally SHARE an action_id, in which case
# duplicate_action_id fires first and a careless test passes without this rule existing at all.

func test_two_solo_dates_with_the_same_friend_are_rejected() -> void:
	var schedule := [
		_date_entry("s1", 0, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("s2", 1, "solo", "picnic:priscilla:day3", ["priscilla"]),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_false(result.get("ok", false), "one friend, one date per day")
	assert_eq(result.get("code"), &"duplicate_friend_date", "typed rejection")
	assert_eq(result.get("details"), {"type": "solo", "friend_ids": ["priscilla"]},
		"exact details keys")


func test_a_group_pair_in_either_order_is_the_same_pair() -> void:
	# Set equality, not list equality: comparison sorts DETACHED copies and never the caller's data.
	var schedule := [
		_date_entry("g1", 0, "group", "group:pl:day3", ["priscilla", "lavinia"]),
		_date_entry("g2", 1, "group", "picnic:pl:day3", ["lavinia", "priscilla"]),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_eq(result.get("code"), &"duplicate_friend_date", "reversed order is the same pair")
	assert_eq(schedule[1]["friend_ids"], ["lavinia", "priscilla"],
		"the caller's array is never reordered by the comparison")


func test_a_solo_and_a_group_sharing_a_friend_remain_valid() -> void:
	# Deliberate canon: solo compares to solo and group to group. Participant exclusivity across
	# types is a future design question, not a Phase-2R bug.
	var schedule := [
		_date_entry("s1", 0, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("g1", 1, "group", "group:pl:day3", ["priscilla", "lavinia"]),
	]
	assert_true(SCHEDULE_RULES.validate_existing(schedule, 3).get("ok", false),
		"cross-type overlap is legal today: " + str(SCHEDULE_RULES.validate_existing(schedule, 3)))


func test_dates_with_different_friends_coexist() -> void:
	var schedule := [
		_date_entry("s1", 0, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("s2", 1, "solo", "solo:lavinia:day3", ["lavinia"]),
	]
	assert_true(SCHEDULE_RULES.validate_existing(schedule, 3).get("ok", false),
		"different friends are different dates")


func test_a_single_date_is_never_a_duplicate_of_itself() -> void:
	var schedule := [_date_entry("s1", 0, "solo", "solo:priscilla:day3", ["priscilla"])]
	assert_true(SCHEDULE_RULES.validate_existing(schedule, 3).get("ok", false),
		"each unordered pair is compared once, and an entry is never paired with itself")


func test_add_and_done_agree_about_a_repeated_friend() -> void:
	var existing := [_date_entry("s1", 0, "solo", "solo:priscilla:day3", ["priscilla"])]
	var candidate := _date_entry("s2", 1, "solo", "picnic:priscilla:day3", ["priscilla"])
	var added: Dictionary = SCHEDULE_RULES.validate_candidate(
		existing, candidate, 3, 6, _eligibility(["picnic:priscilla:day3"]))
	assert_eq(added.get("code"), &"duplicate_friend_date", "Add refuses what Done would refuse")


# ---- semantic route validation in BOTH strict validators (commit E2) ----
#
# Routing is CLOSED: an action carries no route; a solo or group date routes to the registered
# "dating" scene. "none" and "advance" are RETIRED control sentinels, not route ids. Enforcing this
# only inside build_route_plan meant an unroutable schedule was still a "valid" schedule.

func test_an_action_carrying_a_route_is_invalid_in_the_schedule_itself() -> void:
	var strayed := _with("rest", "route_id", "dating")
	var result: Dictionary = SCHEDULE_RULES.validate_existing([strayed], 3)
	assert_eq(result.get("code"), &"invalid_route", "its own typed code, not invalid_entry")
	assert_eq(result.get("details"), {"entry_id": "rest", "type": "action", "route_id": "dating"},
		"exact details keys")


func test_a_date_must_carry_the_registered_dating_route() -> void:
	for stray: Variant in ["none", "advance", "menu", "twofriends", "", null, 7]:
		var entry := _date_entry("s", 0, "solo", "solo:priscilla:day3", ["priscilla"])
		entry["route_id"] = stray
		var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 3)
		assert_eq(result.get("code"), &"invalid_route", "a date may not route to " + str(stray))


func test_the_retired_none_sentinel_is_not_a_route() -> void:
	# "none" was a control sentinel that outlived its purpose and survived in fixtures as if it
	# were a route id. An action carries null, not the STRING "none".
	var result: Dictionary = SCHEDULE_RULES.validate_existing([_with("a", "route_id", "none")], 3)
	assert_eq(result.get("code"), &"invalid_route", "\"none\" is not a route")


func test_add_refuses_a_route_contradiction_the_board_would_refuse() -> void:
	var strayed := _with("rest", "route_id", "dating")
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], strayed, 3, 6, _eligibility(["rest"]))
	assert_eq(result.get("code"), &"invalid_route", "Add and Done agree about routing")


func test_correct_routes_remain_valid() -> void:
	var schedule := [
		_entry("a", 0, "action", "rest"),
		_date_entry("s", 1, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("g", 2, "group", "group:pl:day3", ["priscilla", "lavinia"]),
	]
	# One action plus two dates is exactly the Day 1-6 allowance, so correct routes must pass.
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_true(result.get("ok", false), "correct routes are not rejected: " + str(result))


# ---- day 7 is one solo ending at slot zero (commit F) ----
#
# Validation runs in day-INDEPENDENT phases: day range, then per-entry shape, then the daily
# allowance, then collisions and placement. The allowance deliberately precedes collisions, so two
# well-shaped Day-7 endings report too_many_dates -- the cause -- instead of duplicate_slot_index
# or a nonzero-slot invalid_entry, which are symptoms of having scheduled one ending too many.

func _day7_solo(entry_id: String, slot: int, friend: String, action_id: String) -> Dictionary:
	var entry := _date_entry(entry_id, slot, "solo", action_id, [friend], 7)
	entry["unlock_receipt_id"] = "unlock:%s:day7" % friend
	return entry


func test_an_empty_day_seven_is_the_valid_alone_state() -> void:
	assert_true(SCHEDULE_RULES.validate_existing([], 7).get("ok", false),
		"scheduling no ending is how the player reaches Alone")


func test_day_seven_accepts_exactly_one_solo_at_slot_zero() -> void:
	var schedule := [_day7_solo("e", 0, "sylvia", "ending-date:sylvia:day7")]
	assert_true(SCHEDULE_RULES.validate_existing(schedule, 7).get("ok", false),
		"the single ending date: " + str(SCHEDULE_RULES.validate_existing(schedule, 7)))


func test_day_seven_rejects_actions_and_group_dates() -> void:
	var action := _entry("a", 0, "action", "rest", 7)
	var group := _date_entry("g", 0, "group", "group:pl:day7", ["priscilla", "lavinia"], 7)
	for entry: Dictionary in [action, group]:
		var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 7)
		assert_eq(result.get("code"), &"invalid_entry", "day 7 is endings only: " + str(entry["type"]))
		assert_eq(_field_of(result), "type", "the type field is named")


func test_a_day_seven_ending_at_a_nonzero_slot_is_rejected() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing(
		[_day7_solo("e", 2, "sylvia", "ending-date:sylvia:day7")], 7)
	assert_eq(result.get("code"), &"invalid_entry", "the ending seats at slot zero")
	assert_eq(_field_of(result), "slot_index", "the slot_index field is named")


func test_two_day_seven_endings_report_the_allowance_not_the_slot() -> void:
	# The precedence that keeps too_many_dates reachable on Day 7 at all: both entries are well
	# shaped, so the fault is that there are two endings, not where the second one sits.
	var schedule := [
		_day7_solo("e1", 0, "priscilla", "ending-date:priscilla:day7"),
		_day7_solo("e2", 1, "lavinia", "ending-date:lavinia:day7"),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 7)
	assert_eq(result.get("code"), &"too_many_dates", "the cause, not the symptom")
	assert_eq(result.get("details"), {"day": 7, "date_count": 2, "allowed": 1}, "exact details keys")


func test_three_dates_on_a_normal_day_exceed_the_allowance() -> void:
	# too_many_dates must stay genuinely covered on Days 1-6, not merely survive as dead code.
	var schedule := [
		_date_entry("d1", 0, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("d2", 1, "solo", "solo:lavinia:day3", ["lavinia"]),
		_date_entry("d3", 2, "solo", "solo:sylvia:day3", ["sylvia"]),
	]
	var result: Dictionary = SCHEDULE_RULES.validate_existing(schedule, 3)
	assert_eq(result.get("code"), &"too_many_dates", "days 1-6 allow two dates")
	assert_eq(result.get("details"), {"day": 3, "date_count": 3, "allowed": 2}, "exact details keys")


func test_the_allowance_outranks_a_slot_collision_on_a_normal_day_too() -> void:
	# Deliberate consequence of day-independent phases: a schedule that is BOTH over the allowance
	# and colliding reports the allowance. Pinned so the precedence is a decision, not an accident.
	var schedule := [
		_date_entry("d1", 0, "solo", "solo:priscilla:day3", ["priscilla"]),
		_date_entry("d2", 0, "solo", "solo:lavinia:day3", ["lavinia"]),
		_date_entry("d3", 2, "solo", "solo:sylvia:day3", ["sylvia"]),
	]
	assert_eq(SCHEDULE_RULES.validate_existing(schedule, 3).get("code"), &"too_many_dates",
		"the allowance is judged before the collision")


# ---- exact eligibility graph (commit G) ----
#
# eligibility carries exactly registered_action_ids, day7_candidate and receipt_index. It used to be
# read with tolerant .get() defaults, so a caller that misspelled or omitted a key silently got []
# and every action looked unregistered -- a programmer error wearing a gameplay rejection's clothes.
# invalid_eligibility means MALFORMED; commit H's day7_evidence_on_non_day7 means well-formed but
# forbidden on Days 1-6.

func _receipt(friend: String) -> Dictionary:
	return {
		"receipt_id": "unlock:%s:day7" % friend,
		"kind": "day7_unlock",
		"action_id": "ending-date:%s:day7" % friend,
		"friend_id": friend,
		"day": 7,
		"previous_receipt_id": null,
	}


func _elig_with(key: String, value: Variant) -> Dictionary:
	var elig := _eligibility(["rest"])
	if value == null and key == "__erase__":
		return elig
	elig[key] = value
	return elig


func _rejects_eligibility(eligibility: Dictionary, why: String) -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _entry("a", 0, "action", "rest"), 3, 6, eligibility)
	assert_eq(result.get("code"), &"invalid_eligibility", why + ": " + str(result))


func test_eligibility_carries_exactly_three_keys() -> void:
	var extra := _eligibility(["rest"])
	extra["surprise"] = true
	_rejects_eligibility(extra, "an unknown key is a malformed graph")
	var missing := _eligibility(["rest"])
	missing.erase("receipt_index")
	_rejects_eligibility(missing, "a missing key must not silently default")


func test_registered_action_ids_are_unique_nonempty_strings() -> void:
	for bad: Variant in [["rest", "rest"], ["rest", ""], ["rest", 4], "rest", null]:
		_rejects_eligibility(_elig_with("registered_action_ids", bad), "bad registry " + str(bad))


func test_day7_candidate_is_exactly_shaped_or_null() -> void:
	_rejects_eligibility(_elig_with("day7_candidate", {}), "an empty candidate is not a candidate")
	_rejects_eligibility(_elig_with("day7_candidate", 7), "a candidate is a dictionary or null")
	var extra_key := {"action_id": "a", "friend_id": "sylvia", "unlock_receipt_id": "u", "x": 1}
	_rejects_eligibility(_elig_with("day7_candidate", extra_key), "exactly three candidate keys")


func test_every_receipt_record_is_deep_validated_not_only_the_referenced_one() -> void:
	# The unreferenced record matters: it is persisted evidence, and a malformed one is corruption
	# whether or not today's candidate happens to point at it.
	var broken_kind := _receipt("sylvia")
	broken_kind["kind"] = "schedule_add"
	_rejects_eligibility(_elig_with("receipt_index", {"unlock:sylvia:day7": broken_kind}),
		"an unlock receipt's kind must be day7_unlock")
	var broken_day := _receipt("sylvia")
	broken_day["day"] = 6
	_rejects_eligibility(_elig_with("receipt_index", {"unlock:sylvia:day7": broken_day}),
		"an unlock receipt belongs to day 7")
	var chained := _receipt("sylvia")
	chained["previous_receipt_id"] = "unlock:earlier"
	_rejects_eligibility(_elig_with("receipt_index", {"unlock:sylvia:day7": chained}),
		"an unlock receipt starts the chain")


func test_a_receipt_map_key_must_equal_its_receipt_id() -> void:
	_rejects_eligibility(_elig_with("receipt_index", {"wrong-key": _receipt("sylvia")}),
		"the map key is the receipt id, not a label")


func test_a_well_formed_eligibility_graph_is_accepted() -> void:
	var elig := _eligibility(["rest"])
	elig["receipt_index"] = {"unlock:sylvia:day7": _receipt("sylvia")}
	elig["day7_candidate"] = {
		"action_id": "ending-date:sylvia:day7",
		"friend_id": "sylvia",
		"unlock_receipt_id": "unlock:sylvia:day7",
	}
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _day7_solo("e", 0, "sylvia", "ending-date:sylvia:day7"), 7, 6, elig)
	assert_eq(result.get("code"), &"unregistered_action",
		"the graph itself is well formed; only the registry lacks the action: " + str(result))


# ---- day 7 evidence belongs only to day 7 (commit H) ----
#
# Three distinct faults, three distinct codes: invalid_eligibility means malformed;
# day7_evidence_on_non_day7 means WELL FORMED but forbidden on an ordinary day; and
# day7_candidate_not_synchronized means well formed, allowed, but not matching. A wrong-TYPED
# receipt is still just a bad field, so it stays invalid_entry.

func test_an_ordinary_day_rejects_a_well_formed_entry_receipt() -> void:
	var entry := _date_entry("s", 0, "solo", "solo:priscilla:day3", ["priscilla"])
	entry["unlock_receipt_id"] = "unlock:priscilla:day3"
	var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 3)
	assert_eq(result.get("code"), &"day7_evidence_on_non_day7", "forbidden, not merely malformed")
	assert_eq(result.get("details"), {"day": 3, "source": "entry"}, "exact details keys")


func test_a_wrong_typed_entry_receipt_stays_a_shape_failure() -> void:
	var entry := _date_entry("s", 0, "solo", "solo:priscilla:day3", ["priscilla"])
	entry["unlock_receipt_id"] = 42
	var result: Dictionary = SCHEDULE_RULES.validate_existing([entry], 3)
	assert_eq(result.get("code"), &"invalid_entry", "a bad type is a bad field, not leaked evidence")
	assert_eq(_field_of(result), "unlock_receipt_id", "the field is named")


func test_an_ordinary_day_rejects_a_day7_candidate_in_eligibility() -> void:
	var elig := _eligibility(["rest"])
	elig["day7_candidate"] = {
		"action_id": "ending-date:sylvia:day7",
		"friend_id": "sylvia",
		"unlock_receipt_id": "unlock:sylvia:day7",
	}
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _entry("a", 0, "action", "rest"), 3, 6, elig)
	assert_eq(result.get("code"), &"day7_evidence_on_non_day7", "an ending is not offered on day 3")
	assert_eq(result.get("details"), {"day": 3, "source": "eligibility"}, "exact details keys")


func test_an_ordinary_day_rejects_a_populated_receipt_index() -> void:
	var elig := _eligibility(["rest"])
	elig["receipt_index"] = {"unlock:sylvia:day7": _receipt("sylvia")}
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _entry("a", 0, "action", "rest"), 3, 6, elig)
	assert_eq(result.get("code"), &"day7_evidence_on_non_day7", "day 3 carries no unlock receipts")


func test_day_seven_still_reports_a_mismatch_as_desynchronized() -> void:
	# Well formed AND allowed, but the links disagree: that is a third, different fault.
	var elig := _eligibility(["ending-date:sylvia:day7"])
	elig["receipt_index"] = {"unlock:sylvia:day7": _receipt("sylvia")}
	elig["day7_candidate"] = {
		"action_id": "ending-date:sylvia:day7",
		"friend_id": "lavinia",
		"unlock_receipt_id": "unlock:sylvia:day7",
	}
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _day7_solo("e", 0, "sylvia", "ending-date:sylvia:day7"), 7, 6, elig)
	assert_eq(result.get("code"), &"day7_candidate_not_synchronized", "a mismatch, not a leak")


func test_day_seven_accepts_its_own_synchronized_evidence() -> void:
	var elig := _eligibility(["ending-date:sylvia:day7"])
	elig["receipt_index"] = {"unlock:sylvia:day7": _receipt("sylvia")}
	elig["day7_candidate"] = {
		"action_id": "ending-date:sylvia:day7",
		"friend_id": "sylvia",
		"unlock_receipt_id": "unlock:sylvia:day7",
	}
	var result: Dictionary = SCHEDULE_RULES.validate_candidate(
		[], _day7_solo("e", 0, "sylvia", "ending-date:sylvia:day7"), 7, 6, elig)
	assert_true(result.get("ok", false), "the whole evidence chain agrees: " + str(result))


# ---- day 4 seats Priscilla by slot index (commit I) ----
#
# The rule was approximated as "existing.is_empty()", which is not the same statement. It asked
# whether anything had been added YET, not where Priscilla sits, so it depended on the order the
# caller happened to add entries in. GameState appends sequentially, which is why the two
# readings agreed in practice and no test ever separated them.

func _p_solo(slot: int) -> Dictionary:
	return _date_entry("p", slot, "solo", "solo:priscilla:day4", ["priscilla"], 4)


func test_day_four_rejects_priscilla_away_from_the_first_slot() -> void:
	var result: Dictionary = SCHEDULE_RULES.validate_existing([_p_solo(1)], 4)
	assert_eq(result.get("code"), &"priscilla_first_slot_required", "typed rejection")
	assert_eq(result.get("details"), {"slot_index": 1}, "exact details keys")


func test_day_four_accepts_priscilla_at_slot_zero_beside_a_later_entry() -> void:
	# THE BEHAVIOR THAT CHANGES. Priscilla IS first here, but the old emptiness test rejected her
	# because something already occupied a later slot. Nothing in the tree covered this case.
	var schedule := [_entry("x", 1, "action", "rest", 4), _p_solo(0)]
	assert_true(SCHEDULE_RULES.validate_existing(schedule, 4).get("ok", false),
		"slot 0 is the first slot regardless of what else is scheduled: "
			+ str(SCHEDULE_RULES.validate_existing(schedule, 4)))


func test_add_agrees_with_done_about_priscillas_seat() -> void:
	var elig := _eligibility(["solo:priscilla:day4", "rest"])
	var occupied := [_entry("x", 0, "action", "rest", 4)]
	assert_eq(SCHEDULE_RULES.validate_candidate(occupied, _p_solo(1), 4, 6, elig).get("code"),
		&"priscilla_first_slot_required", "Add refuses a later seat")
	var later := [_entry("x", 1, "action", "rest", 4)]
	assert_true(SCHEDULE_RULES.validate_candidate(later, _p_solo(0), 4, 6, elig).get("ok", false),
		"Add accepts her at slot 0 even when a later slot is taken")


func test_the_seating_rule_applies_only_to_day_four() -> void:
	var day3 := _date_entry("p", 1, "solo", "solo:priscilla:day3", ["priscilla"])
	assert_true(SCHEDULE_RULES.validate_existing([day3], 3).get("ok", false),
		"other days seat Priscilla anywhere")


func test_the_seating_rule_applies_only_to_a_priscilla_solo_date() -> void:
	var lavinia := _date_entry("l", 1, "solo", "solo:lavinia:day4", ["lavinia"], 4)
	assert_true(SCHEDULE_RULES.validate_existing([lavinia], 4).get("ok", false),
		"another friend takes any slot on day 4")
	var group := _date_entry("g", 1, "group", "group:pl:day4", ["priscilla", "lavinia"], 4)
	assert_true(SCHEDULE_RULES.validate_existing([group], 4).get("ok", false),
		"the rule seats her SOLO date, not every date she appears in")
