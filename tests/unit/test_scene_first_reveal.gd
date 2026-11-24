extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")

var f: RefCounted

func before_each() -> void:
	f = FIXTURE.new()
	assert_true(f.setup("TEST.scene.first_reveal").ok)
	assert_true(f.begin().ok)

func after_each() -> void:
	f.dispose()

func _reveal(cell: int, revision: int = 0) -> Dictionary:
	return f.owner.dispatch_scene_panel_action(f.token, "reveal", cell, revision)

func test_preview_and_unavailable_moves_leave_the_board_unstarted() -> void:
	var preview: Dictionary = f.owner.pull_scene_panel(f.token)
	assert_eq(preview.value.board.cells[323].actions, ["reveal"])
	assert_false(f.owner.dispatch_scene_panel_action(f.token, "flag", 323, 0).ok)
	assert_false(_reveal(-1).ok)
	assert_false(_reveal(324).ok)
	assert_false(_reveal(323, 1).ok)
	assert_eq(f.record(), {})
	assert_eq(f.authority.checkpoints, [])

func test_first_reveal_publishes_the_clicked_cell_once() -> void:
	var mines := range(33)
	mines.append_array([288, 289, 307])
	f.generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18, "mine_indices": mines, "mine_count": 36})
	assert_true(_reveal(323).ok)
	var board: Dictionary = f.record()
	assert_eq(board.phase, "active")
	assert_has(board.board.revealed_indices, 323)
	assert_true(_reveal(323).ok)
	assert_eq(f.authority.checkpoints, [board])
	assert_eq(f.record(), board)

func test_first_reveal_can_win_without_publishing_twice() -> void:
	assert_true(_reveal(323).ok)
	var finished: Dictionary = f.record()
	assert_eq(finished.state, "won")
	assert_true(_reveal(323).ok)
	assert_eq(f.authority.checkpoints, [finished])
	assert_eq(f.record(), finished)

func test_refused_checkpoint_retries_the_same_board() -> void:
	f.authority.reject_checkpoint = true
	assert_false(_reveal(323).ok)
	var pending: Dictionary = f.record()
	assert_eq(f.authority.checkpoints, [])
	f.authority.reject_checkpoint = false
	assert_true(f.action("retry").ok)
	assert_has(pending.board.revealed_indices, 323)
	assert_eq(f.authority.checkpoints, [pending])

func test_debug_preparation_resumes_at_the_clicked_cell() -> void:
	f.state.inventory = {"debug_key": 1}
	assert_true(_reveal(323).ok)
	var preparing: Dictionary = f.record()
	assert_eq(preparing.phase, "preparing")
	assert_eq(preparing.envelope.preparation.forced_cell, 323)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_true(_reveal(323).ok)
	assert_eq(f.authority.checkpoints, [preparing])
	assert_eq(f.record(), preparing)
	for slice in 4096:
		if f.record().phase != "preparing": break
		var prepared: Dictionary = f.action("prepare")
		if not prepared.ok:
			fail_test(str(prepared.code))
			return
	var board: Dictionary = f.record()
	assert_has(board.board.revealed_indices, 323)
	assert_eq(f.authority.checkpoints.back(), board)

func test_restored_prepared_debug_flags_clear_before_first_reveal() -> void:
	f.state.inventory = {"debug_key": 1, "lucky_charm": 1}
	var profile: Dictionary = f.authority.bundle.board_profiles[0]
	profile.width = 8
	profile.height = 8
	profile.base_mine_count = 10
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	for slice in 4096:
		if f.record().phase != "preparing": break
		var prepared: Dictionary = f.action("prepare")
		if not prepared.ok:
			fail_test(str(prepared))
			return
	var saved: Dictionary = f.record()
	assert_eq(saved.phase, "ready")
	if saved.phase != "ready": return
	var forced: int = saved.envelope.forced_cell
	var previous := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd").set_shell_flag(
		saved.envelope.shell, 8, 8, forced, true, "previous-mark")
	assert_true(previous.ok)
	saved.envelope.shell = previous.value.shell
	assert_true(f.state.store_dating_challenge_state(saved).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	var view: Dictionary = f.owner.pull_scene_panel(f.token).value
	assert_eq(view.board.cells[forced].mark, "none")
	assert_eq(view.board.cells[forced].actions, ["reveal"])
	assert_eq(f.record(), saved)
	assert_true(_reveal(forced, view.revision).ok)
	var active: Dictionary = f.record()
	assert_has(active.board.revealed_indices, forced)
	assert_eq(active.board.flagged_indices, [])
	assert_eq(active.board.actions[0], previous.value.shell.actions[0])
	assert_eq(active.board.adjacency_counts[forced], 0)
	assert_true(preload("res://scripts/application/run/DatingChallengeEnvelope.gd").advances(saved, active))
