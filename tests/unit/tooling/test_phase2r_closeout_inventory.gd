extends "res://addons/gut/test.gd"

## RED-first binding suite for tools/evidence/Phase2RCloseoutInventory.gd.
##
## Every committed-evidence mode is proven against a throwaway `git clone --shared --no-checkout`
## of this repository. The alternates link keeps the pinned historical commit
## d229ba82e4990336fb5309f3d6b21d16d4cae675 reachable while the fixture commits its own synthetic
## evidence, so SEALED_PRE_ATTACH, ATTACHED_PRE_CLOSE and POST_CLOSE get honest exact-success
## coverage through real Git plumbing without touching this repository's refs or worktree.
##
## Every rejection asserts an exact failure code. Asserting only `ok == false` would pass against
## the unimplemented stub and against any validator that rejects everything, so it would prove
## nothing.

const INVENTORY := preload("res://tools/evidence/Phase2RCloseoutInventory.gd")
const JSON_SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const SCHEMA_PATH := "res://schemas/evidence/phase2r-closeout-inventory.schema.json"
const EPIC_ID := "dwm-p2r"
const CLOSEOUT_ISSUE_ID := "dwm-p2r.10"
const SPEC_ID := "spec.phase_2r.foundation_repair"

const EVIDENCE_ROOT_RELATIVE := "evidence/phase_2r/closeout"
const EVIDENCE_COMMIT_SUBJECT := "test(phase2r): record the final foundation closeout gate"
const NOTE_PREFIX := "PHASE2R_CLOSEOUT_EVIDENCE_V1 "
const EPIC_NOTE_PREFIX := "PHASE2R_EPIC_CLOSEOUT_V1 "

## Metadata order, taken from prompt_docs/metadata/phase_2r_beads.v1.json child_contracts.
const CONTRACT_IDS: Array[String] = [
	"dwm-p2r.1", "dwm-p2r.2", "dwm-p2r.3", "dwm-p2r.4", "dwm-p2r.5", "dwm-p2r.6",
	"dwm-p2r.7", "dwm-p2r.8", "dwm-p2r.9", "dwm-p2r.10", "dwm-p2r.12", "dwm-wks",
	"dwm-p2r.16", "dwm-p2r.13", "dwm-p2r.14", "dwm-p2r.15",
]

## Declaration order from Plan-04 Global Constraints. Deliberately NOT sorted.
const HISTORICAL_HELPER_IDS: Array[String] = ["dwm-p2r.11", "dwm-p2r.7.1"]
const EXECUTION_REMEDIATION_IDS: Array[String] = [
	"dwm-p2r.17", "dwm-p2r.18", "dwm-p2r.19", "dwm-p2r.20", "dwm-p2r.21", "dwm-p2r.22",
	"dwm-p2r.23", "dwm-p2r.24", "dwm-p2r.25", "dwm-p2r.26", "dwm-p2r.27", "dwm-p2r.28",
	"dwm-p2r.29", "dwm-p2r.30", "dwm-p2r.31", "dwm-p2r.32", "dwm-p2r.33", "dwm-p2r.34",
	"dwm-p2r.35", "dwm-p2r.36", "dwm-p2r.37", "dwm-p2r.38",
]

## The one closed living-path historical evidence exception.
const HISTORICAL_INDEX_OWNER := "dwm-p2r.1"
const HISTORICAL_INDEX_PATH := "prompt_docs/INDEX.md"
const HISTORICAL_INDEX_COMMAND := "task4-docs-after-delete"
const HISTORICAL_INDEX_SHA256 := "d30741719d690629d1d32ce3185053775bc19e058b01732cc2bbe7600dbfd408"
const HISTORICAL_INDEX_COMMIT := "d229ba82e4990336fb5309f3d6b21d16d4cae675"
const HISTORICAL_INDEX_PARENT := "0e9ffc5232b8c79f257f3c83275714df5ee24c15"

const FIXTURE_CHECKOUT_PATHS: Array[String] = [
	"docs/superpowers/plans",
	"prompt_docs/metadata/phase_2r_beads.v1.json",
	"prompt_docs/INDEX.md",
	"evidence/phase_2r/baseline.json",
	"evidence/phase_2r/legacy/legacy_heading_inventory.v1.json",
	"evidence/phase_2r/documentation/legacy_disposition.json",
	"evidence/phase_2r/tooling/codegraph_prerequisites.json",
	"evidence/phase_2r/tooling/codegraph_removal.json",
]

const DEFERRED_OWNERS: Array[String] = ["dwm-oyo.3", "dwm-oyo.4", "dwm-oyo.6", "dwm-oyo.7"]
const DEFERRED_OBLIGATION_IDS: Array[String] = [
	"schedule_view_warning_done_and_terminal_intent",
	"relationship_witness_and_dating_completion",
	"final_ending_plan_and_playback",
	"final_full_run_evidence",
]
const DEFERRED_REQUIREMENT_IDS: Array[String] = [
	"req.run.day7_terminal_intent", "req.schedule.done_board_fate", "req.schedule.warning_queue",
	"req.test.schedule_gate", "req.ending.epilogue", "req.ending.ids", "req.ending.playback",
	"req.ending.primary", "req.run.day7_terminal",
]

## Four fresh commands carry the whole requirement mapping; many requirements share one log.
const COMMAND_IDS: Array[String] = ["desktop-gate", "docs-validate", "gut-complete", "schedule-gate"]

## Live dwm-p2r.10 already carries a preservation-ruling note, so the attachment must append to
## existing prose rather than replace it.
const PRESERVED_NOTE := "Preservation ruling, 2026-08-10: baseline.json remains immutable."

var _fixture_directories: Array[String] = []
var _scratch_root := ""
var _repository_root := ""
var _metadata_document := {}


func before_all() -> void:
	_repository_root = _globalized_repository_root()
	_scratch_root = OS.get_user_data_dir().path_join("p2rci%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_scratch_root)
	var parsed: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_string("res://prompt_docs/metadata/phase_2r_beads.v1.json"))
	assert_true(parsed.get("ok", false), "the real Phase-2R metadata must parse: %s" % str(parsed))
	_metadata_document = parsed.get("value", {})


func after_each() -> void:
	for directory: String in _fixture_directories:
		_remove_tree(directory)
	_fixture_directories.clear()


func after_all() -> void:
	if not _scratch_root.is_empty():
		_remove_tree(_scratch_root)


# =============================================================================================
# Harness containment.
#
# `-C` alone gives git NO repository containment: from a missing or empty fixture directory git
# walks up and silently targets the repository under test, so a failed clone turns every later
# add/commit/amend into a write against the real branch. That escape fired once during this task
# and amended the real HEAD. These tests pin the containment that makes it impossible.
# =============================================================================================

func test_the_fixture_git_helper_cannot_reach_the_repository_under_test() -> void:
	var outside: String = _scratch_root.path_join("not-a-repository")
	DirAccess.make_dir_recursive_absolute(outside)
	_fixture_directories.append(outside)
	var result: Dictionary = _run_git(outside, PackedStringArray(["rev-parse", "HEAD"]))
	assert_false(result["ok"],
		"a non-repository fixture path must not resolve a head: %s" % str(result))
	assert_eq(_first_commit_id(str(result["output"])), "",
		"the fixture helper must never reach the repository under test")


func test_the_fixture_git_helper_cannot_commit_from_a_non_repository_path() -> void:
	var outside: String = _scratch_root.path_join("not-a-repository-commit")
	DirAccess.make_dir_recursive_absolute(outside)
	_fixture_directories.append(outside)
	assert_false(_run_git(outside, PackedStringArray(["commit", "-q", "--amend", "-m",
		EVIDENCE_COMMIT_SUBJECT]))["ok"],
		"an uncontained amend must fail rather than rewrite the repository under test")


## dwm-p2r.10 Task 1 residual, folded in by Task 3 Step 2. The two tests above pin containment
## for a non-repository PATH; this pins the remaining hole, an EMPTY path, which used to skip
## the --git-dir/--work-tree block entirely and let git resolve up to the repository under test.
func test_the_fixture_git_helper_refuses_an_empty_working_directory() -> void:
	var result: Dictionary = _run_git("", PackedStringArray(["rev-parse", "HEAD"]))
	assert_false(result["ok"],
		"an uncontained helper call must fail closed: %s" % str(result))
	assert_eq(_first_commit_id(str(result["output"])), "",
		"an uncontained helper call must never resolve the repository under test")
	assert_true(str(result["output"]).begins_with("GIT_WORKING_DIRECTORY_REQUIRED"),
		"the refusal must be the helper's own guard rather than git's own error: %s"
			% str(result))


## Argument-less `clone` fails inside git rather than inside the guard, and that distinction is
## the point: the guard classifies by argv, so a regression into a blanket ban is caught here
## without paying for a real clone or leaving a directory behind.
func test_the_fixture_git_helper_still_permits_an_uncontained_clone() -> void:
	var result: Dictionary = _run_git("", PackedStringArray(["clone"]))
	assert_false(result["ok"], "an argument-less clone must still fail inside git")
	assert_false(str(result["output"]).begins_with("GIT_WORKING_DIRECTORY_REQUIRED"),
		"the guard must not refuse the one call that legitimately has no working directory")


## Returns the first 40-character lowercase hex token in the text, or "" when there is none.
func _first_commit_id(text: String) -> String:
	for token: String in text.replace("\n", " ").replace("\r", " ").split(" ", false):
		var candidate: String = token.strip_edges()
		if candidate.length() != 40:
			continue
		var hex: bool = true
		for index: int in range(candidate.length()):
			if not "0123456789abcdef".contains(candidate.substr(index, 1)):
				hex = false
				break
		if hex:
			return candidate
	return ""


# =============================================================================================
# Mode dispatch.
# =============================================================================================

func test_the_closed_mode_list_is_frozen() -> void:
	assert_eq(INVENTORY.MODES, ["PREREQUISITE", "PRE_SEAL", "SEALED_PRE_ATTACH",
		"ATTACHED_PRE_CLOSE", "POST_CLOSE"], "the closed mode list is frozen")


func test_an_unknown_mode_string_fails_invalid_closeout_mode() -> void:
	_reject(_validate(_prerequisite_fixture("mode-unknown"), "SEALED"), &"invalid_closeout_mode")


func test_a_lowercase_mode_fails_invalid_closeout_mode() -> void:
	_reject(_validate(_prerequisite_fixture("mode-lowercase"), "prerequisite"), &"invalid_closeout_mode")


func test_a_non_string_mode_fails_invalid_closeout_mode() -> void:
	_reject(_validate(_prerequisite_fixture("mode-non-string"), 1), &"invalid_closeout_mode")


func test_an_unreadable_metadata_path_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("metadata-absent")
	fixture["metadata_path"] = str(fixture["repository"]).path_join("absent.json")
	_reject(_validate(fixture, "PREREQUISITE"), &"metadata_unreadable")


func test_an_unreadable_beads_snapshot_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("snapshot-absent")
	fixture["snapshot_path"] = str(fixture["repository"]).path_join("absent.json")
	_reject(_validate(fixture, "PREREQUISITE"), &"beads_snapshot_unreadable")


func test_a_beads_snapshot_that_is_not_a_json_array_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("snapshot-not-array")
	_write_text(str(fixture["snapshot_path"]), "{\"id\":\"dwm-p2r\"}\n")
	_reject(_validate(fixture, "PREREQUISITE"), &"beads_snapshot_invalid")


func test_an_unreadable_requirement_index_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("index-absent")
	fixture["requirement_index_path"] = str(fixture["repository"]).path_join("absent.md")
	_reject(_validate(fixture, "PREREQUISITE"), &"requirement_index_unreadable")


# =============================================================================================
# PREREQUISITE.
# =============================================================================================

func test_prerequisite_succeeds_on_the_exact_real_prerequisite_state() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("prerequisite-success"), "PREREQUISITE"))
	if value.is_empty():
		return
	assert_eq(value.get("mode"), "PREREQUISITE")
	assert_eq(value.get("epic_id"), EPIC_ID)
	assert_eq(value.get("closeout_issue_id"), CLOSEOUT_ISSUE_ID)
	assert_eq(value.get("requirement_evidence"), {}, "PREREQUISITE returns an exactly empty mapping")
	assert_eq(value.get("closeout_evidence"), null, "PREREQUISITE returns a null binding")


func test_the_success_envelope_has_exactly_the_eight_declared_keys() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("envelope-keys"), "PREREQUISITE"))
	if value.is_empty():
		return
	var keys: Array = value.keys()
	keys.sort()
	assert_eq(keys, ["child_contracts", "closeout_evidence", "closeout_issue_id",
		"deferred_requirements", "epic_id", "mode", "non_contract_children",
		"requirement_evidence"], "the success envelope is exactly eight keys")


func test_child_contracts_holds_exactly_sixteen_records_in_metadata_order() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("contract-order"), "PREREQUISITE"))
	if value.is_empty():
		return
	assert_eq(_contract_ids(value), CONTRACT_IDS, "sixteen contract records in metadata order")


func test_prerequisite_rejects_a_present_output_root() -> void:
	var fixture: Dictionary = _prerequisite_fixture("output-present")
	DirAccess.make_dir_recursive_absolute(str(fixture["evidence_root_absolute"]))
	_reject(_validate(fixture, "PREREQUISITE"), &"output_root_present")


func test_prerequisite_rejects_a_closed_closeout_issue() -> void:
	var fixture: Dictionary = _prerequisite_fixture("closeout-closed")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"status": "closed"})
	_reject(_validate(fixture, "PREREQUISITE"), &"closeout_issue_not_open")


func test_prerequisite_rejects_an_open_non_closeout_contract() -> void:
	var fixture: Dictionary = _prerequisite_fixture("sibling-open")
	_mutate_issue(fixture, "dwm-p2r.9", {"status": "open"})
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_record_open")


func test_prerequisite_rejects_a_closeout_issue_blocked_by_an_oyo_dependency() -> void:
	var fixture: Dictionary = _prerequisite_fixture("oyo-blocker")
	((_issue(fixture, CLOSEOUT_ISSUE_ID)["dependencies"]) as Array).append({
		"issue_id": CLOSEOUT_ISSUE_ID, "depends_on_id": "dwm-oyo.3", "type": "blocks"})
	_rewrite_snapshot(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"closeout_oyo_dependency")


func test_prerequisite_rejects_an_existing_closeout_note() -> void:
	var fixture: Dictionary = _prerequisite_fixture("note-present")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"notes": NOTE_PREFIX + "{\"schema_version\":1}"})
	_reject(_validate(fixture, "PREREQUISITE"), &"closeout_attachment_present")


func test_prerequisite_rejects_a_missing_contract_record() -> void:
	var fixture: Dictionary = _prerequisite_fixture("contract-missing")
	_drop_issue(fixture, "dwm-p2r.16")
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_record_missing")


func test_prerequisite_rejects_a_duplicated_contract_record() -> void:
	var fixture: Dictionary = _prerequisite_fixture("contract-duplicate")
	(fixture["snapshot"] as Array).append((_issue(fixture, "dwm-p2r.16") as Dictionary).duplicate(true))
	_rewrite_snapshot(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_record_duplicate")


func test_prerequisite_rejects_a_contract_with_the_wrong_spec_id() -> void:
	var fixture: Dictionary = _prerequisite_fixture("wrong-spec")
	_mutate_issue(fixture, "dwm-p2r.6", {"spec_id": "spec.other"})
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_spec_mismatch")


func test_prerequisite_rejects_a_contract_whose_plan_path_is_absent() -> void:
	var fixture: Dictionary = _prerequisite_fixture("stale-plan")
	_contract_metadata(fixture, "dwm-p2r.6")["plan_path"] = "docs/superpowers/plans/absent.md"
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_plan_path_missing")


func test_prerequisite_rejects_metadata_that_declares_other_than_sixteen_contracts() -> void:
	var fixture: Dictionary = _prerequisite_fixture("metadata-fifteen")
	(fixture["metadata"]["child_contracts"] as Array).remove_at(3)
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_count_mismatch")


# =============================================================================================
# The two named non-contract child classes.
# =============================================================================================

func test_non_contract_children_reports_both_classes_separately() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("classes-success"), "PREREQUISITE"))
	if value.is_empty():
		return
	var classes: Dictionary = value["non_contract_children"]
	var keys: Array = classes.keys()
	keys.sort()
	assert_eq(keys, ["execution_remediation_children", "historical_helpers"],
		"exactly the two named classes are reported")
	assert_eq((classes["historical_helpers"] as Dictionary)["count"], 2)
	assert_eq((classes["execution_remediation_children"] as Dictionary)["count"], 22)


func test_the_class_id_arrays_are_reported_in_exact_declaration_order() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("classes-order"), "PREREQUISITE"))
	if value.is_empty():
		return
	var classes: Dictionary = value["non_contract_children"]
	var helpers: Array = (classes["historical_helpers"] as Dictionary)["ids"]
	assert_eq(helpers, HISTORICAL_HELPER_IDS, "helpers stay in declaration order")
	assert_eq((classes["execution_remediation_children"] as Dictionary)["ids"],
		EXECUTION_REMEDIATION_IDS, "remediation children stay in declaration order")
	# Both declared lists happen to coincide with sorted order, so sorting either is an
	# unobservable no-op. The enforceable law is the general one - any reordering fails closed -
	# which test_sealed_pre_attach_rejects_a_gate_whose_class_ids_were_reordered proves.


func test_each_class_count_equals_its_own_id_array_size() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("classes-count"), "PREREQUISITE"))
	if value.is_empty():
		return
	var classes: Dictionary = value["non_contract_children"]
	for class_key: String in ["historical_helpers", "execution_remediation_children"]:
		var record: Dictionary = classes[class_key]
		assert_eq(int(record["count"]), (record["ids"] as Array).size(),
			"%s count must equal its own id array size" % class_key)


func test_the_two_classes_are_never_merged_or_summed() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("classes-unmerged"), "PREREQUISITE"))
	if value.is_empty():
		return
	var classes: Dictionary = value["non_contract_children"]
	assert_false(classes.has("count"), "the classes must never carry a summed count")
	assert_false(classes.has("ids"), "the classes must never carry a merged id list")
	assert_eq(classes.size(), 2, "exactly two separately named classes")


func test_no_class_member_appears_in_child_contracts() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("classes-disjoint"), "PREREQUISITE"))
	if value.is_empty():
		return
	var contract_ids: Array[String] = _contract_ids(value)
	for member: String in HISTORICAL_HELPER_IDS + EXECUTION_REMEDIATION_IDS:
		assert_false(contract_ids.has(member), "%s must never enter contract counts" % member)


func test_an_unnamed_fortieth_direct_child_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("fortieth-child")
	(fixture["snapshot"] as Array).append(_issue_record("dwm-p2r.39", "closed", EPIC_ID))
	_rewrite_snapshot(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"direct_child_unadmitted")


func test_an_open_historical_helper_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("helper-open")
	_mutate_issue(fixture, "dwm-p2r.11", {"status": "open"})
	_reject(_validate(fixture, "PREREQUISITE"), &"class_member_open")


func test_an_open_execution_remediation_child_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("remediation-open")
	_mutate_issue(fixture, "dwm-p2r.29", {"status": "open"})
	_reject(_validate(fixture, "PREREQUISITE"), &"class_member_open")


func test_a_missing_execution_remediation_child_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("remediation-missing")
	_drop_issue(fixture, "dwm-p2r.33")
	_reject(_validate(fixture, "PREREQUISITE"), &"class_member_missing")


func test_a_missing_historical_helper_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("helper-missing")
	_drop_issue(fixture, "dwm-p2r.7.1")
	_reject(_validate(fixture, "PREREQUISITE"), &"class_member_missing")


func test_an_id_claimed_by_a_class_and_the_contract_set_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("class-contract-collision")
	_drop_issue(fixture, "dwm-p2r.11")
	_issue(fixture, "dwm-p2r.9")["id"] = "dwm-p2r.11"
	_rewrite_snapshot(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"contract_record_missing")


func test_a_class_member_reparented_away_from_the_epic_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("class-reparented")
	_mutate_issue(fixture, "dwm-p2r.21", {"parent": "dwm-p2r.9"})
	_reject(_validate(fixture, "PREREQUISITE"), &"class_member_missing")


# =============================================================================================
# Declared evidence links and the one historical exception.
# =============================================================================================

func test_every_declared_current_byte_evidence_link_is_hash_validated() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("evidence-success"), "PREREQUISITE"))
	if value.is_empty():
		return
	var first: Dictionary = _contract(value, "dwm-p2r.1")
	assert_eq((first["evidence_links"] as Array).size(), 4, "dwm-p2r.1 declares four links")
	assert_eq(first["evidence_verdict"], "declared", "a nonempty declared set reports declared")


func test_a_mutated_current_byte_evidence_hash_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("evidence-hash-drift")
	var links: Array = _contract_metadata(fixture, "dwm-p2r.2")["expected_metadata"]["evidence_links"]
	(links[0] as Dictionary)["sha256"] = _flip_hex(str((links[0] as Dictionary)["sha256"]))
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"evidence_link_hash_mismatch")


func test_an_absent_declared_evidence_path_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("evidence-path-absent")
	var links: Array = _contract_metadata(fixture, "dwm-p2r.2")["expected_metadata"]["evidence_links"]
	(links[0] as Dictionary)["path"] = "evidence/phase_2r/tooling/absent.json"
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"evidence_link_path_missing")


func test_the_historical_index_link_validates_its_committed_blob_not_current_bytes() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("historical-success"), "PREREQUISITE"))
	if value.is_empty():
		return
	var owner: Dictionary = _contract(value, HISTORICAL_INDEX_OWNER)
	var found: bool = false
	for link: Dictionary in (owner["evidence_links"] as Array):
		if str(link["path"]) == HISTORICAL_INDEX_PATH:
			found = true
			assert_eq(str(link["sha256"]), HISTORICAL_INDEX_SHA256,
				"the historical blob hash is reported, not the current bytes")
	assert_true(found, "the historical INDEX.md link is reported")


func test_the_current_index_bytes_genuinely_differ_from_the_historical_blob() -> void:
	var current: String = _sha256_bytes(FileAccess.get_file_as_bytes("res://" + HISTORICAL_INDEX_PATH))
	assert_ne(current, HISTORICAL_INDEX_SHA256,
		"if current bytes matched, the living-path exception would prove nothing")


func test_a_changed_historical_source_commit_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("historical-commit-drift")
	_historical_link(fixture)["command_record_id"] = "task4-docs-before-delete"
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"historical_exception_mismatch")


func test_a_changed_historical_blob_hash_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("historical-hash-drift")
	var link: Dictionary = _historical_link(fixture)
	link["sha256"] = _flip_hex(str(link["sha256"]))
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"historical_exception_mismatch")


func test_a_second_living_path_exception_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("historical-second")
	var links: Array = _contract_metadata(fixture, "dwm-p2r.2")["expected_metadata"]["evidence_links"]
	links.append({"path": "prompt_docs/INDEX.md", "sha256": HISTORICAL_INDEX_SHA256,
		"requirement_id": "req.docs.generated_index", "command_record_id": HISTORICAL_INDEX_COMMAND})
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"historical_exception_extra")


func test_an_empty_declared_evidence_set_stays_empty_and_pending_before_close() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("pending-empty"), "PREREQUISITE"))
	if value.is_empty():
		return
	var contract: Dictionary = _contract(value, "dwm-p2r.9")
	assert_eq(contract["evidence_links"], [], "an intentionally empty set stays physically empty")
	assert_eq(contract["evidence_verdict"], "pending_final_gate",
		"an empty set is pending, never backfilled")


func test_a_requirement_id_absent_from_the_generated_index_fails_closed() -> void:
	var fixture: Dictionary = _prerequisite_fixture("requirement-unindexed")
	(_contract_metadata(fixture, "dwm-p2r.6")["expected_metadata"]["requirement_ids"] as Array).append(
		"req.invented.absent")
	_rewrite_metadata(fixture)
	_reject(_validate(fixture, "PREREQUISITE"), &"requirement_not_indexed")


# =============================================================================================
# Deferred obligations.
# =============================================================================================

func test_the_deferred_obligations_are_exactly_the_four_ordered_records() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("deferred-success"), "PREREQUISITE"))
	if value.is_empty():
		return
	var deferred: Array = value["deferred_requirements"]
	assert_eq(deferred.size(), 4, "exactly four deferred obligations")
	var obligations: Array[String] = []
	var owners: Array[String] = []
	for record: Dictionary in deferred:
		obligations.append(str(record["obligation_id"]))
		owners.append(str(record["owner_beads_id"]))
	assert_eq(obligations, DEFERRED_OBLIGATION_IDS, "the obligation order is frozen")
	assert_eq(owners, DEFERRED_OWNERS, "each obligation names its later owner")


func test_only_the_witness_obligation_may_carry_an_empty_requirement_list() -> void:
	var value: Dictionary = _accept(_validate(_prerequisite_fixture("deferred-empty"), "PREREQUISITE"))
	if value.is_empty():
		return
	for record: Dictionary in (value["deferred_requirements"] as Array):
		var empty: bool = (record["requirement_ids"] as Array).is_empty()
		if str(record["owner_beads_id"]) == "dwm-oyo.4":
			assert_true(empty, "the witness obligation has no dedicated requirement ID yet")
		else:
			assert_false(empty, "%s must list its requirements" % str(record["obligation_id"]))


func test_every_deferred_requirement_resolves_in_the_current_index() -> void:
	var indexed: Dictionary = _indexed_requirement_ids()
	for requirement_id: String in DEFERRED_REQUIREMENT_IDS:
		assert_true(indexed.has(requirement_id),
			"%s must resolve in the generated index" % requirement_id)


# =============================================================================================
# PRE_SEAL.
# =============================================================================================

func test_pre_seal_succeeds_with_the_complete_uncommitted_candidate() -> void:
	var value: Dictionary = _accept(_validate(_sealed_fixture("preseal-success", "PRE_SEAL"), "PRE_SEAL"))
	if value.is_empty():
		return
	assert_eq(value.get("mode"), "PRE_SEAL")
	assert_eq(value.get("closeout_evidence"), null, "PRE_SEAL returns a null binding")
	assert_eq(_expected_requirement_ids().size(), 72,
		"the fully satisfied Phase-2R requirement set is exactly seventy-two IDs")
	assert_eq((value["requirement_evidence"] as Dictionary).size(), _expected_requirement_ids().size(),
		"PRE_SEAL validates the complete gate-backed mapping")


func test_pre_seal_rejects_a_present_closure_note() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-note", "PRE_SEAL")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"notes": str(fixture["note_line"])})
	_reject(_validate(fixture, "PRE_SEAL"), &"closeout_attachment_present")


func test_pre_seal_rejects_an_already_committed_evidence_commit() -> void:
	_reject(_validate(_sealed_fixture("preseal-committed", "SEALED"), "PRE_SEAL"),
		&"evidence_commit_present")


func test_pre_seal_rejects_a_receipt_that_already_exists() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-receipt", "PRE_SEAL")
	_write_text(str(fixture["evidence_root_absolute"]).path_join("validation_receipt.json"),
		"{\"schema_version\":1}\n")
	_reject(_validate(fixture, "PRE_SEAL"), &"validation_receipt_present")


func test_pre_seal_rejects_a_validation_command_record_that_already_exists() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-command-record", "PRE_SEAL")
	_write_text(str(fixture["evidence_root_absolute"]).path_join("logs/validation-command.jsonl"),
		"{\"schema_version\":1}\n")
	_reject(_validate(fixture, "PRE_SEAL"), &"validation_receipt_present")


func test_pre_seal_rejects_a_missing_gate() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-no-gate", "PRE_SEAL")
	DirAccess.remove_absolute(str(fixture["evidence_root_absolute"]).path_join("gate.json"))
	_reject(_validate(fixture, "PRE_SEAL"), &"gate_unreadable")


func test_pre_seal_rejects_a_requirement_evidence_key_set_that_is_short_one_key() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-missing-key", "PRE_SEAL")
	var gate: Dictionary = fixture["gate"]
	(gate["requirement_evidence"] as Dictionary).erase("req.save.journal")
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_key_set_mismatch")


func test_pre_seal_rejects_an_extra_requirement_evidence_key() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-extra-key", "PRE_SEAL")
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.invented.absent"] = \
		[_evidence_record(fixture, "gut-complete")]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_key_set_mismatch")


func test_pre_seal_rejects_a_deferred_requirement_counted_as_phase2r_evidence() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-deferred-claim", "PRE_SEAL")
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.schedule.warning_queue"] = \
		[_evidence_record(fixture, "gut-complete")]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_key_set_mismatch")


func test_pre_seal_rejects_a_final_ending_requirement_claimed_complete() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-ending-claim", "PRE_SEAL")
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.ending.playback"] = \
		[_evidence_record(fixture, "gut-complete")]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_key_set_mismatch")


func test_pre_seal_rejects_an_unsorted_requirement_evidence_record_array() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-unsorted-records", "PRE_SEAL")
	var mapping: Dictionary = fixture["gate"]["requirement_evidence"]
	mapping["req.test.layers"] = [_evidence_record(fixture, "gut-complete"),
		_evidence_record(fixture, "desktop-gate")]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_record_order")


func test_pre_seal_rejects_a_duplicated_requirement_evidence_record() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-duplicate-record", "PRE_SEAL")
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.test.layers"] = \
		[_evidence_record(fixture, "gut-complete"), _evidence_record(fixture, "gut-complete")]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_record_duplicate")


func test_pre_seal_rejects_an_empty_requirement_evidence_record_array() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-empty-record", "PRE_SEAL")
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.test.layers"] = []
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_record_missing")


func test_pre_seal_rejects_a_record_whose_command_id_is_absent_from_the_gate() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-unbound-command", "PRE_SEAL")
	var record: Dictionary = _evidence_record(fixture, "gut-complete")
	record["command_id"] = "invented-command"
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.test.layers"] = [record]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_command_unbound")


func test_pre_seal_rejects_a_record_whose_command_record_hash_drifted() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-record-hash", "PRE_SEAL")
	var record: Dictionary = _evidence_record(fixture, "gut-complete")
	record["command_record_sha256"] = _flip_hex(str(record["command_record_sha256"]))
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.test.layers"] = [record]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_command_unbound")


func test_pre_seal_rejects_a_log_outside_the_closeout_log_root() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-log-escape", "PRE_SEAL")
	var record: Dictionary = _evidence_record(fixture, "gut-complete")
	record["log_path"] = "evidence/phase_2r/logs/gut-complete.log"
	(fixture["gate"]["requirement_evidence"] as Dictionary)["req.test.layers"] = [record]
	_rewrite_gate(fixture)
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_log_outside_root")


func test_pre_seal_rejects_a_log_hash_that_disagrees_with_the_file() -> void:
	var fixture: Dictionary = _sealed_fixture("preseal-log-hash", "PRE_SEAL")
	_write_text(str(fixture["evidence_root_absolute"]).path_join("logs/gut-complete.log"), "tampered\n")
	_reject(_validate(fixture, "PRE_SEAL"), &"requirement_evidence_log_hash_mismatch")


# =============================================================================================
# SEALED_PRE_ATTACH.
# =============================================================================================

func test_sealed_pre_attach_succeeds_with_the_evidence_commit_at_head() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-success", "SEALED")
	var value: Dictionary = _accept(_validate(fixture, "SEALED_PRE_ATTACH"))
	if value.is_empty():
		return
	assert_eq(value.get("mode"), "SEALED_PRE_ATTACH")
	var binding: Dictionary = value["closeout_evidence"]
	var keys: Array = binding.keys()
	keys.sort()
	assert_eq(keys, ["evidence_commit", "gate_sha256", "subject_commit", "validation_receipt_sha256"],
		"the binding is exactly four keys")
	assert_eq(str(binding["evidence_commit"]), str(fixture["evidence_commit"]))
	assert_eq(str(binding["subject_commit"]), str(fixture["subject_commit"]))
	assert_eq(str(binding["gate_sha256"]), str(fixture["gate_sha256"]))


func test_sealed_pre_attach_rejects_any_note_on_the_closeout_issue() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-note", "SEALED")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"notes": str(fixture["note_line"])})
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"preclose_snapshot_drift")


func test_sealed_pre_attach_rejects_a_timestamp_only_beads_drift() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-timestamp", "SEALED")
	_mutate_issue(fixture, "dwm-p2r.6", {"updated_at": "2026-08-26T00:00:00Z"})
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"preclose_snapshot_drift")


func test_a_simulated_drift_during_the_long_gate_fails_before_any_attachment_is_legal() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-drift", "SEALED")
	_mutate_issue(fixture, "dwm-p2r.21", {"close_reason": "amended mid-gate"})
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"preclose_snapshot_drift")


func test_sealed_pre_attach_rejects_an_evidence_commit_that_is_not_head() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-not-head", "SEALED")
	_write_text(str(fixture["repository"]).path_join("unrelated.txt"), "drift\n")
	_commit(fixture, "chore: an unrelated later commit", ["unrelated.txt"])
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"evidence_commit_not_head")


func test_sealed_pre_attach_rejects_a_wrong_evidence_commit_subject() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-wrong-subject", "SEALED_WRONG_SUBJECT")
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"evidence_commit_subject_mismatch")


func test_sealed_pre_attach_rejects_an_evidence_commit_carrying_an_out_of_root_path() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-extra-path", "SEALED_EXTRA_PATH")
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"evidence_commit_path_outside_root")


func test_sealed_pre_attach_rejects_a_generated_path_omission() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-path-omission", "SEALED")
	(fixture["gate"]["generated_paths"] as Array).remove_at(0)
	_rewrite_gate(fixture)
	_recommit_gate(fixture)
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"generated_paths_mismatch")


func test_sealed_pre_attach_rejects_a_merge_evidence_commit() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-merge", "SEALED_MERGE")
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"evidence_commit_not_single_parent")


func test_sealed_pre_attach_rejects_a_mutated_committed_gate() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-gate-mutated", "SEALED")
	_write_text(str(fixture["evidence_root_absolute"]).path_join("gate.json"), "{\"schema_version\":1}\n")
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"gate_hash_mismatch")


func test_sealed_pre_attach_rejects_a_preclose_snapshot_hash_that_drifted_from_the_gate() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-preclose-hash", "SEALED")
	fixture["gate"]["preclose_beads_snapshot_sha256"] = _flip_hex(
		str(fixture["gate"]["preclose_beads_snapshot_sha256"]))
	_rewrite_gate(fixture)
	_recommit_gate(fixture)
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"preclose_snapshot_hash_mismatch")


func test_sealed_pre_attach_rejects_a_gate_whose_class_record_was_merged() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-classes-merged", "SEALED")
	fixture["gate"]["non_contract_children"] = {"count": 24,
		"ids": HISTORICAL_HELPER_IDS + EXECUTION_REMEDIATION_IDS}
	_rewrite_gate(fixture)
	_recommit_gate(fixture)
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"gate_non_contract_children_mismatch")


func test_sealed_pre_attach_rejects_a_gate_whose_class_ids_were_reordered() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-classes-reordered", "SEALED")
	var reordered: Array = HISTORICAL_HELPER_IDS.duplicate()
	reordered.reverse()
	((fixture["gate"]["non_contract_children"] as Dictionary)["historical_helpers"]
		as Dictionary)["ids"] = reordered
	_rewrite_gate(fixture)
	_recommit_gate(fixture)
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"gate_non_contract_children_mismatch")

func test_sealed_pre_attach_rejects_a_parent_that_is_not_the_attested_tooling_subject() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-wrong-parent", "SEALED")
	fixture["gate"]["subject_commit"] = str(_run_git(str(fixture["repository"]),
		PackedStringArray(["rev-parse", "HEAD~2"]))["output"]).strip_edges()
	_rewrite_gate(fixture)
	_recommit_gate(fixture)
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"evidence_commit_parent_mismatch")


func test_sealed_pre_attach_rejects_an_executable_evidence_entry() -> void:
	_reject(_validate(_sealed_fixture("sealed-exec-mode", "SEALED_EXEC_MODE"), "SEALED_PRE_ATTACH"),
		&"evidence_commit_mode_invalid")


## Keeps the correct subject so only the working-versus-committed byte comparison can reject it.
func test_sealed_pre_attach_rejects_a_working_receipt_that_differs_from_the_committed_blob() -> void:
	var fixture: Dictionary = _sealed_fixture("sealed-receipt-bytes", "SEALED")
	_write_text(str(fixture["evidence_root_absolute"]).path_join("validation_receipt.json"),
		_canonical({"schema_version": 1, "subject_commit": str(fixture["subject_commit"]),
			"gate_sha256": str(fixture["gate_sha256"]), "validator_exit_code": 1}) + "\n")
	_reject(_validate(fixture, "SEALED_PRE_ATTACH"), &"validation_receipt_hash_mismatch")


## The committed receipt itself names another subject, so the byte comparison passes and only the
## subject binding can reject it.
func test_sealed_pre_attach_rejects_a_committed_receipt_naming_another_subject() -> void:
	_reject(_validate(_sealed_fixture("sealed-receipt-subject", "SEALED_WRONG_RECEIPT_SUBJECT"),
		"SEALED_PRE_ATTACH"), &"validation_receipt_subject_mismatch")


func test_sealed_pre_attach_rejects_an_attachment_already_in_the_preclose_baseline() -> void:
	_reject(_validate(_sealed_fixture("sealed-prenoted", "SEALED_PRENOTED"), "SEALED_PRE_ATTACH"),
		&"closeout_attachment_present")


func test_attached_pre_close_succeeds_with_exactly_one_canonical_note() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-success", "ATTACHED")
	var value: Dictionary = _accept(_validate(fixture, "ATTACHED_PRE_CLOSE"))
	if value.is_empty():
		return
	assert_eq(value.get("mode"), "ATTACHED_PRE_CLOSE")
	assert_eq(str((value["closeout_evidence"] as Dictionary)["evidence_commit"]),
		str(fixture["evidence_commit"]), "the same binding is returned")


func test_attached_pre_close_rejects_a_duplicate_note() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-duplicate", "ATTACHED")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID,
		{"notes": str(fixture["note_line"]) + "\n" + str(fixture["note_line"])})
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"closeout_attachment_duplicate")


func test_attached_pre_close_rejects_a_note_naming_another_evidence_commit() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-wrong-commit", "ATTACHED")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"notes": NOTE_PREFIX + _canonical(
		_note_payload(fixture, str(fixture["subject_commit"])))})
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"closeout_attachment_mismatch")


func test_attached_pre_close_rejects_a_noncanonical_note_payload() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-noncanonical", "ATTACHED")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID,
		{"notes": NOTE_PREFIX + " " + str(fixture["note_line"]).substr(NOTE_PREFIX.length())})
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"closeout_attachment_mismatch")


func test_attached_pre_close_rejects_a_missing_note() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-missing-note", "SEALED")
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"closeout_attachment_missing")


func test_attached_pre_close_rejects_a_closed_closeout_issue() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-closed", "CLOSED")
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"closeout_issue_not_open")


func test_attached_pre_close_rejects_a_delta_on_another_contract() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-other-delta", "ATTACHED")
	_mutate_issue(fixture, "dwm-p2r.13", {"notes": "an unauthorised note"})
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"preclose_snapshot_drift")


# =============================================================================================
# POST_CLOSE.
# =============================================================================================

func test_attached_pre_close_rejects_notes_that_replaced_rather_than_appended() -> void:
	var fixture: Dictionary = _sealed_fixture("attached-replaced-notes", "ATTACHED")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"notes": str(fixture["note_line"])})
	_reject(_validate(fixture, "ATTACHED_PRE_CLOSE"), &"closeout_attachment_not_appended")


func test_post_close_succeeds_once_all_sixteen_contracts_are_closed() -> void:
	var fixture: Dictionary = _sealed_fixture("postclose-success", "CLOSED")
	var value: Dictionary = _accept(_validate(fixture, "POST_CLOSE"))
	if value.is_empty():
		return
	assert_eq(value.get("mode"), "POST_CLOSE")
	for record: Dictionary in (value["child_contracts"] as Array):
		assert_eq(str(record["status"]), "closed",
			"%s must be closed in POST_CLOSE" % str(record["issue_id"]))


func test_post_close_flips_an_empty_evidence_set_to_satisfied_by_final_gate() -> void:
	var value: Dictionary = _accept(_validate(_sealed_fixture("postclose-verdict", "CLOSED"), "POST_CLOSE"))
	if value.is_empty():
		return
	var contract: Dictionary = _contract(value, "dwm-p2r.9")
	assert_eq(contract["evidence_links"], [], "the empty set is still physically empty after close")
	assert_eq(contract["evidence_verdict"], "satisfied_by_final_gate",
		"only POST_CLOSE may flip the derived verdict")


func test_post_close_rejects_a_premature_close_of_a_sibling_contract() -> void:
	var fixture: Dictionary = _sealed_fixture("postclose-open-sibling", "CLOSED")
	_mutate_issue(fixture, "dwm-p2r.13", {"status": "open"})
	_reject(_validate(fixture, "POST_CLOSE"), &"contract_record_open")


func test_post_close_rejects_a_wrong_close_reason() -> void:
	var fixture: Dictionary = _sealed_fixture("postclose-reason", "CLOSED")
	_mutate_issue(fixture, CLOSEOUT_ISSUE_ID, {"close_reason": "phase2r_closeout_v1 subject=wrong"})
	_reject(_validate(fixture, "POST_CLOSE"), &"close_reason_mismatch")


func test_post_close_rejects_a_missing_closed_at() -> void:
	var fixture: Dictionary = _sealed_fixture("postclose-no-closed-at", "CLOSED")
	(_issue(fixture, CLOSEOUT_ISSUE_ID) as Dictionary).erase("closed_at")
	_rewrite_snapshot(fixture)
	_reject(_validate(fixture, "POST_CLOSE"), &"preclose_snapshot_drift")


func test_post_close_rejects_an_unauthorised_delta_on_a_class_member() -> void:
	var fixture: Dictionary = _sealed_fixture("postclose-class-delta", "CLOSED")
	_mutate_issue(fixture, "dwm-p2r.7.1", {"close_reason": "rewritten"})
	_reject(_validate(fixture, "POST_CLOSE"), &"preclose_snapshot_drift")


func test_post_close_rejects_a_still_open_closeout_issue() -> void:
	var fixture: Dictionary = _sealed_fixture("postclose-still-open", "ATTACHED")
	_reject(_validate(fixture, "POST_CLOSE"), &"contract_record_open")


# =============================================================================================
# validate_export_equivalence.
# =============================================================================================

func test_export_equivalence_accepts_a_faithful_projection() -> void:
	var fixture: Dictionary = _export_fixture("export-success")
	var result: Dictionary = INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"]))
	assert_true(result.get("ok", false), str(result))


func test_export_equivalence_rejects_a_consistently_truncated_projection() -> void:
	var fixture: Dictionary = _export_fixture("export-truncated")
	var listing: Array = fixture["list"]
	for index: int in range(listing.size()):
		if str((listing[index] as Dictionary)["id"]) == "dwm-p2r.16":
			listing.remove_at(index)
			break
	_rewrite_list(fixture)
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_projection_incomplete")


func test_export_equivalence_rejects_a_wrong_type_marker() -> void:
	var fixture: Dictionary = _export_fixture("export-type")
	_rewrite_export(fixture, 0, {"_type": "issue_record"})
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_type_invalid")


func test_export_equivalence_rejects_an_inconsistent_parent_derivation() -> void:
	var fixture: Dictionary = _export_fixture("export-parent")
	for dependency: Variant in (_list_record(fixture, "dwm-p2r.13")["dependencies"] as Array):
		if str((dependency as Dictionary).get("type", "")) == "parent-child":
			(dependency as Dictionary)["depends_on_id"] = "dwm-p2r.9"
	_rewrite_list(fixture)
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_parent_inconsistent")


func test_export_equivalence_rejects_a_mutated_retained_field() -> void:
	var fixture: Dictionary = _export_fixture("export-field")
	_rewrite_export(fixture, 2, {"status": "open"})
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_record_mismatch")


func test_export_equivalence_rejects_a_missing_export_record() -> void:
	var fixture: Dictionary = _export_fixture("export-missing")
	var lines: Array = fixture["export_lines"]
	lines.remove_at(4)
	_write_text(str(fixture["export_path"]), "".join(PackedStringArray(lines)))
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_record_missing")


func test_export_equivalence_rejects_a_non_lf_terminated_export() -> void:
	var fixture: Dictionary = _export_fixture("export-unterminated")
	var text: String = FileAccess.get_file_as_string(str(fixture["export_path"]))
	_write_text(str(fixture["export_path"]), text.trim_suffix("\n"))
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_jsonl_malformed")


func test_export_equivalence_rejects_a_root_record_carrying_a_parent_dependency() -> void:
	var fixture: Dictionary = _export_fixture("export-root-parent")
	((_list_record(fixture, EPIC_ID)["dependencies"]) as Array).append({
		"issue_id": EPIC_ID, "depends_on_id": "dwm-p2r.1", "type": "parent-child"})
	_rewrite_list(fixture)
	_reject(INVENTORY.validate_export_equivalence(str(fixture["list_path"]),
		str(fixture["export_path"])), &"export_parent_inconsistent")


# =============================================================================================
# validate_final_epic_transition.
# =============================================================================================

func test_final_epic_transition_accepts_the_sole_permitted_epic_delta() -> void:
	var fixture: Dictionary = _transition_fixture("transition-success")
	var result: Dictionary = _transition(fixture)
	assert_true(result.get("ok", false), str(result))


func test_final_epic_transition_rejects_a_changed_attachment_hash() -> void:
	var fixture: Dictionary = _transition_fixture("transition-hash")
	var attachment: Dictionary = fixture["attachment"]
	attachment["postclose_export_sha256"] = _flip_hex(str(attachment["postclose_export_sha256"]))
	_rewrite_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_an_extra_attachment_key() -> void:
	var fixture: Dictionary = _transition_fixture("transition-extra-key")
	fixture["attachment"]["operator"] = "someone"
	_reseal_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_a_relocated_transition_path() -> void:
	var fixture: Dictionary = _transition_fixture("transition-relocated")
	fixture["attachment"]["postclose_inventory_path"] = "evidence/phase_2r/closeout/other.json"
	_reseal_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_a_wrong_attachment_schema_version() -> void:
	var fixture: Dictionary = _transition_fixture("transition-schema-version")
	fixture["attachment"]["schema_version"] = 2
	_reseal_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_a_digest_that_is_not_a_sha256() -> void:
	var fixture: Dictionary = _transition_fixture("transition-digest-shape")
	fixture["attachment"]["postclose_inventory_sha256"] = "not-a-digest"
	_reseal_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_a_wrong_contract_count() -> void:
	var fixture: Dictionary = _transition_fixture("transition-count")
	fixture["attachment"]["contract_count"] = 15
	_rewrite_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_a_wrong_verdict() -> void:
	var fixture: Dictionary = _transition_fixture("transition-verdict")
	fixture["attachment"]["verdict"] = "all_phase2r_contracts_verified"
	_rewrite_attachment(fixture)
	_reject(_transition(fixture), &"epic_attachment_mismatch")


func test_final_epic_transition_rejects_a_wrong_close_reason() -> void:
	var fixture: Dictionary = _transition_fixture("transition-reason")
	_final_record(fixture, EPIC_ID)["close_reason"] = "phase2r_epic_closeout_v1 contracts=16"
	_rewrite_final(fixture)
	_reject(_transition(fixture), &"epic_close_reason_mismatch")


func test_final_epic_transition_rejects_a_duplicate_epic_note() -> void:
	var fixture: Dictionary = _transition_fixture("transition-duplicate-note")
	var record: Dictionary = _final_record(fixture, EPIC_ID)
	record["notes"] = str(record["notes"]) + "\n" + str(fixture["epic_note_line"])
	_rewrite_final(fixture)
	_reject(_transition(fixture), &"epic_attachment_duplicate")


func test_final_epic_transition_rejects_a_delta_on_an_unrelated_issue() -> void:
	var fixture: Dictionary = _transition_fixture("transition-unrelated")
	_final_record(fixture, "dwm-p2r.13")["notes"] = "an unauthorised late edit"
	_rewrite_final(fixture)
	_reject(_transition(fixture), &"epic_transition_extra_delta")


func test_final_epic_transition_rejects_an_epic_left_open() -> void:
	var fixture: Dictionary = _transition_fixture("transition-open-epic")
	_final_record(fixture, EPIC_ID)["status"] = "open"
	_rewrite_final(fixture)
	_reject(_transition(fixture), &"epic_transition_status_invalid")


# =============================================================================================
# Schema conformance.
# =============================================================================================

func test_the_success_envelope_conforms_to_the_committed_schema() -> void:
	var result: Dictionary = _validate(_prerequisite_fixture("schema-conformance"), "PREREQUISITE")
	var value: Dictionary = _accept(result)
	if value.is_empty():
		return
	var validated: Dictionary = JSON_SCHEMA_VALIDATOR.validate(value, _read_strict_object(SCHEMA_PATH))
	assert_true(validated.get("ok", false), str(validated))


func test_the_populated_post_close_envelope_conforms_to_the_committed_schema() -> void:
	var value: Dictionary = _accept(_validate(_sealed_fixture("schema-postclose", "CLOSED"),
		"POST_CLOSE"))
	if value.is_empty():
		return
	var validated: Dictionary = JSON_SCHEMA_VALIDATOR.validate(value, _read_strict_object(SCHEMA_PATH))
	assert_true(validated.get("ok", false), str(validated))
	assert_false((value["requirement_evidence"] as Dictionary).is_empty(),
		"the populated envelope must actually carry a requirement mapping")


func test_the_committed_schema_is_closed_over_exactly_the_eight_envelope_keys() -> void:
	var schema: Dictionary = _read_strict_object(SCHEMA_PATH)
	assert_eq(schema.get("additionalProperties"), false, "the envelope schema is closed")
	var required: Array = (schema.get("required", []) as Array).duplicate()
	required.sort()
	assert_eq(required, ["child_contracts", "closeout_evidence", "closeout_issue_id",
		"deferred_requirements", "epic_id", "mode", "non_contract_children",
		"requirement_evidence"], "the schema requires exactly the eight envelope keys")


func test_the_committed_schema_pins_both_class_counts_separately() -> void:
	var properties: Dictionary = ((_read_strict_object(SCHEMA_PATH)["properties"] as Dictionary)
		["non_contract_children"] as Dictionary)["properties"]
	assert_eq((((properties["historical_helpers"] as Dictionary)["properties"] as Dictionary)["count"]
		as Dictionary)["const"], 2)
	assert_eq((((properties["execution_remediation_children"] as Dictionary)["properties"] as Dictionary)["count"]
		as Dictionary)["const"], 22)


# =============================================================================================
# Fixtures: prerequisite.
# =============================================================================================

func _prerequisite_fixture(name: String) -> Dictionary:
	var repository: String = _make_fixture_repository(name)
	var fixture: Dictionary = {
		"repository": repository,
		"metadata": _metadata_document.duplicate(true),
		"snapshot": _base_snapshot(),
		"metadata_path": repository.path_join("prompt_docs/metadata/phase_2r_beads.v1.json"),
		"requirement_index_path": repository.path_join("prompt_docs/INDEX.md"),
		"snapshot_path": repository.path_join("fixture-beads.json"),
		"evidence_root_absolute": repository.path_join(EVIDENCE_ROOT_RELATIVE),
	}
	_rewrite_metadata(fixture)
	_rewrite_snapshot(fixture)
	return fixture


func _validate(fixture: Dictionary, mode: Variant) -> Dictionary:
	return INVENTORY.validate(mode, str(fixture["metadata_path"]), str(fixture["snapshot_path"]),
		str(fixture["requirement_index_path"]), str(fixture["evidence_root_absolute"]))


func _make_fixture_repository(name: String) -> String:
	var destination: String = _scratch_root.path_join(name)
	if DirAccess.dir_exists_absolute(destination):
		_remove_tree(destination)
	if DirAccess.dir_exists_absolute(destination):
		assert_true(false, "a leftover fixture directory blocks the clone: " + destination)
		return destination
	var cloned: Dictionary = _run_git("", PackedStringArray(["clone", "--shared", "--no-checkout",
		"--no-tags", _repository_root, destination]))
	assert_true(cloned["ok"], "the fixture clone must succeed: %s" % str(cloned))
	assert_true(DirAccess.dir_exists_absolute(destination.path_join(".git")),
		"the fixture clone must have produced its own git directory: " + destination)
	if not cloned["ok"] or not DirAccess.dir_exists_absolute(destination.path_join(".git")):
		return destination
	var head: String = str(_run_git(destination, PackedStringArray(["rev-parse", "HEAD"]))["output"]).strip_edges()
	assert_true(head.length() == 40, "the fixture clone must resolve a full head: %s" % head)
	if head.length() != 40:
		return destination
	assert_true(_run_git(destination, PackedStringArray(["read-tree", head]))["ok"],
		"the fixture index must be populated from HEAD without a full checkout")
	var checkout: PackedStringArray = PackedStringArray(["checkout", head, "--"])
	checkout.append_array(PackedStringArray(FIXTURE_CHECKOUT_PATHS))
	assert_true(_run_git(destination, checkout)["ok"], "the fixture working files must materialise")
	_fixture_directories.append(destination)
	return destination


func _base_snapshot() -> Array:
	var records: Array = []
	records.append(_issue_record(EPIC_ID, "open", ""))
	for issue_id: String in CONTRACT_IDS:
		var parent: String = "" if issue_id == "dwm-wks" else EPIC_ID
		var status: String = "open" if issue_id == CLOSEOUT_ISSUE_ID else "closed"
		records.append(_issue_record(issue_id, status, parent))
	for issue_id: String in HISTORICAL_HELPER_IDS + EXECUTION_REMEDIATION_IDS:
		records.append(_issue_record(issue_id, "closed", EPIC_ID))
	for record: Variant in records:
		if str((record as Dictionary)["id"]) == CLOSEOUT_ISSUE_ID:
			(record as Dictionary)["notes"] = PRESERVED_NOTE
	return records


func _issue_record(issue_id: String, status: String, parent: String) -> Dictionary:
	var record: Dictionary = {
		"id": issue_id,
		"status": status,
		"parent": parent,
		"issue_type": "task",
		"priority": 0,
		"spec_id": SPEC_ID,
		"labels": ["phase-2r"],
		"notes": "",
		"metadata": {},
		"dependencies": [],
		"created_at": "2026-07-17T15:42:00Z",
		"updated_at": "2026-08-25T00:00:00Z",
	}
	if parent.is_empty():
		record.erase("parent")
	else:
		(record["dependencies"] as Array).append({"issue_id": issue_id, "depends_on_id": parent,
			"type": "parent-child"})
	if status == "closed":
		record["closed_at"] = "2026-08-25T00:00:00Z"
		record["close_reason"] = "fixture"
	var contract: Dictionary = _metadata_contract(issue_id)
	if not contract.is_empty():
		record["metadata"] = {"phase2r": (contract["expected_metadata"] as Dictionary).duplicate(true)}
		record["labels"] = (contract["expected_labels"] as Array).duplicate()
		record["spec_id"] = str(contract.get("expected_spec_id", ""))
	return record


# =============================================================================================
# Fixtures: sealed evidence.
# =============================================================================================

## stage is PRE_SEAL, SEALED, SEALED_WRONG_SUBJECT, SEALED_EXTRA_PATH, SEALED_MERGE, ATTACHED or
## CLOSED. Everything from SEALED onward commits a real evidence commit into the shared clone.
func _sealed_fixture(name: String, stage: String) -> Dictionary:
	var fixture: Dictionary = _prerequisite_fixture(name)
	fixture["subject_commit"] = str(_run_git(str(fixture["repository"]),
		PackedStringArray(["rev-parse", "HEAD"]))["output"]).strip_edges()
	fixture["write_receipt"] = stage != "PRE_SEAL"
	_write_evidence_tree(fixture)
	if stage == "PRE_SEAL":
		fixture["note_line"] = NOTE_PREFIX + _canonical(_note_payload(fixture,
			str(fixture["subject_commit"])))
		return fixture
	var subject: String = EVIDENCE_COMMIT_SUBJECT
	if stage == "SEALED_WRONG_SUBJECT":
		subject = "test(phase2r): record the closeout gate"
	if stage == "SEALED_WRONG_RECEIPT_SUBJECT":
		_write_text(str(fixture["evidence_root_absolute"]).path_join("validation_receipt.json"),
			_canonical({"schema_version": 1, "gate_sha256": str(fixture["gate_sha256"]),
				"subject_commit": str(_run_git(str(fixture["repository"]),
					PackedStringArray(["rev-parse", "HEAD~1"]))["output"]).strip_edges(),
				"validator_exit_code": 0}) + "\n")
	if stage == "SEALED_PRENOTED":
		_issue(fixture, CLOSEOUT_ISSUE_ID)["notes"] = PRESERVED_NOTE + "\n" + NOTE_PREFIX + "{}"
		_rewrite_snapshot(fixture)
		_write_evidence_tree(fixture)
	var paths: Array[String] = [EVIDENCE_ROOT_RELATIVE]
	if stage == "SEALED_EXTRA_PATH":
		_write_text(str(fixture["repository"]).path_join("prompt_docs/STRAY.md"), "stray\n")
		paths.append("prompt_docs/STRAY.md")
	_commit(fixture, subject, paths)
	if stage == "SEALED_MERGE":
		_make_merge_head(fixture)
	if stage == "SEALED_EXEC_MODE":
		var repository: String = str(fixture["repository"])
		assert_true(_run_git(repository, PackedStringArray(["update-index", "--chmod=+x", "--",
			EVIDENCE_ROOT_RELATIVE + "/logs/gut-complete.log"]))["ok"],
			"the fixture must be able to mark an evidence entry executable")
		assert_true(_run_git(repository, PackedStringArray(["commit", "-q", "--amend", "-m",
			EVIDENCE_COMMIT_SUBJECT]))["ok"], "the executable-mode evidence commit must amend")
	fixture["evidence_commit"] = str(_run_git(str(fixture["repository"]),
		PackedStringArray(["rev-parse", "HEAD"]))["output"]).strip_edges()
	fixture["note_line"] = NOTE_PREFIX + _canonical(_note_payload(fixture, str(fixture["evidence_commit"])))
	fixture["close_reason"] = "phase2r_closeout_v1 subject=%s evidence=%s gate=%s receipt=%s" % [
		str(fixture["subject_commit"]), str(fixture["evidence_commit"]),
		str(fixture["gate_sha256"]), str(fixture["receipt_sha256"])]
	if stage == "ATTACHED" or stage == "CLOSED":
		var closeout: Dictionary = _issue(fixture, CLOSEOUT_ISSUE_ID)
		closeout["notes"] = PRESERVED_NOTE + "\n" + str(fixture["note_line"])
		closeout["updated_at"] = "2026-08-25T01:00:00Z"
	if stage == "CLOSED":
		var closed: Dictionary = _issue(fixture, CLOSEOUT_ISSUE_ID)
		closed["status"] = "closed"
		closed["updated_at"] = "2026-08-25T02:00:00Z"
		closed["closed_at"] = "2026-08-25T02:00:00Z"
		closed["close_reason"] = str(fixture["close_reason"])
	_rewrite_snapshot(fixture)
	return fixture


func _write_evidence_tree(fixture: Dictionary) -> void:
	var root: String = str(fixture["evidence_root_absolute"])
	var preclose_text: String = FileAccess.get_file_as_string(str(fixture["snapshot_path"]))
	_write_text(root.path_join("preclose_beads_snapshot.json"), preclose_text)
	var command_records: Array = []
	var primary_logs: Array = []
	for command_id: String in COMMAND_IDS:
		var log_relative: String = "%s/logs/%s.log" % [EVIDENCE_ROOT_RELATIVE, command_id]
		var log_text: String = "%s: PASS\n" % command_id
		_write_text(str(fixture["repository"]).path_join(log_relative), log_text)
		var log_sha: String = _sha256_text(log_text)
		var record: Dictionary = {"command_id": command_id, "log_path": log_relative,
			"log_sha256": log_sha}
		record["sha256"] = _sha256_text(_canonical(record))
		command_records.append(record)
		primary_logs.append({"path": log_relative, "sha256": log_sha})
	fixture["command_records"] = command_records
	_write_text(root.path_join("logs/phase2r-closeout-validate.log"), "phase2r-closeout-validate: PASS\n")
	if bool(fixture["write_receipt"]):
		_write_text(root.path_join("logs/validation-command.jsonl"), "{\"schema_version\":1}\n")
	_write_text(root.path_join("contract_inventory.json"), "{\"schema_version\":1}\n")
	var mapping: Dictionary = {}
	for requirement_id: String in _expected_requirement_ids():
		mapping[requirement_id] = [_record_for(command_records, "gut-complete")]
	var gate: Dictionary = {
		"schema_version": 1,
		"subject_commit": str(fixture["subject_commit"]),
		"preclose_beads_snapshot_sha256": _sha256_text(preclose_text),
		"non_contract_children": {
			"historical_helpers": {"count": 2, "ids": HISTORICAL_HELPER_IDS.duplicate()},
			"execution_remediation_children": {"count": 22, "ids": EXECUTION_REMEDIATION_IDS.duplicate()},
		},
		"generated_paths": _projected_generated_paths(),
		"requirement_evidence": mapping,
		"command_records": command_records,
		"primary_logs": primary_logs,
	}
	fixture["gate"] = gate
	_rewrite_gate(fixture)
	_write_receipt(fixture)


func _projected_generated_paths() -> Array:
	var paths: Array = [
		"%s/contract_inventory.json" % EVIDENCE_ROOT_RELATIVE,
		"%s/gate.json" % EVIDENCE_ROOT_RELATIVE,
		"%s/logs/phase2r-closeout-validate.log" % EVIDENCE_ROOT_RELATIVE,
		"%s/logs/validation-command.jsonl" % EVIDENCE_ROOT_RELATIVE,
		"%s/preclose_beads_snapshot.json" % EVIDENCE_ROOT_RELATIVE,
		"%s/validation_receipt.json" % EVIDENCE_ROOT_RELATIVE,
	]
	for command_id: String in COMMAND_IDS:
		paths.append("%s/logs/%s.log" % [EVIDENCE_ROOT_RELATIVE, command_id])
	paths.sort()
	return paths


func _rewrite_gate(fixture: Dictionary) -> void:
	var text: String = _canonical(fixture["gate"]) + "\n"
	_write_text(str(fixture["evidence_root_absolute"]).path_join("gate.json"), text)
	fixture["gate_sha256"] = _sha256_text(text)
	_write_receipt(fixture)


func _write_receipt(fixture: Dictionary) -> void:
	var receipt: Dictionary = {
		"schema_version": 1,
		"subject_commit": str(fixture["subject_commit"]),
		"gate_sha256": str(fixture["gate_sha256"]),
		"validator_exit_code": 0,
	}
	var text: String = _canonical(receipt) + "\n"
	if bool(fixture["write_receipt"]):
		_write_text(str(fixture["evidence_root_absolute"]).path_join("validation_receipt.json"), text)
	fixture["receipt_sha256"] = _sha256_text(text)


func _recommit_gate(fixture: Dictionary) -> void:
	var repository: String = str(fixture["repository"])
	assert_true(_run_git(repository, PackedStringArray(["add", "--", EVIDENCE_ROOT_RELATIVE]))["ok"],
		"the amended evidence must stage")
	assert_true(_run_git(repository, PackedStringArray(["commit", "-q", "--amend", "-m",
		EVIDENCE_COMMIT_SUBJECT]))["ok"], "the evidence commit must amend in place")
	fixture["evidence_commit"] = str(_run_git(repository,
		PackedStringArray(["rev-parse", "HEAD"]))["output"]).strip_edges()
	fixture["note_line"] = NOTE_PREFIX + _canonical(_note_payload(fixture,
		str(fixture["evidence_commit"])))


func _commit(fixture: Dictionary, subject: String, paths: Array[String]) -> void:
	var repository: String = str(fixture["repository"])
	var add: PackedStringArray = PackedStringArray(["add", "--"])
	add.append_array(PackedStringArray(paths))
	assert_true(_run_git(repository, add)["ok"], "the fixture must stage its evidence")
	var committed: Dictionary = _run_git(repository, PackedStringArray(["commit", "-q", "-m", subject]))
	assert_true(committed["ok"], "the fixture commit must succeed: %s" % str(committed))


func _make_merge_head(fixture: Dictionary) -> void:
	var repository: String = str(fixture["repository"])
	var evidence: String = str(_run_git(repository, PackedStringArray(["rev-parse", "HEAD"]))["output"]).strip_edges()
	var subject: String = str(fixture["subject_commit"])
	var tree: String = str(_run_git(repository, PackedStringArray(["rev-parse", "HEAD^{tree}"]))["output"]).strip_edges()
	var merged: String = str(_run_git(repository, PackedStringArray(["commit-tree", tree,
		"-p", evidence, "-p", subject, "-m", EVIDENCE_COMMIT_SUBJECT]))["output"]).strip_edges()
	assert_true(merged.length() == 40, "the fixture merge commit must be created: %s" % merged)
	assert_true(_run_git(repository, PackedStringArray(["reset", "--soft", merged]))["ok"],
		"the fixture head must move to the merge commit")


func _note_payload(fixture: Dictionary, evidence_commit: String) -> Dictionary:
	return {
		"schema_version": 1,
		"subject_commit": str(fixture["subject_commit"]),
		"evidence_commit": evidence_commit,
		"gate_sha256": str(fixture["gate_sha256"]),
		"validation_receipt_sha256": str(fixture["receipt_sha256"]),
	}


func _evidence_record(fixture: Dictionary, command_id: String) -> Dictionary:
	return _record_for(fixture["command_records"], command_id)


func _record_for(command_records: Array, command_id: String) -> Dictionary:
	for record: Dictionary in command_records:
		if str(record["command_id"]) == command_id:
			return {"command_id": command_id, "command_record_sha256": str(record["sha256"]),
				"log_path": str(record["log_path"]), "log_sha256": str(record["log_sha256"])}
	return {}


# =============================================================================================
# Fixtures: export equivalence and the final epic transition.
# =============================================================================================

func _export_fixture(name: String) -> Dictionary:
	var directory: String = _scratch_root.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	_fixture_directories.append(directory)
	var fixture: Dictionary = {
		"directory": directory,
		"list": _base_snapshot(),
		"list_path": directory.path_join("postclose-beads.json"),
		"export_path": directory.path_join("postclose-issues.jsonl"),
	}
	_rewrite_list(fixture)
	return fixture


func _rewrite_list(fixture: Dictionary) -> void:
	_write_text(str(fixture["list_path"]), JSON.stringify(fixture["list"]) + "\n")
	var lines: Array = []
	for record: Dictionary in (fixture["list"] as Array):
		var projected: Dictionary = record.duplicate(true)
		projected.erase("parent")
		projected["_type"] = "issue"
		lines.append(_canonical(projected) + "\n")
	fixture["export_lines"] = lines
	_write_text(str(fixture["export_path"]), "".join(PackedStringArray(lines)))


func _rewrite_export(fixture: Dictionary, index: int, changes: Dictionary) -> void:
	var lines: Array = fixture["export_lines"]
	var parsed: Dictionary = STRICT_JSON.parse_object(str(lines[index]).strip_edges())
	var record: Dictionary = parsed.get("value", {})
	for key: String in changes:
		record[key] = changes[key]
	lines[index] = _canonical(record) + "\n"
	_write_text(str(fixture["export_path"]), "".join(PackedStringArray(lines)))


func _list_record(fixture: Dictionary, issue_id: String) -> Dictionary:
	for record: Variant in (fixture["list"] as Array):
		if str((record as Dictionary).get("id", "")) == issue_id:
			return record
	assert_true(false, "the fixture list must contain " + issue_id)
	return {}


func _transition_fixture(name: String) -> Dictionary:
	var directory: String = _scratch_root.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	_fixture_directories.append(directory)
	var postclose: Array = _base_snapshot()
	for record: Variant in postclose:
		if str((record as Dictionary).get("id", "")) == CLOSEOUT_ISSUE_ID:
			(record as Dictionary)["status"] = "closed"
			(record as Dictionary)["closed_at"] = "2026-08-25T02:00:00Z"
			(record as Dictionary)["close_reason"] = "phase2r_closeout_v1"
	var attachment: Dictionary = {
		"schema_version": 1,
		"postclose_inventory_path": "evidence/phase_2r/closeout/transitions/postclose-beads.json",
		"postclose_inventory_sha256": _sha256_text("inventory\n"),
		"postclose_export_path": "evidence/phase_2r/closeout/transitions/postclose-issues.jsonl",
		"postclose_export_sha256": "",
		"postclose_validation_log_path": "evidence/phase_2r/closeout/transitions/postclose-validation.log",
		"postclose_validation_log_sha256": _sha256_text("validation\n"),
		"contract_count": 16,
		"verdict": "all_phase2r_contracts_closed",
	}
	var fixture: Dictionary = {
		"directory": directory,
		"postclose": postclose,
		"attachment": attachment,
		"postclose_path": directory.path_join("postclose-issues.jsonl"),
		"final_path": directory.path_join("final-issues.jsonl"),
		"attachment_path": directory.path_join("epic-attachment.json"),
	}
	var postclose_text: String = _jsonl(postclose)
	_write_text(str(fixture["postclose_path"]), postclose_text)
	attachment["postclose_export_sha256"] = _sha256_text(postclose_text)
	var epic_note: String = EPIC_NOTE_PREFIX + _canonical(attachment)
	fixture["epic_note_line"] = epic_note
	var final_records: Array = []
	for record: Dictionary in postclose:
		var copy: Dictionary = record.duplicate(true)
		if str(copy["id"]) == EPIC_ID:
			copy["notes"] = epic_note
			copy["status"] = "closed"
			copy["updated_at"] = "2026-08-25T03:00:00Z"
			copy["closed_at"] = "2026-08-25T03:00:00Z"
			copy["close_reason"] = ("phase2r_epic_closeout_v1 postclose_export=%s postclose_log=%s "
				+ "contracts=16") % [str(attachment["postclose_export_sha256"]),
				str(attachment["postclose_validation_log_sha256"])]
		final_records.append(copy)
	fixture["final"] = final_records
	_rewrite_final(fixture)
	_rewrite_attachment(fixture)
	return fixture


func _rewrite_final(fixture: Dictionary) -> void:
	_write_text(str(fixture["final_path"]), _jsonl(fixture["final"]))


## Rewrites the attachment AND the epic note derived from it, so an attachment mutation stays
## internally consistent and is rejected only by the closed key set and pinned path constants.
func _reseal_attachment(fixture: Dictionary) -> void:
	_rewrite_attachment(fixture)
	var attachment: Dictionary = fixture["attachment"]
	var line: String = EPIC_NOTE_PREFIX + _canonical(attachment)
	fixture["epic_note_line"] = line
	var epic: Dictionary = _final_record(fixture, EPIC_ID)
	epic["notes"] = line
	epic["close_reason"] = ("phase2r_epic_closeout_v1 postclose_export=%s postclose_log=%s "
		+ "contracts=16") % [str(attachment.get("postclose_export_sha256", "")),
		str(attachment.get("postclose_validation_log_sha256", ""))]
	_rewrite_final(fixture)


func _rewrite_attachment(fixture: Dictionary) -> void:
	_write_text(str(fixture["attachment_path"]), _canonical(fixture["attachment"]) + "\n")


func _final_record(fixture: Dictionary, issue_id: String) -> Dictionary:
	for record: Variant in (fixture["final"] as Array):
		if str((record as Dictionary).get("id", "")) == issue_id:
			return record
	assert_true(false, "the fixture final export must contain " + issue_id)
	return {}


func _transition(fixture: Dictionary) -> Dictionary:
	return INVENTORY.validate_final_epic_transition(str(fixture["postclose_path"]),
		str(fixture["final_path"]), str(fixture["attachment_path"]))


func _jsonl(records: Array) -> String:
	var lines: Array = []
	for record: Dictionary in records:
		var projected: Dictionary = record.duplicate(true)
		projected.erase("parent")
		projected["_type"] = "issue"
		lines.append(_canonical(projected) + "\n")
	return "".join(PackedStringArray(lines))


# =============================================================================================
# Assertion and mutation helpers.
# =============================================================================================

func _accept(result: Dictionary) -> Dictionary:
	assert_true(result.get("ok", false), str(result))
	return result.get("value", {}) if result.get("ok", false) else {}


func _reject(result: Dictionary, expected_code: StringName) -> void:
	assert_false(result.get("ok", true), "expected %s, got a success" % expected_code)
	assert_ne(result.get("code"), &"not_implemented", "the seam must be implemented")
	assert_eq(result.get("code"), expected_code,
		"expected %s, got %s: %s" % [expected_code, str(result.get("code")), str(result)])


func _contract_ids(value: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for record: Dictionary in (value["child_contracts"] as Array):
		ids.append(str(record["issue_id"]))
	return ids


func _contract(value: Dictionary, issue_id: String) -> Dictionary:
	for record: Dictionary in (value["child_contracts"] as Array):
		if str(record["issue_id"]) == issue_id:
			return record
	assert_true(false, "the envelope must report " + issue_id)
	return {}


func _contract_metadata(fixture: Dictionary, issue_id: String) -> Dictionary:
	for contract: Variant in ((fixture["metadata"] as Dictionary)["child_contracts"] as Array):
		if str((contract as Dictionary).get("issue_id", "")) == issue_id:
			return contract
	assert_true(false, "the fixture metadata must contain " + issue_id)
	return {}


func _historical_link(fixture: Dictionary) -> Dictionary:
	var links: Array = _contract_metadata(fixture, HISTORICAL_INDEX_OWNER)["expected_metadata"]["evidence_links"]
	for link: Variant in links:
		if str((link as Dictionary).get("path", "")) == HISTORICAL_INDEX_PATH:
			return link
	assert_true(false, "the fixture metadata must declare the historical INDEX.md link")
	return {}


func _metadata_contract(issue_id: String) -> Dictionary:
	for contract: Dictionary in (_metadata_document.get("child_contracts", []) as Array):
		if str(contract.get("issue_id", "")) == issue_id:
			return contract
	return {}


func _issue(fixture: Dictionary, issue_id: String) -> Dictionary:
	for record: Variant in (fixture["snapshot"] as Array):
		if str((record as Dictionary).get("id", "")) == issue_id:
			return record
	assert_true(false, "the fixture snapshot must contain " + issue_id)
	return {}


func _mutate_issue(fixture: Dictionary, issue_id: String, changes: Dictionary) -> void:
	var record: Dictionary = _issue(fixture, issue_id)
	for key: String in changes:
		record[key] = changes[key]
	_rewrite_snapshot(fixture)


func _drop_issue(fixture: Dictionary, issue_id: String) -> void:
	var snapshot: Array = fixture["snapshot"]
	for index: int in range(snapshot.size()):
		if str((snapshot[index] as Dictionary).get("id", "")) == issue_id:
			snapshot.remove_at(index)
			break
	_rewrite_snapshot(fixture)


func _rewrite_snapshot(fixture: Dictionary) -> void:
	_write_text(str(fixture["snapshot_path"]), JSON.stringify(fixture["snapshot"]) + "\n")


func _rewrite_metadata(fixture: Dictionary) -> void:
	_write_text(str(fixture["metadata_path"]), JSON.stringify(fixture["metadata"]) + "\n")


func _expected_requirement_ids() -> Array[String]:
	var union: Dictionary = {}
	for contract: Dictionary in (_metadata_document.get("child_contracts", []) as Array):
		for requirement_id: String in ((contract["expected_metadata"] as Dictionary)["requirement_ids"] as Array):
			if not DEFERRED_REQUIREMENT_IDS.has(requirement_id) and not requirement_id.begins_with("req.ending."):
				union[requirement_id] = true
	var ids: Array[String] = []
	for requirement_id: String in union:
		ids.append(requirement_id)
	ids.sort()
	return ids


func _indexed_requirement_ids() -> Dictionary:
	var indexed: Dictionary = {}
	for line: String in FileAccess.get_file_as_string("res://" + HISTORICAL_INDEX_PATH).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("| `req."):
			continue
		var closing: int = trimmed.find("`", 3)
		if closing > 3:
			indexed[trimmed.substr(3, closing - 3)] = true
	return indexed


# =============================================================================================
# Local primitives, deliberately independent of the validator's own.
# =============================================================================================

func _globalized_repository_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


func _run_git(working_directory: String, arguments: PackedStringArray) -> Dictionary:
	var full: PackedStringArray = PackedStringArray(["-c", "core.longpaths=true"])
	if working_directory.is_empty():
		## An empty working directory carries no --git-dir/--work-tree, so git resolves upward
		## to the repository under test. `clone` is the sole legitimate uncontained call,
		## because its repository does not exist yet; every other one fails closed here rather
		## than relying on each call site to remember to pass a path.
		if arguments.is_empty() or arguments[0] != "clone":
			return {"ok": false, "exit_code": -1,
				"output": "GIT_WORKING_DIRECTORY_REQUIRED: " + " ".join(arguments)}
	else:
		## --git-dir/--work-tree are the containment. Without them git walks up out of a missing
		## fixture directory and silently targets the repository under test.
		full.append_array(PackedStringArray(["-c", "safe.directory=%s" % working_directory,
			"--git-dir=%s" % working_directory.path_join(".git"),
			"--work-tree=%s" % working_directory, "-C", working_directory]))
	full.append_array(PackedStringArray(["-c", "user.name=phase2r-fixture",
		"-c", "user.email=phase2r-fixture@dwm.local"]))
	full.append_array(arguments)
	var output: Array = []
	var exit_code: int = OS.execute("git", full, output, true)
	return {"ok": exit_code == 0, "exit_code": exit_code,
		"output": "".join(PackedStringArray(output))}


func _canonical(value: Variant) -> String:
	var written: Dictionary = CANONICAL_JSON.stringify(value)
	assert_true(written.get("ok", false), "the fixture value must be canonicalisable: %s" % str(written))
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


func _read_strict_object(path: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	assert_true(parsed.get("ok", false), "%s must be strict JSON: %s" % [path, str(parsed)])
	return parsed.get("value", {})


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
