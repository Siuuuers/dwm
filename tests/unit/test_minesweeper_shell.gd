extends GutTest

const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const LAYOUT := {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [0], "mine_count": 1}

func _empty() -> Dictionary:
	return {"flagged_indices": [], "actions": []}

func test_default_first_reveal_remains_byte_equal_to_explicit_empty_shell() -> void:
	assert_eq(REDUCER.first_reveal(LAYOUT, 8), REDUCER.first_reveal(LAYOUT, 8, _empty()))

func test_shell_flags_are_detached_ordered_and_exact_duplicate_is_a_noop() -> void:
	var source := _empty()
	var first: Dictionary = REDUCER.set_shell_flag(source, 3, 3, 1, true, "flag")
	assert_true(first.ok)
	assert_eq(source, _empty())
	assert_eq(first.value.shell.flagged_indices, [1])
	assert_eq(first.value.shell.actions.size(), 1)
	assert_eq(REDUCER.set_shell_flag(first.value.shell, 3, 3, 1, true, "flag"), first)
	assert_false(REDUCER.set_shell_flag(first.value.shell, 3, 3, 1, false, "flag").ok)
	var undone: Dictionary = REDUCER.set_shell_flag(first.value.shell, 3, 3, 1, false, "unflag")
	assert_eq(undone.value.shell.flagged_indices, [])
	assert_eq(undone.value.shell.actions.size(), 2)
	assert_eq(first.value.shell.flagged_indices, [1])

func test_flagged_first_cell_is_refused_and_flags_do_not_change_mine_placement() -> void:
	var shell: Dictionary = REDUCER.set_shell_flag(_empty(), 3, 3, 8, true, "flag").value.shell
	assert_eq(REDUCER.first_reveal(LAYOUT, 8, shell).code, &"cell_is_flagged")
	var reveal: Dictionary = REDUCER.first_reveal(LAYOUT, 4, shell)
	assert_true(reveal.ok, str(reveal))
	assert_eq(reveal.value.board.mine_indices, [0])
	assert_eq(reveal.value.board.flagged_indices, [8])
	assert_eq(reveal.value.board.actions, shell.actions)

func test_first_flood_respects_flags_and_preserves_prior_unflag_history() -> void:
	var shell: Dictionary = REDUCER.set_shell_flag(_empty(), 3, 3, 1, true, "flag-a").value.shell
	shell = REDUCER.set_shell_flag(shell, 3, 3, 6, true, "flag-b").value.shell
	shell = REDUCER.set_shell_flag(shell, 3, 3, 6, false, "unflag-b").value.shell
	var reveal: Dictionary = REDUCER.first_reveal(LAYOUT, 8, shell)
	assert_true(reveal.ok, str(reveal))
	var board: Dictionary = reveal.value.board
	assert_false(board.revealed_indices.has(1))
	assert_true(board.revealed_indices.has(6))
	assert_false(board.terminal)
	assert_eq(board.revision, 3)
	assert_eq(board.actions, shell.actions)
	assert_true(SCHEMA.validate_board(board).ok)
	board = REDUCER.set_flag(board, 1, false, "unflag-a").value.board
	board = REDUCER.reveal(board, 1, "last").value.board
	assert_true(board.terminal)
	assert_eq(board.actions.size(), 5)
	assert_eq(board.actions[0].transaction_id, "flag-a")

func test_shell_roundtrip_normalizes_integral_json_numbers_without_losing_history() -> void:
	var shell: Dictionary = REDUCER.set_shell_flag(_empty(), 3, 3, 0, true, "flag").value.shell
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(shell))
	var validated: Dictionary = REDUCER.validate_shell(parsed, 3, 3)
	assert_true(validated.ok, str(validated))
	assert_eq(validated.value.shell, shell)
	assert_true(validated.value.shell.actions[0].cell_index is int)

func test_shell_rejects_forged_marks_revision_unknown_action_and_out_of_range_cells() -> void:
	var good: Dictionary = REDUCER.set_shell_flag(_empty(), 3, 3, 0, true, "flag").value.shell
	for corruption: String in ["marks", "revision", "kind", "fraction", "outside", "extra"]:
		var bad := good.duplicate(true)
		match corruption:
			"marks": bad.flagged_indices = [1]
			"revision": bad.actions[0].revision = 2
			"kind": bad.actions[0].kind = "reveal"
			"fraction": bad.actions[0].cell_index = 0.5
			"outside": bad.actions[0].cell_index = 9
			"extra": bad["mine_indices"] = [0]
		assert_false(REDUCER.validate_shell(bad, 3, 3).ok, corruption)


func test_layout_may_reduce_only_extras_without_rewriting_requested_spec() -> void:
	var source := preload("res://tests/support/FakeDesktopBoardStatePort.gd").new()
	var spec: Dictionary = source._fake_spec_for("beginner", "layout")
	spec["requested_mine_count"] = 3
	spec["pressure"] = 6
	spec["raw_extra_mines"] = 2
	var frozen := spec.duplicate(true)
	assert_true(SCHEMA.validate_layout(LAYOUT, spec).ok)
	var two := LAYOUT.duplicate(true)
	two["mine_indices"] = [0, 1]
	two["mine_count"] = 2
	assert_true(SCHEMA.validate_layout(two, spec).ok)
	var below := LAYOUT.duplicate(true)
	below["mine_indices"] = []
	below["mine_count"] = 0
	assert_false(SCHEMA.validate_layout(below, spec).ok)
	var above := LAYOUT.duplicate(true)
	above["mine_indices"] = [0, 1, 2, 3]
	above["mine_count"] = 4
	assert_false(SCHEMA.validate_layout(above, spec).ok)
	assert_eq(spec, frozen)
