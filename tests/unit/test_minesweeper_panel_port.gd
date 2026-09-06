extends GutTest

const PORT := preload("res://scripts/application/minesweeper/MinesweeperPanelPort.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE_PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const UNAVAILABLE := {"ok": false, "code": &"minesweeper_panel_unavailable"}
const ACTIONS := ["reveal", "flag", "drag", "assignments", "rules"]

class CatalogFixture extends RefCounted:
	var tasks: Variant = []
	func get_minesweeper_tasks() -> Variant:
		return tasks

class ChangingOwner extends RefCounted:
	var owner: Object
	var reads := 0
	var change_on_read := 0
	func get_state() -> Dictionary:
		reads += 1
		var result: Dictionary = owner.get_state()
		if reads == change_on_read:
			result.value.identity.run_id = "private-changed-run"
		return result
	func get_entry_context(difficulty: String) -> Dictionary:
		return owner.get_entry_context(difficulty)
	func reveal(request: Dictionary) -> Dictionary:
		return owner.reveal(request)
	func set_flag(request: Dictionary) -> Dictionary:
		return owner.set_flag(request)
	func chord(request: Dictionary) -> Dictionary:
		return owner.chord(request)

var state
var coordinator
var state_port
var checkpoint
var generation
var issuer
var root_store
var catalog
var port


func before_each() -> void:
	state = GAME_STATE.new()
	state.reset_game()
	state.set_stat("pressure", 0)
	root_store = ROOT_STORE.new("42".repeat(32), 1)
	issuer = ISSUER.new()
	assert_true(issuer.configure(root_store).ok)
	state_port = STATE_PORT.new()
	assert_true(state_port.configure(state, issuer, {
		"run_id": "private-run", "branch_id": "private-branch", "desktop_timeline_generation": 0,
		"causal_day_instance": "private-day",
	}).ok)
	checkpoint = CHECKPOINT.new()
	generation = GENERATION.new()
	generation.arm_materialize({"schema_version": 1, "width": 8, "height": 8,
		"mine_indices": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "mine_count": 10})
	coordinator = COORDINATOR.new()
	assert_true(coordinator.configure(state_port, checkpoint, generation, issuer).ok)
	catalog = CATALOG.new()
	port = PORT.new()
	assert_true(port.configure(coordinator, issuer, state, catalog).ok)


func after_each() -> void:
	state.free()


func test_pull_composes_only_detached_public_facts_without_spending_or_allocating() -> void:
	state.check_and_claim_minesweeper_task_rewards({"task_ids": ["complete_beginner"]})
	var before: Dictionary = state.to_save_dict().duplicate(true)
	var board_before: Dictionary = coordinator.get_state().value
	var counter_before: int = root_store.next_counter
	var result: Dictionary = port.pull()
	assert_true(result.ok)
	assert_eq(result.keys(), ["ok", "value"])
	assert_eq(result.value.keys(), ["board", "register", "assignments", "actions"])
	assert_eq(result.value.actions, ACTIONS)
	assert_eq(result.value.assignments, [true, false, false, false, false, false, false, false, false])
	assert_eq(result.value.register.rounds, 2)
	assert_null(result.value.register.foresight)
	assert_eq(result.value.register.difficulty_enabled, [])
	assert_eq(result.value.board.cells.size(), 64)
	assert_false(JSON.stringify(result).contains("private"))
	assert_false(JSON.stringify(result).contains("mine_indices"))
	result.value.board.cells[0].face = "private-edit"
	result.value.assignments[0] = false
	result.value.actions.append("new_board")
	assert_eq(state.to_save_dict(), before)
	assert_eq(coordinator.get_state().value, board_before)
	assert_eq(root_store.next_counter, counter_before)
	assert_true(port.pull().value.assignments[0])
	assert_eq(port.pull().value.actions, ACTIONS)


func test_real_first_reveal_and_flag_unflag_refresh_the_whole_panel() -> void:
	var initial: Dictionary = port.pull()
	var active: Dictionary = port.dispatch("reveal", 0, initial.value.board.revision)
	assert_true(active.ok, str(active))
	assert_eq(coordinator.get_state().value.board.paid_start_receipt.keys(), ["checkpoint_id"],
		"Real coordinator retains frozen difficulty in its first-Reveal journal, not this marker.")
	assert_eq(active.value.board.revision, 1)
	assert_eq(active.value.register.rounds, 1)
	assert_eq(state.minesweeper_rounds_left, 1)
	assert_eq(active.value.register.mine_estimate, 10)
	state.minesweeper_selected_difficulty = "expert"
	var flagged: Dictionary = port.dispatch("flag", 2, active.value.board.revision)
	assert_true(flagged.ok, str(flagged))
	assert_eq(flagged.value.board.cells[2].mark, "flag")
	assert_eq(flagged.value.register.mine_estimate, 9)
	assert_eq(flagged.value.register.difficulty, "beginner")
	assert_eq(flagged.value.register.no_flag, "lost")
	var unflagged: Dictionary = port.dispatch("unflag", 2, flagged.value.board.revision)
	assert_true(unflagged.ok)
	assert_eq(unflagged.value.register.no_flag, "lost")
	assert_eq(unflagged.value.register.mine_estimate, 10)
	assert_eq(unflagged.value.board.mine_estimate, unflagged.value.register.mine_estimate)
	assert_eq(unflagged.value.board.custody, unflagged.value.register.custody)
	assert_eq(unflagged.value.actions, ACTIONS)


func test_terminal_custody_has_no_panel_actions_or_replacement_command() -> void:
	var initial: Dictionary = port.pull()
	var active: Dictionary = port.dispatch("reveal", 0, initial.value.board.revision)
	assert_true(active.ok)
	var terminal: Dictionary = port.dispatch("reveal", 1, active.value.board.revision)
	assert_true(terminal.ok)
	assert_true(terminal.value.board.terminal)
	assert_true(terminal.value.register.custody)
	assert_eq(terminal.value.actions, [])
	assert_eq(terminal.value.register.difficulty_enabled, [])
	var counter_before: int = root_store.next_counter
	var refused: Dictionary = port.dispatch("new_board", -1, terminal.value.board.revision)
	assert_false(refused.ok)
	assert_eq(refused.value.actions, [])
	assert_eq(root_store.next_counter, counter_before)


func test_stale_and_owner_refusal_return_only_safe_refreshed_composites() -> void:
	var initial: Dictionary = port.pull()
	var unpaid_before: Dictionary = coordinator.get_state().value
	checkpoint.fail_next("prepare_checkpoint", {"ok": false, "code": &"private-checkpoint-failure",
		"details": {"private": "receipt"}})
	var refused: Dictionary = port.dispatch("reveal", 0, initial.value.board.revision)
	assert_false(refused.ok)
	assert_eq(refused.code, &"minesweeper_panel_command_refused")
	assert_eq(refused.value, initial.value)
	assert_false(JSON.stringify(refused).contains("private"))
	assert_eq(coordinator.get_state().value, unpaid_before)
	assert_eq(state.minesweeper_rounds_left, 2)
	var active: Dictionary = port.dispatch("reveal", 0, initial.value.board.revision)
	assert_true(active.ok)
	var before: Dictionary = coordinator.get_state().value
	var counter_before: int = root_store.next_counter
	var stale: Dictionary = port.dispatch("flag", 2, initial.value.board.revision)
	assert_eq(stale.code, &"minesweeper_panel_command_refused")
	assert_eq(stale.value, active.value)
	assert_eq(coordinator.get_state().value, before)
	assert_eq(root_store.next_counter, counter_before)


func test_invalid_assignment_read_has_no_partial_view_and_cannot_dispatch_cached_board() -> void:
	var changing_catalog := CatalogFixture.new()
	changing_catalog.tasks = catalog.get_minesweeper_tasks()
	var isolated := PORT.new()
	assert_true(isolated.configure(coordinator, issuer, state, changing_catalog).ok)
	var initial: Dictionary = isolated.pull()
	assert_true(initial.ok)
	changing_catalog.tasks = "private unavailable catalog"
	assert_eq(isolated.pull(), UNAVAILABLE)
	var counter_before: int = root_store.next_counter
	var refused: Dictionary = isolated.dispatch("reveal", 0, initial.value.board.revision)
	assert_eq(refused, {"ok": false, "code": &"minesweeper_panel_command_refused"})
	assert_eq(root_store.next_counter, counter_before)
	assert_eq(coordinator.get_state().value.phase, "NONE")


func test_changed_unpaid_tier_refuses_old_reveal_before_allocation_and_refreshes_expert() -> void:
	var initial: Dictionary = port.pull()
	assert_eq(initial.value.register.difficulty, "beginner")
	state.minesweeper_selected_difficulty = "expert"
	var before: Dictionary = state.to_save_dict().duplicate(true)
	var board_before: Dictionary = coordinator.get_state().value
	var counter_before: int = root_store.next_counter
	var generation_calls_before: int = generation.call_log.size()
	var refused: Dictionary = port.dispatch("reveal", 0, initial.value.board.revision)
	assert_eq(refused.code, &"minesweeper_panel_command_refused")
	assert_eq(refused.value.register.difficulty, "expert")
	assert_eq(refused.value.board.width, 22)
	assert_eq(refused.value.board.revision, initial.value.board.revision)
	assert_eq(refused.value.register.rounds, 2)
	assert_eq(root_store.next_counter, counter_before, "Stale tier selection allocates no command or board identity.")
	assert_eq(generation.call_log.size(), generation_calls_before)
	assert_eq(state.to_save_dict(), before, "Stale Reveal spends neither a round nor Motivation.")
	assert_eq(coordinator.get_state().value, board_before)
	assert_eq(refused.value, port.pull().value)


func test_same_revision_owner_change_between_reads_refuses_the_composite() -> void:
	var initial: Dictionary = port.pull()
	assert_true(port.dispatch("reveal", 0, initial.value.board.revision).ok)
	var changing := ChangingOwner.new()
	changing.owner = coordinator
	changing.change_on_read = 3
	var isolated := PORT.new()
	assert_true(isolated.configure(changing, issuer, state, catalog).ok)
	assert_eq(isolated.pull(), UNAVAILABLE)
	assert_eq(changing.reads, 3)


func test_reconfiguration_is_idempotent_and_rebind_cannot_replace_working_dependencies() -> void:
	assert_eq(port.configure(coordinator, issuer, state, catalog), {"ok": true, "value": {"already_configured": true}})
	var initial: Dictionary = port.pull()
	for replacement: Array in [
		[COORDINATOR.new(), issuer, state, catalog], [coordinator, ISSUER.new(), state, catalog],
		[coordinator, issuer, RefCounted.new(), catalog], [coordinator, issuer, state, CATALOG.new()],
	]:
		assert_eq(port.configure(replacement[0], replacement[1], replacement[2], replacement[3]),
			{"ok": false, "code": &"minesweeper_panel_already_configured"})
	assert_eq(port.pull(), initial)
	assert_true(port.dispatch("reveal", 0, initial.value.board.revision).ok)


func test_unconfigured_or_invalid_dependencies_refuse_without_allocating() -> void:
	var isolated := PORT.new()
	assert_eq(isolated.pull(), UNAVAILABLE)
	assert_eq(isolated.configure(null, issuer, state, catalog), UNAVAILABLE)
	assert_eq(isolated.configure(coordinator, issuer, state, RefCounted.new()), UNAVAILABLE)
	assert_true(isolated.configure(coordinator, issuer, state, catalog).ok)
	var counter_before: int = root_store.next_counter
	var refused: Dictionary = isolated.dispatch("reveal", 0, 0)
	assert_false(refused.ok, "A first dispatch must not bypass initial composite presentation.")
	assert_true(refused.has("value"))
	assert_eq(root_store.next_counter, counter_before)


func test_real_panel_routes_grid_intents_and_keeps_information_sheets_read_only() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 720)
	add_child_autofree(viewport)
	var panel: Control = PANEL.new()
	viewport.add_child(panel)
	assert_true(panel.configure("en", 100, false, &"after_hours"))
	assert_true(panel.bind(port))
	assert_true(panel.refresh())
	watch_signals(panel)
	await get_tree().process_frame
	var grid: Control = panel.worksheet.grid
	var retained_cell: Control = grid.cell_nodes[2]
	grid.cell_action_requested.emit(&"reveal", 0, grid.projection.revision)
	assert_eq(coordinator.get_state().value.phase, "ACTIVE_VISIBLE")
	assert_eq(state.minesweeper_rounds_left, 1)
	assert_eq(grid.projection.revision, 1)
	assert_eq(panel.register.public_view.rounds, 1)
	assert_eq(panel.register.public_view.mine_estimate, 10)
	assert_same(grid.cell_nodes[2], retained_cell)
	grid.cell_action_requested.emit(&"flag", 2, grid.projection.revision)
	assert_eq(grid.projection.cells[2].mark, "flag")
	assert_eq(panel.register.public_view.mine_estimate, 9)
	assert_eq(panel.register.public_view.no_flag, "lost")
	assert_same(grid.cell_nodes[2], retained_cell)
	grid.cell_action_requested.emit(&"unflag", 2, grid.projection.revision)
	assert_eq(grid.projection.cells[2].mark, "none")
	assert_eq(panel.register.public_view.mine_estimate, 10)
	assert_eq(panel.register.public_view.no_flag, "lost")
	assert_same(grid.cell_nodes[2], retained_cell)
	var counter_before: int = root_store.next_counter
	var state_before: Dictionary = state.to_save_dict().duplicate(true)
	var board_before: Dictionary = coordinator.get_state().value
	for action: StringName in [&"rules", &"assignments"]:
		panel.dock.action_requested.emit(action)
		assert_not_null(panel.worksheet.information_sheet)
		if panel.worksheet.information_sheet == null: continue
		assert_eq(panel.worksheet.information_sheet.rows.size(), 4 if action == &"rules" else 9)
		panel.worksheet.information_sheet.return_requested.emit()
		assert_null(panel.worksheet.information_sheet)
		assert_same(grid.cell_nodes[2], retained_cell)
	assert_eq(root_store.next_counter, counter_before, "Opening and returning from sheets allocates no command.")
	assert_eq(state.to_save_dict(), state_before)
	assert_eq(coordinator.get_state().value, board_before)
	assert_signal_not_emitted(panel, "presentation_failed")


func test_panel_foreground_preserves_frozen_register_and_history_without_spending() -> void:
	var initial: Dictionary = port.pull()
	var active: Dictionary = port.dispatch("reveal", 0, initial.value.board.revision)
	var flagged: Dictionary = port.dispatch("flag", 2, active.value.board.revision)
	state.minesweeper_selected_difficulty = "expert"
	var state_before: Dictionary = state.to_save_dict().duplicate(true)
	var board_before: Dictionary = coordinator.get_state().value.board
	var generation_before: Array = generation.call_log.duplicate(true)
	var suspended: Dictionary = port.set_foreground(false, flagged.value.board.revision)
	assert_true(suspended.ok)
	assert_true(suspended.value.register.custody)
	assert_eq(suspended.value.actions, [])
	assert_eq(suspended.value.register.difficulty, "beginner")
	assert_eq(suspended.value.register.no_flag, "lost")
	assert_eq(suspended.value.register.mine_estimate, 9)
	var counter_before: int = root_store.next_counter
	assert_true(port.set_foreground(false, suspended.value.board.revision).ok)
	assert_false(port.dispatch("unflag", 2, suspended.value.board.revision).ok)
	assert_eq(root_store.next_counter, counter_before)
	var resumed: Dictionary = port.set_foreground(true, suspended.value.board.revision)
	assert_true(resumed.ok)
	assert_false(resumed.value.register.custody)
	assert_eq(resumed.value.actions, ACTIONS)
	assert_eq(resumed.value.register, flagged.value.register)
	assert_eq(coordinator.get_state().value.board, board_before)
	assert_eq(state.to_save_dict(), state_before)
	assert_eq(generation.call_log, generation_before)
	counter_before = root_store.next_counter
	assert_true(port.set_foreground(true, resumed.value.board.revision).ok)
	assert_eq(root_store.next_counter, counter_before)


func test_panel_foreground_refuses_changed_unpaid_tier_before_allocation() -> void:
	var initial: Dictionary = port.pull()
	state.minesweeper_selected_difficulty = "expert"
	var counter_before: int = root_store.next_counter
	var refused: Dictionary = port.set_foreground(false, initial.value.board.revision)
	assert_eq(refused.code, &"minesweeper_panel_command_refused")
	assert_eq(refused.value.register.difficulty, "expert")
	assert_eq(root_store.next_counter, counter_before)
	assert_eq(coordinator.get_state().value.phase, "NONE")
