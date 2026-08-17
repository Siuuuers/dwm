extends "res://addons/gut/test.gd"
# Task 3 Step 3.1 (dwm-p2r.9 Plan 06): the desktop handoff artifact is the thing Phase 3 trusts
# INSTEAD OF reading Phase 2R source, so every claim it makes must fail closed when tampered with.
#
# The five required properties, in order: strict parse with duplicate-member rejection; schema and
# evidence-class validation; recomputed source digests with exact ordered binding equality; a
# canonical rebuild that is byte-equal to the checked-in artifact; and a mutation sweep in isolated
# copies where every single-field, nested-record, and binding tamper is rejected.
#
# PARSE HAZARD: the CLI wrappers extend SceneTree. They are probed with load_script() and NEVER
# instantiated -- instantiating one would construct a SceneTree and execute the tool.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const EVIDENCE := preload("res://tools/evidence/DesktopContractEvidence.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const ARTIFACT_PATH := "res://evidence/phase_2r/handoff/desktop_contract.json"
const SCHEMA_PATH := "res://schemas/evidence/desktop-contract.schema.json"


func _artifact() -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(ARTIFACT_PATH).get_string_from_utf8())
	assert_true(parsed.get("ok", false), "the artifact strict-parses")
	return parsed.get("value", {}) as Dictionary


func test_evidence_class_and_both_clis_exist() -> void:
	for path: String in [
		"res://tools/evidence/DesktopContractEvidence.gd",
		"res://tools/evidence/generate_desktop_contract.gd",
		"res://tools/evidence/validate_desktop_contract.gd",
	]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(loaded))


func test_schema_and_artifact_strict_parse_and_reject_duplicate_members() -> void:
	for path: String in [ARTIFACT_PATH, SCHEMA_PATH]:
		assert_true(FileAccess.file_exists(path), path)
		var parsed: Dictionary = STRICT_JSON.parse_object(
			FileAccess.get_file_as_bytes(path).get_string_from_utf8())
		assert_true(parsed.get("ok", false), "%s: %s" % [path, parsed])
	# The strict parser is what rejects a duplicated member, so prove it actually does.
	var duplicated: Dictionary = STRICT_JSON.parse_object(
		'{"artifact_id": "a", "artifact_id": "b"}')
	assert_false(duplicated.get("ok", false), "a duplicate member is rejected")


func test_artifact_passes_schema_and_evidence_validation() -> void:
	var artifact := _artifact()
	assert_true(EVIDENCE.validate_schema(artifact).get("ok", false), "schema pass")
	assert_true(EVIDENCE.validate(artifact).get("ok", false), "evidence-class pass")
	assert_eq(int(artifact["interface_version"]), 1)
	assert_eq(str(artifact["artifact_id"]), "phase_2r.desktop_contract")


func test_every_source_digest_recomputes_to_exact_ordered_binding_equality() -> void:
	var artifact := _artifact()
	var bindings: Array = artifact["source_bindings"]
	assert_eq(bindings.size(), EVIDENCE.SOURCE_BINDING_PATHS.size(),
		"no inferred, omitted, extra, or glob-expanded binding")
	for index: int in range(bindings.size()):
		var record: Dictionary = bindings[index]
		var expected_path: String = EVIDENCE.SOURCE_BINDING_PATHS[index]
		assert_eq(str(record["path"]), expected_path, "binding %d is in frozen sorted order" % index)
		var actual := EVIDENCE.digest_bytes(FileAccess.get_file_as_bytes("res://" + expected_path))
		assert_eq(str(record["sha256"]), actual, "recomputed digest for " + expected_path)
	# Sorted by UTF-8 path bytes.
	var paths: Array = []
	for record: Dictionary in bindings:
		paths.append(str(record["path"]))
	var sorted_paths: Array = paths.duplicate()
	sorted_paths.sort()
	assert_eq(paths, sorted_paths, "bindings are sorted by UTF-8 path bytes")


func test_rebuilt_artifact_is_byte_equal_to_the_checked_in_bytes() -> void:
	var rebuilt: Dictionary = EVIDENCE.build()
	assert_true(rebuilt.get("ok", false), str(rebuilt))
	if not rebuilt.get("ok", false):
		return
	var canonical: Dictionary = EVIDENCE.canonical_bytes(
		(rebuilt.get("value", {}) as Dictionary).get("artifact", {}) as Dictionary)
	assert_true(canonical.get("ok", false), str(canonical))
	assert_eq((canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray()),
		FileAccess.get_file_as_bytes(ARTIFACT_PATH),
		"the checked-in artifact is the canonical serialization of a fresh production build")


func test_every_top_level_field_mutation_fails_closed() -> void:
	for field: String in EVIDENCE.FIELD_KEYS:
		# Removal.
		var without := _artifact()
		without.erase(field)
		assert_false(EVIDENCE.validate(without).get("ok", false), "removing %s must fail" % field)
		# Replacement with a foreign but well-typed value.
		var swapped := _artifact()
		swapped[field] = _foreign_value(swapped[field])
		assert_false(EVIDENCE.validate(swapped).get("ok", false), "mutating %s must fail" % field)
	# An extra member is not tolerated either.
	var extra := _artifact()
	extra["unexpected_member"] = 1
	assert_false(EVIDENCE.validate(extra).get("ok", false), "an unknown member must fail")


func test_every_nested_contract_record_mutation_fails_closed() -> void:
	# Registry rows: every app id, scene and focus target.
	var records: Array = _artifact()["registry_records"]
	for index: int in range(records.size()):
		for key: String in ["app_id", "scene", "focus_target"]:
			var tampered := _artifact()
			var rows: Array = (tampered["registry_records"] as Array).duplicate(true)
			var row: Dictionary = (rows[index] as Dictionary).duplicate(true)
			row[key] = str(row[key]) + "-tampered"
			rows[index] = row
			tampered["registry_records"] = rows
			assert_false(EVIDENCE.validate(tampered).get("ok", false),
				"registry row %d %s must fail" % [index, key])
	# Every Logout row.
	var logout_rows: Array = (_artifact()["logout_contract"] as Dictionary)["rows"]
	for index: int in range(logout_rows.size()):
		var tampered := _artifact()
		var contract: Dictionary = (tampered["logout_contract"] as Dictionary).duplicate(true)
		var rows: Array = (contract["rows"] as Array).duplicate(true)
		var row: Dictionary = (rows[index] as Dictionary).duplicate(true)
		row["should_save"] = not bool(row["should_save"])
		rows[index] = row
		contract["rows"] = rows
		tampered["logout_contract"] = contract
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"logout row %d must fail" % index)
	# The shared fatal-projector schema, its constant fallback, and the exact final-guard return.
	for key: String in ["projector", "fallback", "result"]:
		var tampered := _artifact()
		var owner: Dictionary = (tampered["day_change_owner"] as Dictionary).duplicate(true)
		var dispatch: Dictionary = (owner["missing_or_failing_dispatch"] as Dictionary).duplicate(true)
		dispatch[key] = "tampered" if typeof(dispatch[key]) == TYPE_STRING else {"tampered": true}
		owner["missing_or_failing_dispatch"] = dispatch
		tampered["day_change_owner"] = owner
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"day-change dispatch %s must fail" % key)
	# The day-change owner/once rule and the Phase-3 prohibition.
	for key: String in ["day_changed_connections", "phase_3_is_forbidden_to"]:
		var tampered := _artifact()
		var owner: Dictionary = (tampered["day_change_owner"] as Dictionary).duplicate(true)
		owner[key] = 2 if typeof(owner[key]) == TYPE_INT else []
		tampered["day_change_owner"] = owner
		assert_false(EVIDENCE.validate(tampered).get("ok", false), "day_change_owner.%s must fail" % key)
	# The stable narrative Callable and the unchanged adapter/real-port/consumer identity record.
	for key: String in ["callable_identity_replaced_by_host_injection",
			"narrative_checkpoint_port_identity_replaced", "real_checkpoint_port_identity_replaced",
			"dialogic_bridge_identity_replaced", "game_state_identity_replaced",
			"direct_checkpoint_provider_reads_the_same_host", "never_returns"]:
		var tampered := _artifact()
		var persistence: Dictionary = (tampered["persistence_signatures"] as Dictionary).duplicate(true)
		persistence[key] = (not bool(persistence[key])) if typeof(persistence[key]) == TYPE_BOOL else "tampered"
		tampered["persistence_signatures"] = persistence
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"persistence_signatures.%s must fail" % key)
	# Host result shapes.
	for key: Variant in (_artifact()["host_result_schemas"] as Dictionary).keys():
		var tampered := _artifact()
		var shapes: Dictionary = (tampered["host_result_schemas"] as Dictionary).duplicate(true)
		shapes[str(key)] = "tampered"
		tampered["host_result_schemas"] = shapes
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"host_result_schemas.%s must fail" % str(key))


func test_every_mandatory_binding_delete_reorder_rename_or_corruption_fails_closed() -> void:
	var count: int = EVIDENCE.SOURCE_BINDING_PATHS.size()
	for index: int in range(count):
		# Delete.
		var deleted := _artifact()
		var bindings: Array = (deleted["source_bindings"] as Array).duplicate(true)
		bindings.remove_at(index)
		deleted["source_bindings"] = bindings
		assert_false(EVIDENCE.validate(deleted).get("ok", false), "deleting binding %d must fail" % index)
		# Path rename.
		var renamed := _artifact()
		var renamed_bindings: Array = (renamed["source_bindings"] as Array).duplicate(true)
		var renamed_record: Dictionary = (renamed_bindings[index] as Dictionary).duplicate(true)
		renamed_record["path"] = str(renamed_record["path"]) + ".renamed"
		renamed_bindings[index] = renamed_record
		renamed["source_bindings"] = renamed_bindings
		assert_false(EVIDENCE.validate(renamed).get("ok", false), "renaming binding %d must fail" % index)
		# Hash corruption.
		var corrupted := _artifact()
		var corrupted_bindings: Array = (corrupted["source_bindings"] as Array).duplicate(true)
		var corrupted_record: Dictionary = (corrupted_bindings[index] as Dictionary).duplicate(true)
		corrupted_record["sha256"] = "0".repeat(64)
		corrupted_bindings[index] = corrupted_record
		corrupted["source_bindings"] = corrupted_bindings
		assert_false(EVIDENCE.validate(corrupted).get("ok", false),
			"corrupting binding %d must fail" % index)
	# Reorder: swapping any adjacent pair breaks the frozen order.
	for index: int in range(count - 1):
		var reordered := _artifact()
		var bindings: Array = (reordered["source_bindings"] as Array).duplicate(true)
		var carried: Variant = bindings[index]
		bindings[index] = bindings[index + 1]
		bindings[index + 1] = carried
		reordered["source_bindings"] = bindings
		assert_false(EVIDENCE.validate(reordered).get("ok", false),
			"reordering bindings %d/%d must fail" % [index, index + 1])


func test_an_uppercase_digest_is_rejected_even_though_the_schema_subset_allows_it() -> void:
	# The repo's JsonSchemaValidator honours minLength but not pattern, so digest CASE is caught
	# only by the imperative law. A weakened schema therefore cannot widen what is accepted.
	var tampered := _artifact()
	var bindings: Array = (tampered["source_bindings"] as Array).duplicate(true)
	var record: Dictionary = (bindings[0] as Dictionary).duplicate(true)
	record["sha256"] = str(record["sha256"]).to_upper()
	bindings[0] = record
	tampered["source_bindings"] = bindings
	assert_true(EVIDENCE.validate_schema(tampered).get("ok", false),
		"the schema subset alone accepts an uppercase digest")
	assert_false(EVIDENCE.validate(tampered).get("ok", false),
		"the imperative law rejects it")


func _foreign_value(original: Variant) -> Variant:
	match typeof(original):
		TYPE_INT:
			return int(original) + 1
		TYPE_STRING:
			return str(original) + "-tampered"
		TYPE_BOOL:
			return not bool(original)
		TYPE_ARRAY:
			return []
		TYPE_DICTIONARY:
			return {"tampered": true}
	return "tampered"
