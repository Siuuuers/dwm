extends GutTest

const PORT := preload("res://scripts/application/minesweeper/MinesweeperPresentationPort.gd")
const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE_PORT := preload("res://tests/support/FakeDesktopBoardStatePort.gd")
const CHECKPOINT_PORT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION_PORT := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

var coordinator
var issuer
var root_store
var port
var state_port
var generation


func before_each() -> void:
	root_store = ROOT_STORE.new("42".repeat(32), 1)
	issuer = ISSUER.new()
	issuer.configure(root_store)
	state_port = STATE_PORT.new()
	state_port.identity_issuer = issuer
	generation = GENERATION_PORT.new()
	generation.arm_materialize({"schema_version": 1, "width": 3, "height": 3,
		"mine_indices": [1], "mine_count": 1})
	coordinator = COORDINATOR.new()
	assert_true(coordinator.configure(state_port, CHECKPOINT_PORT.new(), generation, issuer).ok)
	port = PORT.new()
	assert_true(port.configure(coordinator, issuer).ok)


func test_pull_exposes_only_public_projection_and_pre_reveal_has_no_flag_action() -> void:
	var pulled: Dictionary = port.pull("beginner")
	assert_true(pulled.ok)
	assert_eq(pulled.keys(), ["ok", "code", "value"])
	assert_eq(pulled.value.keys(), ["width", "height", "revision", "mine_estimate", "terminal", "custody", "cells"])
	assert_eq(pulled.value.cells[0].actions, ["reveal"])
	assert_false(pulled.value.has("identity"))
	assert_false((pulled.value.cells[0].actions as Array).has("flag"))


func test_valid_first_reveal_and_active_flag_use_real_coordinator_and_issuer() -> void:
	var first: Dictionary = port.pull("beginner")
	var after_reveal: Dictionary = port.dispatch("reveal", 0, first.value.revision)
	assert_true(after_reveal.ok, JSON.stringify(after_reveal))
	assert_eq(after_reveal.value.width, 3)
	assert_eq(after_reveal.value.revision, 1)
	assert_eq(after_reveal.value.cells[2].actions, ["reveal", "flag"])
	var after_flag: Dictionary = port.dispatch("flag", 2, after_reveal.value.revision)
	assert_true(after_flag.ok, JSON.stringify(after_flag))
	assert_eq(after_flag.value.revision, 2)
	assert_eq(after_flag.value.cells[2].mark, "flag")
	assert_eq(after_flag.value.cells[2].actions, ["unflag"])


func test_real_grid_routes_keyboard_and_pointer_actions_through_port_and_coordinator() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	add_child_autofree(viewport)
	var grid: Control = GRID.new()
	viewport.add_child(grid)
	assert_true(grid.configure())
	var initial: Dictionary = port.pull("beginner")
	assert_true(initial.ok, JSON.stringify(initial))
	assert_true(grid.present(initial.value))
	assert_eq(grid.focused_index, 0)

	var dispatched: Array[Dictionary] = []
	grid.cell_action_requested.connect(func(action: StringName, index: int, revision: int) -> void:
		var result: Dictionary = port.dispatch(String(action),index,revision)
		dispatched.append(result)
		if result.get("ok",false): assert_true(grid.present(result.value))
	)
	grid.grab_focus()
	await get_tree().process_frame
	assert_same(viewport.gui_get_focus_owner(),grid)

	var enter: InputEventKey = InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	viewport.push_input(enter,true)
	await get_tree().process_frame
	assert_eq(dispatched.size(), 1)
	if dispatched.size() != 1: return
	assert_true(dispatched[0].ok, JSON.stringify(dispatched[0]))
	assert_eq(grid.projection.revision, 1)
	_assert_public_grid_projection(grid.projection)
	var enter_release: InputEventKey = InputEventKey.new()
	enter_release.physical_keycode = KEY_ENTER
	enter_release.keycode = KEY_ENTER
	enter_release.pressed = false
	viewport.push_input(enter_release,true)
	await get_tree().process_frame

	var cell_two_center := Vector2(122,26)
	var right_down: InputEventMouseButton = InputEventMouseButton.new()
	right_down.button_index = MOUSE_BUTTON_RIGHT
	right_down.position = cell_two_center
	right_down.pressed = true
	viewport.push_input(right_down,true)
	await get_tree().process_frame
	assert_eq(grid.get("_held_index"), 2)
	assert_eq(grid.get("_held_button"), MOUSE_BUTTON_RIGHT)
	var right_up: InputEventMouseButton = InputEventMouseButton.new()
	right_up.button_index = MOUSE_BUTTON_RIGHT
	right_up.position = cell_two_center
	right_up.pressed = false
	viewport.push_input(right_up,true)
	await get_tree().process_frame
	assert_eq(dispatched.size(), 2)
	if dispatched.size() != 2: return
	assert_true(dispatched[1].ok, JSON.stringify(dispatched[1]))
	assert_eq(grid.projection.revision, 2)
	assert_eq(grid.projection.cells[2].mark, "flag")
	_assert_public_grid_projection(grid.projection)
	var owner_board: Dictionary = coordinator.get_state().value.board.board
	assert_true((owner_board.flagged_indices as Array).has(2))


func test_unconfigured_invalid_and_stale_actions_allocate_nothing() -> void:
	var unconfigured := PORT.new()
	assert_eq(unconfigured.dispatch("reveal", 0, 0).code, &"minesweeper_presentation_unavailable")
	var pulled: Dictionary = port.pull("beginner")
	var before: int = root_store.next_counter
	assert_eq(port.dispatch("flag", 0, pulled.value.revision).code, &"minesweeper_action_not_available")
	assert_eq(port.dispatch("reveal", -1, pulled.value.revision).code, &"minesweeper_action_not_available")
	assert_eq(port.dispatch("reveal", 0, pulled.value.revision + 1).code, &"stale_minesweeper_presentation")
	assert_eq(root_store.next_counter, before)


func test_same_revision_with_changed_full_identity_is_stale_before_allocation() -> void:
	var pulled: Dictionary = port.pull("beginner")
	var snapshot: Dictionary = coordinator.get_state().value
	var entry: Dictionary = coordinator.get_entry_context("beginner").value
	# NONE has no retained identity, so change the prospective owner identity at its actual source.
	var state_source: Object = coordinator.get("_state_port")
	state_source.branch_id = str(entry.identity.branch_id) + "-changed"
	var before: int = root_store.next_counter
	var refused: Dictionary = port.dispatch("reveal", 0, pulled.value.revision)
	assert_eq(refused.code, &"stale_minesweeper_presentation")
	assert_eq(root_store.next_counter, before)
	assert_eq(snapshot.revision, pulled.value.revision)


func test_replaying_an_old_public_revision_does_not_allocate_twice() -> void:
	var pulled: Dictionary = port.pull("beginner")
	assert_true(port.dispatch("reveal", 0, pulled.value.revision).ok)
	var after_first: int = root_store.next_counter
	assert_eq(port.dispatch("reveal", 0, pulled.value.revision).code, &"stale_minesweeper_presentation")
	assert_eq(root_store.next_counter, after_first)


func test_live_entry_eligibility_is_rechecked_before_allocation() -> void:
	var pulled: Dictionary = port.pull("beginner")
	state_port.motivation = 0
	var before: int = root_store.next_counter
	var refused: Dictionary = port.dispatch("reveal", 0, pulled.value.revision)
	assert_eq(refused.code, &"minesweeper_action_not_available")
	assert_eq(root_store.next_counter, before)
	assert_true(refused.has("value"))
	assert_eq(refused.value.cells[0].actions, [])


func test_prepared_round_refuses_a_stale_caller_difficulty() -> void:
	var context: Dictionary = coordinator.get_entry_context("beginner").value
	var begin_tx := _issue_transaction()
	assert_true(coordinator.begin_debug_preparation({
		"transaction_id": begin_tx.id, "transaction_issuer_receipt": begin_tx.receipt,
		"expected_identity": context.identity, "expected_revision": context.revision,
		"difficulty_id": "beginner",
	}).ok)
	var search_slices: Array[Dictionary] = [{"done": true, "layout": {"schema_version": 1,
		"width": 3, "height": 3, "mine_indices": [1], "mine_count": 1},
		"forced_cell": 0, "proof_sha256": null}]
	generation.arm_search_slices(search_slices)
	var slice_tx := _issue_transaction()
	assert_true(coordinator.run_debug_preparation_slice({
		"transaction_id": slice_tx.id, "transaction_issuer_receipt": slice_tx.receipt,
		"expected_identity": context.identity, "expected_revision": 1,
	}).ok)
	var before: int = root_store.next_counter
	assert_eq(port.pull("expert").code, &"minesweeper_presentation_unavailable")
	assert_eq(root_store.next_counter, before)


func test_owner_refusal_is_sanitized_and_refreshes_the_public_projection() -> void:
	var pulled: Dictionary = port.pull("beginner")
	generation.arm_materialize({"schema_version": 1, "width": 2, "height": 2,
		"mine_indices": [1], "mine_count": 1})
	var refused: Dictionary = port.dispatch("reveal", 0, pulled.value.revision)
	assert_false(refused.ok)
	assert_eq(refused.code, &"minesweeper_command_refused")
	assert_true(refused.has("value"))
	assert_eq(refused.value, port.pull("beginner").value)
	assert_false(JSON.stringify(refused).contains("layout_dimensions_mismatch"))
	assert_false(JSON.stringify(refused).contains("mine_indices"))


func _issue_transaction() -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	return {"id": str(issued.value.token), "receipt": issued.value.issuer_receipt}


func _assert_public_grid_projection(value: Dictionary) -> void:
	assert_eq(value.keys(), ["width", "height", "revision", "mine_estimate", "terminal", "custody", "cells"])
	for cell: Dictionary in value.cells:
		assert_eq(cell.keys(), ["index", "face", "mark", "number", "bracketed", "inspectable", "pressable", "actions"])
	var encoded: String = JSON.stringify(value)
	for private_key: String in ["mine_indices", "adjacency_counts", "identity", "receipt"]:
		assert_false(encoded.contains(private_key), private_key)
