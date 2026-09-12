extends "res://addons/gut/test.gd"
# RunLifecycle's reversible active-plan seams (Plan 01 Task 6 Step 6.5, dwm-p2r.13).
#
# WHAT THESE SEAMS ARE FOR. A reversible day-resolution start port must be able to prepare a
# resolution, let other participants fail, and leave the lifecycle exactly as it found it. That
# needs two properties, and neither is obvious from reading the happy path:
#   * prepare_day_resolution() must be PURE on EVERY path -- not just the success path, but the
#     idempotent-replay and conflict paths too. A prepare that quietly installed a plan before the
#     caller decided to proceed would make "prepare" a lie.
#   * capture/rollback must be NARROW. Rolling back through to_dict()/commit_restore() would also
#     restore run_id, day, state and the ending plan, so a failed day-resolution participant could
#     silently undo an unrelated concurrent change. That is the bug this file exists to prevent, and
#     it is asserted directly below by mutating the day between capture and rollback.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")

const EMPTY_AGGREGATE := {
	"schema_version": 1, "day": 1, "registry_fingerprint": null,
	"entries": [], "commit_receipt": null,
}


## Plan 02 Task 6 (dwm-p2r.32): branch_id/desktop_timeline_generation/causal_day_instance/receipt
## arrive already allocated in production; this test supplies a self-consistent placeholder.
func _lifecycle() -> RefCounted:
	var lifecycle: RefCounted = LIFECYCLE.new()
	var receipt := {"receipt_id": "issuer_receipt.fixture-causal-day-seams", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-seams", "numeric_value": null}
	lifecycle.reset("run-seams", "branch-seams", 0, "causal-day-seams",
		{"causal_day_instance_issuer_receipt": receipt}, false)
	return lifecycle


func _aggregate(day: int) -> Dictionary:
	var aggregate: Dictionary = EMPTY_AGGREGATE.duplicate(true)
	aggregate["day"] = day
	return aggregate


# ---- purity ----

func test_prepare_produces_a_candidate_without_installing_it() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var prepared: Dictionary = lifecycle.prepare_day_resolution("res:1", _aggregate(1))
	assert_true(prepared.get("ok", false),
		"prepare must succeed: %s" % str(prepared.get("code", &"")))
	var value: Dictionary = prepared.get("value", {}) as Dictionary
	assert_false(value.get("already_active", true), "a first preparation is genuinely new")
	assert_false((value.get("candidate", {}) as Dictionary).is_empty(), "a candidate is produced")
	assert_null(lifecycle.to_dict()["active_resolution_plan"],
		"prepare must NOT install the plan it produced")
	assert_false(lifecycle.resume_resolution().get("ok", true),
		"with nothing installed there is still no active plan to resume")


func test_prepare_is_pure_on_the_conflict_path_too() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).get("ok", false))
	var before: Variant = lifecycle.to_dict()["active_resolution_plan"]
	var conflicting: Dictionary = lifecycle.prepare_day_resolution("res:2", _aggregate(1))
	assert_false(conflicting.get("ok", true), "a different incomplete resolution conflicts")
	assert_eq(str(conflicting.get("code", &"")), "resolution_conflict", "the exact code")
	assert_eq(lifecycle.to_dict()["active_resolution_plan"], before,
		"a rejected preparation must leave the installed plan byte-identical")


func test_prepare_replaying_the_same_resolution_returns_the_existing_plan_and_says_so() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).get("ok", false))
	var installed: Variant = lifecycle.to_dict()["active_resolution_plan"]
	var replay: Dictionary = lifecycle.prepare_day_resolution("res:1", _aggregate(1))
	assert_true(replay.get("ok", false), "the same resolution replays idempotently")
	var value: Dictionary = replay.get("value", {}) as Dictionary
	assert_true(value.get("already_active", false),
		"already_active must tell the caller committing this is a no-op")
	assert_eq(value.get("candidate"), installed,
		"the candidate IS the existing plan, not a freshly built twin")


# ---- commit ----

func test_a_prepared_candidate_commits_and_becomes_the_active_plan() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var prepared: Dictionary = lifecycle.prepare_day_resolution("res:1", _aggregate(1))
	var candidate: Dictionary = (prepared.get("value", {}) as Dictionary).get("candidate", {}) as Dictionary
	var committed: Dictionary = lifecycle.commit_active_plan(candidate)
	assert_true(committed.get("ok", false),
		"the candidate must commit: %s" % str(committed.get("code", &"")))
	assert_eq(lifecycle.to_dict()["active_resolution_plan"], candidate,
		"the installed plan is exactly what was prepared")


func test_commit_refuses_a_malformed_candidate_and_changes_nothing() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var refused: Dictionary = lifecycle.commit_active_plan({"resolution_id": "res:1"})
	assert_false(refused.get("ok", true), "a malformed candidate is refused")
	assert_null(lifecycle.to_dict()["active_resolution_plan"],
		"a refused commit installs nothing")


# ---- narrowness: the property that makes rollback safe ----

func test_capture_and_rollback_touch_only_the_active_plan() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).get("ok", false))
	var backup: Dictionary = (lifecycle.capture_active_plan().get("value", {}) as Dictionary)
	assert_true(backup.has("active_resolution_plan"), "capture names exactly one field")
	assert_eq(backup.size(), 1,
		"capture must be NARROW -- capturing day or state would let rollback undo them")

	# An unrelated concurrent change: the run advances a day while the resolution is in flight.
	_advance_one_day(lifecycle)
	var day_after_advance: int = int(lifecycle.to_dict()["day"])
	assert_eq(day_after_advance, 2, "the run genuinely advanced")

	var rolled: Dictionary = lifecycle.rollback_active_plan(backup)
	assert_true(rolled.get("ok", false),
		"rollback must succeed: %s" % str(rolled.get("code", &"")))
	assert_eq(int(lifecycle.to_dict()["day"]), day_after_advance,
		"rollback must NOT rewind the day it never captured")
	assert_eq(str(lifecycle.to_dict()["state"]), "PLAYING", "rollback must not touch state")


func test_rollback_restores_a_null_active_plan_for_the_first_resolution_of_a_run() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var backup: Dictionary = (lifecycle.capture_active_plan().get("value", {}) as Dictionary)
	assert_null(backup["active_resolution_plan"], "nothing is active yet")
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).get("ok", false))
	assert_not_null(lifecycle.to_dict()["active_resolution_plan"], "a plan is now installed")
	var rolled: Dictionary = lifecycle.rollback_active_plan(backup)
	assert_true(rolled.get("ok", false), "a null backup is a legal restore target")
	assert_null(lifecycle.to_dict()["active_resolution_plan"],
		"rolling back the FIRST resolution must leave no plan at all")


func test_rollback_refuses_a_backup_it_did_not_produce() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_false(lifecycle.rollback_active_plan({}).get("ok", true),
		"an empty backup is refused rather than read as null")
	assert_false(lifecycle.rollback_active_plan({"active_resolution_plan": 7}).get("ok", true),
		"a non-object active plan is refused")
	assert_false(
		lifecycle.rollback_active_plan({"active_resolution_plan": {"resolution_id": "x"}}).get("ok", true),
		"a malformed plan body is refused rather than installed")


# Drives the real increment_day stage so the day advances through production law rather than by
# poking private state.
func _advance_one_day(lifecycle: RefCounted) -> void:
	for _index: int in range(20):
		var cursor: Dictionary = lifecycle.resume_resolution()
		if not cursor.get("ok", false):
			return
		if not (cursor.get("value", {}) as Dictionary).get("has_stage", false):
			return
		# The cursor, not begin_next_stage()'s envelope, is the documented source of the record:
		# RunLifecycle.begin_next_stage() itself reads cursor.value.stage to decide what to begin.
		var record: Dictionary = (cursor.get("value", {}) as Dictionary).get("stage", {}) as Dictionary
		var transaction_id: String = str(record.get("transaction_id", ""))
		var stage_id: String = str(record.get("stage_id", ""))
		if not lifecycle.begin_next_stage().get("ok", false):
			return
		var receipt: Dictionary = {"value": {}}
		match stage_id:
			"increment_day":
				receipt = {"value": {"day": int(lifecycle.to_dict()["day"]) + 1}}
			"invitation_rollover":
				receipt = {"value": {"target_day": int(lifecycle.to_dict()["day"]) + 1}}
		lifecycle.complete_active_stage(transaction_id, receipt)
		if stage_id == "increment_day":
			return
