class_name Phase2RScheduleDesktopHandoffGuard
extends RefCounted

## Proves Plan 01's Schedule participant and Plan 02's desktop participants can be consumed
## together by a later owner, WITHOUT composing the Plan-03/dwm-oyo.3 player-facing departure
## (dwm-p2r.10 Plan 04 Task 2).
##
## PURE, stated precisely. It reads three sealed evidence documents plus two detached primitive
## Dictionaries, reads the Git object database read-only, and mutates no input and no repository
## state. It is NOT side-effect free in the absolute sense, and the two exceptions are deliberate:
## _blob_digest() writes and then deletes one process-local scratch file under user://, and two
## static memos cache pure functions of immutable committed bytes for the life of the process. It
## never resolves an Object from an instance id, never serializes a numeric instance id into a
## verdict, and never compares a live id to a committed one: process-local ids are meaningless
## across runs, so only relations between ids taken from ONE boot are legal.
##
## TWO DIFFERENT BINDING LAWS, AND THEY ARE NOT INTERCHANGEABLE. Observed 2026-08-25:
##   * source_bindings hash the seal's OWN subject-commit tree, because a working-tree hash would
##     re-bind itself every time those files lawfully evolve after the seal closes.
##   * test logs hash CURRENT committed bytes, because a log is produced BY the run the seal
##     describes and therefore cannot pre-exist that seal's subject commit. All four
##     evidence/phase_2r/logs/p2r15-*.log blobs really are absent from gate.json's own
##     subject_commit 2bd24eb2 and present at HEAD, so hashing them at the subject commit
##     reports a false drift. The curated log directory is immutable and append-only.
##
## WHAT IT DELIBERATELY DOES NOT DO. No compatibility mutation path, no participant fingerprint
## method, no live-reference getter, no private bootstrap reflection, and no Done/ScheduleView/
## route/Hospital/terminal-intent/ending composition. A predecessor mismatch is returned as a
## failure for the owning Plan-01/02 issue to answer, never patched around here.

const _GIT := preload("res://tools/evidence/DesktopAmendmentEvidenceGit.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

## The canonical tracked path of each seal, for the document-integrity seam below.
const SEAL_PATHS: Dictionary = {
	"schedule_gate": "evidence/phase_2r/schedule/gate.json",
	"desktop_contract": "evidence/phase_2r/contracts/desktop_contract.json",
	"minesweeper_contract": "evidence/phase_2r/contracts/minesweeper_contract.json",
}

const SCHEDULE_GATE_SUBJECT := "test(schedule): define the Phase-2R committed Schedule gate"
const DESKTOP_CONTRACT_SUBJECT := "feat(phase2r): seal desktop board and shop handoff contracts"
const MINESWEEPER_CONTRACT_SUBJECT := DESKTOP_CONTRACT_SUBJECT

## The exact fourteen-member predecessor subset Plan 04 Task 2 declares. Two structural members
## plus twelve integer roles; nothing else in this set is legal and nothing in it may be absent.
const PREDECESSOR_STRUCTURAL_FIELDS: Array[String] = [
	"restore_order", "restore_participant_instance_ids",
]
const PREDECESSOR_INTEGER_FIELDS: Array[String] = [
	"schedule_port_instance_id",
	"provenance_owner_instance_id",
	"day_resolution_start_port_instance_id",
	"causal_day_advance_identity_port_instance_id",
	"desktop_publication_ledger_instance_id",
	"causal_sequence_port_instance_id",
	"admission_checkpoint_port_instance_id",
	"board_fate_port_instance_id",
	"minesweeper_round_source_port_instance_id",
	"shop_purchase_source_port_instance_id",
	"consequence_coordinator_instance_id",
	"snapshot_provider_instance_id",
]

## The extension names this seam admits, and where they actually come from.
##
## Plan 04 Task 2 says a later-extension key is ignored "only after their names are validated
## against Plan 03's closed extension list". THERE IS NO SUCH LIST. Plan 03
## (2026-08-11-desktop-minesweeper-shop-schedule-03-seven-day-flow-integration.md) declares none of
## these names -- it uses a largely disjoint vocabulary, e.g. desktop_board_state_instance_id rather
## than board_state_instance_id, and never mentions condition_policy_port_instance_id or
## host_instance_id at all. So this list is what it is honestly able to be: the exact set OBSERVED
## at HEAD on 2026-08-25, when the probe returned exactly 45 keys -- the 14 predecessor members and
## these 31. Naming it after Plan 03 would claim an authority binding this list does not have.
##
## What that does and does not buy. The tripwire against a NEW, unnamed probe key is real and
## enforced. The allowlist itself is a snapshot, not a contract, so a name here is admitted because
## production returned it, not because a plan blessed it.
const OBSERVED_HEAD_EXTENSION_FIELDS: Array[String] = [
	"board_state_instance_id",
	"condition_context_port_instance_id",
	"condition_policy_port_instance_id",
	"consequence_state_instance_id",
	"contact_command_port_instance_id",
	"continuation_journal_instance_id",
	"dating_presentation_port_instance_id",
	"dating_presentation_ready",
	"day_resolution_coordinator_instance_id",
	"day_resolution_state_port_instance_id",
	"desktop_consequence_source_port_instance_id",
	"desktop_graph_constructed",
	"destination_composition_ready",
	"game_state_desktop_board_port_instance_id",
	"game_state_minesweeper_shop_port_instance_id",
	"hospital_presentation_port_instance_id",
	"hospital_presentation_ready",
	"host_instance_id",
	"issuer_instance_id",
	"mutation_gate_instance_id",
	"presentation_owner_adapter_instance_id",
	"presentation_producer_ready",
	"publication_ledger_instance_id",
	"registry_versions",
	"root_store_instance_id",
	"run_snapshot_schema_version",
	"save_document_schema_version",
	"save_manager_desktop_board_port_instance_id",
	"schedule_departure_view_port_instance_id",
	"schedule_done_dispatcher_instance_id",
	"schedule_registry_instance_id",
]

## The nine restore roles, in the frozen apply order. identity_allocation applies once, before the
## ordinary eight-participant loop SaveManager itself drives.
const RESTORE_ROLES: Array[String] = [
	"identity_allocation", "run", "desktop_consequence", "desktop_board",
	"profile", "localization", "audio", "route", "narrative",
]

## The Plan-01 classes this task's own net exercises, hashed from gate.json's subject tree.
const GATE_CONSUMED_BINDINGS: Array[String] = [
	"autoload/ApplicationBootstrap.gd",
	"autoload/GameState.gd",
	"scripts/application/run/CausalDayAdvanceIdentityPort.gd",
	"scripts/application/run/DayResolutionStartPort.gd",
	"scripts/application/schedule/GameStateScheduleCommitPort.gd",
	"scripts/domain/run/RunSnapshotSchema.gd",
	"scripts/domain/schedule/Day7ScheduleProvenance.gd",
	"scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd",
]

## The Plan-02 classes this task's own net exercises. test_desktop_bootstrap_wiring.gd is here on
## purpose: it is sha256-BOUND in this very document and Task 2 only RUNS it, so hashing it pins
## the exact reviewed bytes this task consumes. Note precisely what that does and does not prove:
## the digest is read from the SEAL's own subject tree, so a working-tree edit to that suite is
## INVISIBLE here -- catching that is the desktop amendment gate's job, not this guard's. What
## this proves is that the seal still resolves, so the bytes Task 2 is bound to are the reviewed
## ones.
const DESKTOP_CONSUMED_BINDINGS: Array[String] = [
	"autoload/ApplicationBootstrap.gd",
	"scripts/application/desktop/DesktopCausalSequencePort.gd",
	"scripts/application/desktop/DesktopConsequenceCoordinator.gd",
	"scripts/application/minesweeper/DesktopBoardFatePort.gd",
	"scripts/application/restore/DesktopBoardRestoreParticipant.gd",
	"scripts/application/restore/DesktopConsequenceRestoreParticipant.gd",
	"scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd",
	"scripts/application/run/SaveManagerCheckpointPort.gd",
	"scripts/infrastructure/save/DesktopPublicationLedger.gd",
	"tests/integration/test_desktop_bootstrap_wiring.gd",
]

const MINESWEEPER_CONSUMED_BINDINGS: Array[String] = [
	"scripts/application/minesweeper/MinesweeperRoundCoordinator.gd",
	"scripts/application/shop/MinesweeperShopPurchaseParticipant.gd",
	"scripts/domain/desktop/DesktopActionReceipt.gd",
]

## The exact .16 allocator surface. Three seams, no more: a fourth would mean the shared allocator
## grew a caller-reachable mutator between Phase 2R and its later Plan-03 consumer.
const ALLOCATOR_PATH := "scripts/application/run/CausalDayAdvanceIdentityPort.gd"
const ALLOCATOR_SURFACE: Array[String] = [
	"func configure(identity_issuer)",
	"func prepare_advance(request)",
	"func commit_advance(candidate)",
]
const ALLOCATOR_RESOLUTION_KINDS: Array[String] = ["schedule_done", "condition_hospital"]
const ALLOCATOR_ALLOCATION_KEY_FORMAT := "resolution_kind:source_resolution_receipt_id"
const ALLOCATOR_REQUEST_KEYS: Array[String] = [
	"branch_id", "desktop_timeline_generation", "resolution_kind", "run_id",
	"source_causal_day_instance", "source_causal_day_instance_issuer_receipt", "source_day",
	"source_resolution_receipt",
]

## Frozen from the re-sealed desktop contract at fec0020ed.
const SEALED_ROLE_RELATIONS: Array = [
	{"relation": "ledger_shared_by_causal_round_shop_board_fate", "verdict": "equal"},
	{"relation": "round_and_board_fate_share_the_same_live_board_state", "verdict": "equal"},
	{"relation": "round_and_shop_action_sources", "verdict": "distinct"},
	{"relation": "snapshot_provider_equals_game_state_instance", "verdict": "equal"},
	{"relation": "old_simulator_install_seam_untouched", "verdict": "never_written"},
	{"relation": "identical_replay_reuses_every_instance", "verdict": "stable"},
]

## Exactly-once delivery across a restart: delivered on the first pass, refused on the replay.
const FIRST_DELIVERY_SEQUENCE: Array[bool] = [true, false]

const SCHEDULE_DONE_RECIPE: Array[String] = [
	"causal_sequence", "schedule_commit", "board_fate", "day_resolution_start",
]
const RECIPE_FORBIDDEN_MEMBERS: Array[String] = [
	"admission_checkpoint_receipt", "current checkpoint_receipt", "checkpoint candidate",
	"publication_plan_sha256", "recovery_payload_sha256",
]

const SNAPSHOT_INPUT_KEYS: Array[String] = [
	"applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts",
	"committed_schedule", "contacts", "dating", "desktop", "gameplay", "lifecycle",
]
const SNAPSHOT_DESKTOP_MEMBER_KEYS: Array[String] = ["board", "consequence"]

## Task 2's own eleven requirement ids, split by whether any of the three seals actually names
## them. NINE are attested. TWO are not attested by ANY seal and are reported as such rather than
## claimed: honest absence beats a requirement mapping that overstates its own evidence. A third
## unattested id -- or one of these two becoming attested -- fails closed so the split cannot rot.
const TASK2_REQUIREMENT_IDS: Array[String] = [
	"req.desktop.cross_app_actions",
	"req.minesweeper.causal_departure",
	"req.minesweeper.phase_boundary",
	"req.run.day_resolution_plan",
	"req.runtime.schedule_ownership",
	"req.save.desktop_board_continuity",
	"req.save.schedule_state",
	"req.schedule.day7_provenance",
	"req.schedule.done_commit",
	"req.test.desktop_amendment_gate",
	"req.test.schedule_foundation_gate",
]
const TASK2_UNATTESTED_REQUIREMENT_IDS: Array[String] = [
	"req.run.day_resolution_plan", "req.runtime.schedule_ownership",
]

## The ONE permitted forward divergence between gate.json's frozen readiness and live HEAD.
## gate.json is a HISTORICAL seal at 2bd24eb2 that is never regenerated; DEVIATION-5 was finished
## afterwards by dwm-p2r.32 and the dwm-oyo.3 slice, so the sealed false became a live true. The
## other two readiness facts must still agree exactly, and a live FALSE here would be a real
## regression rather than lawful drift.
## dating_presentation_ready is deliberately NOT here: it is owned end to end by the deferred
## composition guard below, so exactly one guard and one failure code answer for it.
const READINESS_MUST_MATCH: Array[String] = ["hospital_presentation_ready"]
const READINESS_FORWARD_ONLY := "presentation_producer_ready"

const OYO3_OWNER := "dwm-oyo.3"

## Process-level memo of (commit, path) -> sha256, so a suite calling validate() many times pays
## the git object reads once. It caches a pure function of immutable committed bytes and mutates
## no input, no file and no repository state.
static var _blob_digest_memo: Dictionary = {}
static var _git_directory_memo: Dictionary = {}


# =============================================================================================
# Master seam.
# =============================================================================================

static func validate(schedule_gate: Variant, desktop_contract: Variant,
		minesweeper_contract: Variant, bootstrap_contract_state: Variant,
		snapshot_input: Variant) -> Dictionary:
	for candidate: Variant in [schedule_gate, desktop_contract, minesweeper_contract,
			bootstrap_contract_state, snapshot_input]:
		if typeof(candidate) != TYPE_DICTIONARY:
			return _fail(&"invalid_handoff_input",
				"every handoff input must be a detached Dictionary", {})
	var gate: Dictionary = schedule_gate
	var desktop: Dictionary = desktop_contract
	var minesweeper: Dictionary = minesweeper_contract
	var state: Dictionary = bootstrap_contract_state
	var snapshot: Dictionary = snapshot_input

	var repository_root: String = _repository_root()
	if repository_root.is_empty():
		return _fail(&"seal_commit_unreachable", "no Git repository contains this project", {})

	var seals: Dictionary = {}
	for spec: Array in [
		["schedule_gate", gate, SCHEDULE_GATE_SUBJECT, GATE_CONSUMED_BINDINGS, true],
		["desktop_contract", desktop, DESKTOP_CONTRACT_SUBJECT, DESKTOP_CONSUMED_BINDINGS, false],
		["minesweeper_contract", minesweeper, MINESWEEPER_CONTRACT_SUBJECT,
			MINESWEEPER_CONSUMED_BINDINGS, false],
	]:
		var sealed: Dictionary = _validate_seal(repository_root, str(spec[0]), spec[1], str(spec[2]),
			spec[3], bool(spec[4]))
		if not sealed.get("ok", false):
			return sealed
		seals[str(spec[0])] = sealed["value"]

	var subset: Dictionary = _validate_predecessor_subset(state, desktop)
	if not subset.get("ok", false):
		return subset

	var relations: Dictionary = _validate_role_relations(state, desktop, gate)
	if not relations.get("ok", false):
		return relations

	var allocator: Dictionary = _validate_allocator(gate)
	if not allocator.get("ok", false):
		return allocator

	var publication: Dictionary = _validate_publication(gate, desktop, minesweeper)
	if not publication.get("ok", false):
		return publication

	var snapshot_facts: Dictionary = _validate_snapshot(snapshot, state, gate, desktop)
	if not snapshot_facts.get("ok", false):
		return snapshot_facts

	var readiness: Dictionary = _validate_sealed_readiness(state, gate)
	if not readiness.get("ok", false):
		return readiness

	var attestation: Dictionary = _validate_requirement_attestation(gate, desktop, minesweeper)
	if not attestation.get("ok", false):
		return attestation

	var deferred: Dictionary = _validate_deferred_composition(state, desktop, gate)
	if not deferred.get("ok", false):
		return deferred

	return _ok({
		"seals": seals,
		"predecessor_subset": subset["value"],
		"role_relations": relations["value"],
		"allocator_binding": allocator["value"],
		"publication_relations": publication["value"],
		"snapshot_facts": snapshot_facts["value"],
		"requirement_attestation": attestation["value"],
		"deferred_composition": deferred["value"],
	})


## Second pure seam: pins the seal DOCUMENTS themselves.
##
## WHY IT IS SEPARATE FROM validate(). validate() hashes each seal's BINDINGS against that seal's
## own subject tree, which says nothing about the seal file's own bytes -- a hand-edited gate.json
## that stayed internally consistent would sail through. Pinning belongs here rather than inside
## validate() because validate()'s rejection tests deliberately pass MUTATED copies, so a document
## pin there would swallow every one of those codes.
##
## WHY HEAD AND NOT THE SUBJECT COMMIT. gate.json does not exist at its own subject_commit
## 2bd24eb2, and both contracts legitimately differ between fec0020ed and HEAD on this re-sealed
## branch. HEAD's tracked bytes are the only reference that is both immutable and current.
static func validate_sealed_documents(schedule_gate: Variant, desktop_contract: Variant,
		minesweeper_contract: Variant) -> Dictionary:
	var supplied: Dictionary = {
		"schedule_gate": schedule_gate,
		"desktop_contract": desktop_contract,
		"minesweeper_contract": minesweeper_contract,
	}
	for name: String in SEAL_PATHS.keys():
		if typeof(supplied[name]) != TYPE_DICTIONARY:
			return _fail(&"invalid_handoff_input", "every seal must be a detached Dictionary",
				{"seal": name})
	var repository_root: String = _repository_root()
	if repository_root.is_empty():
		return _fail(&"seal_commit_unreachable", "no Git repository contains this project", {})

	var pinned: Dictionary = {}
	for name: String in SEAL_PATHS.keys():
		var path: String = str(SEAL_PATHS[name])
		var committed: Dictionary = _blob_text(repository_root, "HEAD", path)
		if not committed.get("ok", false):
			return _fail(&"sealed_document_unreadable", "a seal is absent from HEAD",
				{"seal": name, "path": path})
		var parsed: Dictionary = _STRICT_JSON.parse_object(str(committed["value"]))
		if not parsed.get("ok", false):
			return _fail(&"sealed_document_unreadable", "a committed seal is not strict JSON",
				{"seal": name, "path": path})
		if (parsed["value"] as Dictionary) != (supplied[name] as Dictionary):
			return _fail(&"sealed_document_drift",
				"a supplied seal differs from its committed bytes",
				{"seal": name, "path": path})
		pinned[name] = path
	return _ok({"pinned_seals": pinned, "reference": "HEAD"})


# =============================================================================================
# Sealed upstream evidence.
# =============================================================================================

## `document` is already known to be a Dictionary: validate() rejects a non-Dictionary among all
## five inputs before this is ever reached, so this takes the typed parameter directly rather than
## re-checking it behind a branch no test could reach.
static func _validate_seal(repository_root: String, seal_name: String, seal: Dictionary,
		expected_subject: String, consumed: Array[String], has_declared_surface: bool) -> Dictionary:
	var commit: String = str(seal.get("subject_commit", ""))
	if not _GIT.is_commit_id(commit) or str(seal.get("subject_commit_subject", "")) != expected_subject:
		return _fail(&"seal_subject_mismatch", "a seal does not carry its frozen subject",
			{"seal": seal_name, "subject_commit": commit,
				"subject": seal.get("subject_commit_subject", "")})

	var subject: Dictionary = _reachable_subject(repository_root, commit)
	if not subject.get("ok", false):
		return _fail(&"seal_commit_unreachable",
			"a seal's subject commit is not a readable ancestor of HEAD",
			{"seal": seal_name, "commit": commit})
	if str(subject["value"]) != expected_subject:
		return _fail(&"seal_subject_mismatch",
			"a seal's named commit does not carry the frozen subject",
			{"seal": seal_name, "commit": commit, "observed": subject["value"]})

	var bindings: Variant = seal.get("source_bindings")
	if typeof(bindings) != TYPE_ARRAY:
		return _fail(&"seal_source_binding_missing", "a seal declares no source bindings",
			{"seal": seal_name})
	var by_path: Dictionary = {}
	for entry: Variant in bindings as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			by_path[str((entry as Dictionary).get("path", ""))] = entry

	var verified: Array[String] = []
	for path: String in consumed:
		if not by_path.has(path):
			return _fail(&"seal_source_binding_missing",
				"a consumed production path is absent from its seal",
				{"seal": seal_name, "path": path})
		var binding: Dictionary = by_path[path]
		var digest: Dictionary = _blob_digest(repository_root, commit, path)
		if not digest.get("ok", false):
			return _fail(&"seal_source_binding_drift",
				"a bound path is absent from the seal's own subject tree",
				{"seal": seal_name, "path": path, "commit": commit})
		if str(digest["value"]) != str(binding.get("sha256", "")):
			return _fail(&"seal_source_binding_drift",
				"a bound path's subject-tree bytes do not match the recorded digest",
				{"seal": seal_name, "path": path, "recorded": binding.get("sha256", ""),
					"observed": digest["value"]})
		if has_declared_surface and path == ALLOCATOR_PATH:
			var surface: Dictionary = _validate_declared_surface(binding, seal_name)
			if not surface.get("ok", false):
				return surface
		verified.append(path)
	verified.sort()

	var logs: Dictionary = _validate_test_logs(repository_root, seal_name, seal)
	if not logs.get("ok", false):
		return logs

	return _ok({
		"subject_commit": commit,
		"subject_commit_subject": expected_subject,
		"verified_source_bindings": verified,
		"verified_test_logs": logs["value"],
	})


## The allocator's declared surface is the one signature set this guard pins by value, because the
## whole shared-allocator relation depends on it staying exactly three seams.
static func _validate_declared_surface(binding: Dictionary, seal_name: String) -> Dictionary:
	var declared: Variant = binding.get("declared_surface")
	if typeof(declared) != TYPE_ARRAY:
		return _fail(&"seal_declared_surface_drift", "the allocator binding declares no surface",
			{"seal": seal_name})
	var observed: Array[String] = []
	for item: Variant in declared as Array:
		observed.append(str(item))
	if observed != ALLOCATOR_SURFACE:
		return _fail(&"seal_declared_surface_drift",
			"the allocator's sealed surface is not exactly configure/prepare_advance/commit_advance",
			{"seal": seal_name, "observed": observed})
	if not _GIT.is_sha256(str(binding.get("declared_surface_sha256", ""))):
		return _fail(&"seal_declared_surface_drift",
			"the allocator's declared surface digest is malformed", {"seal": seal_name})
	return _ok({})


## Logs hash CURRENT committed bytes -- see this file's header for why the seal's own subject tree
## is the wrong reference for them.
static func _validate_test_logs(repository_root: String, seal_name: String,
		seal: Dictionary) -> Dictionary:
	var records: Variant = seal.get("commands", seal.get("red_green_command_records"))
	if typeof(records) != TYPE_ARRAY or (records as Array).is_empty():
		return _fail(&"seal_test_log_missing", "a seal records no test-log command records",
			{"seal": seal_name})
	var verified: Array[String] = []
	for entry: Variant in records as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"seal_test_log_missing", "a command record is not an object",
				{"seal": seal_name})
		var record: Dictionary = entry
		var path: String = str(record.get("log_path", ""))
		var recorded: String = str(record.get("log_sha256", ""))
		if path.is_empty() or not _GIT.is_sha256(recorded):
			return _fail(&"seal_test_log_missing", "a command record names no hashed log",
				{"seal": seal_name, "log_path": path})
		var digest: Dictionary = _blob_digest(repository_root, "HEAD", path)
		if not digest.get("ok", false):
			return _fail(&"seal_test_log_drift", "a recorded evidence log is absent at HEAD",
				{"seal": seal_name, "log_path": path})
		if str(digest["value"]) != recorded:
			return _fail(&"seal_test_log_drift",
				"a recorded evidence log's committed bytes changed",
				{"seal": seal_name, "log_path": path, "recorded": recorded,
					"observed": digest["value"]})
		if not verified.has(path):
			verified.append(path)
	verified.sort()
	return _ok(verified)


# =============================================================================================
# The detached predecessor subset.
# =============================================================================================

static func _validate_predecessor_subset(state: Dictionary, desktop: Dictionary) -> Dictionary:
	for field: String in PREDECESSOR_STRUCTURAL_FIELDS + PREDECESSOR_INTEGER_FIELDS:
		if not state.has(field):
			return _fail(&"predecessor_field_missing",
				"the probe omits a declared predecessor member", {"field": field})
	for key: Variant in state.keys():
		var name: String = str(key)
		if PREDECESSOR_STRUCTURAL_FIELDS.has(name) or PREDECESSOR_INTEGER_FIELDS.has(name):
			continue
		if not OBSERVED_HEAD_EXTENSION_FIELDS.has(name):
			return _fail(&"predecessor_field_unadmitted",
				"the probe carries a key named by neither the predecessor subset nor the observed "
				+ "extension list", {"field": name})

	for field: String in PREDECESSOR_INTEGER_FIELDS:
		if typeof(state[field]) != TYPE_INT:
			return _fail(&"predecessor_field_type", "a declared predecessor role is not an integer",
				{"field": field, "type": type_string(typeof(state[field]))})
		if int(state[field]) == 0:
			return _fail(&"predecessor_instance_id_zero",
				"a declared predecessor role is unretained", {"field": field})

	if typeof(state["restore_order"]) != TYPE_ARRAY:
		return _fail(&"predecessor_field_type", "restore_order is not an Array", {})
	var order: Array[String] = []
	for item: Variant in state["restore_order"] as Array:
		order.append(String(item))
	var sealed_order: Array[String] = []
	if typeof(desktop.get("restore_order")) == TYPE_ARRAY:
		for item: Variant in desktop["restore_order"] as Array:
			sealed_order.append(String(item))
	if order != RESTORE_ROLES or sealed_order != RESTORE_ROLES:
		return _fail(&"restore_order_drift",
			"the live restore order and its seal must both be the frozen nine-role order",
			{"live": order, "sealed": sealed_order})

	if typeof(state["restore_participant_instance_ids"]) != TYPE_DICTIONARY:
		return _fail(&"predecessor_field_type",
			"restore_participant_instance_ids is not a Dictionary", {})
	var roles: Dictionary = state["restore_participant_instance_ids"]
	var role_names: Array[String] = []
	for key: Variant in roles.keys():
		role_names.append(str(key))
	role_names.sort()
	var expected_names: Array[String] = RESTORE_ROLES.duplicate()
	expected_names.sort()
	if role_names != expected_names:
		return _fail(&"restore_role_set_drift",
			"the restore participant roles are not exactly the nine declared roles",
			{"observed": role_names})
	var seen: Dictionary = {}
	for role: String in RESTORE_ROLES:
		if typeof(roles[role]) != TYPE_INT or int(roles[role]) == 0:
			return _fail(&"restore_role_instance_id_zero", "a restore role is unretained",
				{"role": role})
		if seen.has(int(roles[role])):
			return _fail(&"restore_role_not_distinct", "two restore roles share one participant",
				{"role": role, "shared_with": seen[int(roles[role])]})
		seen[int(roles[role])] = role

	var integer_fields: Array[String] = PREDECESSOR_INTEGER_FIELDS.duplicate()
	integer_fields.sort()
	var extensions: Array[String] = []
	for key: Variant in state.keys():
		if OBSERVED_HEAD_EXTENSION_FIELDS.has(str(key)):
			extensions.append(str(key))
	extensions.sort()
	return _ok({
		"restore_order": RESTORE_ROLES.duplicate(),
		"restore_roles_retained": expected_names,
		"integer_fields": integer_fields,
		"admitted_extension_fields": extensions,
		"instance_ids_serialized": false,
	})


# =============================================================================================
# Same-boot relations. Verdicts only; never a numeric id.
# =============================================================================================

static func _validate_role_relations(state: Dictionary, desktop: Dictionary,
		gate: Dictionary) -> Dictionary:
	if int(state["minesweeper_round_source_port_instance_id"]) \
			== int(state["shop_purchase_source_port_instance_id"]):
		return _fail(&"action_source_roles_not_distinct",
			"the Round and Shop action sources must be two different owners", {})

	var probe: Variant = desktop.get("bootstrap_probe")
	if typeof(probe) != TYPE_DICTIONARY:
		return _fail(&"role_relation_verdict_drift", "the desktop seal records no bootstrap probe", {})
	var sealed: Variant = (probe as Dictionary).get("role_relations")
	if typeof(sealed) != TYPE_ARRAY or (sealed as Array).size() != SEALED_ROLE_RELATIONS.size():
		return _fail(&"role_relation_verdict_drift",
			"the sealed role-relation set is not the frozen six", {})
	var verdicts: Array = []
	for index: int in range(SEALED_ROLE_RELATIONS.size()):
		var entry: Variant = (sealed as Array)[index]
		var expected: Dictionary = SEALED_ROLE_RELATIONS[index]
		if typeof(entry) != TYPE_DICTIONARY \
				or str((entry as Dictionary).get("relation", "")) != str(expected["relation"]) \
				or str((entry as Dictionary).get("verdict", "")) != str(expected["verdict"]):
			return _fail(&"role_relation_verdict_drift",
				"a sealed role relation drifted from its frozen verdict",
				{"expected": expected, "observed": entry})
		verdicts.append({"relation": expected["relation"], "verdict": expected["verdict"]})

	var ledger: Dictionary = _validate_ledger_distinctness(state, desktop, gate)
	if not ledger.get("ok", false):
		return ledger
	return _ok(verdicts)


## Plan 01's ScheduleFoundationPublicationLedger and Plan 02's DesktopPublicationLedger are two
## different owners writing two different fixed paths. Both seals must SAY so and the live probe
## must SHOW so; an attestation that disagrees with the probe is exactly the drift Task 2 exists
## to catch.
static func _validate_ledger_distinctness(state: Dictionary, desktop: Dictionary,
		gate: Dictionary) -> Dictionary:
	var stores: Variant = desktop.get("external_stores")
	if typeof(stores) != TYPE_DICTIONARY:
		return _fail(&"publication_ledger_relation_violated",
			"the desktop seal records no external stores", {})
	var desktop_ledger: Variant = (stores as Dictionary).get("desktop_publication_ledger")
	var schedule_ledger: Variant = gate.get("publication_ledger")
	if typeof(desktop_ledger) != TYPE_DICTIONARY or typeof(schedule_ledger) != TYPE_DICTIONARY:
		return _fail(&"publication_ledger_relation_violated",
			"one of the two publication ledgers is unrecorded", {})
	var schedule_owner: String = str((schedule_ledger as Dictionary).get("path", "")) \
		.get_file().trim_suffix(".gd")
	if str((desktop_ledger as Dictionary).get("distinct_from", "")) != schedule_owner:
		return _fail(&"publication_ledger_relation_violated",
			"the desktop ledger does not attest distinctness from the Plan-01 ledger",
			{"attested": (desktop_ledger as Dictionary).get("distinct_from", ""),
				"expected": schedule_owner})
	if str((desktop_ledger as Dictionary).get("fixed_path", "")) \
			== str((schedule_ledger as Dictionary).get("fixed_path", "")):
		return _fail(&"publication_ledger_relation_violated",
			"the two ledgers claim one fixed path", {})
	if state.has("publication_ledger_instance_id") \
			and int(state["publication_ledger_instance_id"]) \
				== int(state["desktop_publication_ledger_instance_id"]):
		return _fail(&"publication_ledger_relation_violated",
			"the live probe reports one object serving both ledger roles", {})
	return _ok({})


# =============================================================================================
# The .16 shared allocator.
# =============================================================================================

static func _validate_allocator(gate: Dictionary) -> Dictionary:
	var allocator: Variant = gate.get("day_advance_identity")
	if typeof(allocator) != TYPE_DICTIONARY:
		return _fail(&"allocator_binding_drift", "the gate records no day-advance identity", {})
	var record: Dictionary = allocator
	if str(record.get("path", "")) != ALLOCATOR_PATH:
		return _fail(&"allocator_binding_drift", "the allocator is not the .16 owner",
			{"path": record.get("path", "")})
	if record.get("raw_causal_day_issue_in_plan01", true) != false:
		return _fail(&"allocator_raw_causal_day_issue",
			"Plan 01 must never issue a raw causal_day_instance", {})

	var kinds: Array[String] = []
	if typeof(record.get("resolution_kinds")) == TYPE_ARRAY:
		for item: Variant in record["resolution_kinds"] as Array:
			kinds.append(str(item))
	if kinds != ALLOCATOR_RESOLUTION_KINDS:
		return _fail(&"allocator_resolution_kind_drift",
			"the allocator's resolution kinds are not the frozen pair", {"observed": kinds})

	if str(record.get("allocation_key_format", "")) != ALLOCATOR_ALLOCATION_KEY_FORMAT:
		return _fail(&"allocator_receipt_shape_drift", "the allocation key format drifted",
			{"observed": record.get("allocation_key_format", "")})
	var request_keys: Array[String] = []
	if typeof(record.get("request_keys")) == TYPE_ARRAY:
		for item: Variant in record["request_keys"] as Array:
			request_keys.append(str(item))
	if request_keys != ALLOCATOR_REQUEST_KEYS:
		return _fail(&"allocator_receipt_shape_drift", "the allocator request shape drifted",
			{"observed": request_keys})
	var receipt_keys: Array[String] = []
	if typeof(record.get("receipt_keys")) == TYPE_ARRAY:
		for item: Variant in record["receipt_keys"] as Array:
			receipt_keys.append(str(item))
	for required: String in ["allocation_key", "resolution_kind", "source_resolution_receipt_id",
			"source_causal_day_instance", "source_causal_day_instance_issuer_receipt",
			"target_causal_day_instance", "target_causal_day_instance_issuer_receipt",
			"root_before_fingerprint", "disposition"]:
		if not receipt_keys.has(required):
			return _fail(&"allocator_receipt_shape_drift",
				"the allocator receipt omits a required member", {"member": required})
	return _ok({
		"path": ALLOCATOR_PATH,
		"declared_surface": ALLOCATOR_SURFACE.duplicate(),
		"resolution_kinds": ALLOCATOR_RESOLUTION_KINDS.duplicate(),
		"allocation_key_format": ALLOCATOR_ALLOCATION_KEY_FORMAT,
		"raw_causal_day_issue_in_plan01": false,
		"receipt_key_count": receipt_keys.size(),
	})


# =============================================================================================
# Publication ledgers and restart delivery.
# =============================================================================================

static func _validate_publication(gate: Dictionary, desktop: Dictionary,
		minesweeper: Dictionary) -> Dictionary:
	var ledger: Variant = gate.get("publication_ledger")
	var observed: Variant = gate.get("observed_publications")
	if typeof(ledger) != TYPE_DICTIONARY or typeof(observed) != TYPE_ARRAY \
			or (observed as Array).is_empty():
		return _fail(&"publication_first_delivery_drift",
			"the gate records no observed publications", {})
	var conflict_codes: Variant = (ledger as Dictionary).get("conflict_codes")
	if typeof(conflict_codes) != TYPE_DICTIONARY:
		return _fail(&"publication_conflict_code_drift", "the gate records no conflict codes", {})
	var legal_codes: Array[String] = []
	for value: Variant in (conflict_codes as Dictionary).values():
		legal_codes.append(str(value))

	var delivery: Array = []
	for entry: Variant in observed as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"publication_first_delivery_drift",
				"an observed publication is not an object", {})
		var record: Dictionary = entry
		var sequence: Array[bool] = []
		if typeof(record.get("first_delivery_sequence")) == TYPE_ARRAY:
			for item: Variant in record["first_delivery_sequence"] as Array:
				sequence.append(bool(item))
		if sequence != FIRST_DELIVERY_SEQUENCE:
			return _fail(&"publication_first_delivery_drift",
				"a publication does not deliver exactly once across a restart",
				{"kind": record.get("kind", ""), "owner": record.get("owner", ""),
					"observed": sequence})
		if not legal_codes.has(str(record.get("conflict_code", ""))):
			return _fail(&"publication_conflict_code_drift",
				"an observed publication uses a conflict code the ledger never declared",
				{"kind": record.get("kind", ""), "code": record.get("conflict_code", "")})
		delivery.append({"kind": str(record.get("kind", "")), "owner": str(record.get("owner", "")),
			"first_delivery_sequence": FIRST_DELIVERY_SEQUENCE.duplicate(),
			"conflict_code": str(record.get("conflict_code", ""))})

	var recipes: Variant = minesweeper.get("publication_recipes")
	if typeof(recipes) != TYPE_DICTIONARY:
		return _fail(&"publication_recipe_drift", "the Minesweeper seal records no recipes", {})
	var done: Array[String] = []
	if typeof((recipes as Dictionary).get("schedule_done")) == TYPE_ARRAY:
		for item: Variant in (recipes as Dictionary)["schedule_done"] as Array:
			done.append(str(item))
	if done != SCHEDULE_DONE_RECIPE:
		return _fail(&"publication_recipe_drift", "the schedule_done recipe drifted",
			{"observed": done})
	var forbidden: Array[String] = []
	if typeof((recipes as Dictionary).get("recipe_never_contains")) == TYPE_ARRAY:
		for item: Variant in (recipes as Dictionary)["recipe_never_contains"] as Array:
			forbidden.append(str(item))
	for member: String in RECIPE_FORBIDDEN_MEMBERS:
		if not forbidden.has(member):
			return _fail(&"publication_recipe_drift",
				"a recipe exclusion the seal must keep is absent", {"member": member})

	var desktop_stores: Variant = desktop.get("external_stores")
	var desktop_kinds: Array[String] = []
	if typeof(desktop_stores) == TYPE_DICTIONARY:
		var entry: Variant = (desktop_stores as Dictionary).get("desktop_publication_ledger")
		if typeof(entry) == TYPE_DICTIONARY and typeof((entry as Dictionary).get("kinds")) == TYPE_ARRAY:
			for item: Variant in (entry as Dictionary)["kinds"] as Array:
				desktop_kinds.append(str(item))
	var schedule_kinds: Array[String] = []
	if typeof((ledger as Dictionary).get("kinds")) == TYPE_ARRAY:
		for item: Variant in (ledger as Dictionary)["kinds"] as Array:
			schedule_kinds.append(str(item))
	return _ok({
		"observed_delivery": delivery,
		"schedule_ledger_kinds": schedule_kinds,
		"desktop_ledger_kinds": desktop_kinds,
		"schedule_done_recipe": SCHEDULE_DONE_RECIPE.duplicate(),
	})


# =============================================================================================
# Snapshot and schema facts.
# =============================================================================================

static func _validate_snapshot(snapshot: Dictionary, state: Dictionary, gate: Dictionary,
		desktop: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for key: Variant in snapshot.keys():
		keys.append(str(key))
	keys.sort()
	if keys != SNAPSHOT_INPUT_KEYS:
		return _fail(&"snapshot_input_key_set_drift",
			"capture_run_snapshot_input() no longer returns the frozen nine members",
			{"observed": keys})

	if typeof(snapshot["desktop"]) != TYPE_DICTIONARY:
		return _fail(&"snapshot_input_key_set_drift", "the snapshot desktop member is not an object", {})
	for key: Variant in (snapshot["desktop"] as Dictionary).keys():
		if not SNAPSHOT_DESKTOP_MEMBER_KEYS.has(str(key)):
			return _fail(&"snapshot_desktop_member_drift",
				"the snapshot carries a desktop member the seal never declared", {"member": str(key)})

	var sealed_v4: Variant = desktop.get("run_snapshot_v4")
	if typeof(sealed_v4) != TYPE_DICTIONARY:
		return _fail(&"snapshot_schema_version_drift", "the desktop seal records no v4 facts", {})
	var sealed_version: int = int((sealed_v4 as Dictionary).get("schema_version", 0))
	var live_snapshot_version: int = int(state.get("run_snapshot_schema_version", 0))
	var live_document_version: int = int(state.get("save_document_schema_version", 0))
	if live_snapshot_version != sealed_version:
		return _fail(&"snapshot_schema_version_drift",
			"the live run-snapshot schema version is not the sealed desktop version",
			{"live": live_snapshot_version, "sealed": sealed_version})

	## gate.json froze version 3 for BOTH before Plan 02 raised them to 4. A historical seal is
	## never regenerated, so the law here is monotonic: live may exceed the gate, never regress
	## below it.
	var gate_versions: Variant = gate.get("current_versions")
	if typeof(gate_versions) != TYPE_DICTIONARY:
		return _fail(&"snapshot_schema_version_drift", "the gate records no current versions", {})
	var gate_snapshot: int = int((gate_versions as Dictionary).get("run_snapshot_schema_version", 0))
	var gate_document: int = int((gate_versions as Dictionary).get("save_document_version", 0))
	if live_snapshot_version < gate_snapshot or live_document_version < gate_document:
		return _fail(&"snapshot_schema_version_drift",
			"a live schema version regressed below its Plan-01 seal",
			{"live_snapshot": live_snapshot_version, "gate_snapshot": gate_snapshot,
				"live_document": live_document_version, "gate_document": gate_document})
	if (gate_versions as Dictionary).get("committed_schedule_keys_preserved", false) != true:
		return _fail(&"snapshot_schema_version_drift",
			"the gate no longer attests that committed Schedule keys are preserved", {})

	return _ok({
		"snapshot_input_keys": SNAPSHOT_INPUT_KEYS.duplicate(),
		"desktop_member_keys": SNAPSHOT_DESKTOP_MEMBER_KEYS.duplicate(),
		"live_run_snapshot_schema_version": live_snapshot_version,
		"live_save_document_schema_version": live_document_version,
		"sealed_run_snapshot_schema_version": gate_snapshot,
		"sealed_save_document_version": gate_document,
	})


## The gate's frozen readiness against live HEAD. Two facts must still agree exactly; the third is
## the ONE recorded forward-only divergence.
static func _validate_sealed_readiness(state: Dictionary, gate: Dictionary) -> Dictionary:
	var probe: Variant = gate.get("bootstrap_probe")
	if typeof(probe) != TYPE_DICTIONARY:
		return _fail(&"sealed_readiness_drift", "the gate records no bootstrap probe", {})
	var readiness: Variant = (probe as Dictionary).get("readiness")
	if typeof(readiness) != TYPE_DICTIONARY:
		return _fail(&"sealed_readiness_drift", "the gate records no readiness", {})
	for field: String in READINESS_MUST_MATCH:
		if bool((readiness as Dictionary).get(field, !bool(state.get(field, false)))) \
				!= bool(state.get(field, false)):
			return _fail(&"sealed_readiness_drift",
				"a sealed readiness fact no longer matches the live probe",
				{"field": field, "sealed": (readiness as Dictionary).get(field),
					"live": state.get(field)})
	if bool((readiness as Dictionary).get(READINESS_FORWARD_ONLY, true)) != false:
		return _fail(&"sealed_readiness_drift",
			"the gate no longer records the producer as deliberately not ready", {})
	if bool(state.get(READINESS_FORWARD_ONLY, false)) != true:
		return _fail(&"sealed_readiness_drift",
			"the presentation producer regressed below its finished DEVIATION-5 state", {})
	return _ok({
		"agreed": READINESS_MUST_MATCH.duplicate(),
		"forward_only": READINESS_FORWARD_ONLY,
		"forward_only_reason": "DEVIATION-5 finished after the historical gate was sealed",
	})


# =============================================================================================
# Requirement attestation and the deferred OYO3 composition.
# =============================================================================================

static func _validate_requirement_attestation(gate: Dictionary, desktop: Dictionary,
		minesweeper: Dictionary) -> Dictionary:
	var attested: Dictionary = {}
	for seal: Dictionary in [gate, desktop, minesweeper]:
		if typeof(seal.get("requirement_ids")) != TYPE_ARRAY:
			return _fail(&"requirement_attestation_drift", "a seal records no requirement ids", {})
		for item: Variant in seal["requirement_ids"] as Array:
			attested[str(item)] = true
	var attested_ids: Array[String] = []
	var unattested_ids: Array[String] = []
	for requirement: String in TASK2_REQUIREMENT_IDS:
		if attested.has(requirement):
			attested_ids.append(requirement)
		else:
			unattested_ids.append(requirement)
	attested_ids.sort()
	unattested_ids.sort()
	if unattested_ids != TASK2_UNATTESTED_REQUIREMENT_IDS:
		return _fail(&"requirement_attestation_drift",
			"the attested/unattested requirement split is not the recorded one",
			{"observed_unattested": unattested_ids,
				"recorded_unattested": TASK2_UNATTESTED_REQUIREMENT_IDS})
	return _ok({
		"requirement_ids": TASK2_REQUIREMENT_IDS.duplicate(),
		"attested_by_seals": attested_ids,
		"unattested_by_seals": unattested_ids,
	})


## Task 2 proves the contracts CAN be consumed later; it must never look like the later owner has
## already consumed them.
##
## RECORDED DIVERGENCE FROM PLAN 04 TASK 2 STEP 2. That step, written 2026-08-11, says "The
## production consequence coordinator remains condition-policy-unconfigured at the Phase-2R
## handoff". THAT SENTENCE IS FALSE AT HEAD and asserting it would redden this guard against a
## maintainer-approved seal that postdates it: the dwm-oyo.3 slice (2026-08-24) composed the
## condition pair with Plan 03's real ports, and the re-sealed desktop_contract.json records
## consequence_coordinator_contract.fail_closed_until as "FULFILLED by the dwm-oyo.3 slice
## (2026-08-24)". The seal is the later authority, so this guard binds to the seal.
##
## WHAT IS ENFORCED IN ITS PLACE, since the original boundary still has to hold somewhere: both
## ScheduleView and destination-composition ownership must still read dwm-oyo.3,
## destination_composition_ready must still be false, and Dating must still be deferred in BOTH the
## seal and the live probe. condition_policy_port_instance_id is therefore admitted as a configured
## extension rather than required absent.
static func _validate_deferred_composition(state: Dictionary, desktop: Dictionary,
		gate: Dictionary) -> Dictionary:
	if str(desktop.get("schedule_view_owner", "")) != OYO3_OWNER \
			or str(desktop.get("destination_composition_owner", "")) != OYO3_OWNER:
		return _fail(&"oyo_composition_claimed",
			"the later ScheduleView/destination composition is no longer owned by dwm-oyo.3",
			{"schedule_view_owner": desktop.get("schedule_view_owner", ""),
				"destination_composition_owner": desktop.get("destination_composition_owner", "")})
	if bool(state.get("destination_composition_ready", true)) != false:
		return _fail(&"oyo_composition_claimed",
			"the destination composition claims readiness inside Phase 2R", {})
	var readiness: Variant = (gate.get("bootstrap_probe", {}) as Dictionary).get("readiness", {})
	if typeof(readiness) != TYPE_DICTIONARY \
			or bool((readiness as Dictionary).get("dating_presentation_ready", true)) != false:
		return _fail(&"oyo_composition_claimed",
			"the gate no longer records Dating as deliberately not ready", {})
	if bool(state.get("dating_presentation_ready", true)) != false:
		return _fail(&"oyo_composition_claimed",
			"the Dating presentation claims readiness inside Phase 2R; dwm-oyo.4 owns it", {})
	return _ok({
		"schedule_view_owner": OYO3_OWNER,
		"destination_composition_owner": OYO3_OWNER,
		"destination_composition_ready": false,
		"dating_presentation_ready": false,
		"dating_production_owner": "dwm-oyo.4",
	})


# =============================================================================================
# Read-only Git plumbing.
# =============================================================================================

## Walks UP from the project directory to the nearest Git repository, so the guard never assumes
## res:// is the repository root. In a worktree, .git is a FILE, not a directory.
static func _repository_root() -> String:
	var cursor: String = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	for _depth: int in range(16):
		if cursor.is_empty():
			return ""
		if DirAccess.dir_exists_absolute(cursor.path_join(".git")) \
				or FileAccess.file_exists(cursor.path_join(".git")):
			return cursor
		var parent: String = cursor.get_base_dir()
		if parent == cursor or parent.is_empty():
			return ""
		cursor = parent
	return ""


## Resolves the real git directory ONCE so every later read can carry --git-dir and --work-tree
## beside -C. `git -C` alone gives NO repository containment: from a missing or empty directory git
## walks UP to whatever repository encloses it, and that escape rewrote this branch once during
## Task 1.
##
## THIS DISCOVERY CALL IS THE ONE EXEMPTION, because it is what produces the --git-dir every other
## call then uses. It is safe for a reason, not by luck: _repository_root() has already proved a
## .git exists at exactly this path, so there is no upward walk left to make. The result is then
## required to sit inside repository_root, so a surprising answer fails closed rather than
## redirecting every later read at another repository.
static func _git_directory(repository_root: String) -> String:
	if _git_directory_memo.has(repository_root):
		return str(_git_directory_memo[repository_root])
	var output: Array = []
	var exit_code: int = OS.execute("git", PackedStringArray([
		"-c", "safe.directory=%s" % repository_root, "-C", repository_root,
		"rev-parse", "--absolute-git-dir",
	]), output, false)
	var resolved: String = "" if exit_code != 0 else "".join(PackedStringArray(output)).strip_edges()
	if not resolved.is_empty() and not _serves_this_tree(repository_root):
		resolved = ""
	_git_directory_memo[repository_root] = resolved
	return resolved


## The git dir must belong to THIS working tree. Note what that cannot be: a path test. This
## checkout is a linked worktree, so its git dir is deliberately inside the MAIN repository
## (dwm/.git/worktrees/<name>) and is correctly NOT under repository_root -- an "is it contained in
## the root" assertion rejects the real repository outright, which is exactly what it did on the
## first attempt. Asking git which working tree it is serving is both correct and worktree-safe.
static func _serves_this_tree(repository_root: String) -> bool:
	var output: Array = []
	var exit_code: int = OS.execute("git", PackedStringArray([
		"-c", "safe.directory=%s" % repository_root, "-C", repository_root,
		"rev-parse", "--show-toplevel",
	]), output, false)
	if exit_code != 0:
		return false
	var toplevel: String = "".join(PackedStringArray(output)).strip_edges().simplify_path() \
		.trim_suffix("/")
	return toplevel.nocasecmp_to(repository_root.simplify_path().trim_suffix("/")) == 0


static func _contained_arguments(repository_root: String) -> PackedStringArray:
	var git_directory: String = _git_directory(repository_root)
	if git_directory.is_empty():
		return PackedStringArray()
	return PackedStringArray([
		"-c", "safe.directory=%s" % repository_root,
		"--git-dir=%s" % git_directory, "--work-tree=%s" % repository_root, "-C", repository_root,
	])


## A seal must name a commit that is BOTH readable here and on HEAD's own history. Merely
## existing in the object database is not evidence, and that is not hypothetical in this
## repository: the gate itself records a quarantined evidence-only branch tip, and an abandoned
## amendment relabel survives in the reflog. A seal pointing at either would attest bytes that no
## released history contains. Ancestry is tested FIRST so an unreadable object and an off-history
## object fail the same single guard rather than two branches sharing one code, only one of which
## any test could reach.
static func _reachable_subject(repository_root: String, commit: String) -> Dictionary:
	if not _is_ancestor(repository_root, commit):
		return {"ok": false}
	return _commit_subject(repository_root, commit)


static func _commit_subject(repository_root: String, commit: String) -> Dictionary:
	var arguments: PackedStringArray = _contained_arguments(repository_root)
	if arguments.is_empty():
		return {"ok": false}
	arguments.append_array(PackedStringArray(["show", "-s", "--format=%s", commit]))
	var output: Array = []
	if OS.execute("git", arguments, output, false) != 0:
		return {"ok": false}
	return {"ok": true, "value": "".join(PackedStringArray(output)).strip_edges()}


static func _is_ancestor(repository_root: String, commit: String) -> bool:
	var arguments: PackedStringArray = _contained_arguments(repository_root)
	if arguments.is_empty():
		return false
	arguments.append_array(PackedStringArray(["merge-base", "--is-ancestor", commit, "HEAD"]))
	var output: Array = []
	return OS.execute("git", arguments, output, false) == 0


## Memoized sha256 of one committed blob.
static func _blob_digest(repository_root: String, commit: String, path: String) -> Dictionary:
	var memo_key: String = "%s:%s:%s" % [repository_root, commit, path]
	# Only SUCCESS is memoized. A transient git failure must not become a sticky drift verdict for
	# the rest of the process, so a miss is simply retried.
	if _blob_digest_memo.has(memo_key):
		return {"ok": true, "value": str(_blob_digest_memo[memo_key])}
	var read: Dictionary = _blob_scratch(repository_root, commit, path)
	if not read.get("ok", false):
		return {"ok": false}
	var digest: String = _GIT.digest_bytes(read["value"])
	_blob_digest_memo[memo_key] = digest
	return {"ok": true, "value": digest}


## Reads a blob's exact bytes through a process-local scratch file, which is then deleted.
## OS.execute() decodes stdout into lines with separators dropped and cannot reproduce arbitrary
## bytes faithfully, and on Windows the cmd.exe file redirect is also what keeps quote characters
## intact.
static func _blob_scratch(repository_root: String, commit: String, path: String) -> Dictionary:
	var git_directory: String = _git_directory(repository_root)
	if git_directory.is_empty():
		return {"ok": false}
	var object_name: String = "%s:%s" % [commit, path]
	var scratch: String = OS.get_user_data_dir().path_join("p2r10-handoff-blob-%d-%s.tmp" % [
		OS.get_process_id(), _GIT.digest_bytes(object_name.to_utf8_buffer()).substr(0, 16),
	])
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var windows: bool = OS.get_name() == "Windows"
	var shell: String = "cmd.exe" if windows else "sh"
	var shell_flag: String = "/c" if windows else "-c"
	var command: String = "git -c safe.directory=\"%s\" --git-dir=\"%s\" --work-tree=\"%s\" -C \"%s\" cat-file blob \"%s\" > \"%s\"" % [
		repository_root, git_directory, repository_root, repository_root, object_name, scratch,
	]
	var output: Array = []
	var exit_code: int = OS.execute(shell, PackedStringArray([shell_flag, command]), output, true)
	if exit_code != 0 or not FileAccess.file_exists(scratch):
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(scratch)
		return {"ok": false}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	DirAccess.remove_absolute(scratch)
	return {"ok": true, "value": bytes}


## Reads a committed blob as text. Shares _blob_digest()'s scratch-file route for the same reason:
## OS.execute() drops separators when decoding stdout into lines.
static func _blob_text(repository_root: String, commit: String, path: String) -> Dictionary:
	var scratch: Dictionary = _blob_scratch(repository_root, commit, path)
	if not scratch.get("ok", false):
		return {"ok": false}
	var bytes: PackedByteArray = scratch["value"]
	return {"ok": true, "value": bytes.get_string_from_utf8()}


static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
