extends "res://addons/gut/test.gd"
## Isolated cloud checkout only: exercise real-path cache invalidation and restore
## every modified resource in after_each. No generator or validation test double.
const GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")
const DEPENDENCY := "res://data/schemas/minesweeper-generator-budget.schema.json"
var _originals: Dictionary = {}

func before_each() -> void:
	for path: String in [GENERATOR.BUDGET_MANIFEST_PATH, DEPENDENCY]:
		assert_true(FileAccess.file_exists(path), path)
		_originals[path] = FileAccess.get_file_as_bytes(path)

func after_each() -> void:
	for path: String in _originals:
		_write(path, _originals[path])
		assert_true(FileAccess.get_file_as_bytes(path) == _originals[path], "resource bytes restored")
	_originals.clear()

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, path)
	if file == null: return
	file.store_buffer(bytes)
	file.close()

func _warm() -> Dictionary:
	var result: Dictionary = GENERATOR._read_budget_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	return result.get("value", {}).duplicate(true)

func _refused(message: String, cause: String = "") -> void:
	var result: Dictionary = GENERATOR._read_budget_manifest()
	assert_false(result.ok, str(result))
	assert_eq(str(result.get("code")), "generator_budget_unavailable")
	assert_eq(result.get("message"), message)
	if not cause.is_empty(): assert_eq(str(result.get("details", {}).get("cause")), cause)

func _restore_and_match(expected: Dictionary) -> void:
	for path: String in _originals: _write(path, _originals[path])
	var result: Dictionary = GENERATOR._read_budget_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	assert_true(result.get("value") == expected, "exact restored budget")

func test_warm_results_are_detached_from_nested_caller_mutation() -> void:
	var expected := _warm()
	var cold_expected := expected.duplicate(true)
	cold_expected.device_evidence.cpu_model = "TEST.cache.cold"
	_write(GENERATOR.BUDGET_MANIFEST_PATH, JSON.stringify(cold_expected).to_utf8_buffer())
	var cold: Dictionary = GENERATOR._read_budget_manifest()
	assert_true(cold.ok, str(cold.get("code", "ok")))
	cold.value.rows[0].capability_ids.clear()
	cold.value.source_sha256.kernel = "0".repeat(64)
	var after_cold: Dictionary = GENERATOR._read_budget_manifest()
	assert_true(after_cold.ok, str(after_cold.get("code", "ok")))
	assert_true(after_cold.get("value") == cold_expected, "cold output mutation cannot alter cache")
	_restore_and_match(expected)
	var result: Dictionary = GENERATOR._read_budget_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	result.value.rows[0].capability_ids.clear()
	result.value.source_sha256.kernel = "0".repeat(64)
	result.value.device_evidence.cpu_model = "TEST.changed"
	_restore_and_match(expected)

func test_warm_cache_refuses_same_length_malformed_bytes_and_recovers() -> void:
	var expected := _warm()
	var changed: PackedByteArray = _originals[GENERATOR.BUDGET_MANIFEST_PATH].duplicate()
	changed[0] = 91
	_write(GENERATOR.BUDGET_MANIFEST_PATH, changed)
	_refused("the generator budget manifest is not strict JSON")
	_restore_and_match(expected)

func test_warm_cache_refuses_changed_schema_and_recovers() -> void:
	var expected := _warm()
	var changed := expected.duplicate(true)
	changed.hard_operation_budget += 1
	_write(GENERATOR.BUDGET_MANIFEST_PATH, JSON.stringify(changed).to_utf8_buffer())
	_refused("the generator budget manifest failed schema validation", "budget_formula_invalid")
	_restore_and_match(expected)

func test_warm_cache_rechecks_source_freshness_with_unchanged_budget_bytes() -> void:
	var expected := _warm()
	var changed: PackedByteArray = _originals[DEPENDENCY].duplicate()
	changed.append(10)
	_write(DEPENDENCY, changed)
	assert_true(FileAccess.get_file_as_bytes(GENERATOR.BUDGET_MANIFEST_PATH) == _originals[GENERATOR.BUDGET_MANIFEST_PATH], "budget bytes unchanged")
	_refused("the generator budget manifest is stale", "budget_source_stale")
	_restore_and_match(expected)

func test_warm_cache_refuses_missing_manifest_and_recovers() -> void:
	var expected := _warm()
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(GENERATOR.BUDGET_MANIFEST_PATH)), OK)
	_refused("the generator budget manifest is absent")
	_restore_and_match(expected)

func test_changed_valid_bytes_are_reparsed_and_returned_without_stale_content() -> void:
	var expected := _warm()
	var changed := expected.duplicate(true)
	changed.device_evidence.cpu_model = "TEST.cache.changed-valid"
	_write(GENERATOR.BUDGET_MANIFEST_PATH, JSON.stringify(changed).to_utf8_buffer())
	var result: Dictionary = GENERATOR._read_budget_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	assert_true(result.get("value") == changed, "exact replacement budget")
	_restore_and_match(expected)
