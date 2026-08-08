class_name DialogicTimelineCatalog
extends RefCounted
# Manifest-backed timeline catalog (dwm-p2r.8, Plan-05 Task 1). Timeline IDs resolve to physical
# .dtl locators through the exact data/manifests/timelines.json registry, never through broad
# filename inference. Do NOT execute timeline data; do NOT trust save data to choose paths.

const DEFAULT_MANIFEST_PATH := "res://data/manifests/timelines.json"
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

# Only English narrative records exist; language selection never manufactures zh_CN/zh_HK paths.
const SUPPORTED_LOCALES := ["en"]
const DEFAULT_LOCALE := "en"

static var _records: Dictionary = {}
static var _initialized := false
static var _manifest_path := ""


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


static func get_line_record(timeline_id: String, line_id: String) -> Dictionary:
	_ensure()
	if not _records.has(timeline_id):
		return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
	for line in (_records[timeline_id] as Dictionary).get("lines", []):
		if typeof(line) == TYPE_DICTIONARY and str((line as Dictionary).get("id", "")) == line_id:
			return {"ok": true, "value": (line as Dictionary).duplicate(true)}
	return {"ok": false, "code": &"unknown_line_id", "message": line_id}


static func get_event_record(timeline_id: String, event_id: String) -> Dictionary:
	_ensure()
	if not _records.has(timeline_id):
		return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
	for event in (_records[timeline_id] as Dictionary).get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("event_id", "")) == event_id:
			return {"ok": true, "value": (event as Dictionary).duplicate(true)}
	return {"ok": false, "code": &"unknown_event_id", "message": event_id}


static func validate_successor(timeline_id: String, event_id: String, post_event_id: Variant, choice_id: Variant = null) -> Dictionary:
	var event := get_event_record(timeline_id, event_id)
	if not event.get("ok", false):
		return event
	var record: Dictionary = event["value"]
	var expected: Variant = record.get("post_event_id")
	if choice_id != null:
		var successors: Dictionary = record.get("choice_successors", {})
		if not successors.has(str(choice_id)):
			return {"ok": false, "code": &"unknown_choice_id", "message": str(choice_id)}
		expected = successors[str(choice_id)]
	if post_event_id == null and expected == null:
		return {"ok": true, "value": {"terminal": true}}
	if str(post_event_id) != str(expected):
		return {"ok": false, "code": &"illegal_successor", "message": "%s != %s" % [str(post_event_id), str(expected)]}
	return {"ok": true, "value": {"post_event_id": str(expected)}}


static func validate_all() -> Dictionary:
	_ensure()
	if _records.is_empty():
		return {"ok": false, "code": &"manifest_missing", "message": _manifest_path if _manifest_path != "" else DEFAULT_MANIFEST_PATH}
	for id in _records:
		var res_path := "res://" + str((_records[id] as Dictionary).get("path", ""))
		if not (ResourceLoader.exists(res_path) or FileAccess.file_exists(res_path)):
			return {"ok": false, "code": &"missing_timeline_file", "message": res_path}
	return {"ok": true, "value": {"count": _records.size()}}


# --- Backward-compatible surface consumed by DialogicBridge until Task 2 rewires it ---

static func get_supported_locales() -> Array[String]:
	var out: Array[String] = []
	out.assign(SUPPORTED_LOCALES)
	return out


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
