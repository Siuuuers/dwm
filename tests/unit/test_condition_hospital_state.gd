extends "res://addons/gut/test.gd"

const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const HOSPITAL := preload("res://scripts/domain/run/ConditionHospitalState.gd")

class FakeIdentityPort extends RefCounted:
	func derive_child(request: Dictionary) -> Dictionary:
		var child_id := "condition_hospital_resolution.fixture-1"
		var provenance := {"schema_version": 1, "parent_receipt_id": request.parent_receipt_id,
			"child_kind": request.child_kind, "ordinal": request.ordinal,
			"source_ids": request.source_ids.duplicate(true), "child_id": child_id}
		return {"ok": true, "code": &"ok", "value": {"child_id": child_id,
			"provenance": provenance}, "receipt": provenance.duplicate(true)}

	func validate_child(_provenance: Dictionary, _kind: StringName) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

	func verify_issued(_receipt: Dictionary, _purpose: StringName) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

func _issuer(token: String, purpose: String = "causal_day_instance") -> Dictionary:
	return {"receipt_id": "issuer." + token, "purpose": purpose, "namespace": "fixture",
		"counter": 1, "token": token, "numeric_value": null}

func _request() -> Dictionary:
	var sources := [{"action_id": "invite:lavinia:day3", "receipt_id": "source.a"}]
	return {
		"action_receipt": {"receipt_id": "action.1", "transaction_id": "transaction.condition-1",
			"transaction_issuer_receipt": _issuer("transaction.condition-1", "transaction_id")},
		"condition_receipt": {"receipt_id": "condition.1"},
		"destination_record": {"key": "transaction.condition-1@destination",
			"status": "pending", "payload": {"kind": "hospital_day",
				"accepted_unfulfilled_sources": sources}},
	}

func test_accept_and_commit_preserve_captured_dark() -> void:
	var lifecycle := LIFECYCLE.new()
	lifecycle.reset("run-1", "branch-1", 0, "causal-day-3",
		{"causal_day_instance_issuer_receipt": _issuer("causal-day-3")}, true)
	var hospital := HOSPITAL.new()
	assert_true(hospital.configure(lifecycle, FakeIdentityPort.new()).get("ok", false))
	var prepared: Dictionary = hospital.prepare_accept(_request())
	assert_true(prepared.get("ok", false), str(prepared))
	var candidate: Dictionary = prepared.value.condition_hospital_candidate
	assert_true(candidate.lifecycle_candidate.dark_mode)
	assert_true(hospital.commit(candidate).get("ok", false))
	assert_true(lifecycle.to_dict().dark_mode)
	assert_eq(typeof(lifecycle.to_dict().active_condition_hospital_plan), TYPE_DICTIONARY)

func test_configure_is_idempotent_for_same_owners_and_rejects_rebinding() -> void:
	var lifecycle := LIFECYCLE.new()
	var port := FakeIdentityPort.new()
	var hospital := HOSPITAL.new()
	assert_true(hospital.configure(lifecycle, port).get("ok", false))
	assert_true(hospital.configure(lifecycle, port).get("ok", false))
	assert_false(hospital.configure(LIFECYCLE.new(), port).get("ok", true))


class PriorResolutionLifecycle extends RefCounted:
	var value: Dictionary
	func get_state() -> String: return str(value.state)
	func get_day() -> int: return int(value.day)
	func to_dict() -> Dictionary: return value.duplicate(true)
	func prepare_restore(candidate: Dictionary) -> Dictionary:
		return preload("res://scripts/domain/run/RunLifecycle.gd").new().prepare_restore(candidate)
	func commit_restore(candidate: Dictionary) -> Dictionary:
		value = candidate.duplicate(true)
		return {"ok": true}

func _prior_resolution_owner(stage_state: String, substage_state: String) -> RefCounted:
	var source := LIFECYCLE.new()
	source.reset("run-1", "branch-1", 0, "causal-day-3",
		{"causal_day_instance_issuer_receipt": _issuer("causal-day-3")}, false)
	var owner := PriorResolutionLifecycle.new()
	owner.value = source.to_dict()
	# The facade supplies a retained plan projection; RunLifecycle validates the resulting
	# detached candidate after the completed projection has been removed.
	owner.value["active_resolution_plan"] = {"source_day": 1,
		"stages": [{"state": stage_state, "substages": [{"state": substage_state}]}]}
	return owner

func test_completed_prior_done_plan_is_replaced_only_in_acceptance_candidate() -> void:
	var owner := _prior_resolution_owner("completed", "completed")
	var before: Dictionary = owner.to_dict()
	var hospital := HOSPITAL.new()
	assert_true(hospital.configure(owner, FakeIdentityPort.new()).get("ok", false))
	var prepared: Dictionary = hospital.prepare_accept(_request())
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(owner.to_dict(), before, "preparing Hospital never clears the live prior plan")
	assert_null(prepared.value.condition_hospital_candidate.lifecycle_candidate.active_resolution_plan)
	assert_not_null(prepared.value.condition_hospital_candidate.lifecycle_candidate.active_condition_hospital_plan)

func test_incomplete_prior_stage_or_substage_still_blocks_hospital() -> void:
	for states: Array in [["active", "completed"], ["completed", "active"], ["completed", "pending"]]:
		var owner := _prior_resolution_owner(states[0], states[1])
		var hospital := HOSPITAL.new()
		assert_true(hospital.configure(owner, FakeIdentityPort.new()).get("ok", false))
		var prepared: Dictionary = hospital.prepare_accept(_request())
		assert_false(prepared.get("ok", true))
		assert_eq(prepared.get("code"), &"resolution_conflict")