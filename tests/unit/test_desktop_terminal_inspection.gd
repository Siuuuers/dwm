extends GutTest

const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const PAID_FIXTURE := preload("res://tests/unit/test_desktop_paid_replacement.gd")
const ROUND_FIXTURE := preload("res://tests/unit/test_minesweeper_round_coordinator.gd")
const FATE_FIXTURE := preload("res://tests/unit/test_desktop_board_fate_port.gd")
const WARNING := preload("res://scripts/application/schedule/GameStateScheduleWarningContextPort.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const REWARD := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const LAYOUT := {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [4], "mine_count": 1}

class CountingReward extends RefCounted:
	var real: RefCounted
	var preparations := 0
	var commits := 0
	func prepare_complete(active: Dictionary, result: Dictionary, transaction: String) -> Dictionary:
		preparations += 1
		return real.prepare_complete(active, result, transaction)
	func commit_desktop_completion(candidate: Dictionary) -> Dictionary:
		commits += 1
		return real.commit_desktop_completion(candidate)
	func publish_desktop_completion(receipt: Dictionary, events: Array) -> Dictionary:
		return real.publish_desktop_completion(receipt, events)

func _paid() -> Dictionary:
	var fixture: Node = autofree(PAID_FIXTURE.new())
	fixture.gut = gut
	fixture.before_each()
	var day: Dictionary = fixture._mint_fixture_day()
	fixture.port.causal_day_instance = str(day.value.token)
	return {"fixture": fixture, "day_receipt": day.value.issuer_receipt}

func _settled(fixture: Node) -> Dictionary:
	var started: Dictionary = fixture._start()
	# The legacy fixture normally keeps a checkpoint-only marker. Retain its actual
	# accepted first-Reveal receipt, as the production full-checkpoint path does.
	for entry: Dictionary in started.command_receipts.values():
		if str(entry.command_kind) == "first_reveal":
			started.board.paid_start_receipt = entry.result.value.receipt.duplicate(true)
	var adopted: Dictionary = fixture.coordinator._board_state.prepare_restore(started)
	assert_true(adopted.ok, str(adopted))
	assert_true(fixture.coordinator._board_state.commit(adopted.value.candidate).ok)
	# An already paid Reveal has no difficulty_id; the first-Reveal fixture helper
	# intentionally supplies that field and is not this command's public envelope.
	var explode: Dictionary = fixture._request()
	explode["cell_index"] = 0
	var exploded: Dictionary = fixture.coordinator.reveal(explode)
	assert_true(exploded.ok, str(exploded))
	var terminal: Dictionary = fixture.coordinator.get_state().value
	assert_true(terminal.board.board.terminal, str(terminal.board.board.outcome))
	var command: Dictionary = fixture._request()
	var projection: Dictionary = fixture.coordinator._project_completion_board(
		terminal.identity, terminal, str(terminal.board.board.outcome), str(command.transaction_id))
	var prepared: Dictionary = fixture.coordinator._board_state.prepare_restore(projection)
	assert_true(prepared.ok, str(prepared))
	assert_true(fixture.coordinator._board_state.commit(prepared.value.candidate).ok)
	assert_true(fixture.coordinator._board_state.has_settled_inspection(), str(projection.terminal_receipts))
	return projection

func test_binding_survives_json_stringname_and_typed_array_normalization_but_not_board_change() -> void:
	var setup := _paid()
	var snapshot := _settled(setup.fixture)
	var binding := STATE.inspection_board_sha256(snapshot.board)
	assert_eq(binding.length(), 64)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	assert_true(STATE.is_settled_inspection(parsed), "ordinary JSON integral floats keep the exact binding")
	var typed: Dictionary = snapshot.board.duplicate(true)
	var indices: Array[int] = []
	indices.assign(typed.board.mine_indices)
	typed.board[&"mine_indices"] = indices
	typed.board[&"outcome"] = StringName(typed.board.outcome)
	assert_eq(STATE.inspection_board_sha256(typed), binding)
	parsed.board.paid_start_receipt["different_payment"] = true
	assert_false(STATE.is_settled_inspection(parsed))
	var legacy := snapshot.duplicate(true)
	for receipt: Dictionary in legacy.terminal_receipts.values(): receipt.erase("board_sha256")
	assert_false(STATE.is_settled_inspection(legacy), "an old ordinal alone cannot suppress settlement")
	legacy = STATE.dismissed_inspection_snapshot(legacy)
	assert_true(STATE.new().prepare_restore(legacy).ok, "historical completed NONE remains loadable")

func test_cold_remapped_terminal_keeps_exact_inspection_and_rejects_old_action_without_payment() -> void:
	var setup := _paid()
	var fixture: Node = setup.fixture
	var saved := _settled(fixture)
	var old_action: Dictionary = fixture._request()
	old_action["cell_index"] = 15
	var parsed: Dictionary = STATE._inspection_normalize(JSON.parse_string(JSON.stringify(saved)))
	var mapped: Dictionary = fixture._cold_restore_paid_board(parsed, setup.day_receipt)
	assert_false(mapped.is_empty())
	if mapped.is_empty(): return
	assert_eq(_canonical(mapped.board), _canonical(saved.board))
	var configuration: Dictionary = fixture.coordinator.get_configuration_context()
	assert_true(configuration.ok, str(configuration))
	if not configuration.ok: return
	assert_true(configuration.value.settled_inspection)
	assert_true(fixture.coordinator.get_configuration_context().value.new_board_enabled)
	assert_eq(fixture.coordinator.get_configuration_context().value.difficulty_enabled, [])
	assert_false(fixture.coordinator.reveal(old_action).ok)
	assert_true(fixture.coordinator.suspend(fixture._request()).ok)
	assert_true(fixture.coordinator._board_state.has_settled_inspection())
	assert_true(fixture.coordinator.resume(fixture._request()).ok)
	assert_eq(_canonical(fixture.coordinator.get_state().value.board), _canonical(saved.board))
	assert_eq(fixture.port.motivation, 6)
	assert_eq(fixture.port.rounds_left, 1)
	assert_eq(fixture.generator.calls, [])

func test_dismissal_final_reread_failure_restores_inspection_and_exact_retry_is_durable() -> void:
	var setup := _paid()
	var fixture: Node = setup.fixture
	var saved := _settled(fixture)
	fixture._durable()
	fixture.durable.disk = {"desktop": {"board": saved.duplicate(true)}}
	var old_disk: Dictionary = fixture.durable.disk.duplicate(true)
	var request: Dictionary = fixture._request("beginner")
	fixture.durable.fail_write = true
	var failed: Dictionary = fixture.coordinator.replace_board(request)
	assert_false(failed.ok, str(failed))
	assert_eq(fixture.coordinator.get_state().value, saved)
	assert_eq(_canonical(fixture.durable.disk), _canonical(old_disk),
		"rollback preserves every serialized field across native StringName/typed-array JSON normalization")
	assert_eq(fixture.durable.rollbacks, 1)
	var wrong: Dictionary = fixture.coordinator.replace_board(fixture._request("beginner"))
	assert_eq(wrong.code, &"configuration_retry_required", str(wrong))
	assert_true(fixture.coordinator.replace_board(request).ok)
	var dismissed: Dictionary = fixture.coordinator.get_state().value
	assert_eq(dismissed.phase, "NONE")
	assert_null(dismissed.board)
	assert_eq(dismissed.terminal_receipts, saved.terminal_receipts)
	assert_eq(fixture.durable.disk.desktop.board, dismissed)
	var writes: int = fixture.durable.writes
	assert_true(fixture.coordinator.replace_board(request).ok)
	assert_eq(fixture.durable.writes, writes)
	assert_eq(fixture.generator.calls.size(), 1)
	assert_eq(fixture.port.motivation, 6)
	assert_eq(fixture.port.rounds_left, 1)
	var cold := STATE.new()
	assert_true(cold.commit(cold.prepare_restore(dismissed).value.candidate).ok)
	assert_false(cold.has_settled_inspection())
	assert_null(cold.capture().board)

func test_round_and_shop_preserve_inspection_but_schedule_retires_without_forfeit() -> void:
	var setup := _paid()
	var fixture: Node = setup.fixture
	var saved := _settled(fixture)
	var helper: Node = autofree(FATE_FIXTURE.new())
	helper.gut = gut
	helper.before_each()
	helper._coordinator = fixture.coordinator
	helper._issuer = fixture.issuer
	helper._root_store = fixture.root_store
	var port: RefCounted = helper._wired().port
	for kind: String in ["minesweeper_round", "shop_purchase"]:
		var transaction: String = helper._next_tx()
		var receipt: Dictionary = helper._source_action_receipt(transaction, kind)
		var prepared: Dictionary = port.prepare_projected_causal_departure(helper._projected_request(transaction, receipt, saved, saved))
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: return
		assert_eq(prepared.value.board_fate_receipt.fate, "none")
		assert_eq(prepared.value.board_candidate, saved)
		assert_true(port.commit(prepared.value.board_candidate).ok)
	var closing: Dictionary = port.prepare_causal_departure(helper._schedule_request(helper._next_tx(), saved))
	assert_true(closing.ok, str(closing))
	if not closing.ok: return
	assert_eq(closing.value.board_fate_receipt.fate, "none")
	assert_null(closing.value.board_fate_receipt.board_identity)
	assert_eq(closing.value.board_candidate.phase, "NONE")
	assert_eq(closing.value.board_candidate.terminal_receipts, saved.terminal_receipts)
	assert_true(port.commit(closing.value.board_candidate).ok)
	assert_eq(fixture.coordinator.get_state().value.phase, "NONE")
	assert_true(port.commit(closing.value.board_candidate).ok)

func test_schedule_warning_distinguishes_settled_inspection_from_unsettled_terminal() -> void:
	var setup := _paid()
	var saved := _settled(setup.fixture)
	var state: Dictionary = saved.identity.duplicate(true)
	state["next_app_round_ordinal"] = 2
	var query := WARNING.new()
	var settled: Dictionary = query._project_board(state, saved)
	assert_true(settled.ok, str(settled))
	assert_false(settled.value.unfinished_base_board)
	assert_eq(settled.value.board_identity, saved.identity)
	var unsettled := saved.duplicate(true)
	unsettled.terminal_receipts = {}
	assert_true(query._project_board(state, unsettled).value.unfinished_base_board)

func test_real_rewards_are_applied_once_then_cold_settled_completion_skips_preparation_and_commit() -> void:
	var fixture: Node = autofree(ROUND_FIXTURE.new())
	fixture.gut = gut
	fixture.before_each()
	fixture._generation_port.arm_materialize(LAYOUT)
	var game: Node = autofree(GAME_STATE.new())
	game.reset_game()
	assert_true(game.configure_mutation_gate(fixture._consequence_gate).ok)
	var counted := CountingReward.new()
	counted.real = REWARD.new(game)
	assert_true(counted.real.configure(fixture._consequence_gate).ok)
	assert_true(fixture._coordinator.configure_reward_port(counted).ok)
	assert_true(fixture._reveal_first(fixture._next_tx(), "beginner", 0).ok)
	var paid: Dictionary = fixture._coordinator.get_state().value
	paid.board.paid_start_receipt["difficulty_id"] = "beginner"
	assert_true(fixture._coordinator._board_state.commit(fixture._coordinator._board_state.prepare_restore(paid).value.candidate).ok)
	for cell: int in [4, 0, 1, 3, 5]:
		var live: Dictionary = fixture._coordinator.get_state().value
		var request: Dictionary = fixture._cell_request_with_real_transaction(live.identity, live.revision, cell)
		if cell == 4: request["flagged"] = true
		var played: Dictionary = fixture._coordinator.set_flag(request) if cell == 4 else fixture._coordinator.chord(request)
		assert_true(played.ok, str(played))
	assert_true(fixture._coordinator.complete_round(fixture._complete_round_request(fixture._next_tx())).ok)
	var admitted: Dictionary = fixture._consequence_port.calls[0]
	var committed: Dictionary = fixture._coordinator.commit_recovery_action(admitted.action_candidate, admitted.action_receipt)
	assert_true(committed.ok, str(committed))
	if not committed.ok: return
	assert_gt(game.money, 0)
	var paid_game: Dictionary = game.to_save_dict()
	var completed_board: Dictionary = fixture._coordinator.get_state().value
	assert_true(STATE.is_settled_inspection(completed_board))
	assert_true(fixture._coordinator.release_recovery_lease().ok)
	# A new process has no coordinator completion cache. Install the settled board with
	# a drained consequence owner, as a successful final full checkpoint does.
	var cold := COORDINATOR.new()
	assert_true(cold.configure(fixture._state_port, fixture._checkpoint_port, fixture._generation_port, fixture._issuer).ok)
	assert_true(cold.configure_consequence_port(fixture._consequence_port, fixture._consequence_gate).ok)
	var drained: RefCounted = fixture._bootstrap_consequence_state("causal-day-1")
	assert_true(cold.configure_consequence_checkpoint(drained, fixture._consequence_checkpoint_port).ok)
	assert_true(cold.configure_reward_port(counted).ok)
	var parsed: Dictionary = STATE._inspection_normalize(JSON.parse_string(JSON.stringify(completed_board)))
	assert_true(cold._board_state.commit(cold._board_state.prepare_restore(parsed).value.candidate).ok)
	fixture._coordinator = cold
	var result: Dictionary = cold.complete_round(fixture._complete_round_request(fixture._next_tx()))
	assert_true(result.ok, str(result))
	assert_true(result.value.get("already_settled", false))
	assert_eq(counted.preparations, 1)
	assert_eq(counted.commits, 1)
	assert_eq(game.to_save_dict(), paid_game)
	assert_eq(cold.get_state().value, parsed)


func _canonical(value: Variant) -> String:
	var emitted := CANONICAL.stringify(STATE._inspection_normalize(value))
	assert_true(emitted.ok, str(emitted))
	return str(emitted.get("value", ""))
