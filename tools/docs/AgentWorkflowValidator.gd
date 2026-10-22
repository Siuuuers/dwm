class_name AgentWorkflowValidator
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const HANDOFF_PATH := "docs/agent/2026-09-23-next-session-handoff.md"
const MAP_PATH := "docs/agent/execution-map.md"
const NAVIGATION_FIELDS := {
	"schema_version": 1,
	"document_role": "navigation_only",
	"execution_authority": false,
	"status_authority": false,
	"behavior_authority": false,
	"verification_authority": false,
}

## These files locate current work; they do not grant permission, replace Beads,
## or redefine approved design. Their prose and current task selection may evolve
## without reviving the retired prompt's hash-bound task selector.
func validate_files(repository_root: String = "res://") -> Dictionary:
	var root := _normalize_root(repository_root)
	if root.is_empty():
		return _result(["AGENT_WORKFLOW_ROOT_INVALID"])
	var handoff := _read_document(root, HANDOFF_PATH)
	if not handoff.ok:
		return _result(handoff.errors)
	var map := _read_document(root, MAP_PATH)
	if not map.ok:
		return _result(map.errors)
	return validate_pair(handoff.text, map.text)

func validate_pair(handoff_text: String, map_text: String) -> Dictionary:
	var errors: Array[String] = []
	var handoff := FRONTMATTER.parse_text(handoff_text, HANDOFF_PATH)
	var map := FRONTMATTER.parse_text(map_text, MAP_PATH)
	if not handoff.ok:
		errors.append("AGENT_WORKFLOW_HANDOFF_INVALID: " + JSON.stringify(handoff.errors))
	if not map.ok:
		errors.append("AGENT_WORKFLOW_MAP_INVALID: " + JSON.stringify(map.errors))
	if not errors.is_empty():
		return _result(errors)
	var handoff_expected: Dictionary = NAVIGATION_FIELDS.duplicate()
	handoff_expected.merge({"document_id": "dwm_current_handoff", "execution_map": MAP_PATH, "issue_authority": "beads"})
	_validate_fields(handoff.frontmatter, handoff_expected, "handoff", errors)
	var map_expected: Dictionary = NAVIGATION_FIELDS.duplicate()
	map_expected.merge({"document_id": "dwm_execution_map", "inspected_source": map.frontmatter.get("inspected_source", null)})
	_validate_fields(map.frontmatter, map_expected, "execution map", errors)
	var inspected_source: Variant = map.frontmatter.get("inspected_source", null)
	if typeof(inspected_source) != TYPE_STRING or RegEx.create_from_string("^[0-9a-f]{40}$").search(inspected_source) == null:
		errors.append("AGENT_WORKFLOW_MAP_INVALID: inspected_source")
	var pointer: Variant = handoff.frontmatter.get("execution_map", null)
	if typeof(pointer) != TYPE_STRING or not _is_safe_relative_path(pointer) or pointer != MAP_PATH:
		errors.append("AGENT_WORKFLOW_POINTER_INVALID: execution_map")
	return _result(errors)

func _validate_fields(actual: Dictionary, expected: Dictionary, label: String, errors: Array[String]) -> void:
	if actual.size() != expected.size():
		errors.append("AGENT_WORKFLOW_FIELDS_INVALID: " + label)
	for key: String in expected:
		var value: Variant = actual.get(key, null)
		if not actual.has(key) or typeof(value) != typeof(expected[key]) or value != expected[key]:
			errors.append("AGENT_WORKFLOW_AUTHORITY_INVALID: %s.%s" % [label, key])

func _read_document(repository_root: String, relative_path: String) -> Dictionary:
	var errors: Array[String] = []
	if not _is_regular_non_link_file(repository_root, relative_path):
		errors.append("AGENT_WORKFLOW_SOURCE_INVALID: " + relative_path)
		return {"ok": false, "errors": errors, "text": ""}
	var file := FileAccess.open(repository_root.path_join(relative_path), FileAccess.READ)
	if file == null:
		errors.append("AGENT_WORKFLOW_SOURCE_INVALID: " + relative_path)
		return {"ok": false, "errors": errors, "text": ""}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var source := bytes.get_string_from_utf8()
	if source.to_utf8_buffer() != bytes:
		errors.append("AGENT_WORKFLOW_UTF8_INVALID: " + relative_path)
	return {"ok": errors.is_empty(), "errors": errors, "text": source}

func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty() or path.contains("\\") or path.begins_with("/") or path.contains(":"):
		return false
	for segment: String in path.split("/", true):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true

func _is_regular_non_link_file(repository_root: String, relative_path: String) -> bool:
	if not _is_safe_relative_path(relative_path):
		return false
	var current := repository_root
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
	if path.is_empty():
		return ""
	var root := ProjectSettings.globalize_path(path).replace("\\", "/")
	if not root.is_absolute_path():
		return ""
	while root.ends_with("/") and root != "/" and not root.ends_with(":/"):
		root = root.trim_suffix("/")
	for segment: String in root.split("/", true):
		if segment == "." or segment == "..":
			return ""
	if not DirAccess.dir_exists_absolute(root):
		return ""
	var current := root
	while true:
		var parent_path := current.get_base_dir()
		var name := current.get_file()
		if parent_path == current or name.is_empty():
			break
		var parent := DirAccess.open(parent_path)
		if parent == null or parent.is_link(name):
			return ""
		current = parent_path
	return root

func _result(errors: Array[String]) -> Dictionary:
	return {"ok": errors.is_empty(), "errors": errors}
