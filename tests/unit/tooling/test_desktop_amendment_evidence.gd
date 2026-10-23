extends "res://addons/gut/test.gd"
# dwm-p2r.32 Plan 02 Task 9, req.test.desktop_amendment_gate. Phase 3 (and any later reviewer)
# trusts evidence/phase_2r/contracts/desktop_contract.json and .../minesweeper_contract.json
# INSTEAD OF re-deriving this amendment from source, so both documents must fail closed under
# tamper, and every hash must trace to `git show <subject_commit>:<path>` -- never HEAD, never the
# working tree.
#
# PARSE HAZARD: the CLI wrapper (generate_desktop_amendment_evidence.gd) extends SceneTree. It is
# probed with load_script() and NEVER instantiated -- instantiating it would construct a SceneTree
# and execute the tool.
#
# WHY SOME TESTS READ THE ALREADY-PUBLISHED DOCUMENT'S OWN subject_commit FIELD instead of
# hardcoding a SHA: mirrors tests/unit/tooling/test_schedule_v3_boundary.gd's own established
# pattern for the identical "evidence binds a commit that must already exist" situation. Before
# Step 9.5 generates the two documents, those tests are RED (FILE_MISSING); once generation runs
# against a real subject commit, they read that recorded id and become GREEN without editing this
# file. Negative tests that only need SOME real, wrongly-shaped commit use this branch's own
# existing history instead, which is always available.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const DESKTOP_EVIDENCE := preload("res://tools/evidence/DesktopAmendmentContractEvidence.gd")
const MINESWEEPER_EVIDENCE := preload("res://tools/evidence/MinesweeperAmendmentContractEvidence.gd")
const GIT_PLUMBING := preload("res://tools/evidence/DesktopAmendmentEvidenceGit.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const GENERATOR_PATH := "res://tools/evidence/generate_desktop_amendment_evidence.gd"
const CURATED_LOGS := "res://evidence/phase_2r/logs/"

## The outcome each curated log ACTUALLY records, read off its own Totals block by hand. Written
## down here so a parser that silently reverted to hardcoding zero -- the defect this suite
## exists to keep dead -- has something to contradict.
const EXPECTED_LOG_OUTCOMES := {
	"p2r9-bootstrap-regression.log": {"exit_code": 0, "tests": 190, "passing_tests": 190,
		"failing_tests": 0, "passing_asserts": 1891, "total_asserts": 1891},
	"p2r9-bootstrap-wiring-check.log": {"exit_code": 1, "tests": 18, "passing_tests": 0,
		"failing_tests": 18, "passing_asserts": 100, "total_asserts": 125},
	"p2r9-bootstrap-wiring-check3.log": {"exit_code": 0, "tests": 18, "passing_tests": 18,
		"failing_tests": 0, "passing_asserts": 272, "total_asserts": 272},
}

## A real, already-committed commit on this branch that does NOT carry the frozen amendment
## subject -- used only as a negative fixture, never asserted to succeed.
const A_REAL_WRONG_SUBJECT_COMMIT := "37923e3ec2d574976ceb686e56f51572bbbf8cec"


static func _repository_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


func _published(evidence: Script) -> Dictionary:
	if not FileAccess.file_exists(evidence.ARTIFACT_PATH):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(evidence.ARTIFACT_PATH).get_string_from_utf8())
	assert_true(parsed.get("ok", false), "the published document strict-parses")
	return parsed.get("value", {}) as Dictionary


# -------------------------------------------------------------------------------------------------
# existence / parse
# -------------------------------------------------------------------------------------------------

func test_evidence_classes_generator_and_schemas_exist() -> void:
	for path: String in [
		"res://tools/evidence/DesktopAmendmentContractEvidence.gd",
		"res://tools/evidence/MinesweeperAmendmentContractEvidence.gd",
		"res://tools/evidence/DesktopAmendmentEvidenceGit.gd",
		GENERATOR_PATH,
	]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(loaded))
	for path: String in [DESKTOP_EVIDENCE.SCHEMA_PATH, MINESWEEPER_EVIDENCE.SCHEMA_PATH]:
		assert_true(FileAccess.file_exists(path), path)
		var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
		assert_true(parsed.get("ok", false), "%s strict-parses" % path)


func test_schemas_reject_unknown_top_level_keys() -> void:
	for schema_path: String in [DESKTOP_EVIDENCE.SCHEMA_PATH, MINESWEEPER_EVIDENCE.SCHEMA_PATH]:
		var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(schema_path))
		var schema: Dictionary = parsed["value"]
		assert_eq(schema.get("additionalProperties"), false, schema_path)


# -------------------------------------------------------------------------------------------------
# build() fails closed on a malformed or wrongly-shaped subject_commit -- true right now, needs no
# generated document to exist yet
# -------------------------------------------------------------------------------------------------

func test_build_rejects_a_non_hex_subject_commit() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var built: Dictionary = evidence.build(_repository_root(), "not-a-commit")
		assert_false(built.get("ok", false))
		assert_eq(built.get("code"), &"subject_commit_invalid")


func test_build_rejects_a_real_commit_carrying_the_wrong_subject() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var built: Dictionary = evidence.build(_repository_root(), A_REAL_WRONG_SUBJECT_COMMIT)
		assert_false(built.get("ok", false))
		assert_eq(built.get("code"), &"subject_commit_subject_mismatch")


func test_build_rejects_an_unresolvable_forty_hex_commit() -> void:
	var unresolvable := "f".repeat(40)
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var built: Dictionary = evidence.build(_repository_root(), unresolvable)
		assert_false(built.get("ok", false))
		assert_eq(built.get("code"), &"subject_commit_missing")


# -------------------------------------------------------------------------------------------------
# generator CLI argument law -- true right now, independent of any generated document
# -------------------------------------------------------------------------------------------------

func test_generator_accepts_exactly_subject_commit_plus_one_mode_flag() -> void:
	var loaded: Dictionary = PROBE.load_script(GENERATOR_PATH)
	var script: Script = loaded["value"]
	for mode: String in ["write", "check"]:
		var parsed: Dictionary = script.parse_arguments(PackedStringArray(
			["--subject-commit=%s" % "a".repeat(40), "--%s" % mode]))
		assert_true(parsed.get("ok", false), mode)
		assert_eq(str((parsed["value"] as Dictionary)["mode"]), mode)


func test_generator_rejects_mixed_missing_duplicate_and_extra_flags() -> void:
	var loaded: Dictionary = PROBE.load_script(GENERATOR_PATH)
	var script: Script = loaded["value"]
	var commit := "a".repeat(40)
	var cases := {
		"mixed": PackedStringArray(["--subject-commit=%s" % commit, "--write", "--check"]),
		"missing_mode": PackedStringArray(["--subject-commit=%s" % commit]),
		"missing_commit": PackedStringArray(["--write"]),
		"duplicate_commit": PackedStringArray(["--subject-commit=%s" % commit, "--subject-commit=%s" % commit, "--write"]),
		"unknown_flag": PackedStringArray(["--subject-commit=%s" % commit, "--write", "--extra=1"]),
		"positional": PackedStringArray(["write"]),
	}
	for label: String in cases:
		var parsed: Dictionary = script.parse_arguments(cases[label] as PackedStringArray)
		assert_false(parsed.get("ok", false), label)


# -------------------------------------------------------------------------------------------------
# once the documents are published: full build/validate/round-trip/mutation coverage against the
# real recorded subject_commit
# -------------------------------------------------------------------------------------------------

## Fail-closed on a missing document (dwm-p2r.36, review M-5): this test and the law/schema one
## below used to pending() when a published document was absent, so deleting a sealed document
## left them green. Both documents have been sealed since 6bb2c5b83; absence is a failure now.
func test_published_documents_bind_the_frozen_subject_and_recompute_byte_equal() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		assert_false(published.is_empty(),
			"%s is published; a deleted sealed document is a failure, not a pending" % evidence.ARTIFACT_PATH)
		if published.is_empty():
			continue
		assert_eq(str(published["subject_commit_subject"]), evidence.SUBJECT_COMMIT_SUBJECT)
		var subject_commit: String = str(published["subject_commit"])
		assert_true(GIT_PLUMBING.is_commit_id(subject_commit))
		var rebuilt: Dictionary = evidence.build(_repository_root(), subject_commit)
		assert_true(rebuilt.get("ok", false), JSON.stringify(rebuilt))
		if not rebuilt.get("ok", false):
			continue
		var rebuilt_document: Dictionary = (rebuilt["value"] as Dictionary)["document"]
		var fresh_bytes: Dictionary = evidence.canonical_bytes(rebuilt_document)
		var published_bytes: Dictionary = evidence.canonical_bytes(published)
		assert_eq(fresh_bytes["value"], published_bytes["value"],
			"fresh regeneration is byte-equal to the checked-in document")


func test_published_documents_pass_law_and_schema_validation() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		assert_false(published.is_empty(),
			"%s is published; a deleted sealed document is a failure, not a pending" % evidence.ARTIFACT_PATH)
		if published.is_empty():
			continue
		var validated: Dictionary = evidence.validate(published, _repository_root())
		assert_true(validated.get("ok", false), JSON.stringify(validated))


## Recursively confirms no DICTIONARY KEY ending in "_instance_id" ever carries an INTEGER value
## anywhere in the tree. Deliberately narrower than banning the substring "instance_id" outright:
## `bootstrap_probe.field_keys` legitimately lists the PROBE's own field NAMES as plain strings
## (e.g. the string "mutation_gate_instance_id"), which is exactly the "field/role set" metadata
## the brief requires evidence to record -- that is text describing a field, not a serialized
## numeric instance id, and banning the substring outright would make the required field_keys
## listing impossible to publish at all. What must never appear is an actual `"...instance_id":
## <int>` key/value pair, which is what a live Object's numeric id leaking into the document would
## look like.
func test_no_field_in_either_published_document_is_a_numeric_object_instance_id() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		if published.is_empty():
			pending("evidence/phase_2r/contracts/... not yet generated")
			return
		var violations: Array[String] = []
		_collect_instance_id_integer_keys(published, "$", violations)
		assert_eq(violations, [] as Array[String],
			"the published document carries no *_instance_id KEY WITH AN INTEGER VALUE; the probe " \
			+ "attests relation verdicts, not numeric ids (field NAME strings, e.g. inside " \
			+ "bootstrap_probe.field_keys, are the required field/role-set metadata, not a violation)")


func _collect_instance_id_integer_keys(node: Variant, path: String, violations: Array[String]) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for key: Variant in (node as Dictionary).keys():
			var value: Variant = (node as Dictionary)[key]
			var child_path: String = "%s.%s" % [path, str(key)]
			if str(key).ends_with("instance_id") and typeof(value) == TYPE_INT:
				violations.append(child_path)
			_collect_instance_id_integer_keys(value, child_path, violations)
	elif typeof(node) == TYPE_ARRAY:
		for index: int in range((node as Array).size()):
			_collect_instance_id_integer_keys((node as Array)[index], "%s[%d]" % [path, index], violations)


func test_every_top_level_field_mutation_fails_closed() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		if published.is_empty():
			pending("evidence/phase_2r/contracts/... not yet generated")
			return
		for key: String in (published.keys() as Array):
			var tampered: Dictionary = published.duplicate(true)
			if typeof(tampered[key]) == TYPE_STRING:
				tampered[key] = str(tampered[key]) + "-tampered"
			elif typeof(tampered[key]) == TYPE_ARRAY:
				tampered[key] = (tampered[key] as Array).duplicate(true)
				(tampered[key] as Array).append("tampered")
			elif typeof(tampered[key]) == TYPE_DICTIONARY:
				tampered[key] = (tampered[key] as Dictionary).duplicate(true)
				(tampered[key] as Dictionary)["tampered"] = true
			elif typeof(tampered[key]) == TYPE_BOOL:
				tampered[key] = not bool(tampered[key])
			else:
				tampered[key] = -1
			var validated: Dictionary = evidence.validate_law(tampered, _repository_root())
			assert_false(validated.get("ok", false), "%s: mutating %s must fail closed" % [evidence.ARTIFACT_PATH, key])


func test_a_source_binding_hash_corruption_fails_closed() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		if published.is_empty():
			pending("evidence/phase_2r/contracts/... not yet generated")
			return
		var tampered: Dictionary = published.duplicate(true)
		var bindings: Array = (tampered["source_bindings"] as Array).duplicate(true)
		var first: Dictionary = (bindings[0] as Dictionary).duplicate(true)
		first["sha256"] = "0".repeat(64)
		bindings[0] = first
		tampered["source_bindings"] = bindings
		var validated: Dictionary = evidence.validate(tampered, _repository_root())
		assert_false(validated.get("ok", false))
		assert_eq(validated.get("code"), &"source_binding_hash_mismatch")


func test_check_mode_never_opens_either_target_for_write() -> void:
	if not FileAccess.file_exists(DESKTOP_EVIDENCE.ARTIFACT_PATH):
		pending("evidence/phase_2r/contracts/... not yet generated")
		return
	var loaded: Dictionary = PROBE.load_script(GENERATOR_PATH)
	assert_true(loaded.get("ok", false))
	var before: PackedByteArray = FileAccess.get_file_as_bytes(DESKTOP_EVIDENCE.ARTIFACT_PATH)
	var before_modified: int = FileAccess.get_modified_time(DESKTOP_EVIDENCE.ARTIFACT_PATH)
	# _run_check() is exercised end to end by the PowerShell gate command (Step 9.6/9.8); this unit
	# test proves the narrower, always-checkable property that matters for "check mode opening
	# nothing for write": the published bytes and mtime are unchanged by merely loading the script
	# and by every read-only helper this suite already called above in this same process.
	var after: PackedByteArray = FileAccess.get_file_as_bytes(DESKTOP_EVIDENCE.ARTIFACT_PATH)
	var after_modified: int = FileAccess.get_modified_time(DESKTOP_EVIDENCE.ARTIFACT_PATH)
	assert_eq(after, before)
	assert_eq(after_modified, before_modified)


# -------------------------------------------------------------------------------------------------
# dwm-p2r.35.5 -- red/green evidence integrity (reviewer findings B-C5 and B-I1). Both sealed
# documents shipped red_green_command_records: [] and a bootstrap_probe test-log path that pointed
# at a file nobody had ever curated, and --check still said OK, because the builder skipped any
# absent log without a word, hashed the working tree rather than the subject commit's tree,
# hardcoded exit_code 0, and neither schema set a floor. Everything below is about making each of
# those four silent-pass paths audible.
# -------------------------------------------------------------------------------------------------

func test_every_bound_red_green_log_is_curated_and_parses_to_its_real_outcome() -> void:
	var bound: Array = Array(GIT_PLUMBING.RED_GREEN_LOG_NAMES)
	assert_false(bound.is_empty(), "the amendment binds at least one red/green log")
	var exit_codes: Array[int] = []
	for name: String in bound:
		var resource_path: String = CURATED_LOGS + name
		assert_true(FileAccess.file_exists(resource_path),
			"%s must be curated into evidence/phase_2r/logs/, not left in .godot/phase2r_logs/" % name)
		var outcome: Dictionary = GIT_PLUMBING.parse_gut_log_exit_code(
			FileAccess.get_file_as_bytes(resource_path))
		assert_true(outcome.get("ok", false), "%s parses: %s" % [name, JSON.stringify(outcome)])
		assert_eq(outcome.get("value", {}), EXPECTED_LOG_OUTCOMES.get(name, {}),
			"%s parses to the outcome its own Totals block records" % name)
		exit_codes.append(int((outcome.get("value", {}) as Dictionary)["exit_code"]))
	assert_true(exit_codes.has(1),
		"the bound set contains a genuine RED; an all-green set makes a parsed exit code " \
		+ "indistinguishable from the hardcoded zero it replaces")
	assert_true(exit_codes.has(0), "the bound set contains a green")


## The exact shape of the log this wave refused to bind: .godot/phase2r_logs/
## p2r9-desktop-amendment-gate.log stops mid-listing, with no Totals block and no verdict.
func test_the_gut_parser_refuses_a_log_truncated_before_its_run_summary() -> void:
	var whole: PackedByteArray = FileAccess.get_file_as_bytes(
		CURATED_LOGS + "p2r9-bootstrap-wiring-check3.log")
	var banner_at: int = whole.get_string_from_utf8().rfind("= Run Summary")
	assert_true(banner_at > 0, "the fixture log has a run summary to cut away")
	var truncated: Dictionary = GIT_PLUMBING.parse_gut_log_exit_code(whole.slice(0, banner_at))
	assert_false(truncated.get("ok", false), "a truncated log is not proof of anything")
	assert_eq(truncated.get("code"), &"red_green_log_incomplete")


## A log cut AFTER the banner but before GUT's terminal verdict is still incomplete.
func test_the_gut_parser_refuses_a_log_that_stops_before_the_terminal_verdict() -> void:
	var text: String = FileAccess.get_file_as_bytes(
		CURATED_LOGS + "p2r9-bootstrap-wiring-check3.log").get_string_from_utf8()
	var verdict_at: int = text.rfind("---- All tests passed! ----")
	assert_true(verdict_at > 0, "the fixture log has a verdict to cut away")
	var cut: Dictionary = GIT_PLUMBING.parse_gut_log_exit_code(
		text.substr(0, verdict_at).to_utf8_buffer())
	assert_false(cut.get("ok", false))
	assert_eq(cut.get("code"), &"red_green_log_incomplete")


## A green verdict pasted over a failing Totals block must not mint an exit_code 0 record.
func test_the_gut_parser_refuses_a_verdict_that_contradicts_the_totals() -> void:
	var red: String = FileAccess.get_file_as_bytes(
		CURATED_LOGS + "p2r9-bootstrap-wiring-check.log").get_string_from_utf8()
	var forged: String = red.replace("---- 18 failing tests ----", "---- All tests passed! ----")
	assert_ne(forged, red, "the fixture's verdict line was actually replaced")
	var parsed: Dictionary = GIT_PLUMBING.parse_gut_log_exit_code(forged.to_utf8_buffer())
	assert_false(parsed.get("ok", false))
	assert_eq(parsed.get("code"), &"red_green_log_inconsistent")


## The B-C5 core: a bound log that does not resolve in the named commit's tree fails the whole
## record build closed. A_REAL_WRONG_SUBJECT_COMMIT is a real, immutable commit from before these
## logs were curated, so it stands in permanently for "the log is not there".
func test_a_bound_log_absent_from_the_named_commit_fails_the_record_build_closed() -> void:
	var built: Dictionary = GIT_PLUMBING.build_red_green_command_records(
		_repository_root(), A_REAL_WRONG_SUBJECT_COMMIT)
	assert_false(built.get("ok", false),
		"a missing bound log must fail the build, not be skipped into a shorter record set")
	assert_eq(built.get("code"), &"red_green_log_missing")


## The B-I1 core: bootstrap_probe.test_log_bindings must name files that really exist, and the
## check that says so must itself be capable of failing.
func test_the_bootstrap_probe_test_log_bindings_are_curated_and_checked() -> void:
	var declared: Array = DESKTOP_EVIDENCE.bootstrap_probe_log_paths()
	assert_false(declared.is_empty(), "the probe declares at least one test log")
	for relative: Variant in declared:
		assert_true(FileAccess.file_exists("res://" + str(relative)),
			"%s is curated, not dangling" % str(relative))
	var dangling: Dictionary = GIT_PLUMBING.validate_log_paths_at_commit(
		_repository_root(), A_REAL_WRONG_SUBJECT_COMMIT, declared)
	assert_false(dangling.get("ok", false), "the binding check can actually fail")
	assert_eq(dangling.get("code"), &"test_log_binding_dangling")


## The schema floor tracks the frozen log set, so shrinking the set is a deliberate, visible edit
## in two files rather than a silent one in one.
func test_both_schemas_floor_the_red_green_record_count_at_the_frozen_log_set_size() -> void:
	for schema_path: String in [DESKTOP_EVIDENCE.SCHEMA_PATH, MINESWEEPER_EVIDENCE.SCHEMA_PATH]:
		var schema: Dictionary = (STRICT_JSON.parse_object(
			FileAccess.get_file_as_string(schema_path))["value"] as Dictionary)
		var records: Dictionary = ((schema["properties"] as Dictionary)["red_green_command_records"]
			as Dictionary)
		assert_eq(records.get("minItems"), GIT_PLUMBING.RED_GREEN_LOG_NAMES.size(), schema_path)


## minItems in a schema this repository's own validator ignored would be decoration, which is the
## same silent-pass shape as the bug it is here to close.
func test_the_repository_schema_validator_actually_enforces_min_items() -> void:
	var schema := {"type": "array", "minItems": 2}
	assert_false(SCHEMA_VALIDATOR.validate([] as Array, schema).get("ok", false), "empty")
	assert_false(SCHEMA_VALIDATOR.validate([1] as Array, schema).get("ok", false), "one short")
	assert_true(SCHEMA_VALIDATOR.validate([1, 2] as Array, schema).get("ok", false), "at the floor")


func test_both_schemas_reject_an_empty_red_green_record_set() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		assert_false(published.is_empty(), "%s is published" % evidence.ARTIFACT_PATH)
		var emptied: Dictionary = published.duplicate(true)
		emptied["red_green_command_records"] = [] as Array
		var validated: Dictionary = evidence.validate_schema(emptied)
		assert_false(validated.get("ok", false),
			"%s: an empty record set must not pass the published schema" % evidence.ARTIFACT_PATH)
		assert_eq(validated.get("code"), &"document_schema_rejected")


## Written RED during the wave (dwm-p2r.35.5): both documents on disk were then sealed carrying
## red_green_command_records: [], and the wave itself was forbidden to regenerate them. The
## controller's closing re-seal (subject commit 6d28f7492e75 plus the document commit on top of
## it) is what turned this green. It stays because it is the assertion whose absence let --check
## report CHECK_OK forever.
func test_the_published_documents_bind_a_real_non_empty_red_green_record_set() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		assert_false(published.is_empty(), "%s is published" % evidence.ARTIFACT_PATH)
		var records: Array = published["red_green_command_records"] as Array
		assert_eq(records.size(), GIT_PLUMBING.RED_GREEN_LOG_NAMES.size(),
			"%s binds one record per frozen log" % evidence.ARTIFACT_PATH)
		var exit_codes: Array[int] = []
		for entry: Variant in records:
			var record := entry as Dictionary
			var log_path: String = str(record["log_path"])
			assert_true(FileAccess.file_exists("res://" + log_path), "%s is curated" % log_path)
			assert_eq(str(record["log_sha256"]),
				GIT_PLUMBING.digest_bytes(FileAccess.get_file_as_bytes("res://" + log_path)),
				"%s binds the curated bytes" % log_path)
			exit_codes.append(int(record["exit_code"]))
		assert_true(exit_codes.has(1), "%s binds a real red" % evidence.ARTIFACT_PATH)


## Proves the record BUILDER carries the parsed outcome rather than a constant: the previous
## revision wrote exit_code 0 into every record without looking at the log at all. HEAD is used
## as a commit that certainly carries the curated logs; since the closing re-seal introduced them
## in the sealed subject commit itself, any commit from 6d28f7492e75 forward carries them.
func test_the_record_builder_carries_each_bound_log_s_parsed_exit_code_from_the_tree() -> void:
	var head: Dictionary = GIT_PLUMBING.git_run(_repository_root(), PackedStringArray(["rev-parse", "HEAD"]))
	assert_true(head.get("ok", false), "HEAD resolves")
	var commit: String = str(head.get("output", "")).strip_edges()
	assert_true(GIT_PLUMBING.is_commit_id(commit), commit)
	var built: Dictionary = GIT_PLUMBING.build_red_green_command_records(_repository_root(), commit)
	assert_true(built.get("ok", false), JSON.stringify(built))
	if not built.get("ok", false):
		return
	var records: Array = (built["value"] as Dictionary)["records"]
	assert_eq(records.size(), GIT_PLUMBING.RED_GREEN_LOG_NAMES.size())
	for index: int in range(records.size()):
		var record := records[index] as Dictionary
		var name: String = str(GIT_PLUMBING.RED_GREEN_LOG_NAMES[index])
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, ["exit_code", "log_path", "log_sha256", "suite_id"], name)
		assert_eq(str(record["log_path"]), "evidence/phase_2r/logs/" + name)
		assert_eq(str(record["log_sha256"]),
			GIT_PLUMBING.digest_bytes(FileAccess.get_file_as_bytes(CURATED_LOGS + name)),
			"%s binds the curated bytes" % name)
		assert_eq(int(record["exit_code"]),
			int((EXPECTED_LOG_OUTCOMES[name] as Dictionary)["exit_code"]),
			"%s carries its own parsed exit code" % name)


# -------------------------------------------------------------------------------------------------
# dwm-p2r.36 -- amendment evidence must not self-certify its literals (2026-08-24 fresh-review
# findings I-3/Q4, M-1, M-4). validate_law() compares every non-source field against the builder's
# own hand-written literal, so builder and published document were only ever held consistent WITH
# EACH OTHER; before the dwm-p2r.35.5 re-seal both carried "desktop_contract_ready" long after the
# live probe renamed that field, and the suite stayed green about a literal that was false about
# production. Everything below binds a literal to something live, or a parsed outcome to the line
# GUT actually exits on.
# -------------------------------------------------------------------------------------------------

## I-3/Q4: the one binding from the builder's field_keys literal to the live production probe --
## the keys ApplicationBootstrap._desktop_amendment_probe_fields() actually returns, in
## declaration order. A bare instance is the real production script (never added to the tree, so
## _ready() cannot fire and _target() lawfully resolves nothing); the KEY SET is declared by the
## return literal itself, independent of what the retained members hold. If the probe is renamed
## again, this fails even when test_desktop_bootstrap_wiring.gd's direct indexing is edited in the
## same sweep.
func test_the_builder_field_keys_literal_equals_the_live_bootstrap_probe_field_list() -> void:
	var bootstrap: Node = load("res://autoload/ApplicationBootstrap.gd").new()
	autofree(bootstrap)
	var live: Dictionary = bootstrap._desktop_amendment_probe_fields()
	assert_eq(Array((DESKTOP_EVIDENCE._bootstrap_probe() as Dictionary)["field_keys"]), live.keys(),
		"the builder's field_keys literal is the live probe's own key list, in declaration order")


## M-1, the narrow false-zero the review found: before_all/after_all assert failures produce a
## slashed Asserts line and a nonzero GUT exit but ZERO Failing Tests; alongside a pending
## (passing < tests with a non-all-passed verdict) the old parser called that consistent and
## minted exit_code 0. The totals block below mirrors GUT's real shape for exactly that run.
func test_the_gut_parser_reads_the_asserts_line_gut_actually_exits_on() -> void:
	var log_text: String = "\n".join(PackedStringArray([
		"==============================================",
		"= Run Summary",
		"==============================================",
		"",
		"Totals",
		"------",
		"Scripts               1",
		"Tests                18",
		"Passing Tests        17",
		"Risky/Pending         1",
		"Asserts           250/272",
		"Orphans              24",
		"Time              4.299s",
		"",
		"",
		"---- 1 pending/risky tests. ----",
		"",
	]))
	var parsed: Dictionary = GIT_PLUMBING.parse_gut_log_exit_code(log_text.to_utf8_buffer())
	assert_true(parsed.get("ok", false), JSON.stringify(parsed))
	assert_eq(int((parsed.get("value", {}) as Dictionary).get("exit_code", -1)), 1,
		"failing asserts with zero failing tests is a run GUT exited 1 on, never a lawful zero")


## M-1's forgery half: an all-passed verdict pasted over a slashed Asserts line must be refused,
## exactly as the failing-Totals forgery above it already is.
func test_the_gut_parser_refuses_an_all_passed_verdict_over_failing_asserts() -> void:
	var green: String = FileAccess.get_file_as_bytes(
		CURATED_LOGS + "p2r9-bootstrap-wiring-check3.log").get_string_from_utf8()
	var forged: String = green.replace("Asserts             272", "Asserts           270/272")
	assert_ne(forged, green, "the fixture's Asserts line was actually replaced")
	var parsed: Dictionary = GIT_PLUMBING.parse_gut_log_exit_code(forged.to_utf8_buffer())
	assert_false(parsed.get("ok", false))
	assert_eq(parsed.get("code"), &"red_green_log_inconsistent")


## M-4: the same log used to carry two suite_id spellings -- p2r9_bootstrap_wiring_check3 in
## test_log_bindings, p2r9-bootstrap-wiring-check3 in red_green_command_records -- and nothing
## reconciled them. One rule now, the one build_red_green_command_records() already derives its
## suite_id by: a suite_id IS its log's file name minus .log.
func test_every_test_log_binding_suite_id_is_its_log_file_name_minus_the_extension() -> void:
	var bindings: Array = (DESKTOP_EVIDENCE._bootstrap_probe() as Dictionary)["test_log_bindings"]
	assert_false(bindings.is_empty(), "the probe declares at least one test-log binding")
	for entry: Variant in bindings:
		var binding := entry as Dictionary
		assert_eq(str(binding["suite_id"]),
			str(binding["log_path"]).get_file().trim_suffix(".log"),
			"%s names its suite by the record family's own derivation rule" % str(binding["log_path"]))
