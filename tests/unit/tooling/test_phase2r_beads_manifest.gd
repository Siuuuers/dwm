extends "res://addons/gut/test.gd"

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const JSON_SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const AUTHORITY_RESOLVER := preload("res://tools/docs/AgentWorkflowAuthorityResolver.gd")
const MANIFEST_PATH := "res://prompt_docs/metadata/phase_2r_beads.v1.json"
const SCHEMA_PATH := "res://prompt_docs/schemas/phase_2r_beads_metadata.v1.json"
const RETAINED_PLAN_INDEX := "docs/superpowers/plans/2026-07-17-phase-2r-foundation-repair.md"
const HISTORICAL_INDEX_RECORDS := [
	"dwm-p2r.1",
	"dwm-p2r.2",
	"dwm-p2r.3",
	"dwm-p2r.4",
	"dwm-p2r.5",
]

func test_real_phase2r_manifest_conforms_to_its_schema() -> void:
	var manifest := _read_strict_object(MANIFEST_PATH)
	var schema := _read_strict_object(SCHEMA_PATH)
	var result: Dictionary = JSON_SCHEMA_VALIDATOR.validate(manifest, schema)
	assert_true(result.get("ok", false), str(result))

func test_every_contract_plan_path_is_a_real_regular_repository_file() -> void:
	var manifest := _read_strict_object(MANIFEST_PATH)
	for contract: Dictionary in manifest.get("child_contracts", []):
		var plan_path := str(contract.get("plan_path", ""))
		assert_true(
			FileAccess.file_exists("res://" + plan_path),
			"%s must bind a retained plan file: %s" % [contract.get("issue_id"), plan_path]
		)

func test_closed_first_five_contracts_bind_the_surviving_plan_set_index() -> void:
	var manifest := _read_strict_object(MANIFEST_PATH)
	var by_id := {}
	for contract: Dictionary in manifest.get("child_contracts", []):
		by_id[str(contract.get("issue_id"))] = contract
	for issue_id: String in HISTORICAL_INDEX_RECORDS:
		assert_true(by_id.has(issue_id), "missing contract " + issue_id)
		if by_id.has(issue_id):
			assert_eq(by_id[issue_id].get("plan_path"), RETAINED_PLAN_INDEX)

func test_every_manifest_specification_id_resolves_through_the_closed_design_registry() -> void:
	var manifest := _read_strict_object(MANIFEST_PATH)
	var ids := {
		str(manifest.get("spec_id", "")): true,
		str(manifest.get("deferred_decision_contract", {}).get("expected_spec_id", "")): true,
	}
	for contract: Dictionary in manifest.get("child_contracts", []):
		ids[str(contract.get("expected_spec_id", ""))] = true
	var resolver: RefCounted = AUTHORITY_RESOLVER.new("res://", [])
	for specification_id: String in ids.keys():
		var result: Dictionary = resolver.resolve({"kind":"specification_id", "target":specification_id})
		assert_true(result.get("ok", false), "%s: %s" % [specification_id, JSON.stringify(result)])

func _read_strict_object(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "missing " + path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_strict_text(FileAccess.get_file_as_string(path))
	assert_true(parsed.get("ok", false), str(parsed))
	if not parsed.get("ok", false):
		return {}
	assert_eq(typeof(parsed.get("value")), TYPE_DICTIONARY)
	return parsed.get("value", {})
