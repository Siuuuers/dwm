extends "res://addons/gut/test.gd"
## Presentation-facing first-Reveal contract over the real physical owner, Profile
## ledger, reducer and generator. Checkpoint authority remains an injected seam.
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")

var f: RefCounted

func before_each() -> void:
	f = FIXTURE.new()
	assert_true(f.setup("TEST.scene.first_reveal").ok)
	_arm_unfinished_layout()
	assert_true(f.begin().ok)

func _arm_unfinished_layout() -> void:
	var mines: Array = []
	for index in 33: mines.append(index)
	mines.append_array([288, 289, 307])
	f.generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18, "mine_indices": mines, "mine_count": 36})

func after_each() -> void:
	f.dispose()

func _pull() -> Dictionary:
	return f.owner.pull_scene_panel(f.token)

func _reveal(index: int, revision: int = 0) -> Dictionary:
	return f.owner.dispatch_scene_panel_action(f.token, "reveal", index, revision)

func test_unstarted_panel_is_a_fixed_covered_board_without_start_mutation() -> void:
	var view: Dictionary = _pull()
	assert_true(view.ok, str(view))
	if not view.ok: return
	assert_eq(view.value.phase, "never_started")
	assert_eq(view.value.host, "canonical_solo")
	assert_eq(view.value.state, "never_started")
	assert_eq(view.value.actions, ["reveal"])
	assert_eq(view.value.revision, 0)
	assert_eq(view.value.board.width, 18)
	assert_eq(view.value.board.height, 18)
	assert_eq(view.value.board.cells.size(), 324)
	assert_eq(view.value.board.cells[323].actions, ["reveal"])
	assert_eq(f.record(), {})
	assert_true(f.attempt().ok)
	assert_eq(f.attempt().value, {})
	assert_eq(f.authority.checkpoints.size(), 0)

func test_first_reveal_materializes_commits_and_checkpoints_once() -> void:
	var revealed: Dictionary = _reveal(323)
	assert_true(revealed.ok, str(revealed))
	if not revealed.ok: return
	var record: Dictionary = f.record()
	assert_eq(record.phase, "active")
	assert_eq(record.state, "in_progress")
	assert_true(record.board is Dictionary)
	assert_true(record.board.revealed_indices.has(323))
	var attempt: Dictionary = f.attempt().value
	assert_eq(attempt.materialization_receipt.first_cell_index, 323)
	assert_eq(attempt.record, record)
	assert_eq(attempt.revision, 1)
	assert_eq(f.authority.checkpoints.size(), 1)

func test_duplicate_first_reveal_reuses_exact_profile_result() -> void:
	assert_true(_reveal(323).ok)
	var record: Dictionary = f.record().duplicate(true)
	var attempt: Dictionary = f.attempt().value.duplicate(true)
	var checkpoints: int = f.authority.checkpoints.size()
	var duplicate: Dictionary = _reveal(323, 0)
	assert_true(duplicate.ok, str(duplicate))
	assert_eq(f.record(), record)
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.authority.checkpoints.size(), checkpoints)

func test_non_reveal_bad_cell_and_stale_revision_refuse_before_start() -> void:
	assert_false(f.owner.dispatch_scene_panel_action(f.token, "flag", 323, 0).ok)
	assert_false(_reveal(-1).ok)
	assert_false(_reveal(324).ok)
	assert_false(_reveal(323, 1).ok)
	assert_eq(f.record(), {})
	assert_eq(f.attempt().value, {})
	assert_eq(f.authority.checkpoints.size(), 0)

func test_debug_first_reveal_checkpoints_exact_initial_frontier_and_survives_owner_restart() -> void:
	f.dispose()
	f = FIXTURE.new()
	f.state.inventory = {"debug_key": 1}
	assert_true(f.setup("TEST.scene.first_reveal.debug").ok)
	assert_true(f.begin().ok)
	var revealed: Dictionary = _reveal(323)
	assert_true(revealed.ok, str(revealed))
	if not revealed.ok: return
	var record: Dictionary = f.record().duplicate(true)
	var attempt: Dictionary = f.attempt().value.duplicate(true)
	assert_eq(record.phase, "preparing")
	assert_null(record.board)
	assert_eq(record.envelope.preparation.forced_cell, 323)
	assert_eq(record.envelope.preparation.slice_sequence, 0)
	assert_eq(attempt.record, record)
	assert_eq(attempt.revision, 1)
	assert_eq(f.authority.checkpoints.size(), 1)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(_pull().value.phase, "preparing")
	assert_eq(f.record(), record)
	var duplicate: Dictionary = _reveal(323, 0)
	assert_true(duplicate.ok, str(duplicate))
	assert_eq(f.record(), record)
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.authority.checkpoints.size(), 1)

func test_profile_refusal_leaves_first_reveal_absent_and_retry_commits_once() -> void:
	f.storage.refuse = true
	var refused: Dictionary = _reveal(323)
	assert_false(refused.ok, str(refused))
	assert_eq(f.record(), {})
	assert_eq(f.attempt().value, {})
	assert_eq(f.authority.checkpoints.size(), 0)
	f.storage.refuse = false
	var retried: Dictionary = _reveal(323)
	assert_true(retried.ok, str(retried))
	if not retried.ok: return
	assert_eq(f.attempt().value.revision, 1)
	assert_eq(f.attempt().value.materialization_receipt.first_cell_index, 323)
	assert_eq(f.attempt().value.record, f.record())
	assert_eq(f.authority.checkpoints.size(), 1)

func test_profile_ahead_first_reveal_recovers_exact_attempt_after_cold_owner_retry() -> void:
	f.authority.reject_checkpoint = true
	var refused: Dictionary = _reveal(323)
	assert_false(refused.ok, str(refused))
	var retained: Dictionary = f.attempt().value.duplicate(true)
	assert_eq(retained.revision, 1)
	assert_eq(retained.materialization_receipt.first_cell_index, 323)
	assert_eq(f.authority.checkpoints.size(), 0)
	f.state.route_context = {}
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_eq(_pull().value.phase, "checkpoint_retry")
	f.authority.reject_checkpoint = false
	var retried: Dictionary = f.action("retry")
	assert_true(retried.ok, str(retried))
	assert_eq(f.attempt().value, retained)
	assert_eq(f.record(), retained.record)
	assert_eq(f.authority.checkpoints.size(), 1)

func test_immediately_winning_first_reveal_duplicate_is_write_free() -> void:
	var mines: Array = []
	for index in 36: mines.append(index)
	f.generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18, "mine_indices": mines, "mine_count": 36})
	var revealed: Dictionary = _reveal(323)
	assert_true(revealed.ok, str(revealed))
	if not revealed.ok: return
	var record: Dictionary = f.record().duplicate(true)
	var attempt: Dictionary = f.attempt().value.duplicate(true)
	assert_eq(record.phase, "terminal")
	assert_eq(record.state, "won")
	assert_eq(f.authority.checkpoints.size(), 1)
	var duplicate: Dictionary = _reveal(323, 0)
	assert_true(duplicate.ok, str(duplicate))
	assert_eq(f.record(), record)
	assert_eq(f.attempt().value, attempt)
	assert_eq(f.authority.checkpoints.size(), 1)

func test_fresh_profile_entry_refuses_a_prebuilt_second_action() -> void:
	assert_true(_reveal(323).ok)
	var attempt: Dictionary = f.attempt().value.duplicate(true)
	var record: Dictionary = attempt.record.duplicate(true)
	var covered := -1
	for index in int(record.board.width) * int(record.board.height):
		if not record.board.revealed_indices.has(index) and not record.board.flagged_indices.has(index):
			covered = index
			break
	assert_gte(covered, 0)
	if covered < 0: return
	var marked: Dictionary = REDUCER.set_flag(record.board, covered, true, "extra.after-first-reveal")
	assert_true(marked.ok, str(marked))
	if not marked.ok: return
	var plain: Dictionary = ENVELOPE.plain_frontier(marked.value.board)
	assert_true(plain.ok, str(plain))
	if not plain.ok: return
	record.board = plain.value
	assert_true(LEDGER.validate_record(record))
	var rejected: Dictionary = LEDGER.prepare_update({}, str(attempt.run_id), str(attempt.slot_id),
		str(attempt.branch_id), record, 0, int(attempt.materialization_receipt.first_cell_index), {}, {"mode": "fresh"})
	assert_false(rejected.ok, str(rejected))
	assert_eq(rejected.get("code"), &"dating_fresh_entry_required")

func test_debug_certification_applies_retained_reveal_and_recovers_checkpoint_refusal() -> void:
	f.dispose()
	f = FIXTURE.new()
	f.state.inventory = {"debug_key": 1}
	assert_true(f.setup("TEST.scene.first_reveal.certification").ok)
	assert_true(f.begin().ok)
	var started: Dictionary = _reveal(323)
	assert_true(started.ok, str(started))
	if not started.ok: return
	var slices := 0
	while f.record().phase == "preparing" and slices < 4096:
		# Every slice is Profile-durable before the intentionally refused Run write.
		var saved_run: Dictionary = f.state.route_context.duplicate(true)
		f.authority.reject_checkpoint = true
		var prepared: Dictionary = f.action("prepare")
		assert_false(prepared.ok)
		var retained: Dictionary = f.attempt().value.duplicate(true)
		assert_eq(retained.record.envelope.forced_cell, 323)
		f.state.route_context = saved_run.duplicate(true)
		assert_true(f.recreate_owner().ok)
		assert_true(f.begin().ok)
		assert_eq(_pull().value.phase, "checkpoint_retry")
		f.authority.reject_checkpoint = false
		var retried: Dictionary = f.action("retry")
		assert_true(retried.ok, str(retried))
		if not retried.ok: return
		assert_eq(f.attempt().value, retained)
		assert_eq(f.record(), retained.record)
		slices += 1
	assert_lt(slices, 4096)
	var record: Dictionary = f.record()
	assert_true(record.board is Dictionary)
	if not record.board is Dictionary: return
	assert_true(record.board.revealed_indices.has(323))
	assert_eq(f.attempt().value.materialization_receipt.first_cell_index, 323)
	assert_null(record.envelope.preparation)
	assert_eq(record.envelope.forced_cell, 323)
	assert_eq(f.state.effects, 0)
