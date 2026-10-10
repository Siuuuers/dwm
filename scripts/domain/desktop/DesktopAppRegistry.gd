class_name DesktopAppRegistry
extends RefCounted

# Frozen Phase 2R desktop app registry. This is the sole app-ID-to-path resolver
# for Phase 3. It carries no player-facing composition, no UI state, and no
# filesystem probing: scene paths are exact literals and focus targets are the
# stable Control nodes each app scene exposes.

const _ENTRIES := {
	&"minesweeper": {"scene": "res://scenes/apps/MinesweeperApp.tscn", "focus": NodePath("%HideButton")},
	&"contacts":    {"scene": "res://scenes/apps/ContactListApp.tscn", "focus": NodePath("%HideButton")},
	&"schedule":    {"scene": "res://scenes/apps/ScheduleApp.tscn", "focus": NodePath("%HideButton")},
	&"shop":        {"scene": "res://scenes/apps/ShopApp.tscn", "focus": NodePath("%HideButton")},
	&"backup":      {"scene": "res://scenes/apps/BackupApp.tscn", "focus": NodePath("%HideButton")},
	&"settings":    {"scene": "res://scenes/apps/SettingsApp.tscn", "focus": NodePath("%HideButton")},
	&"logout":      {"scene": "res://scenes/apps/LogOutApp.tscn", "focus": NodePath("%NoButton")},
}


func get_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _ENTRIES.keys():
		out.append(id)
	return out


func has_app(app_id: StringName) -> bool:
	return _ENTRIES.has(app_id)


# Sole app-ID-to-path resolver. Unknown IDs return a safe error; this never
# throws and never touches the filesystem.
func get_record(app_id: StringName) -> Dictionary:
	if not _ENTRIES.has(app_id):
		return {"ok": false, "code": &"unknown_app_id"}
	var entry: Dictionary = _ENTRIES[app_id]
	return {"ok": true, "scene": entry["scene"], "focus_target": entry["focus"]}


# Structural integrity only. Duplicate IDs are impossible by dictionary keying;
# this rejects duplicate scene paths, empty/non-String scenes, and empty/!NodePath
# focus targets. On-tree focus resolution lives in the host-state tests.
func validate_all() -> Dictionary:
	var seen_paths := {}
	for id in _ENTRIES.keys():
		var entry: Dictionary = _ENTRIES[id]
		var scene: Variant = entry.get("scene", null)
		var focus: Variant = entry.get("focus", null)
		if typeof(scene) != TYPE_STRING or scene == "":
			return {"ok": false, "code": &"invalid_scene", "app_id": id}
		if not (focus is NodePath) or (focus as NodePath).is_empty():
			return {"ok": false, "code": &"invalid_focus_target", "app_id": id}
		if seen_paths.has(scene):
			return {"ok": false, "code": &"duplicate_scene_path", "app_id": id}
		seen_paths[scene] = true
	return {"ok": true}


## Current scene launcher; legacy calendar consumers retain get_ids().
func get_scene_ids() -> Array[StringName]:
	var ids := get_ids()
	ids.erase(&"schedule")
	return ids

func get_scene_record(app_id: StringName) -> Dictionary:
	if app_id not in get_scene_ids():
		return {"ok": false, "code": &"unknown_app_id"}
	return get_record(app_id)
