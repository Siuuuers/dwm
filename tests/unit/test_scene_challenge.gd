extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
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

func test_first_start_profile_failure_publishes_no_run_or_attempt() -> void:
	assert_true(f.begin().ok)
	f.storage.refuse = true
	assert_false(f.action("start").ok)
	assert_eq(f.record(), {})
	assert_eq(f.attempt().value, {})
	assert_eq(f.authority.checkpoints.size(), 0)
	f.storage.refuse = false
	assert_true(f.action("start").ok)
	assert_eq(f.record().phase, "ready")
	assert_eq(f.attempt().value.record, f.record())

func test_profile_before_run_failure_retains_exact_attempt_for_retry_and_cold_owner() -> void:
	assert_true(f.begin().ok)
	f.authority.reject_checkpoint = true
	assert_false(f.action("start").ok)
	var attempt: Dictionary = f.attempt().value
	assert_eq(attempt.record.phase, "ready")
	assert_eq(f.owner.pull_physical(f.token).value.actions, ["retry"])
	assert_false(f.action("start").ok)
	# Simulate lost Run write and process-local owner only. Profile remains real.
	f.state.route_context = {}
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.phase, "checkpoint_retry")
	f.authority.reject_checkpoint = false
	assert_true(f.action("retry").ok)
	assert_eq(f.record(), attempt.record)
	assert_eq(f.attempt().value.revision, attempt.revision)

func test_preparing_is_committed_before_run_and_resumes_same_frontier() -> void:
	f.state.inventory = {"debug_key": 1}
	assert_true(f.begin().ok)
	f.authority.reject_checkpoint = true
	assert_false(f.action("start").ok)
	var saved: Dictionary = f.attempt().value.record
	assert_eq(saved.phase, "preparing")
	assert_not_null(saved.envelope.preparation)
	f.state.route_context = {}
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	f.authority.reject_checkpoint = false
	assert_true(f.action("retry").ok)
	assert_eq(f.record(), saved)
	assert_eq(f.attempt().value.entry_receipt.keys().size(), 4)

func test_terminal_state_is_recorded_at_reducer_boundary_without_dating_effects() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 36).ok)
	assert_eq(f.record().state, "in_progress")
	assert_true(f.action("reveal", 0).ok)
	assert_eq(f.record().phase, "terminal")
	assert_eq(f.record().state, "lost")
	assert_eq(f.record().applied_result, {})
	assert_eq(f.attempt().value.record, f.record())
	assert_false(f.action("reveal", 37).ok)
	assert_false(f.action("start").ok)
	assert_eq(f.state.effects, 0)

func test_perfect_survives_win_history_and_exact_closure_proof() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	assert_eq(f.record().state, "won")
	var detail: Dictionary = f.owner.pull_physical(f.token).value.result
	assert_false(detail.perfect_reasons.is_empty())
	assert_eq(f.attempt().value.terminal_receipt.perfect_reasons, detail.perfect_reasons)
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_true(LEDGER.validate_attempt_proof(f.attempt().value, closed.value.attempt_proof).ok)
	var forged: Dictionary = closed.value.attempt_proof.duplicate(true)
	forged.record_sha256 = "f".repeat(64)
	assert_false(LEDGER.validate_attempt_proof(f.attempt().value, forged).ok)
	assert_false(f.owner.close_scene_challenge(f.token).ok)
	assert_eq(f.state.effects, 0)

func test_selected_prefix_closes_on_new_branch_without_importing_terminal_or_ending_unlock() -> void:
	assert_false(f.profile.has_completed_ending())
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("reveal", 323).ok)
	var old_close: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(old_close.ok)
	var original: Dictionary = f.attempt().value
	selected.lifecycle.branch_id = "TEST.selected.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.record().phase, "ready")
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_eq(closed.value.outcome, "unfinished")
	assert_eq(closed.value.attempt_proof.branch_id, "TEST.selected.branch")
	assert_eq(f.attempt(original.branch_id).value, original)
	assert_true(LEDGER.validate_attempt_proof(original, old_close.value.attempt_proof).ok)

func test_selected_prestart_without_authenticated_absence_refuses_future_import() -> void:
	assert_true(f.begin().ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	selected.lifecycle.branch_id = "TEST.prestart.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.recreate_owner().ok)
	var refused: Dictionary = f.begin()
	assert_false(refused.ok)
	assert_eq(str(refused.code), "scene_attempt_recovery_required")
	assert_eq(f.record(), {}, "dependency remains fail-closed; future terminal is never imported")

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

func test_same_operation_profile_ahead_with_existing_run_waits_for_source_retry() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var saved: Dictionary = f.state.capture_restore_state().value.backup
	f.authority.reject_checkpoint = true
	assert_false(f.action("flag", 0).ok)
	var ahead: Dictionary = f.attempt().value.record
	assert_true(f.state.rollback_restore_silent(saved).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.actions, ["retry"])
	assert_false(f.action("reveal", 36).ok)
	f.authority.reject_checkpoint = false
	assert_true(f.action("retry").ok)
	assert_eq(f.record(), ahead)

func test_selected_prefix_flush_requires_confirmed_source_and_preserves_original() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("reveal", 323).ok)
	var original: Dictionary = f.attempt().value
	selected.lifecycle.branch_id = "TEST.flush.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	f.authority.reject_checkpoint = true
	assert_false(f.owner.flush_pending_attempt().ok)
	assert_eq(f.owner.pull_physical(f.token).value.actions, ["retry"])
	assert_eq(f.attempt(original.branch_id).value, original)
	f.authority.reject_checkpoint = false
	assert_true(f.owner.flush_pending_attempt().ok)
	assert_eq(f.record().phase, "ready")
	assert_eq(f.state.route_context.dating_active_attempt_ref.branch_id, "TEST.flush.branch")
	assert_true(f.owner.close_scene_challenge(f.token).ok)

func test_failed_materialization_profile_write_does_not_poison_ready_close() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	f.storage.refuse = true
	assert_false(f.action("reveal", 36).ok)
	f.storage.refuse = false
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	assert_eq(closed.value.outcome, "unfinished")

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
