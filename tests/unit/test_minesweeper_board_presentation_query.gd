extends "res://addons/gut/test.gd"

const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const CELL := preload("res://scripts/ui/minesweeper/MinesweeperCell.gd")
const IDENTITY := {"run_id":"private-run", "branch_id":"private-branch", "desktop_timeline_generation":0,
	"causal_day_instance":"private-day", "app_round_ordinal":1}

func _layout(mines: Array = [1]) -> Dictionary:
	return {"schema_version":1, "width":3, "height":3, "mine_indices":mines, "mine_count":mines.size()}

func _spec(mines: int = 1) -> Dictionary:
	return {"schema_version":1, "board_kind":"desktop", "board_token":"private-token", "board_token_receipt_id":"private-receipt",
		"difficulty_id":"beginner", "width":3, "height":3, "base_mine_count":mines, "pressure":0, "penalty_points_today":0,
		"raw_extra_mines":0, "requested_mine_count":mines, "capability_ids":["first_cell_safe"],
		"placement_stream_id":"minesweeper_placement_v1", "placement_nonce":"private-p", "placement_nonce_receipt_id":"private-pr",
		"debug_stream_id":"minesweeper_debug_v1", "debug_nonce":"private-d", "debug_nonce_receipt_id":"private-dr",
		"explosion_stream_id":"minesweeper_explosion_v1", "explosion_nonce":"private-e", "explosion_nonce_receipt_id":"private-er",
		"generator_version":"dwm_generator_v1", "verifier_version":"visible_deduction_v1"}

func _snapshot(mines: Array = [1]) -> Dictionary:
	var state := STATE.new()
	var layout := _layout(mines)
	var board: Dictionary = REDUCER.first_reveal(layout,0).value.board
	var prepared := state.prepare_first_reveal({"transaction_id":"private-command", "identity":IDENTITY,
		"expected_revision":0, "cell_index":0, "spec":_spec(mines.size()), "request_fingerprint":"private-fingerprint"},
		{"layout":layout, "board":board}, {"checkpoint_id":"private-checkpoint"})
	assert_true(prepared.ok, str(prepared))
	assert_true(state.commit(prepared.value.candidate).ok)
	return state.capture()

func _prepared(preparing: bool = false) -> Dictionary:
	var state := STATE.new()
	var begun := state.prepare_debug_candidate({"transaction_id":"prepare", "identity":IDENTITY, "expected_revision":0,
		"spec":_spec(), "request_fingerprint":"prepare-fingerprint"}, {"frontier":{"private_cursor":77}})
	assert_true(begun.ok, str(begun))
	assert_true(state.commit(begun.value.candidate).ok)
	if not preparing:
		var certified := state.prepare_debug_slice({"transaction_id":"certify", "identity":IDENTITY, "expected_revision":1,
			"request_fingerprint":"certify-fingerprint"}, {"done":true, "layout":_layout(), "forced_cell":0, "proof_sha256":"private-proof"})
		assert_true(certified.ok, str(certified))
		assert_true(state.commit(certified.value.candidate).ok)
	return state.capture()

func test_unpaid_shell_uses_catalog_without_estimated_or_generated_mines() -> void:
	var state := STATE.new()
	for difficulty: String in ["beginner", "intermediate", "expert"]:
		var result: Dictionary = QUERY.desktop(state.capture(),difficulty,true)
		assert_true(result.ok)
		assert_eq(result.value.width,{"beginner":8,"intermediate":16,"expert":22}[difficulty])
		assert_null(result.value.mine_estimate)
		for cell: Dictionary in result.value.cells:
			assert_eq(cell.mark,"none")
			assert_eq(cell.number,0)
	var inert := QUERY.desktop(state.capture(),"beginner")
	assert_false(inert.value.cells[0].pressable)
	assert_eq(state.capture().revision,0,"Projection never creates a shell or consumes a round.")

func test_retained_dimensions_and_top_level_revision_are_literal() -> void:
	var snapshot := _snapshot()
	var result: Dictionary = QUERY.desktop(snapshot,"expert")
	assert_true(result.ok)
	assert_eq(result.value.width,3,"Selected tier cannot reshape a retained board.")
	assert_eq(result.value.revision,1)
	assert_eq(snapshot.board.board.revision,0,"The command token uses the state revision, not the nested reducer revision.")
	assert_eq(result.value.cells[0].number,1)
	assert_true(result.value.cells[0].inspectable)
	assert_false(result.value.cells[0].pressable,"Visible number has no matching adjacent flag yet.")

func test_changing_hidden_mines_without_changing_public_facts_cannot_change_projection() -> void:
	var horizontal := _snapshot([1])
	var vertical := _snapshot([3])
	assert_ne(horizontal.board.board.mine_indices,vertical.board.board.mine_indices)
	assert_eq(QUERY.desktop(horizontal,"beginner"),QUERY.desktop(vertical,"beginner"))

func test_estimate_is_signed_and_chord_depends_only_on_public_flags() -> void:
	var snapshot := _snapshot()
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board,2,true,"flag-a").value.board
	var one: Dictionary = QUERY.desktop(snapshot,"beginner").value
	assert_eq(one.mine_estimate,0)
	assert_false(one.cells[0].pressable,"A nonadjacent flag cannot authorize Chord.")
	snapshot.board.board = REDUCER.set_flag(snapshot.board.board,3,true,"flag-b").value.board
	var two: Dictionary = QUERY.desktop(snapshot,"beginner").value
	assert_eq(two.mine_estimate,-1,"Flags are not clamped to the mine count.")
	assert_true(two.cells[0].pressable,"Even an incorrect adjacent flag qualifies by visible count.")
	assert_eq(two.cells[3].mark,"flag","Incorrect flag identity stays hidden before terminal.")
	assert_true(two.cells[3].pressable,"Direct Unflag remains legal.")

func test_blank_is_inspectable_without_a_press_state() -> void:
	var snapshot := _snapshot()
	snapshot.board.board = REDUCER.reveal(snapshot.board.board,6,"open-blank").value.board
	var result: Dictionary = QUERY.desktop(snapshot,"beginner")
	assert_true(result.ok)
	assert_eq(result.value.cells[6].number,0)
	assert_eq(result.value.cells[6].face,"revealed")
	assert_false(result.value.cells[6].pressable)
	assert_eq(result.value.cells[6].inspectable,not snapshot.board.board.terminal)

func test_preparation_publishes_only_the_bracket_locus_after_certification() -> void:
	var preparing: Dictionary = QUERY.desktop(_prepared(true),"beginner").value
	assert_true(preparing.custody)
	assert_null(preparing.mine_estimate)
	for cell: Dictionary in preparing.cells:
		assert_false(cell.bracketed)
		assert_false(cell.inspectable)
	var certified: Dictionary = QUERY.desktop(_prepared(),"beginner").value
	assert_eq(certified.mine_estimate,1)
	for cell: Dictionary in certified.cells:
		assert_eq(cell.bracketed,cell.index == 0)
		assert_eq(cell.pressable,cell.index == 0)
		assert_eq(cell.mark,"none")
		assert_eq(cell.number,0)

func test_suspended_custody_preserves_content_and_removes_all_contact() -> void:
	var snapshot := _snapshot()
	snapshot.phase = "ACTIVE_SUSPENDED"
	var result: Dictionary = QUERY.desktop(snapshot,"beginner").value
	assert_true(result.custody)
	assert_eq(result.cells[0].number,1)
	for cell: Dictionary in result.cells:
		assert_false(cell.inspectable)
		assert_false(cell.pressable)

func test_terminal_classification_is_public_before_durable_inspection_is_available() -> void:
	var snapshot := _snapshot([1,3])
	var board: Dictionary = snapshot.board.board
	board = REDUCER.set_flag(board,1,true,"flag-mine").value.board
	board = REDUCER.set_flag(board,2,true,"flag-safe").value.board
	board = REDUCER.reveal(board,3,"explode").value.board
	snapshot.board.board = board
	var result: Dictionary = QUERY.desktop(snapshot,"beginner").value
	assert_true(result.terminal)
	assert_true(result.custody,"ACTIVE_VISIBLE terminal is not proof of complete_round durability.")
	assert_eq(result.cells[1].mark,"correct_flag")
	assert_eq(result.cells[1].face,"covered")
	assert_eq(result.cells[2].mark,"incorrect_flag")
	assert_eq(result.cells[3].mark,"exploded")
	assert_eq(result.cells[3].face,"revealed")
	assert_eq(result.cells[3].number,0)
	for cell: Dictionary in result.cells:
		assert_false(cell.inspectable)
		assert_false(cell.pressable)

func test_all_projected_cells_are_accepted_by_the_inert_renderer() -> void:
	var cell: Control = CELL.new()
	add_child_autofree(cell)
	assert_true(cell.configure())
	for snapshot: Dictionary in [_snapshot(), _prepared(), _prepared(true), STATE.new().capture()]:
		var projected := QUERY.desktop(snapshot,"beginner",true)
		assert_true(projected.ok)
		for public: Dictionary in projected.value.cells: assert_true(cell.present(public),str(public))

func test_projection_is_detached_and_has_no_private_metadata() -> void:
	var snapshot := _snapshot()
	var result: Dictionary = QUERY.desktop(snapshot,"beginner")
	assert_eq(result.value.size(),7)
	assert_false(JSON.stringify(result).contains("private"))
	for cell: Dictionary in result.value.cells: assert_eq(cell.size(),8)
	result.value.cells[0].number = 8
	assert_eq(QUERY.desktop(snapshot,"beginner").value.cells[0].number,1)

func test_corrupt_deep_owner_data_refuses_without_echoing_private_diagnostics() -> void:
	var corrupt_board := _snapshot()
	corrupt_board.board.board.adjacency_counts[0] = 7
	var corrupt_wrapper := _snapshot()
	corrupt_wrapper.board.private_extra = "private-leak"
	var corrupt_candidate := _prepared()
	corrupt_candidate.candidate.forced_cell = 1
	var corrupt_frontier := _prepared(true)
	corrupt_frontier.candidate.frontier = "private-invalid"
	for snapshot: Dictionary in [corrupt_board,corrupt_wrapper,corrupt_candidate,corrupt_frontier,{"private-extra":true}]:
		var result: Dictionary = QUERY.desktop(snapshot,"beginner")
		assert_eq(result,{"ok":false,"code":&"invalid_minesweeper_presentation_source"})
	assert_false(QUERY.desktop(STATE.new().capture(),"unknown").ok)
