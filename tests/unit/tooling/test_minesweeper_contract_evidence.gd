extends "res://addons/gut/test.gd"
# Task 3 Step 3.1 (dwm-p2r.9 Plan 06): the Minesweeper handoff artifact is what Phase 3 drives
# real rounds against without reading Phase 2R source, so every claim must fail closed when
# tampered with.
#
# The five required properties, in order: strict parse with duplicate-member rejection; schema and
# evidence-class validation; recomputed source digests with exact ordered binding equality; a
# canonical rebuild that is byte-equal to the checked-in artifact; and a mutation sweep covering
# every port signature (including latch_fatal / is_fatal_latched / guard_external), the
# projector/fallback/final-guard ordering, retained fatal details, normalized_result, the
# reason=stage post-result call, both retry phases, every source hash, and one fixture id.
#
# PARSE HAZARD: the CLI wrappers extend SceneTree. They are probed with load_script() and NEVER
# instantiated -- instantiating one would construct a SceneTree and execute the tool.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const EVIDENCE := preload("res://tools/evidence/MinesweeperContractEvidence.gd")
const CONTRACT := preload("res://scripts/domain/minesweeper/MinesweeperRoundContract.gd")
const COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const ARTIFACT_PATH := "res://evidence/phase_2r/handoff/minesweeper_contract.json"
const SCHEMA_PATH := "res://schemas/evidence/minesweeper-contract.schema.json"


func _artifact() -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(ARTIFACT_PATH).get_string_from_utf8())
	assert_true(parsed.get("ok", false), "the artifact strict-parses")
	return parsed.get("value", {}) as Dictionary


func test_evidence_class_and_both_clis_exist() -> void:
	for path: String in [
		"res://tools/evidence/MinesweeperContractEvidence.gd",
		"res://tools/evidence/generate_minesweeper_contract.gd",
		"res://tools/evidence/validate_minesweeper_contract.gd",
	]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(loaded))


func test_schema_and_artifact_strict_parse_and_reject_duplicate_members() -> void:
	for path: String in [ARTIFACT_PATH, SCHEMA_PATH]:
		assert_true(FileAccess.file_exists(path), path)
		var parsed: Dictionary = STRICT_JSON.parse_object(
			FileAccess.get_file_as_bytes(path).get_string_from_utf8())
		assert_true(parsed.get("ok", false), "%s: %s" % [path, parsed])
	var duplicated: Dictionary = STRICT_JSON.parse_object('{"outcomes": [], "outcomes": []}')
	assert_false(duplicated.get("ok", false), "a duplicate member is rejected")


func test_artifact_passes_schema_and_evidence_validation() -> void:
	var artifact := _artifact()
	assert_true(EVIDENCE.validate_schema(artifact).get("ok", false), "schema pass")
	assert_true(EVIDENCE.validate(artifact).get("ok", false), "evidence-class pass")
	assert_eq(int(artifact["interface_version"]), 1)
	assert_eq(str(artifact["artifact_id"]), "phase_2r.minesweeper_contract")


func test_vocabularies_are_transcribed_from_the_production_contract() -> void:
	var artifact := _artifact()
	var difficulties: Array = []
	for value: StringName in CONTRACT.DIFFICULTIES:
		difficulties.append(String(value))
	var outcomes: Array = []
	for value: StringName in CONTRACT.OUTCOMES:
		outcomes.append(String(value))
	var codes: Array = []
	for value: StringName in COORDINATOR.FAILURE_CODES:
		codes.append(String(value))
	assert_eq(artifact["difficulties"], difficulties, "difficulties come from production")
	assert_eq(artifact["outcomes"], outcomes, "outcomes come from production")
	assert_eq(artifact["failure_codes"], codes, "failure codes come from production")
	assert_eq((artifact["fixture_ids"] as Array).size(), 15, "all fifteen fixtures are named")


func test_every_source_digest_recomputes_to_exact_ordered_binding_equality() -> void:
	var artifact := _artifact()
	var bindings: Array = artifact["source_bindings"]
	assert_eq(bindings.size(), EVIDENCE.SOURCE_BINDING_PATHS.size(),
		"no inferred, omitted, extra, or glob-expanded binding")
	for index: int in range(bindings.size()):
		var record: Dictionary = bindings[index]
		var expected_path: String = EVIDENCE.SOURCE_BINDING_PATHS[index]
		assert_eq(str(record["path"]), expected_path, "binding %d is in frozen sorted order" % index)
		assert_eq(str(record["sha256"]),
			EVIDENCE.digest_bytes(FileAccess.get_file_as_bytes("res://" + expected_path)),
			"recomputed digest for " + expected_path)
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
		var without := _artifact()
		without.erase(field)
		assert_false(EVIDENCE.validate(without).get("ok", false), "removing %s must fail" % field)
		var swapped := _artifact()
		swapped[field] = _foreign_value(swapped[field])
		assert_false(EVIDENCE.validate(swapped).get("ok", false), "mutating %s must fail" % field)
	var extra := _artifact()
	extra["unexpected_member"] = 1
	assert_false(EVIDENCE.validate(extra).get("ok", false), "an unknown member must fail")


func test_every_port_signature_mutation_including_the_three_gate_methods_fails_closed() -> void:
	for group: String in ["state_port", "save_port", "coordinator"]:
		var signatures: Array = (_artifact()["port_signatures"] as Dictionary)[group]
		for index: int in range(signatures.size()):
			var tampered := _artifact()
			var ports: Dictionary = (tampered["port_signatures"] as Dictionary).duplicate(true)
			var list: Array = (ports[group] as Array).duplicate(true)
			list[index] = str(list[index]) + " # tampered"
			ports[group] = list
			tampered["port_signatures"] = ports
			assert_false(EVIDENCE.validate(tampered).get("ok", false),
				"%s signature %d must fail" % [group, index])
	# The three gate methods are individually present and individually load-bearing.
	var state_port: Array = (_artifact()["port_signatures"] as Dictionary)["state_port"]
	for method: String in ["latch_fatal", "is_fatal_latched", "guard_external"]:
		var found := false
		for signature: Variant in state_port:
			if str(signature).begins_with(method + "("):
				found = true
		assert_true(found, "the state port declares " + method)
		var tampered := _artifact()
		var ports: Dictionary = (tampered["port_signatures"] as Dictionary).duplicate(true)
		var list: Array = []
		for signature: Variant in (ports["state_port"] as Array):
			if not str(signature).begins_with(method + "("):
				list.append(signature)
		ports["state_port"] = list
		tampered["port_signatures"] = ports
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"dropping %s must fail" % method)


func test_fatal_latch_projection_order_and_retained_details_mutations_fail_closed() -> void:
	for key: Variant in (_artifact()["fatal_latch_contract"] as Dictionary).keys():
		var tampered := _artifact()
		var latch: Dictionary = (tampered["fatal_latch_contract"] as Dictionary).duplicate(true)
		latch[str(key)] = _foreign_value(latch[str(key)])
		tampered["fatal_latch_contract"] = latch
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"fatal_latch_contract.%s must fail" % str(key))
	# Reordering the recovery sequence is itself a tamper.
	var reordered := _artifact()
	var latch: Dictionary = (reordered["fatal_latch_contract"] as Dictionary).duplicate(true)
	var order: Array = (latch["recovery_order"] as Array).duplicate(true)
	var carried: Variant = order[0]
	order[0] = order[1]
	order[1] = carried
	latch["recovery_order"] = order
	reordered["fatal_latch_contract"] = latch
	assert_false(EVIDENCE.validate(reordered).get("ok", false), "recovery order is frozen")


func test_normalized_result_retry_phases_and_the_stage_post_result_call_fail_closed() -> void:
	# normalized_result inside the pending record.
	var tampered_normalized := _artifact()
	var pending: Dictionary = (tampered_normalized["pending_record_schema"] as Dictionary).duplicate(true)
	pending["normalized_result"] = {"keys": ["outcome", "difficulty"], "value_type": "String"}
	tampered_normalized["pending_record_schema"] = pending
	assert_false(EVIDENCE.validate(tampered_normalized).get("ok", false),
		"normalized_result is exactly one String-valued outcome key")
	# Both retry phases.
	var tampered_phase := _artifact()
	var phases: Dictionary = (tampered_phase["pending_record_schema"] as Dictionary).duplicate(true)
	phases["phase"] = ["publish"]
	tampered_phase["pending_record_schema"] = phases
	assert_false(EVIDENCE.validate(tampered_phase).get("ok", false),
		"both publish and release_lock phases are frozen")
	# The literal post-result call with reason=stage.
	var lock: Dictionary = _artifact()["save_lock_contract"]
	assert_eq(str((lock["post_result_disk_write"] as Dictionary)["reason"]), "stage")
	assert_eq(str((lock["post_result_disk_write"] as Dictionary)["kind"]), "none")
	assert_eq(str(lock["post_result_checkpoint_kind"]), "post_result")
	for key: String in ["kind", "reason"]:
		var tampered := _artifact()
		var contract: Dictionary = (tampered["save_lock_contract"] as Dictionary).duplicate(true)
		var disk_write: Dictionary = (contract["post_result_disk_write"] as Dictionary).duplicate(true)
		disk_write[key] = "tampered"
		contract["post_result_disk_write"] = disk_write
		tampered["save_lock_contract"] = contract
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"post_result disk_write %s must fail" % key)
	# And the durable pre-board pairing.
	var tampered_pre_board := _artifact()
	var pre_contract: Dictionary = (tampered_pre_board["save_lock_contract"] as Dictionary).duplicate(true)
	pre_contract["pre_board_disk_write"] = {"kind": "none", "reason": "stage"}
	tampered_pre_board["save_lock_contract"] = pre_contract
	assert_false(EVIDENCE.validate(tampered_pre_board).get("ok", false),
		"the pre-board autosave pairing is frozen")


func test_one_fixture_id_mutation_fails_closed() -> void:
	var ids: Array = _artifact()["fixture_ids"]
	for index: int in range(ids.size()):
		var tampered := _artifact()
		var list: Array = (tampered["fixture_ids"] as Array).duplicate(true)
		list[index] = str(list[index]) + "-tampered"
		tampered["fixture_ids"] = list
		assert_false(EVIDENCE.validate(tampered).get("ok", false),
			"fixture id %d must fail" % index)


func test_every_mandatory_binding_delete_reorder_rename_or_corruption_fails_closed() -> void:
	var count: int = EVIDENCE.SOURCE_BINDING_PATHS.size()
	for index: int in range(count):
		var deleted := _artifact()
		var bindings: Array = (deleted["source_bindings"] as Array).duplicate(true)
		bindings.remove_at(index)
		deleted["source_bindings"] = bindings
		assert_false(EVIDENCE.validate(deleted).get("ok", false), "deleting binding %d must fail" % index)

		var renamed := _artifact()
		var renamed_bindings: Array = (renamed["source_bindings"] as Array).duplicate(true)
		var renamed_record: Dictionary = (renamed_bindings[index] as Dictionary).duplicate(true)
		renamed_record["path"] = str(renamed_record["path"]) + ".renamed"
		renamed_bindings[index] = renamed_record
		renamed["source_bindings"] = renamed_bindings
		assert_false(EVIDENCE.validate(renamed).get("ok", false), "renaming binding %d must fail" % index)

		var corrupted := _artifact()
		var corrupted_bindings: Array = (corrupted["source_bindings"] as Array).duplicate(true)
		var corrupted_record: Dictionary = (corrupted_bindings[index] as Dictionary).duplicate(true)
		corrupted_record["sha256"] = "0".repeat(64)
		corrupted_bindings[index] = corrupted_record
		corrupted["source_bindings"] = corrupted_bindings
		assert_false(EVIDENCE.validate(corrupted).get("ok", false),
			"corrupting binding %d must fail" % index)
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
	var tampered := _artifact()
	var bindings: Array = (tampered["source_bindings"] as Array).duplicate(true)
	var record: Dictionary = (bindings[0] as Dictionary).duplicate(true)
	record["sha256"] = str(record["sha256"]).to_upper()
	bindings[0] = record
	tampered["source_bindings"] = bindings
	assert_true(EVIDENCE.validate_schema(tampered).get("ok", false),
		"the schema subset alone accepts an uppercase digest")
	assert_false(EVIDENCE.validate(tampered).get("ok", false), "the imperative law rejects it")


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
		TYPE_NIL:
			return "tampered"
	return "tampered"
