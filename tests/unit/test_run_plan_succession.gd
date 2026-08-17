extends "res://addons/gut/test.gd"
# Safe plan succession (dwm-7e6 erratum, plan-author ruling).
#
# RunLifecycle never retired a finished day-resolution plan, so Day 2 hit resolution_conflict and a
# run could never advance past its first resolution. The rule is succession, NOT retirement: the
# completed plan stays live (the coordinator immediately calls resume_resolution() to observe
# plan_complete, and stage receipts exist only inside active_resolution_plan) and is replaced
# atomically only by a VALID new plan.

const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const DAY_RESOLUTION_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")


## Minimal owner exposing exactly what the port reads, so production receipts can be generated
## around a bare lifecycle without standing up the whole GameState autoload.
class _StubOwner extends RefCounted:
	var _run_lifecycle: RefCounted
	var route_context: Dictionary = {"ending_id": "ending.alone"}
	func _init(lifecycle: RefCounted) -> void:
		_run_lifecycle = lifecycle


func _lifecycle() -> RefCounted:
	var lifecycle: RefCounted = RUN_LIFECYCLE.new()
	lifecycle.reset("run-succession")
	return lifecycle


## Drives every stage of the current plan to completion using the plan's own receipts.
func _complete_current_plan(lifecycle: RefCounted) -> void:
	# Bounded: a stage that fails to advance must end the walk, never spin.
	for _iteration in range(64):
		var cursor: Dictionary = lifecycle.resume_resolution()
		if not cursor.get("ok", false) or not cursor["value"]["has_stage"]:
			return
		var begun: Dictionary = lifecycle.begin_next_stage()
		if not begun.get("ok", false):
			return
		var stage: Dictionary = begun["value"]["stage"]
		# Reuse PRODUCTION receipt generation so the walk exercises the real owner-receipt contract
		# rather than hand-rolled shapes that could drift from it.
		var port: Object = DAY_RESOLUTION_PORT.new(_StubOwner.new(lifecycle))
		var envelope: Dictionary = port._immediate_receipt(str(stage.get("stage_id", "")))
		var receipt: Dictionary = DAY_RESOLUTION_PORT._plan_receipt_from_envelope(envelope)
		var completed: Dictionary = lifecycle.complete_active_stage(str(stage["transaction_id"]), receipt)
		if not completed.get("ok", false):
			return


func test_same_id_replay_is_idempotent_after_completion() -> void:
	var lifecycle := _lifecycle()
	assert_true(lifecycle.begin_day_resolution("res:day-1", {"entries": []}).get("ok", false), "day 1 begins")
	_complete_current_plan(lifecycle)
	var replay: Dictionary = lifecycle.begin_day_resolution("res:day-1", {"entries": []})
	assert_true(replay.get("ok", false), "repeating the same Done command stays idempotent after completion")
	assert_eq(str(replay["value"]["plan"]["resolution_id"]), "res:day-1", "it returns the same plan")


func test_incomplete_different_id_still_conflicts() -> void:
	var lifecycle := _lifecycle()
	lifecycle.begin_day_resolution("res:day-1", {"entries": []})
	lifecycle.begin_next_stage()
	var conflicting: Dictionary = lifecycle.begin_day_resolution("res:day-2", {"entries": []})
	assert_false(conflicting.get("ok", false), "a genuinely concurrent incomplete resolution must conflict")
	assert_eq(str(conflicting.get("code")), "resolution_conflict")


func test_day_one_to_day_two_succession() -> void:
	var lifecycle := _lifecycle()
	lifecycle.begin_day_resolution("res:day-1", {"entries": []})
	_complete_current_plan(lifecycle)
	assert_eq(lifecycle.get_day(), 2, "day 1 resolved and incremented")
	var day_two: Dictionary = lifecycle.begin_day_resolution("res:day-2", {"entries": []})
	assert_true(day_two.get("ok", false), "a valid Day-2 command replaces the completed Day-1 plan: " + str(day_two))
	assert_eq(str(day_two["value"]["plan"]["resolution_id"]), "res:day-2", "the new plan is live")
	assert_eq(int(day_two["value"]["plan"]["source_day"]), 2, "sourced from the current day")


func test_failed_replacement_preserves_the_completed_plan() -> void:
	var lifecycle := _lifecycle()
	lifecycle.begin_day_resolution("res:day-1", {"entries": []})
	_complete_current_plan(lifecycle)
	# An invalid new plan (empty resolution id) must not destroy the completed Day-1 receipts.
	var invalid: Dictionary = lifecycle.begin_day_resolution("", {"entries": []})
	assert_false(invalid.get("ok", false), "an invalid replacement rejects")
	var snapshot: Dictionary = lifecycle.to_dict()
	assert_true(snapshot["active_resolution_plan"] != null, "the completed plan survives a failed replacement")
	assert_eq(str(snapshot["active_resolution_plan"]["resolution_id"]), "res:day-1", "and it is still Day 1's")


func test_completed_plan_remains_observable_as_plan_complete() -> void:
	# The coordinator calls resume_resolution() right after completion; clearing the plan would
	# return no_active_plan instead of the plan_complete it expects.
	var lifecycle := _lifecycle()
	lifecycle.begin_day_resolution("res:day-1", {"entries": []})
	_complete_current_plan(lifecycle)
	var cursor: Dictionary = lifecycle.resume_resolution()
	assert_true(cursor.get("ok", false), "resume_resolution still succeeds after completion")
	assert_false(bool(cursor["value"]["has_stage"]), "and reports no incomplete stage")


func test_restore_a_completed_plan_then_succeed_it() -> void:
	var lifecycle := _lifecycle()
	lifecycle.begin_day_resolution("res:day-1", {"entries": []})
	_complete_current_plan(lifecycle)
	var persisted: Dictionary = lifecycle.to_dict()
	var restored: RefCounted = RUN_LIFECYCLE.new()
	var prepared: Dictionary = restored.prepare_restore(persisted)
	assert_true(prepared.get("ok", false), "a completed plan round-trips: " + str(prepared))
	assert_true(restored.commit_restore(prepared["value"]["candidate"]).get("ok", false), "commit_restore accepts it")
	var next_day: Dictionary = restored.begin_day_resolution("res:day-2", {"entries": []})
	assert_true(next_day.get("ok", false), "a restored completed plan can still be succeeded: " + str(next_day))
