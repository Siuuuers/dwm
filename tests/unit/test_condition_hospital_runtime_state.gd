extends "res://addons/gut/test.gd"

const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const HOSPITAL := preload("res://scripts/domain/run/ConditionHospitalState.gd")
const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")


class IdentityPort extends RefCounted:
	func derive_child(request: Dictionary) -> Dictionary:
		var child_id := "%s.%d" % [str(request["child_kind"]), int(request["ordinal"])]
		var provenance := {
			"schema_version": 1,
			"parent_receipt_id": str(request["parent_receipt_id"]),
			"child_kind": str(request["child_kind"]),
			"ordinal": int(request["ordinal"]),
			"source_ids": (request["source_ids"] as Array).duplicate(true),
			"child_id": child_id,
		}
		return {"ok": true, "code": &"ok", "value": {
			"child_id": child_id, "provenance": provenance,
		}, "receipt": provenance.duplicate(true)}


func _issuer(token: String, purpose: String = "causal_day_instance") -> Dictionary:
	return {"receipt_id": "issuer." + token, "purpose": purpose, "namespace": "fixture",
		"counter": 1, "token": token, "numeric_value": null}


func _new_state() -> RefCounted:
	var lifecycle := LIFECYCLE.new()
	lifecycle.reset("run-1", "branch-1", 0, "causal-day-3",
		{"causal_day_instance_issuer_receipt": _issuer("causal-day-3")}, false)
	var source: Dictionary = lifecycle.to_dict()
	source["day"] = 3
	assert_true(lifecycle.commit_restore(lifecycle.prepare_restore(source).value.candidate).get("ok", false))
	var state := HOSPITAL.new()
	assert_true(state.configure(lifecycle, IdentityPort.new()).get("ok", false))
	var sources := [{"action_id": "solo:lavinia:day3", "receipt_id": "source.1"}]
	var accepted: Dictionary = state.prepare_accept({
		"action_receipt": {"receipt_id": "action.1", "transaction_id": "action.tx",
			"transaction_issuer_receipt": _issuer("action.tx", "transaction_id")},
		"condition_receipt": {"receipt_id": "condition.1"},
		"destination_record": {"key": "destination.1", "status": "pending",
			"payload": {"kind": "hospital_day", "accepted_unfulfilled_sources": sources}},
	})
	assert_true(accepted.get("ok", false), JSON.stringify(accepted))
	assert_true(state.commit(accepted["value"]["condition_hospital_candidate"]).get("ok", false))
	return state


func _activate(state: RefCounted, stage_id: String, prepared: Dictionary) -> Dictionary:
	var live: Dictionary = state.capture()["value"]["backup"]
	var plan: Dictionary = live["active_condition_hospital_plan"]
	var resolution_id := str((plan["resolution_receipt"] as Dictionary)["receipt_id"])
	var identity_result: Dictionary = state.prepare_stage_identity({
		"resolution_receipt_id": resolution_id,
		"stage_id": stage_id,
		"input_receipt_ids": [],
	})
	assert_true(identity_result.get("ok", false), JSON.stringify(identity_result))
	var identity: Dictionary = identity_result["value"]["stage_identity"]
	var active: Dictionary = state.prepare_stage({
		"resolution_receipt_id": resolution_id,
		"stage_id": stage_id,
		"stage_identity": identity,
		"prepared": prepared,
	})
	assert_true(active.get("ok", false), JSON.stringify(active))
	assert_true(state.commit_stage(active["value"]).get("ok", false))
	return identity


func _complete(state: RefCounted, stage_id: String, identity: Dictionary,
		prepared: Dictionary, output: Dictionary) -> void:
	var live: Dictionary = state.capture()["value"]["backup"]
	var plan: Dictionary = live["active_condition_hospital_plan"]
	var resolution_id := str((plan["resolution_receipt"] as Dictionary)["receipt_id"])
	var index := ["close_invitation_sources", "present_hospital", "resolve_deferred_pair",
		"present_deferred_pair", "advance_day", "autosave_new_day"].find(stage_id)
	var receipt := {
		"input_receipt_ids": (identity["input_receipt_ids"] as Array).duplicate(true),
		"output": output.duplicate(true),
		"receipt_id": str(identity["child_id"]),
		"receipt_provenance": (identity["provenance"] as Dictionary).duplicate(true),
		"resolution_kind": "condition_hospital",
		"resolution_receipt_id": resolution_id,
		"stage_id": stage_id,
		"stage_index": index,
	}
	var completed: Dictionary = state.complete_stage({
		"resolution_receipt_id": resolution_id,
		"stage_id": stage_id,
		"stage_identity": identity,
		"prepared": prepared,
		"stage_receipt": receipt,
	})
	assert_true(completed.get("ok", false), JSON.stringify(completed))
	assert_true(state.commit_stage(completed["value"]).get("ok", false))


func test_capture_active_stage_attests_only_persisted_identity_and_prepared_bytes() -> void:
	var state := _new_state()
	var prepared := {"kind": "close_invitation_sources", "owner_candidate": {"contacts": {}}}
	var identity := _activate(state, "close_invitation_sources", prepared)
	var captured: Dictionary = state.capture_active_stage()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	var attestation: Dictionary = captured["value"]["active_stage_attestation"]
	assert_eq(attestation["stage_id"], "close_invitation_sources")
	assert_eq(attestation["stage_identity"], identity)
	var emitted: Dictionary = CANONICAL_JSON.stringify(prepared)
	assert_eq(attestation["prepared_sha256"], str(emitted["value"]).sha256_text())
	assert_eq(attestation.keys().size(), 4)


func test_autosave_output_is_projected_from_completed_advance_stage() -> void:
	var state := _new_state()
	var ordinary := ["close_invitation_sources", "present_hospital",
		"resolve_deferred_pair", "present_deferred_pair"]
	for stage_id: String in ordinary:
		var prepared := {"kind": stage_id}
		var identity := _activate(state, stage_id, prepared)
		_complete(state, stage_id, identity, prepared, {})
	var target_receipt := _issuer("causal-day-4")
	var advance_prepared := {"kind": "advance_day", "target_day": 4,
		"target_causal_day_instance": "causal-day-4",
		"target_causal_day_instance_issuer_receipt": target_receipt}
	var advance_identity := _activate(state, "advance_day", advance_prepared)
	_complete(state, "advance_day", advance_identity, advance_prepared, {
		"target_day": 4, "target_causal_day_instance": "causal-day-4",
		"target_causal_day_instance_issuer_receipt": target_receipt})
	var autosave_prepared := {"kind": "autosave_new_day"}
	var autosave_identity := _activate(state, "autosave_new_day", autosave_prepared)
	var live: Dictionary = state.capture()["value"]["backup"]
	var plan: Dictionary = live["active_condition_hospital_plan"]
	var output: Dictionary = state.prepare_autosave_stage_output({
		"resolution_receipt_id": str(plan["resolution_receipt"]["receipt_id"]),
		"stage_identity": autosave_identity,
		"checkpoint_id": "run-1:42",
	})
	assert_true(output.get("ok", false), JSON.stringify(output))
	assert_eq(output["value"]["stage_output"], {
		"checkpoint_id": "run-1:42", "day": 4,
		"target_causal_day_instance": "causal-day-4",
	})
