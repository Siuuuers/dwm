extends "res://addons/gut/test.gd"

const PLAN := preload("res://scripts/domain/run/ConditionHospitalPlan.gd")
const RECEIPT_ID := "condition_hospital_resolution.fixture-1"
const TX_ID := "transaction.condition-1"
const CAUSAL_DAY := "causal-day-3"

func _issuer(token: String, purpose: String = "causal_day_instance") -> Dictionary:
	return {"receipt_id": "issuer." + token, "purpose": purpose, "namespace": "fixture",
		"counter": 1, "token": token, "numeric_value": null}

func _stages() -> Array:
	var result: Array = []
	for stage_id: String in PLAN.STAGE_IDS:
		result.append({"prepared": null, "receipt": null, "stage_id": stage_id,
			"stage_identity": null, "stage_key": RECEIPT_ID + ":" + stage_id,
			"state": "pending"})
	return result

func _plan() -> Dictionary:
	var sources := [{"action_id": "invite:lavinia:day3", "receipt_id": "source.a"}]
	return {
		"accepted_sources": sources.duplicate(true),
		"action_receipt": {"receipt_id": "action.1"},
		"branch_id": "branch-1",
		"causal_day_instance": CAUSAL_DAY,
		"causal_day_instance_issuer_receipt": _issuer(CAUSAL_DAY),
		"condition_receipt": {"receipt_id": "condition.1"},
		"cursor": 0,
		"desktop_timeline_generation": 0,
		"destination_record": {"status": "pending", "payload": {
			"kind": "hospital_day", "accepted_unfulfilled_sources": sources.duplicate(true)}},
		"resolution_kind": "condition_hospital",
		"resolution_receipt": {"receipt_id": RECEIPT_ID},
		"run_id": "run-1",
		"schema_version": 1,
		"source_day": 3,
		"stages": _stages(),
		"transaction_id": TX_ID,
		"transaction_issuer_receipt": _issuer(TX_ID, "transaction_id"),
	}

func test_cursor_zero_plan_validates_without_mutating_source() -> void:
	var source := _plan()
	var before := source.duplicate(true)
	var validated: Dictionary = PLAN.validate(source)
	assert_true(validated.get("ok", false), str(validated))
	assert_eq(source, before, "validation is pure")

func test_plan_rejects_day7_and_mutated_stage_order() -> void:
	var day7 := _plan()
	day7.source_day = 7
	assert_false(PLAN.validate(day7).get("ok", true))
	var reordered := _plan()
	var first: Dictionary = reordered.stages[0]
	reordered.stages[0] = reordered.stages[1]
	reordered.stages[1] = first
	assert_false(PLAN.validate(reordered).get("ok", true))
