extends "res://addons/gut/test.gd"
## Isolated cloud checkout only: exercise real-path cache invalidation and restore
## every modified resource in after_each. No generator or validation test double.
const GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const DEPENDENCY := "res://data/schemas/minesweeper-generator-budget.schema.json"
var _originals: Dictionary = {}

func before_each() -> void:
	for path: String in [GENERATOR.BUDGET_MANIFEST_PATH, GENERATOR.FALLBACK_MANIFEST_PATH, DEPENDENCY]:
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
	assert_false(result.ok, str(result.get("code", "ok")))
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


func _warm_fallback() -> Dictionary:
	var result: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	return result.get("value", {}).duplicate(true)

func _fallback_artifact() -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(
		(_originals[GENERATOR.FALLBACK_MANIFEST_PATH] as PackedByteArray).get_string_from_utf8())
	assert_true(parsed.ok, "original fallback parses")
	return parsed.get("value", {})

func _fallback_refused(message: String, cause: String = "") -> void:
	var result: Dictionary = GENERATOR._read_fallback_manifest()
	assert_false(result.ok, str(result.get("code", "ok")))
	assert_eq(str(result.get("code")), "generator_budget_unavailable")
	assert_eq(result.get("message"), message)
	if not cause.is_empty(): assert_eq(str(result.get("details", {}).get("cause")), cause)

func _restore_fallback_and_match(expected: Dictionary) -> void:
	_write(GENERATOR.FALLBACK_MANIFEST_PATH, _originals[GENERATOR.FALLBACK_MANIFEST_PATH])
	var result: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	assert_true(result.get("value") == expected, "exact restored fallback")

func test_fallback_cold_and_warm_results_are_detached_from_nested_caller_mutation() -> void:
	var expected := _warm_fallback()
	var changed: PackedByteArray = _originals[GENERATOR.FALLBACK_MANIFEST_PATH].duplicate()
	changed.append(10)
	_write(GENERATOR.FALLBACK_MANIFEST_PATH, changed)
	var cold: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(cold.ok, str(cold.get("code", "ok")))
	cold.value.records[0].mine_indices.clear()
	var warm: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(warm.ok, str(warm.get("code", "ok")))
	assert_true(warm.get("value") == expected, "cold output mutation cannot alter fallback cache")
	warm.value.records[0].mine_indices.clear()
	var after_warm: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(after_warm.ok, str(after_warm.get("code", "ok")))
	assert_true(after_warm.get("value") == expected, "warm output mutation cannot alter fallback cache")
	_restore_fallback_and_match(expected)

func test_fallback_warm_cache_refuses_same_length_malformed_bytes_and_recovers() -> void:
	var expected := _warm_fallback()
	var changed: PackedByteArray = _originals[GENERATOR.FALLBACK_MANIFEST_PATH].duplicate()
	changed[0] = 91
	_write(GENERATOR.FALLBACK_MANIFEST_PATH, changed)
	_fallback_refused("the certified fallback manifest is not strict JSON")
	_restore_fallback_and_match(expected)

func test_fallback_warm_cache_refuses_mine_count_schema_change_and_recovers() -> void:
	var expected := _warm_fallback()
	var changed := _fallback_artifact()
	changed.records[0].mine_count += 1
	_write(GENERATOR.FALLBACK_MANIFEST_PATH, JSON.stringify(changed).to_utf8_buffer())
	_fallback_refused("the certified fallback manifest failed schema validation", "fallback_record_invalid")
	_restore_fallback_and_match(expected)

func test_fallback_warm_cache_refuses_missing_manifest_and_recovers() -> void:
	var expected := _warm_fallback()
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(GENERATOR.FALLBACK_MANIFEST_PATH)), OK)
	_fallback_refused("the certified fallback manifest is absent")
	_restore_fallback_and_match(expected)

func test_fallback_changed_valid_records_are_reparsed_without_stale_content() -> void:
	var expected := _warm_fallback()
	var changed := _fallback_artifact()
	changed.records.reverse()
	assert_true(changed.records != expected.records, "replacement order differs")
	_write(GENERATOR.FALLBACK_MANIFEST_PATH, JSON.stringify(changed).to_utf8_buffer())
	var result: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(result.ok, str(result.get("code", "ok")))
	assert_true(result.get("value") == {"records": changed.records}, "exact replacement fallback")
	_restore_fallback_and_match(expected)

func _debug_spec() -> Dictionary:
	return {
		"schema_version": 1, "board_kind": "solo_challenge", "board_token": "token-cache",
		"board_token_receipt_id": "receipt-token-cache", "difficulty_id": "beginner",
		"width": 8, "height": 8, "base_mine_count": 10, "pressure": 0, "penalty_points_today": 0,
		"raw_extra_mines": 0, "requested_mine_count": 10,
		"capability_ids": ["first_cell_safe", "forced_no_guess"],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "bg-cache-placement",
		"placement_nonce_receipt_id": "receipt-placement-cache",
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "bg-cache-debug",
		"debug_nonce_receipt_id": "receipt-debug-cache",
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "bg-cache-explosion",
		"explosion_nonce_receipt_id": "receipt-explosion-cache",
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}

func test_fallback_cache_cannot_bypass_public_source_freshness_with_unchanged_budget() -> void:
	_warm()
	var expected := _warm_fallback()
	var original_begin: Dictionary = GENERATOR.begin_debug(_debug_spec())
	assert_true(original_begin.ok, str(original_begin.get("code", "ok")))
	var changed := _fallback_artifact()
	changed.records.reverse()
	_write(GENERATOR.FALLBACK_MANIFEST_PATH, JSON.stringify(changed).to_utf8_buffer())
	var changed_read: Dictionary = GENERATOR._read_fallback_manifest()
	assert_true(changed_read.ok, str(changed_read.get("code", "ok")))
	assert_true(changed_read.get("value") == {"records": changed.records}, "replacement cached")
	assert_true(FileAccess.get_file_as_bytes(GENERATOR.BUDGET_MANIFEST_PATH) == _originals[GENERATOR.BUDGET_MANIFEST_PATH], "budget bytes unchanged")
	var refused: Dictionary = GENERATOR.begin_debug(_debug_spec())
	assert_false(refused.ok, str(refused.get("code", "ok")))
	assert_eq(str(refused.get("code")), "generator_budget_unavailable")
	assert_eq(refused.get("message"), "the generator budget manifest is stale")
	assert_eq(str(refused.get("details", {}).get("cause")), "budget_source_stale")
	_restore_fallback_and_match(expected)
	var restored: Dictionary = GENERATOR.begin_debug(_debug_spec())
	assert_true(restored.ok, str(restored.get("code", "ok")))
	assert_true(restored == original_begin, "restoration preserves deterministic begin state")
