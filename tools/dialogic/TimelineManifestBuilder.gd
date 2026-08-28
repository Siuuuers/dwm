extends RefCounted
## Builds the exact timeline manifest from the physical .dtl files (dwm-p2r.8, Plan-05 Task 1).
## One record per physical file, fingerprinted from the exact file bytes. No broad filename
## inference: the manifest IS the registry the catalog later consumes.

const TIMELINE_ROOT := "res://dialogic/timelines/en"


static func build() -> Dictionary:
	var files := _list_dtl_files(TIMELINE_ROOT)
	if files.is_empty():
		return {"ok": false, "code": &"no_timeline_files", "message": "no .dtl files under " + TIMELINE_ROOT}
	files.sort()
	var records: Array = []
	var seen_ids := {}
	for path in files:
		var parsed := _parse_file(path)
		if not parsed.get("ok", false):
			return parsed
		var record: Dictionary = parsed["value"]
		var id := str(record["id"])
		if seen_ids.has(id):
			return {"ok": false, "code": &"duplicate_timeline_id", "message": id}
		seen_ids[id] = true
		records.append(record)
	records.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return {"ok": true, "value": {"schema_version": 1, "locale": "en", "records": records}}


static func build_inventory(manifest: Dictionary) -> Dictionary:
	var files: Array = []
	var placeholder := 0
	var draft := 0
	for record in manifest.get("records", []):
		files.append({"id": str(record["id"]), "path": str(record["path"]), "content_status": str(record["content_status"])})
		match str(record["content_status"]):
			"placeholder": placeholder += 1
			"draft": draft += 1
	files.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
	return {
		"schema_version": 1, "locale": "en", "count": files.size(),
		"placeholder_count": placeholder, "draft_count": draft, "files": files,
	}


## Lists the LEGACY timelines only: those in SUBDIRECTORIES of the locale root.
##
## RULING O (Seven-Day Flow Plan 01 Task 3, dwm-oyo.2 DEVIATION-7). The eight plot-neutral master
## timelines Task 3 generates live DIRECTLY in the locale root; every one of the 61 legacy
## timelines lives in a subdirectory of it (contacts/, core/, dating/, ending/). That partition is
## the invariant this function now enforces, and it is why timelines.json stays at 61 records even
## if this Plan-05 generator is re-run after Task 3.
##
## THIS IS NOT COSMETIC. Collecting the masters here would take timelines.json from 61 records to
## 69, which breaks WriteDialogicGateSummary's 61/24/37 production floor inside the FROZEN tooling
## gate, breaks test_timeline_manifest.gd, and stales the sealed manifest_hashes in
## evidence/phase_2r/dialogic/gate_summary.json. It would also fail outright, because _parse_file
## demands a `# timeline_id:` header the masters deliberately do not carry.
##
## tests/unit/test_dtl_master_structure.gd is the only coverage this function has; before Task 3
## nothing in the repository exercised it at all.
static func _list_dtl_files(root: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and name != "." and name != "..":
			out.append_array(_collect_dtl_files(root + "/" + name))
		name = dir.get_next()
	dir.list_dir_end()
	return out


## Collects every .dtl at or below a legacy subdirectory. Legacy timelines nest more than one
## level deep (dating/solo/...), so this stays fully recursive.
static func _collect_dtl_files(root: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				out.append_array(_collect_dtl_files(root + "/" + name))
		elif name.ends_with(".dtl"):
			out.append(root + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	return out


static func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": &"missing_file", "message": path}
	var text := FileAccess.get_file_as_string(path)
	var sha := FileAccess.get_sha256(path)
	if sha.is_empty():
		return {"ok": false, "code": &"fingerprint_failed", "message": path}
	var id := ""
	var locale := ""
	var type_name := ""
	var labels: Array = []
	for raw_line in text.split("\n"):
		var line := (raw_line as String).strip_edges()
		if line.begins_with("#"):
			var body := line.substr(1).strip_edges()
			var colon := body.find(":")
			if colon > 0:
				var key := body.substr(0, colon).strip_edges()
				var value := body.substr(colon + 1).strip_edges()
				match key:
					"timeline_id": id = value
					"locale": locale = value
					"type": type_name = value
		elif line.begins_with("label "):
			labels.append(line.substr(6).strip_edges())
	if id.is_empty():
		return {"ok": false, "code": &"missing_timeline_id", "message": path}
	if locale != "en":
		return {"ok": false, "code": &"non_en_locale", "message": path + " locale=" + locale}
	var status := "placeholder" if "TODO" in text else "draft"
	var ending_ids: Array = labels.duplicate() if type_name == "ending" else []
	return {"ok": true, "value": {
		"id": id,
		"locale": "en",
		"path": path.trim_prefix("res://"),
		"content_status": status,
		"content_fingerprint": "sha256:" + sha,
		"labels": labels,
		"lines": [],
		"markers": [],
		"effect_ids": [],
		"variable_ids": [],
		"route_ids": [],
		"ending_ids": ending_ids,
		"events": [],
	}}
