extends "res://addons/gut/test.gd"

const PLAN_PATH := "res://scripts/domain/run/DayResolutionPlan.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"

const DAY_1_6_STAGES := [
	"lock_day", "validate_schedule", "execute_schedule_entries", "commit_outcomes",
	"hospital_if_triggered", "twofriends_if_deferred", "invitation_rollover",
	"increment_day", "reset_day_scope", "new_day_autosave", "unlock_day",
]
const DAY_7_STAGES := [
	"lock_day", "validate_schedule", "execute_schedule_entries", "commit_outcomes",
	"hospital_if_triggered", "close_invitations_run_end", "resolve_ending_plan",
	"enter_ending", "ending_autosave",
]

func _plan_exists() -> bool:
	return ResourceLoader.exists(PLAN_PATH, "Script")

func _entry(entry_id: String, slot_index: int) -> Dictionary:
	return {"entry_id": entry_id, "slot_index": slot_index}

func _stage_ids(plan: RefCounted) -> Array[String]:
	var ids: Array[String] = []
	for stage: Dictionary in plan.to_dict()["stages"]:
		ids.append(str(stage["stage_id"]))
	return ids

func test_duplicate_completion_reuses_receipt_and_conflict_changes_nothing() -> void:
	assert_true(ResourceLoader.exists(PLAN_PATH, "Script"), "DayResolutionPlan must exist")
	if not ResourceLoader.exists(PLAN_PATH, "Script"):
		return
	assert_true(ResourceLoader.exists(RECEIPTS_PATH, "Script"), "receipt fixtures must exist")
	if not ResourceLoader.exists(RECEIPTS_PATH, "Script"):
		return
	var plan_result: Dictionary = load(PLAN_PATH).create("resolution-r1-d3", 3, [])
	assert_true(plan_result.get("ok", false), JSON.stringify(plan_result))
	var plan: RefCounted = plan_result["value"]["plan"]
	var stage: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
	assert_eq(stage["stage_id"], "lock_day")
	assert_true(plan.begin_stage(stage["stage_id"], stage["transaction_id"])["ok"])
	var receipt: Dictionary = load(RECEIPTS_PATH).call(&"for_stage", &"lock_day", 3)
	var first: Dictionary = plan.complete_stage(
		stage["stage_id"], stage["transaction_id"], receipt
	)
	assert_true(first["ok"])
	var after_first: Dictionary = plan.to_dict()
	var replay: Dictionary = plan.complete_stage(
		stage["stage_id"], stage["transaction_id"], receipt.duplicate(true)
	)
	assert_true(replay["ok"])
	assert_eq(replay["receipt"], first["receipt"])
	var conflicting: Dictionary = receipt.duplicate(true)
	conflicting["value"]["locked"] = false
	var rejected: Dictionary = plan.complete_stage(
		stage["stage_id"], stage["transaction_id"], conflicting
	)
	assert_false(rejected["ok"])
	assert_eq(rejected["code"], &"duplicate_transaction_conflict")
	assert_eq(plan.to_dict(), after_first)

func test_stage_allowlists_by_source_day() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	for day: int in range(1, 7):
		var created: Dictionary = load(PLAN_PATH).create("resolution-d%d" % day, day, [])
		assert_true(created.get("ok", false), JSON.stringify(created))
		assert_eq(_stage_ids(created["value"]["plan"]), DAY_1_6_STAGES, "day %d" % day)
	var day7: Dictionary = load(PLAN_PATH).create("resolution-d7", 7, [])
	assert_true(day7.get("ok", false), JSON.stringify(day7))
	var day7_ids := _stage_ids(day7["value"]["plan"])
	assert_eq(day7_ids, DAY_7_STAGES)
	for forbidden: String in ["invitation_rollover", "increment_day", "twofriends_if_deferred", "new_day_autosave", "reset_day_scope", "unlock_day"]:
		assert_false(forbidden in day7_ids, forbidden + " must not exist on Day 7")
	assert_true(day7_ids.find("hospital_if_triggered") < day7_ids.find("resolve_ending_plan"),
		"Day 7 hospital precedes ending selection")

func test_create_rejects_invalid_inputs() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var plan_script: Script = load(PLAN_PATH)
	assert_false(plan_script.create("", 3, []).get("ok", true), "empty resolution_id rejects")
	assert_false(plan_script.create("r", 0, []).get("ok", true), "day 0 rejects")
	assert_false(plan_script.create("r", 8, []).get("ok", true), "day 8 rejects")
	var duplicate_slots: Array[Dictionary] = [_entry("a", 1), _entry("b", 1)]
	assert_false(plan_script.create("r", 3, duplicate_slots).get("ok", true), "duplicate slot rejects")
	var empty_id: Array[Dictionary] = [_entry("", 1)]
	assert_false(plan_script.create("r", 3, empty_id).get("ok", true), "empty entry_id rejects")

func test_substages_sort_by_slot_and_gate_parent_completion() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var entries: Array[Dictionary] = [_entry("late", 2), _entry("early", 1)]
	var created: Dictionary = load(PLAN_PATH).create("resolution-sub", 2, entries)
	assert_true(created.get("ok", false), JSON.stringify(created))
	var plan: RefCounted = created["value"]["plan"]
	for stage_id: String in ["lock_day", "validate_schedule"]:
		var cursor: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
		assert_eq(cursor["stage_id"], stage_id)
		assert_true(plan.begin_stage(stage_id, cursor["transaction_id"])["ok"])
		assert_true(plan.complete_stage(stage_id, cursor["transaction_id"],
			load(RECEIPTS_PATH).call(&"for_stage", stage_id, 2))["ok"])
	var first_sub: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
	assert_eq(first_sub["substage_id"], "schedule:2:1:early", "substages sort by slot_index")
	var parent_receipt: Dictionary = load(RECEIPTS_PATH).call(&"for_stage", "execute_schedule_entries", 2)
	var parent_transaction := "resolution-sub:execute_schedule_entries"
	assert_false(plan.begin_stage("execute_schedule_entries", parent_transaction).get("ok", true),
		"parent may not begin while substages pending")
	for substage_id: String in ["schedule:2:1:early", "schedule:2:2:late"]:
		var cursor: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
		assert_eq(cursor["substage_id"], substage_id)
		assert_true(plan.begin_substage("execute_schedule_entries", substage_id, cursor["transaction_id"])["ok"])
		assert_true(plan.complete_substage("execute_schedule_entries", substage_id, cursor["transaction_id"],
			load(RECEIPTS_PATH).call(&"for_substage", substage_id))["ok"])
	var parent_cursor: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
	assert_eq(parent_cursor["stage_id"], "execute_schedule_entries")
	assert_true(plan.begin_stage("execute_schedule_entries", parent_transaction)["ok"])
	assert_true(plan.complete_stage("execute_schedule_entries", parent_transaction, parent_receipt)["ok"])

func test_begin_rejects_wrong_transaction_and_out_of_order() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = load(PLAN_PATH).create("resolution-order", 4, [])
	assert_true(created.get("ok", false))
	var plan: RefCounted = created["value"]["plan"]
	assert_false(plan.begin_stage("lock_day", "wrong-transaction").get("ok", true), "wrong transaction rejects")
	assert_false(plan.begin_stage("validate_schedule", "resolution-order:validate_schedule").get("ok", true),
		"beginning a later stage rejects")
	assert_false(plan.complete_stage("lock_day", "resolution-order:lock_day",
		load(RECEIPTS_PATH).call(&"for_stage", "lock_day", 4)).get("ok", true),
		"completing a non-active stage rejects")
	assert_true(plan.begin_stage("lock_day", "resolution-order:lock_day")["ok"])
	var duplicate_begin: Dictionary = plan.begin_stage("lock_day", "resolution-order:lock_day")
	assert_true(duplicate_begin.get("ok", false), "duplicate begin of the active record returns it")

func test_from_dict_round_trip_and_strictness() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var plan_script: Script = load(PLAN_PATH)
	var created: Dictionary = plan_script.create("resolution-io", 5, [])
	assert_true(created.get("ok", false))
	var plan: RefCounted = created["value"]["plan"]
	var data: Dictionary = plan.to_dict()
	var restored: Dictionary = plan_script.from_dict(data.duplicate(true))
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	assert_eq(restored["value"]["plan"].to_dict(), data, "round trip is lossless")

	var unknown_key: Dictionary = data.duplicate(true)
	unknown_key["extra"] = 1
	assert_false(plan_script.from_dict(unknown_key).get("ok", true), "unknown top-level key rejects")

	var reordered: Dictionary = data.duplicate(true)
	var stages: Array = reordered["stages"]
	var moved: Dictionary = stages.pop_back()
	stages.insert(0, moved)
	assert_false(plan_script.from_dict(reordered).get("ok", true), "reordered stages reject")

	var pending_with_receipt: Dictionary = data.duplicate(true)
	pending_with_receipt["stages"][0]["receipt"] = {"value": {"locked": true}}
	assert_false(plan_script.from_dict(pending_with_receipt).get("ok", true), "pending stage with receipt rejects")

	var gap: Dictionary = data.duplicate(true)
	gap["stages"][1]["state"] = "completed"
	gap["stages"][1]["receipt"] = {"value": {"valid": true}}
	assert_false(plan_script.from_dict(gap).get("ok", true), "completed after incomplete rejects")

	var bad_transaction: Dictionary = data.duplicate(true)
	bad_transaction["stages"][0]["transaction_id"] = "other:lock_day"
	assert_false(plan_script.from_dict(bad_transaction).get("ok", true), "mismatched transaction rejects")
