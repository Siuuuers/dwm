extends GutTest

const QUERY := preload("res://scripts/application/minesweeper/MinesweeperRegisterQuery.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const UNAVAILABLE := {"ok": false, "code": &"minesweeper_register_unavailable"}
const IDENTITY := {"run_id": "private-run", "branch_id": "private-branch", "desktop_timeline_generation": 0,
	"causal_day_instance": "private-day", "app_round_ordinal": 1}

class StateFixture extends RefCounted:
	var minesweeper_rounds_left: Variant = 2
	var minesweeper_selected_difficulty: Variant = "beginner"


func _layout(mines: Array = [1]) -> Dictionary:
	return {"schema_version": 1, "width": 3, "height": 3, "mine_indices": mines, "mine_count": mines.size()}


func _spec() -> Dictionary:
	return {"schema_version": 1, "board_kind": "desktop", "board_token": "private-token", "board_token_receipt_id": "private-receipt",
		"difficulty_id": "intermediate", "width": 3, "height": 3, "base_mine_count": 1, "pressure": 0, "penalty_points_today": 0,
		"raw_extra_mines": 0, "requested_mine_count": 1, "capability_ids": ["first_cell_safe"],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "private-p", "placement_nonce_receipt_id": "private-pr",
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "private-d", "debug_nonce_receipt_id": "private-dr",
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "private-e", "explosion_nonce_receipt_id": "private-er",
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1"}


func _snapshot(mines: Array = [1], journal_receipt: bool = false) -> Dictionary:
	var state := STATE.new()
	var layout := _layout(mines)
	var board: Dictionary = REDUCER.first_reveal(layout, 0).value.board
	var marker := {"checkpoint_id": "private-checkpoint"}
	if not journal_receipt: marker["difficulty_id"] = "intermediate"
	var prepared := state.prepare_first_reveal({"transaction_id": "private-command", "identity": IDENTITY,
		"expected_revision": 0, "cell_index": 0, "spec": _spec(), "request_fingerprint": "private-fingerprint"},
		{"layout": layout, "board": board}, marker)
	assert_true(prepared.ok)
	if journal_receipt:
		prepared.value.candidate.result_override = {"ok": true, "code": &"first_reveal_committed", "value": {"receipt": {
			"checkpoint_id": "private-checkpoint", "transaction_id": "private-command", "identity": IDENTITY.duplicate(),
			"difficulty_id": "intermediate", "first_cell": 0, "board_revision": 0,
		}}, "receipt": {}}
	assert_true(state.commit(prepared.value.candidate).ok)
	return state.capture()


func _prepared(preparing: bool = false) -> Dictionary:
	var state := STATE.new()
	var begun := state.prepare_debug_candidate({"transaction_id": "prepare", "identity": IDENTITY, "expected_revision": 0,
		"spec": _spec(), "request_fingerprint": "prepare-fingerprint"}, {"frontier": {"private_cursor": 77}})
	assert_true(begun.ok)
	assert_true(state.commit(begun.value.candidate).ok)
	if not preparing:
		var certified := state.prepare_debug_slice({"transaction_id": "certify", "identity": IDENTITY, "expected_revision": 1,
			"request_fingerprint": "certify-fingerprint"}, {"done": true, "layout": _layout(), "forced_cell": 0, "proof_sha256": "private-proof"})
		assert_true(certified.ok)
		assert_true(state.commit(certified.value.candidate).ok)
	return state.capture()


func test_none_reads_selected_tier_and_raw_signed_rounds_without_mutating_real_owner() -> void:
	var state := GAME_STATE.new()
	state.reset_game()
	state.minesweeper_selected_difficulty = "expert"
	state.minesweeper_round_floor = -3
	var snapshot := STATE.new().capture()
	for rounds: int in [-4, -3, -1, 0, 2, 3]:
		state.minesweeper_rounds_left = rounds
		var before: Dictionary = state.to_save_dict().duplicate(true)
		var snapshot_before := snapshot.duplicate(true)
		assert_eq(QUERY.desktop(snapshot, state), {"ok": true, "value": {
			"difficulty": "expert", "rounds": rounds, "mine_estimate": null,
			"foresight": null, "no_flag": "intact", "custody": false, "difficulty_enabled": [],
		}})
		assert_eq(state.to_save_dict(), before)
		assert_eq(snapshot, snapshot_before)
	state.free()


func test_active_and_prepared_use_frozen_difficulty_and_keep_missing_owners_unavailable() -> void:
	var state := StateFixture.new()
	state.minesweeper_selected_difficulty = "expert"
	for snapshot: Dictionary in [_snapshot(), _prepared(), _prepared(true)]:
		var result: Dictionary = QUERY.desktop(snapshot, state)
		assert_true(result.ok)
		assert_eq(result.value.difficulty, "intermediate")
		assert_eq(result.value.custody, snapshot.phase == "PREPARING")
		assert_eq(result.value.no_flag, "intact")
		assert_null(result.value.foresight)
		assert_eq(result.value.difficulty_enabled, [])
		assert_false(JSON.stringify(result).contains("private"))


func test_committed_flag_then_unflag_keeps_no_flag_lost_and_estimate_signed() -> void:
	var state := StateFixture.new()
	var snapshot := _snapshot()
	assert_eq(QUERY.desktop(snapshot, state).value.no_flag, "intact")
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board, 2, true, "flag-a").value.board
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board, 3, true, "flag-b").value.board
	var flagged: Dictionary = QUERY.desktop(snapshot, state).value
	assert_eq(flagged.no_flag, "lost")
	assert_eq(flagged.mine_estimate, -1)
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board, 2, false, "unflag-a").value.board
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board, 3, false, "unflag-b").value.board
	var unflagged: Dictionary = QUERY.desktop(snapshot, state).value
	assert_eq(unflagged.no_flag, "lost")
	assert_eq(unflagged.mine_estimate, 1)
	snapshot.phase = "ACTIVE_SUSPENDED"
	assert_true(QUERY.desktop(snapshot, state).value.custody)
	assert_eq(QUERY.desktop(snapshot, state).value.no_flag, "lost")


func test_hidden_layout_changes_cannot_change_register_or_modify_sources() -> void:
	var state := GAME_STATE.new()
	state.reset_game()
	var before: Dictionary = state.to_save_dict().duplicate(true)
	var first := _snapshot([1])
	var second := _snapshot([3])
	var first_before := first.duplicate(true)
	var second_before := second.duplicate(true)
	assert_ne(first.board.board.mine_indices, second.board.board.mine_indices)
	assert_eq(QUERY.desktop(first, state), QUERY.desktop(second, state))
	assert_eq(first, first_before)
	assert_eq(second, second_before)
	assert_eq(state.to_save_dict(), before)
	state.free()


func test_malformed_flag_evidence_and_inconsistent_current_flags_fail_closed() -> void:
	var state := StateFixture.new()
	var flagged := _snapshot()
	flagged.board.board = REDUCER.set_flag(flagged.board.board, 2, true, "flag").value.board
	for malformed: Variant in [null, 1, "private true", []]:
		var bad := flagged.duplicate(true)
		bad.board.board.actions[0].flagged = malformed
		assert_eq(QUERY.desktop(bad, state), UNAVAILABLE)
	var missing := flagged.duplicate(true)
	missing.board.board.actions[0].erase("flagged")
	assert_eq(QUERY.desktop(missing, state), UNAVAILABLE)
	var wrong_position := flagged.duplicate(true)
	wrong_position.board.board.flagged_indices = [3]
	assert_eq(QUERY.desktop(wrong_position, state), UNAVAILABLE)
	var absent := flagged.duplicate(true)
	absent.board.board.flagged_indices = []
	assert_eq(QUERY.desktop(absent, state), UNAVAILABLE)
	var invented := _snapshot()
	invented.board.board.flagged_indices = [2]
	assert_eq(QUERY.desktop(invented, state), UNAVAILABLE)


func test_bad_sources_or_frozen_difficulty_never_expose_private_diagnostics() -> void:
	var state := StateFixture.new()
	assert_eq(QUERY.desktop({}, state), UNAVAILABLE)
	assert_eq(QUERY.desktop(_snapshot(), null), UNAVAILABLE)
	assert_eq(QUERY.desktop(_snapshot(), RefCounted.new()), UNAVAILABLE)
	for malformed: Variant in [null, "-2", 1.5]:
		state.minesweeper_rounds_left = malformed
		assert_eq(QUERY.desktop(_snapshot(), state), UNAVAILABLE)
	state.minesweeper_rounds_left = 2
	state.minesweeper_selected_difficulty = "private unknown tier"
	assert_eq(QUERY.desktop(STATE.new().capture(), state), UNAVAILABLE)
	var bad := _snapshot()
	bad.board.paid_start_receipt.difficulty_id = "private unknown tier"
	assert_eq(QUERY.desktop(bad, state), UNAVAILABLE)
	var corrupt := _snapshot()
	corrupt.board.board.adjacency_counts[0] = 7
	assert_eq(QUERY.desktop(corrupt, state), UNAVAILABLE)


func test_checkpoint_only_marker_resolves_frozen_journal_difficulty_without_mutation() -> void:
	var state := StateFixture.new()
	state.minesweeper_selected_difficulty = "expert"
	var snapshot := _snapshot([1], true)
	var before := snapshot.duplicate(true)
	assert_eq(snapshot.board.paid_start_receipt.keys(), ["checkpoint_id"])
	assert_eq(QUERY.desktop(snapshot, state), QUERY.desktop(_snapshot(), state))
	assert_eq(snapshot, before)
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board, 2, true, "flag").value.board
	assert_eq(QUERY.desktop(snapshot, state).value.difficulty, "intermediate")


func test_missing_ambiguous_or_mismatched_first_reveal_journal_fails_closed() -> void:
	var state := StateFixture.new()
	for corruption: String in ["missing", "checkpoint", "transaction", "identity", "fingerprint", "pre", "post",
		"kind", "code", "first_cell", "board_revision", "difficulty", "duplicate"]:
		var snapshot := _snapshot([1], true)
		var entry: Dictionary = snapshot.command_receipts["private-command"]
		var receipt: Dictionary = entry.result.value.receipt
		match corruption:
			"missing": snapshot.command_receipts.clear()
			"checkpoint": receipt.checkpoint_id = "private-other-checkpoint"
			"transaction": receipt.transaction_id = "private-other-command"
			"identity": receipt.identity.run_id = "private-other-run"
			"fingerprint": entry.identity_fingerprint = "private-other-fingerprint"
			"pre": entry.pre_revision = -1
			"post": entry.post_revision = 3
			"kind": entry.command_kind = "board_command"
			"code": entry.result.code = &"private-uncommitted"
			"first_cell": receipt.first_cell = 1
			"board_revision": receipt.board_revision = 1
			"difficulty": receipt.difficulty_id = "private-other-tier"
			"duplicate":
				var duplicate := entry.duplicate(true)
				duplicate.result.value.receipt.transaction_id = "private-second-command"
				snapshot.command_receipts["private-second-command"] = duplicate
		assert_eq(QUERY.desktop(snapshot, state), UNAVAILABLE, corruption)
