class_name ConditionHospitalCoordinator
extends RefCounted

const PLAN := preload("res://scripts/domain/run/ConditionHospitalPlan.gd")

const _STATE_METHODS := ["capture", "prepare_accept", "commit", "prepare_stage_identity",
	"prepare_stage", "complete_stage", "commit_stage", "prepare_retirement",
	"commit_retirement", "prepare_autosave_stage_output"]
const _CONSEQUENCE_METHODS := ["capture", "prepare_outbox_publication", "commit"]
const _ADAPTER_METHODS := ["prepare_stage", "execute_stage", "commit_stage",
	"compose_checkpoint_inputs"]
const _CHECKPOINT_METHODS := ["preview_checkpoint_id", "prepare", "commit"]
const _GATE_METHODS := ["acquire", "release", "is_active", "get_active_owner",
	"is_internal_owner_active", "is_lease_active"]
const _OWNER := &"causal_transaction"

var _state: Object
var _consequence: Object
var _adapter: Object
var _checkpoint: Object
var _gate: Object
var _gate_token := ""


func configure(state_port: Object, consequence_state: Object, stage_adapter: Object,
		checkpoint_port: Object, mutation_gate: Object) -> Dictionary:
	if not _has(state_port, _STATE_METHODS): return _fail(&"invalid_state_port")
	if not _has(consequence_state, _CONSEQUENCE_METHODS): return _fail(&"invalid_consequence_state")
	if not _has(stage_adapter, _ADAPTER_METHODS): return _fail(&"invalid_stage_adapter")
	if not _has(checkpoint_port, _CHECKPOINT_METHODS): return _fail(&"invalid_checkpoint_port")
	if not _has(mutation_gate, _GATE_METHODS): return _fail(&"invalid_mutation_gate")
	if _state != null:
		if _state != state_port or _consequence != consequence_state or _adapter != stage_adapter \
				or _checkpoint != checkpoint_port or _gate != mutation_gate:
			return _fail(&"condition_hospital_coordinator_already_configured")
		return _ok({"already_configured": true})
	_state = state_port
	_consequence = consequence_state
	_adapter = stage_adapter
	_checkpoint = checkpoint_port
	_gate = mutation_gate
	return _ok({"already_configured": false})


## Advances one durable boundary: destination acceptance, pending->active, active->completed, or
## completed-plan retirement. Presentations pause with their active command persisted.
func resume() -> Dictionary:
	var ready := _ready()
	if not ready.get("ok", false): return ready
	var held := _ensure_gate()
	if not held.get("ok", false): return held
	var captured: Dictionary = _state.call(&"capture")
	if not captured.get("ok", false): return captured
	var lifecycle: Dictionary = (captured["value"] as Dictionary)["backup"]
	var active: Variant = lifecycle.get("active_condition_hospital_plan")
	if typeof(active) != TYPE_DICTIONARY:
		return _accept_destination_or_idle(lifecycle)
	var plan: Dictionary = active
	var cursor := int(plan["cursor"])
	if cursor >= PLAN.STAGE_COUNT:
		return _retire(plan)
	var stage: Dictionary = (plan["stages"] as Array)[cursor]
	if str(stage["state"]) == "pending":
		return _activate(plan, stage)
	if str(stage["state"]) == "active":
		return _complete(plan, stage)
	return _fail(&"condition_hospital_stage_state_invalid")


func _accept_destination_or_idle(_lifecycle: Dictionary) -> Dictionary:
	var captured: Dictionary = _consequence.call(&"capture")
	if not captured.get("ok", false): return captured
	var state: Dictionary = (captured["value"] as Dictionary)["state"]
	var raw: Variant = (state.get("outbox", {}) as Dictionary).get("hospital")
	if typeof(raw) != TYPE_DICTIONARY or str((raw as Dictionary).get("status", "")) != "pending":
		var released := _release_gate()
		if not released.get("ok", false): return released
		return _ok({"idle": true, "active_condition_hospital": false})
	var record: Dictionary = raw
	if str((record.get("payload", {}) as Dictionary).get("kind", "")) != "hospital_day" \
			or str(record.get("consumer", "")) != "condition_hospital":
		return _fail(&"condition_hospital_destination_invalid")
	var accepted: Dictionary = _state.call(&"prepare_accept", {
		"destination_record": record.duplicate(true),
		"action_receipt": (record["action_receipt"] as Dictionary).duplicate(true),
		"condition_receipt": (record["condition_receipt"] as Dictionary).duplicate(true),
	})
	if not accepted.get("ok", false): return accepted
	var acceptance: Dictionary = accepted["value"]
	var published: Dictionary = _consequence.call(&"prepare_outbox_publication", {
		"kind": "hospital", "key": str(record["key"]),
		"payload_hash": str(record["payload_hash"]),
		"provenance": (record["provenance"] as Dictionary).duplicate(true),
		"consumer": str(record["consumer"]),
	})
	if not published.get("ok", false): return published
	var consequence_candidate: Dictionary = published["value"]["candidate"]
	var lifecycle_candidate: Dictionary = acceptance["condition_hospital_candidate"]
	var durable := _persist(lifecycle_candidate["lifecycle_candidate"], null,
		consequence_candidate, &"day_resolution_stage", {"kind": &"autosave", "reason": &"automatic"})
	if not durable.get("ok", false): return durable
	var consequence_commit: Dictionary = _consequence.call(&"commit", consequence_candidate)
	if not consequence_commit.get("ok", false): return consequence_commit
	var state_commit: Dictionary = _state.call(&"commit", lifecycle_candidate)
	if not state_commit.get("ok", false): return state_commit
	return _ok({"idle": false, "active_condition_hospital": true,
		"boundary": "destination_accepted", "checkpoint_id": durable["value"]["checkpoint_id"]})


func _activate(plan: Dictionary, stage: Dictionary) -> Dictionary:
	var stage_id := str(stage["stage_id"])
	var prepared: Dictionary = _adapter.call(&"prepare_stage", plan.duplicate(true), stage_id)
	if not prepared.get("ok", false): return prepared
	var prepared_value: Dictionary = prepared["value"]
	var identity_result: Dictionary = _state.call(&"prepare_stage_identity", {
		"resolution_receipt_id": str(plan["resolution_receipt"]["receipt_id"]),
		"stage_id": stage_id,
		"input_receipt_ids": (prepared_value["input_receipt_ids"] as Array).duplicate(true),
	})
	if not identity_result.get("ok", false): return identity_result
	var identity: Dictionary = identity_result["value"]["stage_identity"]
	var activated: Dictionary = _state.call(&"prepare_stage", {
		"resolution_receipt_id": str(plan["resolution_receipt"]["receipt_id"]),
		"stage_id": stage_id, "stage_identity": identity,
		"prepared": (prepared_value["prepared"] as Dictionary).duplicate(true),
	})
	if not activated.get("ok", false): return activated
	var candidate: Dictionary = activated["value"]
	var durable := _persist(candidate["lifecycle_candidate"], null, null,
		&"day_resolution_stage", {"kind": &"autosave", "reason": &"automatic"})
	if not durable.get("ok", false): return durable
	var committed: Dictionary = _state.call(&"commit_stage", candidate)
	if not committed.get("ok", false): return committed
	return _ok({"boundary": "stage_active", "stage_id": stage_id,
		"checkpoint_id": durable["value"]["checkpoint_id"]})


func _complete(plan: Dictionary, stage: Dictionary) -> Dictionary:
	var stage_id := str(stage["stage_id"])
	var output: Dictionary
	var owner_candidate: Variant = null
	var checkpoint_kind := &"day_resolution_stage"
	var disk_write := {"kind": &"autosave", "reason": &"automatic"}
	var expected_checkpoint_id := ""
	if stage_id == "autosave_new_day":
		var preview: Dictionary = _checkpoint.call(&"preview_checkpoint_id", str(plan["run_id"]))
		if not preview.get("ok", false): return preview
		expected_checkpoint_id = str(preview["value"]["checkpoint_id"])
		var projected: Dictionary = _state.call(&"prepare_autosave_stage_output", {
			"resolution_receipt_id": str(plan["resolution_receipt"]["receipt_id"]),
			"stage_identity": stage["stage_identity"], "checkpoint_id": expected_checkpoint_id,
		})
		if not projected.get("ok", false): return projected
		output = projected["value"]["stage_output"]
		checkpoint_kind = &"day_start"
		disk_write = {"kind": &"autosave", "reason": &"day_start"}
	else:
		var executed: Dictionary = _adapter.call(&"execute_stage", plan.duplicate(true), stage.duplicate(true))
		if not executed.get("ok", false): return executed
		if bool((executed.get("value", {}) as Dictionary).get("awaiting_presentation", false)):
			# The active command was checkpointed before execution. Physical owners need
			# their own causal leases; completion will reacquire ours on the next resume.
			var released := _release_gate()
			if not released.get("ok", false): return released
			return _ok({"boundary": "awaiting_presentation", "stage_id": stage_id})
		output = ((executed["value"] as Dictionary)["output"] as Dictionary).duplicate(true)
		owner_candidate = (executed["value"] as Dictionary).get("owner_candidate")
	var receipt := {
		"input_receipt_ids": (stage["stage_identity"]["input_receipt_ids"] as Array).duplicate(true),
		"output": output, "receipt_id": str(stage["stage_identity"]["child_id"]),
		"receipt_provenance": (stage["stage_identity"]["provenance"] as Dictionary).duplicate(true),
		"resolution_kind": "condition_hospital",
		"resolution_receipt_id": str(plan["resolution_receipt"]["receipt_id"]),
		"stage_id": stage_id, "stage_index": int(plan["cursor"]),
	}
	var completed: Dictionary = _state.call(&"complete_stage", {
		"resolution_receipt_id": str(plan["resolution_receipt"]["receipt_id"]),
		"stage_id": stage_id, "stage_identity": stage["stage_identity"],
		"prepared": stage["prepared"], "stage_receipt": receipt,
	})
	if not completed.get("ok", false): return completed
	var candidate: Dictionary = completed["value"]
	var durable := _persist(candidate["lifecycle_candidate"], owner_candidate, null,
		checkpoint_kind, disk_write)
	if not durable.get("ok", false): return durable
	if not expected_checkpoint_id.is_empty() \
			and str(durable["value"]["checkpoint_id"]) != expected_checkpoint_id:
		return _fail(&"condition_hospital_checkpoint_id_changed")
	var owner_commit: Dictionary = _adapter.call(&"commit_stage", stage_id, owner_candidate)
	if not owner_commit.get("ok", false): return owner_commit
	var state_commit: Dictionary = _state.call(&"commit_stage", candidate)
	if not state_commit.get("ok", false): return state_commit
	if _adapter.has_method("publish_stage"):
		var published: Dictionary = _adapter.call(&"publish_stage", stage_id, owner_candidate)
		if not published.get("ok", false): return published
	return _ok({"boundary": "stage_completed", "stage_id": stage_id,
		"checkpoint_id": durable["value"]["checkpoint_id"]})


func _retire(plan: Dictionary) -> Dictionary:
	var autosave: Dictionary = (plan["stages"] as Array)[5]["receipt"]
	var prepared: Dictionary = _state.call(&"prepare_retirement", {
		"completed_plan": plan.duplicate(true), "autosave_stage_receipt": autosave.duplicate(true),
	})
	if not prepared.get("ok", false): return prepared
	var candidate := {"before_fingerprint": "",
		"lifecycle_candidate": (prepared["value"]["lifecycle_candidate"] as Dictionary).duplicate(true)}
	var durable := _persist(candidate["lifecycle_candidate"], null, null,
		&"day_resolution_stage", {"kind": &"autosave", "reason": &"automatic"})
	if not durable.get("ok", false): return durable
	var committed: Dictionary = _state.call(&"commit_retirement", candidate)
	if not committed.get("ok", false): return committed
	var released := _release_gate()
	if not released.get("ok", false): return released
	return _ok({"boundary": "plan_retired", "active_condition_hospital": false,
		"checkpoint_id": durable["value"]["checkpoint_id"]})


func _persist(lifecycle: Dictionary, owner_candidate: Variant, consequence_candidate: Variant,
		kind: StringName, disk_write: Dictionary) -> Dictionary:
	var profile := {}
	var tick := 0
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") == "1":
		tick = Time.get_ticks_usec()
		var plan: Variant = lifecycle.get("active_condition_hospital_plan")
		profile = {"scope": "condition_hospital", "kind": str(kind),
			"day": int(lifecycle.get("day", 0)), "cursor": int(plan.get("cursor", -1)) if plan is Dictionary else -1,
			"_started_us": tick}
	var composed: Dictionary = _adapter.call(&"compose_checkpoint_inputs", lifecycle,
		owner_candidate, consequence_candidate)
	tick = _profile_phase(profile, "compose_us", tick)
	if not composed.get("ok", false): return _profile_result(profile, composed)
	var prepared: Dictionary = _checkpoint.call(&"prepare", composed["value"]["checkpoint_inputs"],
		kind, disk_write)
	tick = _profile_phase(profile, "prepare_us", tick)
	if not prepared.get("ok", false): return _profile_result(profile, prepared)
	var committed: Dictionary = _checkpoint.call(&"commit", prepared["value"]["candidate"])
	_profile_phase(profile, "commit_us", tick)
	if not committed.get("ok", false): return _profile_result(profile, committed)
	if str(committed["value"]["checkpoint_id"]) != str(prepared["value"]["checkpoint_id"]):
		return _profile_result(profile, _fail(&"condition_hospital_checkpoint_commit_mismatch"))
	return _profile_result(profile, _ok({"checkpoint_id": str(committed["value"]["checkpoint_id"])}))


static func _profile_phase(profile: Dictionary, phase: String, started_us: int) -> int:
	if profile.is_empty(): return 0
	var now := Time.get_ticks_usec()
	profile[phase] = now - started_us
	return now


static func _profile_result(profile: Dictionary, result: Dictionary) -> Dictionary:
	if not profile.is_empty():
		profile["elapsed_us"] = Time.get_ticks_usec() - int(profile["_started_us"])
		profile.erase("_started_us")
		profile["ok"] = bool(result.get("ok", false))
		var value: Variant = result.get("value")
		profile["checkpoint_id"] = str(value.get("checkpoint_id", "")) if value is Dictionary else ""
		if not profile["ok"]: profile["code"] = str(result.get("code", ""))
		print("DWM_CHECKPOINT_PROFILE " + JSON.stringify(profile))
	return result

func has_owned_causal_lease(expected_gate: Object = null) -> bool:
	return _gate != null and (expected_gate == null or expected_gate == _gate) \
		and _gate.has_method("is_lease_active") and _gate.is_lease_active(_OWNER, _gate_token)


func _ensure_gate() -> Dictionary:
	if not _gate_token.is_empty():
		if has_owned_causal_lease(): return _ok({"held": true})
		return _fail(&"condition_hospital_gate_ownership_lost")
	# Another causal_transaction owner is still foreign custody without our token.
	if _gate.is_active(): return _fail(&"condition_hospital_transaction_blocked")
	var acquired: Dictionary = _gate.acquire(_OWNER)
	if acquired.get("ok", false): _gate_token = str(acquired["value"]["token"])
	return acquired


func _release_gate() -> Dictionary:
	if _gate_token.is_empty():
		if _gate.is_active(): return _fail(&"condition_hospital_gate_token_unavailable")
		return _ok({"released": false})
	if not has_owned_causal_lease():
		return _fail(&"condition_hospital_gate_ownership_lost")
	# release emits transaction_released synchronously. Retire our capability before
	# that notification; retain it if release fails so the same operation can retry.
	var token := _gate_token
	_gate_token = ""
	var released: Dictionary = _gate.release(_OWNER, token)
	if not released.get("ok", false): _gate_token = token
	return released


func _ready() -> Dictionary:
	return _ok({}) if _state != null else _fail(&"condition_hospital_coordinator_unconfigured")


static func _has(target: Object, methods: Array) -> bool:
	if target == null: return false
	for method: String in methods:
		if not target.has_method(method): return false
	return true


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": str(code), "details": {}}
