extends "res://addons/gut/test.gd"

# =================================================================================================
# EvidenceValidator's contract.
#
# The first three tests are the pre-existing baseline contract and are unchanged. The rest were
# added by dwm-p2r.10 Task 3 Step 1, when the cross-field pass became document-aware.
#
# WHY IT HAD TO CHANGE. _validate_cross_fields ran unconditionally and hard-read the baseline shape
# (source_archive, preserved_outside_authority, commands, archived_logs, legacy_heading_inventory),
# so validate_file could never be pointed at any document but baseline.json. The closeout gate needs
# the same strict schema-plus-cross-field treatment, so the pass now dispatches on the document's
# own `kind`, and an unrecognised kind fails closed instead of silently skipping every law.
#
# SCOPE OF THE CLOSEOUT LAWS. They are settled entirely inside the document. Nothing here reads a
# log off disk: the on-disk triple-hash belongs to Phase2RCloseoutInventory, which resolves logs
# against the evidence root it was handed, and a second copy here would only be free to diverge.
# =================================================================================================

const VALIDATOR_PATH := "res://tools/evidence/EvidenceValidator.gd"
const BASELINE_PATH := "res://evidence/phase_2r/baseline.json"
const SCHEMA_PATH := "res://prompt_docs/schemas/evidence_report.v1.json"
const INVENTORY_PATH := "evidence/phase_2r/legacy/legacy_heading_inventory.v1.json"

const CLOSEOUT_SCHEMA_PATH := "res://schemas/evidence/phase2r-closeout-gate.schema.json"
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const EVIDENCE_ROOT_RELATIVE := "evidence/phase_2r/closeout"
const EVIDENCE_LOG_ROOT_RELATIVE := "evidence/phase_2r/closeout/logs"
const SUBJECT_COMMIT := "1111111111111111111111111111111111111111"
const TREE_ID := "2222222222222222222222222222222222222222"
const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
const COMMAND_IDS: Array[String] = ["docs-validate", "gut-complete", "schedule-gate"]
const REQUIREMENT_IDS: Array[String] = ["req.config.version", "req.test.isolation", "req.test.layers"]

var _scratch_root := ""


func before_all() -> void:
	_scratch_root = OS.get_user_data_dir().path_join("p2rec%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_scratch_root)


func after_all() -> void:
	if not _scratch_root.is_empty():
		_remove_tree(_scratch_root)


# =================================================================================================
# The pre-existing baseline contract.
# =================================================================================================

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


# =================================================================================================
# The cross-field pass dispatches on `kind`.
# =================================================================================================

func test_the_baseline_is_still_reached_through_its_own_kind() -> void:
	var result: Dictionary = _validate(BASELINE_PATH, SCHEMA_PATH)
	assert_eq(str(result.get("evidence", {}).get("kind", "")), "baseline",
		"the baseline must still declare the kind the dispatcher matches on")


## A document whose schema permits an unlisted kind must not slip through with no cross-field pass
## at all. This is the fail-closed half of making the pass document-aware.
func test_an_unrecognised_document_kind_fails_closed() -> void:
	var directory: String = _scratch("kind-unknown")
	var schema_path: String = directory.path_join("permissive.schema.json")
	_write_text(schema_path, "{\"type\":\"object\",\"properties\":{\"kind\":{\"type\":\"string\"}}}\n")
	var document_path: String = directory.path_join("document.json")
	_write_text(document_path, "{\"kind\":\"some_other_document\"}\n")
	var result: Dictionary = _validate(document_path, schema_path)
	assert_false(result.get("ok", true), "an unrecognised kind must not validate")
	_assert_error(result, "EVIDENCE_KIND_UNSUPPORTED: some_other_document")


func test_a_document_declaring_no_kind_at_all_fails_closed() -> void:
	var directory: String = _scratch("kind-absent")
	var schema_path: String = directory.path_join("empty.schema.json")
	_write_text(schema_path, "{\"type\":\"object\"}\n")
	var document_path: String = directory.path_join("document.json")
	_write_text(document_path, "{}\n")
	var result: Dictionary = _validate(document_path, schema_path)
	assert_false(result.get("ok", true), "a document with no kind must not validate")
	_assert_error(result, "EVIDENCE_KIND_UNSUPPORTED: ")


# =================================================================================================
# The closeout gate: positive control.
# =================================================================================================

func test_a_valid_closeout_gate_passes_the_schema_and_every_cross_field_law() -> void:
	var result: Dictionary = _validate_gate("gate-valid", _gate())
	assert_true(result.get("ok", false),
		"the reference gate must validate: %s" % JSON.stringify(result.get("errors", [])))


func test_the_closeout_gate_reaches_its_own_pass_and_never_the_baseline_one() -> void:
	var gate: Dictionary = _gate()
	(gate["worktree"] as Dictionary)["commit"] = TREE_ID
	var result: Dictionary = _validate_gate("gate-dispatch", gate)
	assert_false(result.get("ok", true), "the closeout law must fire")
	_assert_error(result, "CLOSEOUT_SUBJECT_COMMIT_MISMATCH: " + TREE_ID)
	for error: Variant in result.get("errors", []):
		assert_false(str(error).begins_with("SOURCE_"),
			"no baseline law may run against a closeout gate: %s" % str(error))


# =================================================================================================
# The closeout gate: one law per test, each asserting its exact error.
# =================================================================================================

func test_a_gate_whose_worktree_commit_is_not_the_subject_is_rejected() -> void:
	var gate: Dictionary = _gate()
	(gate["worktree"] as Dictionary)["commit"] = TREE_ID
	_reject(gate, "worktree-commit", "CLOSEOUT_SUBJECT_COMMIT_MISMATCH: " + TREE_ID)


func test_a_gate_claiming_a_clean_worktree_with_a_dirty_status_hash_is_rejected() -> void:
	var gate: Dictionary = _gate()
	(gate["worktree"] as Dictionary)["status_porcelain_sha256"] = _flip_hex(EMPTY_SHA256)
	_reject(gate, "worktree-dirty", "CLOSEOUT_WORKTREE_NOT_CLEAN")


func test_a_gate_repeating_a_command_id_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var records: Array = gate["command_records"]
	var clone: Dictionary = (records[0] as Dictionary).duplicate(true)
	clone["log_name"] = "duplicate.log"
	clone["sha256"] = _record_digest(clone)
	records.append(clone)
	_reject(gate, "command-duplicate", "CLOSEOUT_COMMAND_ID_DUPLICATE: docs-validate")


func test_a_command_record_whose_own_digest_is_stale_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var record: Dictionary = (gate["command_records"] as Array)[0]
	record["sha256"] = _flip_hex(str(record["sha256"]))
	_reject(gate, "command-digest", "CLOSEOUT_COMMAND_RECORD_SHA256: docs-validate")


## The exact law commit 727051ca broke: two requested suites never executed and the gate still
## reported 51/51 and exit 0. A record may never claim a suite its own run did not execute.
func test_a_command_record_claiming_an_unexecuted_suite_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var record: Dictionary = (gate["command_records"] as Array)[0]
	var suites: Array = (record["suites"] as Array).duplicate()
	suites.append("res://tests/unit/tooling/test_never_ran.gd")
	record["suites"] = suites
	record["sha256"] = _record_digest(record)
	_reject(gate, "suite-not-executed", "CLOSEOUT_SUITE_NOT_EXECUTED: docs-validate")


func test_a_command_record_whose_test_counts_do_not_add_up_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var record: Dictionary = (gate["command_records"] as Array)[0]
	record["tests"] = int(record["tests"]) + 1
	record["sha256"] = _record_digest(record)
	_reject(gate, "command-counts", "CLOSEOUT_COMMAND_COUNTS: docs-validate")


func test_a_gate_whose_summed_counts_disagree_with_its_records_is_rejected() -> void:
	for key: String in ["scripts", "tests", "passing", "pending", "asserts"]:
		var gate: Dictionary = _gate()
		var counts: Dictionary = gate["counts"]
		counts[key] = int(counts[key]) + 1
		_reject(gate, "counts-" + key, "CLOSEOUT_COUNTS_MISMATCH: " + key)


func test_a_gate_reporting_a_pending_test_without_a_diagnostic_is_rejected() -> void:
	var gate: Dictionary = _gate()
	_declare_one_pending(gate)
	_reject(gate, "pending-undeclared", "CLOSEOUT_PENDING_UNDECLARED")


func test_a_classified_pending_test_is_accepted() -> void:
	var gate: Dictionary = _gate()
	var record: Dictionary = _declare_one_pending(gate)
	(gate["diagnostics"] as Array).append({"command_id": "docs-validate",
		"classification": "pending_test", "detail": "one pre-existing pending test",
		"log_sha256": str(record["log_sha256"])})
	var result: Dictionary = _validate_gate("pending-declared", gate)
	assert_true(result.get("ok", false),
		"an explicitly classified pending test must be accepted: %s"
			% JSON.stringify(result.get("errors", [])))


func test_a_gate_whose_primary_logs_are_out_of_order_is_rejected() -> void:
	var gate: Dictionary = _gate()
	(gate["primary_logs"] as Array).reverse()
	_reject(gate, "logs-unsorted", "CLOSEOUT_PRIMARY_LOG_UNSORTED: "
		+ "%s/docs-validate.log" % EVIDENCE_LOG_ROOT_RELATIVE)


func test_a_primary_log_no_command_produced_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var stray: String = "%s/stray.log" % EVIDENCE_LOG_ROOT_RELATIVE
	(gate["primary_logs"] as Array).append({"path": stray, "sha256": EMPTY_SHA256})
	var generated: Array = gate["generated_paths"]
	generated.append(stray)
	generated.sort()
	_reject(gate, "log-unbound", "CLOSEOUT_PRIMARY_LOG_UNBOUND: " + stray)


func test_a_command_log_absent_from_the_primary_list_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var logs: Array = gate["primary_logs"]
	var dropped: String = str((logs[0] as Dictionary)["path"])
	logs.remove_at(0)
	_reject(gate, "log-unlisted", "CLOSEOUT_COMMAND_LOG_UNLISTED: " + dropped)


func test_a_primary_log_hash_that_differs_from_its_command_record_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var entry: Dictionary = (gate["primary_logs"] as Array)[0]
	entry["sha256"] = _flip_hex(str(entry["sha256"]))
	_reject(gate, "log-hash", "CLOSEOUT_LOG_SHA256_MISMATCH: " + str(entry["path"]))


## Exactly one adjacent pair is swapped, so exactly one path is out of order and the test can
## name it. Reversing the whole list would report every pair and prove nothing in particular.
func test_a_gate_whose_generated_paths_are_out_of_order_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var paths: Array = gate["generated_paths"]
	var first: String = str(paths[0])
	paths[0] = paths[1]
	paths[1] = first
	_reject(gate, "generated-unsorted", "CLOSEOUT_GENERATED_PATHS_UNSORTED: " + first)


func test_a_generated_path_inventory_missing_a_fixed_output_is_rejected() -> void:
	for fixed: String in ["contract_inventory.json", "gate.json",
			"logs/phase2r-closeout-validate.log", "logs/validation-command.jsonl",
			"preclose_beads_snapshot.json", "validation_receipt.json"]:
		var gate: Dictionary = _gate()
		var path: String = "%s/%s" % [EVIDENCE_ROOT_RELATIVE, fixed]
		(gate["generated_paths"] as Array).erase(path)
		_reject(gate, "generated-" + fixed.replace("/", "-"),
			"CLOSEOUT_GENERATED_PATH_MISSING: " + path)


func test_a_generated_path_inventory_missing_a_primary_log_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var path: String = str(((gate["primary_logs"] as Array)[0] as Dictionary)["path"])
	(gate["generated_paths"] as Array).erase(path)
	_reject(gate, "generated-log", "CLOSEOUT_GENERATED_PATH_MISSING: " + path)


## The canonical writer sorts every object's keys, which would destroy the exact reordering
## under test, so this fixture alone is written verbatim in insertion order. The law is not
## academic: the inventory parses the gate with a strict reader that preserves file order, so a
## hand-edited or foreign-written gate really can arrive with unsorted requirement keys.
func test_a_requirement_map_that_is_not_in_sorted_key_order_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var mapping: Dictionary = gate["requirement_evidence"]
	var reordered: Dictionary = {}
	var keys: Array = mapping.keys()
	keys.reverse()
	for key: Variant in keys:
		reordered[key] = mapping[key]
	gate["requirement_evidence"] = reordered
	var path: String = _scratch("requirement-order").path_join("gate.json")
	var verbatim: String = JSON.stringify(gate, "", false)
	assert_ne(verbatim, _canonical(gate),
		"the verbatim fixture must genuinely preserve the reordering")
	_write_text(path, verbatim + "\n")
	var result: Dictionary = _validate(path, CLOSEOUT_SCHEMA_PATH)
	assert_false(result.get("ok", true), "unsorted requirement keys must be rejected")
	_assert_error(result, "CLOSEOUT_REQUIREMENT_KEY_ORDER")


func test_a_requirement_mapping_to_no_record_is_rejected() -> void:
	var gate: Dictionary = _gate()
	(gate["requirement_evidence"] as Dictionary)[REQUIREMENT_IDS[0]] = []
	_reject(gate, "requirement-empty", "CLOSEOUT_REQUIREMENT_RECORDS_EMPTY: " + REQUIREMENT_IDS[0])


func test_a_requirement_record_that_is_not_the_exact_four_keys_is_rejected() -> void:
	var dropped: Dictionary = _gate()
	(_first_record(dropped) as Dictionary).erase("log_sha256")
	_reject(dropped, "requirement-short", "CLOSEOUT_REQUIREMENT_RECORD_KEYS: " + REQUIREMENT_IDS[0])

	var extended: Dictionary = _gate()
	_first_record(extended)["unexpected"] = 1
	_reject(extended, "requirement-extra", "CLOSEOUT_REQUIREMENT_RECORD_KEYS: " + REQUIREMENT_IDS[0])


func test_a_requirement_repeating_one_command_and_log_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var records: Array = (gate["requirement_evidence"] as Dictionary)[REQUIREMENT_IDS[0]]
	records.append((records[0] as Dictionary).duplicate(true))
	_reject(gate, "requirement-duplicate",
		"CLOSEOUT_REQUIREMENT_RECORD_DUPLICATE: " + REQUIREMENT_IDS[0])


func test_requirement_records_out_of_command_and_log_order_are_rejected() -> void:
	var gate: Dictionary = _gate()
	var command_records: Array = gate["command_records"]
	(gate["requirement_evidence"] as Dictionary)[REQUIREMENT_IDS[0]] = [
		_evidence_record(command_records, "schedule-gate"),
		_evidence_record(command_records, "docs-validate"),
	]
	_reject(gate, "requirement-record-order",
		"CLOSEOUT_REQUIREMENT_RECORD_ORDER: " + REQUIREMENT_IDS[0])


func test_a_requirement_record_bound_to_no_command_record_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var record: Dictionary = _first_record(gate)
	record["command_record_sha256"] = _flip_hex(str(record["command_record_sha256"]))
	_reject(gate, "requirement-unbound",
		"CLOSEOUT_REQUIREMENT_COMMAND_UNBOUND: " + REQUIREMENT_IDS[0])


func test_a_requirement_record_whose_log_hash_breaks_the_triple_hash_is_rejected() -> void:
	var gate: Dictionary = _gate()
	var record: Dictionary = _first_record(gate)
	record["log_sha256"] = _flip_hex(str(record["log_sha256"]))
	_reject(gate, "requirement-log-hash", "CLOSEOUT_REQUIREMENT_LOG_HASH: " + REQUIREMENT_IDS[0])


## Each of the three path carriers is checked separately, because the schema pattern that
## guards them cannot exclude a "." or ".." component and one carrier being clean says
## nothing about the others.
func test_a_traversal_component_in_any_gate_path_is_rejected() -> void:
	var stray: String = "%s/.." % EVIDENCE_LOG_ROOT_RELATIVE

	var in_command: Dictionary = _gate()
	var record: Dictionary = (in_command["command_records"] as Array)[0]
	record["log_path"] = stray
	record["sha256"] = _record_digest(record)
	_reject(in_command, "traversal-command", "CLOSEOUT_PATH_TRAVERSAL: " + stray)

	var in_primary: Dictionary = _gate()
	(in_primary["primary_logs"] as Array)[0]["path"] = stray
	_reject(in_primary, "traversal-primary", "CLOSEOUT_PATH_TRAVERSAL: " + stray)

	var in_generated: Dictionary = _gate()
	var paths: Array = in_generated["generated_paths"]
	paths.append(stray)
	paths.sort()
	_reject(in_generated, "traversal-generated", "CLOSEOUT_PATH_TRAVERSAL: " + stray)


## The schema alone genuinely cannot catch this, which is why the law lives in the cross-field
## pass. If this ever starts failing, the pattern has been tightened and the law can move.
func test_the_schema_pattern_alone_admits_a_traversal_component() -> void:
	var schema: Dictionary = _read_schema()
	var pattern: String = str(((schema["properties"] as Dictionary)["primary_logs"]["items"]["properties"]["path"] as Dictionary)["pattern"])
	var expression: RegEx = RegEx.create_from_string(pattern)
	assert_not_null(expression.search("%s/.." % EVIDENCE_LOG_ROOT_RELATIVE),
		"the pattern must be shown to admit what the cross-field law rejects")


func test_a_non_contract_class_whose_count_disagrees_with_its_ids_is_rejected() -> void:
	for class_key: String in ["historical_helpers", "execution_remediation_children"]:
		var gate: Dictionary = _gate()
		var record: Dictionary = (gate["non_contract_children"] as Dictionary)[class_key]
		record["count"] = int(record["count"]) + 1
		_reject(gate, "class-" + class_key, "CLOSEOUT_NON_CONTRACT_COUNT: " + class_key)


# =================================================================================================
# Fixtures.
# =================================================================================================

func _validate(document_path: String, schema_path: String) -> Dictionary:
	var validator_script: Script = load(VALIDATOR_PATH)
	assert_not_null(validator_script, "EvidenceValidator must exist")
	if validator_script == null:
		return {"ok": false, "errors": [], "evidence": {}}
	return validator_script.validate_file(document_path, schema_path)


func _validate_gate(name: String, gate: Dictionary) -> Dictionary:
	var path: String = _scratch(name).path_join("gate.json")
	_write_text(path, _canonical(gate) + "\n")
	return _validate(path, CLOSEOUT_SCHEMA_PATH)


func _reject(gate: Dictionary, name: String, expected_error: String) -> void:
	var result: Dictionary = _validate_gate(name, gate)
	assert_false(result.get("ok", true), "%s must be rejected" % name)
	_assert_error(result, expected_error)


func _assert_error(result: Dictionary, expected_error: String) -> void:
	var errors: Array = result.get("errors", [])
	var found: bool = false
	for error: Variant in errors:
		found = found or str(error) == expected_error
	assert_true(found, "the exact error %s must be reported, got %s"
		% [expected_error, JSON.stringify(errors)])


## Moves one passing test into pending in both the record and the summed counts, so the only thing
## still missing is the diagnostic that classifies it.
func _declare_one_pending(gate: Dictionary) -> Dictionary:
	var record: Dictionary = (gate["command_records"] as Array)[0]
	record["pending"] = 1
	record["passing"] = int(record["passing"]) - 1
	record["sha256"] = _record_digest(record)
	var counts: Dictionary = gate["counts"]
	counts["pending"] = 1
	counts["passing"] = int(counts["passing"]) - 1
	return record


## The one gate every mutation starts from: valid in every respect.
func _gate() -> Dictionary:
	var command_records: Array = []
	var primary_logs: Array = []
	for command_id: String in COMMAND_IDS:
		var record: Dictionary = _command_record(command_id)
		command_records.append(record)
		primary_logs.append({"path": str(record["log_path"]), "sha256": str(record["log_sha256"])})
	var mapping: Dictionary = {}
	for requirement_id: String in REQUIREMENT_IDS:
		mapping[requirement_id] = [_evidence_record(command_records, "gut-complete")]
	return {
		"schema_version": 1,
		"evidence_id": "phase_2r.closeout_gate",
		"kind": "phase2r_closeout_gate",
		"captured_at_utc": "2026-08-25T00:00:00Z",
		"subject_commit": SUBJECT_COMMIT,
		"worktree": {"commit": SUBJECT_COMMIT, "tree": TREE_ID,
			"status_porcelain_sha256": EMPTY_SHA256, "clean": true},
		"versions": {"godot": "4.6.3", "gut": "9.6.1", "dialogic": "2.0-Alpha-19",
			"beads": "bd version 1.1.0", "config": "5"},
		"digests": {
			"authority": {"path": "docs/design/a.md", "sha256": EMPTY_SHA256},
			"plan": {"path": "docs/superpowers/plans/b.md", "sha256": EMPTY_SHA256},
			"requirement_index": {"path": "prompt_docs/INDEX.md", "sha256": EMPTY_SHA256},
			"design_authority_registry": {"path": "prompt_docs/metadata/c.json",
				"sha256": EMPTY_SHA256},
		},
		"counts": {"scripts": 3, "tests": 30, "passing": 30, "failing": 0, "pending": 0,
			"asserts": 300, "load_failures": 0},
		"contract_inventory_sha256": EMPTY_SHA256,
		"preclose_beads_snapshot_sha256": EMPTY_SHA256,
		"non_contract_children": {
			"historical_helpers": {"count": 2, "ids": ["dwm-p2r.11", "dwm-p2r.7.1"]},
			"execution_remediation_children": {"count": 1, "ids": ["dwm-p2r.17"]},
		},
		"generated_paths": _generated_paths(),
		"requirement_evidence": mapping,
		"command_records": command_records,
		"diagnostics": [],
		"beads_results": {
			"dep_cycles": {"command_id": "beads-dep-cycles", "exit_code": 0, "finding_count": 0},
			"lint": {"command_id": "beads-lint", "exit_code": 0, "finding_count": 0},
			"orphans": {"command_id": "beads-orphans", "exit_code": 0, "finding_count": 0},
		},
		"source_binding_scans": [{"document_path": "evidence/phase_2r/schedule/gate.json",
			"document_sha256": EMPTY_SHA256, "bound_path_count": 23}],
		"static_scans": [{"scan_id": "unconditional_pass", "command_id": "static-scans",
			"violation_count": 0}],
		"primary_logs": primary_logs,
	}


func _command_record(command_id: String) -> Dictionary:
	var suite: String = "res://tests/unit/tooling/test_%s.gd" % command_id.replace("-", "_")
	var record: Dictionary = {
		"command_id": command_id,
		"suite_id": command_id.replace("-", "_"),
		"argv": ["-s", "res://addons/gut/gut_cmdln.gd", "-gexit"],
		"exit_code": 0,
		"log_name": "%s.log" % command_id,
		"log_path": "%s/%s.log" % [EVIDENCE_LOG_ROOT_RELATIVE, command_id],
		"log_sha256": _sha256_text("%s: PASS\n" % command_id),
		"scripts": 1,
		"suites": [suite],
		"executed_suites": [suite],
		"tests": 10,
		"passing": 10,
		"failing": 0,
		"pending": 0,
		"asserts": 100,
		"load_failures": 0,
	}
	record["sha256"] = _record_digest(record)
	return record


## The record's own digest covers its canonical bytes with sha256 removed, which is the shape the
## runner writes and the cross-field pass re-derives.
func _record_digest(record: Dictionary) -> String:
	var bare: Dictionary = record.duplicate(true)
	bare.erase("sha256")
	return _sha256_text(_canonical(bare))


func _evidence_record(command_records: Array, command_id: String) -> Dictionary:
	for record: Variant in command_records:
		if str((record as Dictionary)["command_id"]) == command_id:
			return {
				"command_id": command_id,
				"command_record_sha256": str((record as Dictionary)["sha256"]),
				"log_path": str((record as Dictionary)["log_path"]),
				"log_sha256": str((record as Dictionary)["log_sha256"]),
			}
	assert_true(false, "the fixture must carry a command record for " + command_id)
	return {}


func _first_record(gate: Dictionary) -> Dictionary:
	return ((gate["requirement_evidence"] as Dictionary)[REQUIREMENT_IDS[0]] as Array)[0]


func _generated_paths() -> Array:
	var paths: Array = [
		"%s/contract_inventory.json" % EVIDENCE_ROOT_RELATIVE,
		"%s/gate.json" % EVIDENCE_ROOT_RELATIVE,
		"%s/logs/phase2r-closeout-validate.log" % EVIDENCE_ROOT_RELATIVE,
		"%s/logs/validation-command.jsonl" % EVIDENCE_ROOT_RELATIVE,
		"%s/preclose_beads_snapshot.json" % EVIDENCE_ROOT_RELATIVE,
		"%s/validation_receipt.json" % EVIDENCE_ROOT_RELATIVE,
	]
	for command_id: String in COMMAND_IDS:
		paths.append("%s/%s.log" % [EVIDENCE_LOG_ROOT_RELATIVE, command_id])
	paths.sort()
	return paths


func _read_schema() -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(CLOSEOUT_SCHEMA_PATH))
	assert_false(parsed.is_empty(), "the closeout schema must parse")
	return parsed


func _scratch(name: String) -> String:
	var directory: String = _scratch_root.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	return directory


func _canonical(value: Variant) -> String:
	var written: Dictionary = CANONICAL_JSON.stringify(value)
	assert_true(written.get("ok", false),
		"the fixture value must be canonicalisable: %s" % str(written))
	return str(written.get("value", ""))


func _sha256_text(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _flip_hex(value: String) -> String:
	var first: String = "1" if value.begins_with("0") else "0"
	return first + value.substr(1)


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_true(handle != null, "the fixture file must open for writing: " + path)
	if handle != null:
		handle.store_string(text)
		handle.close()


func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child: String = path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
