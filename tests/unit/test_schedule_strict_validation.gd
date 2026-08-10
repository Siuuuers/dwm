extends "res://addons/gut/test.gd"
# Strict ScheduleRules validation (Plan-04 Task 4 Step 3, audit list dated 2026-08-10).
#
# The audit found eight validations missing from the shipped module. They are added one at a time,
# each with RED coverage first, because every one changes what validate_candidate/validate_existing
# REJECT -- and a rule that is subtly too strict breaks saved schedules that used to load.
#
# Progress against the audit list:
#   [x] Duplicate action_id detection
#   [ ] Duplicate solo/group friend-set detection in validate_existing
#   [ ] Validation of the existing schedule BEFORE candidate validation
#   [ ] Exact eligibility keys and types
#   [ ] Rejection of stray Day-7 evidence on Days 1-6
#   [ ] Day-7 action/group and nonzero-slot rejection
#   [ ] Strict action_id, route_id, friend/effect element validation
#   [ ] A detached normalized candidate in successful results

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
