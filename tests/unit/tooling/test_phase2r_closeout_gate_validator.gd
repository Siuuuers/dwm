extends "res://addons/gut/test.gd"

# =================================================================================================
# dwm-p2r.10 Task 3 Step 1 — the closeout gate CLI validator.
#
# SCOPE, and why it is drawn here. Three layers already exist and are NOT re-tested:
#   * Phase2RCloseoutInventory owns every Beads-topology and committed-evidence law and is proven
#     by tests/unit/tooling/test_phase2r_closeout_inventory.gd (124 tests). This suite proves only
#     that the CLI reaches the matching pure seam and surfaces its verdict faithfully.
#   * The gate document's own shape is owned by schemas/evidence/phase2r-closeout-gate.schema.json
#     and its cross-field laws by EvidenceValidator, proven by test_evidence_contract.gd.
#   * This suite owns what is left, and only that: the six closed flag sets, the --gate/--receipt
#     PATH ASSERTIONS, the validation-command.jsonl and validation_receipt.json laws, and seam
#     dispatch.
#
# The --gate and --receipt flags carry no information the seam consumes: validate() resolves
# gate.json, validation_receipt.json and preclose_beads_snapshot.json internally from
# evidence_root. They are therefore assertions, and if the CLI does not itself reject a --gate that
# fails to resolve to <evidence-root>/gate.json the flag is decorative and a mismatched path passes
# silently. That is the defect these tests exist to prevent.
#
# The validator is reached through load() rather than preload() so this file compiles and reports
# an honest RED while tools/evidence/validate_phase2r_closeout_gate.gd is still absent.
# =================================================================================================

const VALIDATOR_PATH := "res://tools/evidence/validate_phase2r_closeout_gate.gd"
const SCHEMA_PATH := "res://schemas/evidence/phase2r-closeout-gate.schema.json"

const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const EVIDENCE_ROOT_RELATIVE := "evidence/phase_2r/closeout"
const EVIDENCE_LOG_ROOT_RELATIVE := "evidence/phase_2r/closeout/logs"

const VALIDATION_COMMAND_ID := "phase2r-closeout-validate"
const VALIDATION_GATE_PATH := "evidence/phase_2r/closeout/gate.json"
const VALIDATION_LOG_PATH := "evidence/phase_2r/closeout/logs/phase2r-closeout-validate.log"

## The exact nine keys of logs/validation-command.jsonl, in the plan's declared order.
const VALIDATION_COMMAND_KEYS: Array[String] = [
	"schema_version", "command_id", "argv", "subject_commit", "gate_path", "gate_sha256",
	"log_path", "log_sha256", "exit_code",
]

## The exact seven keys of validation_receipt.json.
const RECEIPT_KEYS: Array[String] = [
	"schema_version", "subject_commit", "gate_sha256", "validation_command_record_sha256",
	"validation_log_sha256", "validator_exit_code", "sealed_at_utc",
]

const MODE_PRESEAL := "preseal"
const MODE_SEALED := "sealed-pre-attach"
const MODE_ATTACHED := "attached-preclose"
const MODE_POSTCLOSE := "postclose"
const MODE_EXPORT := "export-equivalence"
const MODE_TRANSITION := "final-epic-transition"

const RECEIPT_BEARING_MODES: Array[String] = [MODE_SEALED, MODE_ATTACHED, MODE_POSTCLOSE]
const INVENTORY_MODES: Array[String] = [MODE_PRESEAL, MODE_SEALED, MODE_ATTACHED, MODE_POSTCLOSE]

const SUBJECT_COMMIT := "1111111111111111111111111111111111111111"
const TREE_ID := "2222222222222222222222222222222222222222"
const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

const COMMAND_IDS: Array[String] = ["docs-validate", "gut-complete", "schedule-gate"]
const REQUIREMENT_IDS: Array[String] = ["req.config.version", "req.test.isolation", "req.test.layers"]

var _scratch_root := ""
var _fixture_directories: Array[String] = []


func before_all() -> void:
	_scratch_root = OS.get_user_data_dir().path_join("p2rgv%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_scratch_root)


func after_each() -> void:
	for directory: String in _fixture_directories:
		_remove_tree(directory)
	_fixture_directories.clear()


func after_all() -> void:
	if not _scratch_root.is_empty():
		_remove_tree(_scratch_root)


# =================================================================================================
# The validator exists at all.
# =================================================================================================

func test_the_closeout_gate_validator_script_exists() -> void:
	assert_not_null(load(VALIDATOR_PATH),
		"tools/evidence/validate_phase2r_closeout_gate.gd must exist")


func test_the_closeout_gate_schema_exists_and_is_the_one_the_validator_binds() -> void:
	assert_true(FileAccess.file_exists(SCHEMA_PATH), "the closeout gate schema must exist")
	var script: Script = _validator()
	if script == null:
		return
	assert_eq(script.SCHEMA_PATH, SCHEMA_PATH,
		"the validator must bind the committed closeout gate schema, not another document")


# =================================================================================================
# The six closed flag sets.
#
# Each mode declares one exact flag set. A missing flag, an extra flag, a repeated flag and a flag
# borrowed from another mode are each rejected with their own code, so a regression that merely
# widens the parser cannot hide behind a shared "usage" failure.
# =================================================================================================

func test_the_six_closed_modes_are_exactly_the_declared_set() -> void:
	var script: Script = _validator()
	if script == null:
		return
	var declared: Array = script.MODE_FLAGS.keys()
	declared.sort()
	var expected: Array = [MODE_ATTACHED, MODE_EXPORT, MODE_TRANSITION, MODE_POSTCLOSE,
		MODE_PRESEAL, MODE_SEALED]
	expected.sort()
	assert_eq(declared, expected, "the CLI must expose exactly six closed modes")


func test_prerequisite_is_never_reachable_from_the_command_line() -> void:
	_reject_plan(PackedStringArray(["--mode=prerequisite"]), &"cli_mode_unknown")
	_reject_plan(PackedStringArray(["--mode=PREREQUISITE"]), &"cli_mode_unknown")


func test_a_missing_mode_flag_is_rejected() -> void:
	_reject_plan(PackedStringArray([]), &"cli_mode_missing")
	_reject_plan(PackedStringArray(["--evidence-root=res://x"]), &"cli_mode_missing")


func test_a_repeated_mode_flag_is_rejected() -> void:
	_reject_plan(PackedStringArray(["--mode=preseal", "--mode=postclose"]), &"cli_mode_duplicate")


func test_an_unknown_mode_value_is_rejected() -> void:
	_reject_plan(PackedStringArray(["--mode=pre-seal"]), &"cli_mode_unknown")
	_reject_plan(PackedStringArray(["--mode=PRESEAL"]), &"cli_mode_unknown")
	_reject_plan(PackedStringArray(["--mode="]), &"cli_mode_unknown")


func test_every_closed_mode_accepts_its_own_exact_argument_vector() -> void:
	for mode: String in [MODE_PRESEAL, MODE_SEALED, MODE_ATTACHED, MODE_POSTCLOSE, MODE_EXPORT,
			MODE_TRANSITION]:
		var planned: Dictionary = _plan(_argv(mode, {}))
		assert_true(planned.get("ok", false),
			"the exact %s vector must be accepted: %s" % [mode, str(planned)])


func test_every_closed_mode_rejects_each_of_its_own_flags_when_absent() -> void:
	var script: Script = _validator()
	if script == null:
		return
	for mode: Variant in script.MODE_FLAGS.keys():
		for flag: Variant in script.MODE_FLAGS[mode]:
			var argv: PackedStringArray = _drop_flag(_argv(str(mode), {}), str(flag))
			_reject_plan(argv, &"cli_flag_missing")


func test_every_closed_mode_rejects_a_repeated_flag() -> void:
	var script: Script = _validator()
	if script == null:
		return
	for mode: Variant in script.MODE_FLAGS.keys():
		for flag: Variant in script.MODE_FLAGS[mode]:
			var argv: PackedStringArray = _argv(str(mode), {})
			argv.append("--%s=%s" % [str(flag), _flag_value(str(mode), str(flag))])
			_reject_plan(argv, &"cli_flag_duplicate")


func test_every_closed_mode_rejects_an_undeclared_flag() -> void:
	var script: Script = _validator()
	if script == null:
		return
	for mode: Variant in script.MODE_FLAGS.keys():
		var argv: PackedStringArray = _argv(str(mode), {})
		argv.append("--unexpected=res://x")
		_reject_plan(argv, &"cli_flag_unknown")


func test_a_bare_positional_argument_is_rejected() -> void:
	var argv: PackedStringArray = _argv(MODE_PRESEAL, {})
	argv.append("res://evidence/phase_2r/closeout")
	_reject_plan(argv, &"cli_flag_unknown")


## Cross-mode leakage is the specific failure a shared parser produces: the auxiliary modes must
## refuse the inventory flags and the inventory modes must refuse the auxiliary ones.
func test_the_auxiliary_modes_reject_every_inventory_flag() -> void:
	for mode: String in [MODE_EXPORT, MODE_TRANSITION]:
		for flag: String in ["metadata", "requirements", "evidence-root", "gate", "receipt"]:
			var argv: PackedStringArray = _argv(mode, {})
			argv.append("--%s=res://x" % flag)
			_reject_plan(argv, &"cli_flag_unknown")


func test_the_inventory_modes_reject_every_auxiliary_flag() -> void:
	for mode: String in INVENTORY_MODES:
		for flag: String in ["export", "postclose-export", "final-export", "attachment"]:
			var argv: PackedStringArray = _argv(mode, {})
			argv.append("--%s=res://x" % flag)
			_reject_plan(argv, &"cli_flag_unknown")


func test_preseal_rejects_the_receipt_flag_and_the_sealed_modes_require_it() -> void:
	var with_receipt: PackedStringArray = _argv(MODE_PRESEAL, {})
	with_receipt.append("--receipt=res://evidence/phase_2r/closeout/validation_receipt.json")
	_reject_plan(with_receipt, &"cli_flag_unknown")
	for mode: String in RECEIPT_BEARING_MODES:
		_reject_plan(_drop_flag(_argv(mode, {}), "receipt"), &"cli_flag_missing")


func test_the_final_epic_transition_mode_takes_no_beads_flag() -> void:
	var argv: PackedStringArray = _argv(MODE_TRANSITION, {})
	argv.append("--beads=res://evidence/phase_2r/closeout/preclose_beads_snapshot.json")
	_reject_plan(argv, &"cli_flag_unknown")


# =================================================================================================
# --gate and --receipt are path assertions.
# =================================================================================================

func test_a_gate_flag_that_does_not_resolve_below_the_evidence_root_is_rejected() -> void:
	for mode: String in INVENTORY_MODES:
		_reject_plan(_argv(mode, {"gate": "res://evidence/phase_2r/schedule/gate.json"}),
			&"cli_gate_path_mismatch")


func test_a_gate_flag_naming_another_file_in_the_right_directory_is_rejected() -> void:
	_reject_plan(_argv(MODE_PRESEAL, {"gate": "res://evidence/phase_2r/closeout/contract_inventory.json"}),
		&"cli_gate_path_mismatch")


func test_a_gate_flag_that_only_traverses_back_to_the_right_file_is_rejected() -> void:
	_reject_plan(_argv(MODE_PRESEAL,
		{"gate": "res://evidence/phase_2r/closeout/logs/../gate.json"}), &"cli_gate_path_mismatch")


func test_a_receipt_flag_that_does_not_resolve_below_the_evidence_root_is_rejected() -> void:
	for mode: String in RECEIPT_BEARING_MODES:
		_reject_plan(_argv(mode, {"receipt": "res://evidence/phase_2r/validation_receipt.json"}),
			&"cli_receipt_path_mismatch")


func test_a_receipt_flag_naming_the_gate_is_rejected() -> void:
	_reject_plan(_argv(MODE_SEALED, {"receipt": "res://evidence/phase_2r/closeout/gate.json"}),
		&"cli_receipt_path_mismatch")


## A trailing separator on the evidence root must not defeat the assertion by string compare.
func test_a_trailing_separator_on_the_evidence_root_still_matches_the_gate() -> void:
	var planned: Dictionary = _plan(_argv(MODE_PRESEAL,
		{"evidence-root": "res://evidence/phase_2r/closeout/"}))
	assert_true(planned.get("ok", false),
		"a trailing separator must normalise rather than fail: %s" % str(planned))


# =================================================================================================
# Seam dispatch.
# =================================================================================================

func test_each_inventory_mode_dispatches_to_validate_with_its_own_inventory_mode() -> void:
	var expected: Dictionary = {
		MODE_PRESEAL: "PRE_SEAL",
		MODE_SEALED: "SEALED_PRE_ATTACH",
		MODE_ATTACHED: "ATTACHED_PRE_CLOSE",
		MODE_POSTCLOSE: "POST_CLOSE",
	}
	for mode: String in INVENTORY_MODES:
		var planned: Dictionary = _accept_plan(_argv(mode, {}))
		if planned.is_empty():
			continue
		assert_eq(str(planned["seam"]), "validate",
			"%s must dispatch to the inventory master seam" % mode)
		assert_eq(str(planned["inventory_mode"]), str(expected[mode]),
			"%s must carry its own inventory mode" % mode)


func test_the_two_auxiliary_modes_dispatch_to_their_own_pure_seams() -> void:
	var export_plan: Dictionary = _accept_plan(_argv(MODE_EXPORT, {}))
	if not export_plan.is_empty():
		assert_eq(str(export_plan["seam"]), "validate_export_equivalence")
		assert_false(export_plan.has("inventory_mode"),
			"an auxiliary mode must not carry an inventory mode")
	var transition_plan: Dictionary = _accept_plan(_argv(MODE_TRANSITION, {}))
	if not transition_plan.is_empty():
		assert_eq(str(transition_plan["seam"]), "validate_final_epic_transition")
		assert_false(transition_plan.has("inventory_mode"),
			"an auxiliary mode must not carry an inventory mode")


## Dispatch is proven to be real rather than a label by feeding each auxiliary mode an input only
## that seam can reject, and observing that seam's own failure code come back through the CLI.
func test_the_export_equivalence_mode_really_reaches_its_seam() -> void:
	var root: String = _fixture("export-seam")
	_write_text(root.path_join("list.json"), "[]\n")
	_write_text(root.path_join("issues.jsonl"), "{\"_type\":\"issue\",\"id\":\"a\"}")
	var result: Dictionary = _run(PackedStringArray([
		"--mode=" + MODE_EXPORT,
		"--beads=" + root.path_join("list.json"),
		"--export=" + root.path_join("issues.jsonl"),
	]))
	assert_false(result.get("ok", true), "an export that is not LF terminated must be rejected")
	assert_eq(str(result.get("code", "")), "export_jsonl_malformed",
		"the seam's own code must reach the caller unchanged: %s" % str(result))


func test_the_final_epic_transition_mode_really_reaches_its_seam() -> void:
	var root: String = _fixture("transition-seam")
	_write_text(root.path_join("postclose.jsonl"), "{\"_type\":\"issue\",\"id\":\"a\"}\n")
	_write_text(root.path_join("final.jsonl"), "{\"_type\":\"issue\",\"id\":\"a\"}\n")
	_write_text(root.path_join("attachment.json"), "{\"schema_version\":1}")
	var result: Dictionary = _run(PackedStringArray([
		"--mode=" + MODE_TRANSITION,
		"--postclose-export=" + root.path_join("postclose.jsonl"),
		"--final-export=" + root.path_join("final.jsonl"),
		"--attachment=" + root.path_join("attachment.json"),
	]))
	assert_false(result.get("ok", true), "an attachment that is not LF terminated must be rejected")
	assert_eq(str(result.get("code", "")), "epic_attachment_mismatch",
		"the seam's own code must reach the caller unchanged: %s" % str(result))


# =================================================================================================
# The gate is schema validated by the CLI itself.
# =================================================================================================

func test_a_gate_that_fails_the_schema_is_rejected_before_any_seam_runs() -> void:
	var fixture: Dictionary = _evidence_fixture("schema-reject", MODE_PRESEAL)
	var gate: Dictionary = fixture["gate"]
	gate.erase("versions")
	_write_gate(fixture, gate)
	_reject_run(fixture, MODE_PRESEAL, &"gate_schema_invalid")


func test_a_gate_carrying_an_extra_member_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("schema-extra", MODE_PRESEAL)
	var gate: Dictionary = fixture["gate"]
	gate["unexpected"] = "value"
	_write_gate(fixture, gate)
	_reject_run(fixture, MODE_PRESEAL, &"gate_schema_invalid")


func test_a_gate_with_another_document_kind_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("schema-kind", MODE_PRESEAL)
	var gate: Dictionary = fixture["gate"]
	gate["kind"] = "baseline"
	_write_gate(fixture, gate)
	_reject_run(fixture, MODE_PRESEAL, &"gate_schema_invalid")


func test_an_absent_gate_is_rejected_with_its_own_code() -> void:
	var fixture: Dictionary = _evidence_fixture("schema-absent", MODE_PRESEAL)
	DirAccess.remove_absolute(str(fixture["gate_path"]))
	assert_false(FileAccess.file_exists(str(fixture["gate_path"])),
		"the fixture must genuinely remove the gate before asserting its absence")
	_reject_run(fixture, MODE_PRESEAL, &"cli_gate_unreadable")


func test_a_gate_that_is_not_strict_json_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("schema-nonjson", MODE_PRESEAL)
	_write_text(str(fixture["gate_path"]), "{\"schema_version\": 1,}\n")
	_reject_run(fixture, MODE_PRESEAL, &"cli_gate_unreadable")


# =================================================================================================
# The gate's four authority digests are re-verified against the named files.
# =================================================================================================

func test_a_wrong_authority_digest_is_rejected() -> void:
	for digest_key: String in ["authority", "plan", "requirement_index", "design_authority_registry"]:
		var fixture: Dictionary = _evidence_fixture("digest-" + digest_key, MODE_PRESEAL)
		var gate: Dictionary = fixture["gate"]
		var digests: Dictionary = gate["digests"]
		var record: Dictionary = digests[digest_key]
		record["sha256"] = _flip_hex(str(record["sha256"]))
		_write_gate(fixture, gate)
		_reject_run(fixture, MODE_PRESEAL, &"gate_digest_mismatch")


func test_a_digest_naming_an_absent_document_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("digest-absent", MODE_PRESEAL)
	var gate: Dictionary = fixture["gate"]
	(gate["digests"] as Dictionary)["plan"] = {
		"path": "docs/superpowers/plans/absent-document.md",
		"sha256": EMPTY_SHA256,
	}
	_write_gate(fixture, gate)
	_reject_run(fixture, MODE_PRESEAL, &"gate_digest_unreadable")


# =================================================================================================
# validation-command.jsonl and validation_receipt.json.
#
# These are read only by the receipt-bearing modes. PRE_SEAL runs before both exist, so it must
# never read them, and the inventory itself refuses a PRE_SEAL run that finds them present.
# =================================================================================================

func test_preseal_does_not_read_the_receipt_or_the_command_record() -> void:
	var fixture: Dictionary = _evidence_fixture("preseal-no-receipt", MODE_PRESEAL)
	assert_false(FileAccess.file_exists(str(fixture["receipt_path"])),
		"the PRE_SEAL fixture must not carry a receipt")
	assert_false(FileAccess.file_exists(str(fixture["command_record_path"])),
		"the PRE_SEAL fixture must not carry a command record")
	var result: Dictionary = _run_mode(fixture, MODE_PRESEAL)
	assert_ne(str(result.get("code", "")), "validation_command_record_missing",
		"PRE_SEAL must not demand a record that is correctly absent: %s" % str(result))
	assert_ne(str(result.get("code", "")), "validation_receipt_missing",
		"PRE_SEAL must not demand a receipt that is correctly absent: %s" % str(result))


func test_an_absent_command_record_is_rejected_in_every_receipt_bearing_mode() -> void:
	for mode: String in RECEIPT_BEARING_MODES:
		var fixture: Dictionary = _evidence_fixture("record-absent-" + mode, mode)
		DirAccess.remove_absolute(str(fixture["command_record_path"]))
		assert_false(FileAccess.file_exists(str(fixture["command_record_path"])),
			"the fixture must genuinely remove the command record")
		_reject_run(fixture, mode, &"validation_command_record_missing")


func test_a_command_record_carrying_a_second_line_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-multiline", MODE_SEALED)
	var text: String = FileAccess.get_file_as_string(str(fixture["command_record_path"]))
	_write_text(str(fixture["command_record_path"]), text + text)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_not_single_line")


func test_a_command_record_that_is_not_lf_terminated_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-unterminated", MODE_SEALED)
	var text: String = FileAccess.get_file_as_string(str(fixture["command_record_path"]))
	_write_text(str(fixture["command_record_path"]), text.trim_suffix("\n"))
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_not_single_line")


## Noncanonical but still exactly one LF-terminated line, so this reaches the canonicality law
## instead of being caught earlier by the single-line law. JSON.stringify preserves insertion
## order and the canonical writer sorts, so one object serialises two different ways.
func test_a_command_record_with_noncanonical_bytes_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-noncanonical", MODE_SEALED)
	var record: Dictionary = fixture["command_record"]
	var noncanonical: String = JSON.stringify(record, "", false)
	assert_false(noncanonical.contains("\n"), "the fixture must stay on one line")
	assert_ne(noncanonical, _canonical(record),
		"the fixture bytes must genuinely differ from the canonical bytes")
	_write_text(str(fixture["command_record_path"]), noncanonical + "\n")
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_noncanonical")


func test_a_command_record_missing_or_carrying_an_extra_key_is_rejected() -> void:
	for key: String in VALIDATION_COMMAND_KEYS:
		var dropped: Dictionary = _evidence_fixture("record-drop-" + key, MODE_SEALED)
		var record: Dictionary = (dropped["command_record"] as Dictionary).duplicate(true)
		record.erase(key)
		_rewrite_command_record(dropped, record)
		_reject_run(dropped, MODE_SEALED, &"validation_command_record_keys")
	var extra: Dictionary = _evidence_fixture("record-extra", MODE_SEALED)
	var extended: Dictionary = (extra["command_record"] as Dictionary).duplicate(true)
	extended["unexpected"] = 1
	_rewrite_command_record(extra, extended)
	_reject_run(extra, MODE_SEALED, &"validation_command_record_keys")


func test_a_command_record_naming_another_command_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-command-id", MODE_SEALED)
	var record: Dictionary = (fixture["command_record"] as Dictionary).duplicate(true)
	record["command_id"] = "phase2r-closeout-validate-2"
	_rewrite_command_record(fixture, record)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_command_id")


func test_a_command_record_with_a_changed_argv_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-argv", MODE_SEALED)
	var record: Dictionary = (fixture["command_record"] as Dictionary).duplicate(true)
	var argv: Array = (record["argv"] as Array).duplicate()
	argv.append("--mode=postclose")
	record["argv"] = argv
	_rewrite_command_record(fixture, record)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_argv")


func test_a_command_record_with_a_drifted_gate_or_log_path_is_rejected() -> void:
	var gate_drift: Dictionary = _evidence_fixture("record-gate-path", MODE_SEALED)
	var gate_record: Dictionary = (gate_drift["command_record"] as Dictionary).duplicate(true)
	gate_record["gate_path"] = "evidence/phase_2r/schedule/gate.json"
	_rewrite_command_record(gate_drift, gate_record)
	_reject_run(gate_drift, MODE_SEALED, &"validation_command_record_path")

	var log_drift: Dictionary = _evidence_fixture("record-log-path", MODE_SEALED)
	var log_record: Dictionary = (log_drift["command_record"] as Dictionary).duplicate(true)
	log_record["log_path"] = "evidence/phase_2r/closeout/logs/gut-complete.log"
	_rewrite_command_record(log_drift, log_record)
	_reject_run(log_drift, MODE_SEALED, &"validation_command_record_path")


func test_a_command_record_recording_a_nonzero_exit_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-exit", MODE_SEALED)
	var record: Dictionary = (fixture["command_record"] as Dictionary).duplicate(true)
	record["exit_code"] = 1
	_rewrite_command_record(fixture, record)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_exit_code")


func test_a_command_record_whose_gate_hash_is_stale_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-gate-hash", MODE_SEALED)
	var record: Dictionary = (fixture["command_record"] as Dictionary).duplicate(true)
	record["gate_sha256"] = _flip_hex(str(record["gate_sha256"]))
	_rewrite_command_record(fixture, record)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_gate_hash")


func test_a_command_record_whose_log_hash_disagrees_with_the_log_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-log-hash", MODE_SEALED)
	var record: Dictionary = (fixture["command_record"] as Dictionary).duplicate(true)
	record["log_sha256"] = _flip_hex(str(record["log_sha256"]))
	_rewrite_command_record(fixture, record)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_log_hash")


func test_a_command_record_naming_another_subject_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-subject", MODE_SEALED)
	var record: Dictionary = (fixture["command_record"] as Dictionary).duplicate(true)
	record["subject_commit"] = TREE_ID
	_rewrite_command_record(fixture, record)
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_subject")


func test_an_absent_validation_log_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("log-absent", MODE_SEALED)
	DirAccess.remove_absolute(str(fixture["validation_log_path"]))
	assert_false(FileAccess.file_exists(str(fixture["validation_log_path"])),
		"the fixture must genuinely remove the validation log")
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_log_hash")


func test_an_absent_receipt_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-absent", MODE_SEALED)
	DirAccess.remove_absolute(str(fixture["receipt_path"]))
	assert_false(FileAccess.file_exists(str(fixture["receipt_path"])),
		"the fixture must genuinely remove the receipt")
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_missing")


func test_a_receipt_missing_or_carrying_an_extra_key_is_rejected() -> void:
	for key: String in RECEIPT_KEYS:
		var dropped: Dictionary = _evidence_fixture("receipt-drop-" + key, MODE_SEALED)
		var receipt: Dictionary = (dropped["receipt"] as Dictionary).duplicate(true)
		receipt.erase(key)
		_rewrite_receipt(dropped, receipt)
		_reject_run(dropped, MODE_SEALED, &"validation_receipt_keys")
	var extra: Dictionary = _evidence_fixture("receipt-extra", MODE_SEALED)
	var extended: Dictionary = (extra["receipt"] as Dictionary).duplicate(true)
	extended["unexpected"] = 1
	_rewrite_receipt(extra, extended)
	_reject_run(extra, MODE_SEALED, &"validation_receipt_keys")


func test_a_receipt_that_is_not_lf_terminated_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-unterminated", MODE_SEALED)
	var text: String = FileAccess.get_file_as_string(str(fixture["receipt_path"]))
	_write_text(str(fixture["receipt_path"]), text.trim_suffix("\n"))
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_noncanonical")


## One LF-terminated line, so this reaches the canonicality law rather than dying at the
## single-line law above it. A pretty-printed fixture here proved nothing: it was rejected for
## being multiline and the canonicality guard was never executed at all.
func test_a_receipt_with_noncanonical_bytes_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-noncanonical", MODE_SEALED)
	var noncanonical: String = JSON.stringify(fixture["receipt"], "", false)
	assert_false(noncanonical.contains("\n"), "the fixture must stay on one line")
	assert_ne(noncanonical, _canonical(fixture["receipt"]),
		"the fixture bytes must genuinely differ from the canonical bytes")
	_write_text(str(fixture["receipt_path"]), noncanonical + "\n")
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_noncanonical")


## The receipt's command-record hash covers the WHOLE LF-terminated file, not the object bytes.
## A hash taken over the trimmed line is the exact regression this pins.
func test_a_receipt_hashing_the_trimmed_command_line_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-trimmed-hash", MODE_SEALED)
	var receipt: Dictionary = (fixture["receipt"] as Dictionary).duplicate(true)
	var text: String = FileAccess.get_file_as_string(str(fixture["command_record_path"]))
	receipt["validation_command_record_sha256"] = _sha256_text(text.trim_suffix("\n"))
	_rewrite_receipt(fixture, receipt)
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_command_hash")


func test_a_receipt_whose_gate_hash_is_stale_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-gate-hash", MODE_SEALED)
	var receipt: Dictionary = (fixture["receipt"] as Dictionary).duplicate(true)
	receipt["gate_sha256"] = _flip_hex(str(receipt["gate_sha256"]))
	_rewrite_receipt(fixture, receipt)
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_gate_hash")


func test_a_receipt_whose_log_hash_differs_from_the_command_record_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-log-hash", MODE_SEALED)
	var receipt: Dictionary = (fixture["receipt"] as Dictionary).duplicate(true)
	receipt["validation_log_sha256"] = _flip_hex(str(receipt["validation_log_sha256"]))
	_rewrite_receipt(fixture, receipt)
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_log_hash")


func test_a_receipt_naming_another_subject_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-subject", MODE_SEALED)
	var receipt: Dictionary = (fixture["receipt"] as Dictionary).duplicate(true)
	receipt["subject_commit"] = TREE_ID
	_rewrite_receipt(fixture, receipt)
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_subject")


func test_a_receipt_recording_a_nonzero_validator_exit_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-exit", MODE_SEALED)
	var receipt: Dictionary = (fixture["receipt"] as Dictionary).duplicate(true)
	receipt["validator_exit_code"] = 1
	_rewrite_receipt(fixture, receipt)
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_exit_code")


# =================================================================================================
# Positive control.
#
# Every other run test asserts a rejection, so without this one a CLI that refused everything would
# look perfect. This proves the CLI layer passes a document that satisfies all of its own laws and
# hands control to the inventory: the code that comes back is the inventory's own first verdict on
# the deliberately empty fixture snapshot, and no CLI-layer code at all.
# =================================================================================================

func test_a_valid_evidence_root_clears_every_cli_law_and_reaches_the_inventory_seam() -> void:
	for mode: String in INVENTORY_MODES:
		var fixture: Dictionary = _evidence_fixture("valid-" + mode, mode)
		var result: Dictionary = _run_mode(fixture, mode)
		var code: String = str(result.get("code", ""))
		assert_eq(code, "contract_record_missing",
			"%s must clear the CLI layer and fail only in the inventory: %s" % [mode, str(result)])


# =================================================================================================
# Guards the mutation campaign found untested.
#
# Every test below exists because disabling its guard changed nothing: the campaign ran green
# against production with the guard removed. They are not speculative extras; each one is a
# rejection the CLI performs that nothing was checking.
# =================================================================================================

func test_a_flag_with_an_empty_name_is_rejected() -> void:
	_reject_plan(PackedStringArray(["--=value"]), &"cli_flag_unknown")
	_reject_plan(PackedStringArray(["--mode=preseal", "--=value"]), &"cli_flag_unknown")


func test_a_gate_that_is_not_valid_utf8_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("gate-not-utf8", MODE_PRESEAL)
	var handle: FileAccess = FileAccess.open(str(fixture["gate_path"]), FileAccess.WRITE)
	assert_true(handle != null, "the fixture gate must open for writing")
	if handle == null:
		return
	handle.store_buffer(PackedByteArray([0x7b, 0xff, 0x7d]))
	handle.close()
	_reject_run(fixture, MODE_PRESEAL, &"cli_gate_unreadable")


func test_a_command_record_line_that_is_not_strict_json_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("record-not-json", MODE_SEALED)
	_write_text(str(fixture["command_record_path"]), "{\"schema_version\": 1,}\n")
	_reject_run(fixture, MODE_SEALED, &"validation_command_record_noncanonical")


func test_a_receipt_line_that_is_not_strict_json_is_rejected() -> void:
	var fixture: Dictionary = _evidence_fixture("receipt-not-json", MODE_SEALED)
	_write_text(str(fixture["receipt_path"]), "{\"schema_version\": 1,}\n")
	_reject_run(fixture, MODE_SEALED, &"validation_receipt_noncanonical")


# =================================================================================================
# Process exit codes.
# =================================================================================================

func test_a_usage_failure_and_a_validation_failure_carry_distinct_exit_codes() -> void:
	var script: Script = _validator()
	if script == null:
		return
	assert_eq(script.exit_code_for(_plan(PackedStringArray([]))), 2,
		"a CLI usage failure must exit 2")
	var fixture: Dictionary = _evidence_fixture("exit-codes", MODE_PRESEAL)
	var gate: Dictionary = fixture["gate"]
	gate.erase("versions")
	_write_gate(fixture, gate)
	assert_eq(script.exit_code_for(_run_mode(fixture, MODE_PRESEAL)), 1,
		"a validation failure must exit 1")


# =================================================================================================
# Fixtures.
# =================================================================================================

func _validator() -> Script:
	var script: Script = load(VALIDATOR_PATH)
	assert_not_null(script, "the closeout gate validator must exist at " + VALIDATOR_PATH)
	return script


func _plan(arguments: PackedStringArray) -> Dictionary:
	var script: Script = _validator()
	if script == null:
		return {"ok": false, "code": &"validator_absent"}
	return script.plan(arguments)


func _run(arguments: PackedStringArray) -> Dictionary:
	var script: Script = _validator()
	if script == null:
		return {"ok": false, "code": &"validator_absent"}
	return script.run(arguments)


func _accept_plan(arguments: PackedStringArray) -> Dictionary:
	var planned: Dictionary = _plan(arguments)
	assert_true(planned.get("ok", false), "the vector must plan: %s" % str(planned))
	if not planned.get("ok", false):
		return {}
	return planned["value"]


func _reject_plan(arguments: PackedStringArray, expected_code: StringName) -> void:
	var planned: Dictionary = _plan(arguments)
	assert_false(planned.get("ok", true), "the vector must be rejected: %s" % str(arguments))
	assert_eq(str(planned.get("code", "")), str(expected_code),
		"the rejection must carry its exact code for %s: %s" % [str(arguments), str(planned)])


func _reject_run(fixture: Dictionary, mode: String, expected_code: StringName) -> void:
	var result: Dictionary = _run_mode(fixture, mode)
	assert_false(result.get("ok", true), "the run must be rejected in %s" % mode)
	assert_eq(str(result.get("code", "")), str(expected_code),
		"the rejection must carry its exact code: %s" % str(result))


func _run_mode(fixture: Dictionary, mode: String) -> Dictionary:
	return _run(_fixture_argv(fixture, mode))


func _fixture_argv(fixture: Dictionary, mode: String) -> PackedStringArray:
	var root: String = str(fixture["evidence_root"])
	var argv: PackedStringArray = PackedStringArray([
		"--mode=" + mode,
		"--metadata=" + str(fixture["metadata_path"]),
		"--beads=" + root.path_join("preclose_beads_snapshot.json"),
		"--requirements=" + str(fixture["requirements_path"]),
		"--evidence-root=" + root,
		"--gate=" + root.path_join("gate.json"),
	])
	if RECEIPT_BEARING_MODES.has(mode):
		argv.append("--receipt=" + root.path_join("validation_receipt.json"))
	return argv


## A scratch directory, registered for removal in after_each.
func _fixture(name: String) -> String:
	var directory: String = _scratch_root.path_join(name)
	_remove_tree(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	_fixture_directories.append(directory)
	return directory


## A complete on-disk closeout evidence root that passes every CLI law, so each test mutates one
## thing and observes one code. PRE_SEAL fixtures deliberately omit the receipt and the command
## record, which is the state the runner produces before sealing.
func _evidence_fixture(name: String, mode: String) -> Dictionary:
	var base: String = _fixture(name)
	var root: String = base.path_join(EVIDENCE_ROOT_RELATIVE)
	DirAccess.make_dir_recursive_absolute(root.path_join("logs"))
	var fixture: Dictionary = {
		"base": base,
		"evidence_root": root,
		"gate_path": root.path_join("gate.json"),
		"receipt_path": root.path_join("validation_receipt.json"),
		"command_record_path": root.path_join("logs/validation-command.jsonl"),
		"validation_log_path": root.path_join("logs/phase2r-closeout-validate.log"),
		"metadata_path": ProjectSettings.globalize_path(
			"res://prompt_docs/metadata/phase_2r_beads.v1.json"),
		"requirements_path": ProjectSettings.globalize_path("res://prompt_docs/INDEX.md"),
		"seals": RECEIPT_BEARING_MODES.has(mode),
	}
	_write_text(root.path_join("preclose_beads_snapshot.json"), "[]\n")
	_write_text(root.path_join("contract_inventory.json"), "{\"schema_version\":1}\n")
	for command_id: String in COMMAND_IDS:
		_write_text(root.path_join("logs/%s.log" % command_id), "%s: PASS\n" % command_id)
	_write_text(str(fixture["validation_log_path"]), "phase2r-closeout-validate: PASS\n")
	_write_gate(fixture, _gate())
	return fixture


## The one gate document every schema and cross-field test starts from: valid in every respect.
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
		"worktree": {
			"commit": SUBJECT_COMMIT,
			"tree": TREE_ID,
			"status_porcelain_sha256": EMPTY_SHA256,
			"clean": true,
		},
		"versions": {"godot": "4.6.3", "gut": "9.6.1", "dialogic": "2.0-Alpha-19",
			"beads": "bd version 1.1.0", "config": "5"},
		"digests": _digests(),
		"counts": {"scripts": 3, "tests": 30, "passing": 30, "failing": 0, "pending": 0,
			"asserts": 300, "load_failures": 0},
		"contract_inventory_sha256": _sha256_text("{\"schema_version\":1}\n"),
		"preclose_beads_snapshot_sha256": _sha256_text("[]\n"),
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


## The four authority documents, hashed from their real committed bytes so the CLI's digest
## re-verification has something true to agree with.
func _digests() -> Dictionary:
	return {
		"authority": _digest_record(
			"docs/design/2026-08-11-phase-2r-foundation-repair-current-authority.md"),
		"plan": _digest_record(
			"docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-04-verification-closeout.md"),
		"requirement_index": _digest_record("prompt_docs/INDEX.md"),
		"design_authority_registry": _digest_record(
			"prompt_docs/metadata/design_authority_registry.v1.json"),
	}


func _digest_record(relative_path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://" + relative_path)
	assert_true(bytes.size() > 0, "the fixture digest source must exist: " + relative_path)
	return {"path": relative_path, "sha256": _sha256_bytes(bytes)}


func _command_record(command_id: String) -> Dictionary:
	var log_relative: String = "%s/%s.log" % [EVIDENCE_LOG_ROOT_RELATIVE, command_id]
	var suite: String = "res://tests/unit/tooling/test_%s.gd" % command_id.replace("-", "_")
	var record: Dictionary = {
		"command_id": command_id,
		"suite_id": command_id.replace("-", "_"),
		"argv": ["-s", "res://addons/gut/gut_cmdln.gd", "-gexit"],
		"exit_code": 0,
		"log_name": "%s.log" % command_id,
		"log_path": log_relative,
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
	record["sha256"] = _sha256_text(_canonical(record))
	return record


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


func _write_gate(fixture: Dictionary, gate: Dictionary) -> void:
	fixture["gate"] = gate
	var text: String = _canonical(gate) + "\n"
	_write_text(str(fixture["gate_path"]), text)
	fixture["gate_sha256"] = _sha256_text(text)
	if bool(fixture.get("seals", false)):
		_seal(fixture)


## Writes the command record and the receipt that agree with the gate as it currently stands.
func _seal(fixture: Dictionary) -> void:
	var log_text: String = FileAccess.get_file_as_string(str(fixture["validation_log_path"]))
	var record: Dictionary = {
		"schema_version": 1,
		"command_id": VALIDATION_COMMAND_ID,
		"argv": _preseal_argv(fixture),
		"subject_commit": SUBJECT_COMMIT,
		"gate_path": VALIDATION_GATE_PATH,
		"gate_sha256": str(fixture["gate_sha256"]),
		"log_path": VALIDATION_LOG_PATH,
		"log_sha256": _sha256_text(log_text),
		"exit_code": 0,
	}
	_rewrite_command_record(fixture, record)


func _preseal_argv(fixture: Dictionary) -> Array:
	var argv: Array = []
	for argument: String in _fixture_argv(fixture, MODE_PRESEAL):
		argv.append(argument)
	return argv


func _rewrite_command_record(fixture: Dictionary, record: Dictionary) -> void:
	fixture["command_record"] = record
	var text: String = _canonical(record) + "\n"
	_write_text(str(fixture["command_record_path"]), text)
	fixture["command_record_sha256"] = _sha256_text(text)
	_rewrite_receipt(fixture, {
		"schema_version": 1,
		"subject_commit": SUBJECT_COMMIT,
		"gate_sha256": str(fixture["gate_sha256"]),
		"validation_command_record_sha256": str(fixture["command_record_sha256"]),
		"validation_log_sha256": str(record.get("log_sha256", "")),
		"validator_exit_code": 0,
		"sealed_at_utc": "2026-08-25T00:00:01Z",
	})


func _rewrite_receipt(fixture: Dictionary, receipt: Dictionary) -> void:
	fixture["receipt"] = receipt
	_write_text(str(fixture["receipt_path"]), _canonical(receipt) + "\n")


## Builds a mode's exact argument vector against the real repository paths, with named overrides.
func _argv(mode: String, overrides: Dictionary) -> PackedStringArray:
	var script: Script = _validator()
	if script == null:
		return PackedStringArray(["--mode=" + mode])
	var argv: PackedStringArray = PackedStringArray(["--mode=" + mode])
	for flag: Variant in script.MODE_FLAGS[mode]:
		var name: String = str(flag)
		var value: String = str(overrides[name]) if overrides.has(name) \
			else _flag_value(mode, name)
		argv.append("--%s=%s" % [name, value])
	return argv


func _flag_value(mode: String, flag: String) -> String:
	match flag:
		"metadata": return "res://prompt_docs/metadata/phase_2r_beads.v1.json"
		"beads":
			if mode == MODE_EXPORT:
				return "res://evidence/phase_2r/closeout/transitions/postclose-beads.json"
			return "res://evidence/phase_2r/closeout/preclose_beads_snapshot.json"
		"requirements": return "res://prompt_docs/INDEX.md"
		"evidence-root": return "res://evidence/phase_2r/closeout"
		"gate": return "res://evidence/phase_2r/closeout/gate.json"
		"receipt": return "res://evidence/phase_2r/closeout/validation_receipt.json"
		"export": return "res://evidence/phase_2r/closeout/transitions/postclose-issues.jsonl"
		"postclose-export": return "res://evidence/phase_2r/closeout/transitions/postclose-issues.jsonl"
		"final-export": return "res://.godot/phase2r_logs/phase2r-final-issues.jsonl"
		"attachment": return "res://.godot/phase2r_logs/phase2r-epic-attachment.json"
	assert_true(false, "the fixture has no value for --" + flag)
	return ""


func _drop_flag(arguments: PackedStringArray, flag: String) -> PackedStringArray:
	var kept: PackedStringArray = PackedStringArray()
	for argument: String in arguments:
		if not argument.begins_with("--%s=" % flag):
			kept.append(argument)
	return kept


# =================================================================================================
# Primitives.
# =================================================================================================

func _canonical(value: Variant) -> String:
	var written: Dictionary = CANONICAL_JSON.stringify(value)
	assert_true(written.get("ok", false),
		"the fixture value must be canonicalisable: %s" % str(written))
	return str(written.get("value", ""))


func _sha256_text(text: String) -> String:
	return _sha256_bytes(text.to_utf8_buffer())


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
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
