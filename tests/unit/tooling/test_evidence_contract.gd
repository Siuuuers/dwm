extends "res://addons/gut/test.gd"

const VALIDATOR_PATH := "res://tools/evidence/EvidenceValidator.gd"
const BASELINE_PATH := "res://evidence/phase_2r/baseline.json"
const SCHEMA_PATH := "res://prompt_docs/schemas/evidence_report.v1.json"
const INVENTORY_PATH := "evidence/phase_2r/legacy/legacy_heading_inventory.v1.json"

func test_baseline_exists_and_matches_schema() -> void:
	var validator_script: Script = load(VALIDATOR_PATH)
	assert_not_null(validator_script, "EvidenceValidator must exist")
	if validator_script == null:
		return
	var result: Dictionary = validator_script.validate_file(BASELINE_PATH, SCHEMA_PATH)
	assert_true(result.get("ok", false), JSON.stringify(result.get("errors", [])))

func test_every_command_proves_an_isolated_user_dir() -> void:
	var validator_script: Script = load(VALIDATOR_PATH)
	assert_not_null(validator_script, "EvidenceValidator must exist")
	if validator_script == null:
		return
	var result: Dictionary = validator_script.validate_file(BASELINE_PATH, SCHEMA_PATH)
	assert_true(result.get("ok", false))
	if not result.get("ok", false):
		return
	for command: Dictionary in result["evidence"]["commands"]:
		var root: String = str(command["test_root"]).replace("\\", "/").trim_suffix("/").to_lower()
		var user_dir: String = str(command["user_dir"]).replace("\\", "/").to_lower()
		assert_true(root.contains("/.godot/phase2r_tests/"))
		assert_true(user_dir.begins_with(root + "/"))

func test_heading_inventory_hash_is_bound_into_baseline() -> void:
	var validator_script: Script = load(VALIDATOR_PATH)
	assert_not_null(validator_script, "EvidenceValidator must exist")
	if validator_script == null:
		return
	var result: Dictionary = validator_script.validate_file(BASELINE_PATH, SCHEMA_PATH)
	assert_true(result.get("ok", false))
	if not result.get("ok", false):
		return
	assert_eq(result["evidence"]["legacy_heading_inventory"]["path"], INVENTORY_PATH)
