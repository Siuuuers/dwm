extends "res://addons/gut/test.gd"

const VALIDATOR := preload("res://tools/docs/AgentWorkflowValidator.gd")
const HANDOFF_PATH := "docs/agent/2026-09-23-next-session-handoff.md"
const MAP_PATH := "docs/agent/execution-map.md"
const FLAGS := "document_role: navigation_only\nexecution_authority: false\nstatus_authority: false\nbehavior_authority: false\nverification_authority: false\n"
const VALID_HANDOFF := "---\nschema_version: 1\ndocument_id: dwm_current_handoff\n" + FLAGS + "execution_map: \"docs/agent/execution-map.md\"\nissue_authority: beads\n---\n\n# Current handoff\n\nContinue the selected work using its approved design.\n"
const VALID_MAP := "---\nschema_version: 1\ndocument_id: dwm_execution_map\n" + FLAGS + "inspected_source: \"0123456789abcdef0123456789abcdef01234567\"\n---\n\n# Execution map\n\nBeads owns issue status and dependencies.\n"

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()

func _write(path: String, text: String) -> void:
	_write_bytes(path, text.to_utf8_buffer())

func _fixture_root() -> String:
	var created: Dictionary = TemporaryStorage.create("current-handoff")
	assert_true(created.get("ok", false), str(created))
	if not created.get("ok", false):
		return ""
	var root: String = created["value"]
	_write(root.path_join(HANDOFF_PATH), VALID_HANDOFF)
	_write(root.path_join(MAP_PATH), VALID_MAP)
	return root

func _has_code(result: Dictionary, code: String) -> bool:
	return result.errors.any(func(error: String) -> bool: return error.begins_with(code))

func _create_link(link_path: String, target_path: String, is_directory: bool) -> bool:
	if OS.get_name() != "Windows":
		var unix_output: Array = []
		return OS.execute("/bin/ln", ["-s", target_path, link_path], unix_output, true) == 0
	var item_type := "Junction" if is_directory else "SymbolicLink"
	var command := "$ErrorActionPreference='Stop'; New-Item -ItemType %s -Path '%s' -Target '%s' | Out-Null" % [item_type, link_path.replace("'", "''"), target_path.replace("'", "''")]
	var output: Array = []
	return OS.execute("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], output, true) == 0

func test_valid_navigation_allows_updated_prose_and_inspected_source() -> void:
	var validator := VALIDATOR.new()
	assert_true(validator.validate_pair(VALID_HANDOFF, VALID_MAP).ok)
	var changed_handoff := VALID_HANDOFF + "\n## Next work\n\nUse another selected Bead after the current acceptance.\n"
	var changed_map := VALID_MAP.replace("0123456789abcdef0123456789abcdef01234567", "abcdef0123456789abcdef0123456789abcdef01")
	assert_true(validator.validate_pair(changed_handoff, changed_map).ok)

func test_handoff_rejects_authority_schema_and_issue_source_drift() -> void:
	var validator := VALIDATOR.new()
	for flag: String in ["execution_authority", "status_authority", "behavior_authority", "verification_authority"]:
		var changed := VALID_HANDOFF.replace(flag + ": false", flag + ": true")
		assert_true(_has_code(validator.validate_pair(changed, VALID_MAP), "AGENT_WORKFLOW_AUTHORITY_INVALID"), flag)
	for changed: String in [
		VALID_HANDOFF.replace("navigation_only", "execution_authority"),
		VALID_HANDOFF.replace("schema_version: 1", "schema_version: \"1\""),
		VALID_HANDOFF.replace("dwm_current_handoff", "another_handoff"),
		VALID_HANDOFF.replace("issue_authority: beads", "issue_authority: handoff"),
		VALID_HANDOFF.replace("issue_authority: beads\n", ""),
		VALID_HANDOFF.replace("issue_authority: beads\n", "issue_authority: beads\nfuture_authority: true\n"),
	]:
		assert_false(validator.validate_pair(changed, VALID_MAP).ok, changed)
	var duplicate := VALID_HANDOFF.replace("schema_version: 1", "schema_version: 1\nschema_version: 1")
	assert_true(_has_code(validator.validate_pair(duplicate, VALID_MAP), "AGENT_WORKFLOW_HANDOFF_INVALID"))

func test_map_rejects_authority_and_source_identity_drift() -> void:
	var validator := VALIDATOR.new()
	for flag: String in ["execution_authority", "status_authority", "behavior_authority", "verification_authority"]:
		var changed := VALID_MAP.replace(flag + ": false", flag + ": true")
		assert_true(_has_code(validator.validate_pair(VALID_HANDOFF, changed), "AGENT_WORKFLOW_AUTHORITY_INVALID"), flag)
	for changed: String in [
		VALID_MAP.replace("navigation_only", "execution_authority"),
		VALID_MAP.replace("dwm_execution_map", "another_map"),
		VALID_MAP.replace("schema_version: 1", "schema_version: false"),
		VALID_MAP.replace("0123456789abcdef0123456789abcdef01234567", "latest"),
		VALID_MAP.replace("inspected_source: \"0123456789abcdef0123456789abcdef01234567\"", "inspected_source: 1"),
	]:
		assert_false(validator.validate_pair(VALID_HANDOFF, changed).ok, changed)

func test_handoff_rejects_unsafe_or_alternate_map_pointers() -> void:
	var validator := VALIDATOR.new()
	for pointer: String in ["../execution-map.md", "/execution-map.md", "res://docs/agent/execution-map.md", "docs\\agent\\execution-map.md", "docs//agent/execution-map.md", "docs/./agent/execution-map.md", "docs/agent/other-map.md"]:
		var changed := VALID_HANDOFF.replace(JSON.stringify(MAP_PATH), JSON.stringify(pointer))
		assert_true(_has_code(validator.validate_pair(changed, VALID_MAP), "AGENT_WORKFLOW_POINTER_INVALID"), pointer)

func test_physical_navigation_rejects_missing_or_directory_documents() -> void:
	var root := _fixture_root()
	if root.is_empty():
		return
	var validator := VALIDATOR.new()
	assert_true(validator.validate_files(root).ok)
	assert_eq(DirAccess.remove_absolute(root.path_join(MAP_PATH)), OK)
	assert_true(_has_code(validator.validate_files(root), "AGENT_WORKFLOW_SOURCE_INVALID"))
	assert_eq(DirAccess.make_dir_absolute(root.path_join(MAP_PATH)), OK)
	assert_true(_has_code(validator.validate_files(root), "AGENT_WORKFLOW_SOURCE_INVALID"))
	assert_eq(DirAccess.remove_absolute(root.path_join(MAP_PATH)), OK)
	_write(root.path_join(MAP_PATH), VALID_MAP)
	assert_eq(DirAccess.remove_absolute(root.path_join(HANDOFF_PATH)), OK)
	assert_true(_has_code(validator.validate_files(root), "AGENT_WORKFLOW_SOURCE_INVALID"))

func test_physical_navigation_rejects_invalid_utf8_in_either_document() -> void:
	var root := _fixture_root()
	if root.is_empty():
		return
	var validator := VALIDATOR.new()
	for relative_path: String in [HANDOFF_PATH, MAP_PATH]:
		var valid := VALID_HANDOFF if relative_path == HANDOFF_PATH else VALID_MAP
		var invalid := valid.to_utf8_buffer()
		invalid.append(0xff)
		_write_bytes(root.path_join(relative_path), invalid)
		assert_true(_has_code(validator.validate_files(root), "AGENT_WORKFLOW_UTF8_INVALID"), relative_path)
		_write(root.path_join(relative_path), valid)

func test_physical_navigation_rejects_symlinked_document() -> void:
	var root := _fixture_root()
	if root.is_empty():
		return
	var target := root.path_join("outside.md")
	_write(target, VALID_MAP)
	var link := root.path_join(MAP_PATH)
	assert_eq(DirAccess.remove_absolute(link), OK)
	var linked := _create_link(link, target, false)
	assert_true(linked, "Cloud fixture must create a file symlink to exercise rejection")
	if not linked:
		return
	assert_true(_has_code(VALIDATOR.new().validate_files(root), "AGENT_WORKFLOW_SOURCE_INVALID"))
	assert_eq(DirAccess.remove_absolute(link), OK)

func test_physical_navigation_rejects_symlinked_parent_and_repository_root() -> void:
	var root := _fixture_root()
	if root.is_empty():
		return
	var external := _fixture_root()
	if external.is_empty():
		return
	var nested_root := root.path_join("nested")
	assert_eq(DirAccess.make_dir_absolute(nested_root), OK)
	var parent_link := nested_root.path_join("docs")
	var linked := _create_link(parent_link, external.path_join("docs"), true)
	assert_true(linked, "Cloud fixture must create a directory link to exercise rejection")
	if not linked:
		return
	assert_true(_has_code(VALIDATOR.new().validate_files(nested_root), "AGENT_WORKFLOW_SOURCE_INVALID"))
	assert_eq(DirAccess.remove_absolute(parent_link), OK)
	var root_link := root.path_join("root-link")
	linked = _create_link(root_link, external, true)
	assert_true(linked)
	if not linked:
		return
	assert_true(_has_code(VALIDATOR.new().validate_files(root_link), "AGENT_WORKFLOW_ROOT_INVALID"))
	assert_eq(DirAccess.remove_absolute(root_link), OK)

func test_repository_navigation_validates_without_legacy_files_or_issue_snapshot() -> void:
	var validator := VALIDATOR.new()
	var result: Dictionary = validator.validate_files()
	assert_true(result.ok, JSON.stringify(result.errors))
	assert_true(_has_code(validator.validate_files(""), "AGENT_WORKFLOW_ROOT_INVALID"))
	assert_true(_has_code(validator.validate_files("relative-root"), "AGENT_WORKFLOW_ROOT_INVALID"))
