extends "res://addons/gut/test.gd"

const RESOLVER_PATH := "res://tools/docs/AgentWorkflowAuthorityResolver.gd"
var _counter := 0

func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(text)
	file.close()

func _canonical_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	assert_eq(text.to_utf8_buffer(), bytes)
	assert_false(bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf)
	return text.replace("\r\n", "\n").replace("\r", "\n").sha256_text()

func _refresh_index(root: String) -> void:
	var validator := preload("res://tools/docs/DocValidator.gd").new()
	var preliminary: Dictionary = validator.validate_tree(root.path_join("prompt_docs"), [])
	_write(root.path_join("prompt_docs/INDEX.md"), preload("res://tools/docs/DocIndexGenerator.gd").new().render(preliminary))

func _create_link(link_path: String, target_path: String, is_directory: bool) -> bool:
	if OS.get_name() != "Windows":
		var unix_output: Array = []
		return OS.execute("/bin/ln", ["-s", target_path, link_path], unix_output, true) == 0
	var escaped_link := link_path.replace("'", "''")
	var escaped_target := target_path.replace("'", "''")
	var item_type := "SymbolicLink"
	var command := "$ErrorActionPreference='Stop'; New-Item -ItemType %s -Path '%s' -Target '%s' | Out-Null" % [item_type, escaped_link, escaped_target]
	var output: Array = []
	var powershell := "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
	if OS.execute(powershell, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], output, true) == 0:
		return true
	if not is_directory:
		return false
	command = "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path '%s' -Target '%s' | Out-Null" % [escaped_link, escaped_target]
	output.clear()
	return OS.execute(powershell, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], output, true) == 0

func _has_source_error(result: Dictionary, expected: String) -> bool:
	for error: Variant in result.get("source_errors", []):
		if str(error) == expected:
			return true
	return false

func _fixture_root() -> String:
	_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("agent-authority-%d" % _counter)
	var plan_path := root.path_join("docs/superpowers/plans/sample.md")
	_write(plan_path, "# Sample plan\n\nOne reviewed procedure.\n")
	_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n")
	_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\ndecision_status: accepted\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: []\nrecommended_investigation: [\"Re-open only if the recorded scope changes.\"]\n---\n\n# Accepted decision\n")
	_write(root.path_join("docs/superpowers/specs/sample.md"), "---\nid: spec.sample\nconversational_design_status: approved\nwritten_spec_status: approved\nimplementation_plan_path: \"docs/superpowers/plans/sample.md\"\nimplementation_plan_status: approved\nimplementation_plan_sha256: %s\ncreated_on: 2026-07-18\n---\n\n# Sample specification\n" % _canonical_sha256(plan_path))
	var validator := preload("res://tools/docs/DocValidator.gd").new()
	_refresh_index(root)
	var verified: Dictionary = validator.validate_tree(root.path_join("prompt_docs"), [])
	assert_true(verified.get("ok", false), JSON.stringify(verified.get("errors", [])))
	return root

func test_resolves_every_frozen_link_kind() -> void:
	var loaded := load(RESOLVER_PATH)
	assert_not_null(loaded, "expected RED: missing AgentWorkflowAuthorityResolver.gd")
	if loaded == null:
		return
	var beads_snapshot: Array[Dictionary] = [{"id":"dwm-sample"}]
	var resolver: RefCounted = loaded.new(_fixture_root(), beads_snapshot)
	for link in [
		{"kind":"beads_issue", "target":"dwm-sample"},
		{"kind":"requirement_id", "target":"req.sample"},
		{"kind":"specification_id", "target":"spec.sample"},
		{"kind":"decision_id", "target":"decision.sample"},
		{"kind":"plan_path", "target":"docs/superpowers/plans/sample.md"},
	]:
		var result: Dictionary = resolver.resolve(link)
		assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(resolver.resolve({"kind":"beads_issue", "target":"missing"}).get("code"), &"AUTHORITY_LINK_UNKNOWN")
	assert_eq(resolver.resolve({"kind":"plan_path", "target":"../outside.md"}).get("code"), &"AUTHORITY_LINK_INVALID")

func test_plan_link_is_invalidated_when_approved_canonical_text_changes() -> void:
	var root := _fixture_root()
	_write(root.path_join("docs/superpowers/plans/sample.md"), "# Sample plan\n\nChanged after approval.\n")
	var beads_snapshot: Array[Dictionary] = [{"id":"dwm-sample"}]
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"plan_path", "target":"docs/superpowers/plans/sample.md"}).get("code"), &"AUTHORITY_LINK_UNAPPROVED")

func test_packet_links_require_the_current_generated_index() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/INDEX.md"), "stale\n")
	var beads_snapshot: Array[Dictionary] = [{"id":"dwm-sample"}]
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_specification_projection_rejects_unquoted_paths_duplicate_keys_and_indented_keys() -> void:
	var root := _fixture_root()
	var spec_path := root.path_join("docs/superpowers/specs/sample.md")
	_write(spec_path, "---\nid: spec.sample\nconversational_design_status: approved\nwritten_spec_status: approved\nimplementation_plan_path: docs/superpowers/plans/sample.md\nimplementation_plan_status: approved\nimplementation_plan_sha256: digest\n---\n")
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"specification_id", "target":"spec.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	_write(spec_path, "---\nid: spec.sample\nid: spec.sample\nconversational_design_status: approved\nwritten_spec_status: approved\nimplementation_plan_path: \"docs/superpowers/plans/sample.md\"\nimplementation_plan_status: approved\nimplementation_plan_sha256: digest\n---\n")
	resolver = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"specification_id", "target":"spec.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	_write(spec_path, "---\nid: spec.sample\n conversational_design_status: approved\nwritten_spec_status: approved\nimplementation_plan_path: \"docs/superpowers/plans/sample.md\"\nimplementation_plan_status: approved\nimplementation_plan_sha256: digest\n---\n")
	resolver = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"specification_id", "target":"spec.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_unterminated_specification_preserves_a_matching_id_projection() -> void:
	var root := _fixture_root()
	_write(root.path_join("docs/superpowers/specs/sample.md"), "---\nid: spec.unterminated\nconversational_design_status: approved\n")
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"specification_id", "target":"spec.unterminated"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_unterminated_specification_preserves_a_matching_plan_projection() -> void:
	var root := _fixture_root()
	_write(root.path_join("docs/superpowers/specs/sample.md"), "---\nid: spec.unterminated\nimplementation_plan_path: \"docs/superpowers/plans/sample.md\"\n")
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"plan_path", "target":"docs/superpowers/plans/sample.md"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_requirement_and_decision_duplicates_win_over_unrelated_validation_errors() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/requirements/duplicate.md"), "---\nid: req_packet.duplicate\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Duplicate\n\n## Rule req.sample\n\nDuplicate authority.\n")
	_write(root.path_join("prompt_docs/decisions/duplicate.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\ndecision_status: accepted\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: []\nrecommended_investigation: [\"Re-open only if the recorded scope changes.\"]\n---\n\n# Duplicate decision\n")
	_refresh_index(root)
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_DUPLICATE_TARGET")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_DUPLICATE_TARGET")

func test_packet_links_classify_unknown_unapproved_and_malformed_matches() -> void:
	var root := _fixture_root()
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.missing"}).get("code"), &"AUTHORITY_LINK_UNKNOWN")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.missing"}).get("code"), &"AUTHORITY_LINK_UNKNOWN")
	_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: deferred\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nDeferred authority.\n")
	_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: deferred\ndecision_status: decision_required\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"pending user decision\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: [\"req.sample\"]\nrecommended_investigation: [\"Obtain a decision.\"]\n---\n\n# Deferred decision\n")
	_refresh_index(root)
	resolver = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_UNAPPROVED")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_UNAPPROVED")
	_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n")
	_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\ndecision_status: rejected\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"bad status\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: []\nrecommended_investigation: [\"Correct the status.\"]\n---\n\n# Invalid decision\n")
	_refresh_index(root)
	resolver = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_approved_requirement_with_missing_dependency_has_an_invalid_source() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[\"req.missing\"],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n")
	_refresh_index(root)
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_accepted_decision_with_missing_requirement_target_has_an_invalid_source() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\ndecision_status: accepted\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.missing\"]\nblocking_requirement_ids: []\nrecommended_investigation: [\"Re-open only if the recorded scope changes.\"]\n---\n\n# Accepted decision\n")
	_refresh_index(root)
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_malformed_beads_binding_and_snapshot_invalidate_their_matching_requirement() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: [\"dwm-sample\"]\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n")
	_refresh_index(root)
	var malformed_binding: Array[Dictionary] = [{"id":"dwm-sample", "metadata":{"phase2r":{"requirement_ids":[]}}}]
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, malformed_binding)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	var malformed_snapshot: Array[Dictionary] = [{}]
	resolver = load(RESOLVER_PATH).new(root, malformed_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_unrelated_packet_path_prefix_diagnostic_does_not_invalidate_a_matching_requirement() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/requirements/sample.md-extra.md"), "---\nid: req_packet.unrelated\nkind: invalid_kind\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements: []\n---\n\n# Unrelated\n")
	_refresh_index(root)
	var beads_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, beads_snapshot)
	assert_true(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("ok", false))

func test_first_packet_with_a_duplicate_id_invalidates_its_unique_requirement() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/requirements/first.md"), "---\nid: req_packet.duplicate\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.first\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# First duplicate\n\n## Rule req.first\n\nFirst duplicate authority.\n")
	_write(root.path_join("prompt_docs/requirements/second.md"), "---\nid: req_packet.duplicate\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.second\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Second duplicate\n\n## Rule req.second\n\nSecond duplicate authority.\n")
	_refresh_index(root)
	var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
	assert_eq(validation.get("invalid_packet_paths", []), ["prompt_docs/requirements/first.md", "prompt_docs/requirements/second.md"])
	var empty_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.first"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_malformed_decision_requirement_lists_are_invalid_without_runtime_errors() -> void:
	for malformed_value: String in ["\"req.sample\"", "{\"id\":\"req.sample\"}"]:
		var root := _fixture_root()
		_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\ndecision_status: accepted\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: %s\nblocking_requirement_ids: %s\nrecommended_investigation: [\"Re-open only if the recorded scope changes.\"]\n---\n\n# Accepted decision\n" % [malformed_value, malformed_value])
		_refresh_index(root)
		var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
		assert_true(_has_runtime_marker(validation.get("errors", [])) == false, JSON.stringify(validation.get("errors", [])))
		assert_false(_has_error_code(validation, "DOC_DEPENDENCY_MISSING"), JSON.stringify(validation.get("errors", [])))
		assert_eq(validation.get("invalid_packet_paths", []), ["prompt_docs/decisions/sample.md"])
		var empty_snapshot: Array[Dictionary] = []
		var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
		assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_non_dictionary_beads_metadata_is_invalid_without_runtime_errors() -> void:
	for metadata: Variant in ["metadata", ["metadata"]]:
		var root := _fixture_root()
		_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: [\"dwm-sample\"]\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n")
		_refresh_index(root)
		var snapshot: Array[Dictionary] = [{"id":"dwm-sample", "metadata":metadata}]
		var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), snapshot)
		assert_true(_has_error_code(validation, "DOC_BEAD_METADATA_DRIFT"), JSON.stringify(validation.get("errors", [])))
		assert_true(_has_runtime_marker(validation.get("errors", [])) == false, JSON.stringify(validation.get("errors", [])))
		assert_eq(validation.get("invalid_packet_paths", []), ["prompt_docs/requirements/sample.md"])
		var resolver: RefCounted = load(RESOLVER_PATH).new(root, snapshot)
		assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_deferred_decision_null_or_scalar_blocking_ids_is_total_and_source_invalid() -> void:
	for malformed_value: String in ["null", "\"req.sample\""]:
		var root := _fixture_root()
		_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: deferred\ndecision_status: decision_required\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"pending user decision\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: %s\nrecommended_investigation: [\"Obtain a decision.\"]\n---\n\n# Deferred decision\n" % malformed_value)
		_refresh_index(root)
		var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
		assert_eq(validation.get("invalid_packet_paths", []), ["prompt_docs/decisions/sample.md"])
		var empty_snapshot: Array[Dictionary] = []
		var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
		assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_missing_decision_status_survives_index_render_as_an_identifiable_invalid_record() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: []\nrecommended_investigation: [\"Re-open only if scope changes.\"]\n---\n\n# Missing decision status\n")
	_refresh_index(root)
	var empty_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_malformed_requirement_shapes_are_total_and_source_invalid() -> void:
	var malformed_requirements := [
		"{\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}",
		"{\"id\":\"req.sample\",\"depends_on\":\"req.other\",\"implementation_evidence\":[],\"verification_evidence\":[]}",
		"{\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":\"code\",\"verification_evidence\":[]}",
		"{\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":null}",
	]
	for requirement_json: String in malformed_requirements:
		var root := _fixture_root()
		_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - %s\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n" % requirement_json)
		_refresh_index(root)
		var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
		assert_true("prompt_docs/requirements/sample.md" in validation.get("invalid_packet_paths", []), JSON.stringify(validation.get("invalid_packet_paths", [])))
		var empty_snapshot: Array[Dictionary] = []
		var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
		var target := "" if not requirement_json.contains("\"id\"") else "req.sample"
		if target.is_empty():
			assert_false(validation.get("requirements", []).is_empty(), "missing-id records must remain available to deterministic index rendering")
		else:
			assert_eq(resolver.resolve({"kind":"requirement_id", "target":target}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_scalar_packet_requirements_or_beads_is_identifiable_and_source_invalid() -> void:
	for malformed_line: String in ["requirements: null", "beads: \"dwm-sample\""]:
		var root := _fixture_root()
		var text := "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n"
		if malformed_line.begins_with("requirements"):
			text = text.replace("requirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}", malformed_line)
		else:
			text = text.replace("beads: []", malformed_line)
		_write(root.path_join("prompt_docs/requirements/sample.md"), text)
		_refresh_index(root)
		var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
		assert_true("prompt_docs/requirements/sample.md" in validation.get("invalid_packet_paths", []), JSON.stringify(validation.get("invalid_packet_paths", [])))
		var packet_matches: Array = validation.get("packets", []).filter(func(packet: Dictionary) -> bool: return packet.get("id") == "req_packet.sample")
		assert_eq(packet_matches.size(), 1, "partial packet identity must be preserved")
		var empty_snapshot: Array[Dictionary] = []
		var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
		if malformed_line.begins_with("beads"):
			assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_duplicate_requirement_ids_invalidate_every_owning_packet_but_remain_duplicate_targets() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/requirements/first.md"), "---\nid: req_packet.first\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.duplicate\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n  - {\"id\":\"req.first_unique\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# First owner\n\n## Rule req.duplicate\n\nDuplicate authority.\n\n## Rule req.first_unique\n\nUnique first-owner authority.\n")
	_write(root.path_join("prompt_docs/requirements/second.md"), "---\nid: req_packet.second\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.duplicate\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Second owner\n\n## Rule req.duplicate\n\nDuplicate authority.\n")
	_refresh_index(root)
	var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
	assert_eq(validation.get("invalid_packet_paths", []), ["prompt_docs/requirements/first.md", "prompt_docs/requirements/second.md"])
	var empty_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.duplicate"}).get("code"), &"AUTHORITY_LINK_DUPLICATE_TARGET")
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.first_unique"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")

func test_symlinked_markdown_file_is_rejected_as_a_global_packet_source_error() -> void:
	var root := _fixture_root()
	var target := root.path_join("outside/injected.md")
	_write(target, "---\nid: req_packet.injected\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.injected\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Injected\n\n## Rule req.injected\n\nInjected authority.\n")
	var link := root.path_join("prompt_docs/requirements/injected-link.md")
	if not _create_link(link, target, false):
		pending("file symlink creation unavailable on this platform")
		return
	_refresh_index(root)
	var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
	assert_false(validation.get("packet_source_valid", true))
	assert_true(_has_source_error(validation, "DOC_PACKET_SOURCE_LINK: prompt_docs/requirements/injected-link.md"), JSON.stringify(validation.get("source_errors", [])))
	assert_true(validation.get("requirements", []).all(func(requirement: Dictionary) -> bool: return requirement.get("id") != "req.injected"))
	var empty_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(DirAccess.remove_absolute(link), OK)

func test_symlinked_markdown_directory_is_rejected_as_a_global_packet_source_error() -> void:
	var root := _fixture_root()
	var target := root.path_join("outside/injected-directory")
	_write(target.path_join("injected.md"), "---\nid: req_packet.injected\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.injected\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Injected\n\n## Rule req.injected\n\nInjected authority.\n")
	var link := root.path_join("prompt_docs/requirements/injected-directory")
	if not _create_link(link, target, true):
		pending("directory symlink/junction creation unavailable on this platform")
		return
	_refresh_index(root)
	var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(root.path_join("prompt_docs"), [])
	assert_false(validation.get("packet_source_valid", true))
	assert_true(_has_source_error(validation, "DOC_PACKET_SOURCE_LINK: prompt_docs/requirements/injected-directory"), JSON.stringify(validation.get("source_errors", [])))
	assert_true(validation.get("requirements", []).all(func(requirement: Dictionary) -> bool: return requirement.get("id") != "req.injected"))
	var empty_snapshot: Array[Dictionary] = []
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, empty_snapshot)
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(DirAccess.remove_absolute(link), OK)

func test_prompt_docs_junction_is_rejected_even_when_external_index_matches() -> void:
	var external_authority_root := _fixture_root()
	_counter += 1
	var repository_root := OS.get_environment("DWM_TEST_ROOT").path_join("agent-authority-root-link-%d" % _counter)
	var link := repository_root.path_join("prompt_docs")
	if not _create_link(link, external_authority_root.path_join("prompt_docs"), true):
		pending("directory symlink/junction creation unavailable on this platform")
		return
	var empty_snapshot: Array[Dictionary] = []
	var validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(link, empty_snapshot)
	assert_false(validation.get("packet_source_valid", true), JSON.stringify(validation))
	assert_true(_has_source_error(validation, "DOC_PACKET_SOURCE_LINK: prompt_docs"), JSON.stringify(validation.get("source_errors", [])))
	var resolver: RefCounted = load(RESOLVER_PATH).new(repository_root, empty_snapshot)
	for link_target in [
		{"kind":"requirement_id", "target":"req.sample"},
		{"kind":"decision_id", "target":"decision.sample"},
	]:
		var result: Dictionary = resolver.resolve(link_target)
		assert_false(result.get("ok", false), JSON.stringify(result))
		assert_eq(result.get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(DirAccess.remove_absolute(link), OK)

func test_ambiguous_or_non_descendant_authority_roots_are_source_invalid() -> void:
	var root := _fixture_root()
	var empty_snapshot: Array[Dictionary] = []
	var dotted_root_resolver: RefCounted = load(RESOLVER_PATH).new(root + "/.", empty_snapshot)
	for link_target in [
		{"kind":"requirement_id", "target":"req.sample"},
		{"kind":"decision_id", "target":"decision.sample"},
	]:
		var dotted_result: Dictionary = dotted_root_resolver.resolve(link_target)
		assert_false(dotted_result.get("ok", true), JSON.stringify(dotted_result))
		assert_eq(dotted_result.get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	var external_root := _fixture_root()
	var outside_validation: Dictionary = preload("res://tools/docs/DocValidator.gd").new().validate_tree(external_root.path_join("prompt_docs"), empty_snapshot, root)
	assert_false(outside_validation.get("packet_source_valid", true), JSON.stringify(outside_validation))
	assert_true(_has_source_error(outside_validation, "DOC_PACKET_SOURCE_INVALID: root boundary"), JSON.stringify(outside_validation.get("source_errors", [])))
	_counter += 1
	var redirect_repository_root := OS.get_environment("DWM_TEST_ROOT").path_join("agent-authority-redirect-%d" % _counter)
	var redirect_target := external_root.path_join("safe-child")
	assert_eq(DirAccess.make_dir_recursive_absolute(redirect_target), OK)
	var redirect := redirect_repository_root.path_join("redirect")
	if not _create_link(redirect, redirect_target, true):
		pending("directory symlink/junction creation unavailable on this platform")
		return
	var escaped_root_resolver: RefCounted = load(RESOLVER_PATH).new(redirect_repository_root.path_join("redirect/.."), empty_snapshot)
	for link_target in [
		{"kind":"requirement_id", "target":"req.sample"},
		{"kind":"decision_id", "target":"decision.sample"},
	]:
		var escaped_result: Dictionary = escaped_root_resolver.resolve(link_target)
		assert_false(escaped_result.get("ok", true), JSON.stringify(escaped_result))
		assert_eq(escaped_result.get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(DirAccess.remove_absolute(redirect), OK)

func _has_runtime_marker(errors: Array) -> bool:
	for error: Variant in errors:
		if str(error).contains("SCRIPT ERROR") or str(error).contains("Invalid call"):
			return true
	return false

func _has_error_code(result: Dictionary, code: String) -> bool:
	for error: Variant in result.get("errors", []):
		if str(error).begins_with(code):
			return true
	return false
