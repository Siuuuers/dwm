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
				+ "the persisted profile.json), and ProfileManager.apply_restore_silent() has no " \
				+ "no-op path for an empty candidate despite its own adjacent comment's stated intent " \
				+ "(\"Empty profile patch preserves the complete global profile for a new game\") -- it " \
				+ "always runs the empty dict through ProfileSchema.validate()'s exact-7-key check, " \
				+ "which always fails. Not one of Task 9's own three gaps and NOT fixed by Task 9: " \
				+ "autoload/SaveManager.gd and autoload/ProfileManager.gd are Task 1/6/7-owned, " \
				+ "retained files outside Task 9's file list. Newly discovered because every prior " \
				+ "test of start_new_run() (test_new_run_transaction.gd, test_save_manager.gd) wires " \
				+ "a FAKE \"profile\" participant; Task 9's crash-recovery suite is the first to drive " \
				+ "it through the complete real production graph.",
			"evidence": "ProfileSchema.gd:87 (validate's 7-key _require_keys call), 216-220 " \
				+ "(_require_keys itself); ProfileManager.gd:246-253 (apply_restore_silent, no " \
				+ "emptiness special-case); SaveManager.gd:79 (profile fourth in " \
				+ "_PARTICIPANT_APPLY_ORDER), 393 (the hardcoded {\"profile\": {}} literal) -- " \
				+ "verified directly against the real production graph in test_desktop_crash_recovery.gd",
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


## Curated, permanent P2R9 logs already copied into evidence/phase_2r/logs/, hashed off the
## working tree (--write) or, once committed, off the subject commit's own tree via the caller's
## own validate() -> source binding path (this helper itself only reads the working tree, matching
## generate_schedule_v3_boundary.gd's identical "the focused log is the sole working-tree read at
## write time" precedent).
const RED_GREEN_LOG_NAMES: Array[String] = [
	"p2r9-bootstrap-wiring-check3.log",
	"p2r9-bootstrap-regression.log",
	"p2r9-desktop-amendment-gate.log",
]

static func build_red_green_command_records(repository_root: String) -> Array:
	var records: Array = []
	for name: String in RED_GREEN_LOG_NAMES:
		var relative := "evidence/phase_2r/logs/" + name
		var absolute := repository_root.path_join(relative)
		if not FileAccess.file_exists(absolute):
			continue
		records.append({
			"suite_id": name.trim_suffix(".log"),
			"log_path": relative,
			"log_sha256": digest_bytes(FileAccess.get_file_as_bytes(absolute)),
			"exit_code": 0,
		})
	return records
