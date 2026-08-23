extends "res://addons/gut/test.gd"
# dwm-p2r.13 remediation: crash-boundary resume tests for New Run / restore continuation
# (findings B-C1 "gate lease acquired too late", B-C2 "nothing resumes a continuation forward",
# B-C3 "the cross-task advance() comment describes a pass that never existed", B-C4 "the abort/
# failure half is unreachable"). Frozen law: plan02-frozen-contracts.md around line 543.
#
# Each "crash boundary" test proves the continuation genuinely RESUMES to completion on the next
# reconciliation pass -- not merely that reconcile_incomplete_continuations() reports ok -- by
# asserting the journal operation reaches `completed` AND that the live participant state (Day-1
# GameState) reflects a genuine re-application.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const GS_PATH := "res://autoload/GameState.gd"
const RUN_PARTICIPANT := "res://scripts/application/restore/RunRestoreParticipant.gd"
const CALL_LOG := "res://tests/support/RestoreCallLog.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const FAKE_NAMESPACE_SOURCE := "res://tests/support/FakeDesktopNamespaceSource.gd"
const DESKTOP_CONSEQUENCE_STATE := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const DESKTOP_BOARD_STATE := "res://scripts/domain/minesweeper/DesktopBoardState.gd"
const DESKTOP_CONSEQUENCE_PARTICIPANT := "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
const DESKTOP_BOARD_PARTICIPANT := "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONTINUATION_JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")

const PARTICIPANT_APPLY_ORDER: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "profile", "localization", "audio", "route", "narrative",
]

## Unlike tests/support/FakeRestoreParticipant.gd (a generic `{"plan": {...}}` fake, used elsewhere
## for the participants a scenario never actually restores through), this returns the
## production-shaped `prepare()` value each real participant returns (`profile_plan`+`locale_id`,
## `localization_plan`, `audio_plan`, `route_plan`, `narrative_plan`) -- required here because these
## tests exercise a genuine `prepare_restore_slot()`/`_prepare_bundle_with_all_participants()` call,
## which reads those exact keys. Its content is never validated the way ProfileSchema/
## LocalizationManager would (that content-validation gap is gap dwm-p2r.33, explicitly out of this
## remediation's scope); this fake only needs to be shape-compatible so the SaveManager/journal/gate
## machinery under test -- not participant content validation -- is what's exercised.
class ShapedFakeParticipant extends RefCounted:
	var _id: String
	var _plan_key: String
	var _log: RefCounted
	var _extra_value: Dictionary
	var _fail_at: StringName = &""

	func _init(participant_id: String, plan_key: String, call_log: RefCounted, extra_value: Dictionary = {}) -> void:
		_id = participant_id
		_plan_key = plan_key
		_log = call_log
		_extra_value = extra_value

	func set_failure(position: StringName) -> void:
		_fail_at = position

	func prepare(input: Dictionary) -> Dictionary:
		_log.record(_id, "prepare")
		if _fail_at == &"prepare":
			return {"ok": false, "code": &"forced_prepare_failure", "message": "", "details": {}}
		var value: Dictionary = {_plan_key: {"id": _id, "input": input.duplicate(true)}}
		for key: String in _extra_value:
			value[key] = _extra_value[key]
		return {"ok": true, "code": &"ok", "value": value}

	func capture() -> Dictionary:
		_log.record(_id, "capture")
		return {"ok": true, "code": &"ok", "value": {"backup": {"id": _id}}}

	func apply_silent(plan: Variant) -> Dictionary:
		_log.record(_id, "apply_silent")
		if _fail_at == &"apply_silent":
			return {"ok": false, "code": &"forced_apply_failure", "message": "", "details": {}}
		return {"ok": true, "code": &"ok", "value": {"applied": _id, "plan": plan}}

	func rollback_silent(backup: Dictionary) -> Dictionary:
		_log.record(_id, "rollback_silent")
		return {"ok": true, "code": &"ok", "value": {"rolled_back": _id, "backup": backup}}

	func finalize() -> Dictionary:
		_log.record(_id, "finalize")
		return {"ok": true, "code": &"ok"}

func _initial_context() -> Dictionary:
	return {"route_id": "opening", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}

## Builds one full "process" (SaveManager + GameState + real issuer + real gate + real desktop
## board/consequence participants + fake profile/localization/audio/route/narrative participants,
## mirroring tests/integration/test_new_run_transaction.gd's own established wiring) over the given
## storage roots. Calling this twice with the SAME roots models a fresh process reopening the same
## on-disk state after a crash, exactly like test_desktop_crash_recovery.gd's _boot_process().
func _wired(save_root: String, issuer_root: String, fail_profile_once: bool) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(save_root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(save_root))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	assert_true(manager._journal.reset("run-a")["ok"])

	DirAccess.make_dir_recursive_absolute(issuer_root)
	var root_store: RefCounted = load(ROOT_STORE_PATH).new()
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE).new("4".repeat(64))
	assert_true(root_store.configure(load(STORAGE_PATH).new(issuer_root), namespace_source)["ok"])
	assert_true(root_store.load_or_create()["ok"])
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(root_store)["ok"])
	assert_true(manager.configure_identity_issuer(issuer)["ok"])

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var log: RefCounted = load(CALL_LOG).new()
	var profile_fake: RefCounted = ShapedFakeParticipant.new("profile", "profile_plan", log, {"locale_id": "en"})
	if fail_profile_once:
		profile_fake.set_failure(&"apply_silent")
	assert_true(manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"desktop_consequence": load(DESKTOP_CONSEQUENCE_PARTICIPANT).new(load(DESKTOP_CONSEQUENCE_STATE).new()),
		"desktop_board": load(DESKTOP_BOARD_PARTICIPANT).new(load(DESKTOP_BOARD_STATE).new()),
		"profile": profile_fake,
		"localization": ShapedFakeParticipant.new("localization", "localization_plan", log),
		"audio": ShapedFakeParticipant.new("audio", "audio_plan", log),
		"route": ShapedFakeParticipant.new("route", "route_plan", log),
		"narrative": ShapedFakeParticipant.new("narrative", "narrative_plan", log),
	})["ok"])
	return {"manager": manager, "gate": gate, "gs": gs, "log": log, "issuer": issuer, "profile_fake": profile_fake}

func _wired_single() -> Dictionary:
	var save_root := OS.get_environment("DWM_TEST_ROOT").path_join("continuation_resume").path_join(str(randi())).path_join("saves")
	var issuer_root := OS.get_environment("DWM_TEST_ROOT").path_join("continuation_resume_issuer").path_join(str(randi()))
	return _wired(save_root, issuer_root, false)

static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()

## Mirrors `SaveManager._begin_new_run_continuation()`'s FIRST HALF only (through `commit_intent`),
## stopping deliberately BEFORE the identity mint -- the one interruption point production code
## never pauses at synchronously, so the "after intent_committed" crash boundary can only be
## constructed by hand.
func _manual_new_run_intent(manager: Node, issuer: RefCounted, initial_context: Dictionary) -> Dictionary:
	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	assert_true(issued.get("ok", false), "issue transaction_id")
	var transaction_id := str(issued["value"]["token"])
	var transaction_issuer_receipt: Dictionary = issued["value"]["issuer_receipt"]
	var request := {
		"existing_run_id": null, "kind": "new_run", "remap_source_transaction_ids": [],
		"source_desktop_timeline_generation": null, "transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	}
	var prepared_alloc: Dictionary = issuer.call(&"prepare_continuation_allocation", request)
	assert_true(prepared_alloc.get("ok", false), "prepare_continuation_allocation")
	var raw_candidate: Dictionary = prepared_alloc["value"]
	var allocation_fingerprint := _canonical_sha256(raw_candidate)
	var initial_context_hash := _canonical_sha256(initial_context)
	var request_fingerprint := _canonical_sha256({
		"kind": "new_run", "transaction_id": transaction_id, "initial_context": initial_context,
	})
	var intent_prepared: Dictionary = manager._continuation_journal.prepare_intent({
		"allocation_candidate_fingerprint": allocation_fingerprint, "initial_context": initial_context,
		"initial_context_sha256": initial_context_hash, "kind": "new_run",
		"request_fingerprint": request_fingerprint, "source_locator": null,
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt,
	})
	assert_true(intent_prepared.get("ok", false), "prepare_intent: " + JSON.stringify(intent_prepared))
	var committed: Dictionary = manager._continuation_journal.commit_intent(intent_prepared["value"])
	assert_true(committed.get("ok", false), "commit_intent: " + JSON.stringify(committed))
	return {
		"transaction_id": transaction_id, "request_fingerprint": request_fingerprint,
		"allocation_candidate_fingerprint": allocation_fingerprint, "raw_candidate": raw_candidate,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	}

## Extends the intent above through the real, durable identity mint and the STAGE_ALLOCATED
## advance -- mirrors `_begin_new_run_continuation()`'s second half, stopping deliberately BEFORE
## the STAGE_APPLYING advance (production code never pauses there either).
func _manual_allocated(manager: Node, issuer: RefCounted, intent: Dictionary) -> Dictionary:
	var committed: Dictionary = issuer.call(&"commit_continuation_allocation", intent["raw_candidate"])
	assert_true(committed.get("ok", false), "commit_continuation_allocation")
	var allocated: Dictionary = committed["value"]
	var advanced: Dictionary = manager._continuation_journal.advance({
		"transaction_id": intent["transaction_id"], "request_fingerprint": intent["request_fingerprint"],
		"expected_stage": CONTINUATION_JOURNAL.STAGE_INTENT, "next_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED,
		"expected_next_participant_index": 0, "allocation_receipt": allocated,
		"participant_name": null, "participant_receipt": null, "failure": null,
	})
	assert_true(advanced.get("ok", false), "advance to allocated: " + JSON.stringify(advanced))
	return allocated

## Drives `apply_count` of the 8 participants through apply_silent()+advance() by hand -- the exact
## same calls `SaveManager._run_participant_transaction()`'s own loop makes -- to construct the
## "mid-participants"/"after participants_applied" crash boundaries at an exact, chosen index
## without depending on which real participant happens to fail first.
func _manual_applying(manager: Node, initial_context: Dictionary, intent: Dictionary, allocated: Dictionary,
		apply_count: int, advance_to_applied: bool) -> void:
	var advanced_to_applying: Dictionary = manager._continuation_journal.advance({
		"transaction_id": intent["transaction_id"], "request_fingerprint": intent["request_fingerprint"],
		"expected_stage": CONTINUATION_JOURNAL.STAGE_ALLOCATED, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
		"expected_next_participant_index": 0, "allocation_receipt": null,
		"participant_name": null, "participant_receipt": null, "failure": null,
	})
	assert_true(advanced_to_applying.get("ok", false), "advance to applying: " + JSON.stringify(advanced_to_applying))
	if apply_count == 0:
		return

	var identity := {
		"run_id": str(allocated["run_id"]), "branch_id": str(allocated["branch_id"]),
		"desktop_timeline_generation": int(allocated["desktop_timeline_generation"]),
		"causal_day_instance": str(allocated["causal_day_instance"]),
		"causal_day_instance_issuer_receipt": (allocated["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true),
	}
	var new_run: Dictionary = manager._restore_participants["run"].prepare_new_run(
		identity["run_id"], identity["branch_id"], identity["desktop_timeline_generation"],
		identity["causal_day_instance"], identity["causal_day_instance_issuer_receipt"])
	assert_true(new_run.get("ok", false), "prepare_new_run")
	var snapshot_input: Dictionary = new_run["value"]["snapshot_input"]
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		snapshot_input, initial_context["dialogic_checkpoint"], str(initial_context["route_id"]),
		initial_context["active_app_id"], initial_context["audio_context"],
		int(initial_context["content_version"]), 1)
	assert_true(built.get("ok", false), "RUN_SNAPSHOT_SCHEMA.build")
	var snapshot: Dictionary = built["value"]["snapshot"]
	var consequence_prep: Dictionary = manager._restore_participants["desktop_consequence"].prepare(
		{"state": snapshot["desktop"]["consequence"]})
	assert_true(consequence_prep.get("ok", false))
	var board_prep: Dictionary = manager._restore_participants["desktop_board"].prepare(
		{"state": snapshot["desktop"]["board"]})
	assert_true(board_prep.get("ok", false))
	var plans := {
		"run": {"snapshot": snapshot},
		"desktop_consequence": (consequence_prep["value"] as Dictionary)["consequence_plan"],
		"desktop_board": (board_prep["value"] as Dictionary)["board_plan"],
		"profile": {"profile": {}},
		"localization": {},
		"audio": {"snapshot": initial_context["audio_context"]},
		"route": {"route_id": str(initial_context["route_id"]), "route_context": {}},
		"narrative": {"narrative_checkpoint": initial_context["dialogic_checkpoint"]},
	}

	var route_ready_token: Variant = null
	for index: int in range(apply_count):
		var key: String = PARTICIPANT_APPLY_ORDER[index]
		var plan: Dictionary = (plans[key] as Dictionary).duplicate(true)
		if key == "narrative" and route_ready_token != null:
			plan["route_ready_token"] = route_ready_token
		var result: Dictionary = manager._restore_participants[key].apply_silent(plan)
		assert_true(result.get("ok", false), "apply_silent " + key + ": " + JSON.stringify(result))
		if key == "route":
			route_ready_token = (result.get("value", {}) as Dictionary).get("route_ready_token")
		var receipt_value: Variant = result.get("value", {})
		var participant_receipt: Dictionary = receipt_value if typeof(receipt_value) == TYPE_DICTIONARY else {}
		var advanced: Dictionary = manager._continuation_journal.advance({
			"transaction_id": intent["transaction_id"], "request_fingerprint": intent["request_fingerprint"],
			"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLYING, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLYING,
			"expected_next_participant_index": index, "allocation_receipt": null,
			"participant_name": key, "participant_receipt": participant_receipt, "failure": null,
		})
		assert_true(advanced.get("ok", false), "advance participant " + key + ": " + JSON.stringify(advanced))

	if advance_to_applied:
		var advanced_to_applied: Dictionary = manager._continuation_journal.advance({
			"transaction_id": intent["transaction_id"], "request_fingerprint": intent["request_fingerprint"],
			"expected_stage": CONTINUATION_JOURNAL.STAGE_APPLYING, "next_stage": CONTINUATION_JOURNAL.STAGE_APPLIED,
			"expected_next_participant_index": PARTICIPANT_APPLY_ORDER.size(), "allocation_receipt": null,
			"participant_name": null, "participant_receipt": null, "failure": null,
		})
		assert_true(advanced_to_applied.get("ok", false), "advance to applied: " + JSON.stringify(advanced_to_applied))

func _assert_resumed_to_completion(manager: Node, gs: Node, gate: RefCounted, transaction_id: String) -> void:
	var reconciled: Dictionary = manager.reconcile_incomplete_continuations()
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	var results: Array = (reconciled["value"] as Dictionary)["reconciled"]
	assert_eq(results.size(), 1, "exactly the one incomplete operation is reconciled")
	var entry_result: Dictionary = (results[0] as Dictionary)["result"]
	assert_true(entry_result.get("ok", false), "reconciling must not itself fail: " + JSON.stringify(entry_result))
	assert_eq(str((entry_result["value"] as Dictionary).get("outcome", "")), "completed",
		"the resume must genuinely complete the transaction, not merely report ok")

	var final_operation: Dictionary = manager._continuation_journal.get_operation(transaction_id)
	assert_true(final_operation.get("ok", false))
	assert_eq(str((final_operation["value"] as Dictionary).get("stage", "")), "completed",
		"the journal record itself reaches the completed stage, not just the reconcile call's report")
	assert_null((final_operation["value"] as Dictionary).get("failure"),
		"a genuinely completed operation carries no lingering diagnostic")

	assert_eq(gs.day, 1, "the live GameState is genuinely restored to Day 1, not just reported ok")
	assert_false(gate.is_active(), "the gate lease is released after resumed completion")
	assert_false(gate.is_fatal_latched(), "a genuine resume never latches a fatal")
	assert_false(manager.is_save_locked(), "no lingering save lock")

# -------------------------------------------------------------------------------------------------
# Finding B-C1: the gate lease is acquired BEFORE any identity is minted or journal intent written.
# -------------------------------------------------------------------------------------------------

func test_a_busy_gate_rejects_new_run_before_any_identity_is_minted_or_intent_is_written() -> void:
	var wired := _wired_single()
	var manager: Node = wired["manager"]
	var gate: RefCounted = wired["gate"]

	var occupied: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(occupied.get("ok", false), "occupy the gate with an unrelated owner first")

	var result: Dictionary = manager.start_new_run(_initial_context())
	assert_false(result.get("ok", true), "a busy gate must reject start_new_run outright")
	assert_eq(str(result.get("code", "")), "TRANSACTION_ACTIVE")

	var listed: Dictionary = manager._continuation_journal.list_incomplete()
	assert_true(listed.get("ok", false))
	assert_eq((listed["value"] as Array).size(), 0,
		"finding B-C1: a busy gate must reject BEFORE any journal intent is ever written -- the " \
		+ "identity was never minted and no record was ever stranded")

func test_a_busy_gate_rejects_restore_before_any_identity_is_minted_or_intent_is_written() -> void:
	var wired := _wired_single()
	var manager: Node = wired["manager"]
	var gate: RefCounted = wired["gate"]

	# Build one real completed run and a real save file so prepare_restore_slot() has something
	# genuine to select, matching production's own restore path (source_locator present).
	assert_true(manager.start_new_run(_initial_context()).get("ok", false))
	assert_true(manager.save_latest_to_slot(1).get("ok", false))
	var prepared_restore: Dictionary = manager.prepare_restore_slot(1)
	assert_true(prepared_restore.get("ok", false))

	var occupied: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(occupied.get("ok", false), "occupy the gate with an unrelated owner first")

	var before: Dictionary = manager._continuation_journal.list_incomplete()
	assert_true(before.get("ok", false))
	var incomplete_before: int = (before["value"] as Array).size()

	var result: Dictionary = manager.call(&"commit_prepared_restore", prepared_restore["value"]["prepared"])
	assert_false(result.get("ok", true), "a busy gate must reject commit_prepared_restore outright")
	assert_eq(str(result.get("code", "")), "TRANSACTION_ACTIVE")

	var after: Dictionary = manager._continuation_journal.list_incomplete()
	assert_true(after.get("ok", false))
	assert_eq((after["value"] as Array).size(), incomplete_before,
		"finding B-C1: a busy gate must reject BEFORE any restore intent is ever written")
	assert_false(manager.is_save_locked(),
		"finding B-C1: a busy gate must reject BEFORE the restore save lock is ever taken")

# -------------------------------------------------------------------------------------------------
# Finding B-C2: crash-boundary resume genuinely completes the transaction on the next boot.
# -------------------------------------------------------------------------------------------------

func test_crash_after_intent_committed_resumes_forward_to_completion() -> void:
	var wired := _wired_single()
	var manager: Node = wired["manager"]
	var issuer: RefCounted = wired["issuer"]
	var initial_context := _initial_context()
	var intent := _manual_new_run_intent(manager, issuer, initial_context)

	var listed: Dictionary = manager._continuation_journal.list_incomplete()
	assert_true(listed.get("ok", false))
	assert_eq((listed["value"] as Array).size(), 1)
	assert_eq(str((listed["value"] as Array)[0].get("stage", "")), CONTINUATION_JOURNAL.STAGE_INTENT)

	_assert_resumed_to_completion(manager, wired["gs"], wired["gate"], intent["transaction_id"])

func test_crash_after_allocation_resumes_forward_to_completion() -> void:
	var wired := _wired_single()
	var manager: Node = wired["manager"]
	var issuer: RefCounted = wired["issuer"]
	var initial_context := _initial_context()
	var intent := _manual_new_run_intent(manager, issuer, initial_context)
	_manual_allocated(manager, issuer, intent)

	var listed: Dictionary = manager._continuation_journal.list_incomplete()
	assert_true(listed.get("ok", false))
	assert_eq(str((listed["value"] as Array)[0].get("stage", "")), CONTINUATION_JOURNAL.STAGE_ALLOCATED)

	_assert_resumed_to_completion(manager, wired["gs"], wired["gate"], intent["transaction_id"])

func test_crash_mid_participants_resumes_to_completion_on_a_fresh_boot() -> void:
	var save_root := OS.get_environment("DWM_TEST_ROOT").path_join("continuation_resume_mid").path_join(str(randi())).path_join("saves")
	var issuer_root := OS.get_environment("DWM_TEST_ROOT").path_join("continuation_resume_mid_issuer").path_join(str(randi()))

	var process_a := _wired(save_root, issuer_root, true)
	var manager_a: Node = process_a["manager"]
	var failed: Dictionary = manager_a.start_new_run(_initial_context())
	assert_false(failed.get("ok", true), "the fake profile participant forces a mid-participants failure")

	var listed_a: Dictionary = manager_a._continuation_journal.list_incomplete()
	assert_true(listed_a.get("ok", false))
	assert_eq((listed_a["value"] as Array).size(), 1)
	var stuck: Dictionary = (listed_a["value"] as Array)[0]
	assert_eq(str(stuck.get("stage", "")), CONTINUATION_JOURNAL.STAGE_APPLYING)
	assert_eq(int(stuck.get("next_participant_index", -1)), 3,
		"run/desktop_consequence/desktop_board (indices 0-2) applied before profile (index 3) failed")

	# A fresh process reopens the SAME on-disk journal/issuer/save roots -- the fake profile
	# participant does not fail this time, modelling whatever transient condition caused the
	# original crash no longer being present on the next boot.
	var process_b := _wired(save_root, issuer_root, false)
	var manager_b: Node = process_b["manager"]
	_assert_resumed_to_completion(manager_b, process_b["gs"], process_b["gate"], str(stuck["transaction_id"]))

	# The three participants applied before the crash are re-applied fresh in process B (a fresh
	# process has fresh live objects) and REPLAY through the journal rather than double-recording;
	# profile onward genuinely apply for the first time.
	var log: RefCounted = process_b["log"]
	assert_true((log.for_participant("profile") as Array).has("apply_silent"))
	assert_true((log.for_participant("narrative") as Array).has("apply_silent"))

## Unlike the intent_committed/allocated boundaries above, constructing this one touches the live
## "run" participant (GameState) directly -- so it needs the SAME two-process pattern the
## mid-participants test uses. Reusing the SAME live GameState for both the manual construction and
## the reconcile call would make `prepare_new_run_snapshot_input()`'s own "don't reuse the run_id
## GameState already carries" guard fire spuriously (GameState.gd:1671-1672), which a genuine crash
## (a fresh process, fresh GameState) never would.
func test_crash_after_participants_applied_resumes_to_completion() -> void:
	var save_root := OS.get_environment("DWM_TEST_ROOT").path_join("continuation_resume_applied").path_join(str(randi())).path_join("saves")
	var issuer_root := OS.get_environment("DWM_TEST_ROOT").path_join("continuation_resume_applied_issuer").path_join(str(randi()))

	var process_a := _wired(save_root, issuer_root, false)
	var manager_a: Node = process_a["manager"]
	var issuer_a: RefCounted = process_a["issuer"]
	var initial_context := _initial_context()
	var intent := _manual_new_run_intent(manager_a, issuer_a, initial_context)
	var allocated := _manual_allocated(manager_a, issuer_a, intent)
	_manual_applying(manager_a, initial_context, intent, allocated, PARTICIPANT_APPLY_ORDER.size(), true)

	var listed: Dictionary = manager_a._continuation_journal.list_incomplete()
	assert_true(listed.get("ok", false))
	assert_eq(str((listed["value"] as Array)[0].get("stage", "")), CONTINUATION_JOURNAL.STAGE_APPLIED)

	var process_b := _wired(save_root, issuer_root, false)
	_assert_resumed_to_completion(process_b["manager"], process_b["gs"], process_b["gate"], intent["transaction_id"])

# -------------------------------------------------------------------------------------------------
# Finding B-C4: a failed pre-allocation transaction leaves no unresolvable journal entry -- it
# reaches `aborted` with a typed failure instead of staying stuck forever.
# -------------------------------------------------------------------------------------------------

func test_a_pre_allocation_restore_source_that_vanishes_aborts_with_a_typed_failure() -> void:
	var wired := _wired_single()
	var manager: Node = wired["manager"]
	var issuer: RefCounted = wired["issuer"]
	var gate: RefCounted = wired["gate"]

	assert_true(manager.start_new_run(_initial_context()).get("ok", false))
	assert_true(manager.save_latest_to_slot(1).get("ok", false))
	var prepared_restore: Dictionary = manager.prepare_restore_slot(1)
	assert_true(prepared_restore.get("ok", false))
	var prepared: Dictionary = prepared_restore["value"]["prepared"]
	var source_locator: Dictionary = prepared["source_locator"]

	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	assert_true(issued.get("ok", false))
	var transaction_id := str(issued["value"]["token"])
	var transaction_issuer_receipt: Dictionary = issued["value"]["issuer_receipt"]
	var alloc_request := {
		"existing_run_id": str(prepared["existing_run_id"]), "kind": "restore",
		"remap_source_transaction_ids": prepared["remap_source_transaction_ids"],
		"source_desktop_timeline_generation": int(prepared["source_desktop_timeline_generation"]),
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt,
	}
	var prepared_alloc: Dictionary = issuer.call(&"prepare_continuation_allocation", alloc_request)
	assert_true(prepared_alloc.get("ok", false))
	var allocation_fingerprint := _canonical_sha256(prepared_alloc["value"])
	var request_fingerprint := _canonical_sha256({
		"kind": "restore", "transaction_id": transaction_id, "source_locator": source_locator,
	})
	var intent_prepared: Dictionary = manager._continuation_journal.prepare_intent({
		"allocation_candidate_fingerprint": allocation_fingerprint, "initial_context": null,
		"initial_context_sha256": null, "kind": "restore", "request_fingerprint": request_fingerprint,
		"source_locator": source_locator, "transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	})
	assert_true(intent_prepared.get("ok", false))
	var committed: Dictionary = manager._continuation_journal.commit_intent(intent_prepared["value"])
	assert_true(committed.get("ok", false), "commit_intent: " + JSON.stringify(committed))

	# The save file this restore intent points at is deleted before the next boot -- the source can
	# no longer be proven.
	assert_true(manager.delete_slot(1).get("ok", false))

	var reconciled: Dictionary = manager.reconcile_incomplete_continuations()
	assert_true(reconciled.get("ok", false), JSON.stringify(reconciled))
	var results: Array = (reconciled["value"] as Dictionary)["reconciled"]
	assert_eq(results.size(), 1)
	var entry_result: Dictionary = (results[0] as Dictionary)["result"]
	assert_true(entry_result.get("ok", false), JSON.stringify(entry_result))
	assert_eq(str((entry_result["value"] as Dictionary).get("outcome", "")), "aborted",
		"finding B-C4: a proven-missing pre-allocation restore source reaches `aborted`, not a " \
		+ "permanently stuck `intent_committed` record")

	var final_operation: Dictionary = manager._continuation_journal.get_operation(transaction_id)
	assert_true(final_operation.get("ok", false))
	var op: Dictionary = final_operation["value"]
	assert_eq(str(op.get("stage", "")), CONTINUATION_JOURNAL.STAGE_ABORTED)
	assert_null(op.get("allocation_receipt"), "nothing was ever minted for the aborted transaction")
	var failure: Dictionary = op.get("failure", {})
	assert_false(str(failure.get("code", "")).is_empty(), "the abort carries a typed failure code")
	assert_false(str(failure.get("message", "")).is_empty(), "the abort carries a typed failure message")

	assert_false(gate.is_fatal_latched(), "a pre-allocation abort is a clean resolution, not a fatal")
	assert_false(gate.is_active(), "the gate lease is released after the pre-allocation abort")

	# No unresolvable record remains: list_incomplete() no longer returns this transaction.
	var still_incomplete: Dictionary = manager._continuation_journal.list_incomplete()
	assert_true(still_incomplete.get("ok", false))
	for entry: Dictionary in (still_incomplete["value"] as Array):
		assert_ne(str(entry.get("transaction_id", "")), transaction_id,
			"the aborted transaction must no longer appear in list_incomplete()")
