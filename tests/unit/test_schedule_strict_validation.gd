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
#   [ ] E1 Entry element types, arity and day range                audit 7a
#   [ ] C  Duplicate solo/group friend sets in validate_existing   audit 2
#   [ ] E2 Semantic route validation in both strict validators     audit 7b
#   [ ] F  Day 7 restricted to one solo entry at slot zero         audit 6
#   [ ] G  Exact eligibility graph validation                      audit 4
#   [ ] H  Day-7 evidence rejected outside Day 7                   audit 5
#   [ ] I  Day-4 Priscilla seated by slot index                    new
#   [ ] J  Detached validated candidate in successful results      audit 8
#
# This sequence completes the PURE-VALIDATOR slice only. Task 4 stays open: Step 4.2a receipt
# ownership, Step 4.2b GameState delegation, and snapshot/migration/restore validation remain.

const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")


func _entry(entry_id: String, slot: int, type: String, action_id: String, day := 3) -> Dictionary:
	return {
		"entry_id": entry_id,
		"slot_index": slot,
		"day": day,
		"type": type,
		"action_id": action_id,
		"friend_ids": ["priscilla"] if type != "action" else [],
		"route_id": "dating" if type != "action" else null,
		"effect_ids": [],
		"unlock_receipt_id": null,
	}


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
