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
