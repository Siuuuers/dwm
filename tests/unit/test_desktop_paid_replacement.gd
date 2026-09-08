extends GutTest

const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const FATE := preload("res://scripts/application/minesweeper/DesktopBoardFatePort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const OLD_CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const COMPOSER := preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

class StatePort extends "res://tests/support/FakeDesktopBoardStatePort.gd":
	var selected := "beginner"
	var board_owner: RefCounted
	var pressure := 3
	func get_selected_difficulty() -> String: return selected
	func prepare_spec(difficulty: String, transaction: String, proof: Dictionary) -> Dictionary:
		var result: Dictionary = super.prepare_spec(difficulty, transaction, proof)
		if not result.ok: return result
		var size: Dictionary = CATALOG.lookup("desktop_app", difficulty).value
		result.value.spec["width"] = int(size.width)
		result.value.spec["height"] = int(size.height)
		result.value.spec["base_mine_count"] = int(size.base_mine_count)
		result.value.spec["requested_mine_count"] = int(size.base_mine_count)
		result.value.spec["pressure"] = pressure
		result.value.spec["raw_extra_mines"] = int(pressure / 3)
		return result
	func commit(candidate: Dictionary) -> Dictionary:
		var result: Dictionary = super.commit(candidate)
		if result.ok and candidate.has("selected_difficulty"): selected = str(candidate.selected_difficulty)
		return result
	func capture_base_snapshot_input() -> Dictionary:
		return {"ok": true, "value": {"snapshot_input": {
			"desktop": {"board": board_owner.capture(), "consequence": {}},
			"gameplay": {"minesweeper_selected_difficulty": selected, "money": 53},
			"contacts": {"preserved": "contact"}, "route_context": {"preserved": "route"}}}}

class Generation extends RefCounted:
	var calls: Array = []
	var search_frontier: Dictionary = {}
	func materialize(spec: Dictionary, index: int) -> Dictionary:
		calls.append({"spec": spec.duplicate(true), "index": index})
		var mines: Array = []
		for cell in int(spec.requested_mine_count): mines.append(cell)
		return {"ok": true, "value": {"layout": {"schema_version": 1, "width": int(spec.width),
			"height": int(spec.height), "mine_count": mines.size(), "mine_indices": mines}}}
	func begin_search(_spec: Dictionary) -> Dictionary: return {"ok": true, "value": {"frontier": search_frontier.duplicate(true)}}
	func run_search_slice(_frontier: Dictionary) -> Dictionary: return {"ok": false}

class Durable extends RefCounted:
	const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
	const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
	var disk: Dictionary = {"old": "artifact"}
	var journal: Dictionary = {"revision": 0, "snapshot": {}}
	var last_candidate: Dictionary = {}
	var writes := 0
	var prepares := 0
	var rollbacks := 0
	var fail_write := false
	var fail_prepare := false
	var fail_rollback := false
	func capture() -> Dictionary:
		return {"ok": true, "value": {"backup": journal.duplicate(true)}}
	func preview_checkpoint_id(_run: String) -> Dictionary: return {"ok": true, "value": {"checkpoint_id": "checkpoint"}}
	func prepare_checkpoint(input: Dictionary, _kind: StringName, _intent: Dictionary) -> Dictionary:
		prepares += 1
		if fail_prepare:
			fail_prepare = false
			return {"ok": false, "code": &"injected_prepare"}
		var encoded: Dictionary = JSON_WRITER.stringify(disk)
		if not encoded.ok: return encoded
		# Exact outer candidate/descriptor ownership of SaveManagerCheckpointPort.
		# In particular prepare never returns a journal_backup member.
		last_candidate = {"journal_candidate": {"revision": int(journal.revision) + 1, "snapshot": input.duplicate(true)},
			"checkpoint_id": "checkpoint", "autosave_document": {"current_snapshot": {"snapshot": input.duplicate(true)}},
			"storage_backup": {"relative_path": "autosave.json", "existed": true, "validated_text": str(encoded.value)}}
		return {"ok": true, "value": {"candidate": last_candidate.duplicate(true), "checkpoint_id": "checkpoint"}}
	func commit_checkpoint(candidate: Dictionary) -> Dictionary:
		writes += 1
		disk = candidate.autosave_document.current_snapshot.snapshot.duplicate(true)
		if fail_write:
			fail_write = false
			return {"ok": false, "code": &"injected_final_reread"}
		journal = candidate.journal_candidate.duplicate(true)
		return {"ok": true}
	func rollback(backup: Dictionary) -> Dictionary:
		rollbacks += 1
		if fail_rollback: return {"ok": false, "code": &"injected_rollback"}
		if not backup.get("journal_backup") is Dictionary or not backup.get("storage_backup") is Dictionary:
			return {"ok": false, "code": &"invalid_rollback_envelope"}
		var decoded: Dictionary = JSON_READER._parse_value_document(str(backup.storage_backup.validated_text))
		if not decoded.ok: return decoded
		journal = backup.journal_backup.duplicate(true)
		disk = decoded.value.duplicate(true)
		return {"ok": true}

var coordinator: RefCounted
var port: StatePort
var generator: Generation
var issuer: RefCounted
var root_store: RefCounted
var durable: Durable

func before_each() -> void:
	coordinator = COORDINATOR.new()
	port = StatePort.new()
	generator = Generation.new()
	root_store = ROOT_STORE.new("22".repeat(32), 1)
	issuer = ISSUER.new()
	assert_true(issuer.configure(root_store).ok)
	port.identity_issuer = issuer
	port.board_owner = coordinator._board_state
	assert_true(coordinator.configure(port, OLD_CHECKPOINT.new(), generator, issuer).ok)
	durable = Durable.new()

func _request(difficulty: String = "") -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	var state: Dictionary = coordinator.get_state().value
	var request := {"transaction_id": str(issued.value.token), "transaction_issuer_receipt": issued.value.issuer_receipt,
		"expected_identity": state.identity, "expected_revision": int(state.revision)}
	if not difficulty.is_empty(): request["difficulty_id"] = difficulty
	return request

func _reveal(index: int, difficulty: String = "beginner") -> Dictionary:
	var request := _request(difficulty)
	if coordinator.get_state().value.phase in ["NONE", "UNPAID_UNSTARTED"]:
		request["expected_identity"] = coordinator.get_entry_context(difficulty).value.identity
	request["cell_index"] = index
	return coordinator.reveal(request)

func _flag(index: int, flagged: bool) -> Dictionary:
	var request := _request()
	request["cell_index"] = index
	request["flagged"] = flagged
	return coordinator.set_flag(request)

func _start() -> Dictionary:
	var result := _reveal(10)
	assert_true(result.ok, str(result))
	assert_false(coordinator.get_state().value.board.board.terminal)
	return coordinator.get_state().value.duplicate(true)

func _durable() -> void:
	assert_true(coordinator.configure_durable_checkpoint(durable, COMPOSER, CONSEQUENCE.new()).ok)

func test_untouched_new_board_and_same_tier_are_byte_equal_without_spec_or_storage() -> void:
	_durable()
	var before: Dictionary = coordinator.get_state().value
	var request := {"transaction_id": "", "transaction_issuer_receipt": {}, "expected_identity": null,
		"expected_revision": 0, "difficulty_id": "beginner"}
	assert_true(coordinator.replace_board(request).value.unchanged)
	assert_true(coordinator.select_difficulty(request).value.unchanged)
	assert_eq(coordinator.get_state().value, before)
	assert_eq(generator.calls, [])
	assert_eq(durable.prepares, 0)

func test_unpaid_flags_are_saved_without_capacity_then_preserved_by_first_reveal() -> void:
	port.motivation = 0
	port.rounds_left = 0
	assert_true(_flag(11, true).ok)
	assert_true(_flag(12, true).ok)
	assert_true(_flag(12, false).ok)
	var shell: Dictionary = coordinator.get_state().value
	assert_eq(shell.phase, "UNPAID_UNSTARTED")
	assert_null(shell.identity)
	assert_eq(shell.candidate.actions.size(), 3)
	assert_eq(generator.calls, [])
	assert_false(_reveal(11).ok)
	assert_eq(generator.calls, [])
	port.motivation = 7
	port.rounds_left = 2
	var result := _reveal(10)
	assert_true(result.ok, str(result))
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)
	var board: Dictionary = coordinator.get_state().value.board.board
	assert_eq(board.actions, shell.candidate.actions)
	assert_eq(board.flagged_indices, [11])
	assert_true(SCHEMA.validate_board(board).ok)

func test_free_difficulty_checkpoint_resets_shell_and_does_not_allocate_layout() -> void:
	_durable()
	assert_true(_flag(11, true).ok)
	var selected: Dictionary = coordinator.select_difficulty(_request("intermediate"))
	assert_true(selected.ok, str(selected))
	var state: Dictionary = coordinator.get_state().value
	assert_eq(state.candidate.width, 16)
	assert_eq(state.candidate.actions, [])
	assert_eq(port.selected, "intermediate")
	assert_eq(port.motivation, 7)
	assert_eq(port.rounds_left, 2)
	assert_eq(generator.calls, [])
	assert_eq(durable.disk.desktop.board, state)
	assert_eq(durable.disk.contacts, {"preserved": "contact"})

func test_paid_replacement_retains_original_payment_and_fresh_spec_on_each_touch() -> void:
	var original := _start()
	_durable()
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	var replacement: Dictionary = coordinator.get_state().value
	assert_eq(replacement.phase, "PAID_UNSTARTED")
	assert_eq(replacement.identity, original.identity)
	assert_eq(replacement.candidate.paid_start_receipt, original.board.paid_start_receipt)
	assert_eq(replacement.candidate.spec.difficulty_id, "intermediate")
	assert_eq(generator.calls.size(), 1)
	assert_true(coordinator.replace_board(_request("intermediate")).value.unchanged)
	assert_true(_reveal(40, "intermediate").ok)
	var active: Dictionary = coordinator.get_state().value
	assert_eq(active.board.spec, replacement.candidate.spec)
	assert_eq(active.board.paid_start_receipt, original.board.paid_start_receipt)
	port.pressure = 8
	assert_true(coordinator.replace_board(_request("intermediate")).ok)
	var next: Dictionary = coordinator.get_state().value
	assert_ne(next.candidate.spec.board_token, replacement.candidate.spec.board_token)
	assert_eq(next.candidate.spec.pressure, 8)
	assert_eq(next.identity, original.identity)
	assert_eq(next.terminal_receipts, {})
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)
	assert_eq(port.next_ordinal, 2)

func test_failed_final_reread_rolls_back_full_artifact_then_exact_retry_reuses_spec() -> void:
	var original := _start()
	_durable()
	var disk_before := durable.disk.duplicate(true)
	var request := _request("expert")
	durable.fail_write = true
	var failed: Dictionary = coordinator.select_difficulty(request)
	assert_eq(failed.code, &"injected_final_reread", str(failed))
	assert_eq(coordinator.get_state().value, original)
	assert_eq(durable.disk, disk_before)
	assert_eq(port.selected, "beginner")
	var frozen: Dictionary = coordinator._configuration_pending.candidate.candidate_after.spec.duplicate(true)
	assert_eq(coordinator.select_difficulty(_request("intermediate")).code, &"configuration_retry_required")
	assert_true(coordinator.select_difficulty(request).ok)
	assert_eq(coordinator.get_state().value.candidate.spec, frozen)
	assert_eq(durable.disk.desktop.board, coordinator.get_state().value)
	var writes := durable.writes
	assert_true(coordinator.select_difficulty(request).ok)
	assert_eq(durable.writes, writes)
	assert_eq(port.motivation, 6)

func test_prepare_failure_keeps_original_board_and_exact_retry_does_not_refreeze_inputs() -> void:
	var original := _start()
	_durable()
	durable.fail_prepare = true
	var request := _request("expert")
	assert_false(coordinator.select_difficulty(request).ok)
	assert_eq(coordinator.get_state().value, original)
	port.pressure = 9
	assert_true(coordinator.select_difficulty(request).ok)
	assert_eq(coordinator.get_state().value.candidate.spec.pressure, 3)
	assert_eq(durable.writes, 1)

func test_paid_shell_save_restore_keeps_layout_recipe_and_flags_without_second_charge() -> void:
	var original := _start()
	_durable()
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	assert_true(_flag(41, true).ok)
	var saved: Dictionary = durable.disk.desktop.board.duplicate(true)
	var restored := STATE.new()
	var prepared: Dictionary = restored.prepare_restore(saved)
	assert_true(prepared.ok, str(prepared))
	assert_true(restored.commit(prepared.value.candidate).ok)
	assert_eq(restored.capture(), saved)
	coordinator._board_state = restored
	port.board_owner = restored
	assert_true(_reveal(40, "intermediate").ok)
	assert_eq(coordinator.get_state().value.board.board.flagged_indices, [41])
	assert_eq(coordinator.get_state().value.board.paid_start_receipt, original.board.paid_start_receipt)
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)

func test_restore_to_new_identity_rejects_stale_replacement_retry_and_discards_local_candidate() -> void:
	_start()
	_durable()
	var old_request := _request("expert")
	durable.fail_prepare = true
	assert_false(coordinator.select_difficulty(old_request).ok)
	var fresh := STATE.new().capture()
	fresh["revision"] = 13
	var prepared: Dictionary = coordinator._board_state.prepare_restore(fresh)
	coordinator._board_state.commit(prepared.value.candidate)
	assert_eq(coordinator.select_difficulty(old_request).code, &"stale_revision")
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	assert_eq(coordinator.get_state().value.phase, "UNPAID_UNSTARTED")
	assert_null(coordinator.get_state().value.identity)

func test_shell_public_projection_and_departure_fate_preserve_paid_status() -> void:
	assert_true(_flag(11, true).ok)
	var unpaid: Dictionary = coordinator.get_state().value
	var projected: Dictionary = QUERY.desktop(unpaid, "beginner", false)
	assert_true(projected.ok, str(projected))
	assert_eq(projected.value.cells[11].actions, ["unflag"])
	assert_eq(projected.value.cells[12].actions, ["flag"])
	assert_false(projected.value.has("mine_indices"))
	assert_eq(FATE._fate_for_snapshot(unpaid), &"discarded_unstarted")
	assert_true(_reveal(10).ok)
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	var paid: Dictionary = coordinator.get_state().value
	assert_eq(FATE._fate_for_snapshot(paid), &"forfeited_started")
	assert_true(QUERY.desktop(paid, "intermediate").ok)
	var debug := paid.duplicate(true)
	debug["phase"] = "PREPARING"
	assert_eq(FATE._fate_for_snapshot(debug), &"forfeited_started")

func test_terminal_and_foreign_gate_refuse_configuration_before_spec_or_checkpoint() -> void:
	_start()
	var mine := _request()
	mine["cell_index"] = 0
	assert_true(coordinator.reveal(mine).ok)
	_durable()
	assert_false(coordinator.select_difficulty(_request("expert")).ok)
	assert_eq(durable.prepares, 0)
	var empty := STATE.new()
	coordinator._board_state = empty
	port.board_owner = empty
	var gate := ApplicationMutationGate.new()
	coordinator._consequence_gate = gate
	var lease := gate.acquire(&"restore")
	assert_eq(coordinator.get_configuration_context().value.difficulty_enabled, [])
	assert_false(coordinator.select_difficulty(_request("expert")).ok)
	assert_eq(durable.prepares, 0)
	gate.release(&"restore", lease.value.token)


func test_paid_first_reveal_failed_checkpoint_retries_same_materialization_once() -> void:
	_start()
	_durable()
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	var before: Dictionary = coordinator.get_state().value
	var request := _request("intermediate")
	request["cell_index"] = 40
	durable.fail_write = true
	assert_false(coordinator.reveal(request).ok)
	assert_eq(coordinator.get_state().value, before)
	var calls := generator.calls.size()
	var retried: Dictionary = coordinator.reveal(request)
	assert_true(retried.ok)
	assert_eq(coordinator.reveal(request), retried)
	assert_eq(generator.calls.size(), calls)
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)


class RewardProbe extends RefCounted:
	var context: Dictionary = {}
	func prepare_complete(value: Dictionary, _result: Dictionary, _transaction: String) -> Dictionary:
		context = value.duplicate(true)
		return {"ok": false, "code": &"reward_probe"}
	func commit_desktop_completion(_candidate: Dictionary) -> Dictionary: return {"ok": false}
	func publish_desktop_completion(_candidate: Dictionary) -> Dictionary: return {"ok": false}

class CompletionStub extends RefCounted:
	func accept_prepared_action(_request: Dictionary) -> Dictionary: return {"ok": false}

func test_replacement_terminal_reward_uses_current_tier_and_original_paid_session() -> void:
	var original := _start()
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	assert_true(_reveal(40, "intermediate").ok)
	var explode := _request()
	explode["cell_index"] = 0
	assert_true(coordinator.reveal(explode).ok)
	var consequence := CONSEQUENCE.new()
	var issued: Dictionary = root_store.mint(&"causal_day_instance")
	var made: Dictionary = CONSEQUENCE.make_empty({"causal_day_instance": str(issued.token), "causal_day_instance_issuer_receipt": issued})
	assert_true(made.ok, str(made))
	consequence.commit(consequence.prepare_restore(made.value.state).value.candidate)
	var checkpoints := preload("res://tests/support/FakeDesktopConsequenceCheckpointPort.gd").new()
	assert_true(coordinator.configure_consequence_port(CompletionStub.new(), ApplicationMutationGate.new()).ok)
	assert_true(coordinator.configure_consequence_checkpoint(consequence, checkpoints).ok)
	var rewards := RewardProbe.new()
	assert_true(coordinator.configure_reward_port(rewards).ok)
	var result: Dictionary = coordinator.complete_round(_request())
	assert_eq(result.code, &"reward_probe", str(result))
	assert_eq(rewards.context.difficulty, "intermediate")
	assert_eq(coordinator.get_state().value.board.paid_start_receipt, original.board.paid_start_receipt)


func test_failed_artifact_rollback_latches_shared_fatal_fence() -> void:
	_start()
	_durable()
	var gate := ApplicationMutationGate.new()
	coordinator._consequence_gate = gate
	durable.fail_write = true
	durable.fail_rollback = true
	var result: Dictionary = coordinator.select_difficulty(_request("expert"))
	assert_eq(result.code, &"APPLICATION_FATAL", str(result))
	assert_true(gate.is_fatal_latched())
	assert_false(gate.guard_external(&"shop").ok)
	assert_false(coordinator.get_configuration_context().ok)


func test_owned_debug_refuses_direct_first_reveal_before_spec_or_layout_allocation() -> void:
	port.generation_capabilities = ["first_cell_safe", "forced_no_guess"]
	var before: Dictionary = coordinator.get_state().value
	var result := _reveal(10)
	assert_eq(result.code, &"debug_preparation_required", str(result))
	assert_eq(coordinator.get_state().value, before)
	assert_eq(generator.calls, [])
	for call: Dictionary in port.call_log:
		assert_ne(call.method, &"prepare_spec")
	assert_eq(port.motivation, 7)

func test_paid_frozen_debug_refuses_materialization_even_if_live_debug_was_removed() -> void:
	_start()
	port.generation_capabilities = ["first_cell_safe", "forced_no_guess"]
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	port.generation_capabilities = ["first_cell_safe"]
	var before: Dictionary = coordinator.get_state().value
	var calls := generator.calls.size()
	var result := _reveal(40, "intermediate")
	assert_eq(result.code, &"debug_preparation_required", str(result))
	assert_eq(coordinator.get_state().value, before)
	assert_eq(generator.calls.size(), calls)


func _certify_shell(paid: bool) -> Dictionary:
	if paid:
		_start()
		assert_true(coordinator.replace_board(_request("beginner")).ok)
	else:
		assert_true(_flag(11, true).ok)
	var state: Dictionary = coordinator.get_state().value
	var transaction := _request("beginner")
	var spec: Dictionary
	var identity: Dictionary
	if paid:
		spec = state.candidate.spec.duplicate(true)
		identity = state.identity.duplicate(true)
	else:
		spec = port.prepare_spec("beginner", transaction.transaction_id, transaction.transaction_issuer_receipt).value.spec
		identity = coordinator.get_entry_context("beginner").value.identity
	var input := {"transaction_id": str(transaction.transaction_id), "identity": identity,
		"expected_revision": int(state.revision), "spec": spec, "request_fingerprint": "debug-begin"}
	var begun: Dictionary = coordinator._board_state.prepare_debug_candidate(input, {"frontier": {"step": 0}})
	assert_true(begun.ok, str(begun))
	coordinator._board_state.commit(begun.value.candidate)
	var layout: Dictionary = generator.materialize(spec, 10).value.layout
	transaction = _request()
	input = {"transaction_id": str(transaction.transaction_id), "identity": identity,
		"expected_revision": int(coordinator.get_state().value.revision), "request_fingerprint": "debug-certified"}
	var prepared: Dictionary = coordinator._board_state.prepare_debug_slice(input, {
		"done": true, "layout": layout, "forced_cell": 10, "proof_sha256": null})
	assert_true(prepared.ok, str(prepared))
	coordinator._board_state.commit(prepared.value.candidate)
	return coordinator.get_state().value.duplicate(true)

func test_certified_unpaid_flags_can_be_removed_without_changing_layout_or_payment() -> void:
	var certified := _certify_shell(false)
	var view: Dictionary = QUERY.desktop(certified, "beginner", true)
	assert_true(view.ok, str(view))
	assert_eq(view.value.cells[11].actions, ["unflag"])
	assert_eq(view.value.cells[10].actions, ["reveal", "flag"])
	assert_eq(view.value.cells[12].actions, ["flag"])
	assert_true(_flag(11, false).ok)
	var changed: Dictionary = coordinator.get_state().value
	assert_eq(changed.candidate.layout, certified.candidate.layout)
	assert_eq(changed.candidate.spec, certified.candidate.spec)
	assert_eq(changed.candidate.forced_cell, 10)
	assert_eq(changed.candidate.actions.size(), 2)
	assert_eq(port.motivation, 7)
	assert_true(_reveal(10).ok)
	assert_eq(port.motivation, 6)
	assert_eq(coordinator.get_state().value.board.board.actions.size(), 2)

func test_certified_unpaid_difficulty_change_drops_recipe_without_new_spec_or_cost() -> void:
	_certify_shell(false)
	_durable()
	var calls := generator.calls.size()
	var preparation_calls := port.call_log.filter(func(entry: Dictionary) -> bool: return entry.method == &"prepare_spec").size()
	assert_true(coordinator.get_configuration_context().value.difficulty_enabled.has("expert"))
	assert_true(coordinator.select_difficulty(_request("expert")).ok)
	var state: Dictionary = coordinator.get_state().value
	assert_eq(state.phase, "UNPAID_UNSTARTED")
	assert_null(state.identity)
	assert_eq(state.candidate.difficulty_id, "expert")
	assert_false(state.candidate.has("spec"))
	assert_eq(state.candidate.actions, [])
	assert_eq(generator.calls.size(), calls)
	assert_eq(port.call_log.filter(func(entry: Dictionary) -> bool: return entry.method == &"prepare_spec").size(), preparation_calls)
	assert_eq(port.motivation, 7)
	assert_eq(durable.disk.desktop.board, state)

func test_certified_paid_difficulty_change_retains_payment_and_new_board_is_noop() -> void:
	var certified := _certify_shell(true)
	_durable()
	var no_op: Dictionary = coordinator.replace_board(_request("beginner"))
	assert_true(no_op.ok, str(no_op))
	assert_true(no_op.value.unchanged)
	assert_eq(coordinator.get_state().value, certified)
	assert_eq(durable.prepares, 0)
	assert_true(coordinator.select_difficulty(_request("expert")).ok)
	var state: Dictionary = coordinator.get_state().value
	assert_eq(state.phase, "PAID_UNSTARTED")
	assert_eq(state.identity, certified.identity)
	assert_eq(state.candidate.paid_start_receipt, certified.candidate.paid_start_receipt)
	assert_ne(state.candidate.spec.board_token, certified.candidate.spec.board_token)
	assert_eq(state.candidate.spec.difficulty_id, "expert")
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)


# The facade intentionally forbids direct day issuance; fixture bootstrap uses the
# root receipt seam also used by the established round/consequence fixtures.
func _mint_fixture_day() -> Dictionary:
	var receipt: Dictionary = root_store.mint(&"causal_day_instance")
	assert_true(issuer.verify_issued(receipt, &"causal_day_instance").ok)
	return {"ok": true, "value": {"token": str(receipt.token), "issuer_receipt": receipt}}


func _cold_restore_paid_board(saved: Dictionary, source_day_receipt: Dictionary) -> Dictionary:
	var remapper := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
	var consequence: Dictionary = CONSEQUENCE.make_empty({
		"causal_day_instance": str(source_day_receipt.token),
		"causal_day_instance_issuer_receipt": source_day_receipt})
	assert_true(consequence.ok, str(consequence))
	var source := {"lifecycle": {}, "desktop": {"board": saved.duplicate(true), "consequence": consequence.value.state}}
	var frozen_source := source.duplicate(true)
	var census: Dictionary = remapper.collect_rewindable_transaction_ids(source)
	assert_true(census.ok, str(census))
	var transaction_remap := {}
	for old_id: String in census.value.transaction_ids:
		var issued: Dictionary = issuer.issue(&"transaction_id")
		assert_true(issued.ok)
		transaction_remap[old_id] = {"source_transaction_id": old_id, "new_transaction_id": str(issued.value.token),
			"new_transaction_issuer_receipt": issued.value.issuer_receipt}
	var restore_transaction: Dictionary = issuer.issue(&"transaction_id")
	var next_day: Dictionary = _mint_fixture_day()
	var bundle := {"transaction_id": str(restore_transaction.value.token),
		"transaction_issuer_receipt": restore_transaction.value.issuer_receipt,
		"branch_id": "branch-cold-restored", "desktop_timeline_generation": int(saved.identity.desktop_timeline_generation) + 1,
		"causal_day_instance": str(next_day.value.token), "causal_day_instance_issuer_receipt": next_day.value.issuer_receipt,
		"transaction_remap": transaction_remap}
	var remapped: Dictionary = remapper.prepare(source, str(restore_transaction.value.token), bundle)
	assert_true(remapped.ok, str(remapped))
	assert_eq(source, frozen_source, "remapping must not mutate the selected durable source")
	if not remapped.ok: return {}
	var validated: Dictionary = remapper.validate_remap(source, remapped.value.snapshot)
	assert_true(validated.ok, str(validated))
	var mapped_board: Dictionary = remapped.value.snapshot.desktop.board
	assert_eq(mapped_board.candidate, saved.candidate, "recipe, marks, history, frontier and original payment stay byte-equal")
	assert_eq(mapped_board.identity.run_id, saved.identity.run_id)
	assert_eq(mapped_board.identity.app_round_ordinal, saved.identity.app_round_ordinal)
	assert_eq(mapped_board.identity.branch_id, bundle.branch_id)
	assert_eq(mapped_board.identity.desktop_timeline_generation, bundle.desktop_timeline_generation)
	assert_eq(mapped_board.identity.causal_day_instance, bundle.causal_day_instance)
	for old_id: String in census.value.transaction_ids:
		var ledger_key := "command_receipts" if saved.command_receipts.has(old_id) else "terminal_receipts"
		assert_false(mapped_board[ledger_key].has(old_id))
		assert_true(mapped_board[ledger_key].has(transaction_remap[old_id].new_transaction_id))

	# A cold owner cannot benefit from the source coordinator's local retry/spec caches.
	var paid_motivation: int = port.motivation
	var paid_rounds: int = port.rounds_left
	var next_ordinal: int = port.next_ordinal
	var selected: String = port.selected
	coordinator = COORDINATOR.new()
	port = StatePort.new()
	port.motivation = paid_motivation
	port.rounds_left = paid_rounds
	port.next_ordinal = next_ordinal
	port.selected = selected
	port.branch_id = str(bundle.branch_id)
	port.desktop_timeline_generation = int(bundle.desktop_timeline_generation)
	port.causal_day_instance = str(bundle.causal_day_instance)
	port.board_owner = coordinator._board_state
	issuer = ISSUER.new()
	assert_true(issuer.configure(root_store).ok, "fresh issuer facade uses the retained durable root")
	port.identity_issuer = issuer
	generator = Generation.new()
	assert_true(coordinator.configure(port, OLD_CHECKPOINT.new(), generator, issuer).ok)
	var participant := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(coordinator._board_state)
	var prepared: Dictionary = participant.prepare({"state": mapped_board})
	assert_true(prepared.ok, str(prepared))
	assert_true(participant.apply_silent(prepared.value.board_plan).ok)
	assert_true(participant.finalize().ok)
	assert_eq(coordinator.get_state().value, mapped_board)
	_durable()
	return mapped_board


func test_cold_paid_shell_remaps_identity_keeps_recipe_and_rejects_old_reveal_without_repayment() -> void:
	var source_day: Dictionary = _mint_fixture_day()
	port.causal_day_instance = str(source_day.value.token)
	var original := _start()
	_durable()
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	assert_true(_flag(41, true).ok)
	assert_true(_flag(42, true).ok)
	assert_true(_flag(42, false).ok)
	var saved: Dictionary = durable.disk.desktop.board.duplicate(true)
	var old_reveal := _request("intermediate")
	old_reveal["cell_index"] = 40
	var mapped := _cold_restore_paid_board(saved, source_day.value.issuer_receipt)
	assert_false(mapped.is_empty())
	if mapped.is_empty(): return
	assert_true(issuer.verify_issued(old_reveal.transaction_issuer_receipt, &"transaction_id").ok,
		"the stale command is a genuinely issued command; branch identity is what refuses it")
	var rejected: Dictionary = coordinator.reveal(old_reveal)
	assert_eq(rejected.code, &"identity_mismatch", str(rejected))
	assert_eq(coordinator.get_state().value, mapped)
	assert_eq(generator.calls, [])
	assert_true(_reveal(40, "intermediate").ok)
	var active: Dictionary = coordinator.get_state().value
	assert_eq(active.board.spec, saved.candidate.spec)
	assert_eq(active.board.board.actions, saved.candidate.actions)
	assert_eq(active.board.board.flagged_indices, [41])
	assert_eq(active.board.paid_start_receipt, original.board.paid_start_receipt)
	assert_eq(active.identity, mapped.identity)
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)
	assert_eq(port.next_ordinal, 2)
	assert_eq(generator.calls.size(), 1)
	assert_eq(durable.disk.desktop.board, active)


func test_cold_paid_preparing_restore_keeps_frontier_and_rejects_old_issued_slice() -> void:
	var source_day: Dictionary = _mint_fixture_day()
	port.causal_day_instance = str(source_day.value.token)
	var original := _start()
	_durable()
	port.generation_capabilities = ["first_cell_safe", "forced_no_guess"]
	assert_true(coordinator.select_difficulty(_request("intermediate")).ok)
	assert_true(_flag(41, true).ok)
	generator.search_frontier = {"cursor": 7, "rng_state": [13, 21], "retained_candidates": [2, 5]}
	var begun: Dictionary = coordinator.begin_debug_preparation(_request("intermediate"))
	assert_true(begun.ok, str(begun))
	var saved: Dictionary = durable.disk.desktop.board.duplicate(true)
	assert_eq(saved.phase, "PREPARING")
	assert_eq(saved.candidate.frontier, generator.search_frontier)
	var old_slice := _request()
	var mapped := _cold_restore_paid_board(saved, source_day.value.issuer_receipt)
	assert_false(mapped.is_empty())
	if mapped.is_empty(): return
	assert_eq(mapped.phase, "PREPARING")
	assert_eq(mapped.candidate.frontier, saved.candidate.frontier)
	assert_eq(mapped.candidate.flagged_indices, [41])
	assert_eq(mapped.candidate.paid_start_receipt, original.board.paid_start_receipt)
	assert_true(issuer.verify_issued(old_slice.transaction_issuer_receipt, &"transaction_id").ok)
	var rejected: Dictionary = coordinator.run_debug_preparation_slice(old_slice)
	assert_eq(rejected.code, &"identity_mismatch", str(rejected))
	assert_eq(coordinator.get_state().value, mapped)
	assert_eq(coordinator.get_preparation_context().value.action, "slice")
	assert_eq(coordinator.get_preparation_context().value.identity, mapped.identity)
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)
	assert_eq(port.next_ordinal, 2)


func test_cost_free_failure_uses_captured_journal_with_real_candidate_storage_descriptor() -> void:
	_start()
	_durable()
	durable.journal = {"revision": 7, "snapshot": {"journal_only": "prior checkpoint"}}
	durable.disk = {"physical_only": "prior validated autosave"}
	var prior_journal := durable.journal.duplicate(true)
	var prior_disk := durable.disk.duplicate(true)
	var prior_board: Dictionary = coordinator.get_state().value
	var request := _request("intermediate")
	durable.fail_write = true
	var failed: Dictionary = coordinator.select_difficulty(request)
	assert_false(failed.ok, str(failed))
	var keys: Array = durable.last_candidate.keys()
	keys.sort()
	assert_eq(keys, ["autosave_document", "checkpoint_id", "journal_candidate", "storage_backup"])
	assert_eq(durable.journal, prior_journal)
	assert_eq(durable.disk, prior_disk)
	assert_eq(coordinator.get_state().value, prior_board)
	assert_eq(port.selected, "beginner")
	assert_eq(durable.rollbacks, 1)
	assert_true(coordinator.select_difficulty(request).ok)
	assert_eq(durable.journal.revision, 8)
	assert_eq(durable.journal.snapshot, durable.disk)
	assert_eq(durable.disk.desktop.board, coordinator.get_state().value)
	assert_eq(port.motivation, 6)
	assert_eq(port.rounds_left, 1)
