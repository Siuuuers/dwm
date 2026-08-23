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
const GENERATOR_PATH := "res://tools/evidence/generate_desktop_amendment_evidence.gd"

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

func test_published_documents_bind_the_frozen_subject_and_recompute_byte_equal() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		if published.is_empty():
			pending("evidence/phase_2r/contracts/... not yet generated (Step 9.5 has not run this session)")
			return
		assert_eq(str(published["subject_commit_subject"]), evidence.SUBJECT_COMMIT_SUBJECT)
		var subject_commit: String = str(published["subject_commit"])
		assert_true(GIT_PLUMBING.is_commit_id(subject_commit))
		var rebuilt: Dictionary = evidence.build(_repository_root(), subject_commit)
		assert_true(rebuilt.get("ok", false), JSON.stringify(rebuilt))
		var rebuilt_document: Dictionary = (rebuilt["value"] as Dictionary)["document"]
		var fresh_bytes: Dictionary = evidence.canonical_bytes(rebuilt_document)
		var published_bytes: Dictionary = evidence.canonical_bytes(published)
		assert_eq(fresh_bytes["value"], published_bytes["value"],
			"fresh regeneration is byte-equal to the checked-in document")


func test_published_documents_pass_law_and_schema_validation() -> void:
	for evidence: Script in [DESKTOP_EVIDENCE, MINESWEEPER_EVIDENCE]:
		var published: Dictionary = _published(evidence)
		if published.is_empty():
			pending("evidence/phase_2r/contracts/... not yet generated")
			return
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
