extends RefCounted

const QUERY := preload("res://scripts/application/minesweeper/MinesweeperBoardPresentationQuery.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")

static func expert_board(check: Callable) -> Dictionary:
	var mines: Array[int] = []
	for index in range(1,100): mines.append(index)
	var layout := {"schema_version":1,"width":22,"height":22,"mine_indices":mines,"mine_count":99}
	var first: Dictionary = REDUCER.first_reveal(layout,0)
	if not check.call(first.get("ok",false),"reducer first-Reveal fixture failed"): return {}
	var identity := {"run_id":"evidence-run","branch_id":"evidence-branch","desktop_timeline_generation":0,"causal_day_instance":"evidence-day","app_round_ordinal":1}
	var spec := {"schema_version":1,"board_kind":"desktop","board_token":"evidence-token","board_token_receipt_id":"evidence-receipt",
		"difficulty_id":"expert","width":22,"height":22,"base_mine_count":99,"pressure":0,"penalty_points_today":0,
		"raw_extra_mines":0,"requested_mine_count":99,"capability_ids":["first_cell_safe"],
		"placement_stream_id":"minesweeper_placement_v1","placement_nonce":"evidence-p","placement_nonce_receipt_id":"evidence-pr",
		"debug_stream_id":"minesweeper_debug_v1","debug_nonce":"evidence-d","debug_nonce_receipt_id":"evidence-dr",
		"explosion_stream_id":"minesweeper_explosion_v1","explosion_nonce":"evidence-e","explosion_nonce_receipt_id":"evidence-er",
		"generator_version":"dwm_generator_v1","verifier_version":"visible_deduction_v1"}
	var state := STATE.new()
	var prepared: Dictionary = state.prepare_first_reveal({"transaction_id":"evidence-first","identity":identity,"expected_revision":0,
		"cell_index":0,"spec":spec,"request_fingerprint":"evidence-first"},{"layout":layout,"board":first.value.board},{"checkpoint_id":"evidence-checkpoint"})
	if not check.call(prepared.get("ok",false) and state.commit(prepared.value.candidate).get("ok",false),"fixture state first-Reveal commit failed"): return {}
	var flagged: Dictionary = REDUCER.set_flag(first.value.board,1,true,"evidence-flag")
	if not check.call(flagged.get("ok",false),"fixture Flag reducer failed"): return {}
	var command: Dictionary = state.prepare_board_command({"transaction_id":"evidence-flag","identity":identity,"expected_revision":1,
		"kind":&"set_flag","request_fingerprint":"evidence-flag"},flagged.value.board)
	if not check.call(command.get("ok",false) and state.commit(command.value.candidate).get("ok",false),"fixture Flag state commit failed"): return {}
	var projected: Dictionary = QUERY.desktop(state.capture(),"expert")
	if not check.call(projected.get("ok",false),"fixture public projection failed"): return {}
	return {"board":projected.value,"register":{"difficulty":"expert","rounds":1,"mine_estimate":projected.value.mine_estimate,
		"foresight":null,"no_flag":"lost","custody":false,"difficulty_enabled":[]},
		"assignments":[false,false,false,false,false,false,false,false,false],
		"actions":["reveal","flag","drag","assignments","rules"],"settled":false}
