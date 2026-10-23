extends "res://addons/gut/test.gd"

const COORDINATOR := preload("res://scripts/application/run/ConditionHospitalCoordinator.gd")
const RUNTIME_PORT := preload("res://scripts/application/run/GameStateConditionHospitalPort.gd")


class Capability extends RefCounted:
	func capture() -> Dictionary: return {"ok": true, "value": {"backup": {}}}
	func prepare_accept(_request: Dictionary) -> Dictionary: return {"ok": false}
	func commit(_candidate: Dictionary) -> Dictionary: return {"ok": true}
	func prepare_stage_identity(_request: Dictionary) -> Dictionary: return {"ok": true}
	func prepare_stage(_request: Dictionary) -> Dictionary: return {"ok": true}
	func complete_stage(_request: Dictionary) -> Dictionary: return {"ok": true}
	func commit_stage(_candidate: Dictionary) -> Dictionary: return {"ok": true}
	func prepare_retirement(_request: Dictionary) -> Dictionary: return {"ok": true}
	func commit_retirement(_candidate: Dictionary) -> Dictionary: return {"ok": true}
	func prepare_autosave_stage_output(_request: Dictionary) -> Dictionary: return {"ok": true}


class ConsequenceCapability extends RefCounted:
	func capture() -> Dictionary: return {"ok": true, "value": {"state": {"outbox": {}}}}
	func prepare_outbox_publication(_request: Dictionary) -> Dictionary: return {"ok": true}
	func commit(_candidate: Dictionary) -> Dictionary: return {"ok": true}


class AdapterCapability extends RefCounted:
	func prepare_stage(_plan: Dictionary, _stage_id: String) -> Dictionary: return {"ok": true}
	func execute_stage(_plan: Dictionary, _stage: Dictionary) -> Dictionary: return {"ok": true}
	func commit_stage(_stage_id: String, _candidate: Variant) -> Dictionary: return {"ok": true}
	func compose_checkpoint_inputs(_lifecycle: Dictionary, _owner_candidate: Variant,
			_consequence_candidate: Variant = null) -> Dictionary: return {"ok": true}


class CheckpointCapability extends RefCounted:
	func preview_checkpoint_id(_run_id: String) -> Dictionary: return {"ok": true}
	func prepare(_inputs: Dictionary, _kind: StringName, _write: Dictionary) -> Dictionary: return {"ok": true}
	func commit(_candidate: Dictionary) -> Dictionary: return {"ok": true}


class GateCapability extends RefCounted:
	func acquire(_owner: StringName) -> Dictionary: return {"ok": true, "value": {"token": "t"}}
	func release(_owner: StringName, _token: String) -> Dictionary: return {"ok": true}
	func is_active() -> bool: return false
	func get_active_owner() -> StringName: return &""
	func is_internal_owner_active(_owner: StringName) -> bool: return false
	func is_lease_active(_owner: StringName, _token: String) -> bool: return false


func test_coordinator_configuration_is_one_way_and_exact() -> void:
	var state := Capability.new()
	var consequence := ConsequenceCapability.new()
	var adapter := AdapterCapability.new()
	var checkpoint := CheckpointCapability.new()
	var gate := GateCapability.new()
	var coordinator := COORDINATOR.new()
	var configured: Dictionary = coordinator.configure(state, consequence, adapter, checkpoint, gate)
	assert_true(configured.get("ok", false), JSON.stringify(configured))
	assert_true(coordinator.configure(state, consequence, adapter, checkpoint, gate).get("ok", false))
	assert_false(coordinator.configure(state, consequence, AdapterCapability.new(), checkpoint, gate)
		.get("ok", true))


func test_runtime_adapter_rejects_incomplete_real_owner_graph() -> void:
	var result: Dictionary = RUNTIME_PORT.new().configure(
		RefCounted.new(), RefCounted.new(), RefCounted.new(), RefCounted.new(),
		RefCounted.new(), RefCounted.new(), Callable())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"invalid_game_state")


class PresentationState extends Capability:
	var lifecycle: Dictionary
	var captures := 0
	var commits := 0
	func _init() -> void:
		var stages: Array[Dictionary] = []
		var ids := ["close_invitation_sources", "present_hospital", "resolve_deferred_pair",
			"present_deferred_pair", "advance_day", "autosave_new_day"]
		for index: int in ids.size():
			stages.append({"stage_id": ids[index], "state": "completed" if index < 3 else ("active" if index == 3 else "pending"),
				"stage_identity": {"input_receipt_ids": ["input.receipt"], "child_id": "stage.%d" % index, "provenance": {}},
				"prepared": {"presentation_request": {"completion_transaction_id": "physical.pair"}}, "receipt": null})
		lifecycle = {"day": 2, "active_condition_hospital_plan": {"run_id": "run", "cursor": 3,
			"resolution_receipt": {"receipt_id": "hospital.resolution"}, "stages": stages}}
	func capture() -> Dictionary:
		captures += 1
		return {"ok": true, "value": {"backup": lifecycle.duplicate(true)}}
	func complete_stage(request: Dictionary) -> Dictionary:
		var after := lifecycle.duplicate(true)
		after["active_condition_hospital_plan"]["stages"][3]["state"] = "completed"
		after["active_condition_hospital_plan"]["stages"][3]["receipt"] = request.stage_receipt.duplicate(true)
		after["active_condition_hospital_plan"]["cursor"] = 4
		return {"ok": true, "value": {"lifecycle_candidate": after}}
	func commit_stage(candidate: Dictionary) -> Dictionary:
		lifecycle = candidate.lifecycle_candidate.duplicate(true)
		commits += 1
		return {"ok": true}

class PresentationAdapter extends AdapterCapability:
	var completed := false
	var executions := 0
	var commits := 0
	func execute_stage(_plan: Dictionary, _stage: Dictionary) -> Dictionary:
		executions += 1
		if not completed: return {"ok": true, "value": {"awaiting_presentation": true}}
		return {"ok": true, "value": {"output": {"presented": true,
			"presentation_completion_receipt": {"receipt_id": "physical.pair.complete"}}, "owner_candidate": null}}
	func compose_checkpoint_inputs(lifecycle: Dictionary, _owner_candidate: Variant,
			_consequence_candidate: Variant = null) -> Dictionary:
		return {"ok": true, "value": {"checkpoint_inputs": {"lifecycle": lifecycle.duplicate(true)}}}
	func commit_stage(_stage_id: String, _candidate: Variant) -> Dictionary:
		commits += 1
		return {"ok": true}

class PresentationCheckpoint extends CheckpointCapability:
	var fail_next := false
	var attempts := 0
	var commits := 0
	func prepare(inputs: Dictionary, _kind: StringName, _write: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"candidate": inputs.duplicate(true), "checkpoint_id": "run:42"}}
	func commit(_candidate: Dictionary) -> Dictionary:
		attempts += 1
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"injected_checkpoint_failure"}
		commits += 1
		return {"ok": true, "value": {"checkpoint_id": "run:42"}}

func _presentation_wired() -> Dictionary:
	var state := PresentationState.new()
	var adapter := PresentationAdapter.new()
	var checkpoint := PresentationCheckpoint.new()
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	var coordinator := COORDINATOR.new()
	assert_true(coordinator.configure(state, ConsequenceCapability.new(), adapter, checkpoint, gate).get("ok", false))
	return {"state": state, "adapter": adapter, "checkpoint": checkpoint, "gate": gate, "coordinator": coordinator}

func test_durable_presentation_wait_frees_gate_then_reacquires_for_completion() -> void:
	var wired := _presentation_wired()
	var before: Dictionary = wired.state.lifecycle.duplicate(true)
	var waiting: Dictionary = wired.coordinator.resume()
	assert_true(waiting.get("ok", false), str(waiting))
	assert_eq(waiting.get("value", {}).get("boundary"), "awaiting_presentation")
	assert_false(wired.gate.is_active(), "Dating can acquire its own causal action lease while visible")
	assert_eq(wired.coordinator.get("_gate_token"), "")
	assert_eq(wired.state.lifecycle, before, "the active durable stage remains the recovery owner")
	assert_eq(wired.checkpoint.attempts, 0, "waiting does not append another checkpoint")
	var action: Dictionary = wired.gate.acquire(&"causal_transaction")
	assert_true(action.get("ok", false), str(action))
	assert_eq(wired.coordinator.resume().get("code"), &"condition_hospital_transaction_blocked")
	assert_eq(wired.adapter.executions, 1, "Hospital cannot consume completion under Dating's lease")
	assert_true(wired.gate.release(&"causal_transaction", action.value.token).get("ok", false))
	wired.adapter.completed = true
	var completed: Dictionary = wired.coordinator.resume()
	assert_true(completed.get("ok", false), str(completed))
	assert_eq(completed.get("value", {}).get("boundary"), "stage_completed")
	assert_eq(wired.state.lifecycle.active_condition_hospital_plan.cursor, 4)
	assert_eq(wired.checkpoint.commits, 1)
	assert_eq(wired.state.commits, 1)
	assert_eq(wired.adapter.commits, 1)
	assert_true(wired.coordinator._release_gate().get("ok", false))

func test_foreign_causal_and_restore_leases_are_neither_borrowed_nor_released() -> void:
	for owner: StringName in [&"causal_transaction", &"restore"]:
		var wired := _presentation_wired()
		var foreign: Dictionary = wired.gate.acquire(owner)
		assert_true(foreign.get("ok", false))
		assert_eq(wired.coordinator.resume().get("code"), &"condition_hospital_transaction_blocked")
		assert_eq(wired.state.captures, 0, "refusal precedes all Hospital owner reads")
		assert_eq(wired.adapter.executions, 0)
		assert_false(wired.coordinator._release_gate().get("ok", true))
		assert_eq(wired.gate.get_active_owner(), owner)
		assert_true(wired.gate.release(owner, foreign.value.token).get("ok", false), "foreign token remains authoritative")

func test_failed_completion_checkpoint_keeps_owned_lease_and_retries_once() -> void:
	var wired := _presentation_wired()
	assert_true(wired.coordinator.resume().get("ok", false))
	assert_false(wired.gate.is_active())
	var before: Dictionary = wired.state.lifecycle.duplicate(true)
	wired.adapter.completed = true
	wired.checkpoint.fail_next = true
	assert_eq(wired.coordinator.resume().get("code"), &"injected_checkpoint_failure")
	assert_eq(wired.state.lifecycle, before)
	assert_eq(wired.state.commits, 0)
	assert_eq(wired.adapter.commits, 0)
	assert_true(wired.gate.is_internal_owner_active(&"causal_transaction"))
	var token: String = wired.coordinator.get("_gate_token")
	assert_false(token.is_empty())
	var retried: Dictionary = wired.coordinator.resume()
	assert_true(retried.get("ok", false), str(retried))
	assert_eq(wired.coordinator.get("_gate_token"), token, "checkpoint retry reuses our existing lease")
	assert_eq(wired.checkpoint.attempts, 2)
	assert_eq(wired.checkpoint.commits, 1)
	assert_eq(wired.state.commits, 1)
	assert_eq(wired.adapter.commits, 1)
	assert_true(wired.coordinator._release_gate().get("ok", false))
