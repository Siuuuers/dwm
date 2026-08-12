class_name ImplementationPlanSuite
extends RefCounted

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const TOP_LEVEL_KEYS := [&"schema_version", &"specification_id", &"status", &"roadmap", &"plans"]
const PLAN_KEYS := [&"path", &"status", &"sha256"]
const STATUSES := [&"proposed", &"approved"]
const SPECIFICATION_ID := "^spec\\.[a-z0-9_.]+$"
const PLAN_PATH := "^docs/superpowers/plans/[^/]+\\.md$"
const SHA256 := "^[0-9a-f]{64}$"
const HASH_PLACEHOLDER := "^__REPLACE_WITH_CANONICAL_SHA256_[A-Z0-9_]+__$"

func validate(repository_root: String, suite_path: String, expected_specification_id: String = "") -> Dictionary:
	var errors: Array[String] = []
	var root := _normalize_root(repository_root)
	var full_path := suite_path if suite_path.contains("://") or suite_path.is_absolute_path() else root.path_join(suite_path)
	var parsed := _read_strict_json(full_path)
	if not parsed.get("ok", false):
		return _result("", [], ["IMPLEMENTATION_PLAN_SUITE_INVALID: " + suite_path])
	var value: Variant = parsed.get("value")
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value, TOP_LEVEL_KEYS):
		return _result("", [], ["IMPLEMENTATION_PLAN_SUITE_INVALID: top-level shape"])
	var suite: Dictionary = value
	var specification_id: Variant = suite.get("specification_id")
	var status: Variant = suite.get("status")
	if (
		suite.get("schema_version") != 1
		or typeof(specification_id) != TYPE_STRING
		or RegEx.create_from_string(SPECIFICATION_ID).search(specification_id) == null
		or (not expected_specification_id.is_empty() and specification_id != expected_specification_id)
		or typeof(status) != TYPE_STRING
		or StringName(status) not in STATUSES
		or typeof(suite.get("roadmap")) != TYPE_DICTIONARY
		or typeof(suite.get("plans")) != TYPE_ARRAY
		or suite.plans.is_empty()
	):
		errors.append("IMPLEMENTATION_PLAN_SUITE_INVALID: fields")
	var records: Array[Dictionary] = []
	var seen_paths := {}
	var roadmap := _validate_record(root, suite.get("roadmap"), str(status), "roadmap", errors)
	if not roadmap.is_empty():
		records.append(roadmap)
		seen_paths[roadmap.path] = true
	var input_paths: Array[String] = []
	if typeof(suite.get("plans")) == TYPE_ARRAY:
		for plan_value: Variant in suite.plans:
			var plan := _validate_record(root, plan_value, str(status), "plan", errors)
			if plan.is_empty():
				continue
			input_paths.append(plan.path)
			if seen_paths.has(plan.path):
				errors.append("IMPLEMENTATION_PLAN_SUITE_INVALID: duplicate path " + plan.path)
			else:
				seen_paths[plan.path] = true
				records.append(plan)
	var sorted_paths := input_paths.duplicate()
	sorted_paths.sort()
	if input_paths != sorted_paths:
		errors.append("IMPLEMENTATION_PLAN_SUITE_INVALID: plans must be sorted by path")
	return _result(str(status), records, errors)

func _validate_record(root: String, value: Variant, suite_status: String, role: String, errors: Array[String]) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value, PLAN_KEYS):
		errors.append("IMPLEMENTATION_PLAN_SUITE_INVALID: %s shape" % role)
		return {}
	var record: Dictionary = value
	var path: Variant = record.get("path")
	var status: Variant = record.get("status")
	var digest: Variant = record.get("sha256")
	if (
		typeof(path) != TYPE_STRING
		or not _is_safe_relative_path(path)
		or RegEx.create_from_string(PLAN_PATH).search(path) == null
		or typeof(status) != TYPE_STRING
		or StringName(status) not in STATUSES
		or (suite_status == "approved" and status != "approved")
		or typeof(digest) != TYPE_STRING
		or not _valid_digest(digest, str(status))
	):
		errors.append("IMPLEMENTATION_PLAN_SUITE_INVALID: %s fields" % role)
		return {}
	if not _is_regular_non_link_file(root, path):
		errors.append("IMPLEMENTATION_PLAN_SUITE_INVALID: missing " + str(path))
		return {}
	return {"path":str(path), "status":str(status), "sha256":str(digest), "role":role}

func _valid_digest(digest: String, status: String) -> bool:
	if RegEx.create_from_string(SHA256).search(digest) != null:
		return true
	return status == "proposed" and RegEx.create_from_string(HASH_PLACEHOLDER).search(digest) != null

func _read_strict_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false}
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or (bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf):
		return {"ok":false}
	return STRICT_JSON.parse_strict_text(text)

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

func _result(status: String, records: Array[Dictionary], errors: Array[String]) -> Dictionary:
	return {"ok":errors.is_empty(), "status":status, "records":records, "errors":errors}
