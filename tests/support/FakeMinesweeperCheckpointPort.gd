class_name FakeMinesweeperCheckpointPort
extends RefCounted

## Contract fake for the Task-5 first-Reveal checkpoint seam (Plan 02 Task 5, dwm-p2r.32). Its
## in-memory `commit_checkpoint()` is explicitly provisional and remains exactly reversible through
## `rollback(backup)` until `seal_checkpoint(candidate)` marks the joint fake-checkpoint plus
## GameState/board transaction committed; only publication follows that seal. It supports
## duplicate publication within one process but claims no restart recovery.
##
## MUST NOT create SaveManagerMinesweeperPort, configure ApplicationBootstrap, write a canonical
## save, claim crash durability, or call a production persistence path. `is_production()` always
## reports false.

var call_log: Array[Dictionary] = []

var _run_sequence: Dictionary = {}  # run_id (String) -> last-committed sequence (int)
var _committed: Dictionary = {}  # checkpoint_id (String) -> {"candidate": Dictionary, "sealed": bool}
var _fail_next: Dictionary = {}  # method_name (String) -> failure Dictionary


func fail_next(method_name: String, failure: Dictionary) -> void:
	_fail_next[method_name] = failure.duplicate(true)


func is_committed(checkpoint_id: String) -> bool:
	return _committed.has(checkpoint_id)


func is_sealed(checkpoint_id: String) -> bool:
	return _committed.has(checkpoint_id) and bool((_committed[checkpoint_id] as Dictionary)["sealed"])


func is_production() -> bool:
	return false


func capture() -> Dictionary:
	_log(&"capture", {})
	var armed := _consume_failure("capture")
	if not armed.is_empty():
		return armed
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"run_sequence": _run_sequence.duplicate(true), "committed": _committed.duplicate(true),
	}}, "receipt": {}}


func preview_checkpoint_id(run_id: String) -> Dictionary:
	_log(&"preview_checkpoint_id", {"run_id": run_id})
	var armed := _consume_failure("preview_checkpoint_id")
	if not armed.is_empty():
		return armed
	if run_id.strip_edges().is_empty():
		return {"ok": false, "code": &"invalid_run_id", "message": "", "details": {}}
	var sequence: int = int(_run_sequence.get(run_id, 0)) + 1
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": "%s:%d" % [run_id, sequence]}, "receipt": {}}


func prepare_checkpoint(snapshot_input: Dictionary, checkpoint_kind: StringName,
		disk_write: Dictionary) -> Dictionary:
	_log(&"prepare_checkpoint", {"checkpoint_kind": checkpoint_kind})
	var armed := _consume_failure("prepare_checkpoint")
	if not armed.is_empty():
		return armed
	var run_id := str(snapshot_input.get("run_id", ""))
	if run_id.is_empty():
		return {"ok": false, "code": &"invalid_snapshot_input", "message": "run_id is required", "details": {}}
	var sequence: int = int(_run_sequence.get(run_id, 0)) + 1
	var checkpoint_id := "%s:%d" % [run_id, sequence]
	var candidate := {
		"run_id": run_id, "sequence": sequence, "checkpoint_id": checkpoint_id,
		"kind": String(checkpoint_kind), "inputs": snapshot_input.duplicate(true),
		"disk_write": disk_write.duplicate(true),
	}
	return {"ok": true, "code": &"ok",
		"value": {"candidate": candidate, "checkpoint_id": checkpoint_id}, "receipt": {}}


## Provisional: recorded but exactly reversible via rollback(backup) until seal_checkpoint().
func commit_checkpoint(candidate: Dictionary) -> Dictionary:
	_log(&"commit_checkpoint", {"checkpoint_id": candidate.get("checkpoint_id", "")})
	var armed := _consume_failure("commit_checkpoint")
	if not armed.is_empty():
		return armed
	var checkpoint_id := str(candidate.get("checkpoint_id", ""))
	if checkpoint_id.is_empty():
		return {"ok": false, "code": &"invalid_candidate", "message": "", "details": {}}
	_run_sequence[str(candidate["run_id"])] = int(candidate["sequence"])
	_committed[checkpoint_id] = {"candidate": candidate.duplicate(true), "sealed": false}
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": checkpoint_id}, "receipt": {}}


## Marks the joint fake-checkpoint plus GameState/board transaction committed. Only publication
## follows a successful seal.
func seal_checkpoint(candidate: Dictionary) -> Dictionary:
	_log(&"seal_checkpoint", {"checkpoint_id": candidate.get("checkpoint_id", "")})
	var armed := _consume_failure("seal_checkpoint")
	if not armed.is_empty():
		return armed
	var checkpoint_id := str(candidate.get("checkpoint_id", ""))
	if not _committed.has(checkpoint_id):
		return {"ok": false, "code": &"checkpoint_not_committed", "message": checkpoint_id, "details": {}}
	var entry: Dictionary = _committed[checkpoint_id]
	if entry["candidate"] != candidate:
		return {"ok": false, "code": &"checkpoint_candidate_mismatch", "message": checkpoint_id, "details": {}}
	entry["sealed"] = true
	_committed[checkpoint_id] = entry
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": checkpoint_id, "sealed": true}, "receipt": {}}


func rollback(backup: Dictionary) -> Dictionary:
	_log(&"rollback", {})
	var armed := _consume_failure("rollback")
	if not armed.is_empty():
		return armed
	_run_sequence = (backup["run_sequence"] as Dictionary).duplicate(true)
	_committed = (backup["committed"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func _consume_failure(method_name: String) -> Dictionary:
	if not _fail_next.has(method_name):
		return {}
	var failure: Dictionary = _fail_next[method_name]
	_fail_next.erase(method_name)
	return failure


func _log(method: StringName, argument: Dictionary) -> void:
	call_log.append({"method": method, "argument": argument.duplicate(true)})
