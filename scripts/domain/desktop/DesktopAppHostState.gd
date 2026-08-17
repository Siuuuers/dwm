class_name DesktopAppHostState
extends RefCounted

## One visible cached desktop app + deterministic focus outputs (dwm-p2r.9, Plan 02 Task 1).
## Pure runtime state: no scene composition, no filesystem, no persistence of day/cache/paths.
## Phase 3 consumes this through the frozen seams; it never constructs or replaces the host.

const REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")

var _current_day: int = 0
var _active_app_id: StringName = &""
var _cached_app_ids: Array[StringName] = []


func reset(current_day: int) -> void:
	_current_day = current_day
	_active_app_id = &""
	_cached_app_ids = []


func open_app(app_id: StringName, current_day: int) -> Dictionary:
	if not REGISTRY.new().has_app(app_id):
		return {"ok": false, "code": &"unknown_app_id", "message": "app_id is not a registered desktop app"}
	_current_day = current_day
	var hide_app_id: StringName = _active_app_id if _active_app_id != &"" else &""
	var was_cached := _cached_app_ids.has(app_id)
	if not was_cached:
		_cached_app_ids.append(app_id)
	var record: Dictionary = REGISTRY.new().get_record(app_id)
	var focus_target: NodePath = record.get("focus_target", NodePath())
	_active_app_id = app_id
	return {
		"ok": true,
		"instantiate": not was_cached,
		"hide_app_id": hide_app_id if hide_app_id != &"" else null,
		"show_app_id": app_id,
		"focus_target": focus_target,
	}


func close_app() -> Dictionary:
	if _active_app_id == &"":
		return {"ok": false, "code": &"no_active_app", "message": "no app is currently open"}
	var focus_icon_app_id: StringName = _active_app_id
	_active_app_id = &""
	return {"ok": true, "code": &"ok", "focus_icon_app_id": focus_icon_app_id}


func change_day(new_day: int) -> Dictionary:
	if new_day <= 0:
		return {"ok": false, "code": &"invalid_day", "message": "day must be positive"}
	if new_day <= _current_day:
		return {"ok": false, "code": &"day_not_advanced", "message": "day must strictly advance"}
	var evicted: Array[StringName] = []
	for id in REGISTRY.new().get_ids():
		if _cached_app_ids.has(id):
			evicted.append(id)
	var eviction_command := {
		"command_id": "desktop-day:%d" % new_day,
		"kind": &"evict_cached_apps",
		"day": new_day,
		"app_ids": evicted.duplicate(true),
	}
	_active_app_id = &""
	_cached_app_ids = []
	_current_day = new_day
	return {"ok": true, "code": &"ok",
		"value": {"eviction_command": eviction_command.duplicate(true)}, "receipt": {}}


func get_state() -> Dictionary:
	return {
		"current_day": _current_day,
		"active_app_id": _active_app_id if _active_app_id != &"" else null,
		"cached_app_ids": _cached_app_ids.duplicate(true),
	}


func capture_persistent_state() -> Dictionary:
	return {"active_app_id": _active_app_id if _active_app_id != &"" else null}


func prepare_restore(active_app_id: Variant, current_day: int) -> Dictionary:
	var saved_id: StringName = &""
	if active_app_id != null:
		if typeof(active_app_id) == TYPE_STRING_NAME:
			saved_id = active_app_id
		elif typeof(active_app_id) == TYPE_STRING:
			saved_id = StringName(active_app_id)
		else:
			return {"ok": false, "code": &"invalid_active_app_id", "message": "active_app_id must be a registered ID or null"}
		if not REGISTRY.new().has_app(saved_id):
			return {"ok": false, "code": &"unknown_app_id", "message": "saved active_app_id is not a registered desktop app"}
	_current_day = current_day
	_active_app_id = &""
	_cached_app_ids = []
	var candidate_state := {
		"current_day": _current_day,
		"active_app_id": saved_id if saved_id != &"" else null,
		"cached_app_ids": [],
	}
	var instantiate_command = null
	if saved_id != &"":
		var record: Dictionary = REGISTRY.new().get_record(saved_id)
		instantiate_command = {
			"ok": true,
			"instantiate": true,
			"hide_app_id": null,
			"show_app_id": saved_id,
			"focus_target": record.get("focus_target", NodePath()),
		}
	return {"ok": true, "code": &"ok",
		"value": {"candidate_state": candidate_state, "instantiate_command": instantiate_command}, "receipt": {}}
