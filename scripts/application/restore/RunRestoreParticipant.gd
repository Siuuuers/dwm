class_name RunRestoreParticipant
extends RefCounted

## Restore participant wrapping GameState's run state
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## Thin adapter: prepares detached plans and delegates capture/apply/rollback/
## finalize to the owner's silent restore seams. Emits no domain signals here.

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_run_input", "run participant requires a snapshot")
	return {"ok": true, "code": &"ok", "value": {"run_plan": {"snapshot": (input["snapshot"] as Dictionary).duplicate(true)}}}

## `branch_id`/`desktop_timeline_generation`/`causal_day_instance`/`causal_day_instance_issuer_
## receipt` (Plan 02 Task 6, dwm-p2r.32) arrive already durably allocated through SaveManager's
## Task-1 issuer/journal seams; this thin adapter invents none of them, it only forwards.
func prepare_new_run(run_id: String, branch_id: String, desktop_timeline_generation: int,
		causal_day_instance: String, causal_day_instance_issuer_receipt: Dictionary) -> Dictionary:
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	var prepared: Dictionary = _owner.prepare_new_run_snapshot_input(run_id, branch_id,
		desktop_timeline_generation, causal_day_instance, causal_day_instance_issuer_receipt)
	if not prepared.get("ok", false):
		return prepared
	var snapshot_input: Dictionary = prepared["value"]["snapshot_input"]
	return {"ok": true, "code": &"ok", "value": {
		"snapshot_input": snapshot_input.duplicate(true),
		"run_plan": {"snapshot_input": snapshot_input.duplicate(true)},
	}}

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func apply_silent(plan: Dictionary) -> Dictionary:
	return _owner.apply_restore_silent(plan)

func rollback_silent(backup: Dictionary) -> Dictionary:
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
