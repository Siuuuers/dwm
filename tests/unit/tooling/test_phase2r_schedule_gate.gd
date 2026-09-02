extends "res://addons/gut/test.gd"
# Plan 01 Task 9 Step 9.1 (dwm-p2r.15): the Phase-2R committed Schedule gate.
#
# WHAT THIS FILE OWNS
#   * The CLI contract and the pure parsers of tools/evidence/generate_phase2r_schedule_gate.gd:
#     declared-surface parsing, the byte-exact matrix-blob law, matrix-row parsing, GUT-log parsing,
#     the derive_child census classifier, and the fixture committed-entry audit.
#   * Double entry on every binding the generator freezes: required/absent declared-surface
#     entries, forbidden executable tokens, the 13 stable P01.* rows read out of the plan text, the
#     bootstrap-probe key set, the committed-entry key law, the retired-symbol absences.
#   * One OBSERVED GREEN provenance vector per realized matrix row (and first/replay/conflict
#     publication vectors over the real ledger and ports), produced over the real substrate
#     (real root store over a fixed namespace, the real issuer, the production registry, a real
#     GameState in the tree, the real commit/start/state ports) and printed as
#     `P2R15_OBSERVED_VECTOR:<canonical json>` so the generator can bind them from the fresh log.
#     Every observed provenance is also mutated member by member and must be refused by the issuer.
#   * The honest disposition of the two rows with no issuer-anchored producer at this subject
#     (P01.day_resolution.stage under DEVIATION-4, P01.hospital.sylvia_witness under the realized
#     witness fact-record shape): their role literal is proved absent from production and the
#     realized shapes are pinned, so the deviation is visible rather than silently "green".
#   * The immutable record at evidence/phase_2r/schedule/gate.json once it exists: canonical bytes,
#     subject-commit proof, digest agreement with the subject tree, and the tamper battery across
#     schema and law, in both directions so neither layer can be deleted as redundant.
#
# THE GENERATOR IS NEVER INSTANTIATED. It extends SceneTree and performs its work in _init(); it is
# loaded with load() in before_all so a missing generator is a failing assertion, never a parse
# error that would drop this suite from a run.
#
# PARSE HAZARD. GUT treats an inferred-Variant `:=` as a parse error, so every local carries an
# explicit type.

const GENERATOR_PATH := "res://tools/evidence/generate_phase2r_schedule_gate.gd"
const RECORD_PATH := "res://evidence/phase_2r/schedule/gate.json"
const RECORD_RELATIVE := "evidence/phase_2r/schedule/gate.json"
const PLAN_PATH := "res://docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-01-phase2r-schedule-foundation.md"
const REQUIRED_SURFACE_PATH := "res://evidence/phase_2r/runtime/game_state_required_surface.json"
const V3_BOUNDARY_PATH := "res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"

const OWNER_BEADS_ID := "dwm-p2r.15"
const SUBJECT := "test(schedule): define the Phase-2R committed Schedule gate"
const EVIDENCE_SUBJECT := "test(schedule): seal the Phase-2R committed Schedule gate"
const VECTOR_MARKER := "P2R15_OBSERVED_VECTOR:"
const PUBLICATION_MARKER := "P2R15_OBSERVED_PUBLICATION:"
const LOG_DIRECTORY := "res://evidence/phase_2r/logs"
const SURFACE_PATH := "res://evidence/phase_2r/runtime/game_state_surface.json"

const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const DAY7_PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CONSEQUENCE_SOURCE := preload("res://tests/support/FakeDesktopConsequenceSource.gd")
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Fixed namespace so every observed vector is a deterministic function of the source alone.
const VECTOR_NAMESPACE := "9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c"
const CAUSAL_DAY := "causal_day_instance.1515151515151515151515151515151515151515151515151515151515151515"
const VIEW_FINGERPRINT := "opaque_view.15151515151515151515151515151515"
const MAX_WALK_STEPS := 40
const HOSPITAL_TIMELINE_ID := "hospital.faint"
const HOSPITAL_STAGE := "hospital_if_triggered"
const DAY_1_6_STAGES := ["lock_day", "validate_schedule", "execute_schedule_actions", "commit_outcomes",
	"hospital_if_triggered", "execute_schedule_dates", "twofriends_if_deferred", "invitation_rollover",
	"increment_day", "reset_day_scope", "new_day_autosave", "unlock_day"]
const DAY_7_STAGES := ["lock_day", "validate_schedule", "close_invitations_run_end",
	"validate_day7_provenance", "checkpoint_day7_provenance"]

const ROW_IDS := [
	"P01.contact_source.solo", "P01.contact_source.group", "P01.schedule.entry",
	"P01.schedule.commit", "P01.schedule.empty_done", "P01.schedule.day7_provenance",
	"P01.day_resolution.start", "P01.day_resolution.stage", "P01.hospital.resolution",
	"P01.hospital.miss", "P01.hospital.sylvia_witness", "P01.presentation.intent",
	"P01.presentation.completion",
]
const ROW_KINDS := {
	"P01.contact_source.solo": "contact_source", "P01.contact_source.group": "contact_source",
	"P01.schedule.entry": "schedule_entry", "P01.schedule.commit": "schedule_commit",
	"P01.schedule.empty_done": "empty_schedule_done",
	"P01.schedule.day7_provenance": "day7_schedule_provenance",
	"P01.day_resolution.start": "day_resolution_stage", "P01.day_resolution.stage": "day_resolution_stage",
	"P01.hospital.resolution": "hospital_resolution", "P01.hospital.miss": "hospital_miss",
	"P01.hospital.sylvia_witness": "sylvia_hospital_witness",
	"P01.presentation.intent": "day_resolution_stage", "P01.presentation.completion": "day_resolution_stage",
}
const UNREALIZED_ROWS := ["P01.day_resolution.stage", "P01.hospital.sylvia_witness"]
const REALIZED_WITNESS_KEYS := [
	"action_id", "affection_delta", "attitude", "care_followup_day", "care_followup_entry_id",
	"dark_delta", "hospital_miss_ordinal", "kind", "resolution_kind", "schedule_entry_id",
	"source_receipt_id", "tier_transition",
]
const TASK4_SEAMS := [
	"capture_schedule_commit_state", "prepare_schedule_commit_candidate",
	"commit_schedule_commit_candidate", "rollback_schedule_commit_state", "publish_schedule_commit",
	"committed_schedule_published",
]

const SAMPLE_COMMIT := "0123456789abcdef0123456789abcdef01234567"
const OUTPUT_FLAG := "--output=res://evidence/phase_2r/schedule/gate.json"
const BEADS_FLAG := "--beads-snapshot=res://.godot/beads/phase2r-all.json"
const COMMIT_FLAG := "--subject-commit=0123456789abcdef0123456789abcdef01234567"
const ARGUMENT_REJECTIONS := [
	{"name": "unknown valueless flag", "code": "unknown_generator_argument",
		"args": [OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG, "--write"]},
	{"name": "bare positional token", "code": "unknown_generator_argument",
		"args": ["check", OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG]},
	{"name": "unknown valued flag", "code": "unknown_generator_argument",
		"args": [OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG, "--focused-log=x"]},
	{"name": "duplicate output", "code": "duplicate_generator_argument",
		"args": [OUTPUT_FLAG, OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG]},
	{"name": "duplicate check", "code": "duplicate_generator_argument",
		"args": [OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG, "--check", "--check"]},
	{"name": "blank subject commit", "code": "blank_generator_argument",
		"args": [OUTPUT_FLAG, BEADS_FLAG, "--subject-commit="]},
	{"name": "missing output", "code": "missing_generator_argument", "args": [BEADS_FLAG, COMMIT_FLAG]},
	{"name": "missing beads snapshot", "code": "missing_generator_argument", "args": [OUTPUT_FLAG, COMMIT_FLAG]},
	{"name": "missing subject commit", "code": "missing_generator_argument", "args": [OUTPUT_FLAG, BEADS_FLAG]},
	{"name": "semantic fact smuggled as a flag", "code": "unknown_generator_argument",
		"args": [OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG, "--registry-fingerprint=abc"]},
]

const SURFACE_FIXTURE := """extends RefCounted
## func documented_in_a_comment(not_real)
signal completion_ready(completion_result: Dictionary)
signal bare_signal
const THING := "func not_a_func(x)"
func _init(game_state: Object, action_registry: Object,
		identity_issuer: Object, publication_ledger: Object) -> void:
	pass
func configure(_root_store: Object) -> Dictionary:
	return {}
func publish(publication: Dictionary = {}) -> Dictionary:
	return {}
static func load_current() -> Dictionary:
	return {}
func _private_helper(value: int) -> int:
	return value
	func indented_inner(x: int) -> void:
		pass
"""
const SURFACE_FIXTURE_ENTRIES := [
	"signal completion_ready(completion_result)", "signal bare_signal()",
	"func _init(game_state,action_registry,identity_issuer,publication_ledger)",
	"func configure(_root_store)", "func publish(publication)", "static func load_current()",
]

const ZERO_DIGEST := "0000000000000000000000000000000000000000000000000000000000000000"
const ABSENT_COMMIT := "ffffffffffffffffffffffffffffffffffffffff"

var _generator: Script = null
var _record: Dictionary = {}
var _record_bytes: PackedByteArray = PackedByteArray()
var _plan_bytes: PackedByteArray = PackedByteArray()
var _matrix_rows: Array = []

# substrate state for the observed-vector tests
var _root: String = ""
var _root_counter: int = 0
var _registry: RefCounted = null
var _fingerprint: String = ""
var _issuer: RefCounted = null
var _game_state: Node = null
var _state_port: RefCounted = null
var _start_port: RefCounted = null
var _ledger: RefCounted = null
var _consequence: RefCounted = null
var _commands: Dictionary = {}


func before_all() -> void:
	var probe: Dictionary = DynamicScriptProbe.load_script(GENERATOR_PATH)
	if probe.get("ok", false):
		_generator = probe["value"]
	if FileAccess.file_exists(RECORD_PATH):
		_record_bytes = FileAccess.get_file_as_bytes(RECORD_PATH)
		var parsed: Dictionary = StrictJson.parse_object(_record_bytes.get_string_from_utf8())
		if parsed.get("ok", false):
			_record = parsed["value"] as Dictionary
	if FileAccess.file_exists(PLAN_PATH):
		_plan_bytes = FileAccess.get_file_as_bytes(PLAN_PATH)
	if _generator != null and not _plan_bytes.is_empty():
		var blob: Dictionary = _generator.extract_matrix_blob(_plan_bytes)
		if blob.get("ok", false):
			var rows: Dictionary = _generator.parse_matrix_rows(
				((blob["value"] as Dictionary)["bytes"] as PackedByteArray).get_string_from_utf8())
			if rows.get("ok", false):
				_matrix_rows = (rows["value"] as Dictionary)["rows"]


func _ready_generator() -> bool:
	assert_not_null(_generator, "the generator must load: " + GENERATOR_PATH)
	return _generator != null


# =================================================================================================
# the generator and its frozen constants
# =================================================================================================

func test_generator_loads_and_freezes_its_contract() -> void:
	if not _ready_generator():
		return
	assert_eq(_generator.OWNER_BEADS_ID, OWNER_BEADS_ID, "owner")
	assert_eq(_generator.SUBJECT_COMMIT_SUBJECT, SUBJECT, "subject commit subject")
	assert_eq(_generator.EVIDENCE_COMMIT_SUBJECT, EVIDENCE_SUBJECT, "evidence commit subject")
	assert_eq(_generator.OUTPUT_PATH, RECORD_PATH, "output path")
	assert_eq("res://" + _generator.PLAN_PATH, PLAN_PATH, "plan path")
	assert_eq(_generator.MATRIX_ROW_COUNT, 13, "thirteen stable rows")
	assert_eq(_generator.MATRIX_BEGIN_PAYLOAD, "PLAN01_CHILD_DERIVATION_MATRIX_V1_BEGIN", "begin payload")
	assert_eq(_generator.MATRIX_END_PAYLOAD, "PLAN01_CHILD_DERIVATION_MATRIX_V1_END", "end payload")
	var realizations: Dictionary = _generator.ROW_REALIZATIONS
	var ids: Array = realizations.keys()
	ids.sort()
	var expected: Array = ROW_IDS.duplicate()
	expected.sort()
	assert_eq(ids, expected, "the realization map names exactly the thirteen rows")
	for row_id: String in UNREALIZED_ROWS:
		assert_true(((realizations[row_id] as Dictionary)["producers"] as Array).is_empty(),
			row_id + " has no issuer-anchored producer at this subject")
		assert_false(str((realizations[row_id] as Dictionary).get("deviation", "")).is_empty(),
			row_id + " records its deviation")
	for row_id: String in ROW_IDS:
		if row_id in UNREALIZED_ROWS:
			continue
		assert_false(((realizations[row_id] as Dictionary)["producers"] as Array).is_empty(),
			row_id + " names at least one producer")


# =================================================================================================
# CLI contract
# =================================================================================================

func test_write_and_check_forms_are_accepted_with_exactly_the_three_flags() -> void:
	if not _ready_generator():
		return
	var written: Dictionary = _generator.parse_arguments(PackedStringArray([OUTPUT_FLAG, BEADS_FLAG, COMMIT_FLAG]))
	assert_true(written.get("ok", false), "the write form is accepted: " + str(written.get("code", &"")))
	var value: Dictionary = written.get("value", {}) as Dictionary
	assert_eq(str(value.get("output", "")), RECORD_PATH, "--output")
	assert_eq(str(value.get("beads_snapshot", "")), "res://.godot/beads/phase2r-all.json", "--beads-snapshot")
	assert_eq(str(value.get("subject_commit", "")), SAMPLE_COMMIT, "--subject-commit")
	assert_false(bool(value.get("check", true)), "write mode")
	var checked: Dictionary = _generator.parse_arguments(PackedStringArray([COMMIT_FLAG, "--check", OUTPUT_FLAG, BEADS_FLAG]))
	assert_true(checked.get("ok", false), "the check form is accepted in any order")
	assert_true(bool((checked.get("value", {}) as Dictionary).get("check", false)), "check mode")


func test_every_malformed_invocation_is_rejected_with_its_own_code() -> void:
	if not _ready_generator():
		return
	for row: Dictionary in ARGUMENT_REJECTIONS:
		var parsed: Dictionary = _generator.parse_arguments(PackedStringArray(row["args"] as Array))
		assert_false(parsed.get("ok", true), str(row["name"]) + " must be rejected")
		assert_eq(str(parsed.get("code", &"")), str(row["code"]), str(row["name"]) + " rejection code")


# =================================================================================================
# pure parsers
# =================================================================================================

func test_declared_surface_parser_applies_its_frozen_rules() -> void:
	if not _ready_generator():
		return
	var parsed: Dictionary = _generator.parse_declared_surface(SURFACE_FIXTURE)
	assert_true(parsed.get("ok", false), "the fixture parses")
	var entries: Array = (parsed["value"] as Dictionary)["entries"]
	assert_eq(entries, SURFACE_FIXTURE_ENTRIES,
		"signals, funcs, static funcs and _init are kept; comments, consts, private helpers and inner methods are not")
	var preimage: String = str((parsed["value"] as Dictionary)["preimage"])
	assert_eq(preimage, "\n".join(PackedStringArray(SURFACE_FIXTURE_ENTRIES)) + "\n", "preimage is entries joined by LF")
	assert_eq(str((parsed["value"] as Dictionary)["sha256"]).length(), 64, "lowercase sha256")
	var renamed: Dictionary = _generator.parse_declared_surface(SURFACE_FIXTURE.replace("func configure(_root_store", "func configure(root_store"))
	assert_ne(str((renamed["value"] as Dictionary)["sha256"]), str((parsed["value"] as Dictionary)["sha256"]),
		"a parameter rename changes the surface hash: _root_store is not root_store")


func test_comment_stripper_removes_comments_but_keeps_hash_characters_inside_strings() -> void:
	if not _ready_generator():
		return
	var stripped: String = _generator.strip_comments("var a := \"#not a comment\" # a comment\n## doc\nvar b := 1")
	assert_eq(stripped, "var a := \"#not a comment\" \n\nvar b := 1", "only real comments are removed")


func test_matrix_blob_is_selected_byte_exactly_from_the_committed_plan_text() -> void:
	if not _ready_generator():
		return
	assert_false(_plan_bytes.is_empty(), "the plan must exist")
	var blob: Dictionary = _generator.extract_matrix_blob(_plan_bytes)
	assert_true(blob.get("ok", false), "the blob extracts: " + str(blob.get("code", &"")))
	if not blob.get("ok", false):
		return
	var bytes: PackedByteArray = (blob["value"] as Dictionary)["bytes"]
	var text: String = bytes.get_string_from_utf8()
	assert_true(text.begins_with("#### Canonical Plan-01 child-derivation matrix"),
		"the blob starts on the heading line immediately after the BEGIN delimiter")
	assert_true(text.ends_with("\n"), "the blob ends with the LF immediately before the END delimiter")
	assert_lt(text.find("<!-- "), 0, "neither delimiter is inside the blob")
	assert_eq(str((blob["value"] as Dictionary)["sha256"]), _sha256_bytes(bytes), "the hash is of those exact bytes")
	# A byte outside the blob must not move the hash; a byte inside must.
	var outside: PackedByteArray = ("# changed title\n").to_utf8_buffer()
	outside.append_array(_plan_bytes)
	var outside_blob: Dictionary = _generator.extract_matrix_blob(outside)
	assert_eq(str((outside_blob["value"] as Dictionary)["sha256"]), str((blob["value"] as Dictionary)["sha256"]),
		"bytes before the BEGIN delimiter do not affect the matrix hash")
	var inside: PackedByteArray = _plan_bytes.duplicate()
	var heading_at: int = _find(inside, "#### Canonical Plan-01 child-derivation matrix".to_utf8_buffer())
	inside[heading_at + 5] = 0x63
	var inside_blob: Dictionary = _generator.extract_matrix_blob(inside)
	assert_ne(str((inside_blob["value"] as Dictionary)["sha256"]), str((blob["value"] as Dictionary)["sha256"]),
		"one byte inside the blob changes the matrix hash")


func test_matrix_delimiter_law_rejects_every_delimiter_tamper() -> void:
	if not _ready_generator():
		return
	var begin: PackedByteArray = "<!-- PLAN01_CHILD_DERIVATION_MATRIX_V1_BEGIN -->".to_utf8_buffer()
	var end: PackedByteArray = "<!-- PLAN01_CHILD_DERIVATION_MATRIX_V1_END -->".to_utf8_buffer()
	var duplicated: PackedByteArray = _plan_bytes.duplicate()
	duplicated.append_array(begin)
	duplicated.append_array("\n".to_utf8_buffer())
	assert_eq(str(_generator.extract_matrix_blob(duplicated).get("code", &"")), "matrix_begin_delimiter_count", "two BEGIN delimiters")
	var ended_twice: PackedByteArray = _plan_bytes.duplicate()
	ended_twice.append_array("\n".to_utf8_buffer())
	ended_twice.append_array(end)
	assert_eq(str(_generator.extract_matrix_blob(ended_twice).get("code", &"")), "matrix_end_delimiter_count", "two END delimiters")
	var lowercase: PackedByteArray = _plan_bytes.get_string_from_utf8().replace(
		"PLAN01_CHILD_DERIVATION_MATRIX_V1_BEGIN", "plan01_child_derivation_matrix_v1_begin").to_utf8_buffer()
	assert_eq(str(_generator.extract_matrix_blob(lowercase).get("code", &"")), "matrix_begin_delimiter_count", "payload case is exact")
	var reordered: PackedByteArray = (end.get_string_from_utf8() + "\nbody\n" + begin.get_string_from_utf8() + "\n").to_utf8_buffer()
	assert_eq(str(_generator.extract_matrix_blob(reordered).get("code", &"")), "matrix_delimiter_order", "END before BEGIN")
	var glued: PackedByteArray = (begin.get_string_from_utf8() + "\nbody" + end.get_string_from_utf8() + "\n").to_utf8_buffer()
	assert_eq(str(_generator.extract_matrix_blob(glued).get("code", &"")), "matrix_end_line_not_preceded_by_lf",
		"the END delimiter must be preceded by LF; no text is silently trimmed")
	var unterminated: PackedByteArray = (begin.get_string_from_utf8() + " trailing" + end.get_string_from_utf8() + "\n").to_utf8_buffer()
	assert_eq(str(_generator.extract_matrix_blob(unterminated).get("code", &"")), "matrix_begin_line_unterminated", "the BEGIN line must end in LF")
	var trailing_junk: PackedByteArray = (begin.get_string_from_utf8() + " junk\nrow\n" + end.get_string_from_utf8() + "\n").to_utf8_buffer()
	assert_eq(str(_generator.extract_matrix_blob(trailing_junk).get("code", &"")), "matrix_begin_line_unterminated",
		"text after the BEGIN delimiter on its own line is refused rather than silently excluded from the hash")
	var crlf: PackedByteArray = (begin.get_string_from_utf8() + "\r\nrow\r\n" + end.get_string_from_utf8() + "\r\n").to_utf8_buffer()
	var crlf_blob: Dictionary = _generator.extract_matrix_blob(crlf)
	assert_true(crlf_blob.get("ok", false), "CRLF is not normalized away")
	assert_eq(((crlf_blob["value"] as Dictionary)["bytes"] as PackedByteArray).get_string_from_utf8(), "row\r\n",
		"the CR before the LF stays inside the blob")


func test_the_thirteen_rows_are_read_out_of_the_plan_text() -> void:
	if not _ready_generator():
		return
	assert_eq(_matrix_rows.size(), 13, "thirteen rows parse out of the committed plan")
	if _matrix_rows.size() != 13:
		return
	for index: int in range(ROW_IDS.size()):
		var row: Dictionary = _matrix_rows[index]
		assert_eq(str(row["row_id"]), str(ROW_IDS[index]), "row %d id in matrix order" % index)
		assert_eq(str(row["child_kind"]), str(ROW_KINDS[str(row["row_id"])]), str(row["row_id"]) + " child kind")
		assert_true((row["source_paths"] as Array).has("role"), str(row["row_id"]) + " projects a role token")
		assert_false(str(row["ordinal_law"]).is_empty(), str(row["row_id"]) + " has an ordinal law")
		assert_false(str(row["parent"]).is_empty(), str(row["row_id"]) + " names its parent")
		assert_true(str(row["parent"]).ends_with("receipt_id"), str(row["row_id"]) + " parent is a receipt id")
	var entry: Dictionary = _row("P01.schedule.entry")
	assert_eq(entry["source_paths"], ["role", "transaction_id", "view_fingerprint", "causal_day_instance",
		"registry_fingerprint", "draft_entry_id", "day", "slot_index", "action_id", "action_kind", "participants",
		"source_receipt_id"], "the entry row's twelve paths in plan order")
	var witness: Dictionary = _row("P01.hospital.sylvia_witness")
	assert_eq((witness["source_paths"] as Array).size(), 16, "the witness row's sixteen paths")
	var increment: Dictionary = _row("P01.day_resolution.stage")
	assert_true((increment["source_paths"] as Array).has("input_receipt_ids"),
		"the stage row carries the sole target-issuer-receipt input exception for increment_day")
	var blob_text: String = (((_generator.extract_matrix_blob(_plan_bytes))["value"] as Dictionary)["bytes"] as PackedByteArray).get_string_from_utf8()
	assert_true(blob_text.find("`increment_day` is derived only after the shared root allocation commits") >= 0,
		"the increment_day input exception is stated by the plan text the blob hash binds")
	assert_true(blob_text.find("Schedule entry rows precede the nonempty aggregate row") >= 0,
		"the required derivation order is stated inside the hashed blob")


func test_matrix_row_parser_rejects_structural_tampers_and_reflects_token_swaps() -> void:
	if not _ready_generator():
		return
	var blob_text: String = (((_generator.extract_matrix_blob(_plan_bytes))["value"] as Dictionary)["bytes"] as PackedByteArray).get_string_from_utf8()
	var lines: PackedStringArray = blob_text.split("\n")
	var entry_line: int = -1
	for index: int in range(lines.size()):
		if lines[index].begins_with("| `P01.schedule.entry`"):
			entry_line = index
	assert_gt(entry_line, 0, "the entry row line is found")
	var deleted: PackedStringArray = lines.duplicate()
	deleted.remove_at(entry_line)
	assert_eq(str(_generator.parse_matrix_rows("\n".join(deleted)).get("code", &"")), "matrix_row_count", "deleting a row")
	var added: PackedStringArray = lines.duplicate()
	added.insert(entry_line, lines[entry_line].replace("P01.schedule.entry", "P01.schedule.extra"))
	assert_eq(str(_generator.parse_matrix_rows("\n".join(added)).get("code", &"")), "matrix_row_count", "adding a row")
	var duplicated: PackedStringArray = lines.duplicate()
	duplicated.insert(entry_line, lines[entry_line])
	var duplicate_result: Dictionary = _generator.parse_matrix_rows("\n".join(duplicated))
	assert_false(duplicate_result.get("ok", true), "duplicating a row id")
	var substituted: PackedStringArray = lines.duplicate()
	substituted[entry_line] = lines[entry_line].replace("P(\"slot_index\",entry.slot_index)", "P(\"day\",entry.day)")
	assert_eq(str(_generator.parse_matrix_rows("\n".join(substituted)).get("code", &"")), "matrix_row_duplicate_path",
		"substituting a neighbouring path makes one row name a path twice")
	var swapped: PackedStringArray = lines.duplicate()
	swapped[entry_line] = lines[entry_line].replace(
		"P(\"draft_entry_id\",entry.draft_entry_id)`, `P(\"day\",entry.day)`",
		"P(\"day\",entry.day)`, `P(\"draft_entry_id\",entry.draft_entry_id)`")
	assert_ne(swapped[entry_line], lines[entry_line], "the swap edit applied")
	var swapped_rows: Dictionary = _generator.parse_matrix_rows("\n".join(swapped))
	assert_true(swapped_rows.get("ok", false), "a token swap still parses")
	var swapped_entry: Dictionary = _row_in((swapped_rows["value"] as Dictionary)["rows"], "P01.schedule.entry")
	assert_ne(swapped_entry["source_paths"], _row("P01.schedule.entry")["source_paths"],
		"swapping two source tokens changes the parsed row, so the bound record would differ")
	var renamed: PackedStringArray = lines.duplicate()
	renamed[entry_line] = lines[entry_line].replace("`P01.schedule.entry`", "`P01.schedule.entry_v2`")
	var renamed_rows: Dictionary = _generator.parse_matrix_rows("\n".join(renamed))
	assert_true(renamed_rows.get("ok", false), "a renamed row parses")
	assert_false(_generator.ROW_REALIZATIONS.has("P01.schedule.entry_v2"), "but the generator refuses to bind an unknown row id")
	var kind_changed: PackedStringArray = lines.duplicate()
	kind_changed[entry_line] = lines[entry_line].replace("| `schedule_entry` |", "| `schedule_commit` |")
	var kind_rows: Dictionary = _generator.parse_matrix_rows("\n".join(kind_changed))
	assert_eq(str(_row_in((kind_rows["value"] as Dictionary)["rows"], "P01.schedule.entry")["child_kind"]),
		"schedule_commit", "a changed child kind is reflected, and the law catches it against the observed vector")


func test_gut_log_parser_reads_counts_executed_suites_load_failures_and_vectors() -> void:
	if not _ready_generator():
		return
	var sample: String = "res://tests/unit/tooling/test_phase2r_schedule_gate.gd\n" \
		+ "* test_alpha\n* test_beta\n" \
		+ VECTOR_MARKER + "{\"row_id\":\"P01.x\",\"child_id\":\"c\"}\n" \
		+ PUBLICATION_MARKER + "{\"owner\":\"ledger\",\"kind\":\"schedule_commit\"}\n" \
		+ "ERROR: Failed to load script res://tests/unit/missing.gd\n" \
		+ "==============================================\n= Run Summary\n==============================================\n\n" \
		+ "Scripts               2\nTests                 9\nPassing Tests         7\nFailing Tests         2\n" \
		+ "Risky/Pending         1\nAsserts            990/996\nOrphans              24\n"
	var parsed: Dictionary = _generator.parse_gut_log(sample)
	assert_true(parsed.get("ok", false), "the sample parses")
	var value: Dictionary = parsed["value"]
	assert_eq(int(value["scripts"]), 2, "scripts")
	assert_eq(int(value["tests"]), 9, "tests")
	assert_eq(int(value["passing"]), 7, "passing")
	assert_eq(int(value["failing"]), 2, "failing")
	assert_eq(int(value["pending"]), 1, "GUT prints Risky/Pending, and that is what is read")
	assert_eq(int(value["asserts"]), 990, "asserts passed, read from the passed/total form GUT prints on failure")
	assert_eq(int(value["asserts_total"]), 996, "asserts total")
	assert_eq(value["executed_suites"], ["res://tests/unit/tooling/test_phase2r_schedule_gate.gd"], "executed suites")
	assert_eq(value["test_names"], ["test_alpha", "test_beta"], "test names")
	assert_eq(int(value["load_failures"]), 1, "load failures")
	assert_eq(value["vectors"], [{"row_id": "P01.x", "child_id": "c"}], "vectors")
	assert_eq(value["publications"], [{"owner": "ledger", "kind": "schedule_commit"}], "publications")
	var clean: Dictionary = _generator.parse_gut_log("= Run Summary\nAsserts            1008\n")
	assert_eq(int((clean["value"] as Dictionary)["asserts"]), 1008, "a clean run has asserts == total")
	assert_eq(int((clean["value"] as Dictionary)["asserts_total"]), 1008, "asserts total on a clean run")
	var malformed: Dictionary = _generator.parse_gut_log(VECTOR_MARKER + "{not json}\n")
	assert_eq(str(malformed.get("code", &"")), "observed_vector_unparsable", "a malformed vector line is refused")
	var malformed_publication: Dictionary = _generator.parse_gut_log(PUBLICATION_MARKER + "{not json}\n")
	assert_eq(str(malformed_publication.get("code", &"")), "observed_publication_unparsable", "a malformed publication line is refused")
	var orphan_count_ignored: Dictionary = _generator.parse_gut_log("Orphans              24\nTests 3\n")
	assert_eq(int((orphan_count_ignored["value"] as Dictionary)["tests"]), 0,
		"counts are only read after the run summary banner")

func test_derive_child_census_classifier_separates_definition_capability_calls_and_dynamic_sites() -> void:
	if not _ready_generator():
		return
	var classified: Dictionary = _generator.classify_derive_child_hits([
		{"path": "a.gd", "line": 1, "text": "func derive_child(request: Dictionary) -> Dictionary:"},
		{"path": "b.gd", "line": 2, "text": "const _ISSUER_METHODS: Array[String] = [\"verify_issued\", \"derive_child\"]"},
		{"path": "b.gd", "line": 3, "text": "\t\t\"derive_child\", \"validate_child\",", "previous": "\tfor method: String in [\"issue\", \"verify_issued\","},
		{"path": "b.gd", "line": 4, "text": "\t\tor not identity_issuer.has_method(\"derive_child\") \\"},
		{"path": "b.gd", "line": 5, "text": "\tvar ready := _require_configured(\"derive_child\")"},
		{"path": "c.gd", "line": 6, "text": "\tvar derived: Variant = _identity_issuer.call(&\"derive_child\", {"},
		{"path": "d.gd", "line": 6, "text": "## documentation mentioning derive_child"},
		{"path": "e.gd", "line": 7, "text": "\tvar derived: Variant = _identity_issuer.callv(method_name, [request])  # derive_child"},
		{"path": "f.gd", "line": 8, "text": "\tvar name := \"derive_child\"; issuer.call(name, request)"},
		{"path": "g.gd", "line": 9, "text": "\tvar derived := _derive_child(parent_id, ENTRY_CHILD_KIND, index, tokens)"},
		{"path": "g.gd", "line": 10, "text": "func _derive_child(parent_receipt_id: String, sources: Array) -> Dictionary:"},
		{"path": "h.gd", "line": 12, "text": "\t\t&\"derive_child\", request)", "previous": "\tvar derived: Variant = _identity_issuer.call("},
		{"path": "i.gd", "line": 13, "text": "\tissuer.call_deferred(\"derive_child\", request)"},
		{"path": "j.gd", "line": 14, "text": "\tvar c := Callable(issuer, \"derive_child\")"},
		{"path": "k.gd", "line": 15, "text": "\t\t\"derive_child\", request)", "previous": "\tvar derived: Variant = _identity_issuer.call("},
		{"path": "l.gd", "line": 16, "text": "\tvar kind := &\"derive_child\""},
	])
	var value: Dictionary = classified["value"]
	assert_eq(value["definition"], [{"path": "a.gd", "line": 1}], "definition")
	assert_eq(value["capability"], [{"path": "b.gd", "line": 2}, {"path": "b.gd", "line": 3}, {"path": "b.gd", "line": 4}, {"path": "b.gd", "line": 5}],
		"array literals, array continuations, has_method checks and the issuer guard are capability")
	assert_eq(value["call_sites"], [{"path": "c.gd", "line": 6}], "literal call sites")
	assert_eq(value["comments"], [{"path": "d.gd", "line": 6}], "comments")
	assert_eq(value["wrappers"], [{"path": "g.gd", "line": 9}, {"path": "g.gd", "line": 10}],
		"a producer's private _derive_child wrapper and its calls are wrappers, attributed with their file")
	assert_eq(value["dynamic"], [{"path": "e.gd", "line": 7}, {"path": "f.gd", "line": 8}, {"path": "h.gd", "line": 12},
		{"path": "i.gd", "line": 13}, {"path": "j.gd", "line": 14}, {"path": "k.gd", "line": 15}, {"path": "l.gd", "line": 16}],
		"callv, a call through a variable, a call wrapped across lines (StringName or String), call_deferred, Callable and a bare StringName literal are all dynamic")

func test_fixture_audit_accepts_exact_committed_entries_and_refuses_caller_owned_fields() -> void:
	if not _ready_generator():
		return
	var entry: Dictionary = {
		"schedule_entry_id": "e", "schedule_entry_provenance": {}, "day": 3, "slot_index": 0,
		"action_id": "training", "action_kind": "ordinary", "participants": [], "source_receipt_id": null,
		"commit_transaction_id": "t", "state": "committed",
	}
	var document: Dictionary = {"run": {"committed_schedule": {"schema_version": 1, "day": 3,
		"registry_fingerprint": ZERO_DIGEST, "entries": [entry], "commit_receipt": null}}}
	var accepted: Dictionary = _generator.audit_fixture_committed_schedules(document)
	assert_true(accepted.get("ok", false), "an exact committed entry is accepted")
	assert_eq(accepted["value"], {"aggregates": 1, "entries": 1}, "counts")
	for field: String in ["route_id", "effect_ids", "motivation_cost"]:
		var polluted: Dictionary = document.duplicate(true)
		(((polluted["run"] as Dictionary)["committed_schedule"] as Dictionary)["entries"] as Array)[0][field] = "x"
		var judged: Dictionary = _generator.audit_fixture_committed_schedules(polluted)
		assert_false(judged.get("ok", true), field + " is refused")
		assert_eq(str(judged.get("code", &"")), "fixture_entry_keys_invalid", field + " code")
	var missing: Dictionary = document.duplicate(true)
	((((missing["run"] as Dictionary)["committed_schedule"] as Dictionary)["entries"] as Array)[0] as Dictionary).erase("state")
	assert_eq(str(_generator.audit_fixture_committed_schedules(missing).get("code", &"")), "fixture_entry_keys_invalid", "a missing key")
	var aggregate_polluted: Dictionary = document.duplicate(true)
	((aggregate_polluted["run"] as Dictionary)["committed_schedule"] as Dictionary)["schedule_view"] = {}
	assert_eq(str(_generator.audit_fixture_committed_schedules(aggregate_polluted).get("code", &"")),
		"fixture_aggregate_keys_invalid", "a widened aggregate")


func test_every_checked_in_snapshot_and_save_fixture_passes_the_structural_audit() -> void:
	if not _ready_generator():
		return
	var paths: Array[String] = []
	for root: String in ["res://tests/fixtures/snapshots", "res://tests/fixtures/saves"]:
		for file: String in DirAccess.get_files_at(root):
			if file.ends_with(".json"):
				paths.append(root.path_join(file))
	assert_gt(paths.size(), 10, "the fixture roots are populated")
	for path: String in paths:
		var parsed: Dictionary = EvidenceValidator.parse_strict_text(FileAccess.get_file_as_string(path))
		assert_true(parsed.get("ok", false), path + " strict-parses")
		if not parsed.get("ok", false):
			continue
		var audited: Dictionary = _generator.audit_fixture_committed_schedules(parsed["value"])
		assert_true(audited.get("ok", false), path + " carries only exact committed entries: " + str(audited.get("code", &"")))


# =================================================================================================
# double entry on the source bindings, against the working tree
# =================================================================================================

func test_every_required_declared_surface_entry_is_present_and_every_retired_symbol_absent() -> void:
	if not _ready_generator():
		return
	var required: Dictionary = _generator.REQUIRED_SURFACE_ENTRIES
	for path: String in required:
		var parsed: Dictionary = _generator.parse_declared_surface(FileAccess.get_file_as_string("res://" + path))
		var entries: Array = (parsed["value"] as Dictionary)["entries"]
		for entry: String in (required[path] as Array):
			assert_true(entries.has(entry), "%s declares %s" % [path, entry])
	var absent: Dictionary = _generator.ABSENT_SURFACE_SYMBOLS
	for path: String in absent:
		var parsed: Dictionary = _generator.parse_declared_surface(FileAccess.get_file_as_string("res://" + path))
		for entry: String in ((parsed["value"] as Dictionary)["entries"] as Array):
			var name: String = entry.substr(entry.rfind(" ") + 1)
			name = name.substr(0, name.find("("))
			assert_false((absent[path] as Array).has(name), "%s must not declare %s" % [path, name])
	# Independent of the generator: DialogicBridge's public finish_current_timeline is gone and the
	# generic runtime-end branch is the only generic completion source.
	var bridge: String = FileAccess.get_file_as_string("res://autoload/DialogicBridge.gd")
	assert_lt(_generator.strip_comments(bridge).find("func finish_current_timeline"), 0, "finish_current_timeline is absent")
	assert_true(bridge.find("func _on_runtime_timeline_ended()") >= 0, "the runtime-end handler owns generic completion")
	assert_true(bridge.find("signal timeline_finished(timeline_id: String, result: Dictionary)") >= 0, "the trusted signal exists")


func test_forbidden_tokens_are_absent_from_executable_plan01_source() -> void:
	if not _ready_generator():
		return
	var forbidden: Dictionary = _generator.FORBIDDEN_SOURCE_TOKENS
	for path: String in forbidden:
		var code: String = _generator.strip_comments(FileAccess.get_file_as_string("res://" + path))
		for token: String in (forbidden[path] as Array):
			assert_lt(code.find(token), 0, "%s must not carry %s in executable text" % [path, token])
	# The comment stripper is doing real work: DayResolutionPlan.gd's header still names the removed
	# execute_schedule_entries stage as documentation.
	var raw: String = FileAccess.get_file_as_string("res://scripts/domain/run/DayResolutionPlan.gd")
	assert_true(raw.find("execute_schedule_entries") >= 0, "the raw file still documents the removed stage")
	assert_lt(_generator.strip_comments(raw).find("execute_schedule_entries"), 0, "and the code does not carry it")


func test_every_matrix_role_literal_is_owned_by_its_producer_and_unrealized_roles_are_absent() -> void:
	if not _ready_generator():
		return
	var realizations: Dictionary = _generator.ROW_REALIZATIONS
	var sources: Dictionary = {}
	for path: String in _generator.SOURCE_PATHS:
		sources[path] = _generator.strip_comments(FileAccess.get_file_as_string("res://" + path))
	for row_id: String in realizations:
		var realization: Dictionary = realizations[row_id]
		var literal: String = "\"%s\"" % str(realization["role"])
		for producer: String in (realization["producers"] as Array):
			assert_true(str(sources[producer]).find(literal) >= 0, "%s carries %s" % [producer, literal])
		if (realization["producers"] as Array).is_empty():
			for path: String in sources:
				assert_lt(str(sources[path]).find(literal), 0,
					"%s is unrealized, so %s must not carry %s" % [row_id, path, literal])


func test_derive_child_census_at_head_attributes_every_call_site_to_a_matrix_producer() -> void:
	if not _ready_generator():
		return
	var head: String = _git_line(PackedStringArray(["rev-parse", "HEAD"])).substr(0, 40)
	assert_eq(head.length(), 40, "HEAD resolves")
	var census: Dictionary = _generator.derive_child_census(head)
	assert_true(census.get("ok", false), "the census runs: " + str(census.get("code", &"")))
	if not census.get("ok", false):
		return
	var value: Dictionary = census["value"]
	# The dwm-oyo.3 slice (2026-08-24, dwm-p2r.21) added a SECOND definition: the frozen Plan-03
	# context seam GameStateDesktopConditionContextPort.derive_child (plan line 854), which DELEGATES
	# to the one production issuer and mints nothing -- proven below by requiring its executable text
	# to route through the issuer's own call. The issuer remains the sole minting definition.
	var definition_paths: Array[String] = []
	for definition_site: Dictionary in (value["definition"] as Array):
		definition_paths.append(str(definition_site["path"]))
	definition_paths.sort()
	assert_eq(definition_paths, [
		"scripts/application/desktop/DesktopIdentityNonceIssuer.gd",
		"scripts/application/desktop/GameStateDesktopConditionContextPort.gd",
	], "derive_child is defined by the minting issuer plus the one delegating Plan-03 context seam")
	var context_seam_code: String = _generator.strip_comments(FileAccess.get_file_as_string(
		"res://scripts/application/desktop/GameStateDesktopConditionContextPort.gd"))
	assert_true(context_seam_code.find("_identity_issuer.call(&\"derive_child\"") >= 0,
		"the context seam delegates every derivation to the retained issuer, never minting itself")
	assert_eq(value["dynamic"], [], "no dynamic derive_child site exists")
	var call_paths: Array[String] = []
	for site: Dictionary in (value["call_sites"] as Array):
		if not call_paths.has(str(site["path"])):
			call_paths.append(str(site["path"]))
	call_paths.sort()
	# GameStateDesktopBoardPort.gd added as a sixth attributed producer: its board-start receipt
	# is derived through the production issuer (bead dwm-p2r.32.4's issuer-derived board_start
	# receipt fix), predating this task's own Phase A/B work but never folded into this census.
	# MinesweeperShopPurchaseParticipant.gd added as a seventh (Plan 02 Task 7, dwm-p2r.32.7): its
	# shop_quote/desktop_action receipts are likewise derived through the production issuer -- this
	# gap predates Task 8 (landed with Task 7's own commit) and was never folded into this census
	# either; found and fixed here rather than left broken, per this file's own established
	# precedent (see the note above for GameStateDesktopBoardPort.gd's identical gap).
	# DesktopBoardFatePort.gd added as an eighth (Plan 02 Task 8, dwm-p2r.32): its board_fate
	# receipt is likewise derived through the production issuer's derive_child() seam.
	# MinesweeperRoundCoordinator.gd (application) added as a ninth (Plan 02 Task 8, dwm-p2r.32):
	# complete_round()'s own desktop_action receipt is likewise derived through the production
	# issuer, matching MinesweeperShopPurchaseParticipant's own identical derivation exactly.
	# DesktopConsequenceCoordinator.gd added as a tenth (Plan 02 Task 8 Review-fix pass,
	# dwm-p2r.32.8, CRITICAL 1): accept_prepared_action()'s own outer receipt_id/receipt_provenance
	# is likewise derived through the production issuer's derive_child() seam, under the newly
	# additive "action_consequence" child_kind.
	# DesktopConditionPolicyPort.gd and GameStateDesktopConditionContextPort.gd added as the
	# eleventh and twelfth (dwm-oyo.3 slice, 2026-08-24, dwm-p2r.21): the policy derives the
	# P03.condition.decision/.destination/.notification rows exclusively THROUGH the context seam,
	# and that seam's own single call is the delegation into the production issuer proven above.
	# ScheduleViewController.gd added as the thirteenth (Amendment Plan 03 Task 3,
	# dwm-oyo.3, recorded deviation authorized by the maintainer): its warning
	# activation and terminal receipts (rows P03.warning.activation/dismissal/
	# navigation) are likewise derived through the production issuer's own seam under
	# the already-registered "warning" and "navigation" child kinds; folded here per
	# this file's own established precedent above.
	assert_eq(call_paths, [
		"scripts/application/desktop/DesktopConditionPolicyPort.gd",
		"scripts/application/desktop/DesktopConsequenceCoordinator.gd",
		"scripts/application/desktop/GameStateDesktopConditionContextPort.gd",
		"scripts/application/minesweeper/DesktopBoardFatePort.gd",
		"scripts/application/minesweeper/GameStateDesktopBoardPort.gd",
		"scripts/application/minesweeper/MinesweeperRoundCoordinator.gd",
		"scripts/application/run/DayResolutionStartPort.gd",
		"scripts/application/run/GameStateDayResolutionPort.gd",
		"scripts/application/schedule/GameStateScheduleCommitPort.gd",
		"scripts/application/schedule/ScheduleViewController.gd",
		"scripts/application/shop/MinesweeperShopPurchaseParticipant.gd",
		"scripts/domain/contact/ContactInvitationState.gd",
		"scripts/domain/schedule/Day7ScheduleProvenance.gd",
	], "exactly the thirteen attributed producers call derive_child")


func test_bootstrap_probe_key_set_and_owner_bindings_are_exact() -> void:
	if not _ready_generator():
		return
	var keys: Dictionary = _generator.parse_probe_keys(FileAccess.get_file_as_string("res://autoload/ApplicationBootstrap.gd"))
	assert_true(keys.get("ok", false), "the probe parses")
	assert_eq((keys["value"] as Dictionary)["keys"], _generator.BOOTSTRAP_PROBE_KEYS, "the frozen probe key set")
	assert_true((_generator.BOOTSTRAP_PROBE_KEYS as Array).has("causal_day_advance_identity_port_instance_id"),
		"the final key set includes the shared allocator")
	for key: String in _generator.BOOTSTRAP_PROBE_KEYS:
		if key.ends_with("_instance_id"):
			assert_true(_generator.BOOTSTRAP_PROBE_OWNERS.has(key), key + " has an owner class")
			assert_true(FileAccess.file_exists("res://" + str(_generator.BOOTSTRAP_PROBE_OWNERS[key])),
				key + " owner class exists")
	var source: String = FileAccess.get_file_as_string("res://autoload/ApplicationBootstrap.gd")
	assert_true(source.find("static func _instance_id(retained: Object) -> int:") >= 0,
		"the probe reports integers, never Objects")


func test_required_surface_manifest_classifies_the_task4_game_state_seams() -> void:
	var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(REQUIRED_SURFACE_PATH))
	assert_true(parsed.get("ok", false), "the manifest strict-parses")
	var by_symbol: Dictionary = {}
	for entry: Variant in ((parsed["value"] as Dictionary).get("symbols", []) as Array):
		var symbol: Dictionary = entry
		if str(symbol.get("availability", "")) == "current":
			by_symbol[str(symbol.get("symbol", ""))] = symbol
	for seam: String in TASK4_SEAMS:
		assert_true(by_symbol.has(seam), seam + " is classified as a current symbol")
		if not by_symbol.has(seam):
			continue
		assert_eq(str((by_symbol[seam] as Dictionary).get("disposition", "")), "retain", seam + " is retained")
		assert_false(str((by_symbol[seam] as Dictionary).get("contract_test", "")).is_empty(), seam + " names a contract test")
	for retired: String in ["validate_date_candidate", "clear_schedule_with_refund", "clear_schedule_without_refund",
			"add_schedule_action", "add_schedule_date_entry", "remove_schedule_entry", "choose_contact_option"]:
		assert_false(by_symbol.has(retired), retired + " is not a current GameState symbol")


func test_committed_entry_key_law_and_state_schema_agree() -> void:
	if not _ready_generator():
		return
	var text: String = FileAccess.get_file_as_string("res://scripts/domain/schedule/ScheduleStateSchema.gd")
	var entry: Dictionary = _generator.parse_string_array_constant(text, "ENTRY_KEYS")
	var keys: Array = ((entry["value"] as Dictionary)["values"] as Array).duplicate()
	keys.sort()
	assert_eq(keys, _generator.COMMITTED_ENTRY_KEYS, "ScheduleStateSchema.ENTRY_KEYS is the frozen ten")
	assert_eq(_generator.COMMITTED_ENTRY_KEYS, ["action_id", "action_kind", "commit_transaction_id", "day",
		"participants", "schedule_entry_id", "schedule_entry_provenance", "slot_index", "source_receipt_id", "state"],
		"the frozen ten committed-entry keys")
	var aggregate: Dictionary = _generator.parse_string_array_constant(text, "AGGREGATE_KEYS")
	var aggregate_keys: Array = ((aggregate["value"] as Dictionary)["values"] as Array).duplicate()
	aggregate_keys.sort()
	assert_eq(aggregate_keys, _generator.COMMITTED_AGGREGATE_KEYS, "the five aggregate keys")
	# dwm-p2r.32 Task 6 delivers exactly the v4 this assertion previously documented as undelivered;
	# the probe now proves the opposite fact for the same reason it existed before.
	assert_eq(int((_generator.parse_int_constant(FileAccess.get_file_as_string("res://scripts/domain/run/RunSnapshotSchema.gd"), "SCHEMA_VERSION")["value"] as Dictionary)["value"]), 4,
		"the subject carries RunSnapshotSchema v4; Plan 02 Task 6 delivered the desktop-durability boundary")


func test_stage_arrays_are_frozen_and_the_ending_residue_is_unreachable() -> void:
	if not _ready_generator():
		return
	var plan_text: String = FileAccess.get_file_as_string("res://scripts/domain/run/DayResolutionPlan.gd")
	var day_1_6: Dictionary = _generator.parse_string_array_constant(plan_text, "DAY_1_6_STAGES")
	var day_7: Dictionary = _generator.parse_string_array_constant(plan_text, "DAY_7_STAGES")
	assert_eq((day_1_6["value"] as Dictionary)["values"], DAY_1_6_STAGES, "the frozen twelve D1-6 stages in order")
	assert_eq((day_7["value"] as Dictionary)["values"], DAY_7_STAGES, "the frozen five D7 stages in order")
	assert_eq(_generator.DAY_1_6_STAGES, DAY_1_6_STAGES, "generator and test agree on D1-6")
	assert_eq(_generator.DAY_7_STAGES, DAY_7_STAGES, "generator and test agree on D7")
	for retired: String in _generator.RETIRED_ENDING_STAGES:
		assert_false(DAY_1_6_STAGES.has(retired) or DAY_7_STAGES.has(retired), retired + " is reachable from no stage array")
	# The residue is real and is sealed as dead, not denied.
	var coordinator: String = _generator.strip_comments(FileAccess.get_file_as_string("res://scripts/application/run/DayResolutionCoordinator.gd"))
	var state_port: String = _generator.strip_comments(FileAccess.get_file_as_string("res://scripts/application/run/GameStateDayResolutionPort.gd"))
	assert_true(coordinator.find("\"resolve_ending_plan\"") >= 0, "the coordinator still declares the retired stage contract")
	assert_true(state_port.find("_default_ending_plan") >= 0 and state_port.find("\"ending.alone\"") >= 0,
		"the state port still carries the dead default-ending fallback")
	assert_eq(DAY_RESOLUTION_PLAN.stage_allowlist(7), DAY_7_STAGES, "the live allowlist for Day 7 is the frozen five")
	assert_eq(DAY_RESOLUTION_PLAN.stage_allowlist(3), DAY_1_6_STAGES, "the live allowlist for Days 1-6 is the frozen twelve")


func test_the_realized_witness_care_entry_format_is_pinned_with_its_plan_drift() -> void:
	if not _ready_generator():
		return
	var text: String = _generator.strip_comments(FileAccess.get_file_as_string("res://scripts/domain/hospital/HospitalRules.gd"))
	assert_true(text.find("\"care.%s.day%d\" % [WITNESS_FRIEND_ID, care_day]") >= 0,
		"HospitalRules builds care.<friend>.day<N>; the plan text says contact.hospital_care.<friend>.day<N>")
	assert_lt(text.find("contact.hospital_care"), 0, "the plan's format is not what production writes")


func test_day_advance_identity_shapes_are_bound_from_source() -> void:
	if not _ready_generator():
		return
	var text: String = FileAccess.get_file_as_string("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
	var request: Dictionary = _generator.parse_string_array_constant(text, "REQUEST_KEYS")
	assert_eq((request["value"] as Dictionary)["values"], ["branch_id", "desktop_timeline_generation", "resolution_kind",
		"run_id", "source_causal_day_instance", "source_causal_day_instance_issuer_receipt", "source_day",
		"source_resolution_receipt"], "the eight request keys")
	var receipt: Dictionary = _generator.parse_string_array_constant(text, "RECEIPT_KEYS")
	var receipt_keys: Array = (receipt["value"] as Dictionary)["values"]
	for key: String in ["allocation_key", "target_causal_day_instance", "target_causal_day_instance_issuer_receipt",
			"counter_start", "counter_end", "disposition", "root_before_fingerprint"]:
		assert_true(receipt_keys.has(key), "receipt carries " + key)
	var kinds: Dictionary = _generator.parse_string_array_constant(text, "ALLOWED_RESOLUTION_KIND")
	assert_eq((kinds["value"] as Dictionary)["values"], ["schedule_done", "condition_hospital"], "both resolution kinds")
	assert_true(_generator.strip_comments(text).find("\"%s:%s\" % [resolution_kind, source_resolution_receipt_id]") >= 0,
		"the allocation key is resolution_kind:source_resolution_receipt_id, so schedule_done keys are schedule_done:<start receipt id>")


# =================================================================================================
# observed vectors over the real substrate
# =================================================================================================

func test_observed_vectors_for_contact_source_solo_empty_done_and_day7_provenance() -> void:
	if not _ready_generator() or not _build_substrate():
		return
	# P01.contact_source.solo over a detached copy of the fresh Contacts owner: read acceptance.
	var detached: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	var action_id: String = "solo:sylvia:day1"
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(detached, "sylvia", 1, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	var command: Dictionary = _command("open.sylvia.day1")
	var record: Dictionary = ((_registry.find_record(action_id))["value"] as Dictionary)["record"]
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(offered["value"]["candidate"], "sylvia", 1,
		command["id"], command["receipt"], _issuer, record)
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return
	var solo_receipt: Dictionary = opened["receipt"]
	_observe("P01.contact_source.solo", solo_receipt["receipt_provenance"], str((command["receipt"] as Dictionary)["receipt_id"]), 0)
	assert_true((solo_receipt["receipt_provenance"]["source_ids"] as Array).has("kind=\"solo_read_acceptance\""),
		"the solo source projects its exact kind")
	# P01.schedule.empty_done: a receipt-backed empty Day-7 commit.
	_game_state._lifecycle_set_playing_day(7)
	var commit: Dictionary = _prepare_commit(7, [])
	if commit.is_empty():
		return
	var receipt: Dictionary = commit["schedule_commit_receipt"]
	var transaction_receipt_id: String = str((receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	_observe("P01.schedule.empty_done", receipt["receipt_provenance"], transaction_receipt_id, 0)
	assert_eq(int(receipt["motivation_charged"]), 0, "empty Done charges nothing")
	assert_true((receipt["receipt_provenance"]["source_ids"] as Array).has("schedule_entry_ids=[]"), "no entry child exists")
	# P01.schedule.day7_provenance through the configured pure service.
	var provenance: RefCounted = DAY7_PROVENANCE.new()
	assert_true(provenance.configure(_registry, _issuer).get("ok", false), "the service configures")
	var handoff: Dictionary = provenance.validate_handoff({
		"transaction_id": str(receipt["transaction_id"]),
		"transaction_issuer_receipt": (receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": (commit["committed_schedule"] as Dictionary).duplicate(true),
		"source_receipt_index": {},
	})
	assert_true(handoff.get("ok", false), "the empty Day-7 handoff validates: " + str(handoff))
	if not handoff.get("ok", false):
		return
	var terminal: Dictionary = (handoff["value"] as Dictionary)["terminal_provenance"]
	assert_eq(str(terminal["cause"]), "empty_done", "cause")
	assert_eq(terminal.get("schedule_entry_id"), null, "no entry for empty_done")
	assert_false(terminal.has("ending_id"), "no ending id is produced by Plan 01")
	_observe("P01.schedule.day7_provenance", terminal["receipt_provenance"], transaction_receipt_id, 0)


func test_observed_vectors_for_the_day3_hospital_walk_with_two_superseded_dates() -> void:
	if not _ready_generator() or not _build_substrate():
		return
	# P01.contact_source.group on Day 2 (the canonical pair window), before the owner moves to Day 3.
	_game_state._lifecycle_set_playing_day(2)
	var group_source: String = _seed_group_source(2)
	if group_source.is_empty():
		return
	var group_receipt: Dictionary = ((_game_state.contacts as Dictionary)["schedule_source_receipts"] as Dictionary)[group_source]
	_observe("P01.contact_source.group", group_receipt["receipt_provenance"],
		str((_command("group.reply.day2")["receipt"] as Dictionary)["receipt_id"]), 0)
	# Day 3: two solo dates (lavinia slot 0, sylvia slot 1) and one ordinary (slot 2), drafted out of order.
	_game_state._lifecycle_set_playing_day(3)
	var drafts: Array = [
		_ordinary("d-rest", 2, "rest", 3),
		_solo_draft("d-syl", 1, "sylvia", 3),
		_solo_draft("d-lav", 0, "lavinia", 3),
	]
	var commit: Dictionary = _prepare_commit(3, drafts)
	if commit.is_empty():
		return
	var committed: Dictionary = commit["committed_schedule"]
	var receipt: Dictionary = commit["schedule_commit_receipt"]
	var transaction_receipt_id: String = str((receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	var entries: Array = committed["entries"]
	assert_eq(entries.size(), 3, "three committed entries")
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		assert_eq(int(entry["slot_index"]), index, "entries are in slot order")
		assert_eq(int((entry["schedule_entry_provenance"] as Dictionary)["ordinal"]), index,
			"the entry ordinal is the zero-based slot-order index, not the draft order or the raw slot")
	_observe("P01.schedule.entry", (entries[0] as Dictionary)["schedule_entry_provenance"], transaction_receipt_id, 0)
	_observe_silently("P01.schedule.entry", (entries[1] as Dictionary)["schedule_entry_provenance"], transaction_receipt_id, 1)
	_observe_silently("P01.schedule.entry", (entries[2] as Dictionary)["schedule_entry_provenance"], transaction_receipt_id, 2)
	_observe("P01.schedule.commit", receipt["receipt_provenance"], transaction_receipt_id, 0)
	assert_eq(int(receipt["motivation_charged"]), 3, "one motivation per committed entry")
	# Begin the resolution through the producer.
	var command: Dictionary = _command("commit.day3")
	var start_signals: Array = []
	_game_state.save_relevant_state_changed.connect(func() -> void: start_signals.append(true))
	assert_true(_state_port.begin_or_resume(str(command["id"]) + ":resolution").get("ok", false), "the walk begins")
	_game_state.pending_hospital = true
	var plan: Dictionary = _active_plan()
	var root: Dictionary = plan["resolution_issuer_receipt"]
	var start: Dictionary = plan["day_resolution_start_receipt"]
	var root_id: String = str(root["receipt_id"])
	_observe("P01.day_resolution.start", start["receipt_provenance"], root_id, 0)
	assert_eq(str(plan["resolution_id"]), str(root["token"]), "the resolution id is the minted root token")
	# Start publication. The producer only PREPARES the start inside begin_or_resume (publication is
	# the consequence coordinator's job, Plan 03), so the first publish here is a genuine first
	# delivery: recorded, then exactly one save_relevant_state_changed. The same bytes replay with no
	# second signal; progressed plan bytes at the same key conflict.
	var signals_before_first: int = start_signals.size()
	var start_publication: Dictionary = {"resolution_plan": plan.duplicate(true), "day_resolution_start_receipt": start.duplicate(true)}
	var first_start: Dictionary = _start_port.publish(start_publication.duplicate(true))
	assert_true(first_start.get("ok", false), "first start publication: " + str(first_start))
	assert_eq((first_start.get("value", {}) as Dictionary).get("published"), true, "frozen success")
	assert_eq(first_start.get("receipt"), start, "the outer receipt is the start receipt")
	assert_eq(start_signals.size() - signals_before_first, 1, "exactly one start signal after the first delivery")
	var replayed: Dictionary = _start_port.publish(start_publication.duplicate(true))
	assert_eq(replayed, first_start, "byte-identical start publication replays the byte-identical success")
	assert_eq(start_signals.size() - signals_before_first, 1, "a replay emits no second start signal")
	# DEVIATION-4 made visible: the top-level stage ids are synthetic, not derived children.
	var hospital_stage_id: String = _top_level_stage_transaction_id(HOSPITAL_STAGE)
	assert_eq(hospital_stage_id, str(plan["resolution_id"]) + ":" + HOSPITAL_STAGE,
		"DEVIATION-4: the stage transaction id is resolution_id:stage_id, so P01.day_resolution.stage is unrealized")
	var request: Dictionary = _await_stage_presentation(HOSPITAL_STAGE)
	if request.is_empty():
		return
	var progressed: Dictionary = _start_port.publish({"resolution_plan": _active_plan(), "day_resolution_start_receipt": start.duplicate(true)})
	assert_false(progressed.get("ok", true), "progressed plan bytes under the same start key conflict")
	assert_eq(str(progressed.get("code", &"")), "day_resolution_start_publication_conflict", "start conflict code")
	_publish_vector("day_resolution_start_port", "day_resolution_start", [true, false], "save_relevant_state_changed", [1, 1],
		"day_resolution_start_publication_conflict")
	assert_eq(str(request["route_id"]), "hospital", "route")
	assert_eq(str(request["timeline_id"]), HOSPITAL_TIMELINE_ID, "registered locator")
	var context: Dictionary = request["context"]
	var condition_id: String = _condition_receipt_id(3)
	# P01.hospital.resolution and P01.hospital.miss, rebuilt from the plan text and required to
	# reproduce the ids the producer embedded in the context and the intent.
	var date_ids: Array[String] = []
	for entry: Variant in entries:
		if str((entry as Dictionary)["action_kind"]) in ["solo", "group"]:
			date_ids.append(str((entry as Dictionary)["schedule_entry_id"]))
	assert_eq(date_ids.size(), 2, "two committed dates in slot order")
	var resolution_tokens: Array = _tokens([
		["role", "hospital.resolution"], ["resolution_id", str(plan["resolution_id"])],
		["causal_day_instance", CAUSAL_DAY], ["source_day", 3],
		["day_resolution_start_receipt_id", str(start["receipt_id"])],
		["schedule_commit_receipt_id", str(plan["schedule_commit_receipt_id"])],
		["condition_receipt_id", condition_id], ["date_schedule_entry_ids", date_ids], ["required", true],
	])
	var resolution: Dictionary = _derive(root_id, &"hospital_resolution", 0, resolution_tokens)
	if resolution.is_empty():
		return
	var misses: Array = []
	for ordinal: int in range(2):
		var date_entry: Dictionary = entries[ordinal]
		var miss_tokens: Array = _tokens([
			["role", "hospital.miss"], ["resolution_id", str(plan["resolution_id"])],
			["causal_day_instance", CAUSAL_DAY], ["source_day", 3],
			["hospital_resolution_id", str(resolution["child_id"])],
			["schedule_entry_id", str(date_entry["schedule_entry_id"])], ["action_id", str(date_entry["action_id"])],
			["source_receipt_id", date_entry["source_receipt_id"]], ["reason", HOSPITAL_RULES.MISS_REASON],
		])
		var miss: Dictionary = _derive(root_id, &"hospital_miss", ordinal, miss_tokens)
		if miss.is_empty():
			return
		misses.append(miss)
	var miss_ids: Array = [str((misses[0] as Dictionary)["child_id"]), str((misses[1] as Dictionary)["child_id"])]
	var sorted_miss_ids: Array = miss_ids.duplicate()
	sorted_miss_ids.sort()
	assert_eq(context["miss_receipt_ids"], sorted_miss_ids,
		"the producer embedded exactly the two plan-text P01.hospital.miss children, at ordinals 0 and 1, sorted")
	assert_eq(context["source_entry_ids"], _sorted_copy(date_ids), "the context names both superseded dates")
	_observe("P01.hospital.resolution", resolution["provenance"], root_id, 0)
	_observe("P01.hospital.miss", (misses[0] as Dictionary)["provenance"], root_id, 0)
	_observe_silently("P01.hospital.miss", (misses[1] as Dictionary)["provenance"], root_id, 1)
	# P01.presentation.intent: rebuilt, and required to equal the substage_id the producer minted.
	var inputs: Array = [condition_id] + miss_ids
	inputs.sort()
	var intent_tokens: Array = _tokens([
		["role", "presentation.intent"], ["resolution_id", str(plan["resolution_id"])],
		["causal_day_instance", CAUSAL_DAY], ["source_day", 3],
		["day_resolution_start_receipt_id", str(start["receipt_id"])], ["stage_name", HOSPITAL_STAGE],
		["stage_index", DAY_RESOLUTION_PLAN.stage_allowlist(3).find(HOSPITAL_STAGE)],
		["presentation_kind", "hospital"], ["schedule_entry_id", null], ["route_id", "hospital"],
		["timeline_id", HOSPITAL_TIMELINE_ID], ["context_sha256", _sha256_value(context)],
		["input_receipt_ids", inputs],
	])
	var intent: Dictionary = _derive(root_id, &"day_resolution_stage", 0, intent_tokens)
	if intent.is_empty():
		return
	assert_eq(str(request["substage_id"]), str(intent["child_id"]),
		"the producer's substage_id is exactly the plan-text P01.presentation.intent child")
	_observe("P01.presentation.intent", intent["provenance"], root_id, 0)
	# P01.presentation.completion: the producer returns its full provenance; it must bind the intent.
	var completion: Dictionary = request["completion_transaction_provenance"]
	assert_eq(str(completion["child_id"]), str(request["completion_transaction_id"]), "completion id")
	assert_true((completion["source_ids"] as Array).has("substage_id=" + _json(str(intent["child_id"]))),
		"the completion projects its intent as substage_id")
	assert_true((completion["source_ids"] as Array).has("stage_id=" + _json(hospital_stage_id)),
		"the completion projects the top-level stage id (synthetic under DEVIATION-4)")
	assert_eq(str(request["stage_id"]), hospital_stage_id, "request stage id")
	_observe("P01.presentation.completion", completion, root_id, 0)
	# Derivation order: the aggregate precedes its misses, which precede the intent, which precedes
	# the completion -- each later child projects the earlier child's id.
	for miss: Dictionary in misses:
		assert_true((miss["provenance"]["source_ids"] as Array).has("hospital_resolution_id=" + _json(str(resolution["child_id"]))), "miss after aggregate")
	assert_true((intent["provenance"]["source_ids"] as Array).has("input_receipt_ids=" + _json(inputs)), "intent after both misses")


func test_observed_publication_vectors_over_the_real_ledger_and_ports() -> void:
	if not _ready_generator() or not _build_substrate():
		return
	_game_state._lifecycle_set_playing_day(4)
	var commit: Dictionary = _prepare_commit(4, [_ordinary("d-train", 0, "training", 4)])
	if commit.is_empty():
		return
	var receipt: Dictionary = commit["schedule_commit_receipt"]
	var publication: Dictionary = {"committed_schedule": (commit["committed_schedule"] as Dictionary).duplicate(true),
		"schedule_commit_receipt": receipt.duplicate(true)}
	# Ledger, schedule_commit kind: first delivery, byte-identical replay, changed bytes conflict.
	var ledger: RefCounted = _fresh_ledger("ledger-vectors")
	var first: Dictionary = ledger.record_before_emit(_ledger_request("schedule_commit", receipt, publication))
	assert_true(first.get("ok", false), str(first))
	assert_eq((first["value"] as Dictionary)["first_delivery"], true, "first delivery")
	var replay: Dictionary = ledger.record_before_emit(_ledger_request("schedule_commit", receipt, publication))
	assert_true(replay.get("ok", false), str(replay))
	assert_eq((replay["value"] as Dictionary)["first_delivery"], false, "byte-identical replay")
	var changed: Dictionary = publication.duplicate(true)
	(changed["committed_schedule"] as Dictionary)["day"] = 5
	var conflict: Dictionary = ledger.record_before_emit(_ledger_request("schedule_commit", receipt, changed))
	assert_eq(str(conflict.get("code", &"")), "publication_record_conflict", "changed bytes at an occupied key conflict")
	assert_eq((ledger.record_before_emit(_ledger_request("schedule_commit", receipt, publication))["value"] as Dictionary)["first_delivery"], false,
		"the conflict rewrote nothing: the original bytes still replay")
	_publish_vector("ledger", "schedule_commit", [true, false], "", [], "publication_record_conflict")
	# Commit port: first publish records then emits exactly one committed_schedule_published; the
	# replay emits none; a ledger already holding different bytes under the same receipt conflicts.
	var emissions: Array = []
	_game_state.committed_schedule_published.connect(func(result: Dictionary) -> void: emissions.append(result))
	var port: RefCounted = commit["port"]
	var published: Dictionary = port.publish(publication.duplicate(true))
	assert_true(published.get("ok", false), "first publish: " + str(published))
	assert_eq((published["value"] as Dictionary)["published"], true, "frozen success")
	assert_eq(published["receipt"], receipt, "the outer receipt is the request's schedule_commit_receipt")
	assert_eq(emissions.size(), 1, "exactly one signal after the first delivery")
	var republished: Dictionary = port.publish(publication.duplicate(true))
	assert_true(republished.get("ok", false), "replay publish")
	assert_eq(republished, published, "the replay returns the byte-identical success")
	assert_eq(emissions.size(), 1, "no second signal on replay")
	var seeded: RefCounted = _fresh_ledger("ledger-seeded-conflict")
	assert_true(seeded.record_before_emit(_ledger_request("schedule_commit", receipt, changed)).get("ok", false), "seed different bytes under the same key")
	var conflicting: Dictionary = _commit_port(seeded).publish(publication.duplicate(true))
	assert_eq(str(conflicting.get("code", &"")), "schedule_publication_conflict", "the port maps the ledger conflict to its own code")
	assert_eq(emissions.size(), 1, "a conflict emits nothing")
	_publish_vector("schedule_commit_port", "schedule_commit", [true, false], "committed_schedule_published", [1, 1],
		"schedule_publication_conflict")
	# Ledger, day_resolution_start kind, over a real start receipt from a real walk.
	var command: Dictionary = _command("commit.day4")
	assert_true(_state_port.begin_or_resume(str(command["id"]) + ":resolution").get("ok", false), "the walk begins")
	var plan: Dictionary = _active_plan()
	var start: Dictionary = plan["day_resolution_start_receipt"]
	var start_publication: Dictionary = {"resolution_plan": plan.duplicate(true), "day_resolution_start_receipt": start.duplicate(true)}
	var start_ledger: RefCounted = _fresh_ledger("ledger-start-vectors")
	assert_eq((start_ledger.record_before_emit(_ledger_request("day_resolution_start", start, start_publication))["value"] as Dictionary)["first_delivery"], true, "start first delivery")
	assert_eq((start_ledger.record_before_emit(_ledger_request("day_resolution_start", start, start_publication))["value"] as Dictionary)["first_delivery"], false, "start replay")
	var start_changed: Dictionary = start_publication.duplicate(true)
	(start_changed["resolution_plan"] as Dictionary)["source_day"] = 5
	assert_eq(str(start_ledger.record_before_emit(_ledger_request("day_resolution_start", start, start_changed)).get("code", &"")),
		"publication_record_conflict", "start changed bytes conflict")
	_publish_vector("ledger", "day_resolution_start", [true, false], "", [], "publication_record_conflict")


func test_observed_day7_scheduled_solo_handoff() -> void:
	if not _ready_generator() or not _build_substrate():
		return
	_game_state._lifecycle_set_playing_day(7)
	var commit: Dictionary = _prepare_commit(7, [_solo_draft("d-syl7", 0, "sylvia", 7)])
	if commit.is_empty():
		return
	var receipt: Dictionary = commit["schedule_commit_receipt"]
	var provenance: RefCounted = DAY7_PROVENANCE.new()
	assert_true(provenance.configure(_registry, _issuer).get("ok", false), "the service configures")
	var handoff: Dictionary = provenance.validate_handoff({
		"transaction_id": str(receipt["transaction_id"]),
		"transaction_issuer_receipt": (receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": (commit["committed_schedule"] as Dictionary).duplicate(true),
		"source_receipt_index": ((_game_state.contacts as Dictionary)["schedule_source_receipts"] as Dictionary).duplicate(true),
	})
	assert_true(handoff.get("ok", false), "the scheduled-solo Day-7 handoff validates: " + str(handoff))
	if not handoff.get("ok", false):
		return
	var terminal: Dictionary = (handoff["value"] as Dictionary)["terminal_provenance"]
	assert_eq(str(terminal["cause"]), "scheduled_solo", "cause")
	assert_eq(str(terminal["action_id"]), "solo:sylvia:day7", "the one eligible solo")
	assert_eq(str(terminal["schedule_entry_id"]), str(((commit["committed_schedule"] as Dictionary)["entries"] as Array)[0]["schedule_entry_id"]), "its entry")
	for forbidden: String in ["ending_id", "friend_id", "tier", "dark_mode", "presentation_form"]:
		assert_false(terminal.has(forbidden), "no " + forbidden)
	_observe_silently("P01.schedule.day7_provenance", terminal["receipt_provenance"],
		str((receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"]), 0)

func test_every_observed_provenance_is_refused_by_the_issuer_when_any_member_is_mutated() -> void:
	if not _ready_generator() or not _build_substrate():
		return
	_game_state._lifecycle_set_playing_day(3)
	var drafts: Array = [_ordinary("d-rest", 2, "rest", 3), _ordinary("d-work", 0, "working", 3)]
	var commit: Dictionary = _prepare_commit(3, drafts)
	if commit.is_empty():
		return
	var receipt: Dictionary = commit["schedule_commit_receipt"]
	var provenances: Array = [
		((commit["committed_schedule"] as Dictionary)["entries"] as Array)[0]["schedule_entry_provenance"],
		((commit["committed_schedule"] as Dictionary)["entries"] as Array)[1]["schedule_entry_provenance"],
		receipt["receipt_provenance"],
	]
	var kinds: Array = [&"schedule_entry", &"schedule_entry", &"schedule_commit"]
	for index: int in range(provenances.size()):
		var provenance: Dictionary = provenances[index]
		var kind: StringName = kinds[index]
		assert_true(_issuer.validate_child(provenance, kind).get("ok", false), "the honest child validates")
		var mutations: Array = []
		var parent_changed: Dictionary = provenance.duplicate(true)
		parent_changed["parent_receipt_id"] = str(provenance["parent_receipt_id"]) + "x"
		mutations.append(["parent", parent_changed, kind])
		var ordinal_changed: Dictionary = provenance.duplicate(true)
		ordinal_changed["ordinal"] = int(provenance["ordinal"]) + 1
		mutations.append(["ordinal", ordinal_changed, kind])
		var kind_changed: Dictionary = provenance.duplicate(true)
		kind_changed["child_kind"] = "empty_schedule_done"
		mutations.append(["kind", kind_changed, &"empty_schedule_done"])
		var sources: Array = provenance["source_ids"]
		var reversed: Dictionary = provenance.duplicate(true)
		reversed["source_ids"] = sources.duplicate()
		(reversed["source_ids"] as Array).reverse()
		mutations.append(["reversed token order", reversed, kind])
		var swapped: Dictionary = provenance.duplicate(true)
		swapped["source_ids"] = sources.duplicate()
		var first: Variant = (swapped["source_ids"] as Array)[0]
		(swapped["source_ids"] as Array)[0] = (swapped["source_ids"] as Array)[1]
		(swapped["source_ids"] as Array)[1] = first
		mutations.append(["two tokens swapped", swapped, kind])
		var extra: Dictionary = provenance.duplicate(true)
		extra["source_ids"] = sources.duplicate()
		(extra["source_ids"] as Array).append("zzz_extra=\"x\"")
		mutations.append(["extra token", extra, kind])
		for token_index: int in range(sources.size()):
			var removed: Dictionary = provenance.duplicate(true)
			removed["source_ids"] = sources.duplicate()
			(removed["source_ids"] as Array).remove_at(token_index)
			mutations.append(["token %d removed" % token_index, removed, kind])
			var edited: Dictionary = provenance.duplicate(true)
			edited["source_ids"] = sources.duplicate()
			(edited["source_ids"] as Array)[token_index] = str(sources[token_index]) + "~"
			mutations.append(["token %d value changed" % token_index, edited, kind])
		var blank: Dictionary = provenance.duplicate(true)
		blank["child_id"] = ""
		mutations.append(["blank child id", blank, kind])
		for mutation: Array in mutations:
			var judged: Dictionary = _issuer.validate_child(mutation[1] as Dictionary, mutation[2] as StringName)
			assert_false(judged.get("ok", true), "provenance %d: %s must be refused" % [index, str(mutation[0])])
	# A neighbouring row substituted for the honest one: an entry child presented as the aggregate.
	var entry_as_commit: Dictionary = (provenances[0] as Dictionary).duplicate(true)
	assert_false(_issuer.validate_child(entry_as_commit, &"schedule_commit").get("ok", true),
		"a P01.schedule.entry child cannot pass as P01.schedule.commit")


func test_unrealized_rows_are_pinned_to_their_recorded_deviations() -> void:
	if not _ready_generator():
		return
	# The realized witness is HospitalRules' twelve-member fact record, not a derived child.
	var planned: Dictionary = HOSPITAL_RULES.plan_resolution({"required": true, "source_day": 3, "committed_entries": [
		{"schedule_entry_id": "sylvia-entry", "schedule_entry_provenance": {}, "day": 3, "slot_index": 0,
			"action_id": "solo:sylvia:day3", "action_kind": "solo", "participants": ["sylvia"],
			"source_receipt_id": "contact_source.abc", "commit_transaction_id": "t", "state": "committed"},
	]})
	assert_true(planned.get("ok", false), str(planned))
	if not planned.get("ok", false):
		return
	var witness: Variant = (planned["value"] as Dictionary)["witness"]
	assert_eq(typeof(witness), TYPE_DICTIONARY, "a superseded accepted Sylvia solo yields a witness")
	var witness_keys: Array = (witness as Dictionary).keys()
	witness_keys.sort()
	assert_eq(witness_keys, REALIZED_WITNESS_KEYS, "the realized witness shape carries no receipt_id or receipt_provenance")
	assert_eq(str((witness as Dictionary)["resolution_kind"]), "schedule_done", "resolution kind")
	assert_eq(int((witness as Dictionary)["care_followup_day"]), 4, "care follows the next day")
	assert_false((witness as Dictionary).has("applied"), "no applied flag")
	# The realization map records both deviations, and the stage row's role literal is nowhere.
	var realizations: Dictionary = _generator.ROW_REALIZATIONS
	assert_true(str((realizations["P01.day_resolution.stage"] as Dictionary)["deviation"]).find("DEVIATION-4") >= 0, "stage row cites DEVIATION-4")
	assert_true(str((realizations["P01.hospital.sylvia_witness"] as Dictionary)["deviation"]).find("dwm-p2r.14") >= 0, "witness row cites its bead")


# =================================================================================================
# the immutable record, once it exists
# =================================================================================================

func test_record_is_absent_before_generation_or_valid_canonical_and_source_bound_afterwards() -> void:
	if not _ready_generator():
		return
	if _record.is_empty():
		assert_false(FileAccess.file_exists(RECORD_PATH), "before generation the record does not exist")
		assert_eq(_git_line(PackedStringArray(["ls-files", "--", RECORD_RELATIVE])), "", "and is untracked")
		return
	var validated: Dictionary = _generator.validate_record(_record)
	assert_true(validated.get("ok", false), "the record validates: %s %s" % [str(validated.get("code", &"")), str(validated.get("message", ""))])
	var canonical: Dictionary = _generator.canonical_bytes(_record)
	assert_eq((canonical["value"] as Dictionary)["bytes"], _record_bytes, "the stored bytes are canonical JSON plus one LF")
	var subject: String = str(_record["subject_commit"])
	assert_eq(_git_line(PackedStringArray(["show", "-s", "--format=%s", subject])), SUBJECT, "the subject commit carries the frozen subject")
	assert_true(_git_ok(PackedStringArray(["merge-base", "--is-ancestor", subject, "HEAD"])), "the subject commit is an ancestor")
	for binding: Dictionary in (_record["source_bindings"] as Array):
		var blob: PackedByteArray = _git_blob(subject, str(binding["path"]))
		assert_eq(_sha256_bytes(blob), str(binding["sha256"]), str(binding["path"]) + " digest matches the subject tree")
		var surface: Dictionary = _generator.parse_declared_surface(blob.get_string_from_utf8())
		assert_eq(str((surface["value"] as Dictionary)["sha256"]), str(binding["declared_surface_sha256"]), str(binding["path"]) + " surface digest")
	var plan_blob: PackedByteArray = _git_blob(subject, _generator.PLAN_PATH)
	assert_eq(_sha256_bytes(plan_blob), str(_record["plan_sha256"]), "plan digest")
	var matrix: Dictionary = _generator.extract_matrix_blob(plan_blob)
	assert_eq(str((matrix["value"] as Dictionary)["sha256"]), str(_record["plan01_child_derivation_matrix_sha256"]), "matrix digest")
	assert_eq(_sha256_bytes(_git_blob(subject, str((_record["v3_boundary"] as Dictionary)["record_path"]))),
		str((_record["v3_boundary"] as Dictionary)["record_sha256"]), "v3 boundary record digest")
	assert_eq(str((_record["v3_boundary"] as Dictionary)["boundary_commit"]),
		str((StrictJson.parse_object(FileAccess.get_file_as_string(V3_BOUNDARY_PATH))["value"] as Dictionary)["boundary_commit"]),
		"the recorded .13 boundary commit")
	for command: Dictionary in (_record["commands"] as Array):
		var log_path: String = "res://" + str(command["log_path"])
		assert_true(str(command["log_path"]).begins_with("evidence/phase_2r/logs/"), "bound logs live in tracked evidence, never under .godot/")
		assert_true(FileAccess.file_exists(log_path), log_path + " exists")
		if FileAccess.file_exists(log_path):
			assert_eq(_sha256_bytes(FileAccess.get_file_as_bytes(log_path)), str(command["log_sha256"]), log_path + " digest")
	# Every other digest re-derived from the subject tree by this file's own git reader.
	var registry_record: Dictionary = _record["registry"]
	assert_eq(_sha256_bytes(_git_blob(subject, str(registry_record["manifest_path"]))), str(registry_record["manifest_sha256"]), "registry manifest digest")
	assert_eq(_sha256_bytes(_git_blob(subject, str(registry_record["schema_path"]))), str(registry_record["schema_sha256"]), "registry schema digest")
	var ledger_record: Dictionary = _record["publication_ledger"]
	assert_eq(_sha256_bytes(_git_blob(subject, str(ledger_record["schema_path"]))), str(ledger_record["schema_sha256"]), "ledger schema digest")
	var required_record: Dictionary = _record["required_surface"]
	assert_eq(_sha256_bytes(_git_blob(subject, str(required_record["path"]))), str(required_record["sha256"]), "required-surface digest")
	for fixture: Dictionary in (_record["fixtures"] as Array):
		assert_eq(_sha256_bytes(_git_blob(subject, str(fixture["path"]))), str(fixture["sha256"]), str(fixture["path"]) + " digest")
	var surface_record: Dictionary = _record["generated_surface"]
	assert_true(FileAccess.file_exists(SURFACE_PATH), "the co-generated surface exists")
	assert_eq(_sha256_bytes(FileAccess.get_file_as_bytes(SURFACE_PATH)), str(surface_record["sha256"]), "the co-generated surface is cross-bound")
	assert_eq((_record["observed_vectors"] as Array).size(), 11, "eleven realized rows carry an observed vector")
	assert_eq((_record["observed_publications"] as Array).size(), 4, "four publication vectors")
	var live_registry: Dictionary = REGISTRY.load_current()
	assert_eq(str((_record["registry"] as Dictionary)["registry_fingerprint"]),
		str((live_registry["value"] as Dictionary)["registry_fingerprint"]),
		"the recorded registry fingerprint is the one the production loader computes from the same manifest")
	assert_eq((_record["requirement_ids"] as Array).size(), 6, "six requirement ids")
	var record_json: String = _record_bytes.get_string_from_utf8()
	# Member-level claims only: the sealed retired stage name resolve_ending_plan legitimately appears
	# inside day_resolution_stages.retired_ending_stages, which is the opposite of a claim.
	for forbidden: String in ["schedule_view", "req.test.schedule_gate\"", "\"terminal_intent\":", "\"ending_plan\":",
			"\"ending_id\":", "\"playback", "snapshot_provider_instance_id"]:
		assert_lt(record_json.find(forbidden), 0, "the record never claims " + forbidden)


func test_the_law_rejects_every_record_tamper_with_its_own_code() -> void:
	if not _ready_generator() or _record.is_empty():
		return
	var tampers: Array = [
		["extra member", _with(_record, ["extra"], 1), "record_member_set_invalid"],
		["missing member", _without(_record, "commands"), "record_member_set_invalid"],
		["subject commit shape", _with(_record, ["subject_commit"], "abc"), "record_commit_invalid"],
		["overlong subject commit", _with(_record, ["subject_commit"], str(_record["subject_commit"]) + "a"), "record_commit_invalid"],
		["uppercase plan digest", _with(_record, ["plan_sha256"], str(_record["plan_sha256"]).to_upper()), "record_digest_invalid"],
		["uppercase source digest", _with(_record, ["source_bindings", 0, "sha256"], ZERO_DIGEST.to_upper().replace("0", "A")), "record_digest_invalid"],
		["bound source path renamed", _with(_record, ["source_bindings", 0, "path"], "autoload/Other.gd"), "record_source_paths_invalid"],
		["row deleted", _without_row(), "record_matrix_row_count"],
		["derivation order swapped", _swap_order(), "record_matrix_order_invalid"],
		["row renamed (caught first by the order check)", _with(_record, ["derivation_matrix", "rows", 2, "row_id"], "P01.schedule.entry_v2"), "record_matrix_order_invalid"],
		["row producers widened", _with(_record, ["derivation_matrix", "rows", 2, "producers"], ["scripts/application/schedule/GameStateScheduleCommitPort.gd", "autoload/GameState.gd"]), "record_matrix_producers_invalid"],
		["completion validators dropped", _with(_record, ["derivation_matrix", "rows", 12, "validators"], []), "record_matrix_producers_invalid"],
		["row realization flipped", _with(_record, ["derivation_matrix", "rows", 7, "realization"], "realized"), "record_matrix_realization_invalid"],
		["row role changed", _with(_record, ["derivation_matrix", "rows", 2, "role"], "schedule.commit"), "record_matrix_role_invalid"],
		["role path removed", _with(_record, ["derivation_matrix", "rows", 2, "source_paths"], ["day"]), "record_matrix_role_path_missing"],
		["vector removed", _without_vector(), "record_vectors_incomplete"],
		["vector for an unrealized row", _vector_for_unrealized(), "record_vectors_incomplete"],
		["vector kind changed", _with(_record, ["observed_vectors", 0, "child_kind"], "hospital_miss"), "record_vector_kind_invalid"],
		["vector path drift", _vector_path_drift(), "record_vector_paths_invalid"],
		["vector token order", _vector_token_reversed(), "record_vector_order_invalid"],
		["vector negative ordinal", _with(_record, ["observed_vectors", 0, "ordinal"], -1), "record_vector_ordinal_invalid"],
		["fixed-ordinal row observed at 1", _with(_record, ["observed_vectors", 3, "ordinal"], 1), "record_vector_ordinal_invalid"],
		["sibling parent drift", _with(_record, ["observed_vectors", 7, "parent_receipt_id"], "issuer_receipt.other"), "record_vector_parent_invalid"],
		["dynamic census site", _with(_record, ["derive_child_census", "dynamic"], [{"path": "x.gd", "line": 1}]), "record_census_dynamic_call_site"],
		["derive_child definition count not one", _with(_record, ["derive_child_census", "definition"], []), "record_census_definition_count"],
		["unattributed wrapper", _with(_record, ["derive_child_census", "wrappers"], [{"path": "autoload/SceneRouter.gd", "line": 1}]), "record_census_unattributed_call_site"],
		["unattributed call site", _with(_record, ["derive_child_census", "call_sites"], [{"path": "autoload/GameState.gd", "line": 1}]), "record_census_unattributed_call_site"],
		["green command failing", _with(_record, ["commands", 1, "failing"], 1), "record_command_not_green"],
		["green command suite not executed", _with(_record, ["commands", 1, "executed_suites"], []), "record_command_suite_not_executed"],
		["green command load failure", _with(_record, ["commands", 1, "load_failures"], 1), "record_command_not_green"],
		["red command that passed", _red_passing(), "record_command_not_red"],
		["red by load failure", _red_by_load_failure(), "record_command_not_red"],
		["command suites drift", _with(_record, ["commands", 1, "suites"], ["res://tests/unit/other.gd"]), "record_command_binding_invalid"],
		["command log outside tracked evidence", _with(_record, ["commands", 1, "log_path"], ".godot/phase2r_logs/p2r15-schedule-gate-green.log"), "record_command_binding_invalid"],
		["publication vector missing", _without_publication(), "record_publications_incomplete"],
		["publication replay claimed as first", _with(_record, ["observed_publications", 2, "first_delivery_sequence"], [true, true]), "record_publication_invalid"],
		["publication second signal", _with(_record, ["observed_publications", 2, "signal_counts"], [1, 2]), "record_publication_invalid"],
		["publication conflict code", _with(_record, ["observed_publications", 0, "conflict_code"], "ok"), "record_publication_invalid"],
		["stage array drift", _with(_record, ["day_resolution_stages", "day_7"], DAY_7_STAGES + ["resolve_ending_plan"]), "record_stage_arrays_invalid"],
		["stage array reordered", _with(_record, ["day_resolution_stages", "day_1_6"], ["validate_schedule", "lock_day"] + DAY_1_6_STAGES.slice(2)), "record_stage_arrays_invalid"],
		["exclusions drift", _with(_record, ["exclusions"], ["new product behavior"]), "record_exclusions_invalid"],
		["log digest uppercase", _with(_record, ["commands", 0, "log_sha256"], str(((_record["commands"] as Array)[0] as Dictionary)["log_sha256"]).to_upper()), "record_digest_invalid"],
		["registry fingerprint uppercase", _with(_record, ["registry", "registry_fingerprint"], str((_record["registry"] as Dictionary)["registry_fingerprint"]).to_upper()), "record_digest_invalid"],
		["registry manifest digest overlong", _with(_record, ["registry", "manifest_sha256"], str((_record["registry"] as Dictionary)["manifest_sha256"]) + "a"), "record_digest_invalid"],
		["ledger schema digest uppercase", _with(_record, ["publication_ledger", "schema_sha256"], str((_record["publication_ledger"] as Dictionary)["schema_sha256"]).to_upper()), "record_digest_invalid"],
		["v3 record digest uppercase", _with(_record, ["v3_boundary", "record_sha256"], str((_record["v3_boundary"] as Dictionary)["record_sha256"]).to_upper()), "record_digest_invalid"],
		["required-surface digest uppercase", _with(_record, ["required_surface", "sha256"], str((_record["required_surface"] as Dictionary)["sha256"]).to_upper()), "record_digest_invalid"],
		["generated-surface digest uppercase", _with(_record, ["generated_surface", "sha256"], str((_record["generated_surface"] as Dictionary)["sha256"]).to_upper()), "record_digest_invalid"],
		["fixture digest uppercase", _with(_record, ["fixtures", 0, "sha256"], str(((_record["fixtures"] as Array)[0] as Dictionary)["sha256"]).to_upper()), "record_digest_invalid"],
		["v3 boundary commit shape", _with(_record, ["v3_boundary", "boundary_commit"], "3ae8ca1ba"), "record_commit_invalid"],
		["v3 version regressed", _with(_record, ["v3_boundary", "run_snapshot_schema_version"], 2), "record_v3_versions_invalid"],
		["current version regressed", _with(_record, ["current_versions", "save_document_version"], 2), "record_current_versions_invalid"],
		["committed_schedule not preserved", _with(_record, ["current_versions", "committed_schedule_keys_preserved"], false), "record_committed_schedule_not_preserved"],
		["probe key dropped", _without_probe_key(), "record_probe_keys_invalid"],
		["probe owner missing", _without_owner_class(), "record_probe_owner_missing"],
		["caller-owned entry field", _with(_record, ["schedule_state_schema", "entry_keys"], Array(_generator.COMMITTED_ENTRY_KEYS) + ["route_id"]), "record_entry_keys_caller_owned"],
		["entry key missing", _with(_record, ["schedule_state_schema", "entry_keys"], Array(_generator.COMMITTED_ENTRY_KEYS).slice(1)), "record_entry_keys_invalid"],
	]
	for tamper: Array in tampers:
		var judged: Dictionary = _generator.validate_record_law(tamper[1] as Dictionary)
		assert_false(judged.get("ok", true), str(tamper[0]) + " must be rejected by the law")
		assert_eq(str(judged.get("code", &"")), str(tamper[2]), str(tamper[0]) + " rejection code")


func test_the_schema_rejects_every_frozen_member_tamper_on_its_own() -> void:
	if not _ready_generator() or _record.is_empty():
		return
	var tampers: Array = [
		["schema version", ["schema_version"], 2],
		["evidence id", ["evidence_id"], "other"],
		["owner", ["owner_beads_id"], "dwm-p2r.7"],
		["subject", ["subject_commit_subject"], "test(schedule): something else"],
		["plan path", ["plan_path"], "docs/other.md"],
		["requirement id blank", ["requirement_ids"], [""]],
		["requirement ids duplicated", ["requirement_ids"], ["req.a", "req.a"]],
		["row count", ["derivation_matrix", "row_count"], 12],
		["row realization enum", ["derivation_matrix", "rows", 0, "realization"], "maybe"],
		["registry record count", ["registry", "record_count"], 19],
		["registry version", ["registry", "registry_version"], 2],
		["ledger fixed path", ["publication_ledger", "fixed_path"], "other.json"],
		["ledger conflict code", ["publication_ledger", "conflict_codes", "ledger"], "other"],
		["schedule conflict code", ["publication_ledger", "conflict_codes", "schedule_commit"], "other"],
		["start conflict code", ["publication_ledger", "conflict_codes", "day_resolution_start"], "other"],
		["first delivery field", ["publication_ledger", "first_delivery_field"], "delivered"],
		["day advance key format", ["day_advance_identity", "allocation_key_format"], "source_day"],
		["raw causal day issue", ["day_advance_identity", "raw_causal_day_issue_in_plan01"], true],
		["hospital readiness", ["bootstrap_probe", "readiness", "hospital_presentation_ready"], false],
		["dating readiness", ["bootstrap_probe", "readiness", "dating_presentation_ready"], true],
		["producer readiness", ["bootstrap_probe", "readiness", "presentation_producer_ready"], true],
		["instance ids serialized", ["bootstrap_probe", "instance_ids_serialized"], true],
		["v3 owner", ["v3_boundary", "owner_beads_id"], "dwm-p2r.9"],
		["v3 subject", ["v3_boundary", "boundary_subject"], "feat(save): other"],
		["v3 sources not revalidated", ["v3_boundary", "sources_revalidated_at_boundary"], false],
		["migration code", ["v3_boundary", "migration_rejection_code"], "other"],
		["strict branch", ["strict_branch", "branch"], "main"],
		["strict disposition", ["strict_branch", "disposition"], "merged"],
		["witness kind", ["sylvia_witness", "kind"], "other"],
		["witness resolution kind", ["sylvia_witness", "resolution_kind"], "condition_hospital"],
		["witness affection", ["sylvia_witness", "consequence", "affection_delta"], 3],
		["witness dark", ["sylvia_witness", "consequence", "dark_delta"], 0],
		["witness attitude", ["sylvia_witness", "consequence", "attitude"], "calm"],
		["witness tier", ["sylvia_witness", "consequence", "tier_transition"], "none"],
		["witness application owner", ["sylvia_witness", "application_owner"], "dwm-oyo.3"],
		["witness applied flag", ["sylvia_witness", "applied_flag_present"], true],
		["witness issuer anchored", ["sylvia_witness", "issuer_anchored"], true],
		["day7 kind", ["day7_provenance", "child_kind"], "other"],
		["day7 day", ["day7_provenance", "day"], 8],
		["day7 terminal owner", ["day7_provenance", "terminal_intent_owner"], "dwm-p2r.15"],
		["day7 final plan owner", ["day7_provenance", "final_plan_owner"], "dwm-oyo.3"],
		["day7 ending plan in plan01", ["day7_provenance", "ending_plan_in_plan01_composition"], true],
		["dating owner", ["dating_presentation", "production_owner"], "dwm-p2r.15"],
		["dating ready", ["dating_presentation", "ready_in_phase_2r"], true],
		["dating code", ["dating_presentation", "unconfigured_code"], "other"],
		["required surface path", ["required_surface", "path"], "other.json"],
		["command expect enum", ["commands", 0, "expect"], "amber"],
		["command extra member", ["commands", 0, "extra"], 1],
		["chain status enum", ["beads_chain", 0, "status"], "done"],
		["witness care format", ["sylvia_witness", "care_followup_entry_id_format"], "contact.hospital_care.sylvia.day<source_day+1>"],
		["witness plan care format", ["sylvia_witness", "plan_care_followup_entry_id_format"], "care.sylvia.day<source_day+1>"],
		["ending stages reachable", ["day_resolution_stages", "ending_stages_reachable"], true],
		["stage plan path", ["day_resolution_stages", "path"], "scripts/domain/run/Other.gd"],
		["generated surface path", ["generated_surface", "path"], "evidence/other.json"],
		["probe owner class swapped", ["bootstrap_probe", "owner_classes", "issuer_instance_id"], "tests/support/FakeDesktopIssuerRootStore.gd"],
		["probe owner key unknown", ["bootstrap_probe", "owner_classes", "snapshot_provider_instance_id"], "autoload/GameState.gd"],
		["publication owner enum", ["observed_publications", 0, "owner"], "scene"],
		["publication kind enum", ["observed_publications", 0, "kind"], "schedule_view"],
		["row validators not strings", ["derivation_matrix", "rows", 12, "validators"], [1]],
	]
	for tamper: Array in tampers:
		var judged: Dictionary = _generator.validate_record_schema(_with(_record, tamper[1] as Array, tamper[2]))
		assert_false(judged.get("ok", true), str(tamper[0]) + " must be rejected by the schema")
		assert_eq(str(judged.get("code", &"")), "record_schema_rejected", str(tamper[0]) + " schema code")


func test_only_the_law_sees_digest_case_commit_length_and_vector_paths() -> void:
	if not _ready_generator() or _record.is_empty():
		return
	var uppercase: Dictionary = _with(_record, ["plan_sha256"], str(_record["plan_sha256"]).to_upper())
	assert_true(_generator.validate_record_schema(uppercase).get("ok", false), "the schema cannot see digest case")
	assert_eq(str(_generator.validate_record_law(uppercase).get("code", &"")), "record_digest_invalid", "the law can")
	var overlong: Dictionary = _with(_record, ["subject_commit"], str(_record["subject_commit"]) + "a")
	assert_true(_generator.validate_record_schema(overlong).get("ok", false), "minLength is a floor, so the schema accepts an overlong commit")
	assert_eq(str(_generator.validate_record_law(overlong).get("code", &"")), "record_commit_invalid", "the law rejects it")
	var drifted: Dictionary = _vector_path_drift()
	assert_true(_generator.validate_record_schema(drifted).get("ok", false), "the schema sees only strings in source_ids")
	assert_eq(str(_generator.validate_record_law(drifted).get("code", &"")), "record_vector_paths_invalid", "the law binds each vector to its row")


func test_the_record_binds_the_recorded_beads_chain_and_exclusions() -> void:
	if not _ready_generator() or _record.is_empty():
		return
	var ids: Array[String] = []
	var statuses: Dictionary = {}
	for entry: Dictionary in (_record["beads_chain"] as Array):
		ids.append(str(entry["id"]))
		statuses[str(entry["id"])] = str(entry["status"])
	assert_eq(ids, _generator.BEADS_CHAIN, "the chain in plan order")
	for id: String in ["dwm-p2r.12", "dwm-wks", "dwm-p2r.16", "dwm-p2r.13", "dwm-p2r.9", "dwm-p2r.14", "dwm-p2r.18"]:
		assert_eq(str(statuses[id]), "closed", id + " closed before the seal")
	assert_ne(str(statuses["dwm-p2r.7"]), "closed", ".7 is judged separately and never closed from this plan")
	assert_ne(str(statuses["dwm-p2r.15"]), "closed", ".15 was open when its evidence was generated")
	assert_eq(_record["requirement_ids"], _generator.REQUIREMENT_IDS, "the six requirement ids")
	assert_eq(_record["exclusions"], _generator.EXCLUSIONS, "the exact frozen exclusion set")
	assert_eq(_generator.EXCLUSIONS, ["ScheduleView warnings or final Done composition", "final ending selection or playback",
		"new product behavior", "waived diagnostics", "unverified migration"], "ScheduleView, final ending, new behavior, waived diagnostics and unverified migration are excluded")


# =================================================================================================
# substrate helpers
# =================================================================================================

func _build_substrate() -> bool:
	_commands = {}
	_root_counter += 1
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required; run through Invoke-IsolatedGodot.ps1")
	if wrapper.strip_edges().is_empty():
		return false
	_root = wrapper.path_join("schedule-gate-%d" % _root_counter)
	assert_eq(DirAccess.make_dir_recursive_absolute(_root), OK)
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))
	var storage: JsonFileStorage = JsonFileStorage.new(_root)
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(storage, NAMESPACE_SOURCE.new(VECTOR_NAMESPACE)).get("ok", false), "root store configures over the fixed namespace")
	assert_true(store.load_or_create().get("ok", false), "root store initializes")
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(store).get("ok", false), "issuer configures")
	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()
	_ledger = LEDGER.new()
	assert_true(_ledger.configure(storage).get("ok", false))
	assert_true(_ledger.load().get("ok", false))
	_state_port = STATE_PORT.new(_game_state)
	_consequence = CONSEQUENCE_SOURCE.new()
	assert_true(_consequence.configure(_issuer).get("ok", false))
	assert_true(_state_port.configure_desktop_consequence_source(_consequence).get("ok", false))
	_start_port = START_PORT.new(_state_port, _registry, _issuer, _ledger)
	assert_true(_state_port.configure_resolution_identity(_issuer, _start_port).get("ok", false))
	return true


func _prepare_commit(day: int, drafts: Array) -> Dictionary:
	var port: RefCounted = _commit_port(_ledger)
	var command: Dictionary = _command("commit.day%d" % day)
	var prepared: Dictionary = port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return {}
	var value: Dictionary = (prepared["value"] as Dictionary).duplicate(true)
	assert_true(port.call(&"commit", value["game_state_candidate"]).get("ok", false), "the candidate commits")
	value["port"] = port
	return value


func _commit_port(ledger: RefCounted) -> RefCounted:
	return COMMIT_PORT.new(_game_state, _registry, _issuer, ledger)


func _fresh_ledger(label: String) -> RefCounted:
	var root: String = _root.path_join(label)
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(JsonFileStorage.new(root)).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	return ledger


func _solo_draft(draft_entry_id: String, slot_index: int, friend: String, day: int) -> Dictionary:
	var action_id: String = "solo:%s:day%d" % [friend, day]
	return {"draft_entry_id": draft_entry_id, "day": day, "slot_index": slot_index, "action_id": action_id,
		"action_kind": "solo", "participants": [friend], "source_receipt_id": _seed_solo_source(friend, day, action_id)}


func _seed_solo_source(friend_id: String, day: int, action_id: String) -> String:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(_game_state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return ""
	var command: Dictionary = _command("open.%s.day%d" % [friend_id, day])
	var record: Dictionary = ((_registry.find_record(action_id))["value"] as Dictionary)["record"]
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(offered["value"]["candidate"], friend_id, day,
		command["id"], command["receipt"], _issuer, record)
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	_game_state.contacts = opened["value"]["candidate"]
	return str((opened["receipt"] as Dictionary)["receipt_id"])


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day: int) -> Dictionary:
	return {"draft_entry_id": draft_entry_id, "day": day, "slot_index": slot_index, "action_id": action_id,
		"action_kind": "ordinary", "participants": [], "source_receipt_id": null}


func _group_draft(draft_entry_id: String, slot_index: int, day: int, source_receipt_id: String) -> Dictionary:
	return {"draft_entry_id": draft_entry_id, "day": day, "slot_index": slot_index,
		"action_id": "group:priscilla_lavinia:day%d" % day, "action_kind": "group",
		"participants": ["priscilla", "lavinia"], "source_receipt_id": source_receipt_id}


func _seed_group_source(day: int) -> String:
	var state: Dictionary = _game_state.contacts
	for participant: String in ["priscilla", "lavinia"]:
		var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(state, participant, day,
			"offer.%s.day%d" % [participant, day], "solo.%s.day%d" % [participant, day])
		assert_true(offered.get("ok", false), str(offered))
		if not offered.get("ok", false):
			return ""
		state = offered["value"]["candidate"]
	var activated: Dictionary = CONTACT_STATE.prepare_activate_group_after_round(state, day, 2, 3, "group.activate.day%d" % day)
	assert_true(activated.get("ok", false), str(activated))
	if not activated.get("ok", false):
		return ""
	state = activated["value"]["candidate"]
	var record: Dictionary = ((_registry.find_record("group:priscilla_lavinia:day%d" % day))["value"] as Dictionary)["record"]
	var open_command: Dictionary = _command("group.open.day%d" % day)
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(state, "priscilla", day, open_command["id"], open_command["receipt"], _issuer, record)
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	state = opened["value"]["candidate"]
	var reply_command: Dictionary = _command("group.reply.day%d" % day)
	var replied: Dictionary = CONTACT_STATE.prepare_reply(state, "priscilla", day, reply_command["id"], reply_command["receipt"], _issuer, record)
	assert_true(replied.get("ok", false), str(replied))
	if not replied.get("ok", false):
		return ""
	_game_state.contacts = replied["value"]["candidate"]
	return str((replied["receipt"] as Dictionary)["receipt_id"])


func _await_stage_presentation(stage_name: String) -> Dictionary:
	var steps: int = 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false) or not bool(cursor["value"]["has_stage"]):
			assert_true(false, "the walk ended before the %s presentation" % stage_name)
			return {}
		var begun: Dictionary = _state_port.begin_next_stage()
		if not begun.get("ok", false):
			assert_true(false, "a stage before %s refused: %s" % [stage_name, JSON.stringify(begun)])
			return {}
		var value: Dictionary = begun["value"]
		var stage: Dictionary = value["stage"]
		if str(value["mode"]) == "await_registered_command":
			if str(stage["stage_id"]) == stage_name:
				return (value["command"] as Dictionary)["presentation_request"]
			assert_true(false, "an unexpected presentation paused the walk at " + str(stage["stage_id"]))
			return {}
		if str(stage["stage_id"]) == stage_name:
			assert_true(false, "the %s stage derived no presentation" % stage_name)
			return {}
		var advanced: Dictionary = _game_state._run_lifecycle.complete_active_stage(
			str(stage["transaction_id"]), {"value": ((value["receipt"] as Dictionary)["value"] as Dictionary).duplicate(true)})
		if not advanced.get("ok", false):
			assert_true(false, "a stage before %s would not complete: %s" % [stage_name, JSON.stringify(advanced)])
			return {}
	assert_true(false, "the walk stopped advancing before the %s presentation" % stage_name)
	return {}


func _active_plan() -> Dictionary:
	var plan: Variant = _game_state._run_lifecycle.to_dict()["active_resolution_plan"]
	return (plan as Dictionary) if typeof(plan) == TYPE_DICTIONARY else {}


func _top_level_stage_transaction_id(stage_name: String) -> String:
	for stage_value: Variant in (_active_plan().get("stages", []) as Array):
		if str((stage_value as Dictionary).get("stage_id", "")) == stage_name:
			return str((stage_value as Dictionary).get("transaction_id", ""))
	return ""


func _condition_receipt_id(source_day: int) -> String:
	var resolved: Dictionary = _consequence.resolve_condition_receipt({"causal_day_instance": CAUSAL_DAY, "source_day": source_day})
	assert_true(resolved.get("ok", false), str(resolved))
	return str(((resolved["value"] as Dictionary)["condition_receipt"] as Dictionary)["receipt_id"])


func _derive(parent_receipt_id: String, child_kind: StringName, ordinal: int, sources: Array) -> Dictionary:
	var sorted: Array = sources.duplicate()
	sorted.sort()
	var derived: Dictionary = _issuer.derive_child({"parent_receipt_id": parent_receipt_id, "child_kind": child_kind,
		"ordinal": ordinal, "source_ids": sorted})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	if not derived.get("ok", false):
		return {}
	return {"child_id": str((derived["value"] as Dictionary)["child_id"]),
		"provenance": ((derived["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true)}


func _tokens(projection: Array) -> Array:
	var tokens: Array = []
	for member: Array in projection:
		tokens.append(str(member[0]) + "=" + _json(member[1]))
	return tokens


func _json(value: Variant) -> String:
	return str((CANONICAL.stringify(value))["value"])


func _sha256_value(value: Variant) -> String:
	return _sha256_bytes(_json(value).to_utf8_buffer())


## Asserts one observed provenance against its plan-text row, prints it for the generator, and --
## once the record exists -- requires it to equal the vector the record carries for that row, so
## the sealed vectors and the live producer can never silently diverge.
func _observe(row_id: String, provenance: Dictionary, expected_parent: String, expected_ordinal: int) -> void:
	_observe_silently(row_id, provenance, expected_parent, expected_ordinal)
	var vector: Dictionary = {
		"row_id": row_id,
		"child_kind": str(provenance["child_kind"]),
		"ordinal": int(provenance["ordinal"]),
		"parent_receipt_id": str(provenance["parent_receipt_id"]),
		"child_id": str(provenance["child_id"]),
		"source_ids": (provenance["source_ids"] as Array).duplicate(),
	}
	print(VECTOR_MARKER + _json(vector))
	if not _record.is_empty():
		var recorded: Dictionary = {}
		for candidate: Dictionary in (_record.get("observed_vectors", []) as Array):
			if str(candidate["row_id"]) == row_id:
				recorded = candidate
		assert_eq(recorded, vector, row_id + ": the live vector equals the sealed vector byte for byte")


## Prints one publication vector and, once the record exists, requires it to be the sealed one.
func _publish_vector(owner: String, kind: String, sequence: Array, signal_name: String, counts: Array, conflict_code: String) -> void:
	var vector: Dictionary = {"owner": owner, "kind": kind, "first_delivery_sequence": sequence,
		"signal": signal_name, "signal_counts": counts, "conflict_code": conflict_code}
	print(PUBLICATION_MARKER + _json(vector))
	if not _record.is_empty():
		var recorded: Dictionary = {}
		for candidate: Dictionary in (_record.get("observed_publications", []) as Array):
			if str(candidate["owner"]) == owner and str(candidate["kind"]) == kind:
				recorded = candidate
		assert_eq(recorded, vector, owner + "/" + kind + ": the live publication vector equals the sealed one")


func _ledger_request(kind: String, semantic_receipt: Dictionary, publication: Dictionary) -> Dictionary:
	return {"kind": kind, "semantic_receipt": semantic_receipt.duplicate(true), "publication": publication.duplicate(true),
		"publication_sha256": _sha256_value(publication)}


func _sorted_copy(values: Array) -> Array:
	var copy: Array = values.duplicate()
	copy.sort()
	return copy


func _observe_silently(row_id: String, provenance: Dictionary, expected_parent: String, expected_ordinal: int) -> void:
	var row: Dictionary = _row(row_id)
	assert_false(row.is_empty(), row_id + " is a parsed matrix row")
	if row.is_empty():
		return
	assert_eq(str(provenance["child_kind"]), str(row["child_kind"]), row_id + " child kind")
	assert_eq(str(provenance["parent_receipt_id"]), expected_parent, row_id + " parent receipt id")
	assert_eq(int(provenance["ordinal"]), expected_ordinal, row_id + " ordinal")
	var observed_paths: Array = []
	for token: String in (provenance["source_ids"] as Array):
		observed_paths.append(token.substr(0, token.find("=")))
	observed_paths.sort()
	var expected_paths: Array = (row["source_paths"] as Array).duplicate()
	expected_paths.sort()
	assert_eq(observed_paths, expected_paths, row_id + " projects exactly its row's paths")
	var sorted_tokens: Array = (provenance["source_ids"] as Array).duplicate()
	sorted_tokens.sort()
	assert_eq(sorted_tokens, provenance["source_ids"], row_id + " tokens are strictly sorted")
	assert_true((provenance["source_ids"] as Array).has("role=" + _json(str((_generator.ROW_REALIZATIONS[row_id] as Dictionary)["role"]))),
		row_id + " projects its exact role")
	var validated: Dictionary = _issuer.validate_child(provenance, StringName(str(row["child_kind"])))
	assert_true(validated.get("ok", false), row_id + " revalidates through the issuer: " + str(validated.get("code", &"")))


# =================================================================================================
# record helpers
# =================================================================================================

func _row(row_id: String) -> Dictionary:
	return _row_in(_matrix_rows, row_id)


func _row_in(rows: Array, row_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row["row_id"]) == row_id:
			return row
	return {}


func _with(record: Dictionary, path: Array, value: Variant) -> Dictionary:
	var copy: Dictionary = record.duplicate(true)
	var cursor: Variant = copy
	for index: int in range(path.size() - 1):
		cursor = cursor[path[index]]
	cursor[path[path.size() - 1]] = value
	return copy


func _without(record: Dictionary, key: String) -> Dictionary:
	var copy: Dictionary = record.duplicate(true)
	copy.erase(key)
	return copy


func _without_row() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	((copy["derivation_matrix"] as Dictionary)["rows"] as Array).remove_at(0)
	((copy["derivation_matrix"] as Dictionary)["derivation_order"] as Array).remove_at(0)
	return copy


func _swap_order() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	var order: Array = (copy["derivation_matrix"] as Dictionary)["derivation_order"]
	var first: Variant = order[0]
	order[0] = order[1]
	order[1] = first
	return copy


func _without_vector() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	(copy["observed_vectors"] as Array).remove_at(0)
	return copy


func _vector_for_unrealized() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	var vector: Dictionary = ((copy["observed_vectors"] as Array)[0] as Dictionary).duplicate(true)
	vector["row_id"] = "P01.day_resolution.stage"
	(copy["observed_vectors"] as Array).append(vector)
	return copy


func _vector_path_drift() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	var vector: Dictionary = (copy["observed_vectors"] as Array)[0]
	var sources: Array = vector["source_ids"]
	sources[0] = "aaa_drifted=" + str(sources[0]).substr(str(sources[0]).find("=") + 1)
	return copy


func _vector_token_reversed() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	((copy["observed_vectors"] as Array)[0]["source_ids"] as Array).reverse()
	return copy


func _red_passing() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	var command: Dictionary = (copy["commands"] as Array)[0]
	command["failing"] = 0
	command["load_failures"] = 0
	return copy


func _red_by_load_failure() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	var command: Dictionary = (copy["commands"] as Array)[0]
	command["failing"] = 1
	command["load_failures"] = 1
	return copy


func _without_publication() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	(copy["observed_publications"] as Array).remove_at(0)
	return copy


func _without_owner_class() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	((copy["bootstrap_probe"] as Dictionary)["owner_classes"] as Dictionary).erase("issuer_instance_id")
	return copy


func _without_probe_key() -> Dictionary:
	var copy: Dictionary = _record.duplicate(true)
	((copy["bootstrap_probe"] as Dictionary)["keys"] as Array).remove_at(0)
	return copy


func _find(haystack: PackedByteArray, needle: PackedByteArray) -> int:
	for offset: int in range(haystack.size() - needle.size() + 1):
		var matched: bool = true
		for index: int in range(needle.size()):
			if haystack[offset + index] != needle[index]:
				matched = false
				break
		if matched:
			return offset
	return -1


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


# This file's OWN git reader, independent of the generator's, so a broken helper there cannot make
# these assertions agree with it by accident.
func _git_line(arguments: PackedStringArray) -> String:
	var repository: String = ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var full: PackedStringArray = PackedStringArray(["-c", "safe.directory=%s" % repository, "-C", repository])
	full.append_array(arguments)
	var output: Array = []
	if OS.execute("git", full, output, false) != 0:
		return ""
	return "".join(PackedStringArray(output)).strip_edges()


func _git_ok(arguments: PackedStringArray) -> bool:
	var repository: String = ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var full: PackedStringArray = PackedStringArray(["-c", "safe.directory=%s" % repository, "-C", repository])
	full.append_array(arguments)
	return OS.execute("git", full, [], false) == 0


func _git_blob(commit: String, path: String) -> PackedByteArray:
	var repository: String = ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var scratch: String = OS.get_user_data_dir().path_join("p2r15-test-blob-%d.tmp" % OS.get_process_id())
	var redirect: String = "git -c safe.directory=\"%s\" -C \"%s\" cat-file blob %s:%s > \"%s\"" % [repository, repository, commit, path, scratch]
	var shell: String = "cmd.exe" if OS.get_name() == "Windows" else "sh"
	var flag: String = "/c" if OS.get_name() == "Windows" else "-c"
	if OS.execute(shell, PackedStringArray([flag, redirect]), [], false) != 0:
		return PackedByteArray()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	DirAccess.remove_absolute(scratch)
	return bytes
