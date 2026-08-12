class_name DesignAuthorityRegistry
extends RefCounted

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const PLAN_SUITE := preload("res://tools/docs/ImplementationPlanSuite.gd")
const DEFAULT_MANIFEST := "prompt_docs/metadata/design_authority_registry.v1.json"
const RECORD_KEYS := [&"id", &"kind", &"path"]
const KINDS := [&"design_specification", &"design_amendment"]
const PROJECTED_FIELDS := [
	&"id", &"kind", &"schema_version", &"decision_status",
	&"conversational_design_status", &"written_spec_status",
	&"implementation_authorized", &"amends", &"amends_path",
	&"implementation_plan_path", &"implementation_plan_status",
	&"implementation_plan_sha256",
	&"implementation_plan_suite_path", &"implementation_plan_suite_status",
	&"implementation_plan_suite_sha256",
]
const PLAN_FIELDS := [&"implementation_plan_path", &"implementation_plan_status", &"implementation_plan_sha256"]
const PLAN_SUITE_FIELDS := [&"implementation_plan_suite_path", &"implementation_plan_suite_status", &"implementation_plan_suite_sha256"]
const AUTHORITY_ID := "^spec\\.[a-z0-9_.]+$"
const AUTHORITY_PATH := "^docs/(?:design|superpowers/specs)/[^/]+\\.md$"
const SAFE_BARE := "^[A-Za-z0-9_.-]+$"
const SHA256 := "^[0-9a-f]{64}$"
const HASH_PLACEHOLDER := "^__REPLACE_WITH_CANONICAL_SHA256_[A-Z0-9_]+__$"

func validate(repository_root: String = "res://", manifest_path: String = DEFAULT_MANIFEST) -> Dictionary:
	var errors: Array[String] = []
	var root := _normalize_root(repository_root)
	var manifest_full := manifest_path if manifest_path.contains("://") or manifest_path.is_absolute_path() else root.path_join(manifest_path)
	var manifest_result := _read_strict_json(manifest_full)
	if not manifest_result.get("ok", false):
		return _result([], ["DESIGN_AUTHORITY_MANIFEST_INVALID: " + manifest_full])
	var manifest: Variant = manifest_result.get("value")
	if typeof(manifest) != TYPE_DICTIONARY or not _has_exact_keys(manifest, [&"schema_version", &"records"]):
		return _result([], ["DESIGN_AUTHORITY_MANIFEST_INVALID: top-level shape"])
	if manifest.get("schema_version") != 1 or typeof(manifest.get("records")) != TYPE_ARRAY or manifest.records.is_empty():
		return _result([], ["DESIGN_AUTHORITY_MANIFEST_INVALID: schema_version/records"])
	var records: Array[Dictionary] = []
	var ids := {}
	var paths := {}
	var input_ids: Array[String] = []
	for value: Variant in manifest.records:
		if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value, RECORD_KEYS):
			errors.append("DESIGN_AUTHORITY_MANIFEST_INVALID: record shape")
			continue
		var entry: Dictionary = value
		var id_value: Variant = entry.get("id")
		var kind_value: Variant = entry.get("kind")
		var path_value: Variant = entry.get("path")
		if (
			typeof(id_value) != TYPE_STRING
			or RegEx.create_from_string(AUTHORITY_ID).search(str(id_value)) == null
			or typeof(kind_value) != TYPE_STRING
			or StringName(kind_value) not in KINDS
			or typeof(path_value) != TYPE_STRING
			or not _is_registered_path(path_value)
		):
			errors.append("DESIGN_AUTHORITY_MANIFEST_INVALID: record values")
			continue
		var id := str(id_value)
		var path := str(path_value)
		input_ids.append(id)
		if ids.has(id):
			errors.append("DESIGN_AUTHORITY_DUPLICATE_ID: " + id)
		if paths.has(path):
			errors.append("DESIGN_AUTHORITY_DUPLICATE_PATH: " + path)
		ids[id] = true
		paths[path] = true
		var projected := _project(root, entry)
		if not projected.get("ok", false):
			for error: Variant in projected.get("errors", []):
				errors.append(str(error))
		else:
			records.append(projected.record)
	var sorted_ids := input_ids.duplicate()
	sorted_ids.sort()
	if input_ids != sorted_ids:
		errors.append("DESIGN_AUTHORITY_MANIFEST_INVALID: records must be sorted by id")
	_validate_lineage(records, errors)
	return _result(records, errors)

func _project(root: String, entry: Dictionary) -> Dictionary:
	var relative_path := str(entry.path)
	var full_path := root.path_join(relative_path)
	if not _is_regular_non_link_file(root, relative_path):
		return {"ok":false, "errors":["DESIGN_AUTHORITY_SOURCE_INVALID: " + relative_path]}
	var projection := _project_frontmatter(full_path, relative_path)
	if not projection.get("ok", false):
		return projection
	var fields: Dictionary = projection.fields
	var errors: Array[String] = []
	for required: StringName in [&"id", &"kind", &"schema_version", &"conversational_design_status", &"written_spec_status", &"implementation_authorized"]:
		if not fields.has(required):
			errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: %s missing %s" % [relative_path, required])
	if fields.get("id") != entry.id or fields.get("kind") != entry.kind or fields.get("schema_version") != 1:
		errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: registry/frontmatter mismatch " + relative_path)
	if fields.get("conversational_design_status") != "approved" or fields.get("written_spec_status") != "approved" or typeof(fields.get("implementation_authorized")) != TYPE_BOOL:
		errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: approval fields " + relative_path)
	if entry.kind == "design_amendment":
		if fields.get("decision_status") != "accepted" or typeof(fields.get("amends")) != TYPE_STRING or typeof(fields.get("amends_path")) != TYPE_STRING:
			errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: amendment fields " + relative_path)
	elif fields.has("decision_status") or fields.has("amends") or fields.has("amends_path"):
		errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: base contains amendment fields " + relative_path)
	var plan_count := 0
	for field: StringName in PLAN_FIELDS:
		if fields.has(field):
			plan_count += 1
	if plan_count != 0 and plan_count != PLAN_FIELDS.size():
		errors.append("DESIGN_AUTHORITY_PLAN_INVALID: partial binding " + relative_path)
	elif plan_count == PLAN_FIELDS.size():
		_validate_plan(root, fields, relative_path, errors)
	var suite_count := 0
	for field: StringName in PLAN_SUITE_FIELDS:
		if fields.has(field):
			suite_count += 1
	var suite_result := {}
	if suite_count != 0 and suite_count != PLAN_SUITE_FIELDS.size():
		errors.append("DESIGN_AUTHORITY_PLAN_SUITE_INVALID: partial binding " + relative_path)
	elif suite_count == PLAN_SUITE_FIELDS.size():
		suite_result = _validate_plan_suite(root, fields, relative_path, errors)
	if fields.get("implementation_authorized") == true:
		var approved_plan: bool = plan_count == PLAN_FIELDS.size() and fields.get("implementation_plan_status") == "approved"
		var approved_suite: bool = suite_count == PLAN_SUITE_FIELDS.size() and fields.get("implementation_plan_suite_status") == "approved" and bool(suite_result.get("ok", false))
		if not approved_plan and not approved_suite:
			errors.append("DESIGN_AUTHORITY_AUTHORIZATION_INVALID: " + relative_path)
	var record := {"id":str(entry.id), "kind":str(entry.kind), "path":relative_path, "fields":fields}
	if suite_result.get("ok", false):
		record["plan_suite"] = suite_result
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"record": record,
	}

func _project_frontmatter(path: String, label: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or (bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf):
		return {"ok":false, "errors":["DESIGN_AUTHORITY_SOURCE_INVALID: UTF-8 " + label]}
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	if lines.is_empty() or lines[0] != "---":
		return {"ok":false, "errors":["DESIGN_AUTHORITY_SOURCE_INVALID: frontmatter " + label]}
	var closing := -1
	for index: int in range(1, lines.size()):
		if lines[index] == "---":
			closing = index
			break
	if closing < 0:
		return {"ok":false, "errors":["DESIGN_AUTHORITY_SOURCE_INVALID: unterminated " + label]}
	var fields := {}
	var errors: Array[String] = []
	var key_pattern := RegEx.create_from_string("^([a-z][a-z0-9_]*):[ \\t]*(.*)$")
	for index: int in range(1, closing):
		var line: String = lines[index]
		var stripped := line.strip_edges()
		var match := key_pattern.search(stripped if line.begins_with(" ") or line.begins_with("\t") else line)
		if match == null:
			continue
		var key := StringName(match.get_string(1))
		if key not in PROJECTED_FIELDS:
			continue
		if line.begins_with(" ") or line.begins_with("\t") or fields.has(key):
			errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: projected field syntax %s:%d" % [label, index + 1])
			continue
		var parsed := _parse_scalar(match.get_string(2))
		if not parsed.get("ok", false):
			errors.append("DESIGN_AUTHORITY_SOURCE_INVALID: projected scalar %s:%d" % [label, index + 1])
		else:
			fields[key] = parsed.value
	return {"ok":errors.is_empty(), "fields":fields, "errors":errors}

func _parse_scalar(raw: String) -> Dictionary:
	if raw.begins_with("\"") or raw in ["true", "false"] or RegEx.create_from_string("^[0-9]+$").search(raw) != null:
		var parsed := STRICT_JSON.parse_strict_text(raw)
		return {"ok":parsed.get("ok", false), "value":parsed.get("value")}
	if RegEx.create_from_string(SAFE_BARE).search(raw) != null:
		return {"ok":true, "value":raw}
	return {"ok":false, "value":null}

func _validate_plan(root: String, fields: Dictionary, source_path: String, errors: Array[String]) -> void:
	var plan_path: Variant = fields.get("implementation_plan_path")
	var status: Variant = fields.get("implementation_plan_status")
	var digest: Variant = fields.get("implementation_plan_sha256")
	if typeof(plan_path) != TYPE_STRING or not _is_safe_relative_path(plan_path) or not str(plan_path).begins_with("docs/superpowers/plans/") or not str(plan_path).ends_with(".md"):
		errors.append("DESIGN_AUTHORITY_PLAN_INVALID: path " + source_path)
		return
	if status not in ["proposed", "approved"] or typeof(digest) != TYPE_STRING or RegEx.create_from_string(SHA256).search(digest) == null:
		errors.append("DESIGN_AUTHORITY_PLAN_INVALID: fields " + source_path)
		return
	if not _is_regular_non_link_file(root, plan_path):
		errors.append("DESIGN_AUTHORITY_PLAN_INVALID: missing " + source_path)
		return

func _validate_plan_suite(root: String, fields: Dictionary, source_path: String, errors: Array[String]) -> Dictionary:
	var suite_path: Variant = fields.get("implementation_plan_suite_path")
	var status: Variant = fields.get("implementation_plan_suite_status")
	var digest: Variant = fields.get("implementation_plan_suite_sha256")
	if (
		typeof(suite_path) != TYPE_STRING
		or not _is_safe_relative_path(suite_path)
		or not str(suite_path).begins_with("prompt_docs/metadata/")
		or not str(suite_path).ends_with(".json")
	):
		errors.append("DESIGN_AUTHORITY_PLAN_SUITE_INVALID: path " + source_path)
		return {}
	if (
		status not in ["proposed", "approved"]
		or typeof(digest) != TYPE_STRING
		or not _valid_bound_digest(str(digest), str(status))
	):
		errors.append("DESIGN_AUTHORITY_PLAN_SUITE_INVALID: fields " + source_path)
		return {}
	if not _is_regular_non_link_file(root, suite_path):
		errors.append("DESIGN_AUTHORITY_PLAN_SUITE_INVALID: missing " + source_path)
		return {}
	var suite_result: Dictionary = PLAN_SUITE.new().validate(root, suite_path, str(fields.get("id", "")))
	if not suite_result.get("ok", false):
		for error: Variant in suite_result.get("errors", []):
			errors.append(str(error))
		return {}
	if suite_result.get("status") != status:
		errors.append("DESIGN_AUTHORITY_PLAN_SUITE_INVALID: status mismatch " + source_path)
		return {}
	suite_result["path"] = str(suite_path)
	return suite_result

func _valid_bound_digest(digest: String, status: String) -> bool:
	if RegEx.create_from_string(SHA256).search(digest) != null:
		return true
	return status == "proposed" and RegEx.create_from_string(HASH_PLACEHOLDER).search(digest) != null

func _validate_lineage(records: Array[Dictionary], errors: Array[String]) -> void:
	var by_id := {}
	for record: Dictionary in records:
		by_id[record.id] = record
	for record: Dictionary in records:
		if record.kind != "design_amendment":
			continue
		var base_id := str(record.fields.get("amends", ""))
		if not by_id.has(base_id) or str(by_id[base_id].path) != str(record.fields.get("amends_path", "")) or base_id == record.id:
			errors.append("DESIGN_AUTHORITY_LINEAGE_INVALID: " + record.id)
	var colors := {}
	for record: Dictionary in records:
		_visit_lineage(record.id, by_id, colors, [], errors)

func _visit_lineage(id: String, by_id: Dictionary, colors: Dictionary, trail: Array, errors: Array[String]) -> void:
	if colors.get(id, 0) == 1:
		errors.append("DESIGN_AUTHORITY_LINEAGE_INVALID: cycle " + " -> ".join(trail + [id]))
		return
	if colors.get(id, 0) == 2:
		return
	colors[id] = 1
	var record: Dictionary = by_id.get(id, {})
	if record.get("kind") == "design_amendment":
		var next := str(record.get("fields", {}).get("amends", ""))
		if by_id.has(next):
			_visit_lineage(next, by_id, colors, trail + [id], errors)
	colors[id] = 2

func _read_strict_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false}
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or (bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf):
		return {"ok":false}
	return STRICT_JSON.parse_strict_text(text)

func _is_registered_path(path: String) -> bool:
	return _is_safe_relative_path(path) and RegEx.create_from_string(AUTHORITY_PATH).search(path) != null

func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty() or path != path.replace("\\", "/") or path.begins_with("/") or path.contains(":"):
		return false
	for segment: String in path.split("/", true):
		if segment.is_empty() or segment in [".", ".."]:
			return false
	return true

func _is_regular_non_link_file(root: String, relative_path: String) -> bool:
	if not _is_safe_relative_path(relative_path):
		return false
	var current := root
	var segments := relative_path.split("/", true)
	for index: int in range(segments.size()):
		var directory := DirAccess.open(current)
		if directory == null or directory.is_link(segments[index]):
			return false
		if index == segments.size() - 1:
			return directory.file_exists(segments[index])
		current = current.path_join(segments[index])
	return false

func _canonical_text_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return ""
	return text.replace("\r\n", "\n").replace("\r", "\n").sha256_text()

func _normalize_root(path: String) -> String:
	var normalized := path.replace("\\", "/")
	while normalized.ends_with("/") and not normalized.ends_with("://"):
		normalized = normalized.trim_suffix("/")
	return normalized

func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(str(key)):
			return false
	return true

func _result(records: Array[Dictionary], errors: Array[String]) -> Dictionary:
	return {"ok":errors.is_empty(), "records":records, "errors":errors}
