extends "res://scripts/application/backup/BackupPresentationPort.gd"
## Pause composes the existing opaque Backup transaction. Delete leaves suspension intact;
## idle-source Load releases it before the normal restore and re-acquires only on exact rollback.
var _pause: Object

func configure_pause(saves: Object, pause: Object) -> Dictionary:
	if _pause != null and _pause != pause: return {"ok": false, "code": &"pause_backup_already_configured"}
	_pause = pause
	return configure(saves, "in_run", Callable(pause, "_backup_admission"))

func _project_record(source: Dictionary, capability: Dictionary, admitted: bool) -> Dictionary:
	var record: Dictionary = super._project_record(source, capability, admitted)
	record.actions.save = bool(record.actions.save) and _pause.can_save_backup()
	record.actions.load = bool(record.actions.load) and _pause.can_load_backup()
	return record

func _quick_available(action: String) -> bool:
	if action == "save" and not _pause.can_save_backup(): return false
	if action == "load" and not _pause.can_load_backup(): return false
	return super._quick_available(action)


func commit_action(token: String) -> Dictionary:
	if _pending.has(token) and _pending[token].get("action") == "save":
		var prepared: Dictionary = _pause.prepare_backup_save()
		if not prepared.get("ok", false):
			cancel_action(token)
			return prepared
	if not _pending.has(token) or _pending[token].get("action") != "load":
		return super.commit_action(token)
	var released: Dictionary = await _pause.release_for_backup_load()
	if not released.get("ok", false):
		cancel_action(token)
		return released
	var result: Dictionary = super.commit_action(token)
	return await _pause.finish_backup_load(result)
