extends "res://addons/gut/test.gd"

const VALIDATOR_PATH := "res://tools/docs/AgentWorkflowValidator.gd"
const VALID_PROMPT := "---\nschema_version: 1\nkind: agent_entry\nagent_workflow_guide: \"docs/agent/AGENT_WORKFLOW.md\"\n---\n\n# Entry\n"
const VALID_GUIDE := "---\nschema_version: 1\ndocument_id: agent_workflow\ndocument_role: navigation_only\nexecution_authority: false\nstatus_authority: false\nbehavior_authority: false\nverification_authority: false\ncapability_intentions: [{\"intention_id\":\"desktop_experience\",\"purpose\":\"Provide a usable desktop experience.\",\"authority_links\":[]}]\n---\n\n# Agent Workflow Navigation\n\n## Decision table\n\n| decision_id | exact action |\n|---|---|\n| commit_parent_open | Report the bounded commit; report the parent as open. |\n| one_ready_issue | Inspect the issue and its dependencies; mutate only with scope-matched permission. |\n| multiple_active_ambiguous | Stop, list the issue IDs, and request one selection. |\n| intention_links_empty | Treat it as intent only and request design authority. |\n| authority_link_broken | Stop and identify the broken link. |\n| design_without_plan | Do not implement; prepare a plan only when requested. |\n| plan_without_permission | Stop and request exact execution permission. |\n| ignored_script | Treat verification as failed, fix discovery, and rerun. |\n| child_closed_parent_open | Report the child closed and the parent open. |\n"

class StubResolver:
	extends RefCounted
	var succeeds := true
	func _init(value: bool) -> void: succeeds = value
	func resolve(_link: Dictionary) -> Dictionary:
		return {"ok":true, "code":&"ok"} if succeeds else {"ok":false, "code":&"AUTHORITY_LINK_UNKNOWN"}

func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(text)
	file.close()

func _has_code(result: Dictionary, code: String) -> bool:
	return result.errors.any(func(error: String) -> bool: return error.begins_with(code))

func test_validator_rejects_every_frozen_drift() -> void:
	var loaded := load(VALIDATOR_PATH)
	assert_not_null(loaded, "expected RED: missing AgentWorkflowValidator.gd")
	if loaded == null:
		return
	var validator: RefCounted = loaded.new()
	assert_true(validator.validate_pair(VALID_PROMPT, VALID_GUIDE).ok)
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT.replace("docs/agent/AGENT_WORKFLOW.md", "missing.md"), VALID_GUIDE), "AGENT_WORKFLOW_POINTER_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("execution_authority: false", "execution_authority: true")), "AGENT_WORKFLOW_AUTHORITY_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("Provide a usable desktop experience.", "Phase 3 desktop")), "AGENT_WORKFLOW_NUMBERED_PHASE"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("# Agent Workflow Navigation", "# Agent Workflow Navigation\n\nTBD")), "AGENT_WORKFLOW_PLACEHOLDER"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE + "\n---\nsecond: block\n---\n"), "AGENT_WORKFLOW_GUIDE_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE + "\ncapability_intentions: []\n"), "AGENT_WORKFLOW_GUIDE_INVALID"))
	var duplicate := VALID_GUIDE.replace("}]\n---", "},{\"intention_id\":\"desktop_experience\",\"purpose\":\"duplicate\",\"authority_links\":[]}]\n---")
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, duplicate), "AGENT_WORKFLOW_INTENTION_DUPLICATE"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("| ignored_script |", "| removed_script |")), "AGENT_WORKFLOW_DECISION_MATRIX_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("Report the bounded commit; report the parent as open.", "Report everything complete.")), "AGENT_WORKFLOW_DECISION_MATRIX_INVALID"))
	var competing_table := VALID_GUIDE.replace("## Decision table", "## Unrelated table\n\n| arbitrary | value |\n|---|---|\n| unknown_id | unrelated |\n\n## Decision table")
	assert_true(validator.validate_pair(VALID_PROMPT, competing_table).ok)
	var unknown_decision := VALID_GUIDE.replace("| child_closed_parent_open |", "| unknown_decision | unrelated action |\n| child_closed_parent_open |")
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, unknown_decision), "AGENT_WORKFLOW_DECISION_MATRIX_INVALID"))

func test_nonempty_links_must_resolve() -> void:
	var validator: RefCounted = load(VALIDATOR_PATH).new()
	var linked := VALID_GUIDE.replace("\"authority_links\":[]", "\"authority_links\":[{\"kind\":\"beads_issue\",\"target\":\"dwm-sample\"}]")
	assert_true(validator.validate_pair(VALID_PROMPT, linked, StubResolver.new(true)).ok)
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, linked, StubResolver.new(false)), "AGENT_WORKFLOW_LINK_UNRESOLVED"))

func test_validate_files_rejects_physically_missing_guide() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("agent-workflow-missing")
	_write(root.path_join("Prompt.md"), VALID_PROMPT)
	var empty_snapshot: Array[Dictionary] = []
	var result: Dictionary = load(VALIDATOR_PATH).new().validate_files(root.path_join("Prompt.md"), empty_snapshot)
	assert_true(_has_code(result, "AGENT_WORKFLOW_POINTER_INVALID"), JSON.stringify(result.errors))
