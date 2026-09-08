class_name RunRestoreParticipant
extends RefCounted

## Restore participant wrapping GameState's run state
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## Thin adapter: prepares detached plans and delegates capture/apply/rollback/
## finalize to the owner's silent restore seams. Emits no domain signals here.

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func get_new_run_replacement_baseline() -> Dictionary:
	if not is_instance_valid(_owner) or not _owner.has_method("get_new_run_replacement_baseline"):
		return _fail(&"new_run_replacement_unavailable", "")
	return _owner.get_new_run_replacement_baseline()

func capture_live_session() -> Dictionary:
	return _owner.capture_live_session()

func validate_live_session_activation(ticket: Dictionary) -> Dictionary:
	return _owner.validate_live_session_activation(ticket)

func activate_live_session(ticket: Dictionary) -> Dictionary:
	return _owner.activate_live_session(ticket)

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_run_input", "run participant requires a snapshot")
	return {"ok": true, "code": &"ok", "value": {"run_plan": {"snapshot": (input["snapshot"] as Dictionary).duplicate(true)}}}

## `branch_id`/`desktop_timeline_generation`/`causal_day_instance`/`causal_day_instance_issuer_
## receipt` (Plan 02 Task 6, dwm-p2r.32) arrive already durably allocated through SaveManager's
## Task-1 issuer/journal seams; this thin adapter invents none of them, it only forwards.
func prepare_new_run(run_id: String, branch_id: String, desktop_timeline_generation: int,
		causal_day_instance: String, causal_day_instance_issuer_receipt: Dictionary, dark_mode: Variant,
		pair_witnessed_forms: Array = []) -> Dictionary:
	if typeof(dark_mode) != TYPE_BOOL:
		return _fail(&"invalid_run_configuration", "dark_mode must be a Boolean")
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	var prepared: Dictionary = _owner.prepare_new_run_snapshot_input(run_id, branch_id,
		desktop_timeline_generation, causal_day_instance, causal_day_instance_issuer_receipt, dark_mode, pair_witnessed_forms)
	if not prepared.get("ok", false):
		return prepared
	var snapshot_input: Dictionary = prepared["value"]["snapshot_input"]
	return {"ok": true, "code": &"ok", "value": {
		"snapshot_input": snapshot_input.duplicate(true),
		"run_plan": {"snapshot_input": snapshot_input.duplicate(true)},
	}}

## Task 6 Phase C2 (dwm-p2r.32): after the ordinary snapshot apply above has installed day/state/
## active_resolution_plan (still carrying whatever identity that snapshot's bytes held), this second
## step swaps in the durably-allocated NEW identity for a restore transaction. Delegates to
## RunLifecycle.prepare_continuation_remap()/commit_continuation_remap() (Phase C), which build the
## destination identity from the bundle and restore_provenance's source_* fields from the explicit
## `source_identity` argument -- the SOURCE document's pre-restore identity (ruling T4-AF item 23),
## never the lifecycle object's own live members, which by this point already carry the destination
## identity. day/state/plan are left exactly as apply_silent() above just set them. New Run never
## calls this: its identity is correct from construction (prepare_new_run above), never remapped.
func apply_continuation_remap(restore_transaction_id: String, identity_allocation_bundle: Dictionary,
		source_identity: Dictionary) -> Dictionary:
	return _owner.apply_continuation_remap_silent(restore_transaction_id, identity_allocation_bundle, source_identity)

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
