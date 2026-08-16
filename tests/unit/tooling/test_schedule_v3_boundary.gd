extends "res://addons/gut/test.gd"
# Boundary tooling contract for Plan 01 Task 5 Step 5.10 (dwm-p2r.13).
#
# WHAT THIS FILE OWNS
#   * The two closed CLI forms of tools/schedule/generate_schedule_v3_boundary.gd: --write with its
#     three flags, --check with its two, and the four rejection classes plan line 901 enumerates --
#     missing, extra, duplicate, mixed.
#   * The immutable record at evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json: its
#     exact member set, its frozen constants, its canonical bytes, and the fact that every digest in
#     it still matches the blob it names in the boundary commit's tree.
#   * Tamper coverage on all six axes the plan names -- source, log, subject, ancestry, path, hash.
#   * Agreement between the published schema and the generator's own constants, so the two cannot
#     drift apart silently.
#
# WHY BOTH RECORD PASSES ARE EXERCISED SEPARATELY. The generator validates a record twice: once
# against schemas/evidence/phase2r-schedule-v3-boundary.schema.json and once against its own
# imperative law. Asserting only the combined entry point would prove that SOMETHING rejected a
# tampered record without proving which, and the two layers genuinely differ in reach: the repo's
# JsonSchemaValidator honours `minLength` but not `pattern`, so an uppercase SHA-256 satisfies the
# published schema and is caught only by the law. That exact asymmetry is asserted below, in both
# directions, so neither layer can be deleted as redundant.
#
# THE GENERATOR IS NEVER INSTANTIATED. It extends SceneTree and performs its work in _init(), so
# instantiate() would construct a SceneTree and run the tool. Only its statics are called, through
# a preloaded const -- which is a Script resource and constructs nothing.
#
# PARSE HAZARD. GUT installs its own warning set and treats an inferred-Variant `:=` as a parse
# error, so every local declaration below carries an explicit type annotation.

const GENERATOR := preload("res://tools/schedule/generate_schedule_v3_boundary.gd")

const RECORD_PATH := "res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"
const RECORD_RELATIVE := "evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"
const SCHEMA_PATH := "res://schemas/evidence/phase2r-schedule-v3-boundary.schema.json"
const LOG_PATH := "res://evidence/phase_2r/logs/p2r13-schedule-v3-green.log"
const LOG_RELATIVE := "evidence/phase_2r/logs/p2r13-schedule-v3-green.log"

const OWNER_BEADS_ID := "dwm-p2r.13"
const BOUNDARY_SUBJECT := "feat(save): persist canonical committed Schedule"
const EVIDENCE_SUBJECT := "chore(evidence): bind committed Schedule v3 boundary"

const RECORD_KEYS := [
	"boundary_commit",
	"boundary_subject",
	"focused_log_path",
	"focused_log_sha256",
	"migration_path",
	"migration_sha256",
	"owner_beads_id",
	"run_snapshot_schema_path",
	"run_snapshot_schema_sha256",
	"save_document_schema_path",
	"save_document_schema_sha256",
	"schema_version",
]

# The consts the published schema must declare, independently of what the generator believes. This
# is double-entry on the frozen contract: the generator could be edited to accept a different owner
# or path, and this table would still fail.
const SCHEMA_CONSTS := {
	"schema_version": 1,
	"owner_beads_id": "dwm-p2r.13",
	"boundary_subject": "feat(save): persist canonical committed Schedule",
	"run_snapshot_schema_path": "scripts/domain/run/RunSnapshotSchema.gd",
	"save_document_schema_path": "scripts/infrastructure/save/SaveDocumentSchema.gd",
	"migration_path": "scripts/infrastructure/save/SaveMigrations.gd",
	"focused_log_path": "evidence/phase_2r/logs/p2r13-schedule-v3-green.log",
}

# ---- the two closed CLI forms (plan line 901) ----

const SAMPLE_COMMIT := "0123456789abcdef0123456789abcdef01234567"
const BOUNDARY_FLAG := "--boundary-commit=0123456789abcdef0123456789abcdef01234567"
const EVIDENCE_FLAG := "--evidence-commit=0123456789abcdef0123456789abcdef01234567"
const LOG_FLAG := "--focused-log=res://evidence/phase_2r/logs/p2r13-schedule-v3-green.log"
const OUTPUT_FLAG := "--output=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"
const RECORD_FLAG := "--record=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"

const ARGUMENT_REJECTIONS := [
	{"name": "both modes", "code": "generator_mode_mixed",
		"args": ["--write", "--check", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG]},
	{"name": "no mode", "code": "generator_mode_missing",
		"args": [BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG]},
	{"name": "unknown valueless flag", "code": "generator_argument_unknown",
		"args": ["--write", "--force", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG]},
	{"name": "bare positional token", "code": "generator_argument_unknown",
		"args": ["write", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG]},
	{"name": "unknown valued flag", "code": "generator_argument_extra",
		"args": ["--write", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG, "--force=1"]},
	{"name": "write borrowing a check flag", "code": "generator_argument_extra",
		"args": ["--write", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG, RECORD_FLAG]},
	{"name": "check borrowing a write flag", "code": "generator_argument_extra",
		"args": ["--check", EVIDENCE_FLAG, RECORD_FLAG, LOG_FLAG]},
	{"name": "check borrowing the write commit flag", "code": "generator_argument_extra",
		"args": ["--check", EVIDENCE_FLAG, RECORD_FLAG, BOUNDARY_FLAG]},
	{"name": "duplicate output", "code": "generator_argument_duplicate",
		"args": ["--write", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG, OUTPUT_FLAG]},
	{"name": "duplicate record", "code": "generator_argument_duplicate",
		"args": ["--check", EVIDENCE_FLAG, RECORD_FLAG, RECORD_FLAG]},
	{"name": "blank output value", "code": "generator_argument_blank",
		"args": ["--write", BOUNDARY_FLAG, LOG_FLAG, "--output="]},
	{"name": "write missing boundary commit", "code": "generator_argument_missing",
		"args": ["--write", LOG_FLAG, OUTPUT_FLAG]},
	{"name": "write missing focused log", "code": "generator_argument_missing",
		"args": ["--write", BOUNDARY_FLAG, OUTPUT_FLAG]},
	{"name": "write missing output", "code": "generator_argument_missing",
		"args": ["--write", BOUNDARY_FLAG, LOG_FLAG]},
	{"name": "check missing evidence commit", "code": "generator_argument_missing",
		"args": ["--check", RECORD_FLAG]},
	{"name": "check missing record", "code": "generator_argument_missing",
		"args": ["--check", EVIDENCE_FLAG]},
]

# ---- record tampers ----
# `op` is set|remove|add. Rows aimed at the imperative law only; the schema layer is covered
# separately below so the two reaches stay distinguishable.

const ZERO_DIGEST := "0000000000000000000000000000000000000000000000000000000000000000"
const ABSENT_COMMIT := "ffffffffffffffffffffffffffffffffffffffff"

const LAW_TAMPERS := [
	{"name": "extra member", "op": "add", "field": "extra_member", "value": "x",
		"code": "record_member_set_invalid"},
	{"name": "missing member", "op": "remove", "field": "migration_sha256", "value": null,
		"code": "record_member_set_invalid"},
	{"name": "schema version", "op": "set", "field": "schema_version", "value": 2,
		"code": "record_schema_version_invalid"},
	{"name": "owner", "op": "set", "field": "owner_beads_id", "value": "dwm-p2r.9",
		"code": "record_owner_invalid"},
	{"name": "subject case", "op": "set", "field": "boundary_subject",
		"value": "feat(save): persist canonical committed schedule",
		"code": "record_subject_invalid"},
	{"name": "commit shape", "op": "set", "field": "boundary_commit", "value": "3ae8ca1ba",
		"code": "record_commit_invalid"},
	{"name": "log path", "op": "set", "field": "focused_log_path",
		"value": "evidence/phase_2r/logs/p2r13-schedule-v3-green.log.bak",
		"code": "record_log_path_invalid"},
	{"name": "source path", "op": "set", "field": "migration_path",
		"value": "scripts/infrastructure/save/SaveMigrationsLegacy.gd",
		"code": "record_source_path_invalid"},
	{"name": "digest length", "op": "set", "field": "focused_log_sha256", "value": "abc123",
		"code": "record_digest_invalid"},
]

# Rows the published schema must reject on its own, with no help from the imperative law.
const SCHEMA_TAMPERS := [
	{"name": "schema version", "field": "schema_version", "value": 2},
	{"name": "owner", "field": "owner_beads_id", "value": "dwm-p2r.9"},
	{"name": "subject", "field": "boundary_subject", "value": "feat(save): something else"},
	{"name": "source path", "field": "run_snapshot_schema_path", "value": "scripts/Other.gd"},
	{"name": "log path", "field": "focused_log_path", "value": "evidence/other.log"},
	{"name": "short commit", "field": "boundary_commit", "value": "3ae8ca1ba"},
	{"name": "short digest", "field": "migration_sha256", "value": "abc123"},
]

var _record: Dictionary = {}
var _record_bytes: PackedByteArray = PackedByteArray()
var _log_bytes: PackedByteArray = PackedByteArray()


func before_all() -> void:
	if FileAccess.file_exists(RECORD_PATH):
		_record_bytes = FileAccess.get_file_as_bytes(RECORD_PATH)
		var parsed: Dictionary = StrictJson.parse_object(_record_bytes.get_string_from_utf8())
		if parsed.get("ok", false):
			_record = parsed.get("value", {}) as Dictionary
	if FileAccess.file_exists(LOG_PATH):
		_log_bytes = FileAccess.get_file_as_bytes(LOG_PATH)


# ---- documents ----

func test_generator_and_published_documents_load() -> void:
	var probe: Dictionary = DynamicScriptProbe.load_script(
		"res://tools/schedule/generate_schedule_v3_boundary.gd")
	assert_true(probe.get("ok", false),
		"the generator must parse and load: %s" % str(probe.get("message", "")))
	for path: String in [SCHEMA_PATH, RECORD_PATH]:
		assert_true(FileAccess.file_exists(path), "%s must exist" % path)
		if not FileAccess.file_exists(path):
			continue
		var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(path))
		assert_true(parsed.get("ok", false),
			"%s must strict-parse as an object: %s" % [path, str(parsed.get("message", ""))])


func test_permanent_focused_log_is_present_and_nonempty() -> void:
	assert_true(FileAccess.file_exists(LOG_PATH), "%s must exist" % LOG_PATH)
	assert_gt(_log_bytes.size(), 0, "the permanent focused log must carry bytes")


# ---- the published schema, judged independently of the generator ----

func test_published_schema_freezes_the_exact_member_set_and_constants() -> void:
	var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(SCHEMA_PATH))
	assert_true(parsed.get("ok", false), "the published schema must strict-parse")
	if not parsed.get("ok", false):
		return
	var schema: Dictionary = parsed.get("value", {}) as Dictionary
	assert_eq(schema.get("additionalProperties"), false,
		"the schema must close the record against unknown members")
	var required: Array = (schema.get("required", []) as Array).duplicate()
	required.sort()
	assert_eq(required, RECORD_KEYS, "the schema must require exactly the twelve frozen members")
	var properties: Dictionary = schema.get("properties", {}) as Dictionary
	var property_names: Array = properties.keys()
	property_names.sort()
	assert_eq(property_names, RECORD_KEYS,
		"the schema must describe exactly the twelve frozen members")
	for field: String in SCHEMA_CONSTS:
		var property: Dictionary = properties.get(field, {}) as Dictionary
		assert_true(property.has("const"), "%s must be frozen with a const" % field)
		assert_eq(property.get("const"), SCHEMA_CONSTS[field], "%s const" % field)


func test_generator_constants_agree_with_the_published_schema() -> void:
	assert_eq(GENERATOR.OWNER_BEADS_ID, OWNER_BEADS_ID, "owner")
	assert_eq(GENERATOR.BOUNDARY_SUBJECT, BOUNDARY_SUBJECT, "boundary subject")
	assert_eq(GENERATOR.EVIDENCE_SUBJECT, EVIDENCE_SUBJECT, "evidence subject")
	assert_eq(GENERATOR.RECORD_PATH, RECORD_PATH, "record path")
	assert_eq(GENERATOR.FOCUSED_LOG_PATH, LOG_PATH, "focused log path")
	assert_eq(GENERATOR.RECORD_SCHEMA_PATH, SCHEMA_PATH, "record schema path")
	var loaded: Dictionary = GENERATOR.load_record_schema()
	assert_true(loaded.get("ok", false),
		"the generator must load the published schema: %s" % str(loaded.get("code", &"")))


# ---- the two closed CLI forms ----

func test_write_form_is_accepted_with_exactly_its_own_three_flags() -> void:
	var parsed: Dictionary = GENERATOR.parse_arguments(
		PackedStringArray(["--write", BOUNDARY_FLAG, LOG_FLAG, OUTPUT_FLAG]))
	assert_true(parsed.get("ok", false),
		"the write form must be accepted: %s" % str(parsed.get("code", &"")))
	var value: Dictionary = parsed.get("value", {}) as Dictionary
	assert_eq(str(value.get("mode", "")), "write", "mode")
	var values: Dictionary = value.get("values", {}) as Dictionary
	assert_eq(str(values.get("boundary-commit", "")), SAMPLE_COMMIT, "--boundary-commit")
	assert_eq(str(values.get("focused-log", "")), LOG_PATH, "--focused-log")
	assert_eq(str(values.get("output", "")), RECORD_PATH, "--output")
	assert_eq(values.size(), 3, "the write form carries no other flag")


func test_check_form_is_accepted_with_exactly_its_own_two_flags() -> void:
	var parsed: Dictionary = GENERATOR.parse_arguments(
		PackedStringArray(["--check", EVIDENCE_FLAG, RECORD_FLAG]))
	assert_true(parsed.get("ok", false),
		"the check form must be accepted: %s" % str(parsed.get("code", &"")))
	var value: Dictionary = parsed.get("value", {}) as Dictionary
	assert_eq(str(value.get("mode", "")), "check", "mode")
	var values: Dictionary = value.get("values", {}) as Dictionary
	assert_eq(str(values.get("evidence-commit", "")), SAMPLE_COMMIT, "--evidence-commit")
	assert_eq(str(values.get("record", "")), RECORD_PATH, "--record")
	assert_eq(values.size(), 2, "the check form carries no other flag")


func test_every_malformed_invocation_is_rejected_with_its_own_code() -> void:
	for row: Dictionary in ARGUMENT_REJECTIONS:
		var name: String = str(row["name"])
		var parsed: Dictionary = GENERATOR.parse_arguments(PackedStringArray(row["args"] as Array))
		assert_false(parsed.get("ok", true), "%s must be rejected" % name)
		assert_eq(str(parsed.get("code", &"")), str(row["code"]), "%s rejection code" % name)


# ---- the immutable record ----

func test_record_binds_the_boundary_commit_tree_and_the_permanent_log() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var validated: Dictionary = GENERATOR.validate_boundary_record(_record, _log_bytes)
	assert_true(validated.get("ok", false), "the record must validate: %s %s" % [
		str(validated.get("code", &"")), str(validated.get("message", "")),
	])
	assert_eq(str(_record.get("boundary_subject", "")), BOUNDARY_SUBJECT, "boundary subject")
	assert_eq(str(_record.get("owner_beads_id", "")), OWNER_BEADS_ID, "owner")
	assert_eq(str(_record.get("focused_log_path", "")), LOG_RELATIVE, "focused log path")


func test_stored_record_bytes_are_the_canonical_serialization() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var canonical: Dictionary = GENERATOR.canonical_record_bytes(_record)
	assert_true(canonical.get("ok", false),
		"the record must serialize canonically: %s" % str(canonical.get("code", &"")))
	var bytes: PackedByteArray = (canonical.get("value", {}) as Dictionary).get(
		"bytes", PackedByteArray())
	assert_eq(bytes, _record_bytes,
		"the stored record must be canonical JSON followed by exactly one newline")


func test_recorded_boundary_commit_is_an_ancestor_carrying_the_frozen_subject() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var boundary_commit: String = str(_record["boundary_commit"])
	assert_eq(_git_line(PackedStringArray(["show", "-s", "--format=%s", boundary_commit])),
		BOUNDARY_SUBJECT, "the recorded boundary commit must carry the frozen subject")
	var proven: Dictionary = GENERATOR.prove_boundary_commit(boundary_commit)
	assert_true(proven.get("ok", false),
		"the recorded boundary commit must be a proven ancestor: %s" % str(proven.get("code", &"")))


# --check decides direct ancestry from commit_parents() alone, and that reader is the one part of
# the check form no pre-commit run can otherwise reach. Both shapes it must handle are pinned here:
# a normal commit with exactly one parent, compared against an independently resolved rev-parse, and
# the repository root, whose empty parent list must not be read as one blank id.
func test_commit_parent_reader_handles_one_parent_and_the_parentless_root() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var boundary_commit: String = str(_record["boundary_commit"])
	var expected_parent: String = _git_line(
		PackedStringArray(["rev-parse", "%s^" % boundary_commit]))
	assert_eq(expected_parent.length(), 40, "the boundary commit must have a resolvable parent")
	var parents: Dictionary = GENERATOR.commit_parents(boundary_commit)
	assert_true(parents.get("ok", false),
		"commit_parents must read the boundary commit: %s" % str(parents.get("code", &"")))
	var ids: PackedStringArray = (parents.get("value", {}) as Dictionary).get(
		"parents", PackedStringArray())
	assert_eq(ids.size(), 1, "the boundary commit has exactly one parent")
	if ids.size() == 1:
		assert_eq(ids[0], expected_parent, "the parent id must match rev-parse")
	var root_parents: Dictionary = GENERATOR.commit_parents(_root_commit())
	assert_true(root_parents.get("ok", false), "commit_parents must read the root commit")
	assert_eq(((root_parents.get("value", {}) as Dictionary).get(
		"parents", PackedStringArray()) as PackedStringArray).size(), 0,
		"the root commit reports no parents rather than one blank id")


# ---- tamper coverage: the imperative law ----

func test_the_imperative_law_rejects_every_record_tamper() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	for row: Dictionary in LAW_TAMPERS:
		var name: String = str(row["name"])
		var tampered: Dictionary = _tamper(row)
		var judged: Dictionary = GENERATOR.validate_record_law(tampered)
		assert_false(judged.get("ok", true), "%s tamper must be rejected" % name)
		assert_eq(str(judged.get("code", &"")), str(row["code"]), "%s rejection code" % name)


# The law's own reach beyond the schema: an UPPERCASE digest is the right length and the right type,
# so the published schema accepts it, and only the law's lowercase rule catches it. Asserting both
# halves is what stops either layer being deleted as redundant.
func test_only_the_imperative_law_rejects_an_uppercase_digest() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var tampered: Dictionary = _record.duplicate(true)
	tampered["run_snapshot_schema_sha256"] = str(_record["run_snapshot_schema_sha256"]).to_upper()
	var by_schema: Dictionary = GENERATOR.validate_record_schema(tampered)
	assert_true(by_schema.get("ok", false),
		"the published schema cannot see digest case, so it must accept this record")
	var by_law: Dictionary = GENERATOR.validate_record_law(tampered)
	assert_false(by_law.get("ok", true), "the imperative law must reject an uppercase digest")
	assert_eq(str(by_law.get("code", &"")), "record_digest_invalid", "rejection code")


# The same asymmetry on the other hex member, which fails differently. `minLength` is a FLOOR, so a
# forty-one character all-lowercase commit id satisfies the published schema; only the law's
# exact-forty rule catches it. Without this row the schema could silently be relaxed from a length
# floor to nothing at all for boundary_commit and the digest row above would not notice.
func test_only_the_imperative_law_rejects_an_overlong_commit_id() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var tampered: Dictionary = _record.duplicate(true)
	var overlong: String = "%sa" % str(_record["boundary_commit"])
	assert_eq(overlong.length(), 41, "the tamper must be longer than a commit id, not shorter")
	tampered["boundary_commit"] = overlong
	var by_schema: Dictionary = GENERATOR.validate_record_schema(tampered)
	assert_true(by_schema.get("ok", false),
		"minLength is a floor, so the published schema must accept an overlong commit id")
	var by_law: Dictionary = GENERATOR.validate_record_law(tampered)
	assert_false(by_law.get("ok", true), "the imperative law must reject an overlong commit id")
	assert_eq(str(by_law.get("code", &"")), "record_commit_invalid", "rejection code")


# ---- tamper coverage: the published schema ----

func test_the_published_schema_rejects_every_frozen_member_tamper() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	for row: Dictionary in SCHEMA_TAMPERS:
		var name: String = str(row["name"])
		var tampered: Dictionary = _record.duplicate(true)
		tampered[str(row["field"])] = row["value"]
		var judged: Dictionary = GENERATOR.validate_record_schema(tampered)
		assert_false(judged.get("ok", true), "%s tamper must be rejected by the schema" % name)
		assert_eq(str(judged.get("code", &"")), "record_schema_rejected",
			"%s schema rejection code" % name)


# ---- tamper coverage: source, log, and ancestry ----

func test_a_source_digest_that_no_longer_matches_the_boundary_tree_is_rejected() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	for field: String in ["run_snapshot_schema_sha256", "save_document_schema_sha256",
			"migration_sha256"]:
		var tampered: Dictionary = _record.duplicate(true)
		tampered[field] = ZERO_DIGEST
		var judged: Dictionary = GENERATOR.validate_boundary_record(tampered, _log_bytes)
		assert_false(judged.get("ok", true), "%s tamper must be rejected" % field)
		assert_eq(str(judged.get("code", &"")), "boundary_source_hash_mismatch",
			"%s rejection code" % field)


func test_a_focused_log_that_no_longer_matches_the_record_is_rejected() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var recorded_digest_tampered: Dictionary = _record.duplicate(true)
	recorded_digest_tampered["focused_log_sha256"] = ZERO_DIGEST
	var by_record: Dictionary = GENERATOR.validate_boundary_record(
		recorded_digest_tampered, _log_bytes)
	assert_false(by_record.get("ok", true), "a rewritten log digest must be rejected")
	assert_eq(str(by_record.get("code", &"")), "focused_log_hash_mismatch", "rejection code")
	var mutated_bytes: PackedByteArray = _log_bytes.duplicate()
	mutated_bytes.append(0x20)
	var by_bytes: Dictionary = GENERATOR.validate_boundary_record(_record, mutated_bytes)
	assert_false(by_bytes.get("ok", true), "a mutated log body must be rejected")
	assert_eq(str(by_bytes.get("code", &"")), "focused_log_hash_mismatch", "rejection code")


func test_a_boundary_commit_that_is_absent_or_carries_another_subject_is_rejected() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var absent: Dictionary = _record.duplicate(true)
	absent["boundary_commit"] = ABSENT_COMMIT
	var by_absence: Dictionary = GENERATOR.validate_boundary_record(absent, _log_bytes)
	assert_false(by_absence.get("ok", true), "an unresolvable boundary commit must be rejected")
	assert_eq(str(by_absence.get("code", &"")), "boundary_commit_missing", "rejection code")
	var root_commit: String = _root_commit()
	assert_eq(root_commit.length(), 40, "the repository root commit must resolve")
	if root_commit.length() != 40:
		return
	var rebound: Dictionary = _record.duplicate(true)
	rebound["boundary_commit"] = root_commit
	var by_subject: Dictionary = GENERATOR.validate_boundary_record(rebound, _log_bytes)
	assert_false(by_subject.get("ok", true),
		"a real ancestor carrying another subject must be rejected")
	assert_eq(str(by_subject.get("code", &"")), "boundary_subject_mismatch", "rejection code")


# ---- the --check form ----

func test_check_rejects_a_foreign_record_path_and_a_malformed_commit() -> void:
	var foreign: Dictionary = GENERATOR.verify_evidence_commit(
		SAMPLE_COMMIT, "res://evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json")
	assert_false(foreign.get("ok", true), "check must refuse a record path it does not own")
	assert_eq(str(foreign.get("code", &"")), "record_path_invalid", "rejection code")
	var malformed: Dictionary = GENERATOR.verify_evidence_commit("3ae8ca1ba", RECORD_PATH)
	assert_false(malformed.get("ok", true), "check must refuse a short evidence commit")
	assert_eq(str(malformed.get("code", &"")), "evidence_commit_invalid", "rejection code")
	var absent: Dictionary = GENERATOR.verify_evidence_commit(ABSENT_COMMIT, RECORD_PATH)
	assert_false(absent.get("ok", true), "check must refuse an unresolvable evidence commit")
	assert_eq(str(absent.get("code", &"")), "evidence_commit_missing", "rejection code")


func test_check_refuses_a_commit_that_does_not_carry_the_evidence_subject() -> void:
	assert_false(_record.is_empty(), "the immutable record must be present and parsable")
	if _record.is_empty():
		return
	var judged: Dictionary = GENERATOR.verify_evidence_commit(
		str(_record["boundary_commit"]), RECORD_PATH)
	assert_false(judged.get("ok", true),
		"the code boundary is not an evidence commit and must be refused as one")
	assert_eq(str(judged.get("code", &"")), "evidence_subject_mismatch", "rejection code")


# Once the evidence commit exists this reproduces the plan's post-commit --check from history
# alone. Before it exists -- the one run between the write and the commit -- the record is present
# but untracked, and that is what gets asserted instead, so neither branch is vacuous.
func test_check_accepts_the_commit_that_introduced_the_record() -> void:
	var introducing: String = _introducing_commit()
	if introducing.length() != 40:
		assert_true(FileAccess.file_exists(RECORD_PATH),
			"before the evidence commit the record must already be written")
		assert_eq(_git_line(PackedStringArray(["ls-files", "--", RECORD_RELATIVE])), "",
			"before the evidence commit the record must still be untracked")
		return
	assert_eq(_git_line(PackedStringArray(["show", "-s", "--format=%s", introducing])),
		EVIDENCE_SUBJECT, "the introducing commit must carry the evidence subject")
	var verified: Dictionary = GENERATOR.verify_evidence_commit(introducing, RECORD_PATH)
	assert_true(verified.get("ok", false), "check must accept the evidence commit: %s %s" % [
		str(verified.get("code", &"")), str(verified.get("message", "")),
	])


# ---- helpers ----

# This file's OWN git reader, independent of the generator's, so a broken helper there cannot make
# these assertions agree with it by accident. stderr is not captured, for the same reason the
# generator does not capture it: an advice line would be indistinguishable from output.
func _git_line(arguments: PackedStringArray) -> String:
	var repository: String = ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var full: PackedStringArray = PackedStringArray([
		"-c", "safe.directory=%s" % repository, "-C", repository,
	])
	full.append_array(arguments)
	var output: Array = []
	var exit_code: int = OS.execute("git", full, output, false)
	if exit_code != 0:
		return ""
	return "".join(PackedStringArray(output)).strip_edges()


# OS.execute drops line separators, so a multi-line result arrives concatenated. Both callers below
# want a single forty-character id, which the leading forty characters always are.
func _first_commit_id(arguments: PackedStringArray) -> String:
	var joined: String = _git_line(arguments)
	return joined.substr(0, 40) if joined.length() >= 40 else ""


func _root_commit() -> String:
	return _first_commit_id(PackedStringArray(["rev-list", "--max-parents=0", "HEAD"]))


func _introducing_commit() -> String:
	return _first_commit_id(PackedStringArray([
		"log", "--diff-filter=A", "--format=%H", "--", RECORD_RELATIVE,
	]))


func _tamper(row: Dictionary) -> Dictionary:
	var tampered: Dictionary = _record.duplicate(true)
	var field: String = str(row["field"])
	match str(row["op"]):
		"remove":
			tampered.erase(field)
		_:
			tampered[field] = row["value"]
	return tampered
