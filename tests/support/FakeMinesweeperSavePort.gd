class_name FakeMinesweeperSavePort
extends RefCounted

# Test double for the Minesweeper coordinator's save port. Wraps the exact frozen
# method set and records per-method call counts. Checkpoint ids are derived from
# the last preview so prepare_checkpoint reproduces the same id the coordinator
# commits, mirroring the production journal-sequence determinism.

const METHODS: Array[String] = [
	"capture", "preview_checkpoint_id", "prepare_checkpoint", "commit_checkpoint",
	"rollback", "acquire_board_lock", "release_board_lock", "owns_board_lock",
]

var _calls := {}
var _failures := {}
var _lock_held := false
var _last_preview_id := ""


func _init() -> void:
	_reset_counters()


func _reset_counters() -> void:
	_calls = {}
	for m in METHODS:
		_calls[m] = 0


func reset_call_counts() -> void:
	_reset_counters()


func get_call_counts() -> Dictionary:
	return _calls.duplicate()


func set_failure(method: StringName, remaining_failures: int = 1) -> void:
	_failures[method] = remaining_failures


func _maybe_fail(method: StringName) -> bool:
	if _failures.has(method) and _failures[method] > 0:
		_failures[method] -= 1
		return true
	return false


func capture() -> Dictionary:
	_calls.capture += 1
	if _maybe_fail(&"capture"):
		return {"ok": false, "code": &"capture_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"backup": {"save": "backup"}}}


func preview_checkpoint_id(run_id: String) -> Dictionary:
	_calls.preview_checkpoint_id += 1
	if _maybe_fail(&"preview_checkpoint_id"):
		return {"ok": false, "code": &"preview_failed", "message": "fake failure", "details": {}}
	_last_preview_id = "%s:%d" % [run_id, 1]
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": _last_preview_id}}


func prepare_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	_calls.prepare_checkpoint += 1
	if _maybe_fail(&"prepare_checkpoint"):
		return {"ok": false, "code": &"prepare_failed", "message": "fake failure", "details": {}}
	var cid: String = _last_preview_id
	return {"ok": true, "code": &"ok",
		"value": {"candidate": {"checkpoint_id": cid}, "checkpoint_id": cid}}


func commit_checkpoint(candidate: Dictionary) -> Dictionary:
	_calls.commit_checkpoint += 1
	if _maybe_fail(&"commit_checkpoint"):
		return {"ok": false, "code": &"commit_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": candidate.get("checkpoint_id", "ckpt")}}


func rollback(backup: Dictionary) -> Dictionary:
	_calls.rollback += 1
	if _maybe_fail(&"rollback"):
		return {"ok": false, "code": &"rollback_failed", "message": "fake failure", "details": {}}
	return {"ok": true, "code": &"ok", "value": {"rolled_back": true}}


func acquire_board_lock() -> Dictionary:
	_calls.acquire_board_lock += 1
	if _maybe_fail(&"acquire_board_lock"):
		return {"ok": false, "code": &"lock_failed", "message": "fake failure", "details": {}}
	if _lock_held:
		return {"ok": false, "code": &"LOCK_ALREADY_HELD"}
	_lock_held = true
	return {"ok": true, "code": &"ok", "value": {"lock": &"minesweeper_board"}}


func release_board_lock() -> Dictionary:
	_calls.release_board_lock += 1
	if _maybe_fail(&"release_board_lock"):
		return {"ok": false, "code": &"release_failed", "message": "fake failure", "details": {}}
	if not _lock_held:
		return {"ok": false, "code": &"LOCK_NOT_HELD"}
	_lock_held = false
	return {"ok": true, "code": &"ok", "value": {"released": true}}


func owns_board_lock() -> bool:
	_calls.owns_board_lock += 1
	return _lock_held
