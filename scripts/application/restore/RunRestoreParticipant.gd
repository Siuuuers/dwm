class_name RunRestoreParticipant
extends RefCounted


const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
var _owner: Object = null
var _scene_creation_plan: Dictionary = {}
var _scene_creation_owner: Object

func _init(owner: Object) -> void:
	_owner = owner

func has_new_run_replacement() -> bool:
	return _owner.has_new_run_replacement()

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

func activate_loaded_session(ticket: Dictionary) -> Dictionary:
	return _owner.activate_loaded_session(ticket)

func prepare(input: Dictionary) -> Dictionary:
	_scene_creation_plan = {}
	_scene_creation_owner = null
	if typeof(input.get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_run_input", "run participant requires a snapshot")
	if input.snapshot.get("schema_version") == 9:
		var scene: Dictionary = RUN_SCHEMA.validate(input.snapshot)
		if not scene.get("ok", false): return scene
	elif _owner.has_method("validate_scene_event_snapshot"):
		var events: Dictionary = _owner.validate_scene_event_snapshot(input["snapshot"])
		if not events.get("ok", false): return events
	return _prepare_admitted_snapshot(input.snapshot)

func _prepare_admitted_snapshot(snapshot: Dictionary) -> Dictionary:
	_scene_creation_plan = {}
	_scene_creation_owner = null
	return {"ok": true, "code": &"ok", "value": {"run_plan": {"snapshot": snapshot.duplicate(true)}}}

func prepare_scene_new_run_snapshot_input(allocation_candidate: Dictionary, entry_id: String,
		occurrence: String) -> Dictionary:
	return _owner.prepare_scene_new_run_snapshot_input(allocation_candidate, entry_id, occurrence)

func prepare_scene_new_run(snapshot: Dictionary, allocation_candidate: Dictionary, profile_material: Dictionary,
		bundle: Dictionary, issuer: Object, creation_owner: Object) -> Dictionary:
	_scene_creation_plan = {}
	_scene_creation_owner = null
	var prepared: Dictionary = _owner.prepare_scene_new_run(snapshot, allocation_candidate, profile_material,
		bundle, issuer, creation_owner)
	if not prepared.get("ok", false): return prepared
	_scene_creation_plan = prepared.value.run_plan.duplicate(true)
	_scene_creation_owner = creation_owner
	return prepared

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

func apply_continuation_remap(restore_transaction_id: String, identity_allocation_bundle: Dictionary,
		source_identity: Dictionary) -> Dictionary:
	return _owner.apply_continuation_remap_silent(restore_transaction_id, identity_allocation_bundle, source_identity)

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func apply_silent(plan: Dictionary) -> Dictionary:
	if not _scene_creation_plan.is_empty():
		if plan != _scene_creation_plan:
			return _fail(&"scene_creation_plan_mismatch", "")
		var applied: Dictionary = _owner.apply_scene_new_run_silent(plan, _scene_creation_owner)
		if applied.get("ok", false):
			_scene_creation_plan = {}
			_scene_creation_owner = null
		return applied
	return _owner.apply_restore_silent(plan)

func rollback_silent(backup: Dictionary) -> Dictionary:
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

