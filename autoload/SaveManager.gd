extends Node
# SaveManager (CONTRACTS §6): serializes/deserializes ONLY whitelisted GameState data.
# Never saves Nodes/Objects/Callables/Resources/live references; never loads scripts or
# executes methods from save data. JSON-only. Missing/corrupt saves never crash.

signal save_completed(result: Dictionary)
signal load_completed(result: Dictionary)
signal save_failed(result: Dictionary)
signal load_failed(result: Dictionary)
signal slot_metadata_changed()

const SAVE_FOLDER := "user://saves/"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const QUICK_SAVE_PATH := "user://saves/quick.json"
const MIN_SLOT := 1
const MAX_SLOT := 7


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func _current_schema_version() -> int:
	var gs := _gs()
	if gs != null:
		var v = gs.get("SAVE_SCHEMA_VERSION")
		if typeof(v) == TYPE_INT:
			return v
	return 1


# ---- Paths ----
func get_slot_path(slot_id: int) -> String:
	if slot_id < MIN_SLOT or slot_id > MAX_SLOT:
		return ""
	return "%sslot_%d.json" % [SAVE_FOLDER, slot_id]


func get_quick_save_path() -> String:
	return QUICK_SAVE_PATH


func get_autosave_path() -> String:
	return AUTOSAVE_PATH


func ensure_save_folder() -> bool:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		return true
	var err := DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	return err == OK


# ---- Build / IO ----
func build_save_dict(kind: String, slot_id: int = -1) -> Dictionary:
	var gs := _gs()
	var game_state: Dictionary = {}
	var summary: Dictionary = {}
	var route_context: Dictionary = {}
	if gs != null:
		if gs.has_method("to_save_dict"):
			game_state = gs.to_save_dict()
		if gs.has_method("get_save_summary"):
			summary = gs.get_save_summary()
		if gs.get("route_context") is Dictionary:
			route_context = (gs.route_context as Dictionary).duplicate(true)
	var scene_id := "main"
	var router := get_node_or_null("/root/SceneRouter")
	if router != null and router.has_method("get_current_scene_id"):
		var sid: String = router.get_current_scene_id()
		if sid != "":
			scene_id = sid
	return {
		"schema_version": _current_schema_version(),
		"kind": kind,
		"slot_id": slot_id,
		"saved_at_unix_time": int(Time.get_unix_time_from_system()),
		"scene_id": scene_id,
		"route_context": route_context,
		"summary": summary,
		"game_state": game_state,
	}


func write_json_file(path: String, data: Dictionary) -> Dictionary:
	if not ensure_save_folder():
		return {"ok": false, "reason": "folder_error", "path": path}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "reason": "open_write_failed", "path": path, "error": FileAccess.get_open_error()}
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return {"ok": true, "path": path}


func read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "not_found", "path": path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "open_read_failed", "path": path}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {"ok": false, "reason": "malformed_json", "path": path}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_a_dictionary", "path": path}
	return {"ok": true, "data": json.data, "path": path}


# ---- Validation / migration ----
func validate_save_dict(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_a_dictionary"}
	# JSON stores every number as a float, so schema_version round-trips as e.g. 1.0.
	# Accept any numeric type and normalize to int.
	if not data.has("schema_version") or not _is_number(data["schema_version"]):
		return {"ok": false, "reason": "missing_schema_version"}
	var sv: int = int(data["schema_version"])
	if sv > _current_schema_version():
		return {"ok": false, "reason": "unsupported_future_version", "schema_version": sv}
	if not data.has("game_state") or typeof(data["game_state"]) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "missing_game_state"}
	return {"ok": true, "schema_version": sv}


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func migrate_save_dict(data: Dictionary) -> Dictionary:
	# Upgrade an older schema_version forward to the current one, chaining per-version
	# migrations. Newly added whitelisted fields are left for GameState.apply_save_dict to
	# default (it applies only present keys, preserving fresh defaults for absent ones).
	var out := data.duplicate(true)
	var target := _current_schema_version()
	var sv: int = int(out.get("schema_version", target))
	while sv < target:
		match sv:
			0:
				# 0 -> 1: no structural change; version bump only.
				sv = 1
			_:
				sv = target
		out["schema_version"] = sv
	out["schema_version"] = target
	return out


# ---- Apply / route ----
func apply_save_dict(data: Dictionary) -> Dictionary:
	var v := validate_save_dict(data)
	if not v["ok"]:
		var fail := {"ok": false, "reason": v["reason"]}
		emit_signal("load_failed", fail)
		return fail
	var migrated := migrate_save_dict(data)
	var gs := _gs()
	if gs != null and gs.has_method("apply_save_dict"):
		gs.apply_save_dict(migrated["game_state"])
	# REQUIRED GUARD (CONTRACTS §6): a save taken mid-dating-queue would otherwise restore
	# stale pending_date_* with no consumer. Clear them on load unless the saved scene is a
	# dating scene (where the queue is expected to resume).
	var loaded_scene_id := str(migrated.get("scene_id", ""))
	if loaded_scene_id != "dating" and gs != null and gs.has_method("clear_pending_date_state"):
		gs.clear_pending_date_state()
	_route_after_load(migrated)
	var result := {"ok": true, "schema_version": migrated["schema_version"], "scene_id": migrated.get("scene_id", "")}
	emit_signal("load_completed", result)
	return result


func _route_after_load(data: Dictionary) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router == null:
		return
	# Only route when a live game scene is active. In headless/script contexts (e.g. the
	# GUT unit runner) there is no current_scene; state is applied but no scene change fires.
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var gs := _gs()
	var day := 1
	if gs != null:
		day = int(gs.day)
	var scene_id: String = str(data.get("scene_id", ""))
	# Mid-schedule saves and unknown ids restore MainGameScene (never auto-run Done).
	var safe_ids := ["menu", "opening", "main", "ending", "hospital"]
	if scene_id in safe_ids and router.has_method("goto_scene_id"):
		if scene_id == "ending":
			router.goto_scene_id("ending", data.get("route_context", {}))
		else:
			router.goto_scene_id(scene_id)
		return
	if day >= 1 and day <= 7:
		if router.has_method("goto_main"):
			router.goto_main()
	else:
		if router.has_method("goto_ending"):
			router.goto_ending()


# ---- Public save/load operations ----
func _do_save(path: String, kind: String, slot_id: int = -1) -> Dictionary:
	var data := build_save_dict(kind, slot_id)
	var res := write_json_file(path, data)
	if res["ok"]:
		emit_signal("save_completed", {"ok": true, "kind": kind, "slot_id": slot_id, "path": path})
		emit_signal("slot_metadata_changed")
		return {"ok": true, "kind": kind, "slot_id": slot_id, "path": path}
	emit_signal("save_failed", {"ok": false, "reason": res.get("reason", "unknown"), "path": path})
	return {"ok": false, "reason": res.get("reason", "unknown"), "path": path}


func _do_load(path: String) -> Dictionary:
	var res := read_json_file(path)
	if not res["ok"]:
		var fail := {"ok": false, "reason": res.get("reason", "unknown"), "path": path}
		emit_signal("load_failed", fail)
		return fail
	return apply_save_dict(res["data"])


func save_slot(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path == "":
		return {"ok": false, "reason": "invalid_slot", "slot_id": slot_id}
	return _do_save(path, "slot", slot_id)


func load_slot(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path == "":
		return {"ok": false, "reason": "invalid_slot", "slot_id": slot_id}
	return _do_load(path)


func quick_save() -> Dictionary:
	return _do_save(QUICK_SAVE_PATH, "quick", -1)


func quick_load() -> Dictionary:
	return _do_load(QUICK_SAVE_PATH)


func autosave() -> Dictionary:
	return _do_save(AUTOSAVE_PATH, "autosave", -1)


func load_autosave() -> Dictionary:
	return _do_load(AUTOSAVE_PATH)


func delete_slot(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path == "":
		return {"ok": false, "reason": "invalid_slot", "slot_id": slot_id}
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "not_found", "slot_id": slot_id}
	var err := DirAccess.remove_absolute(path)
	if err == OK:
		emit_signal("slot_metadata_changed")
		return {"ok": true, "slot_id": slot_id}
	return {"ok": false, "reason": "delete_failed", "slot_id": slot_id}


func has_slot(slot_id: int) -> bool:
	var path := get_slot_path(slot_id)
	if path == "":
		return false
	return FileAccess.file_exists(path)


# ---- Metadata ----
func get_slot_metadata(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path == "" or not FileAccess.file_exists(path):
		return {"exists": false, "slot_id": slot_id}
	var res := read_json_file(path)
	if not res["ok"]:
		return {"exists": true, "valid": false, "slot_id": slot_id, "reason": res.get("reason", "unknown")}
	var data: Dictionary = res["data"]
	return {
		"exists": true,
		"valid": true,
		"slot_id": slot_id,
		"saved_at_unix_time": data.get("saved_at_unix_time", 0),
		"summary": data.get("summary", {}),
		"schema_version": data.get("schema_version", 0),
	}


func get_all_slot_metadata() -> Array:
	var out: Array = []
	out.append({"kind": "autosave", "metadata": _path_metadata(AUTOSAVE_PATH)})
	out.append({"kind": "quick", "metadata": _path_metadata(QUICK_SAVE_PATH)})
	for slot_id in range(MIN_SLOT, MAX_SLOT + 1):
		out.append({"kind": "slot", "slot_id": slot_id, "metadata": get_slot_metadata(slot_id)})
	return out


func _path_metadata(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var res := read_json_file(path)
	if not res["ok"]:
		return {"exists": true, "valid": false, "reason": res.get("reason", "unknown")}
	var data: Dictionary = res["data"]
	return {
		"exists": true,
		"valid": true,
		"saved_at_unix_time": data.get("saved_at_unix_time", 0),
		"summary": data.get("summary", {}),
		"schema_version": data.get("schema_version", 0),
	}
