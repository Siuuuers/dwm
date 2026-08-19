extends "res://addons/gut/test.gd"

const PLAN_PATH := "res://scripts/domain/run/DayResolutionPlan.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"

## Plan 01 Task 7 frozen stage arrays. The provisional single `execute_schedule_entries` stage is
## gone: Days 1-6 execute committed ORDINARY effects first, resolve condition truth, run Hospital,
## and only then run the dates Hospital did not supersede. Day 7 keeps no board, no reset, no
## increment, and no ending selection -- it ends at the checkpointed provenance handoff that
## dwm-oyo.3 / dwm-oyo.6 consume.
const DAY_1_6_STAGES := [
	"lock_day", "validate_schedule", "execute_schedule_actions", "commit_outcomes",
	"hospital_if_triggered", "execute_schedule_dates", "twofriends_if_deferred",
	"invitation_rollover", "increment_day", "reset_day_scope", "new_day_autosave", "unlock_day",
]
const DAY_7_STAGES := [
	"lock_day", "validate_schedule", "close_invitations_run_end",
	"validate_day7_provenance", "checkpoint_day7_provenance",
]

func _plan_exists() -> bool:
	return ResourceLoader.exists(PLAN_PATH, "Script")

## Committed entries now carry the registry-owned `action_kind`, because the plan must FILTER them
## into the ordinary stage and the date stage. `action_kind` is never inferred from the id.
func _entry(entry_id: String, slot_index: int, action_kind: String = "ordinary") -> Dictionary:
	return {"schedule_entry_id": entry_id, "slot_index": slot_index, "action_kind": action_kind}


## The canonical committed aggregate create() now reads its entries out of (plan line 963). Built
## here rather than inline so these cases keep asserting PLAN law -- stage order, substage order,
## transaction ids -- instead of turning into aggregate-shape tests.
func _aggregate(day: int, entries: Array) -> Dictionary:
	return {
		"schema_version": 1,
		"day": day,
		"registry_fingerprint": null,
		"entries": entries.duplicate(true),
		"commit_receipt": null,
	}

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
	var plan_result: Dictionary = load(PLAN_PATH).create("resolution-r1-d3", 3, _aggregate(3, []), [], null, null)
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
		var created: Dictionary = load(PLAN_PATH).create("resolution-d%d" % day, day, _aggregate(day, []), [], null, null)
		assert_true(created.get("ok", false), JSON.stringify(created))
		assert_eq(_stage_ids(created["value"]["plan"]), DAY_1_6_STAGES, "day %d" % day)
	var day7: Dictionary = load(PLAN_PATH).create("resolution-d7", 7, _aggregate(7, []), [], null, null)
	assert_true(day7.get("ok", false), JSON.stringify(day7))
	var day7_ids := _stage_ids(day7["value"]["plan"])
	assert_eq(day7_ids, DAY_7_STAGES)
	# Day 7 owns NO board, NO day advance, and NO ending selection. Plan 01 stops at the
	# checkpointed provenance handoff; dwm-oyo.6 alone turns that into an ordered ending plan.
	for forbidden: String in [
		"execute_schedule_actions", "execute_schedule_dates", "commit_outcomes",
		"hospital_if_triggered", "twofriends_if_deferred", "invitation_rollover",
		"increment_day", "reset_day_scope", "new_day_autosave", "unlock_day",
		"resolve_ending_plan", "enter_ending", "ending_autosave",
	]:
		assert_false(forbidden in day7_ids, forbidden + " must not exist on Day 7")
	assert_eq(day7_ids.back(), "checkpoint_day7_provenance",
		"Day 7 ends at the checkpointed provenance handoff")

func test_day_1_6_runs_hospital_between_ordinary_effects_and_dates() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = load(PLAN_PATH).create("resolution-order-d3", 3, _aggregate(3, []), [], null, null)
	assert_true(created.get("ok", false), JSON.stringify(created))
	var ids := _stage_ids(created["value"]["plan"])
	# req.flow.hospital_order: ordinary effects -> condition truth -> Hospital -> surviving dates.
	assert_true(ids.find("execute_schedule_actions") < ids.find("commit_outcomes"),
		"ordinary effects execute before outcomes commit")
	assert_true(ids.find("commit_outcomes") < ids.find("hospital_if_triggered"),
		"condition truth resolves before Hospital")
	assert_true(ids.find("hospital_if_triggered") < ids.find("execute_schedule_dates"),
		"Hospital supersedes dates BEFORE any dating board runs")
	assert_true(ids.find("execute_schedule_dates") < ids.find("twofriends_if_deferred"),
		"surviving dates precede the deferred pair presentation")
	assert_true(ids.find("twofriends_if_deferred") < ids.find("increment_day"),
		"the day advances only after every presentation stage")
	assert_false("execute_schedule_entries" in ids,
		"the provisional combined execute stage is removed")

func test_create_rejects_invalid_inputs() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var plan_script: Script = load(PLAN_PATH)
	assert_false(plan_script.create("", 3, _aggregate(3, []), [], null, null).get("ok", true), "empty resolution_id rejects")
	assert_false(plan_script.create("r", 0, _aggregate(0, []), [], null, null).get("ok", true), "day 0 rejects")
	assert_false(plan_script.create("r", 8, _aggregate(8, []), [], null, null).get("ok", true), "day 8 rejects")
	var duplicate_slots: Array[Dictionary] = [_entry("a", 1), _entry("b", 1)]
	assert_false(plan_script.create("r", 3, _aggregate(3, duplicate_slots), [], null, null).get("ok", true), "duplicate slot rejects")
	var empty_id: Array[Dictionary] = [_entry("", 1)]
	assert_false(plan_script.create("r", 3, _aggregate(3, empty_id), [], null, null).get("ok", true), "empty schedule_entry_id rejects")

func test_substages_sort_by_slot_and_gate_parent_completion() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var entries: Array[Dictionary] = [_entry("early", 1), _entry("late", 2)]
	var created: Dictionary = load(PLAN_PATH).create("resolution-sub", 2, _aggregate(2, entries), [], null, null)
	assert_true(created.get("ok", false), JSON.stringify(created))
	var plan: RefCounted = created["value"]["plan"]
	for stage_id: String in ["lock_day", "validate_schedule"]:
		var cursor: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
		assert_eq(cursor["stage_id"], stage_id)
		assert_true(plan.begin_stage(stage_id, cursor["transaction_id"])["ok"])
		assert_true(plan.complete_stage(stage_id, cursor["transaction_id"],
			load(RECEIPTS_PATH).call(&"for_stage", stage_id, 2))["ok"])
	var first_sub: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
	assert_eq(first_sub["substage_id"], "ordinary_action:2:1:early", "substages sort by slot_index")
	var parent_receipt: Dictionary = load(RECEIPTS_PATH).call(&"for_stage", "execute_schedule_actions", 2)
	var parent_transaction := "resolution-sub:execute_schedule_actions"
	assert_false(plan.begin_stage("execute_schedule_actions", parent_transaction).get("ok", true),
		"parent may not begin while substages pending")
	for substage_id: String in ["ordinary_action:2:1:early", "ordinary_action:2:2:late"]:
		var cursor: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
		assert_eq(cursor["substage_id"], substage_id)
		assert_true(plan.begin_substage("execute_schedule_actions", substage_id, cursor["transaction_id"])["ok"])
		assert_true(plan.complete_substage("execute_schedule_actions", substage_id, cursor["transaction_id"],
			load(RECEIPTS_PATH).call(&"for_substage", substage_id))["ok"])
	var parent_cursor: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
	assert_eq(parent_cursor["stage_id"], "execute_schedule_actions")
	assert_true(plan.begin_stage("execute_schedule_actions", parent_transaction)["ok"])
	assert_true(plan.complete_stage("execute_schedule_actions", parent_transaction, parent_receipt)["ok"])

## Step 7.1: the two entry stages own DISJOINT substage sets, filtered by the registry-owned
## action_kind, and each is indexed independently from zero in committed slot order. An ordinal is
## never the raw slot number, never the completion order, and never the top-level stage index.
func test_entry_substages_split_by_kind_with_independent_zero_based_ordinals() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	# Deliberately interleaved: ordinary at slots 0 and 4, dates at slots 2 and 5.
	var entries: Array[Dictionary] = [
		_entry("work", 0, "ordinary"),
		_entry("date-p", 2, "solo"),
		_entry("rest", 4, "ordinary"),
		_entry("date-pl", 5, "group"),
	]
	var created: Dictionary = load(PLAN_PATH).create("res-split", 2, _aggregate(2, entries), [], null, null)
	assert_true(created.get("ok", false), JSON.stringify(created))
	var stages: Array = created["value"]["plan"].to_dict()["stages"]
	var by_id := {}
	for stage: Dictionary in stages:
		by_id[str(stage["stage_id"])] = stage

	var ordinary_ids: Array[String] = []
	for substage: Dictionary in (by_id["execute_schedule_actions"]["substages"] as Array):
		ordinary_ids.append(str(substage["substage_id"]))
	assert_eq(ordinary_ids, ["ordinary_action:2:0:work", "ordinary_action:2:4:rest"],
		"only ordinary entries reach execute_schedule_actions, in slot order")

	var date_ids: Array[String] = []
	for substage: Dictionary in (by_id["execute_schedule_dates"]["substages"] as Array):
		date_ids.append(str(substage["substage_id"]))
	assert_eq(date_ids, ["surviving_date:2:2:date-p", "surviving_date:2:5:date-pl"],
		"only solo/group entries reach execute_schedule_dates, in slot order")

	# The date at slot 2 is the FIRST date (ordinal 0) even though its slot is 2 and it sits at
	# index 1 of the committed array. Filtering is per-stage and restarts at zero.
	assert_eq((by_id["execute_schedule_dates"]["substages"] as Array).size(), 2)
	assert_eq((by_id["execute_schedule_actions"]["substages"] as Array).size(), 2)
	for stage_id: String in DAY_1_6_STAGES:
		if stage_id in ["execute_schedule_actions", "execute_schedule_dates"]:
			continue
		assert_true((by_id[stage_id]["substages"] as Array).is_empty(),
			stage_id + " may not hold entry substages")

func test_day7_retains_its_committed_aggregate_and_holds_no_entry_substages() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var entries: Array[Dictionary] = [_entry("d7-solo", 0, "solo")]
	var aggregate := _aggregate(7, entries)
	var created: Dictionary = load(PLAN_PATH).create("res-d7", 7, aggregate, [], null, null)
	assert_true(created.get("ok", false), JSON.stringify(created))
	var plan: RefCounted = created["value"]["plan"]
	assert_eq(plan.get_committed_schedule()["entries"], entries,
		"Day 7 retains its committed aggregate rather than clearing it")
	for stage: Dictionary in plan.to_dict()["stages"]:
		assert_true((stage["substages"] as Array).is_empty(),
			"Day 7 executes no entry substage: " + str(stage["stage_id"]))

func test_begin_rejects_wrong_transaction_and_out_of_order() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = load(PLAN_PATH).create("resolution-order", 4, _aggregate(4, []), [], null, null)
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
	var created: Dictionary = plan_script.create("resolution-io", 5, _aggregate(5, []), [], null, null)
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


# -------------------------------------------------------------------------------------------------
# The persisted resolution ROOT (Plan 01 Task 8 Step 8.2 producer half, dwm-p2r.18)
# -------------------------------------------------------------------------------------------------
#
# WHY THE PLAN MUST CARRY THE ROOT. A presentation intent projects
# `P("day_resolution_start_receipt_id", ...)`, and `resume()` after a crash never re-runs
# `begin_or_resume`. If the root and its start receipt lived only in memory, a restored resolution
# would derive DIFFERENT presentation children than the ones it had already published -- a
# corruption that surfaces only on reload. So both are persisted, and the correspondence between
# them is re-proven on every load rather than trusted.
#
# `command_id` is a SEPARATE member because `resolution_id` is now the issuer-minted root token on
# the minted path. The Done command that began the resolution is what idempotence keys off, and a
# token cannot be recomputed from a command id.

const ROOT_TOKEN := "tok-resolution-1"


func _issuer_receipt(token: String = ROOT_TOKEN) -> Dictionary:
	return {
		"receipt_id": "receipt-" + token, "purpose": "transaction_id", "namespace": "ns-1",
		"counter": 7, "token": token, "numeric_value": null,
	}


func _start_receipt(resolution_id: String = ROOT_TOKEN) -> Dictionary:
	return {
		"receipt_id": "start-child-1",
		"receipt_provenance": {
			"schema_version": 1, "parent_receipt_id": "receipt-" + resolution_id,
			"child_kind": "day_resolution_stage", "ordinal": 0, "source_ids": [],
			"child_id": "start-child-1",
		},
		"resolution_id": resolution_id,
		"causal_day_instance": "causal-day-3",
		"source_day": 3,
		"registry_fingerprint": "fp-1",
		"schedule_commit_receipt_id": "commit-1",
		"board_fate_receipt_id": "board-1",
		"schedule_entry_ids": [],
	}


func _rooted_plan() -> Dictionary:
	return load(PLAN_PATH).create(
		ROOT_TOKEN, 3, _aggregate(3, []), [], "commit-1", "board-1",
		{
			"command_id": "done.day3",
			"resolution_issuer_receipt": _issuer_receipt(),
			"day_resolution_start_receipt": _start_receipt(),
		})


## Without a minted root the plan still records WHICH command began it: on the unconfigured
## board-fate path the command id and the resolution id are simply the same string.
func test_an_unrooted_plan_records_its_command_and_null_receipts() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = load(PLAN_PATH).create(
		"resolution-unrooted", 3, _aggregate(3, []), [], null, null)
	assert_true(created.get("ok", false), JSON.stringify(created))
	if not created.get("ok", false):
		return
	var data: Dictionary = (created["value"]["plan"] as RefCounted).to_dict()
	assert_eq(str(data["command_id"]), "resolution-unrooted",
		"the command id defaults to the resolution id when no root was minted")
	assert_eq(data["resolution_issuer_receipt"], null, "no root was minted")
	assert_eq(data["day_resolution_start_receipt"], null, "so no start receipt exists either")


func test_a_rooted_plan_persists_its_root_and_start_receipt_losslessly() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = _rooted_plan()
	assert_true(created.get("ok", false), JSON.stringify(created))
	if not created.get("ok", false):
		return
	var plan: RefCounted = created["value"]["plan"]
	var data: Dictionary = plan.to_dict()
	assert_eq(str(data["command_id"]), "done.day3", "the Done command that began this resolution")
	assert_eq(data["resolution_issuer_receipt"], _issuer_receipt(), "the FULL root receipt, not its id")
	assert_eq(data["day_resolution_start_receipt"], _start_receipt(), "the full start receipt")
	assert_eq(str(data["resolution_id"]), ROOT_TOKEN, "the resolution id IS the minted root token")

	var restored: Dictionary = load(PLAN_PATH).from_dict(data.duplicate(true))
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	if not restored.get("ok", false):
		return
	assert_eq((restored["value"]["plan"] as RefCounted).to_dict(), data,
		"a rooted plan round trips byte-identically, so a restore derives the SAME children")
	assert_eq(plan.get_resolution_issuer_receipt(), _issuer_receipt(),
		"the accessor hands back a detached copy of the root")
	assert_eq(plan.get_day_resolution_start_receipt(), _start_receipt(),
		"and of the start receipt")
	assert_eq(plan.get_command_id(), "done.day3", "and of the command id")


## The two new members are proven AGAINST EACH OTHER on load, not merely type-checked. A tampered
## snapshot that keeps a root but swaps the token, drops the start receipt, or re-points the start
## at another resolution would otherwise restore a plan whose presentation children cannot be
## reproduced.
func test_a_restored_root_is_re_proven_against_its_resolution() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = _rooted_plan()
	assert_true(created.get("ok", false))
	if not created.get("ok", false):
		return
	var plan_script: Script = load(PLAN_PATH)
	var data: Dictionary = (created["value"]["plan"] as RefCounted).to_dict()

	var wrong_token: Dictionary = data.duplicate(true)
	(wrong_token["resolution_issuer_receipt"] as Dictionary)["token"] = "tok-other"
	assert_false(plan_script.from_dict(wrong_token).get("ok", true),
		"a root whose token is not the resolution id rejects")

	var wrong_purpose: Dictionary = data.duplicate(true)
	(wrong_purpose["resolution_issuer_receipt"] as Dictionary)["purpose"] = "causal_day_instance"
	assert_false(plan_script.from_dict(wrong_purpose).get("ok", true),
		"a root minted for another purpose rejects")

	var dropped_start: Dictionary = data.duplicate(true)
	dropped_start["day_resolution_start_receipt"] = null
	assert_false(plan_script.from_dict(dropped_start).get("ok", true),
		"a rooted plan without its start receipt rejects")

	var orphan_start: Dictionary = data.duplicate(true)
	orphan_start["resolution_issuer_receipt"] = null
	assert_false(plan_script.from_dict(orphan_start).get("ok", true),
		"a start receipt without the root it was derived under rejects")

	var foreign_start: Dictionary = data.duplicate(true)
	(foreign_start["day_resolution_start_receipt"] as Dictionary)["resolution_id"] = "tok-other"
	assert_false(plan_script.from_dict(foreign_start).get("ok", true),
		"a start receipt naming another resolution rejects")

	var idless_start: Dictionary = data.duplicate(true)
	(idless_start["day_resolution_start_receipt"] as Dictionary)["receipt_id"] = ""
	assert_false(plan_script.from_dict(idless_start).get("ok", true),
		"a start receipt with no id rejects: the intent projects exactly that id")

	var blank_command: Dictionary = data.duplicate(true)
	blank_command["command_id"] = ""
	assert_false(plan_script.from_dict(blank_command).get("ok", true), "a blank command id rejects")

	var missing_member: Dictionary = data.duplicate(true)
	missing_member.erase("command_id")
	assert_false(plan_script.from_dict(missing_member).get("ok", true),
		"PLAN_KEYS stays an EXACT member set")


## THE ANCESTRY EDGE ITSELF, which the checks above do not reach (dwm-p2r.18 review, Finding 3a).
##
## `receipt_provenance` was only type-checked. Full provenance sitting BESIDE a root proves nothing
## until it is tied to THAT root: a tampered snapshot could pair a genuine root R with a start
## receipt derived under a DIFFERENT root, so long as the start receipt still named this resolution.
## The producer would then anchor every presentation child under R while projecting
## `day_resolution_start_receipt_id` from the foreign receipt, and the forged chain would reproduce
## byte-identically on every later load -- which is exactly what makes it undetectable downstream.
func test_a_restored_start_receipt_must_descend_from_the_persisted_root() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = _rooted_plan()
	assert_true(created.get("ok", false))
	if not created.get("ok", false):
		return
	var plan_script: Script = load(PLAN_PATH)
	var data: Dictionary = (created["value"]["plan"] as RefCounted).to_dict()

	var foreign_parent: Dictionary = data.duplicate(true)
	_start_provenance(foreign_parent)["parent_receipt_id"] = "receipt-tok-other"
	assert_false(plan_script.from_dict(foreign_parent).get("ok", true),
		"a start receipt derived under ANOTHER root rejects, even while it names this resolution")

	var rootless_parent: Dictionary = data.duplicate(true)
	_start_provenance(rootless_parent)["parent_receipt_id"] = ""
	assert_false(plan_script.from_dict(rootless_parent).get("ok", true),
		"and so does provenance naming no parent at all")

	var swapped_child: Dictionary = data.duplicate(true)
	(swapped_child["day_resolution_start_receipt"] as Dictionary)["receipt_id"] = "start-child-2"
	assert_false(plan_script.from_dict(swapped_child).get("ok", true),
		"a receipt id that is not the child its OWN provenance names rejects: the intent projects "
			+ "exactly that id, so the swap would fork the chain")

	assert_true(plan_script.from_dict(data.duplicate(true)).get("ok", false),
		"and the honest pair still restores")


## The one member of the start receipt the walk indexes RAW (dwm-p2r.18 review, Finding 3b).
##
## `GameStateDayResolutionPort._presentation_command` and `_derive_hospital_rows` both do
## `str(start["causal_day_instance"])` with no guard. It was never required here, so a restored plan
## missing it passed validation and then CRASHED the walk rather than failing closed at the
## boundary. A non-String is refused for the same reason `str()` would hide it: coercion changes the
## projected bytes without changing the shape.
func test_a_restored_start_receipt_must_carry_the_causal_day_the_walk_indexes() -> void:
	assert_true(_plan_exists(), "DayResolutionPlan must exist")
	if not _plan_exists():
		return
	var created: Dictionary = _rooted_plan()
	assert_true(created.get("ok", false))
	if not created.get("ok", false):
		return
	var plan_script: Script = load(PLAN_PATH)
	var data: Dictionary = (created["value"]["plan"] as RefCounted).to_dict()

	var missing_day: Dictionary = data.duplicate(true)
	(missing_day["day_resolution_start_receipt"] as Dictionary).erase("causal_day_instance")
	assert_false(plan_script.from_dict(missing_day).get("ok", true),
		"a start receipt with no causal_day_instance rejects rather than crashing the walk later")

	var blank_day: Dictionary = data.duplicate(true)
	(blank_day["day_resolution_start_receipt"] as Dictionary)["causal_day_instance"] = ""
	assert_false(plan_script.from_dict(blank_day).get("ok", true),
		"a blank causal day rejects: the intent projects it as a load-bearing member")

	var coerced_day: Dictionary = data.duplicate(true)
	(coerced_day["day_resolution_start_receipt"] as Dictionary)["causal_day_instance"] = 3
	assert_false(plan_script.from_dict(coerced_day).get("ok", true),
		"and so does a non-String the projection would silently coerce")


## The provenance record inside a snapshot copy, so the mutations above read as one fact each.
func _start_provenance(plan_data: Dictionary) -> Dictionary:
	return ((plan_data["day_resolution_start_receipt"] as Dictionary)["receipt_provenance"]
		as Dictionary)
