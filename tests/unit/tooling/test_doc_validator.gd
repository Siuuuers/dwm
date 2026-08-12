extends "res://addons/gut/test.gd"

const VALIDATOR_PATH := "res://tools/docs/DocValidator.gd"
const FIXTURES := "res://tests/fixtures/docs"
var _counter := 0

func _snapshot(requirement_ids: Array[String]) -> Array[Dictionary]:
	return [{"id": "dwm-p2r.4", "metadata": {"phase2r": {"requirement_ids": requirement_ids}}}]

func _validate_fixture(names: Array[String], snapshot: Array[Dictionary] = []) -> Dictionary:
	_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("docs-fixture-%d" % _counter)
	var requirements := root.path_join("requirements")
	assert_eq(DirAccess.make_dir_recursive_absolute(requirements), OK)
	for name: String in names:
		var bytes := FileAccess.get_file_as_bytes(FIXTURES.path_join(name))
		var output := FileAccess.open(requirements.path_join(name), FileAccess.WRITE)
		output.store_buffer(bytes); output.close()
	return load(VALIDATOR_PATH).new().validate_tree(root, snapshot)

func _has_code(result: Dictionary, code: String) -> bool:
	for error: String in result.errors:
		if error.begins_with(code): return true
	return false

func _find_bytes(bytes: PackedByteArray, target: PackedByteArray) -> int:
	for start: int in range(bytes.size() - target.size() + 1):
		var matches := true
		for offset: int in range(target.size()):
			if bytes[start + offset] != target[offset]:
				matches = false
				break
		if matches:
			return start
	return -1

func test_validator_error_matrix() -> void:
	var validator: Script = load(VALIDATOR_PATH)
	assert_not_null(validator, "DocValidator.gd must exist")
	if validator == null: return
	var valid := _validate_fixture(["valid_packet.md"], _snapshot(["req.run.day_range"]))
	assert_true(valid.ok, JSON.stringify(valid.errors))
	assert_true(_has_code(_validate_fixture(["missing_section.md"]), "DOC_REQUIREMENT_SECTION_MISSING"))
	var duplicate := _validate_fixture(["duplicate_section.md"])
	assert_true(_has_code(duplicate, "DOC_REQUIREMENT_SECTION_DUPLICATE"), JSON.stringify(duplicate.errors))
	assert_true(_has_code(_validate_fixture(["missing_dependency.md"]), "DOC_DEPENDENCY_MISSING"))
	assert_true(_has_code(_validate_fixture(["dependency_cycle_a.md", "dependency_cycle_b.md"]), "DOC_DEPENDENCY_CYCLE"))
	assert_true(_has_code(_validate_fixture(["approved_placeholder.md"]), "DOC_APPROVED_PLACEHOLDER"))
	assert_true(_has_code(_validate_fixture(["beads_metadata_drift.md"], _snapshot(["req.wrong"])), "DOC_BEAD_METADATA_DRIFT"))
	assert_true(_has_code(_validate_fixture(["valid_packet.md"]), "DOC_BEAD_SNAPSHOT_REQUIRED"))
	var ambiguous := _snapshot(["req.run.day_range"])
	ambiguous[0].metadata["requirement_ids"] = ["req.legacy"]
	assert_true(_has_code(_validate_fixture(["valid_packet.md"], ambiguous), "DOC_BEAD_METADATA_NAMESPACE_AMBIGUOUS"))

func _write_decision_fixture(specification_status: String, decision_status: String, blocking_ids: Array[String] = []) -> Dictionary:
	_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("decision-fixture-%d" % _counter)
	var requirements_path := root.path_join("requirements/sample.md")
	var decisions_path := root.path_join("decisions/sample.md")
	assert_eq(DirAccess.make_dir_recursive_absolute(requirements_path.get_base_dir()), OK)
	assert_eq(DirAccess.make_dir_recursive_absolute(decisions_path.get_base_dir()), OK)
	var requirement_file := FileAccess.open(requirements_path, FileAccess.WRITE)
	assert_not_null(requirement_file)
	if requirement_file == null:
		return {}
	requirement_file.store_string("---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample requirement.\n")
	requirement_file.close()
	var decision_file := FileAccess.open(decisions_path, FileAccess.WRITE)
	assert_not_null(decision_file)
	if decision_file == null:
		return {}
	var decision_status_line := "" if decision_status.is_empty() else "decision_status: %s\n" % decision_status
	decision_file.store_string("---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: %s\n%sbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: %s\nrecommended_investigation: [\"Re-open only if the recorded scope changes.\"]\n---\n\n# Accepted decision\n" % [specification_status, decision_status_line, JSON.stringify(blocking_ids)])
	decision_file.close()
	return load(VALIDATOR_PATH).new().validate_tree(root)

func test_accepted_decision_contract_and_index() -> void:
	var accepted := _write_decision_fixture("approved", "accepted")
	assert_true(accepted.ok, JSON.stringify(accepted.errors))
	var index := preload("res://tools/docs/DocIndexGenerator.gd").new().render(accepted)
	assert_eq(index.count("| `decision.sample` |"), 1)
	assert_false(_write_decision_fixture("draft", "accepted").ok)
	assert_false(_write_decision_fixture("approved", "").ok)
	assert_false(_write_decision_fixture("approved", "rejected").ok)
	assert_false(_write_decision_fixture("approved", "accepted", ["req.sample"]).ok)

func test_authority_index_validation_rejects_invalid_bytes_that_decode_like_expected_text() -> void:
	_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("index-bytes-%d/prompt_docs" % _counter)
	var packet_path := root.path_join("requirements/replacement.md")
	assert_eq(DirAccess.make_dir_recursive_absolute(packet_path.get_base_dir()), OK)
	var packet := FileAccess.open(packet_path, FileAccess.WRITE)
	assert_not_null(packet)
	if packet == null:
		return
	var replacement_character := String.chr(0xfffd)
	packet.store_string("---\nid: req_packet.replacement\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.replace.%s\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Replacement\n\n## Rule req.replace.%s\n\nByte-sensitive authority.\n" % [replacement_character, replacement_character])
	packet.close()
	var validator: RefCounted = preload("res://tools/docs/DocValidator.gd").new()
	var beads_snapshot: Array[Dictionary] = []
	var preliminary: Dictionary = validator.validate_tree(root, beads_snapshot)
	assert_true(_has_code(preliminary, "DOC_INDEX_DRIFT"), JSON.stringify(preliminary.errors))
	var expected := preload("res://tools/docs/DocIndexGenerator.gd").new().render(preliminary)
	var expected_bytes: PackedByteArray = expected.to_utf8_buffer()
	var replacement := _find_bytes(expected_bytes, PackedByteArray([0xef, 0xbf, 0xbd]))
	assert_ne(replacement, -1)
	var actual: PackedByteArray = expected_bytes.slice(0, replacement)
	actual.append(0xff)
	actual.append_array(expected_bytes.slice(replacement + 3))
	var index := FileAccess.open(root.path_join("INDEX.md"), FileAccess.WRITE)
	assert_not_null(index)
	if index == null:
		return
	index.store_buffer(actual)
	index.close()
	var result: Dictionary = validator.validate_tree(root, beads_snapshot)
	assert_true(_has_code(result, "DOC_INDEX_DRIFT"), JSON.stringify(result.errors))
