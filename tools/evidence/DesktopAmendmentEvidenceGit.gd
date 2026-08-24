class_name DesktopAmendmentEvidenceGit
extends RefCounted

## Shared git/hash plumbing for DesktopAmendmentContractEvidence.gd and
## MinesweeperAmendmentContractEvidence.gd (dwm-p2r.32 Plan 02 Task 9). Extracted so neither
## evidence builder reaches into the other's internals; both depend on this one small, honest
## utility instead. Mirrors tools/schedule/generate_schedule_v3_boundary.gd's own git-plumbing
## functions exactly (same commands, same cmd.exe file-redirect route for quote safety, same
## OS.execute() line-decoding caveat), just shared rather than duplicated a third time.

const REQUIREMENT_IDS: Array[String] = [
	"req.desktop.cross_app_actions", "req.desktop.logout", "req.minesweeper.board_lifecycle",
	"req.minesweeper.causal_departure", "req.minesweeper.phase_boundary",
	"req.minesweeper.rng_isolation", "req.minesweeper.round_contract",
	"req.minesweeper.safety_capabilities", "req.save.desktop_board_continuity",
	"req.test.desktop_amendment_gate",
]

## Not papered over with a fake: each entry names a genuine production gap this amendment leaves
## fail-closed, the evidence for it, and which test(s) assert the fail-closed behavior so a later
## change cannot silently regress it into a fake without a test failing first. Shared by both
## evidence documents since both describe the same amendment.
static func honest_gaps() -> Array:
	return [
		{
			"gap_id": "round_coordinator_generation_and_checkpoint_adapter_missing",
			"summary": "MinesweeperRoundCoordinator's base configure(state_port, checkpoint_port, " \
				+ "generation_port, identity_issuer) is never called in production: no class " \
				+ "anywhere implements seal_checkpoint (Task-5-shaped checkpoint_port) or " \
				+ "materialize/begin_search/run_search_slice (generation_port).",
			"evidence": "grep -rn \"func seal_checkpoint\" scripts/ matches only " \
				+ "tests/support/FakeMinesweeperCheckpointPort.gd; MinesweeperBoardGenerator.gd " \
				+ "exposes materialize_first_reveal/begin_debug/run_debug_slice instead",
			"asserted_by": ["test_desktop_action_matrix.gd", "test_desktop_simulator_authority.gd"],
		},
		{
			"gap_id": "desktop_identity_context_is_a_boot_time_placeholder",
			"summary": "GameStateDesktopBoardPort/GameStateMinesweeperShopPort are configured with " \
				+ "a fixed run_id/branch_id (real, issuer-minted) plus honestly blank " \
				+ "desktop_timeline_generation=0/causal_day_instance=\"\", never a live per-run " \
				+ "identity; configure() refuses reconfiguration so this cannot rotate per New Run. " \
				+ "CONCRETELY, NOT JUST THEORETICALLY: this blocks Shop purchases too, not only board " \
				+ "reveal. MinesweeperShopPurchaseParticipant._build_action_receipt() reads " \
				+ "run_id/branch_id/desktop_timeline_generation/causal_day_instance from " \
				+ "GameStateMinesweeperShopPort.capture()'s facts (this placeholder), never from " \
				+ "DesktopConsequenceState's own live causal_day_instance -- so even a fully seeded, " \
				+ "otherwise-valid DesktopConsequenceState cannot make prepare_purchase() succeed: " \
				+ "DesktopActionReceipt.validate() rejects the blank causal_day_instance every time, " \
				+ "verified directly against the real production graph in " \
				+ "test_desktop_action_matrix.gd. quote() itself is unaffected (it never reads the " \
				+ "identity context), so registry/price/currency/quote_id contracts remain provable.",
			"evidence": "DesktopIdentityNonceIssuer.issue() refuses GENERATION_PURPOSE and " \
				+ "CAUSAL_DAY_PURPOSE directly (allocator-only); neither port is in Task 9's own Files " \
				+ "list; MinesweeperShopPurchaseParticipant.gd:685 builds the action candidate's " \
				+ "causal_day_instance from facts[\"causal_day_instance\"], not live_state's",
			"asserted_by": ["test_desktop_action_matrix.gd", "test_desktop_simulator_authority.gd"],
		},
		{
			"gap_id": "logout_coordinator_stable_board_port_missing",
			"summary": "LogoutCoordinator is never constructed: no production class implements " \
				+ "stable_board_port's is_slice_executing()/capture_stable_board() contract.",
			"evidence": "grep -rn \"capture_stable_board|is_slice_executing\" the whole repository " \
				+ "matches only LogoutCoordinator.gd's own contract comment and its unit test",
			"asserted_by": ["test_desktop_simulator_authority.gd"],
		},
		{
			"gap_id": "new_run_empty_profile_patch_fails_closed",
			"summary": "SaveManager.start_new_run() can never complete against a real ProfileManager: " \
				+ "it hardcodes plans[\"profile\"] = {\"profile\": {}} (the literal empty dict, never " \
				+ "the persisted profile.json, and never routed through ProfileRestoreParticipant." \
				+ "prepare() the way the ordinary restore path uses it), and ProfileManager." \
				+ "apply_restore_silent() has no no-op path for an empty candidate despite its own " \
				+ "adjacent comment's stated intent (\"Empty profile patch preserves the complete " \
				+ "global profile for a new game\") -- it always runs the empty dict through " \
				+ "ProfileSchema.validate()'s exact-7-key check, which always fails. The SAME pattern " \
				+ "(a hardcoded, caller-independent literal that bypasses .prepare() and cannot " \
				+ "satisfy its own participant's real validator) also blocks plans[\"localization\"] " \
				+ "= {} immediately afterward -- LocalizationManager._is_restore_plan_valid({}) " \
				+ "requires canonical_locale_id/bundle/presentation_profile/root_plans, none of which " \
				+ "an empty dict carries -- confirmed by code reading, not exercised live since the " \
				+ "profile failure (participant order: run, desktop_consequence, desktop_board, " \
				+ "PROFILE, localization, audio, route, narrative) is always reached first. NOT fixed " \
				+ "by Task 9. Note for the record: autoload/SaveManager.gd IS one of Task 9's own " \
				+ "authorized Modify targets per the brief's Files list (unlike autoload/" \
				+ "ProfileManager.gd and autoload/LocalizationManager.gd, which are not), so this is " \
				+ "not blocked by file ownership the way gaps 1-3 are -- it is left unfixed because " \
				+ "the correct fix is a real design decision (what locale/profile a brand-new run " \
				+ "should start from, including the no-prior-profile.json case) that the brief's own " \
				+ "prose never specifies, not a mechanical wiring gap. Newly discovered because every " \
				+ "prior test of start_new_run() (test_new_run_transaction.gd, test_save_manager.gd) " \
				+ "wires FAKE participants for every key; Task 9's crash-recovery suite is the first " \
				+ "to drive it through the complete real production graph.",
			"evidence": "ProfileSchema.gd:87 (validate's 7-key _require_keys call), 216-220 " \
				+ "(_require_keys itself); ProfileManager.gd:246-253 (apply_restore_silent, no " \
				+ "emptiness special-case); LocalizationManager.gd:391-392 (_is_restore_plan_valid's " \
				+ "4-key has_all check); SaveManager.gd:79 (profile fourth in " \
				+ "_PARTICIPANT_APPLY_ORDER), 393-394 (the hardcoded {\"profile\": {}} and {} " \
				+ "literals) -- verified directly against the real production graph in " \
				+ "test_desktop_crash_recovery.gd",
			"asserted_by": ["test_desktop_crash_recovery.gd"],
		},
	]


static func is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for byte: int in value.to_utf8_buffer():
		var decimal: bool = byte >= 48 and byte <= 57
		var lower_af: bool = byte >= 97 and byte <= 102
		if not decimal and not lower_af:
			return false
	return true


static func is_sha256(value: String) -> bool:
	return is_lower_hex(value, 64)


static func is_commit_id(value: String) -> bool:
	return is_lower_hex(value, 40)


static func git_run(repository_root: String, arguments: PackedStringArray) -> Dictionary:
	var full: PackedStringArray = PackedStringArray(["-c", "safe.directory=%s" % repository_root,
		"-C", repository_root])
	full.append_array(arguments)
	var output: Array = []
	var exit_code: int = OS.execute("git", full, output, false)
	return {"ok": exit_code == 0, "exit_code": exit_code, "output": "".join(PackedStringArray(output))}


static func commit_subject(repository_root: String, commit: String) -> Dictionary:
	var shown: Dictionary = git_run(repository_root, PackedStringArray(["show", "-s", "--format=%s", commit]))
	if not shown.get("ok", false):
		return {"ok": false, "code": &"commit_unreadable", "message": "the commit cannot be read",
			"details": {"commit": commit}}
	return {"ok": true, "code": &"ok", "value": {"subject": str(shown["output"]).strip_edges()}, "receipt": {}}


static func digest_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## Reads a blob's exact bytes from a named commit through a process-local scratch file, since
## OS.execute() decodes stdout into lines with separators dropped and cannot reproduce arbitrary
## binary/multi-line source bytes faithfully (mirrors generate_schedule_v3_boundary.gd's own
## blob_bytes_at_commit() exactly, including the cmd.exe file-redirect route for quote safety).
static func blob_bytes_at_commit(repository_root: String, commit: String, path: String) -> Dictionary:
	var object_name: String = "%s:%s" % [commit, path]
	var scratch: String = OS.get_user_data_dir().path_join("p2r9-amendment-blob-%d-%s.tmp" % [
		OS.get_process_id(), digest_bytes(object_name.to_utf8_buffer()).substr(0, 16),
	])
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var windows: bool = OS.get_name() == "Windows"
	var shell: String = "cmd.exe" if windows else "sh"
	var shell_flag: String = "/c" if windows else "-c"
	var command: String = "git -c safe.directory=\"%s\" -C \"%s\" cat-file blob \"%s\" > \"%s\"" % [
		repository_root, repository_root, object_name, scratch,
	]
	var output: Array = []
	var exit_code: int = OS.execute(shell, PackedStringArray([shell_flag, command]), output, true)
	if exit_code != 0 or not FileAccess.file_exists(scratch):
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(scratch)
		return {"ok": false, "code": &"blob_missing", "message": "the object is absent from the named commit",
			"details": {"object": object_name}}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	DirAccess.remove_absolute(scratch)
	return {"ok": true, "code": &"ok", "value": {"bytes": bytes}, "receipt": {}}


const CURATED_LOG_DIRECTORY := "evidence/phase_2r/logs/"

## The curated, permanent red/green proof this amendment binds. Every name here is a verbatim
## copy of the run that produced it, kept under its original run name so the record traces back
## to a real command, and every one is read FROM THE SUBJECT COMMIT'S TREE like every other
## binding in this file -- never off the working tree, which would re-bind itself every time the
## logs directory lawfully changes.
##
## THE SET IS A RED AND ITS GREEN, NOT A PILE OF GREENS. p2r9-bootstrap-wiring-check.log is the
## genuine RED for tests/integration/test_desktop_bootstrap_wiring.gd (18 tests, none passing);
## p2r9-bootstrap-wiring-check3.log is the same suite's GREEN (18/18); p2r9-bootstrap-regression.log
## is the nine-suite regression that proves the fix broke nothing. A field named
## red_green_command_records whose every record carried exit_code 0 would make a parsed exit code
## indistinguishable from the hardcoded one this replaces.
##
## WHY p2r9-desktop-amendment-gate.log IS NOT HERE (dwm-p2r.35.5). The only surviving copy of it,
## in the transient .godot/phase2r_logs/ directory it was written to, is TRUNCATED: it stops in
## the middle of listing res://tests/unit/test_desktop_continuation_operation_journal.gd's tests,
## with no Totals block and no terminal verdict, so its outcome is simply unknown. It is not bound
## because a log nobody can vouch for is not evidence, and it is not regenerated under its own
## p2r9 name because a re-run today would record this branch's tip, not the P2R9 state that name
## claims. parse_gut_log_exit_code() below refuses that exact shape rather than recording it as a
## pass.
const RED_GREEN_LOG_NAMES: Array[String] = [
	"p2r9-bootstrap-regression.log",
	"p2r9-bootstrap-wiring-check.log",
	"p2r9-bootstrap-wiring-check3.log",
]

const _SUMMARY_BANNER := "= Run Summary"
const _ALL_PASSED_VERDICT := "---- All tests passed! ----"

## Derives a bound log's REAL outcome from its own bytes. A complete GUT run always ends with a
## Run Summary banner, a Totals block and exactly one terminal verdict line; a run that was killed
## or whose file was clobbered mid-write has none of them, and is refused here instead of being
## recorded as exit_code 0. Note GUT prints the word "none", not "0", for a zero count, and omits
## the Failing Tests line entirely when nothing failed -- which is why this is a parse and not a
## substring search. Pending/risky tests are not failures: GUT exits 0 for them, so passing <
## tests with no failures is a lawful zero.
static func parse_gut_log_exit_code(bytes: PackedByteArray) -> Dictionary:
	var text: String = bytes.get_string_from_utf8()
	var banner_at: int = text.rfind(_SUMMARY_BANNER)
	if banner_at < 0:
		return {"ok": false, "code": &"red_green_log_incomplete",
			"message": "the log carries no GUT run summary", "details": {}}
	var tests: int = -1
	var passing: int = -1
	var failing: int = 0
	var verdict: String = ""
	for raw_line: String in text.substr(banner_at).split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("Tests "):
			tests = _summary_count(line, "Tests")
		elif line.begins_with("Passing Tests "):
			passing = _summary_count(line, "Passing Tests")
		elif line.begins_with("Failing Tests "):
			failing = _summary_count(line, "Failing Tests")
		elif line.begins_with("---- ") and line.ends_with(" ----"):
			verdict = line
	if tests < 0 or passing < 0 or failing < 0:
		return {"ok": false, "code": &"red_green_log_incomplete",
			"message": "the run summary has no readable totals block", "details": {}}
	if verdict.is_empty():
		return {"ok": false, "code": &"red_green_log_incomplete",
			"message": "the log stops before GUT's terminal verdict", "details": {}}
	if (verdict == _ALL_PASSED_VERDICT) != (failing == 0 and passing == tests):
		return {"ok": false, "code": &"red_green_log_inconsistent",
			"message": "the terminal verdict contradicts the totals block",
			"details": {"verdict": verdict, "tests": tests, "passing_tests": passing,
				"failing_tests": failing}}
	return {"ok": true, "code": &"ok", "value": {"exit_code": 0 if failing == 0 else 1,
		"tests": tests, "passing_tests": passing, "failing_tests": failing}, "receipt": {}}


static func _summary_count(line: String, label: String) -> int:
	var tail: String = line.substr(label.length()).strip_edges()
	if tail == "none":
		return 0
	if not tail.is_valid_int():
		return -1
	return tail.to_int()


## Every bound log must resolve in the subject commit's tree and must carry a complete, self-
## consistent GUT summary. A name that no longer resolves fails the whole build closed; the
## previous revision skipped it silently, which is how both sealed documents came to carry an
## empty record set while --check still reported OK (dwm-p2r.35.5, reviewer finding B-C5).
static func build_red_green_command_records(repository_root: String, subject_commit: String) -> Dictionary:
	if RED_GREEN_LOG_NAMES.is_empty():
		return {"ok": false, "code": &"red_green_command_records_empty",
			"message": "no red/green log is bound at all", "details": {}}
	var records: Array = []
	for name: String in RED_GREEN_LOG_NAMES:
		var relative: String = CURATED_LOG_DIRECTORY + name
		var blob: Dictionary = blob_bytes_at_commit(repository_root, subject_commit, relative)
		if not blob.get("ok", false):
			return {"ok": false, "code": &"red_green_log_missing",
				"message": "a bound red/green log is absent from the subject commit",
				"details": {"log_path": relative, "subject_commit": subject_commit}}
		var bytes: PackedByteArray = (blob.get("value", {}) as Dictionary).get("bytes", PackedByteArray())
		var outcome: Dictionary = parse_gut_log_exit_code(bytes)
		if not outcome.get("ok", false):
			outcome["details"] = {"log_path": relative, "subject_commit": subject_commit}
			return outcome
		records.append({
			"suite_id": name.trim_suffix(".log"),
			"log_path": relative,
			"log_sha256": digest_bytes(bytes),
			"exit_code": int((outcome.get("value", {}) as Dictionary).get("exit_code", -1)),
		})
	return {"ok": true, "code": &"ok", "value": {"records": records}, "receipt": {}}


## Confirms a document's declared test-log bindings are not dangling. The sealed desktop document
## named evidence/phase_2r/logs/p2r9-bootstrap-wiring-check3.log while that file had never been
## curated out of the transient logs directory, and nothing in the tree noticed (dwm-p2r.35.5,
## reviewer finding B-I1).
static func validate_log_paths_at_commit(repository_root: String, subject_commit: String,
		log_paths: Array) -> Dictionary:
	for path: Variant in log_paths:
		var relative: String = str(path)
		if not relative.begins_with(CURATED_LOG_DIRECTORY):
			return {"ok": false, "code": &"test_log_binding_outside_curated_directory",
				"message": "a bound test log is not under the curated logs directory",
				"details": {"log_path": relative}}
		var blob: Dictionary = blob_bytes_at_commit(repository_root, subject_commit, relative)
		if not blob.get("ok", false):
			return {"ok": false, "code": &"test_log_binding_dangling",
				"message": "a bound test log is absent from the subject commit",
				"details": {"log_path": relative, "subject_commit": subject_commit}}
	return {"ok": true, "code": &"ok", "value": {"log_paths": log_paths.duplicate()}, "receipt": {}}
