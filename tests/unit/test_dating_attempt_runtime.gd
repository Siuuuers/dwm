extends "res://addons/gut/test.gd"

const STATE := preload("res://autoload/GameState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")

class ProfileStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var reject_write := false
	func _init(root_dir: String, file_ops: RefCounted) -> void:
		super(root_dir, file_ops)
	func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		if reject_write: return {"ok": false, "code": &"fixture_profile_write_failure"}
		return super.write_atomic(relative_path, text, validator, keep_backup)

# Real initial frontier; deterministic certification isolates history from search cost.
# The production certifier has separate capability-envelope and kernel coverage.
class PreparationGeneration extends "res://tests/support/FakeMinesweeperGenerationPort.gd":
	func begin_search(spec: Dictionary) -> Dictionary:
		_log(&"begin_search", {"spec": spec})
		return preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new().begin_search(spec)
	func run_search_slice(frontier: Dictionary) -> Dictionary:
		_log(&"run_search_slice", {"frontier": frontier})
		var spec: Dictionary = frontier.spec
		var mines: Array = []
		for index in int(spec.width) * int(spec.height):
			if index != int(frontier.forced_cell) and mines.size() < int(spec.requested_mine_count): mines.append(index)
		return {"ok": true, "value": {"done": true, "forced_cell": int(frontier.forced_cell),
			"layout": {"schema_version": 1, "width": int(spec.width), "height": int(spec.height),
				"mine_indices": mines, "mine_count": mines.size()}}}

class PostRenderPort extends RefCounted:
	var physical: RefCounted
	var narrative := preload("res://tests/support/FakeDatingNarrativePlayback.gd").new()
	func begin(_command: Dictionary) -> Dictionary: return {"ok": true}
	func complete(_command: Dictionary) -> Dictionary: return {"ok": false}
	func pull_physical(value: Dictionary) -> Dictionary:
		return physical.pull_physical(value.physical_token)
	func dispatch_physical(value: Dictionary, action: String, index: int, revision: int) -> Dictionary:
		var phase: String = str(physical.pull_physical(value.physical_token).value.phase)
		var result: Dictionary = physical.dispatch_physical(value.physical_token, action, index, revision)
		if result.get("ok", false) and action == "continue" and phase in ["pre_challenge", "post_challenge"]:
			narrative.finish_phase(value, phase)
		return result
	func begin_narrative_phase(value: Dictionary, retry: bool = false) -> Dictionary:
		return narrative.begin_phase(value, str(physical.pull_physical(value.physical_token).value.phase), retry)
	func pull_narrative_phase(value: Dictionary) -> Dictionary:
		return narrative.pull_phase(value, str(physical.pull_physical(value.physical_token).value.phase))
	func acknowledge_post_challenge_render(value: Dictionary) -> Dictionary:
		return physical.acknowledge_post_challenge_render(value.physical_token)

var state: Node
var profile: Node
var storage: ProfileStorage
var physical_owner: RefCounted
var issuer: RefCounted
var gate: RefCounted
var generation: RefCounted
var command: Dictionary
var reject_checkpoint := false
var checkpoint_calls := 0
var checkpoint_records: Array[Dictionary] = []

func before_each() -> void:
	state = add_child_autofree(STATE.new())
	state.reset_game()
	storage = ProfileStorage.new("dating-attempt-runtime", OPS.new())
	profile = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	gate = GATE.new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	issuer = ISSUER.new()
	assert_true(issuer.configure(ROOT_STORE.new("87".repeat(32), 1)).ok)
	generation = PreparationGeneration.new()
	var mines: Array = []
	for index in 36: mines.append(index)
	generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
		"mine_indices": mines, "mine_count": 36})
	physical_owner = OWNER.new()
	assert_true(physical_owner.configure(issuer, state, profile, generation).ok)
	assert_true(physical_owner.configure_attempt_history(gate).ok)
	assert_true(physical_owner.configure_checkpoint_writer(_checkpoint).ok)
	assert_true(state.configure_dating_restore_reconciler(physical_owner.reconcile_restore_silent).ok)
	reject_checkpoint = false
	checkpoint_calls = 0
	checkpoint_records = []
	command = {}

func _checkpoint(record: Dictionary) -> Dictionary:
	checkpoint_calls += 1
	if reject_checkpoint: return {"ok": false, "code": &"fixture_checkpoint_failure"}
	checkpoint_records.append(record.duplicate(true))
	return {"ok": true, "value": {}}

func _begin(label: String = "initial", kind: String = "solo", day_number: int = 1) -> Dictionary:
	var context := {"kind": kind, "day": day_number,
		"participants": ["priscilla"] if kind == "solo" else ["priscilla", "lavinia"]}
	command = {"completion_transaction_id": "dating-runtime:" + label,
		"command_sha256": label.sha256_text(), "context": context}
	command["physical_token"] = physical_owner._token(command.completion_transaction_id, command.command_sha256)
	return physical_owner.begin_physical(command)

func _dispatch(action: String, index: int = -1) -> Dictionary:
	var record := _record()
	var revision: int = int(record.board.revision) if record.get("board") is Dictionary else (record.envelope.shell.actions.size() if record.schema_version == 3 else 0)
	var result: Dictionary = physical_owner.dispatch_physical(command.physical_token, action, index, revision)
	# dwm-634.2: a terminal reveal only paints; the scene settles it on its next frame, so this
	# helper settles too and reports that settlement as the command's outcome.
	if result.get("ok", false) and action != "settle":
		var pulled: Dictionary = physical_owner.pull_physical(command.physical_token)
		var view: Dictionary = pulled.get("value", {}) if pulled.get("ok", false) else {}
		if view.get("phase") == "challenge" and view.get("board") is Dictionary and bool(view.board.terminal):
			return physical_owner.dispatch_physical(command.physical_token, "settle", -1, int(view.board.revision))
	return result

func _record() -> Dictionary:
	return state.capture_dating_challenge_state().value

func _attempt(context: Dictionary = {}) -> Dictionary:
	var effective: Dictionary = command.context if context.is_empty() else context
	var identity: Dictionary = state.capture_run_snapshot_input().lifecycle
	return profile.get_dating_attempt(str(identity.run_id), LEDGER.semantic_slot(effective)).value

func _backup() -> Dictionary:
	return state.capture_restore_state().value.backup

func _restore(backup: Dictionary) -> void:
	var restored: Dictionary = state.rollback_restore_silent(backup)
	assert_true(restored.ok, str(restored))

func _paint_nonperfect_fixture() -> void:
	# Retain the terminal-paint/settlement boundary while exercising ordinary Solved.
	if _record().host == "canonical_solo":
		assert_true(_dispatch("flag", 0).ok)
		assert_true(_dispatch("unflag", 0).ok)
	var record := _record()
	var revision: int = int(record.board.revision) if record.board is Dictionary else record.envelope.shell.actions.size()
	assert_true(physical_owner.dispatch_physical(command.physical_token, "reveal", 323, revision).ok)
	assert_eq(_record().phase, "challenge", "the last cell paints before settlement")
	assert_true(_record().board.terminal)

func _clear_nonperfect_fixture() -> void:
	_paint_nonperfect_fixture()
	assert_true(_dispatch("settle").ok)

func _finish_solo() -> void:
	assert_true(_dispatch("continue").ok)
	_clear_nonperfect_fixture()
	assert_eq(_record().phase, "post_challenge")

## Rows 0-1 hold 33 mines and three more wall off the bottom-left corner (306), so the flood
## from 323 leaves exactly one safe cell covered and the board stays in play.
func _arm_walled_board() -> void:
	var mines: Array = []
	for index in 33: mines.append(index)
	mines.append_array([288, 289, 307])
	generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18,
		"mine_indices": mines, "mine_count": 36})

func _enter_walled_board() -> int:
	_arm_walled_board()
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 323).ok)
	assert_eq(_record().phase, "challenge")
	assert_false(bool(_record().board.terminal), "the walled corner keeps the board in play")
	var boundary: Dictionary = _attempt()
	assert_false(boundary.is_empty(), "materializing the board commits the attempt")
	return int(boundary.get("revision", -1))

func test_routine_board_actions_commit_no_profile_attempt_until_flush() -> void:
	var boundary_revision := _enter_walled_board()
	var boundary_actions: int = _attempt().record.board.actions.size()
	var boundary_checkpoints := checkpoint_calls
	assert_true(_dispatch("flag", 306).ok)
	assert_true(_dispatch("unflag", 306).ok)
	assert_eq(_record().board.actions.size(), boundary_actions + 2, "the live record follows every action")
	assert_eq(int(_attempt().revision), boundary_revision, "routine actions commit no Profile attempt (dwm-634.2)")
	assert_eq(_attempt().record.board.actions.size(), boundary_actions)
	assert_true(physical_owner.has_method("flush_pending_attempt"), "the owner flushes pending progress before a save")
	if not physical_owner.has_method("flush_pending_attempt"): return
	var flushed: Dictionary = physical_owner.flush_pending_attempt()
	assert_true(flushed.get("ok", false), str(flushed))
	assert_gt(int(_attempt().revision), boundary_revision, "a flush commits the pending routine progress")
	assert_eq(_attempt().record.board.actions.size(), boundary_actions + 2)
	assert_eq(checkpoint_calls, boundary_checkpoints, "a flush writes no run checkpoint of its own")
	var flushed_revision := int(_attempt().revision)
	assert_true(physical_owner.flush_pending_attempt().get("ok", false))
	assert_eq(int(_attempt().revision), flushed_revision, "a second flush has nothing to commit")
	assert_false(gate.is_active(), "the flush releases the lease it took")

func test_refused_admission_keeps_uncommitted_progress_flushable() -> void:
	var boundary_revision := _enter_walled_board()
	assert_true(_dispatch("flag", 306).ok)
	var live := command.duplicate(true)
	# A different day is a different slot, so the live board refuses the new admission.
	assert_eq(_begin("other-day", "solo", 2).code, &"dating_challenge_already_active")
	command = live
	assert_true(physical_owner.flush_pending_attempt().get("ok", false))
	assert_gt(int(_attempt().revision), boundary_revision, "a refused admission keeps pending progress flushable")
	assert_eq(_attempt().record.board.flagged_indices, [306])

func test_failed_load_rollback_keeps_uncommitted_progress_flushable() -> void:
	var boundary_revision := _enter_walled_board()
	assert_true(_dispatch("flag", 306).ok)
	var live_state := _backup()
	var retained: Dictionary = physical_owner.capture_reconciliation_state().value
	# The run participant applied a Load; a later participant failed, so everything rolls back.
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	_restore(live_state)
	assert_true(physical_owner.rollback_reconciliation_silent(retained).ok)
	assert_eq(_record().board.flagged_indices, [306])
	assert_true(physical_owner.flush_pending_attempt().get("ok", false))
	assert_gt(int(_attempt().revision), boundary_revision, "rolled-back progress is still uncommitted and flushes")
	assert_eq(_attempt().record.board.flagged_indices, [306])

func test_flush_pending_attempt_uses_the_active_causal_lease_or_takes_its_own() -> void:
	var boundary_revision := _enter_walled_board()
	assert_true(_dispatch("flag", 306).ok)
	if not physical_owner.has_method("flush_pending_attempt"):
		assert_true(false, "the owner flushes pending progress before a save")
		return
	var foreign: Dictionary = gate.acquire(&"restore")
	assert_true(foreign.ok)
	var refused: Dictionary = physical_owner.flush_pending_attempt()
	assert_false(refused.get("ok", false), "pending progress cannot commit under a foreign lease")
	assert_eq(int(_attempt().revision), boundary_revision)
	assert_true(gate.release(&"restore", foreign.value.token).ok)
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	assert_true(physical_owner.flush_pending_attempt().get("ok", false), "an active causal lease is reused")
	assert_true(gate.is_lease_active(&"causal_transaction", lease.value.token), "the caller keeps its lease")
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)
	assert_gt(int(_attempt().revision), boundary_revision)
	foreign = gate.acquire(&"restore")
	assert_true(physical_owner.flush_pending_attempt().get("ok", false), "nothing pending is fine under any owner")
	assert_true(gate.release(&"restore", foreign.value.token).ok)

func test_continue_freezes_existing_spec_and_first_reveal_freezes_exact_layout() -> void:
	assert_true(_begin().ok)
	var pre := _record()
	assert_eq(_attempt(), {}, "presentation alone cannot enter the irreversible slot")
	assert_eq(generation.call_log.size(), 0)
	assert_true(_dispatch("continue").ok)
	var entered := _attempt()
	assert_eq(entered.revision, 1)
	assert_eq(entered.entry_receipt.spec, pre.spec, "the already allocated presentation nonce is frozen at Continue")
	assert_null(entered.materialization_receipt)
	assert_true(_dispatch("reveal", 36).ok)
	var materialized := _attempt()
	assert_eq(materialized.revision, 2)
	assert_eq(materialized.materialization_receipt.first_cell_index, 36)
	assert_eq(materialized.materialization_receipt.layout.mine_indices, _record().board.mine_indices)
	assert_eq(materialized.record.board, _record().board)
	assert_eq(generation.call_log.size(), 1)
	assert_false(gate.is_active(), "the physical action releases its own causal lease")

func test_failed_profile_entry_restores_game_state_and_never_writes_autosave() -> void:
	assert_true(_begin().ok)
	var before: Dictionary = state.to_save_dict()
	var calls := checkpoint_calls
	storage.reject_write = true
	assert_eq(_dispatch("continue").code, &"fixture_profile_write_failure")
	assert_eq(state.to_save_dict(), before)
	assert_eq(_attempt(), {})
	assert_eq(checkpoint_calls, calls)
	assert_eq(physical_owner.pull_physical(command.physical_token).value.phase, "pre_challenge")
	storage.reject_write = false
	assert_true(_dispatch("continue").ok)
	assert_eq(_attempt().revision, 1)

func test_profile_ahead_after_board_autosave_failure_only_retries_same_committed_move() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	var before: Dictionary = state.to_save_dict()
	reject_checkpoint = true
	assert_eq(_dispatch("reveal", 36).code, &"fixture_checkpoint_failure")
	assert_eq(state.to_save_dict(), before)
	var durable := _attempt()
	assert_not_null(durable.record.board)
	var view: Dictionary = physical_owner.pull_physical(command.physical_token).value
	assert_eq(view.phase, "checkpoint_retry")
	assert_eq(view.actions, ["retry"])
	var profile_revision: int = profile.get_profile_revision()
	assert_eq(_dispatch("reveal", 37).code, &"dating_checkpoint_retry_required")
	assert_eq(physical_owner.dispatch_physical("foreign-token", "retry", -1, 0).code, &"dating_checkpoint_retry_required")
	assert_eq(_dispatch("retry").code, &"fixture_checkpoint_failure")
	assert_eq(state.to_save_dict(), before, "another checkpoint failure rolls back the run again")
	reject_checkpoint = false
	assert_true(_dispatch("retry").ok)
	assert_eq(_record().board, durable.record.board)
	assert_eq(_attempt(), durable)
	assert_eq(profile.get_profile_revision(), profile_revision)
	assert_eq(generation.call_log.size(), 1)
	assert_eq(physical_owner.pull_physical(command.physical_token).value.phase, "challenge")

func test_terminal_profile_ahead_replays_frozen_effect_once_after_checkpoint_retry() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	_paint_nonperfect_fixture()
	var before: Dictionary = state.to_save_dict()
	reject_checkpoint = true
	assert_eq(_dispatch("settle").code, &"fixture_checkpoint_failure")
	assert_eq(state.to_save_dict(), before)
	var durable := _attempt()
	var effect_id: String = durable.effect_receipt.receipt_id
	assert_eq(effect_id, str(durable.attempt_id) + ":effect")
	assert_false(state.dating_route_state.priscilla.get("provisional_receipts", {}).has(effect_id))
	reject_checkpoint = false
	assert_true(_dispatch("retry").ok)
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_eq(state.dating_route_state.priscilla.provisional_receipts[effect_id], durable.effect_receipt.value)
	var after: Dictionary = state.to_save_dict()
	assert_true(_begin("rebound-post").ok)
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_eq(state.affection, after.affection)
	assert_eq(generation.call_log.size(), 1)

func test_old_pre_entry_load_delays_committed_effect_until_continue_and_rebinds_command() -> void:
	assert_true(_begin().ok)
	var pre_entry := _backup()
	_finish_solo()
	var durable := _attempt()
	_restore(pre_entry)
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	assert_eq(_record().phase, "pre_challenge")
	assert_true(_begin("old-save-new-command").ok)
	assert_eq(_record().phase, "pre_challenge")
	assert_eq(state.dating_route_state.priscilla.get("date_count", 0), 0)
	assert_true(_dispatch("continue").ok)
	assert_eq(_record().phase, "post_challenge")
	assert_eq(_record().board, durable.record.board)
	assert_eq(_record().completion_transaction_id, command.completion_transaction_id)
	assert_eq(_record().command_sha256, command.command_sha256)
	assert_eq(_record().physical_token, command.physical_token)
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_eq(_attempt().effect_receipt, durable.effect_receipt)
	assert_eq(generation.call_log.size(), 1)

func test_silent_restore_uses_final_route_and_current_day_before_overlaying_profile() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var mid_board := _backup()
	assert_true(_dispatch("reveal", 0).ok)
	var durable := _attempt()
	_restore(mid_board)
	var before: Dictionary = state.to_save_dict()
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "main"}).ok)
	assert_eq(state.to_save_dict(), before, "a non-Dating final route cannot acquire future consequences")
	state._lifecycle_set_playing_day(2)
	var later_day: Dictionary = state.to_save_dict()
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	assert_eq(state.to_save_dict(), later_day, "a leftover prior-day record is not an active challenge")
	_restore(mid_board)
	var signals: Array = []
	state.friends_changed.connect(func() -> void: signals.append("friends"))
	state.save_relevant_state_changed.connect(func() -> void: signals.append("save"))
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	assert_eq(_record().board, durable.record.board)
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_eq(signals, [], "the entire overlay, including physical-record installation, is silent")
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_eq(signals, [])
	_restore(mid_board)
	assert_eq(state.to_save_dict(), before, "the original full participant backup rolls back an overlay")

func test_restored_mid_board_new_command_preserves_exact_materialized_instance() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var board: Dictionary = _record().board.duplicate(true)
	var spec: Dictionary = _record().spec.duplicate(true)
	assert_true(_begin("new-restored-envelope").ok)
	assert_eq(_record().board, board)
	assert_eq(_record().spec, spec)
	assert_eq(_record().completion_transaction_id, command.completion_transaction_id)
	assert_eq(generation.call_log.size(), 1)
	assert_true(_dispatch("flag", 0).ok)
	# dwm-634.2: routine progress reaches Profile at the next save, not per click.
	assert_true(physical_owner.flush_pending_attempt().ok)
	assert_eq(_attempt().record.board, _record().board)

func _begin_pair() -> void:
	state._lifecycle_set_playing_day(2)
	state.inter_friend_route_state["priscilla_lavinia"] = {"frozen_form": "love_dark"}
	assert_true(_begin("pair-group", "group", 2).ok)
	assert_true(_dispatch("continue").ok)
	_clear_nonperfect_fixture()
	assert_eq(_record().phase, "post_challenge")

func test_group_to_deferred_rebind_keeps_one_pair_slot_and_atomic_completion_witness() -> void:
	_begin_pair()
	var original := _attempt()
	assert_true(_begin("pair-deferred", "twofriends_if_deferred", 2).ok)
	assert_eq(_record().context.kind, "twofriends_if_deferred")
	assert_eq(_record().board, original.record.board)
	assert_eq(state.route_context.dating_post_challenge_presentation.entry_id, "dating.twofriends.priscilla_lavinia.day2.post_challenge")
	assert_eq(state.route_context.dating_post_challenge_presentation.fields,
		{"pair_mode": "twofriends_if_deferred", "pair_form": "love_dark"})
	assert_true(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	var reached: Array = profile.get_reached_presentations("dating.twofriends.priscilla_lavinia.day2.post_challenge").value.records
	assert_eq(reached.size(), 1)
	assert_eq(reached[0].signature.fields.pair_form, "love_dark")
	assert_false(reached[0].signature.fields.has("relationship_outcome"))
	assert_true(_dispatch("continue").ok)
	var completed := _attempt()
	assert_eq(completed.record.context.kind, "group", "Profile entry retains its original frozen context")
	assert_eq(completed.attempt_id, original.attempt_id)
	assert_eq(profile.get_profile_snapshot().pair_form_witness_receipts[str(completed.attempt_id) + ":complete"], "love_dark")
	var revision: int = profile.get_profile_revision()
	assert_true(_dispatch("resume_completion").ok)
	assert_eq(profile.get_profile_revision(), revision)

func test_pair_witness_conflict_rejects_completion_without_partial_ledger_write() -> void:
	_begin_pair()
	var witness_id: String = str(_attempt().attempt_id) + ":complete"
	assert_true(profile.record_pair_form_witness("love_sweet", witness_id).ok)
	var before: Dictionary = profile.get_profile_snapshot()
	var run_before: Dictionary = state.to_save_dict()
	assert_eq(_dispatch("continue").code, &"pair_form_witness_conflict")
	assert_eq(profile.get_profile_snapshot(), before)
	assert_eq(state.to_save_dict(), run_before)
	assert_null(_attempt().completion_receipt)

func test_pair_profile_write_failure_keeps_both_completion_and_witness_uncommitted() -> void:
	_begin_pair()
	var before: Dictionary = profile.get_profile_snapshot()
	var run_before: Dictionary = state.to_save_dict()
	var witness_id: String = str(_attempt().attempt_id) + ":complete"
	storage.reject_write = true
	assert_eq(_dispatch("continue").code, &"fixture_profile_write_failure")
	assert_eq(profile.get_profile_snapshot(), before)
	assert_eq(state.to_save_dict(), run_before)
	assert_false(profile.get_profile_snapshot().pair_form_witness_receipts.has(witness_id))
	assert_null(_attempt().completion_receipt)
	storage.reject_write = false
	assert_true(_dispatch("continue").ok)
	assert_not_null(_attempt().completion_receipt)
	assert_eq(profile.get_profile_snapshot().pair_form_witness_receipts[witness_id], "love_dark")

func test_dating_refuses_foreign_causal_lease_until_presentation_owner_releases_it() -> void:
	assert_true(_begin().ok)
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	assert_false(_dispatch("continue").ok)
	assert_eq(_record().phase, "pre_challenge")
	assert_eq(_attempt(), {})
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)
	assert_true(_dispatch("continue").ok)
	assert_false(gate.is_active())

func _milestone() -> void:
	assert_true(profile.unlock_ending("ending.alone", "ending:runtime-fixture:gallery:ending.alone").ok)
	assert_true(profile.has_completed_ending())

func _load_branch(backup: Dictionary, branch_id: String) -> void:
	# The allocator is tested by SaveManager. This fixture supplies its already allocated
	# branch to the real lifecycle rollback/restore seam, then invokes Dating reconciliation.
	var selected := backup.duplicate(true)
	selected.lifecycle.branch_id = branch_id
	_restore(selected)
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)

func _selected_attempt() -> Dictionary:
	var reference: Dictionary = state.route_context.dating_active_attempt_ref
	var identity: Dictionary = state.capture_run_snapshot_input().lifecycle
	return profile.get_dating_attempt(str(identity.run_id), LEDGER.semantic_slot(_record().context),
		str(reference.attempt_id), str(reference.branch_id)).value

func test_post_ending_old_midboard_and_sibling_loads_keep_exact_progress() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var saved := _backup()
	var board: Dictionary = _record().board.duplicate(true)
	var spec: Dictionary = _record().spec.duplicate(true)
	assert_true(_dispatch("flag", 0).ok)
	var parent := _attempt()
	_milestone()
	var revision: int = profile.get_profile_revision()
	_load_branch(saved, "loaded-branch-b")
	assert_eq(_record().board, board)
	assert_eq(_record().spec, spec)
	assert_eq(profile.get_profile_revision(), revision, "silent Load cannot create a progress record")
	assert_eq(state.route_context.dating_active_attempt_ref.branch_id, parent.branch_id)
	assert_true(_begin("loaded-b").ok)
	assert_eq(_record().board, board, "command rebinding cannot import the parent's later flag")
	assert_true(_dispatch("flag", 1).ok)
	var branch_b := _selected_attempt()
	assert_eq(branch_b.branch_id, "loaded-branch-b")
	assert_eq(branch_b.attempt_id, parent.attempt_id)
	assert_eq(branch_b.generation, parent.generation)
	assert_eq(branch_b.materialization_receipt.first_cell_index, 36)
	assert_eq(branch_b.record.board.flagged_indices, [1])
	assert_eq(_attempt(), parent)
	_load_branch(saved, "loaded-branch-c")
	assert_true(_begin("loaded-c").ok)
	assert_eq(_record().board, board)
	assert_true(_dispatch("flag", 2).ok)
	assert_eq(_selected_attempt().record.board.flagged_indices, [2])
	var identity: Dictionary = state.capture_run_snapshot_input().lifecycle
	assert_eq(profile.get_dating_attempt(str(identity.run_id), LEDGER.semantic_slot(command.context),
		str(parent.attempt_id), "loaded-branch-b").value, branch_b)
	assert_eq(_attempt(), parent)
	assert_eq(generation.call_log.size(), 1)

func test_post_ending_pre_entry_load_gets_fresh_attempt_only_at_continue() -> void:
	assert_true(_begin().ok)
	var pre_entry := _backup()
	var preliminary: Dictionary = _record().spec.duplicate(true)
	_finish_solo()
	assert_true(_dispatch("continue").ok)
	var first := _attempt()
	_milestone()
	_load_branch(pre_entry, "fresh-loaded-branch")
	assert_true(_begin("fresh-entry").ok)
	assert_eq(_record().spec, preliminary)
	assert_eq(_record().phase, "pre_challenge")
	assert_eq(state.dating_route_state.priscilla.get("date_count", 0), 0)
	assert_true(_dispatch("continue").ok)
	var entered := _selected_attempt()
	assert_eq(entered.generation, 2)
	assert_ne(entered.attempt_id, first.attempt_id)
	assert_ne(_record().spec.placement_nonce, preliminary.placement_nonce)
	assert_null(entered.materialization_receipt)
	assert_eq(entered.branch_id, "fresh-loaded-branch")
	assert_eq(_attempt(), first)
	assert_eq(generation.call_log.size(), 1, "Continue allocates a fresh spec but waits for first-click generation")
	_clear_nonperfect_fixture()
	assert_true(_dispatch("continue").ok)
	var slot := LEDGER.semantic_slot(command.context)
	assert_eq(state.route_context.dating_canonical_heads[slot],
		{"attempt_id": entered.attempt_id, "branch_id": "fresh-loaded-branch"})
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_eq(_attempt(), first)

func test_post_ending_copied_action_profile_and_checkpoint_failures_preserve_retry_identity() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var saved := _backup()
	assert_true(_dispatch("flag", 0).ok)
	var parent := _attempt()
	_milestone()
	_load_branch(saved, "copied-failure-branch")
	assert_true(_begin("copied-failure").ok)
	var before: Dictionary = state.to_save_dict()
	var identity: Dictionary = state.capture_run_snapshot_input().lifecycle
	var slot := LEDGER.semantic_slot(command.context)
	storage.reject_write = true
	assert_eq(_dispatch("flag", 1).code, &"fixture_profile_write_failure")
	assert_eq(state.to_save_dict(), before)
	assert_false(profile.get_dating_attempt(str(identity.run_id), slot, str(parent.attempt_id), "copied-failure-branch").ok)
	storage.reject_write = false
	# dwm-634.1: a routine flag commits the attempt to Profile but writes no run checkpoint of its
	# own; the next checkpoint boundary is the terminal reveal, so the failure is injected there.
	var checkpoints_before_routine := checkpoint_calls
	assert_true(_dispatch("flag", 1).ok)
	assert_eq(checkpoint_calls, checkpoints_before_routine, "a routine flag writes no run checkpoint")
	reject_checkpoint = true
	# dwm-634.2: the terminal reveal paints first and is accepted; the failing run checkpoint
	# belongs to its settlement, which rolls back to the painted board.
	assert_true(physical_owner.dispatch_physical(command.physical_token, "reveal", 323, int(_record().board.revision)).ok)
	before = state.to_save_dict()
	assert_eq(_dispatch("settle").code, &"fixture_checkpoint_failure")
	assert_eq(state.to_save_dict(), before)
	var durable: Dictionary = profile.get_dating_attempt(str(identity.run_id), slot,
		str(parent.attempt_id), "copied-failure-branch").value
	assert_eq(durable.record.board.flagged_indices, [1])
	assert_true(bool(durable.record.board.terminal), "the boundary reveal reached Profile before the run checkpoint failed")
	assert_eq(physical_owner.pull_physical(command.physical_token).value.phase, "checkpoint_retry")
	assert_eq(_dispatch("flag", 2).code, &"dating_checkpoint_retry_required")
	var revision: int = profile.get_profile_revision()
	reject_checkpoint = false
	assert_true(_dispatch("retry").ok)
	assert_eq(_selected_attempt(), durable)
	assert_eq(_record().board, durable.record.board)
	assert_eq(state.route_context.dating_active_attempt_ref.branch_id, "copied-failure-branch")
	assert_eq(profile.get_profile_revision(), revision)
	assert_eq(_attempt(), parent)
	assert_eq(generation.call_log.size(), 1)

func test_post_ending_entered_unmaterialized_save_keeps_spec_and_chooses_its_own_first_click() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	var entered := _backup()
	var spec: Dictionary = _record().spec.duplicate(true)
	assert_true(_dispatch("reveal", 36).ok)
	var parent := _attempt()
	_milestone()
	_load_branch(entered, "unmaterialized-branch")
	assert_true(_begin("unmaterialized").ok)
	assert_null(_record().board)
	assert_eq(_record().spec, spec)
	_clear_nonperfect_fixture()
	assert_eq(_selected_attempt().materialization_receipt.first_cell_index, 323)
	assert_eq(_selected_attempt().attempt_id, parent.attempt_id)
	assert_eq(_attempt().materialization_receipt.first_cell_index, 36)
	assert_eq(generation.call_log.size(), 2)

func test_post_ending_saved_terminal_board_keeps_automatic_loved_effect_and_exact_head() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	_paint_nonperfect_fixture()
	var cleared := _backup()
	assert_true(_dispatch("settle").ok)
	assert_true(_dispatch("continue").ok)
	var parent := _attempt()
	_milestone()
	_load_branch(cleared, "independent-terminal")
	assert_true(_begin("independent-terminal").ok)
	assert_eq(_record().phase, "challenge")
	assert_eq(state.dating_route_state.priscilla.get("date_count", 0), 0)
	assert_true(_dispatch("settle").ok)
	var branch := _selected_attempt()
	assert_eq(branch.record.relationship_outcome, "loved")
	assert_eq(parent.record.relationship_outcome, "loved")
	assert_eq(branch.effect_receipt.receipt_id, parent.effect_receipt.receipt_id)
	assert_eq(branch.effect_receipt.value, parent.effect_receipt.value)
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	assert_true(_dispatch("continue").ok)
	assert_eq(state.route_context.dating_canonical_heads[LEDGER.semantic_slot(command.context)],
		{"attempt_id": parent.attempt_id, "branch_id": "independent-terminal"})
	assert_eq(_attempt(), parent)
	assert_eq(generation.call_log.size(), 1)

func test_completed_head_inheritance_keeps_prior_progress_branch() -> void:
	assert_true(_begin().ok)
	_finish_solo()
	assert_true(_dispatch("continue").ok)
	var first := _attempt()
	var first_slot := LEDGER.semantic_slot(command.context)
	_milestone()
	state._lifecycle_set_playing_day(2)
	assert_true(_begin("day-two", "solo", 2).ok)
	var day_two := _backup()
	_load_branch(day_two, "inherited-head-branch")
	assert_true(_begin("loaded-day-two", "solo", 2).ok)
	assert_eq(state.route_context.dating_canonical_heads[first_slot],
		{"attempt_id": first.attempt_id, "branch_id": first.branch_id})
	_finish_solo()
	assert_true(_dispatch("continue").ok)
	var second := _selected_attempt()
	assert_eq(state.route_context.dating_canonical_heads[first_slot],
		{"attempt_id": first.attempt_id, "branch_id": first.branch_id})
	assert_eq(state.route_context.dating_canonical_heads[LEDGER.semantic_slot(command.context)],
		{"attempt_id": second.attempt_id, "branch_id": "inherited-head-branch"})

func test_post_ending_pair_continuation_normalizes_group_deferred_context() -> void:
	_begin_pair()
	var post := _backup()
	assert_true(_dispatch("continue").ok)
	var parent := _attempt()
	_milestone()
	_load_branch(post, "pair-continuation")
	assert_true(_begin("loaded-pair-deferred", "twofriends_if_deferred", 2).ok)
	assert_eq(_record().context.kind, "twofriends_if_deferred")
	assert_true(_dispatch("continue").ok)
	var branch := _selected_attempt()
	assert_eq(branch.record.context.kind, "group")
	assert_eq(branch.attempt_id, parent.attempt_id)
	assert_eq(branch.branch_id, "pair-continuation")
	assert_eq(_attempt(), parent)
	assert_eq(state.route_context.dating_canonical_heads[LEDGER.semantic_slot(command.context)],
		{"attempt_id": parent.attempt_id, "branch_id": "pair-continuation"})

func test_failed_restore_rolls_back_local_continuation_selection_on_next_action() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	var saved := _backup()
	_milestone()
	_load_branch(saved, "retained-live-branch")
	assert_true(_begin("retained-live").ok)
	assert_true(_dispatch("flag", 1).ok)
	var live := _backup()
	var live_command := command.duplicate(true)
	_load_branch(saved, "failed-restore-branch")
	_restore(live) # A later restore participant fails; it rolls back the complete GameState backup.
	command = live_command
	assert_true(_dispatch("flag", 2).ok)
	assert_eq(_selected_attempt().branch_id, "retained-live-branch")
	assert_eq(_selected_attempt().record.board.flagged_indices, [1, 2])
	var identity: Dictionary = state.capture_run_snapshot_input().lifecycle
	assert_false(profile.get_dating_attempt(str(identity.run_id), LEDGER.semantic_slot(command.context),
		str(_record().spec.board_token), "failed-restore-branch").ok)

func test_failed_load_restores_exact_pending_retry_and_successful_load_discards_it() -> void:
	assert_true(_begin().ok)
	var pre_entry := _backup()
	_finish_solo()
	var head_before: Dictionary = state.route_context.get("dating_canonical_heads", {}).duplicate(true)
	reject_checkpoint = true
	assert_eq(_dispatch("continue").code, &"fixture_checkpoint_failure")
	var durable := _attempt()
	assert_eq(durable.record.phase, "completed")
	var pending := _backup()
	var pending_local: Dictionary = physical_owner.capture_reconciliation_state().value
	var original_command := command.duplicate(true)
	var profile_revision: int = profile.get_profile_revision()
	var stale := pending.duplicate(true)
	stale.session_generation = int(stale.session_generation) - 1
	assert_eq(state.rollback_restore_silent(stale).code, &"stale_run_backup")
	assert_eq(physical_owner.capture_reconciliation_state().value, pending_local,
		"a stale session is rejected before adopting local retry or command state")
	_load_branch(pre_entry, "failed-load-during-retry")
	assert_eq(physical_owner._pending_checkpoint, {})
	_restore(pending) # A later restore participant failed; the existing full backup is authoritative.
	command = original_command
	assert_eq(physical_owner.capture_reconciliation_state().value, pending_local)
	assert_eq(physical_owner.pull_physical(command.physical_token).value.phase, "checkpoint_retry")
	assert_eq(state.route_context.get("dating_canonical_heads", {}), head_before)
	assert_eq(_dispatch("continue").code, &"dating_checkpoint_retry_required")
	assert_eq(physical_owner.dispatch_physical("wrong-token", "retry", -1, 0).code, &"dating_checkpoint_retry_required")
	assert_eq(_dispatch("retry").code, &"fixture_checkpoint_failure")
	assert_eq(physical_owner.pull_physical(command.physical_token).value.actions, ["retry"])
	assert_eq(state.route_context.get("dating_canonical_heads", {}), head_before)
	reject_checkpoint = false
	assert_true(_dispatch("retry").ok)
	assert_eq(profile.get_profile_revision(), profile_revision)
	assert_eq(_record().phase, "completed")
	assert_eq(state.route_context.dating_canonical_heads[LEDGER.semantic_slot(command.context)],
		{"attempt_id": durable.attempt_id, "branch_id": durable.branch_id})
	assert_eq(state.dating_route_state.priscilla.date_count, 1)
	# Re-establish the same pre-Load failure fixture, then let a selected Load succeed.
	_restore(pending)
	assert_false(physical_owner._pending_checkpoint.is_empty())
	_load_branch(pre_entry, "successful-load-during-retry")
	assert_eq(physical_owner._pending_checkpoint, {})
	assert_true(_begin("successful-load").ok)
	assert_eq(physical_owner.pull_physical(command.physical_token).value.phase, "pre_challenge")
	assert_eq(_attempt(), durable, "successful Load discards local retry only, never Profile history")

func test_exploded_pair_completion_does_not_grant_combination_witness() -> void:
	state._lifecycle_set_playing_day(2)
	state.inter_friend_route_state["priscilla_lavinia"] = {"frozen_form": "love_dark"}
	assert_true(_begin("exploded-pair", "group", 2).ok)
	assert_true(_dispatch("continue").ok)
	assert_true(_dispatch("reveal", 36).ok)
	assert_true(_dispatch("reveal", 0).ok)
	assert_eq(_record().outcome, "exploded")
	assert_true(_dispatch("continue").ok)
	var completed := _attempt()
	assert_not_null(completed.completion_receipt, "the actual exploded attempt remains irreversible history")
	assert_false(profile.get_profile_snapshot().pair_form_witness_receipts.has(str(completed.attempt_id) + ":complete"))
	assert_eq(profile.get_pair_form_witnesses().value, [])

func _begin_observer(friend_id: String = "priscilla", label: String = "observer") -> Dictionary:
	state._lifecycle_set_playing_day(2)
	command = {"completion_transaction_id": "dating-runtime:" + label, "command_sha256": label.sha256_text(),
		"context": {"kind": "solo", "day": 2, "participants": [friend_id]}}
	command["physical_token"] = physical_owner._token(command.completion_transaction_id, command.command_sha256)
	return physical_owner.begin_physical(command)

func test_retired_observer_actions_have_no_source_and_cannot_write_evidence() -> void:
	for friend_id: String in ["priscilla", "lavinia"]:
		assert_true(_begin_observer(friend_id).ok)
		var before: Dictionary = profile.get_profile_snapshot().duplicate(true)
		var route_before: Dictionary = state.route_context.duplicate(true)
		assert_eq(physical_owner.pull_observer(command.physical_token).value, {})
		assert_eq(physical_owner.pull_observer("stale-token").code, &"stale_dating_physical_token")
		for action: String in ["render", "capture", "compare", "compare_rendered", "tick", "intervene", "close", "retry"]:
			var denied: Dictionary = physical_owner.dispatch_observer(
				command.physical_token, "retired.atom", action, 1000)
			assert_eq(denied.code, &"observer_source_not_admitted", action)
		assert_eq(profile.get_profile_snapshot(), before, "Retirement grants no fictitious evidence.")
		assert_eq(state.route_context, route_before, "Refused interactions mutate no run state.")
		state.route_context.erase("active_dating_challenge")

func test_retired_observer_checkpoint_cannot_strand_restored_board_entry() -> void:
	assert_true(_begin_observer("lavinia").ok)
	var run_id: String = str(state.capture_run_snapshot_input().lifecycle.run_id)
	var stale := {"run_id": run_id, "entry_id": "dating.solo.lavinia.day2.pre_challenge",
		"checkpoint_pending": true, "rendered": true, "playback_token": "retired-token",
		"comparison_shown": false, "elapsed_ms": 5000, "closed": false,
		"capture_receipt_id": "", "intervened": false}
	state.route_context["dating_observer_source"] = stale.duplicate(true)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	assert_true(physical_owner.begin_physical(command).ok, "An older pending interaction may be loaded.")
	assert_eq(state.route_context.dating_observer_source, stale, "Admission does not rewrite historical evidence.")
	assert_eq(physical_owner.pull_observer(command.physical_token).value, {})
	assert_true(_dispatch("continue").ok, "The retired checkpoint cannot own current input.")
	assert_eq(_record().phase, "challenge")
	assert_eq(profile.get_profile_snapshot().observer_evidence, profile_before.observer_evidence)

func test_pre_challenge_reached_signature_needs_actual_draw_and_uses_saved_base_fields() -> void:
	assert_true(_begin().ok)
	assert_eq(profile.get_reached_presentations().value.records, [])
	assert_false(profile.has_completed_ending())
	var frozen: Dictionary = state.route_context.dating_pre_challenge_presentation.duplicate(true)
	state.friend_attitude["priscilla"] = "later-attitude"
	assert_false(physical_owner.acknowledge_pre_challenge_render("stale-token").ok)
	assert_true(physical_owner.acknowledge_pre_challenge_render(command.physical_token).ok)
	var reached: Array = profile.get_reached_presentations().value.records
	assert_eq(reached.size(), 1)
	assert_eq(reached[0].signature.fields, frozen.fields)
	assert_false(profile.has_completed_ending(), "reaching the pre-challenge scene does not unlock Rehearsal")
	var revision: int = profile.get_profile_revision()
	assert_true(physical_owner.acknowledge_pre_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_profile_revision(), revision)
	assert_true(_dispatch("continue").ok)
	assert_false(physical_owner.acknowledge_pre_challenge_render(command.physical_token).ok)

func test_pre_challenge_reached_profile_failure_retries_without_rebinding_or_rehearsal_write() -> void:
	assert_true(_begin().ok)
	var frozen: Dictionary = state.route_context.dating_pre_challenge_presentation.duplicate(true)
	storage.reject_write = true
	assert_false(physical_owner.acknowledge_pre_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_reached_presentations().value.records, [])
	storage.reject_write = false
	assert_eq(state.route_context.dating_pre_challenge_presentation, frozen)
	physical_owner._admitted_command["execution_mode"] = "rehearsal"
	assert_false(physical_owner.acknowledge_pre_challenge_render(command.physical_token).ok)
	physical_owner._admitted_command.erase("execution_mode")
	assert_true(physical_owner.acknowledge_pre_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_reached_presentations().value.records.size(), 1)

func test_post_challenge_reach_freezes_terminal_fields_and_exact_draw_deduplicates() -> void:
	assert_true(_begin().ok)
	_finish_solo()
	assert_eq(profile.get_reached_presentations().value.records, [], "terminal board alone is not a rendered post scene")
	var frozen: Dictionary = state.route_context.dating_post_challenge_presentation.duplicate(true)
	state.friend_attitude["priscilla"] = "later-attitude"
	var before: Dictionary = state.to_save_dict().duplicate(true)
	assert_false(physical_owner.acknowledge_post_challenge_render("stale-token").ok)
	assert_true(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	var reached: Array = profile.get_reached_presentations("dating.solo.priscilla.day1.post_challenge").value.records
	assert_eq(reached.size(), 1)
	assert_eq(reached[0].signature.fields.attitude, frozen.fields.attitude)
	assert_eq(reached[0].signature.fields.relationship_outcome, "loved")
	assert_eq(reached[0].signature.fields.special_mine_phase, "declined")
	assert_eq(reached[0].signature.fields.perfect_reasons, _record().perfect_reasons)
	assert_eq(state.to_save_dict(), before, "render recording does not replay terminal effects")
	var revision: int = profile.get_profile_revision()
	assert_true(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_profile_revision(), revision)
	assert_true(_dispatch("continue").ok)
	assert_false(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)

func test_post_challenge_profile_failure_restores_exact_fields_and_rehearsal_has_no_writer() -> void:
	assert_true(_begin().ok)
	_finish_solo()
	var frozen: Dictionary = state.route_context.dating_post_challenge_presentation.duplicate(true)
	var backup: Dictionary = _backup()
	storage.reject_write = true
	assert_false(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_reached_presentations().value.records, [])
	storage.reject_write = false
	_restore(backup)
	assert_true(_begin("restored-post-render").ok)
	assert_eq(state.route_context.dating_post_challenge_presentation, frozen)
	physical_owner._admitted_command["execution_mode"] = "rehearsal"
	assert_false(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	physical_owner._admitted_command.erase("execution_mode")
	assert_true(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_reached_presentations().value.records.size(), 1)

func test_failed_terminal_checkpoint_cannot_record_post_until_exact_retry_is_saved() -> void:
	assert_true(_begin().ok)
	assert_true(_dispatch("continue").ok)
	_paint_nonperfect_fixture()
	reject_checkpoint = true
	assert_false(_dispatch("settle").ok)
	assert_false(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_reached_presentations().value.records, [])
	reject_checkpoint = false
	assert_true(_dispatch("retry").ok)
	assert_eq(_record().phase, "post_challenge")
	assert_true(physical_owner.acknowledge_post_challenge_render(command.physical_token).ok)
	assert_eq(profile.get_reached_presentations().value.records.size(), 1)

func test_post_dtl_completion_gates_progression_and_start_failure_stays_retryable() -> void:
	assert_true(_begin().ok)
	_finish_solo()
	var port := PostRenderPort.new()
	port.physical = physical_owner
	port.narrative.auto_complete = false
	port.narrative.fail_begin = true
	var scene: Control = load("res://scenes/dating/DatingScene.tscn").instantiate()
	assert_true(scene.configure_presentation(port, command).ok)
	add_child_autofree(scene)
	scene.set_process(false)
	scene._process(0.0)
	assert_eq(_record().phase, "post_challenge")
	assert_true(scene._narrative_failed)
	assert_true(scene._continue_button.visible)
	assert_eq(scene._continue_button.text, "Retry")
	assert_eq(port.narrative.started.size(), 1)
	scene._process(0.0)
	assert_eq(port.narrative.started.size(), 1, "a failed start is not retried every frame")
	scene._status_label.draw.emit()
	assert_eq(profile.get_reached_presentations().value.records, [], "a title draw is not witnessed dialogue")
	port.narrative.fail_begin = false
	scene._continue_button.pressed.emit()
	assert_false(scene._narrative_failed)
	assert_eq(_record().phase, "post_challenge", "a playing DTL cannot be bypassed")
	assert_false(scene._continue_button.visible)
	assert_eq(port.narrative.started.size(), 2)
	port.narrative.finish()
	scene._process(0.0)
	assert_eq(_record().phase, "completed", "natural DTL completion advances automatically")
	assert_eq(profile.get_reached_presentations().value.records, [], "an empty fixture grants no prose receipt")

func _begin_post_ending_preparation(label: String) -> Dictionary:
	_milestone()
	state.inventory["debug_key"] = 1
	var begun: Dictionary = _begin(label)
	assert_true(begun.ok, str(begun))
	if not begun.ok: return {}
	var entered: Dictionary = _dispatch("continue")
	assert_true(entered.ok, str(entered))
	if not entered.ok: return {}
	assert_eq(_record().phase, "preparing")
	assert_eq(_attempt(), {}, "searching has not entered Profile history")
	return _backup()

func test_post_ending_preparing_load_enters_exact_saved_spec_without_reroll() -> void:
	var saved: Dictionary = _begin_post_ending_preparation("preparing-load")
	if saved.is_empty(): return
	var preparing: Dictionary = _record().duplicate(true)
	var issued_before: Dictionary = issuer.capture_root().value.duplicate(true)
	_load_branch(saved, "preparing-loaded-branch")
	assert_true(_begin("preparing-loaded-command").ok)
	assert_eq(_record().spec, preparing.spec)
	assert_eq(_record().envelope, preparing.envelope)
	assert_eq(_attempt(), {})
	var advanced: Dictionary = _dispatch("prepare")
	assert_true(advanced.ok, str(advanced))
	if not advanced.ok: return
	var entered: Dictionary = _selected_attempt()
	assert_eq(entered.branch_id, "preparing-loaded-branch")
	assert_eq(entered.attempt_id, preparing.spec.board_token)
	assert_eq(entered.entry_receipt.spec, preparing.spec)
	assert_eq(entered.record.phase, "challenge")
	assert_null(entered.materialization_receipt)
	assert_eq(issuer.capture_root().value, issued_before, "Load and certification allocate no new nonce")
	assert_eq(generation.call_log.size(), 2, "one begin and one resumed slice")

func test_post_ending_preparing_cold_recovery_reuses_profile_ahead_entry() -> void:
	var saved: Dictionary = _begin_post_ending_preparation("preparing-profile-ahead")
	if saved.is_empty(): return
	var preparing: Dictionary = _record().duplicate(true)
	reject_checkpoint = true
	var failed: Dictionary = _dispatch("prepare")
	assert_eq(failed.get("code"), &"fixture_checkpoint_failure", str(failed))
	assert_eq(_record(), preparing, "failed Run checkpoint restores its searching preimage")
	var durable: Dictionary = _attempt().duplicate(true)
	assert_eq(durable.record.phase, "challenge")
	var profile_revision: int = profile.get_profile_revision()
	var issued_before: Dictionary = issuer.capture_root().value.duplicate(true)
	# Cold reconciliation discards transient retry and retains the saved searching record.
	assert_true(physical_owner.reconcile_restore_silent({"route_id": "dating"}).ok)
	reject_checkpoint = false
	assert_true(_begin("preparing-profile-ahead").ok)
	assert_eq(_record().envelope, preparing.envelope)
	var advanced: Dictionary = _dispatch("prepare")
	assert_true(advanced.ok, str(advanced))
	if not advanced.ok: return
	assert_eq(_selected_attempt(), durable)
	assert_eq(profile.get_profile_revision(), profile_revision, "Profile-ahead entry is not appended twice")
	assert_eq(_record().spec, preparing.spec)
	assert_eq(issuer.capture_root().value, issued_before)
	assert_false(gate.is_active())

func test_post_ending_preparing_older_load_uses_existing_attempt_continuation() -> void:
	var saved: Dictionary = _begin_post_ending_preparation("preparing-parent")
	if saved.is_empty(): return
	var completed: Dictionary = _dispatch("prepare")
	assert_true(completed.ok, str(completed))
	if not completed.ok: return
	var parent: Dictionary = _selected_attempt().duplicate(true)
	var issued_before: Dictionary = issuer.capture_root().value.duplicate(true)
	_load_branch(saved, "preparing-child-branch")
	assert_true(_begin("preparing-child-command").ok)
	var advanced: Dictionary = _dispatch("prepare")
	assert_true(advanced.ok, str(advanced))
	if not advanced.ok: return
	var child: Dictionary = _selected_attempt()
	assert_eq(child.attempt_id, parent.attempt_id)
	assert_eq(child.generation, parent.generation)
	assert_eq(child.entry_receipt, parent.entry_receipt)
	assert_eq(child.branch_id, "preparing-child-branch")
	assert_eq(child.record.phase, "challenge")
	assert_null(child.materialization_receipt)
	assert_eq(profile.get_dating_attempt(parent.run_id, parent.slot_id, parent.attempt_id, parent.branch_id).value, parent)
	assert_eq(issuer.capture_root().value, issued_before)
