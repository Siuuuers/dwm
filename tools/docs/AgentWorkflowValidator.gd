class_name AgentWorkflowValidator
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const RESOLVER := preload("res://tools/docs/AgentWorkflowAuthorityResolver.gd")
const GUIDE_PATH := "docs/agent/AGENT_WORKFLOW.md"
const GUIDE_FIELDS := [&"schema_version", &"document_id", &"document_role", &"execution_authority", &"status_authority", &"behavior_authority", &"verification_authority", &"capability_intentions"]
const AUTHORITY_VALUES := {&"document_role":"navigation_only", &"execution_authority":false, &"status_authority":false, &"behavior_authority":false, &"verification_authority":false}
const DECISION_ROWS := {
	"commit_parent_open":"Report the bounded commit; report the parent as open.",
	"one_ready_issue":"Inspect the issue and its dependencies; mutate only with scope-matched permission.",
	"multiple_active_ambiguous":"Stop, list the issue IDs, and request one selection.",
	"intention_links_empty":"Treat it as intent only and request design authority.",
	"authority_link_broken":"Stop and identify the broken link.",
	"design_without_plan":"Do not implement; prepare a plan only when requested.",
	"plan_without_permission":"Stop and request exact execution permission.",
	"ignored_script":"Treat verification as failed, fix discovery, and rerun.",
	"child_closed_parent_open":"Report the child closed and the parent open.",
}
const NUMBERED_PHASE_PATTERN := "(?i)\\bphase(?:\\s+|[-_])?[0-9]+[a-z0-9._-]*\\b"
const PLACEHOLDER_PATTERN := "(?i)\\b(?:TBD|TODO|FIXME|XXX|My first issue)\\b"
const INTENTION_ID_PATTERN := "^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"
const DECISION_HEADING := "## Decision table"
const DECISION_HEADER := "| decision_id | exact action |"
const DECISION_SEPARATOR := "|---|---|"

func validate_files(prompt_path: String = "res://Prompt.md", beads_snapshot: Array[Dictionary] = []) -> Dictionary:
	var prompt := FRONTMATTER.parse_file(prompt_path)
	if not prompt.ok:
		return _result(["AGENT_WORKFLOW_PROMPT_INVALID: " + JSON.stringify(prompt.errors)])
	var pointer: Variant = prompt.frontmatter.get("agent_workflow_guide", null)
	if typeof(pointer) != TYPE_STRING or not _is_safe_relative_path(pointer) or pointer != GUIDE_PATH:
		return _result(["AGENT_WORKFLOW_POINTER_INVALID: " + str(pointer)])
	var repository_root := _normalize_root(prompt_path.get_base_dir())
	if repository_root.is_empty() or not _is_regular_non_link_file(repository_root, pointer):
		return _result(["AGENT_WORKFLOW_POINTER_INVALID: " + str(pointer)])
	var prompt_source := _read_utf8(prompt_path)
	if not prompt_source.ok:
		return _result(["AGENT_WORKFLOW_PROMPT_INVALID: " + prompt_path])
	var guide_path := repository_root.path_join(pointer)
	var guide_source := _read_utf8(guide_path)
	if not guide_source.ok:
		return _result(["AGENT_WORKFLOW_GUIDE_INVALID: " + guide_path])
	var resolver: RefCounted = RESOLVER.new(repository_root, beads_snapshot)
	return validate_pair(prompt_source.text, guide_source.text, resolver)

func validate_pair(prompt_text: String, guide_text: String, resolver: RefCounted = null) -> Dictionary:
	var errors: Array[String] = []
	var prompt := FRONTMATTER.parse_text(prompt_text, "Prompt.md")
	if not prompt.ok:
		errors.append("AGENT_WORKFLOW_PROMPT_INVALID: " + JSON.stringify(prompt.errors))
		return {"ok":false, "errors":errors}
	if prompt.frontmatter.get("agent_workflow_guide") != GUIDE_PATH:
		errors.append("AGENT_WORKFLOW_POINTER_INVALID: " + str(prompt.frontmatter.get("agent_workflow_guide", "")))
	var guide := FRONTMATTER.parse_text(guide_text, GUIDE_PATH)
	if not guide.ok:
		errors.append("AGENT_WORKFLOW_GUIDE_INVALID: " + JSON.stringify(guide.errors))
		return {"ok":false, "errors":errors}
	_validate_frontmatter(guide.frontmatter, resolver, errors)
	_validate_text(guide_text, guide.body, errors)
	return {"ok":errors.is_empty(), "errors":errors}

func _validate_frontmatter(frontmatter: Dictionary, resolver: RefCounted, errors: Array[String]) -> void:
	if not _has_exact_keys(frontmatter, GUIDE_FIELDS):
		errors.append("AGENT_WORKFLOW_GUIDE_INVALID: frontmatter fields")
	if frontmatter.get("schema_version") != 1:
		errors.append("AGENT_WORKFLOW_GUIDE_INVALID: schema_version")
	if frontmatter.get("document_id") != "agent_workflow":
		errors.append("AGENT_WORKFLOW_GUIDE_INVALID: document_id")
	for key: Variant in AUTHORITY_VALUES.keys():
		if frontmatter.get(str(key)) != AUTHORITY_VALUES[key]:
			errors.append("AGENT_WORKFLOW_AUTHORITY_INVALID: %s" % str(key))
	var intentions: Variant = frontmatter.get("capability_intentions", null)
	if typeof(intentions) != TYPE_ARRAY:
		errors.append("AGENT_WORKFLOW_INTENTION_INVALID: capability_intentions")
		return
	var intention_ids := {}
	var intention_id_pattern := RegEx.create_from_string(INTENTION_ID_PATTERN)
	for intention_value: Variant in intentions:
		if typeof(intention_value) != TYPE_DICTIONARY:
			errors.append("AGENT_WORKFLOW_INTENTION_INVALID: non-object intention")
			continue
		var intention: Dictionary = intention_value
		if not _has_exact_keys(intention, [&"intention_id", &"purpose", &"authority_links"]):
			errors.append("AGENT_WORKFLOW_INTENTION_INVALID: intention fields")
			continue
		var intention_id: Variant = intention.get("intention_id", null)
		if typeof(intention_id) != TYPE_STRING or intention_id_pattern.search(intention_id) == null:
			errors.append("AGENT_WORKFLOW_INTENTION_INVALID: intention_id")
		else:
			if intention_ids.has(intention_id):
				errors.append("AGENT_WORKFLOW_INTENTION_DUPLICATE: " + intention_id)
			else:
				intention_ids[intention_id] = true
		var purpose: Variant = intention.get("purpose", null)
		if typeof(purpose) != TYPE_STRING or String(purpose).strip_edges().is_empty():
			errors.append("AGENT_WORKFLOW_INTENTION_INVALID: purpose")
		var links: Variant = intention.get("authority_links", null)
		if typeof(links) != TYPE_ARRAY:
			errors.append("AGENT_WORKFLOW_INTENTION_INVALID: authority_links")
			continue
		for link_value: Variant in links:
			if typeof(link_value) != TYPE_DICTIONARY:
				errors.append("AGENT_WORKFLOW_INTENTION_INVALID: non-object authority link")
				continue
			var link: Dictionary = link_value
			if not _has_exact_keys(link, [&"kind", &"target"]):
				errors.append("AGENT_WORKFLOW_INTENTION_INVALID: authority link fields")
				continue
			if typeof(link.get("kind")) != TYPE_STRING or String(link.get("kind")).is_empty() or typeof(link.get("target")) != TYPE_STRING or String(link.get("target")).is_empty():
				errors.append("AGENT_WORKFLOW_INTENTION_INVALID: authority link values")
				continue
			if resolver == null or not resolver.has_method("resolve"):
				errors.append("AGENT_WORKFLOW_LINK_UNRESOLVED: " + JSON.stringify(link))
				continue
			var resolution: Variant = resolver.resolve(link)
			if typeof(resolution) != TYPE_DICTIONARY or not resolution.get("ok", false):
				errors.append("AGENT_WORKFLOW_LINK_UNRESOLVED: " + JSON.stringify(link))

func _validate_text(guide_text: String, body: String, errors: Array[String]) -> void:
	if RegEx.create_from_string(NUMBERED_PHASE_PATTERN).search(guide_text) != null:
		errors.append("AGENT_WORKFLOW_NUMBERED_PHASE: forbidden numbered phase")
	if RegEx.create_from_string(PLACEHOLDER_PATTERN).search(guide_text) != null:
		errors.append("AGENT_WORKFLOW_PLACEHOLDER: forbidden placeholder")
	var body_lines := body.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	for line: String in body_lines:
		if line == "---":
			errors.append("AGENT_WORKFLOW_GUIDE_INVALID: second frontmatter block")
		if line.begins_with("capability_intentions:"):
			errors.append("AGENT_WORKFLOW_GUIDE_INVALID: body capability_intentions")
	_validate_decision_matrix(body_lines, errors)

func _validate_decision_matrix(body_lines: PackedStringArray, errors: Array[String]) -> void:
	var heading_indexes: Array[int] = []
	for index: int in range(body_lines.size()):
		if body_lines[index] == DECISION_HEADING:
			heading_indexes.append(index)
	if heading_indexes.size() != 1:
		errors.append("AGENT_WORKFLOW_DECISION_MATRIX_INVALID: decision heading count")
		return
	var section_end := body_lines.size()
	for index: int in range(heading_indexes[0] + 1, body_lines.size()):
		if body_lines[index].begins_with("## "):
			section_end = index
			break
	var header_count := 0
	var separator_count := 0
	var row_counts := {}
	for index: int in range(heading_indexes[0] + 1, section_end):
		var line: String = body_lines[index]
		if line == DECISION_HEADER:
			header_count += 1
			continue
		if line == DECISION_SEPARATOR:
			separator_count += 1
			continue
		var cells := _two_cell_row(line)
		if cells.is_empty():
			continue
		var decision_id: String = cells[0]
		var action: String = cells[1]
		if not DECISION_ROWS.has(decision_id):
			errors.append("AGENT_WORKFLOW_DECISION_MATRIX_INVALID: unknown decision " + decision_id)
			continue
		row_counts[decision_id] = int(row_counts.get(decision_id, 0)) + 1
		if action != DECISION_ROWS[decision_id]:
			errors.append("AGENT_WORKFLOW_DECISION_MATRIX_INVALID: wrong action " + decision_id)
	if header_count != 1 or separator_count != 1:
		errors.append("AGENT_WORKFLOW_DECISION_MATRIX_INVALID: table framing")
	for decision_id: Variant in DECISION_ROWS.keys():
		if int(row_counts.get(decision_id, 0)) != 1:
			errors.append("AGENT_WORKFLOW_DECISION_MATRIX_INVALID: decision row " + str(decision_id))

func _two_cell_row(line: String) -> Array[String]:
	var cells: Array[String] = []
	if not line.begins_with("|") or not line.ends_with("|"):
		return cells
	var pieces := line.split("|", true)
	if pieces.size() != 4 or not pieces[0].is_empty() or not pieces[3].is_empty():
		return cells
	cells.append(pieces[1].strip_edges())
	cells.append(pieces[2].strip_edges())
	return cells

func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(str(key)):
			return false
	return true

func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty() or path != path.replace("\\", "/") or path.begins_with("/") or path.contains(":"):
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
	var normalized := path.replace("\\", "/")
	while normalized.ends_with("/") and not normalized.ends_with("://"):
		normalized = normalized.trim_suffix("/")
	return normalized

func _read_utf8(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false, "text":""}
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok":false, "text":""}
	return {"ok":true, "text":text}

func _result(errors: Array[String]) -> Dictionary:
	return {"ok":errors.is_empty(), "errors":errors}
