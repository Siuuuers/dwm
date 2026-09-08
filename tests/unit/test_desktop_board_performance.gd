extends GutTest

const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")
const DATING := preload("res://scripts/application/run/DatingChallengeRules.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const REWARD := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")
const ROUND_FIXTURE := preload("res://tests/unit/test_minesweeper_round_coordinator.gd")
const REGISTER_FIXTURE := preload("res://tests/unit/test_minesweeper_register_query.gd")
const QUERY := preload("res://scripts/application/minesweeper/MinesweeperRegisterQuery.gd")
const LAYOUT := {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [4], "mine_count": 1}
const ACTIVE := {"round_id": "performance-round", "context": "app", "difficulty": "beginner"}

func _first() -> Dictionary:
	return REDUCER.first_reveal(LAYOUT, 0).value.board

func _chord_clear(extra_flag_pair: bool = false) -> Dictionary:
	var board: Dictionary = REDUCER.set_flag(_first(), 4, true, "flag").value.board
	if extra_flag_pair:
		board = REDUCER.set_flag(board, 4, false, "unflag").value.board
		board = REDUCER.set_flag(board, 4, true, "reflag").value.board
	for cell: int in [0, 1, 3, 5]:
		var result: Dictionary = REDUCER.chord(board, cell, "chord-%d" % cell)
		assert_true(result.ok, str(result))
		if not result.ok: return board
		board = result.value.board
	assert_eq(str(board.outcome), "cleared")
	return board

func test_real_chords_exceed_one_hundred_but_exact_one_hundred_does_not_qualify() -> void:
	var board := _chord_clear()
	assert_eq(PERFORMANCE.three_bv(board), 8)
	assert_eq(PERFORMANCE.click_count(board), 6)
	assert_almost_eq(PERFORMANCE.foresight_percent(board), 133.333333, 0.0001)
	assert_eq(PERFORMANCE.perfect_reasons(board), ["efficiency_gt_100"])
	assert_eq(DATING.perfect_reasons(board), PERFORMANCE.perfect_reasons(board))
	var exact := _chord_clear(true)
	assert_eq(PERFORMANCE.click_count(exact), 8)
	assert_eq(PERFORMANCE.foresight_percent(exact), 100.0)
	assert_eq(PERFORMANCE.perfect_reasons(exact), [])

func test_flag_then_unflag_cannot_recover_no_flag_and_individual_reveals_count_first_click() -> void:
	for used_flag: bool in [false, true]:
		var board := _first()
		if used_flag:
			board = REDUCER.set_flag(board, 4, true, "flag").value.board
			board = REDUCER.set_flag(board, 4, false, "unflag").value.board
		for cell: int in [1, 2, 3, 5, 6, 7, 8]:
			board = REDUCER.reveal(board, cell, "reveal-%d" % cell).value.board
		assert_eq(PERFORMANCE.click_count(board), 10 if used_flag else 8)
		assert_eq(PERFORMANCE.perfect_reasons(board), [] if used_flag else ["no_flag"])

func test_exploded_board_has_no_qualifiers_even_with_high_ratio_and_no_flags() -> void:
	var board: Dictionary = REDUCER.reveal(_first(), 4, "explode").value.board
	assert_gt(PERFORMANCE.foresight_percent(board), 100.0)
	assert_eq(PERFORMANCE.perfect_reasons(board), [])

func test_both_qualifiers_award_each_task_once_without_expanding_durable_receipt() -> void:
	var state: Node = autofree(GAME_STATE.new())
	state.reset_game()
	var port: RefCounted = REWARD.new(state)
	# The port accepts the two independently derived reasons, without squeezing them into one outcome.
	var result := {"outcome": "perfect", "perfect_reasons": ["efficiency_gt_100", "no_flag"]}
	var before: Dictionary = state.to_save_dict().duplicate(true)
	var prepared: Dictionary = port.prepare_complete(ACTIVE, result, "both-1")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(state.to_save_dict(), before)
	var receipt: Dictionary = prepared.value.prepared_domain_receipt
	assert_eq(receipt.task_ids, ["complete_beginner", "perfect_beginner", "no_flag_finish", "foresight_finish"])
	var legacy: Dictionary = port.prepare_complete(ACTIVE, {"outcome": "no_flag"}, "legacy")
	assert_eq(receipt.keys(), legacy.value.prepared_domain_receipt.keys())
	assert_eq(legacy.value.prepared_domain_receipt.task_ids, ["complete_beginner", "no_flag_finish"])
	assert_true(port.commit(prepared.value.prepared_candidate).ok)
	var claims: Dictionary = state.minesweeper_task_rewards_claimed.duplicate(true)
	var repeated: Dictionary = port.prepare_complete(ACTIVE, result, "both-2")
	assert_true(repeated.ok, str(repeated))
	assert_eq(repeated.value.prepared_candidate.gameplay.minesweeper_task_rewards_claimed, claims)
	assert_eq(repeated.value.prepared_domain_receipt.counter_deltas.money, 9, "only ordinary Perfect round money repeats")
	assert_eq(receipt.counter_deltas.money, 9)
	assert_eq(prepared.value.prepared_candidate.gameplay.coins, 4, "first round adds the four existing task coins")
	assert_eq(repeated.value.prepared_candidate.gameplay.coins, 4, "task coins do not repeat")

func test_optional_qualifiers_reject_unknown_duplicate_and_outcome_mismatch_before_mutation() -> void:
	var state: Node = autofree(GAME_STATE.new())
	state.reset_game()
	var port: RefCounted = REWARD.new(state)
	var before: Dictionary = state.to_save_dict().duplicate(true)
	for result: Dictionary in [
		{"outcome": "perfect", "perfect_reasons": "no_flag"},
		{"outcome": "perfect", "perfect_reasons": ["unknown"]},
		{"outcome": "perfect", "perfect_reasons": ["no_flag", "no_flag"]},
		{"outcome": "perfect", "perfect_reasons": []},
		{"outcome": "exploded", "perfect_reasons": ["no_flag"]},
	]:
		assert_eq(port.prepare_complete(ACTIVE, result, "bad").code, &"invalid_perfect_reasons")
	assert_eq(state.to_save_dict(), before)

func _round_cell(fixture: Node, method: String, cell: int, flagged: bool = true) -> void:
	var live: Dictionary = fixture._coordinator.get_state().value
	var request: Dictionary = fixture._cell_request_with_real_transaction(live.identity, live.revision, cell)
	if method == "set_flag": request["flagged"] = flagged
	var result: Dictionary = fixture._coordinator.call(method, request)
	assert_true(result.ok, str(result))

func test_real_desktop_completion_freezes_perfect_reward_and_qualifying_tasks_for_exact_retry() -> void:
	var fixture: Node = autofree(ROUND_FIXTURE.new())
	fixture.gut = gut
	fixture.before_each()
	fixture._generation_port.arm_materialize(LAYOUT)
	var state: Node = autofree(GAME_STATE.new())
	state.reset_game()
	assert_true(fixture._coordinator.configure_reward_port(REWARD.new(state)).ok)
	assert_true(fixture._reveal_first(fixture._next_tx(), "beginner", 0).ok)
	# The legacy fake stores only a checkpoint marker; the real durable owner retains the tier.
	# Supply that same frozen fact through the real board-state restore seam for this reward test.
	var paid_snapshot: Dictionary = fixture._coordinator._board_state.capture()
	paid_snapshot.board.paid_start_receipt["difficulty_id"] = "beginner"
	var restored: Dictionary = fixture._coordinator._board_state.prepare_restore(paid_snapshot)
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	assert_true(fixture._coordinator._board_state.commit(restored.value.candidate).ok)
	_round_cell(fixture, "set_flag", 4)
	for cell: int in [0, 1, 3, 5]: _round_cell(fixture, "chord", cell)
	fixture._consequence_port.armed_result = {"ok": false, "code": &"test_handoff_failure"}
	var request: Dictionary = fixture._complete_round_request(fixture._next_tx())
	assert_false(fixture._coordinator.complete_round(request).ok)
	var first: Dictionary = fixture._consequence_port.calls[0].duplicate(true)
	var candidate: Dictionary = first.action_candidate
	assert_eq(candidate.outcome, "cleared", "board fate remains distinct from reward classification")
	assert_eq(candidate.reward.prepared_domain_receipt.outcome, "perfect")
	assert_eq(candidate.reward.prepared_domain_receipt.task_ids, ["complete_beginner", "perfect_beginner", "foresight_finish"])
	fixture._consequence_port.armed_result = {}
	assert_true(fixture._coordinator.complete_round(request).ok)
	assert_eq(fixture._consequence_port.calls[1], first, "retry preserves the already frozen reward candidate")
	assert_eq(state.money, 0, "preparation and handoff never commit rewards by themselves")

func test_retained_and_restored_board_derive_same_register_without_adding_saved_fields() -> void:
	var fixture: Node = autofree(REGISTER_FIXTURE.new())
	fixture.gut = gut
	var snapshot: Dictionary = fixture._snapshot([4])
	snapshot.board.board = _chord_clear()
	var state: Node = autofree(GAME_STATE.new())
	state.reset_game()
	var saved: Dictionary = snapshot.duplicate(true)
	var projected: Dictionary = QUERY.desktop(snapshot, state)
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	assert_eq(projected.value.foresight, 133)
	assert_eq(projected.value.no_flag, "lost")
	var restored: Dictionary = saved.duplicate(true)
	restored.phase = "ACTIVE_SUSPENDED"
	var reprojected: Dictionary = QUERY.desktop(restored, state)
	assert_eq(reprojected.value.foresight, projected.value.foresight)
	assert_eq(reprojected.value.no_flag, projected.value.no_flag)
	assert_eq(snapshot, saved)
	assert_false(snapshot.board.board.has("three_bv"))
	assert_false(snapshot.board.board.has("click_count"))
	assert_false(snapshot.board.board.has("foresight"))
