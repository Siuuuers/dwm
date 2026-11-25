class_name DialogicTimelineCatalog
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://data/manifests/timelines.json"
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const DEFAULT_LOCALE := "en"

static var _records: Dictionary = {}
static var _initialized := false
static var _manifest_path := ""

static var _entry_document: Dictionary = {}
static var _entries_initialized := false


static func initialize(manifest_path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	var text := FileAccess.get_file_as_string(manifest_path)
	if text.is_empty():
		return {"ok": false, "code": &"manifest_missing", "message": manifest_path}
	var parsed := _STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return parsed
	var manifest: Dictionary = parsed["value"]
	if typeof(manifest.get("records")) != TYPE_ARRAY:
		return {"ok": false, "code": &"manifest_invalid", "message": "records must be an array"}
	var by_id := {}
	for record in manifest["records"]:
		if typeof(record) != TYPE_DICTIONARY or not (record as Dictionary).has("id"):
			return {"ok": false, "code": &"manifest_invalid", "message": "record missing id"}
		var id := str((record as Dictionary)["id"])
		if by_id.has(id):
			return {"ok": false, "code": &"duplicate_timeline_id", "message": id}
		by_id[id] = record
	_records = by_id
	_manifest_path = manifest_path
	_initialized = true
	return {"ok": true, "value": {"count": _records.size()}}


static func _ensure() -> void:
	if not _initialized:
		initialize()


static func has_timeline_id(timeline_id: String) -> bool:
	_ensure()
	return _records.has(timeline_id)


static func get_record(timeline_id: String) -> Dictionary:
	_ensure()
	if not _records.has(timeline_id):
		return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
	return {"ok": true, "value": (_records[timeline_id] as Dictionary).duplicate(true)}


static func get_path_for_id(timeline_id: String) -> Dictionary:
	_ensure()
	if not _records.has(timeline_id):
		return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
	return {"ok": true, "value": {"path": "res://" + str((_records[timeline_id] as Dictionary)["path"])}}


static func validate_all() -> Dictionary:
	_ensure()
	if _records.is_empty():
		return {"ok": false, "code": &"manifest_missing", "message": _manifest_path if _manifest_path != "" else DEFAULT_MANIFEST_PATH}
	for id in _records:
		var res_path := "res://" + str((_records[id] as Dictionary).get("path", ""))
		if not (ResourceLoader.exists(res_path) or FileAccess.file_exists(res_path)):
			return {"ok": false, "code": &"missing_timeline_file", "message": res_path}
	return {"ok": true, "value": {"count": _records.size()}}


static func get_required_timeline_ids() -> Array[String]:
	_ensure()
	var ids: Array[String] = []
	for id in _records:
		ids.append(str(id))
	ids.sort()
	return ids


static func get_timeline_path(timeline_id: String, _locale: String = "en") -> String:
	_ensure()
	if not _records.has(timeline_id):
		return ""
	return "res://" + str((_records[timeline_id] as Dictionary)["path"])


static func get_required_timeline_paths(_locale: String = "en") -> Array[String]:
	var out: Array[String] = []
	for id in get_required_timeline_ids():
		var path := get_timeline_path(id)
		if path != "" and not (path in out):
			out.append(path)
	return out


static func build_missing_timeline_report(locale: String = "en") -> Dictionary:
	var required := get_required_timeline_paths(locale)
	var existing: Array[String] = []
	var missing: Array[String] = []
	for path in required:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			existing.append(path)
		else:
			missing.append(path)
	return {
		"locale": locale,
		"required_count": required.size(),
		"existing_count": existing.size(),
		"missing_count": missing.size(),
		"missing": missing,
	}



static func _ensure_entries() -> Dictionary:
	if _entries_initialized:
		return {"ok": true}
	var loaded := DialogicEntryManifest.load_default()
	if not loaded.get("ok", false):
		return loaded
	var validated := DialogicEntryManifest.validate_document(loaded["value"])
	if not validated.get("ok", false):
		return validated
	_entry_document = loaded["value"]
	_entries_initialized = true
	return {"ok": true}


static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var initialized := _ensure_entries()
	if not initialized.get("ok", false):
		return initialized
	var selected := locale
	if selected.is_empty():
		selected = DEFAULT_LOCALE
	return DialogicEntryManifest.resolve_entry(_entry_document, entry_id, selected)


static func has_entry_id(entry_id: String) -> bool:
	return get_entry(entry_id).get("ok", false)


static func get_required_entry_ids() -> Array[String]:
	var ids: Array[String] = []
	var initialized := _ensure_entries()
	if not initialized.get("ok", false):
		return ids
	var records: Array = _entry_document.entries
	for record: Dictionary in records:
		ids.append(str(record["entry_id"]))
	ids.sort()
	return ids


static func get_required_master_paths(locale: String = "en") -> Array[String]:
	var out: Array[String] = []
	for entry_id in get_required_entry_ids():
		var path := str((get_entry(entry_id, locale)["value"] as Dictionary)["path"])
		if not (path in out):
			out.append(path)
	out.sort()
	return out


static func build_validation_report(locale: String = "en") -> Dictionary:
	var required := get_required_master_paths(locale)
	var existing: Array[String] = []
	var missing: Array[String] = []
	for path in required:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			existing.append(path)
		else:
			missing.append(path)
	return {
		"locale": locale,
		"entry_count": get_required_entry_ids().size(),
		"required_count": required.size(),
		"existing_count": existing.size(),
		"missing_count": missing.size(),
		"missing": missing,
	}

