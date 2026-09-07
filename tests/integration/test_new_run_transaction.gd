extends "res://addons/gut/test.gd"
# start_new_run transaction over the real run participant + fake owners
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
# Plan 02 Task 6 (dwm-p2r.32): New Run now allocates a REAL desktop identity through the real
# DesktopIssuerRootStore/DesktopIdentityNonceIssuer pair (a deterministic FakeDesktopNamespaceSource
# stands in only for the namespace's entropy source, matching Task 1's own test precedent) rather
# than echoing a caller-supplied run_id.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const GS_PATH := "res://autoload/GameState.gd"
const RUN_PARTICIPANT := "res://scripts/application/restore/RunRestoreParticipant.gd"
const FAKE_PARTICIPANT := "res://tests/support/FakeRestoreParticipant.gd"
const CALL_LOG := "res://tests/support/RestoreCallLog.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const FAKE_NAMESPACE_SOURCE := "res://tests/support/FakeDesktopNamespaceSource.gd"
## Plan 02 Task 6 (dwm-p2r.32), Phase C2: start_new_run() now builds real desktop_consequence/
## desktop_board plans by calling `.prepare()` on the configured participants (mirroring how it
## already calls the real RunRestoreParticipant's prepare_new_run()), so these two must be the REAL
## classes -- a generic FakeRestoreParticipant's prepare() returns the wrong shape.
const DESKTOP_CONSEQUENCE_STATE := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const DESKTOP_BOARD_STATE := "res://scripts/domain/minesweeper/DesktopBoardState.gd"
const DESKTOP_CONSEQUENCE_PARTICIPANT := "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
const DESKTOP_BOARD_PARTICIPANT := "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"

## dwm-p2r.33: start_new_run() now routes profile/localization/audio through their participants'
## real prepare() seam and reads the production-shaped keys (`profile_plan`+`locale_id`,
## `localization_plan`, `audio_plan`) from those preps, so the three fakes must return those exact
## shapes -- the generic FakeRestoreParticipant's `{"plan": {...}}` no longer suffices, mirroring
## test_desktop_continuation_resume.gd's own ShapedFakeParticipant precedent.
class ShapedFakeParticipant extends RefCounted:
	var _id: String
	var _plan_key: String
	var _log: RefCounted
	var _extra_value: Dictionary
	var fail_at: StringName = &""
	var observed_journal: RefCounted
	var journal_at_finalize: Dictionary = {}

	func _init(participant_id: String, plan_key: String, call_log: RefCounted, extra_value: Dictionary = {}) -> void:
		_id = participant_id
		_plan_key = plan_key
		_log = call_log
		_extra_value = extra_value

	func prepare(input: Dictionary) -> Dictionary:
		_log.record(_id, "prepare")
		var value: Dictionary = {_plan_key: {"id": _id, "input": input.duplicate(true)}}
		for key: String in _extra_value:
			value[key] = _extra_value[key]
		return {"ok": true, "code": &"ok", "value": value}

	func capture() -> Dictionary:
		_log.record(_id, "capture")
		return {"ok": true, "code": &"ok", "value": {"backup": {"id": _id}}}

	func apply_silent(plan: Variant) -> Dictionary:
		_log.record(_id, "apply_silent")
		if fail_at == &"apply_silent": return {"ok":false,"code":&"fixture_apply_failure"}
		return {"ok": true, "code": &"ok", "value": {"applied": _id, "plan": plan}}

	func rollback_silent(backup: Dictionary) -> Dictionary:
		_log.record(_id, "rollback_silent")
		return {"ok": true, "code": &"ok", "value": {"rolled_back": _id, "backup": backup}}

	func finalize() -> Dictionary:
		_log.record(_id, "finalize")
		if observed_journal != null: journal_at_finalize = observed_journal.capture_state()["value"]["backup"]
		if fail_at == &"finalize": return {"ok":false,"code":&"fixture_finalize_failure"}
		return {"ok": true, "code": &"ok"}

func _initial_context() -> Dictionary:
	return {"route_id": "opening", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}

func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	assert_true(manager._journal.reset("run-a")["ok"])

	var issuer_root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_issuer").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(issuer_root)
	var root_store: RefCounted = load(ROOT_STORE_PATH).new()
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE).new("3".repeat(64))
	assert_true(root_store.configure(load(STORAGE_PATH).new(issuer_root), namespace_source)["ok"])
	assert_true(root_store.load_or_create()["ok"])
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(root_store)["ok"])
	assert_true(manager.configure_identity_issuer(issuer)["ok"])

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var log: RefCounted = load(CALL_LOG).new()
	assert_true(manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"desktop_consequence": load(DESKTOP_CONSEQUENCE_PARTICIPANT).new(load(DESKTOP_CONSEQUENCE_STATE).new()),
		"desktop_board": load(DESKTOP_BOARD_PARTICIPANT).new(load(DESKTOP_BOARD_STATE).new()),
		"profile": ShapedFakeParticipant.new("profile", "profile_plan", log, {"locale_id": "en"}),
		"localization": ShapedFakeParticipant.new("localization", "localization_plan", log),
		"audio": ShapedFakeParticipant.new("audio", "audio_plan", log),
		"route": load(FAKE_PARTICIPANT).new("route", log),
		"narrative": load(FAKE_PARTICIPANT).new("narrative", log),
	})["ok"])
	return {"manager": manager, "gate": gate, "gs": gs, "log": log, "issuer": issuer}

func test_start_new_run_rejects_bad_context() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	assert_eq(manager.start_new_run({"route_id": "main"}).get("code"), &"invalid_initial_context")
	var extra := _initial_context()
	extra["surprise"] = 1
	assert_eq(manager.start_new_run(extra).get("code"), &"invalid_initial_context")

func test_start_new_run_builds_day1_run_b() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	# Plan 02 Task 6 (dwm-p2r.32): start_new_run() no longer accepts a caller-supplied run_id at all
	# -- the real identity comes entirely from the desktop issuer's own durable allocation.
	var result: Dictionary = manager.start_new_run(_initial_context())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var allocated_run_id: String = str(result["value"]["run_id"])
	assert_ne(allocated_run_id, "", "the issuer allocates a real, nonblank run_id")
	assert_ne(allocated_run_id, "run-b", "the caller-supplied run_id is never adopted directly")
	assert_eq(result["value"]["checkpoint_id"], "%s:1" % allocated_run_id, "Run-B starts at sequence 1")
	assert_eq(result["value"]["route_id"], "opening")
	assert_eq(int(manager._journal.peek_next_sequence(allocated_run_id)["value"]["checkpoint_sequence"]), 2)
	assert_eq(manager._journal.get_bundles_for_disk(), [], "a fresh run has no earlier bundles")
	assert_eq(wired["gs"].day, 1, "live GameState is now Day 1 of the new run")
	assert_false(wired["gate"].is_active(), "gate released after the new-run transaction")
	assert_false(manager.is_save_locked(), "no lingering save lock")
	assert_eq(str(wired["gs"]._run_lifecycle.get_desktop_identity_context()["run_id"]), allocated_run_id,
		"the live lifecycle's run_id matches the allocated identity")

func test_start_new_run_requires_identity_issuer() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_no_issuer").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var log: RefCounted = load(CALL_LOG).new()
	manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"desktop_consequence": load(FAKE_PARTICIPANT).new("desktop_consequence", log),
		"desktop_board": load(FAKE_PARTICIPANT).new("desktop_board", log),
		"profile": load(FAKE_PARTICIPANT).new("profile", log),
		"localization": load(FAKE_PARTICIPANT).new("localization", log),
		"audio": load(FAKE_PARTICIPANT).new("audio", log),
		"route": load(FAKE_PARTICIPANT).new("route", log),
		"narrative": load(FAKE_PARTICIPANT).new("narrative", log),
	})
	# The identity-issuer guard runs before any participant is ever consulted, so fakes suffice here.
	var result: Dictionary = manager.start_new_run(_initial_context())
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"identity_issuer_not_configured")

func test_start_new_run_allocates_a_fresh_identity_per_call() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	var first: Dictionary = manager.start_new_run(_initial_context())
	assert_true(first.get("ok", false), JSON.stringify(first))
	# A second New Run over the same manager needs a fresh GameState/participant set (the first run
	# already occupies the live one), but the SAME issuer must allocate a genuinely different branch.
	var context: Dictionary = wired["gs"]._run_lifecycle.get_desktop_identity_context()
	assert_false(str(context["branch_id"]).is_empty(), "a real branch_id was allocated")
	assert_false(str(context["causal_day_instance"]).is_empty(), "a real causal_day_instance was allocated")
	assert_eq(int(context["desktop_timeline_generation"]), 0, "New Run always opens generation zero")

func test_start_new_run_requires_participants() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_np").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	assert_eq(manager.start_new_run(_initial_context()).get("code"),
		&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED")


class FailingJournal extends "res://scripts/infrastructure/save/CheckpointJournal.gd":
	var refuse_commit := false
	var refuse_rollback := false
	var rollback_attempts := 0
	func commit_prepared(candidate: Dictionary) -> Dictionary:
		if refuse_commit: return {"ok":false,"code":&"fixture_journal_commit_failure"}
		return super.commit_prepared(candidate)
	func restore_state(backup: Dictionary) -> Dictionary:
		rollback_attempts += 1
		if refuse_rollback: return {"ok":false,"code":&"fixture_journal_rollback_failure"}
		return super.restore_state(backup)

func _seed_populated_journal(wired: Dictionary) -> Dictionary:
	var manager: Node = wired.manager
	var started: Dictionary = manager.start_new_run(_initial_context())
	assert_true(started.get("ok",false),JSON.stringify(started))
	if not started.get("ok",false): return {}
	var snapshot: Dictionary = manager._journal.get_current_bundle()["value"]["bundle"]["snapshot"].duplicate(true)
	snapshot.checkpoint_sequence = 2
	snapshot.checkpoint_id = str(snapshot.run_id)+":2"
	var prepared: Dictionary = manager._journal.prepare_record(snapshot,&"safe_marker")
	assert_true(prepared.get("ok",false),JSON.stringify(prepared))
	if not prepared.get("ok",false): return {}
	assert_true(manager._journal.commit_prepared(prepared.value.candidate).ok)
	var baseline: Dictionary = manager._journal.capture_state().value.backup
	assert_eq(baseline.earlier.size(),1,"The rollback baseline contains real earlier checkpoint history")
	assert_eq(baseline.current.snapshot.checkpoint_sequence,2)
	return baseline

func test_finalize_failure_restores_original_live_run_and_populated_checkpoint_history() -> void:
	var wired := _wired()
	var before := _seed_populated_journal(wired)
	if before.is_empty(): return
	var manager: Node = wired.manager
	var live_before: Dictionary = wired.gs.capture_restore_state()
	var audio: ShapedFakeParticipant = manager._restore_participants.audio
	audio.observed_journal = manager._journal
	audio.fail_at = &"finalize"
	var result: Dictionary = manager.start_new_run(_initial_context())
	assert_false(result.ok)
	assert_eq(result.code,&"fixture_finalize_failure")
	assert_ne(audio.journal_at_finalize.current.snapshot.run_id,before.current.snapshot.run_id,"The failure occurs after the candidate journal has actually committed")
	assert_eq(audio.journal_at_finalize.earlier,[])
	assert_eq(manager._journal.capture_state().value.backup,before,"Rollback restores current checkpoint, history and sequence together")
	assert_eq(wired.gs.capture_restore_state(),live_before,"The same real live run is restored")
	assert_false(wired.gate.is_active())
	assert_false(wired.gate.is_fatal_latched())
	assert_false(manager.is_save_locked())

func test_successful_finalization_keeps_new_checkpoint_instead_of_restoring_backup() -> void:
	var wired := _wired()
	var before := _seed_populated_journal(wired)
	if before.is_empty(): return
	var result: Dictionary = wired.manager.start_new_run(_initial_context())
	assert_true(result.get("ok",false),JSON.stringify(result))
	if not result.get("ok",false): return
	var after: Dictionary = wired.manager._journal.capture_state().value.backup
	assert_ne(after.run_id,before.run_id)
	assert_eq(after.current.snapshot.checkpoint_id,result.value.checkpoint_id)
	assert_eq(after.earlier,[])
	assert_eq(after.next_sequence,2)
	assert_eq(wired.gs._run_lifecycle.get_desktop_identity_context().run_id,after.run_id)
	assert_false(wired.gate.is_active())

func test_precommit_and_participant_apply_failures_leave_populated_journal_unchanged() -> void:
	for phase: String in ["invalid_context","apply","journal_commit"]:
		var wired := _wired()
		var before := _seed_populated_journal(wired)
		if before.is_empty(): continue
		var manager: Node = wired.manager
		var live_before: Dictionary = wired.gs.capture_restore_state()
		var context := _initial_context()
		var journal := FailingJournal.new()
		assert_true(journal.restore_state(before).ok)
		journal.rollback_attempts = 0
		manager._journal = journal
		if phase == "invalid_context": context.route_id = "main"
		elif phase == "apply": manager._restore_participants.audio.fail_at = &"apply_silent"
		else: journal.refuse_commit = true
		var result: Dictionary = manager.start_new_run(context)
		assert_false(result.ok,phase)
		assert_eq(manager._journal.capture_state().value.backup,before,phase)
		assert_eq(wired.gs.capture_restore_state(),live_before,phase)
		assert_eq(journal.rollback_attempts,0,"A journal never committed by this attempt needs no compensation")
		assert_false(wired.gate.is_active(),phase)

func test_failed_checkpoint_compensation_latches_fatal_after_attempting_live_rollback() -> void:
	var wired := _wired()
	var before := _seed_populated_journal(wired)
	if before.is_empty(): return
	var manager: Node = wired.manager
	var live_before: Dictionary = wired.gs.capture_restore_state()
	var journal := FailingJournal.new()
	assert_true(journal.restore_state(before).ok)
	journal.rollback_attempts = 0
	journal.refuse_rollback = true
	manager._journal = journal
	manager._restore_participants.audio.fail_at = &"finalize"
	var result: Dictionary = manager.start_new_run(_initial_context())
	assert_false(result.ok)
	assert_eq(journal.rollback_attempts,1)
	assert_true(wired.gate.is_fatal_latched(),"A failed checkpoint rollback cannot return an ordinary retryable failure")
	assert_eq(result.code,&"APPLICATION_FATAL")
	assert_eq(wired.gs.capture_restore_state(),live_before,"Journal rollback failure does not skip participant compensation")
	assert_ne(manager._journal.capture_state().value.backup,before,"The test does not pretend the refused journal rollback succeeded")
