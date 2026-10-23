class_name AgentWorkflowAuthorityResolver
extends RefCounted

const DOC_VALIDATOR := preload("res://tools/docs/DocValidator.gd")
const DESIGN_REGISTRY := preload("res://tools/docs/DesignAuthorityRegistry.gd")
const LINK_KINDS := [&"beads_issue", &"requirement_id", &"specification_id", &"decision_id", &"plan_path"]

var _repository_root: String
var _beads_by_id := {}
var _beads_source_valid := true
var _packet_result: Dictionary
var _design_result: Dictionary
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
	_design_result = DESIGN_REGISTRY.new().validate(_repository_root, _path(DESIGN_REGISTRY.DEFAULT_MANIFEST))
	_spec_records.assign(_design_result.get("records", []))

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
	if not _design_result.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"specification_id", "target":target, "errors":_design_result.get("errors", [])})
	var matches: Array = _spec_records.filter(func(record: Dictionary) -> bool: return record.get("fields", {}).get("id") == target)
	return _unique_approved(matches, target, &"specification_id", func(record: Dictionary) -> bool:
		var fields: Dictionary = record.get("fields", {})
		return fields.get("conversational_design_status") == "approved" and fields.get("written_spec_status") == "approved" and (record.get("kind") != "design_amendment" or fields.get("decision_status") == "accepted")
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
	if not _design_result.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"plan_path", "target":target, "errors":_design_result.get("errors", [])})
	var path := _path(target)
	if not _is_regular_non_link_file(path):
		return _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind": "plan_path", "target": target})
	var matches: Array[Dictionary] = []
	for record: Dictionary in _spec_records:
		var fields: Dictionary = record.get("fields", {})
		if fields.get("implementation_plan_path") == target:
			matches.append({
				"record":record,
				"binding_status":str(fields.get("implementation_plan_status", "")),
				"binding_sha256":str(fields.get("implementation_plan_sha256", "")),
				"suite":{},
			})
		var suite: Dictionary = record.get("plan_suite", {})
		for suite_record: Dictionary in suite.get("records", []):
			if suite_record.get("path") == target:
				matches.append({
					"record":record,
					"binding_status":str(suite_record.get("status", "")),
					"binding_sha256":str(suite_record.get("sha256", "")),
					"suite":suite,
				})
	if matches.size() != 1:
		return _failure(&"AUTHORITY_LINK_UNKNOWN" if matches.is_empty() else &"AUTHORITY_LINK_DUPLICATE_TARGET", {"kind": "plan_path", "target": target})
	var match_record: Dictionary = matches[0]
	var record: Dictionary = match_record.record
	var approved: bool = (
		record.fields.get("conversational_design_status") == "approved"
		and record.fields.get("written_spec_status") == "approved"
		and match_record.binding_status == "approved"
		and (record.get("kind") != "design_amendment" or record.fields.get("decision_status") == "accepted")
	)
	var suite: Dictionary = match_record.suite
	if not suite.is_empty():
		approved = (
			approved
			and suite.get("status") == "approved"
			and record.fields.get("implementation_plan_suite_status") == "approved"
		)
		var suite_digest := _canonical_text_sha256(_path(str(suite.get("path", ""))))
		approved = (
			approved
			and suite_digest.get("ok", false)
			and record.fields.get("implementation_plan_suite_sha256") == suite_digest.get("value")
		)
		var every_member_matches := true
		for suite_member: Dictionary in suite.get("records", []):
			var member_digest := _canonical_text_sha256(_path(str(suite_member.get("path", ""))))
			if not member_digest.get("ok", false):
				return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"plan_path", "target":target})
			if str(suite_member.get("sha256", "")) != str(member_digest.get("value", "")):
				every_member_matches = false
		approved = approved and every_member_matches
	var digest_result := _canonical_text_sha256(path)
	if not digest_result.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind": "plan_path", "target": target})
	var digest_matches: bool = match_record.binding_sha256 == digest_result.get("value")
	return _success(&"plan_path", target) if approved and digest_matches else _failure(&"AUTHORITY_LINK_UNAPPROVED", {"kind": "plan_path", "target": target})

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
