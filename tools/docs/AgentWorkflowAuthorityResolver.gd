class_name AgentWorkflowAuthorityResolver
extends RefCounted

const DOC_VALIDATOR := preload("res://tools/docs/DocValidator.gd")
const LINK_KINDS := [&"beads_issue", &"requirement_id", &"specification_id", &"decision_id", &"plan_path"]
const SPEC_FIELDS := [&"id", &"conversational_design_status", &"written_spec_status", &"implementation_plan_path", &"implementation_plan_status", &"implementation_plan_sha256"]

var _repository_root: String
var _beads_by_id := {}
var _beads_source_valid := true
var _packet_result: Dictionary
var _spec_records: Array[Dictionary] = []

func _init(repository_root: String = "res://", beads_snapshot: Array[Dictionary] = []) -> void:
	_repository_root = repository_root.replace("\\", "/")
	while _repository_root.ends_with("/") and not _repository_root.ends_with("://"):
		_repository_root = _repository_root.trim_suffix("/")
	for issue: Dictionary in beads_snapshot:
		var issue_id := str(issue.get("id", ""))
		if issue_id.is_empty() or _beads_by_id.has(issue_id):
			_beads_source_valid = false
		else:
			_beads_by_id[issue_id] = issue.duplicate(true)
	_packet_result = DOC_VALIDATOR.new().validate_tree(_path("prompt_docs"), beads_snapshot, _repository_root)
	_spec_records = _project_specifications(_path("docs/superpowers/specs"))

func resolve(link: Dictionary) -> Dictionary:
	if link.keys().size() != 2 or not link.has("kind") or not link.has("target"):
		return _failure(&"AUTHORITY_LINK_INVALID", {})
	if typeof(link.kind) != TYPE_STRING or typeof(link.target) != TYPE_STRING:
		return _failure(&"AUTHORITY_LINK_INVALID", {})
	var kind := StringName(link.kind)
	var target := str(link.target)
	if kind not in LINK_KINDS or target.is_empty():
		return _failure(&"AUTHORITY_LINK_INVALID", {"kind": str(kind), "target": target})
	match kind:
		&"beads_issue":
			if not _beads_source_valid:
				return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": str(kind), "target": target})
			return _success(kind, target) if _beads_by_id.has(target) else _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind": str(kind), "target": target})
		&"requirement_id":
			return _resolve_requirement(target)
		&"specification_id":
			return _resolve_specification(target)
		&"decision_id":
			return _resolve_decision(target)
		&"plan_path":
			return _resolve_plan(target)
	return _failure(&"AUTHORITY_LINK_INVALID", {})

func _resolve_requirement(target: String) -> Dictionary:
	if not _packet_result.get("packet_source_valid", true) or not _packet_result.get("index_valid", true):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "requirement_id", "target": target, "errors": _packet_result.get("errors", [])})
	var matches: Array = _packet_result.get("requirements", []).filter(func(requirement: Dictionary) -> bool: return requirement.get("id") == target)
	if matches.size() == 1 and _packet_path_is_invalid(str(matches[0].get("path", ""))):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "requirement_id", "target": target, "errors": _packet_result.get("errors", [])})
	return _unique_approved(matches, target, &"requirement_id", func(requirement: Dictionary) -> bool: return requirement.get("specification_status") == "approved")

func _resolve_specification(target: String) -> Dictionary:
	var matches: Array = _spec_records.filter(func(record: Dictionary) -> bool: return record.get("fields", {}).get("id") == target)
	return _unique_approved(matches, target, &"specification_id", func(record: Dictionary) -> bool:
		return record.get("ok", false) and record.fields.get("conversational_design_status") == "approved" and record.fields.get("written_spec_status") == "approved"
	)

func _resolve_decision(target: String) -> Dictionary:
	if not _packet_result.get("packet_source_valid", true) or not _packet_result.get("index_valid", true):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "decision_id", "target": target, "errors": _packet_result.get("errors", [])})
	var matches: Array = _packet_result.get("packets", []).filter(func(front: Dictionary) -> bool: return front.get("id") == target and front.get("kind") == "decision_packet")
	if matches.size() == 1 and _packet_path_is_invalid(str(matches[0].get("path", ""))):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "decision_id", "target": target, "errors": _packet_result.get("errors", [])})
	return _unique_approved(matches, target, &"decision_id", func(front: Dictionary) -> bool:
		return front.get("specification_status") == "approved" and front.get("decision_status") == "accepted"
	)

func _resolve_plan(target: String) -> Dictionary:
	if not _is_safe_relative_path(target) or not target.begins_with("docs/superpowers/plans/") or not target.ends_with(".md"):
		return _failure(&"AUTHORITY_LINK_INVALID", {"kind": "plan_path", "target": target})
	var path := _path(target)
	if not _is_regular_non_link_file(path):
		return _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind": "plan_path", "target": target})
	var matches: Array = _spec_records.filter(func(record: Dictionary) -> bool: return record.get("fields", {}).get("implementation_plan_path") == target)
	if matches.size() != 1:
		return _failure(&"AUTHORITY_LINK_UNKNOWN" if matches.is_empty() else &"AUTHORITY_LINK_DUPLICATE_TARGET", {"kind": "plan_path", "target": target})
	var record: Dictionary = matches[0]
	if not record.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "plan_path", "target": target})
	var approved: bool = record.fields.get("conversational_design_status") == "approved" and record.fields.get("written_spec_status") == "approved" and record.fields.get("implementation_plan_status") == "approved"
	var digest_result := _canonical_text_sha256(path)
	if not digest_result.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "plan_path", "target": target})
	var digest_matches: bool = record.fields.get("implementation_plan_sha256") == digest_result.get("value")
	return _success(&"plan_path", target) if approved and digest_matches else _failure(&"AUTHORITY_LINK_UNAPPROVED", {"kind": "plan_path", "target": target})

func _project_specifications(root: String) -> Array[Dictionary]:
	var paths: Array[String] = []
	_collect_markdown(root, paths)
	paths.sort()
	var records: Array[Dictionary] = []
	for path: String in paths:
		records.append(_project_frontmatter(path))
	return records

func _project_frontmatter(path: String) -> Dictionary:
	var fields := {}
	if not _is_regular_non_link_file(path):
		return {"ok": false, "fields": fields, "path": path}
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or (bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf):
		return {"ok": false, "fields": fields, "path": path}
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	if lines.is_empty() or lines[0] != "---":
		return {"ok": false, "fields": fields, "path": path}
	var closing := lines.size()
	for index: int in range(1, lines.size()):
		if lines[index] == "---":
			closing = index
			break
	var valid := closing < lines.size()
	var bare_value := RegEx.create_from_string("^[A-Za-z0-9_.-]+$")
	var key_line := RegEx.create_from_string("^([A-Za-z0-9_.-]+):[ \\t]*(.*)$")
	for index: int in range(1, closing):
		var line: String = lines[index]
		var candidate_key := ""
		if line.begins_with(" ") or line.begins_with("\t"):
			var indented_match := key_line.search(line.strip_edges())
			if indented_match != null and StringName(indented_match.get_string(1)) in SPEC_FIELDS:
				valid = false
			continue
		var match := key_line.search(line)
		if match == null:
			continue
		candidate_key = match.get_string(1)
		var key := StringName(candidate_key)
		if key not in SPEC_FIELDS:
			continue
		var raw_value := match.get_string(2)
		if fields.has(key) or raw_value.is_empty():
			valid = false
			continue
		var value := ""
		if raw_value.begins_with("\""):
			var json := JSON.new()
			if json.parse(raw_value) != OK or typeof(json.data) != TYPE_STRING or String(json.data).is_empty():
				valid = false
				continue
			value = json.data
		elif bare_value.search(raw_value) != null:
			value = raw_value
		else:
			valid = false
			continue
		fields[key] = value
	for required: StringName in SPEC_FIELDS:
		if not fields.has(required):
			valid = false
	return {"ok": valid, "fields": fields, "path": path}

func _collect_markdown(path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name.begins_with(".") or directory.is_link(name):
			continue
		var child := path.path_join(name)
		if directory.current_is_dir():
			_collect_markdown(child, output)
		elif name.ends_with(".md"):
			output.append(child)
	directory.list_dir_end()

func _unique_approved(matches: Array, target: String, kind: StringName, approved: Callable) -> Dictionary:
	if matches.is_empty():
		return _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind": str(kind), "target": target})
	if matches.size() != 1:
		return _failure(&"AUTHORITY_LINK_DUPLICATE_TARGET", {"kind": str(kind), "target": target})
	var match: Dictionary = matches[0]
	if not match.get("ok", true):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": str(kind), "target": target})
	return _success(kind, target) if approved.call(match) else _failure(&"AUTHORITY_LINK_UNAPPROVED", {"kind": str(kind), "target": target})

func _packet_path_is_invalid(path: String) -> bool:
	if path.is_empty():
		return true
	var invalid_paths: Variant = _packet_result.get("invalid_packet_paths", [])
	return typeof(invalid_paths) == TYPE_ARRAY and path.replace("\\", "/") in invalid_paths

func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty() or path != path.replace("\\", "/") or path.begins_with("/") or path.contains(":"):
		return false
	for segment: String in path.split("/", true):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true

func _is_regular_non_link_file(path: String) -> bool:
	var normalized := path.replace("\\", "/")
	var root := _repository_root
	if not normalized.begins_with(root):
		return false
	var relative := normalized.trim_prefix(root).trim_prefix("/")
	if not _is_safe_relative_path(relative):
		return false
	var current := root
	var parts := relative.split("/", true)
	for index: int in range(parts.size()):
		var directory := DirAccess.open(current)
		if directory == null or directory.is_link(parts[index]):
			return false
		if index == parts.size() - 1:
			return directory.file_exists(parts[index])
		current = current.path_join(parts[index])
	return false

func _canonical_text_sha256(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes or (bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf):
		return {"ok": false}
	return {"ok": true, "value": text.replace("\r\n", "\n").replace("\r", "\n").sha256_text()}

func _path(relative: String) -> String:
	return _repository_root.path_join(relative)

func _success(kind: StringName, target: String) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"kind": str(kind), "target": target}, "receipt": {}}

func _failure(code: StringName, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "details": details, "receipt": {}}
