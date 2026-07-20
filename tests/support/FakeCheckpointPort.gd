class_name FakeCheckpointPort
extends RefCounted

## In-memory checkpoint port double for DayResolutionCoordinator tests
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).

const DISK_WRITES := [
	{"kind": &"none", "reason": &"stage"},
	{"kind": &"autosave", "reason": &"day_start"},
	{"kind": &"autosave", "reason": &"ending"},
]

var _calls: Array[String]
var _run_id := ""
var _sequence := 0
var _committed: Array[Dictionary] = []
var _failure: StringName = &""

func _init(calls: Array[String]) -> void:
	_calls = calls

func seed_empty(run_id: String) -> void:
	_run_id = run_id
	_sequence = 0
	_committed = []

func set_failure(phase: StringName) -> void:
	_failure = phase

func peek_state() -> Dictionary:
	return {
		"run_id": _run_id,
		"sequence": _sequence,
		"committed": _committed.duplicate(true),
	}

func preview_checkpoint_id(run_id: String) -> Dictionary:
	if run_id != _run_id:
		return {"ok": false, "code": &"unknown_run", "message": run_id}
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": "%s:%d" % [_run_id, _sequence + 1]}}

func capture() -> Dictionary:
	_calls.append("checkpoint.capture")
	return {"ok": true, "code": &"ok", "value": {"backup": peek_state()}}

func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	_calls.append("checkpoint.prepare")
	if _failure == &"prepare":
		return {"ok": false, "code": &"checkpoint_prepare_failed", "message": "forced", "details": {}}
	if disk_write not in DISK_WRITES:
		return {"ok": false, "code": &"invalid_disk_write", "message": str(disk_write), "details": {}}
	var checkpoint_id := "%s:%d" % [_run_id, _sequence + 1]
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {
			"checkpoint_id": checkpoint_id,
			"kind": String(checkpoint_kind),
			"inputs": checkpoint_inputs.duplicate(true),
			"disk_write": disk_write.duplicate(true),
		},
		"checkpoint_id": checkpoint_id,
	}}

func commit(candidate: Dictionary) -> Dictionary:
	_calls.append("checkpoint.commit")
	if _failure == &"commit_after_mutation":
		_sequence += 1
		return {"ok": false, "code": &"checkpoint_commit_failed", "message": "forced after mutation", "details": {}}
	if _failure == &"commit":
		return {"ok": false, "code": &"checkpoint_commit_failed", "message": "forced", "details": {}}
	_sequence += 1
	_committed.append(candidate.duplicate(true))
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": str(candidate["checkpoint_id"])}}

func rollback(backup: Dictionary) -> Dictionary:
	_calls.append("checkpoint.rollback")
	if _failure == &"rollback":
		return {"ok": false, "code": &"checkpoint_rollback_failed", "message": "forced", "details": {}}
	_run_id = str(backup["run_id"])
	_sequence = int(backup["sequence"])
	_committed.assign(backup["committed"])
	return {"ok": true, "code": &"ok"}
