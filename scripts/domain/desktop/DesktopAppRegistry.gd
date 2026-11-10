class_name DesktopAppRegistry
extends RefCounted


const _ENTRIES := {
	&"minesweeper": {"scene": "res://scenes/apps/MinesweeperApp.tscn", "focus": NodePath("%HideButton")},
	&"contacts":    {"scene": "res://scenes/apps/ContactListApp.tscn", "focus": NodePath("%HideButton")},
	&"shop":        {"scene": "res://scenes/apps/ShopApp.tscn", "focus": NodePath("%HideButton")},
	&"backup":      {"scene": "res://scenes/apps/BackupApp.tscn", "focus": NodePath("%HideButton")},
	&"settings":    {"scene": "res://scenes/apps/SettingsApp.tscn", "focus": NodePath("%HideButton")},
}


func get_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _ENTRIES.keys():
		out.append(id)
	return out


func has_app(app_id: StringName) -> bool:
	return _ENTRIES.has(app_id)


func get_record(app_id: StringName) -> Dictionary:
	if not _ENTRIES.has(app_id):
		return {"ok": false, "code": &"unknown_app_id"}
	var entry: Dictionary = _ENTRIES[app_id]
	return {"ok": true, "scene": entry["scene"], "focus_target": entry["focus"]}


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


func get_scene_ids() -> Array[StringName]:
	return get_ids()

func get_scene_record(app_id: StringName) -> Dictionary:
	return get_record(app_id)
