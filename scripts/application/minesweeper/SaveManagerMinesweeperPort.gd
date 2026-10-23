class_name SaveManagerMinesweeperPort
extends RefCounted

## Production Minesweeper save port (dwm-p2r.9 Plan 06 Task 2).
##
## Delegates checkpoint preview/capture/prepare/commit/rollback to plan03's ONE real
## `SaveManagerCheckpointPort`, and delegates ONLY owner `&"minesweeper_board"` to
## SaveManager's lock API. It reimplements no schema, journal, filename, or save
## capability of its own.

const BOARD_LOCK_OWNER: StringName = &"minesweeper_board"

const CHECKPOINT_METHODS: Array[String] = [
	"preview_checkpoint_id", "capture", "prepare", "commit", "rollback",
]
const SAVE_MANAGER_METHODS: Array[String] = [
	"acquire_save_lock", "release_save_lock", "is_save_locked",
]

var _checkpoint_port: Object = null
var _save_manager: Object = null
## Whether THIS port currently holds the board lock. SaveManager exposes no owner query,
## so ownership is tracked here and always confirmed against its live lock state.
var _owns_board_lock := false


func _init(checkpoint_port: Object = null, save_manager: Object = null) -> void:
	_checkpoint_port = checkpoint_port
	_save_manager = save_manager


func configure(checkpoint_port: Object, save_manager: Object) -> Dictionary:
	if checkpoint_port == null or save_manager == null:
		return _fail(&"invalid_minesweeper_save_port", "both the checkpoint port and SaveManager are required")
	for method in CHECKPOINT_METHODS:
		if not checkpoint_port.has_method(method):
			return _fail(&"invalid_minesweeper_save_port", "checkpoint port is missing " + method)
	for method in SAVE_MANAGER_METHODS:
		if not save_manager.has_method(method):
			return _fail(&"invalid_minesweeper_save_port", "SaveManager is missing " + method)
	if _checkpoint_port != null and _checkpoint_port != checkpoint_port:
		return _fail(&"minesweeper_save_port_already_configured", "another checkpoint port is configured")
	if _save_manager != null and _save_manager != save_manager:
		return _fail(&"minesweeper_save_port_already_configured", "another SaveManager is configured")
	_checkpoint_port = checkpoint_port
	_save_manager = save_manager
	return {"ok": true, "code": &"ok", "value": {
		"checkpoint_port_instance_id": _checkpoint_port.get_instance_id(),
		"save_manager_instance_id": _save_manager.get_instance_id(),
	}, "receipt": {}}


# ---- Frozen coordinator port surface ----

func capture() -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"capture")


func preview_checkpoint_id(run_id: String) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"preview_checkpoint_id", run_id)


func prepare_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"prepare", checkpoint_inputs, checkpoint_kind, disk_write)


func commit_checkpoint(candidate: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"commit", candidate)


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var payload: Variant = backup.get("backup", backup)
	return _checkpoint_port.call(&"rollback", payload if typeof(payload) == TYPE_DICTIONARY else backup)


func acquire_board_lock() -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var acquired: Dictionary = _save_manager.call(&"acquire_save_lock", BOARD_LOCK_OWNER)
	if acquired.get("ok", false):
		_owns_board_lock = true
	return acquired


func release_board_lock() -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var released: Dictionary = _save_manager.call(&"release_save_lock", BOARD_LOCK_OWNER)
	if released.get("ok", false):
		_owns_board_lock = false
	return released


func owns_board_lock() -> bool:
	if _save_manager == null:
		return false
	return _owns_board_lock and bool(_save_manager.call(&"is_save_locked"))


func _readiness() -> Dictionary:
	if _checkpoint_port == null or _save_manager == null:
		return _fail(&"minesweeper_save_port_not_configured", "")
	return {}


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}, "receipt": {}}
