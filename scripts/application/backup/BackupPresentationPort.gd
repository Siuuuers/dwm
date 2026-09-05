class_name BackupPresentationPort
extends RefCounted

signal projection_changed()

## Backup presentation context. File custody, stable snapshots and restore routing stay in SaveManager.
const LOCATORS: Array[String] = ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]

var _owner: Object
var _context := "in_run"
var _pending: Dictionary = {}
var _projection_change_queued := false

func configure(save_manager: Object, context: String = "in_run") -> Dictionary:
	if context not in ["in_run", "title"]:
		return _fail(&"invalid_backup_context")
	if save_manager == null:
		return _fail(&"backup_owner_unavailable")
	for method: String in ["inspect_backup", "get_backup_save_capability", "prepare_backup_action", "commit_backup_action", "cancel_backup_action"]:
		if not save_manager.has_method(method):
			return _fail(&"backup_owner_unavailable")
	if _owner != null and (_owner != save_manager or _context != context):
		return _fail(&"backup_already_configured")
	_owner = save_manager
	_context = context
	if _owner.has_signal("slot_metadata_changed") and not _owner.slot_metadata_changed.is_connected(_queue_projection_changed):
		_owner.slot_metadata_changed.connect(_queue_projection_changed)
	if _owner.has_signal("save_capability_changed") and not _owner.save_capability_changed.is_connected(_on_capability_changed):
		_owner.save_capability_changed.connect(_on_capability_changed)
	return {"ok": true}

func _on_capability_changed(_capability: Dictionary) -> void:
	_queue_projection_changed()

func _queue_projection_changed() -> void:
	if not _projection_change_queued:
		_projection_change_queued = true
		call_deferred("_publish_projection_changed")

func _publish_projection_changed() -> void:
	_projection_change_queued = false
	projection_changed.emit()

func get_projection() -> Dictionary:
	if not is_instance_valid(_owner):
		return _fail(&"backup_owner_unavailable")
	var capability: Dictionary = _owner.get_backup_save_capability()
	if _context == "title":
		capability = {"enabled": false, "reason": "title_load_only"}
	var records: Array[Dictionary] = []
	for locator: String in LOCATORS:
		var inspected: Dictionary = _owner.inspect_backup(locator)
		var record: Dictionary
		if inspected.get("ok", false):
			record = _project_record(inspected["value"], capability)
		else:
			record = {"locator": locator, "state": "unavailable", "day": null, "saved_time": null,
				"fallback": false, "load_day": null, "load_saved_time": null, "reason": "unreadable",
				"actions": {"save": false, "load": false, "delete": false}}
		records.append(record)
	return {"ok": true, "value": {"records": records, "save_capability": capability}}

func prepare_action(action: String, locator: String) -> Dictionary:
	if not is_instance_valid(_owner):
		return _fail(&"backup_owner_unavailable")
	if locator not in LOCATORS or action not in ["save", "load", "delete"]:
		return _fail(&"invalid_backup_action")
	if _context == "title" and action == "save":
		return _fail(&"backup_action_unavailable")
	for pending_token: String in _pending.keys():
		cancel_action(pending_token)
	var inspected: Dictionary = _owner.inspect_backup(locator)
	if not inspected.get("ok", false):
		return inspected
	var record := _project_record(inspected["value"], _owner.get_backup_save_capability())
	if not record["actions"][action]:
		return _fail(&"backup_action_unavailable")
	var prepared: Dictionary = _owner.prepare_backup_action(action, locator)
	if not prepared.get("ok", false):
		return prepared
	# Owner's final preparation is authoritative if bytes changed since inspection.
	record = _project_record(prepared["value"]["record"], _owner.get_backup_save_capability())
	var confirmation_kind := "none"
	if action == "load":
		if _context == "title":
			confirmation_kind = "fallback" if record["fallback"] else "none"
		else:
			confirmation_kind = "replace_progress_fallback" if record["fallback"] else "replace_progress"
	elif action == "delete":
		confirmation_kind = "delete"
	elif record["state"] != "empty" and (locator != "quick" or record["state"] == "unavailable" or record["fallback"]):
		confirmation_kind = "overwrite"
	var token := str(prepared["value"]["token"])
	_pending[token] = {"action": action, "locator": locator}
	return {"ok": true, "value": {"confirmation_required": confirmation_kind != "none",
		"confirmation_kind": confirmation_kind, "token": token, "record": record}}

func commit_action(token: String) -> Dictionary:
	if not _pending.has(token) or not is_instance_valid(_owner):
		return _fail(&"stale_backup_action")
	var pending: Dictionary = _pending[token]
	_pending.erase(token)
	var result: Dictionary = _owner.commit_backup_action(token)
	if result.get("ok", false):
		var value: Dictionary = result.get("value", {}).duplicate(true)
		value.merge(pending, true)
		result["value"] = value
	return result

func cancel_action(token: String) -> void:
	if _pending.has(token):
		if is_instance_valid(_owner):
			_owner.cancel_backup_action(token)
		_pending.erase(token)

func _project_record(source: Dictionary, capability: Dictionary) -> Dictionary:
	var record := {}
	for key: String in ["locator", "state", "day", "saved_time", "fallback", "load_day", "load_saved_time", "reason"]:
		record[key] = source[key]
	var accessible: bool = source.has("revision") and source.get("operation_allowed", false)
	record["actions"] = {
		"save": _context != "title" and accessible and capability.get("enabled", false) and source["locator"] != "autosave",
		"load": accessible and source.get("loadable", false),
		"delete": accessible and source["state"] != "empty",
	}
	return record

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
