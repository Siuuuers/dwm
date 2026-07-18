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
