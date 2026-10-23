class_name FakeRestoreParticipant
extends RefCounted

## Fake restore participant for SaveManager transaction tests: records every
## call, can fail each position, and can pause an awaited apply or rollback
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

var _id: String
var _log: RefCounted
var _fail_at: StringName = &""
var _applied := false

func _init(participant_id: String, call_log: RefCounted) -> void:
	_id = participant_id
	_log = call_log

func set_failure(position: StringName) -> void:
	_fail_at = position

func was_applied() -> bool:
	return _applied

func prepare(input: Dictionary) -> Dictionary:
	_log.record(_id, "prepare")
	if _fail_at == &"prepare":
		return _fail(&"forced_prepare_failure")
	return {"ok": true, "code": &"ok", "value": {"plan": {"id": _id, "input": input.duplicate(true)}}}

func prepare_new_run(run_id: String) -> Dictionary:
	_log.record(_id, "prepare_new_run")
	if _fail_at == &"prepare_new_run":
		return _fail(&"forced_prepare_new_run_failure")
	return {"ok": true, "code": &"ok", "value": {
		"snapshot_input": {"run_id": run_id},
		"run_plan": {"snapshot_input": {"run_id": run_id}},
	}}

func capture() -> Dictionary:
	_log.record(_id, "capture")
	if _fail_at == &"capture":
		return _fail(&"forced_capture_failure")
	return {"ok": true, "code": &"ok", "value": {"backup": {"id": _id}}}

func apply_silent(plan: Dictionary) -> Dictionary:
	_log.record(_id, "apply_silent")
	if _fail_at == &"apply_silent":
		return _fail(&"forced_apply_failure")
	_applied = true
	return {"ok": true, "code": &"ok", "value": {"applied": _id, "plan": plan.duplicate(true)}}

func rollback_silent(backup: Dictionary) -> Dictionary:
	_log.record(_id, "rollback_silent")
	if _fail_at == &"rollback_silent":
		return _fail(&"forced_rollback_failure")
	_applied = false
	return {"ok": true, "code": &"ok", "value": {"rolled_back": _id, "backup": backup.duplicate(true)}}

func finalize() -> Dictionary:
	_log.record(_id, "finalize")
	if _fail_at == &"finalize":
		return _fail(&"forced_finalize_failure")
	return {"ok": true, "code": &"ok"}

func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}
