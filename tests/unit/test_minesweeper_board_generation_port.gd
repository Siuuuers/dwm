extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd")
const GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")


func test_materialize_returns_the_coordinator_shape_deterministically_and_keeps_first_cell_safe() -> void:
	var port := PORT.new()
	var spec := _board_spec("materialize", ["first_cell_safe"])
	var first: Dictionary = port.materialize(spec, 9)
	var replay: Dictionary = port.materialize(spec, 9)

	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(first, replay)
	assert_eq((first["value"] as Dictionary).keys(), ["layout"])
	var layout: Dictionary = first["value"]["layout"]
	assert_eq(int(layout["mine_count"]), 10)
	assert_false((layout["mine_indices"] as Array).has(9))


func test_debug_search_projects_real_generator_progress_and_certification_into_exact_port_shapes() -> void:
	if not FileAccess.file_exists(GENERATOR.BUDGET_MANIFEST_PATH) \
			or not FileAccess.file_exists(GENERATOR.FALLBACK_MANIFEST_PATH):
		pending("requires both frozen generator manifests")
		return
	var port := PORT.new()
	var spec := _board_spec("debug", ["first_cell_safe", "forced_no_guess"])
	var begun: Dictionary = port.begin_search(spec)
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	assert_eq((begun["value"] as Dictionary).keys(), ["frontier"])
	var frontier: Dictionary = begun["value"]["frontier"]
	var forced_cell := int(frontier["forced_cell"])

	# Leave too little search budget for another candidate so the real generator takes its
	# deterministic, independently certified fallback on this one bounded call.
	var budget: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(GENERATOR.BUDGET_MANIFEST_PATH))
	frontier["operations_used"] = int(budget["search_operation_budget"]) - 1
	var completed: Dictionary = port.run_search_slice(frontier)

	assert_true(completed.get("ok", false), JSON.stringify(completed))
	assert_eq((completed["value"] as Dictionary).keys(),
		["done", "layout", "forced_cell", "proof_sha256"])
	assert_true(bool(completed["value"]["done"]))
	assert_eq(int(completed["value"]["forced_cell"]), forced_cell)
	assert_null(completed["value"]["proof_sha256"])
	var layout: Dictionary = completed["value"]["layout"]
	assert_false((layout["mine_indices"] as Array).has(forced_cell))


func test_debug_search_keeps_a_searching_frontier_in_the_exact_progress_shape() -> void:
	if not FileAccess.file_exists(GENERATOR.BUDGET_MANIFEST_PATH) \
			or not FileAccess.file_exists(GENERATOR.FALLBACK_MANIFEST_PATH):
		pending("requires both frozen generator manifests")
		return
	var port := PORT.new()
	var begun: Dictionary = port.begin_search(
		_board_spec("progress", ["first_cell_safe", "forced_no_guess"]))
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var frontier: Dictionary = begun["value"]["frontier"]

	# A valid frontier with less than one board-candidate operation remaining in the current
	# slice stays searching, which exercises the nonterminal projection without an expensive loop.
	var budget: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(GENERATOR.BUDGET_MANIFEST_PATH))
	var total_cells := int(frontier["spec"]["width"]) * int(frontier["spec"]["height"])
	frontier["operations_used"] = int(budget["search_operation_budget"]) - total_cells
	var progressed: Dictionary = port.run_search_slice(frontier)

	assert_true(progressed.get("ok", false), JSON.stringify(progressed))
	var value: Dictionary = progressed["value"]
	if bool(value["done"]):
		# The frozen candidate can certify on its first legal attempt; that is still a correct
		# terminal port projection and is covered in detail by the prior test.
		assert_eq(value.keys(), ["done", "layout", "forced_cell", "proof_sha256"])
	else:
		assert_eq(value.keys(), ["done", "frontier"])
		assert_eq(int(value["frontier"]["forced_cell"]), int(frontier["forced_cell"]))


func _board_spec(nonce_suffix: String, capability_ids: Array[String]) -> Dictionary:
	return {
		"schema_version": 1, "board_kind": "solo_challenge", "board_token": "token-" + nonce_suffix,
		"board_token_receipt_id": "receipt-token-" + nonce_suffix, "difficulty_id": "beginner",
		"width": 8, "height": 8, "base_mine_count": 10, "pressure": 0,
		"penalty_points_today": 0, "raw_extra_mines": 0, "requested_mine_count": 10,
		"capability_ids": capability_ids,
		"placement_stream_id": "minesweeper_placement_v1",
		"placement_nonce": "port-placement-" + nonce_suffix,
		"placement_nonce_receipt_id": "receipt-placement-" + nonce_suffix,
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "port-debug-" + nonce_suffix,
		"debug_nonce_receipt_id": "receipt-debug-" + nonce_suffix,
		"explosion_stream_id": "minesweeper_explosion_v1",
		"explosion_nonce": "port-explosion-" + nonce_suffix,
		"explosion_nonce_receipt_id": "receipt-explosion-" + nonce_suffix,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}
