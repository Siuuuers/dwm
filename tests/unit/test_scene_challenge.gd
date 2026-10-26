extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
# This suite owns physical/Run checkpoint seams. Atomic destination persistence
# and receipt-free player saves are exercised by the rendered integration children.
class SelectedClosedState extends RefCounted:
	var record: Dictionary
	var closure: Dictionary
	func capture_dating_challenge_state() -> Dictionary:
		return {"ok": true, "value": record.duplicate(true)}
	func capture_scene_challenge_closure(_context: Dictionary) -> Dictionary:
		return {"ok": true, "value": closure.duplicate(true)}

var f: RefCounted

func before_each() -> void:
	f = FIXTURE.new()
	assert_true(f.setup().ok)
func after_each() -> void: f.dispose()

func test_never_started_is_validated_absence_and_closed_occurrence_cannot_reenter() -> void:
	assert_true(f.begin().ok)
	assert_eq(f.record(), {})
	assert_eq(f.attempt().value, {})
	assert_eq(f.owner.pull_physical(f.token).value.state, "never_started")
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_null(closed.value.attempt_proof)
	assert_eq(closed.value.outcome, "never_started")
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	assert_true(f.recreate_owner().ok)
	assert_false(f.begin().ok, "retained closure authority survives physical owner recreation")
	assert_eq(f.state.effects, 0)

func test_terminal_state_is_recorded_at_reducer_boundary_without_dating_effects() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_eq(f.record().state, "in_progress")
	assert_true(f.action("reveal", 0).ok)
	assert_eq(f.record().phase, "terminal")
	assert_eq(f.record().state, "lost")
	assert_eq(f.record().applied_result, {})
	assert_eq(f.attempt().value, {}, "Challenge progress belongs to the Run")
	assert_false(f.action("reveal", 37).ok)
	assert_false(f.action("start").ok)
	assert_eq(f.state.effects, 0)

func test_selected_prefix_closes_on_new_branch_without_importing_terminal_or_ending_unlock() -> void:
	assert_false(f.profile.has_completed_ending())
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("reveal", 323).ok)
	var old_close: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(old_close.ok)
	var original: Dictionary = f.profile.get_profile_snapshot()
	selected.lifecycle.branch_id = "TEST.selected.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.record().phase, "ready")
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_eq(closed.value.outcome, "unfinished")
	assert_eq(closed.value.attempt_proof.branch_id, "TEST.selected.branch")
	assert_eq(f.profile.get_profile_snapshot(), original)

func test_selected_prestart_restores_absence_without_future_import() -> void:
	assert_true(f.begin().ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	selected.lifecycle.branch_id = "TEST.prestart.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.state, "never_started")
	assert_eq(f.record(), {}, "future terminal is never imported")

func test_close_flushes_pending_work_and_refuses_without_authenticated_end() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	f.authority.held_end = false
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	f.authority.held_end = true
	f.authority.reject_checkpoint = true
	assert_false(f.action("flag", 0).ok)
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	assert_eq(f.authority.closures, {})
	f.authority.reject_checkpoint = false
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_eq(closed.value.outcome, "unfinished")
	assert_eq(f.record().envelope.shell.flagged_indices, [0])

func test_unconfirmed_checkpoint_is_fatal_and_foreign_commands_cannot_admit() -> void:
	var forged: Dictionary = f.command.duplicate(true)
	forged.context.playable_command_id = "TEST.foreign"
	assert_false(f.owner.begin_physical(forged).ok)
	assert_true(f.begin().ok)
	f.authority.unconfirmed = true
	assert_false(f.action("start").ok)
	assert_false(f.action("retry").ok)
	assert_false(f.owner.close_scene_challenge(f.token).ok)

func test_presentation_routes_scene_to_exact_owner_without_legacy_completion() -> void:
	var port := PORT.new()
	assert_true(port.configure(f.issuer, f.owner).ok)
	var admitted: Dictionary = port.begin(f.command)
	assert_true(admitted.ok, str(admitted))
	var command: Dictionary = admitted.value.presentation_command.duplicate(true)
	assert_true(port.dispatch_physical(command, "start", -1, 0).ok)
	assert_false(port.complete({"presentation_command": command, "physical_completion_receipt": {}}).ok)
	command.physical_token = "TEST.foreign"
	assert_false(port.pull_physical(command).ok)
	assert_true(port.close_scene_challenge(admitted.value.presentation_command).ok)

func test_malformed_context_and_unadmitted_close_fail_without_runtime_errors() -> void:
	assert_false(f.owner.close_scene_challenge("TEST.unadmitted").ok)
	var port := PORT.new()
	assert_true(port.configure(f.issuer, f.owner).ok)
	for context: Variant in [null, 7, []]:
		assert_false(f.owner.begin_physical({"context": context}).ok)
		assert_false(port.begin({"context": context}).ok)
		assert_false(port.complete({"presentation_command": context, "physical_completion_receipt": {}}).ok)

func test_same_owner_selected_prefix_clears_materialization_scratch_and_requires_readmission() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("reveal", 36).ok)
	selected.lifecycle.branch_id = "TEST.same.owner.load"
	f.owner.set("_first_cell_index", 36) # Transient scratch may predate this scene family.
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	assert_false(f.owner.pull_physical(f.token).ok)
	assert_false(f.owner.flush_pending_attempt().ok)
	assert_false(f.owner.dispatch_physical(f.token, "prepare", -1, 0).ok)
	assert_true(f.begin().ok)
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_eq(closed.value.outcome, "unfinished")
	assert_eq(closed.value.attempt_proof.branch_id, "TEST.same.owner.load")

func test_restore_journal_flush_leaves_selected_prefix_unadmitted_and_unchanged() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("reveal", 36).ok)
	selected.lifecycle.branch_id = "TEST.restore.journal.load"
	var lease: Dictionary = f.gate.acquire(&"restore")
	assert_true(lease.ok)
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	var owner_before: Dictionary = f.owner.capture_reconciliation_state()
	assert_false(owner_before.value.history.committed)
	assert_true(owner_before.value.admitted_command.is_empty())
	assert_true(owner_before.value.pending_checkpoint.is_empty())
	var run_before: Dictionary = f.state.capture_restore_state()
	var profile_state_before: Dictionary = f.profile.get_profile_snapshot()
	var profile_before: Dictionary = f.storage.read_text("profile.json")
	assert_true(profile_before.ok)
	var checkpoints_before: Array = f.authority.checkpoints.duplicate(true)
	for _journal_write: int in range(2):
		var flushed: Dictionary = f.owner.flush_pending_attempt()
		assert_true(flushed.ok, str(flushed))
		assert_eq(flushed.get("value", {}), {"committed": false})
		assert_false(f.owner.pull_physical(f.token).ok)
		assert_false(f.owner.dispatch_physical(f.token, "prepare", -1, 0).ok)
	assert_eq(f.owner.capture_reconciliation_state(), owner_before)
	assert_eq(f.state.capture_restore_state(), run_before)
	assert_eq(f.profile.get_profile_snapshot(), profile_state_before)
	assert_eq(f.storage.read_text("profile.json"), profile_before)
	assert_eq(f.authority.checkpoints, checkpoints_before)
	assert_true(f.gate.release(&"restore", lease.value.token).ok)
	assert_false(f.owner.flush_pending_attempt().ok)
	assert_false(f.owner.pull_physical(f.token).ok)
	assert_eq(f.owner.capture_reconciliation_state(), owner_before)

func test_restore_journal_flush_refuses_unadmitted_routine_progress_and_fatal_custody() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var lease: Dictionary = f.gate.acquire(&"restore")
	assert_true(lease.ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	var run_before: Dictionary = f.state.capture_restore_state()
	var profile_state_before: Dictionary = f.profile.get_profile_snapshot()
	var profile_before: Dictionary = f.storage.read_text("profile.json")
	assert_true(profile_before.ok)
	for fence: String in ["_routine_pending", "_scene_fatal"]:
		f.owner.set(fence, true)
		var owner_before: Dictionary = f.owner.capture_reconciliation_state()
		assert_false(f.owner.flush_pending_attempt().ok, fence)
		assert_eq(f.owner.get(fence), true)
		assert_eq(f.owner.capture_reconciliation_state(), owner_before)
		assert_eq(f.state.capture_restore_state(), run_before)
		assert_eq(f.profile.get_profile_snapshot(), profile_state_before)
		assert_eq(f.storage.read_text("profile.json"), profile_before)
		f.owner.set(fence, false)
	assert_true(f.gate.release(&"restore", lease.value.token).ok)

func test_uncertain_or_committed_checkpoint_failure_never_grants_retry_custody() -> void:
	for failure: Dictionary in [{"ok": false, "code": &"event_commit_ack_invalid", "committed": true},
			{"ok": false, "code": &"APPLICATION_FATAL"}, {"ok": false, "code": &"TEST.unclassified"}]:
		var isolated := FIXTURE.new()
		assert_true(isolated.setup().ok)
		assert_true(isolated.begin().ok)
		isolated.authority.checkpoint_failure = failure
		assert_false(isolated.action("start").ok)
		assert_false(isolated.owner.pull_physical(isolated.token).ok)
		assert_false(isolated.owner.flush_pending_attempt().ok)
		isolated.dispose()

func test_malformed_successful_closure_ack_retains_fatal_custody() -> void:
	assert_true(f.begin().ok)
	f.authority.malformed_closure = true
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_false(closed.ok)
	assert_eq(str(closed.code), "scene_closure_ack_invalid")
	assert_false(f.owner.pull_physical(f.token).ok)
	assert_false(f.begin().ok)

func test_same_owner_selected_absence_revokes_future_scene_and_restore_rollback_reinstates_it() -> void:
	assert_true(f.begin().ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	var original: Dictionary = f.profile.get_profile_snapshot()
	var run_backup: Dictionary = f.state.capture_restore_state().value.backup
	var owner_backup: Dictionary = f.owner.capture_reconciliation_state().value
	var checkpoints: int = f.authority.checkpoints.size()
	selected.lifecycle.branch_id = "TEST.absent.same.owner"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	assert_false(f.owner.pull_physical(f.token).ok, "old token cannot expose the future terminal board")
	assert_false(f.owner.dispatch_physical(f.token, "start", -1, 0).ok)
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	var flushed: Dictionary = f.owner.flush_pending_attempt()
	assert_true(flushed.ok)
	assert_false(flushed.value.committed, "no scene remains to flush")
	assert_eq(f.record(), {})
	assert_eq(f.authority.checkpoints.size(), checkpoints)
	assert_eq(f.profile.get_profile_snapshot(), original)
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.state, "never_started")
	assert_eq(f.record(), {})
	# A later restore-participant failure rolls both Run and retained owner back.
	assert_true(f.state.rollback_restore_silent(run_backup).ok)
	assert_true(f.owner.rollback_reconciliation_silent(owner_backup).ok)
	assert_eq(f.owner.capture_reconciliation_state().value, owner_backup)
	assert_eq(f.owner.pull_physical(f.token).value.state, "won")

func test_same_owner_selected_absence_discards_old_profile_ahead_retry() -> void:
	assert_true(f.begin().ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	f.authority.reject_checkpoint = true
	assert_false(f.action("start").ok)
	var original: Dictionary = f.profile.get_profile_snapshot()
	assert_eq(f.owner.pull_physical(f.token).value.actions, ["retry"])
	selected.lifecycle.branch_id = "TEST.absent.pending.owner"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	f.authority.reject_checkpoint = false
	assert_false(f.owner.pull_physical(f.token).ok)
	assert_false(f.owner.dispatch_physical(f.token, "retry", -1, 0).ok)
	assert_false(f.owner.flush_pending_attempt().value.committed)
	assert_eq(f.authority.checkpoints.size(), 0)
	assert_eq(f.record(), {})
	assert_eq(f.profile.get_profile_snapshot(), original)
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.state, "never_started")

func test_same_owner_legacy_replacement_revokes_scene_admission_after_validation() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var scene: Dictionary = f.record()
	var legacy := {"schema_version": 3, "completion_transaction_id": "TEST.legacy.completion",
		"command_sha256": "TEST.legacy.command".sha256_text(), "physical_token": "",
		"context": {"kind": "solo", "day": 1, "participants": ["sylvia"]},
		"host": "canonical_solo", "spec": scene.spec.duplicate(true), "board": null,
		"envelope": scene.envelope.duplicate(true), "phase": "pre_challenge", "outcome": null,
		"applied_result": {}, "pair_form": "", "mine_dispositions": [],
		"relationship_outcome": null, "perfect_reasons": []}
	legacy.physical_token = f.owner._token(legacy.completion_transaction_id, legacy.command_sha256)
	assert_true(f.owner._valid_record(legacy, {}))
	var owner_backup: Dictionary = f.owner.capture_reconciliation_state().value
	f.state.lifecycle.day = 1
	f.state.lifecycle.branch_id = "TEST.legacy.replacement"
	f.state.route_context = {"active_dating_challenge": legacy.duplicate(true)}
	f.state.route_context.active_dating_challenge.context.participants = []
	assert_false(f.owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	assert_eq(f.owner.capture_reconciliation_state().value, owner_backup, "invalid replacement preserves owner for rollback")
	f.state.route_context.active_dating_challenge = legacy.duplicate(true)
	assert_true(f.owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	assert_false(f.owner.pull_physical(f.token).ok)
	assert_false(f.owner.dispatch_physical(f.token, "retry", -1, 0).ok)
	assert_false(f.owner.flush_pending_attempt().value.committed)
	assert_eq(f.record(), legacy, "legacy replacement retains its existing restore policy")
	assert_eq(f.owner.pull_physical(legacy.physical_token).value.phase, "pre_challenge")

func test_before_save_flush_with_no_started_board_needs_no_playable_admission() -> void:
	assert_true(f.begin().ok)
	f.authority.presentation_held = true
	var flushed: Dictionary = f.owner.flush_pending_attempt()
	assert_true(flushed.ok, str(flushed))
	assert_false(flushed.value.get("committed", true))
	assert_eq(f.record(), {})
	assert_eq(f.attempt().value, {})
	assert_eq(f.authority.checkpoints.size(), 0)

func test_before_save_flush_of_checkpointed_board_preserves_held_presentation() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	var record: Dictionary = f.record()
	var attempt: Dictionary = f.attempt().value
	var checkpoints: int = f.authority.checkpoints.size()
	f.authority.presentation_held = true
	var flushed: Dictionary = f.owner.flush_pending_attempt()
	assert_true(flushed.ok, str(flushed))
	assert_false(flushed.value.get("committed", true))
	assert_true(f.authority.presentation_held)
	assert_eq(f.record(), record)
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.authority.checkpoints.size(), checkpoints)

func test_before_save_flush_of_pending_checkpoint_still_requires_source_admission() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	f.authority.reject_checkpoint = true
	assert_false(f.action("flag", 0).ok)
	var owner_backup: Dictionary = f.owner.capture_reconciliation_state().value
	var record: Dictionary = f.record()
	var attempt: Dictionary = f.attempt().value
	var checkpoints: int = f.authority.checkpoints.size()
	f.authority.reject_checkpoint = false
	f.authority.presentation_held = true
	var refused: Dictionary = f.owner.flush_pending_attempt()
	assert_false(refused.ok)
	assert_eq(str(refused.code), "event_presentation_held")
	assert_eq(f.owner.capture_reconciliation_state().value, owner_backup)
	assert_eq(f.record(), record)
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.authority.checkpoints.size(), checkpoints)
	f.authority.presentation_held = false
	var retried: Dictionary = f.owner.flush_pending_attempt()
	assert_true(retried.ok, str(retried))
	assert_true(retried.value.get("committed", false))
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.authority.checkpoints.size(), checkpoints + 1)

func test_closed_current_outcome_without_proof_keeps_exact_board_read_only() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_true(f.action("reveal", 0).ok)
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	var selected: Dictionary = f.record()
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	var checkpoints: Array = f.authority.checkpoints.duplicate(true)
	# Fresh Load projects this current outcome without the old live proof.
	f.authority.closures[f.state.lifecycle.branch_id].attempt_proof = null
	f.authority.presentation_held = true
	var view: Dictionary = f.owner.pull_physical(f.token)
	assert_true(view.ok, str(view))
	if view.ok:
		assert_eq(view.value.phase, "closed")
		assert_eq(view.value.state, "lost")
		assert_eq(view.value.actions, [])
	assert_false(f.action("reveal", 37).ok)
	f.state.route_context.active_dating_challenge = {}
	assert_false(f.owner.pull_physical(f.token).ok, "closed view refuses a different selected Run board")
	f.state.route_context.active_dating_challenge = selected.duplicate(true)
	# With no playable command after Load, before-save accepts only the exact
	# retained board and its direct outcome, never a Profile-derived replacement.
	var current := SelectedClosedState.new()
	current.record = selected.duplicate(true)
	current.closure = f.authority.closures[f.state.lifecycle.branch_id].duplicate(true)
	f.owner.set("_game_state", current)
	f.owner.set("_admitted_command", {})
	var flushed: Dictionary = f.owner.flush_pending_attempt()
	assert_true(flushed.ok, str(flushed))
	if flushed.ok: assert_false(flushed.value.committed)
	current.record = {}
	assert_false(f.owner.flush_pending_attempt().ok, "missing selected board refuses closed no-op")
	current.record = selected.duplicate(true)
	current.closure.outcome = "won"
	assert_false(f.owner.flush_pending_attempt().ok, "contradictory current outcome refuses closed no-op")
	current.closure = f.authority.closures[f.state.lifecycle.branch_id].duplicate(true)
	current.closure.playable_command_id = "TEST.foreign.playable"
	assert_false(f.owner.flush_pending_attempt().ok, "another challenge command cannot close this board")
	assert_eq(f.record(), selected)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)
	assert_eq(f.authority.checkpoints, checkpoints)
	assert_eq(f.state.effects, 0)

func test_failed_finish_retries_same_board_without_duplicate_profile_or_reward() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_true(f.action("reveal", 0).ok)
	var selected: Dictionary = f.record()
	var attempt: Dictionary = f.attempt().value
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	var checkpoints: Array = f.authority.checkpoints.duplicate(true)
	f.authority.reject_closure = true
	var refused: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_false(refused.ok)
	assert_eq(f.authority.closures, {})
	assert_eq(f.record(), selected)
	assert_eq(f.attempt().value, attempt)
	f.authority.reject_closure = false
	var retried: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(retried.ok, str(retried))
	if retried.ok: assert_eq(retried.value.outcome, "lost")
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	assert_eq(f.authority.closures.size(), 1)
	assert_eq(f.record(), selected)
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)
	assert_eq(f.authority.checkpoints.size(), checkpoints.size() + 2)
	for checkpoint: Dictionary in f.authority.checkpoints.slice(checkpoints.size()):
		assert_eq(checkpoint, selected, "each Finish source checkpoint preserves the exact same board")
	assert_eq(f.state.effects, 0)

func test_scene_actions_and_closure_do_not_write_global_profile() -> void:
	var before: Dictionary = f.storage.read_text("profile.json")
	assert_true(f.begin().ok)
	f.storage.refuse = true
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_true(f.action("reveal", 0).ok)
	assert_true(f.owner.close_scene_challenge(f.token).ok)
	assert_eq(f.storage.read_text("profile.json"), before)
	assert_eq(f.attempt().value, {})

func test_failed_run_checkpoint_retries_in_memory_and_restart_uses_saved_run() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var saved: Dictionary = f.state.capture_restore_state().value.backup
	f.authority.reject_checkpoint = true
	assert_false(f.action("flag", 0).ok)
	assert_eq(f.owner.pull_physical(f.token).value.actions, ["retry"])
	f.authority.reject_checkpoint = false
	assert_true(f.action("retry").ok)
	assert_eq(f.record().envelope.shell.flagged_indices, [0])
	assert_true(f.state.rollback_restore_silent(saved).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.record(), saved.route_context.active_dating_challenge)
	assert_eq(f.attempt().value, {})

func test_preparing_frontier_restores_exactly_from_saved_run() -> void:
	f.state.inventory = {"debug_key": 1}
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var saved: Dictionary = f.record()
	assert_eq(saved.phase, "preparing")
	assert_not_null(saved.envelope.preparation)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.record(), saved)
	assert_eq(f.attempt().value, {})
