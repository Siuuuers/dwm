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

class ReplacementCheckpoint extends RefCounted:
	var fail_prepare := true
	var disk: Dictionary = {}
	func capture() -> Dictionary: return {"ok":true,"value":{"backup":disk.duplicate(true)}}
	func preview_checkpoint_id(_run: String) -> Dictionary:
		return {"ok":true,"value":{"checkpoint_id":"replacement-checkpoint"}}
	func prepare_checkpoint(inputs: Dictionary, _kind: StringName, _intent: Dictionary) -> Dictionary:
		if fail_prepare:
			fail_prepare = false
			return {"ok":false,"code":&"injected_replacement_failure"}
		return {"ok":true,"value":{"candidate":{"snapshot":inputs.duplicate(true)}}}
	func commit_checkpoint(candidate: Dictionary) -> Dictionary:
		disk = candidate.snapshot.duplicate(true)
		return {"ok":true}
	func rollback(backup: Dictionary) -> Dictionary:
		disk = backup.duplicate(true)
		return {"ok":true}

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
	func complete_round(request: Dictionary) -> Dictionary:
		return owner.complete_round(request)

class TerminalClearingOwner extends RefCounted:
	const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
	var completion_calls: Array = []
	var snapshot: Dictionary

	func _init() -> void:
		var revealed: Dictionary = REDUCER.first_reveal({
			"schema_version":1,"width":3,"height":3,"mine_indices":[1],"mine_count":1,
		},0)
		snapshot = {
			"schema_version":1,"phase":"ACTIVE_VISIBLE","revision":1,
			"identity":{"run_id":"run-ui","branch_id":"branch-ui",
				"desktop_timeline_generation":1,"causal_day_instance":"day-ui",
				"app_round_ordinal":1},
			"candidate":null,"board":{"board":revealed.value.board,
				"paid_start_receipt":{"receipt_id":"paid-ui","difficulty_id":"beginner"}},
			"settlement":null,"command_receipts":{},"terminal_receipts":{},
		}

	func get_state() -> Dictionary:
		return {"ok":true,"code":&"ok","value":snapshot.duplicate(true),"receipt":{}}
	func get_entry_context(difficulty: String) -> Dictionary:
		return {"ok":true,"code":&"ok","value":{"identity":snapshot.identity,
			"revision":snapshot.revision,"difficulty_id":difficulty,"eligible":false},"receipt":{}}
	func reveal(request: Dictionary) -> Dictionary:
		var reduced: Dictionary = REDUCER.reveal(snapshot.board.board,
			int(request.cell_index),str(request.transaction_id))
		if not reduced.ok: return reduced
		snapshot.board.board = reduced.value.board
		snapshot.revision += 1
		return {"ok":true,"code":&"ok","value":{},"receipt":{}}
	func set_flag(_request: Dictionary) -> Dictionary:
		return {"ok":false,"code":&"unused"}
	func chord(_request: Dictionary) -> Dictionary:
		return {"ok":false,"code":&"unused"}
	func complete_round(request: Dictionary) -> Dictionary:
		completion_calls.append(request.duplicate(true))
		if completion_calls.size() == 1:
			return {"ok":false,"code":&"temporary_settlement_failure","details":{}}
		snapshot = {"schema_version":1,"phase":"NONE","revision":snapshot.revision+1,
			"identity":null,"candidate":null,"board":null,"settlement":null,
			"command_receipts":{},"terminal_receipts":{}}
		return {"ok":true,"code":&"ok","value":{},"receipt":{}}

class RetainedTerminalOwner extends TerminalClearingOwner:
	var settled := false
	var refuse_completion := true
	var refuse_dismissal := true
	var dismissal_calls: Array[Dictionary] = []
	func get_configuration_context() -> Dictionary:
		return {"ok":true,"value":{"phase":snapshot.phase,"identity":snapshot.identity,
			"revision":snapshot.revision,"difficulty_id":"beginner","difficulty_enabled":[],
			"new_board_enabled":settled,"settled_inspection":settled}}
	func complete_round(request: Dictionary) -> Dictionary:
		completion_calls.append(request.duplicate(true))
		if refuse_completion:
			refuse_completion = false
			return {"ok":false,"code":&"injected_completion_checkpoint"}
		settled = true
		snapshot.revision += 1
		return {"ok":true}
	func replace_board(request: Dictionary) -> Dictionary:
		dismissal_calls.append(request.duplicate(true))
		if request.expected_identity != snapshot.identity or request.expected_revision != snapshot.revision \
				or request.difficulty_id != "beginner" or not settled:
			return {"ok":false,"code":&"stale_dismissal"}
		if refuse_dismissal:
			refuse_dismissal = false
			return {"ok":false,"code":&"injected_dismissal_checkpoint"}
		settled = false
		snapshot = {"schema_version":1,"phase":"NONE","revision":snapshot.revision+1,
			"identity":null,"candidate":null,"board":null,"settlement":null,
			"command_receipts":{},"terminal_receipts":{}}
		return {"ok":true}

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
	assert_eq(result.value.keys(), ["board", "register", "assignments", "actions", "settled"])
	assert_eq(result.value.actions, ACTIONS)
	assert_false(result.value.settled)
	assert_eq(result.value.assignments, [true, false, false, false, false, false, false, false, false])
	assert_eq(result.value.register.rounds, 2)
	assert_null(result.value.register.foresight)
	assert_eq(result.value.register.difficulty_enabled, ["beginner", "intermediate", "expert"])
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
	assert_eq(unflagged.value.actions, ACTIONS + ["new_board"])


func test_terminal_settlement_failure_stays_visible_then_success_holds_exact_board_after_owner_clears() -> void:
	var owner := TerminalClearingOwner.new()
	var isolated := PORT.new()
	assert_true(isolated.configure(owner,issuer,state,catalog).ok)
	var initial: Dictionary = isolated.pull()
	assert_true(initial.ok,str(initial))
	var published: Dictionary = isolated.dispatch("reveal",1,initial.value.board.revision)
	assert_true(published.ok,str(published))
	assert_true(published.value.board.terminal)
	assert_true(published.value.board.custody)
	assert_false(published.value.settled)
	assert_eq(published.value.actions,[])
	assert_eq(owner.completion_calls.size(),0,"dwm-634.1: the click publishes the terminal board before settlement")
	var first: Dictionary = isolated.advance_preparation(published.value.board.revision)
	assert_false(first.ok)
	assert_true(first.value.board.terminal)
	assert_true(first.value.board.custody)
	assert_false(first.value.settled)
	assert_eq(first.value.actions,[])
	assert_eq(owner.completion_calls.size(),1)
	var terminal_bytes: Dictionary = first.value.board.duplicate(true)
	var settled: Dictionary = isolated.pull()
	assert_true(settled.ok,str(settled))
	assert_eq(settled.value.board,terminal_bytes)
	assert_true(settled.value.settled)
	assert_eq(settled.value.actions,["new_board","assignments","rules"])
	assert_eq(owner.completion_calls.size(),2)
	assert_eq(owner.snapshot.phase,"NONE","the completion double really clears its board owner")
	assert_eq(isolated.pull(),settled,"ordinary refresh retains the settled terminal view")
	assert_eq(owner.completion_calls.size(),2,"held refresh never repeats completion")
	var counter_before: int = root_store.next_counter
	var rounds_before: int = state.minesweeper_rounds_left
	var released: Dictionary = isolated.dispatch("new_board",-1,settled.value.board.revision)
	assert_true(released.ok,str(released))
	assert_false(released.value.board.terminal)
	assert_false(released.value.settled)
	assert_eq(released.value.actions,ACTIONS)
	assert_eq(root_store.next_counter,counter_before,"New Board allocates no gameplay identity")
	assert_eq(state.minesweeper_rounds_left,rounds_before,"New Board spends no round")


func test_failed_terminal_settlement_retains_exact_projection_without_next_action() -> void:
	var initial: Dictionary = port.pull()
	var active: Dictionary = port.dispatch("reveal",0,initial.value.board.revision)
	assert_true(active.ok)
	var published: Dictionary = port.dispatch("reveal",1,active.value.board.revision)
	assert_true(published.ok,str(published))
	assert_false(published.value.settled)
	var terminal: Dictionary = port.advance_preparation(published.value.board.revision)
	assert_false(terminal.ok)
	assert_true(terminal.value.board.terminal)
	assert_true(terminal.value.register.custody)
	assert_false(terminal.value.settled)
	assert_eq(terminal.value.actions,[])
	assert_eq(coordinator.get_state().value.phase,"ACTIVE_VISIBLE")
	var refused: Dictionary = port.dispatch("new_board",-1,terminal.value.board.revision)
	assert_false(refused.ok)
	assert_eq(refused.value,terminal.value)


func test_day_change_invalidates_a_held_terminal_view() -> void:
	var owner := TerminalClearingOwner.new()
	var isolated := PORT.new()
	assert_true(isolated.configure(owner,issuer,state,catalog).ok)
	var initial: Dictionary = isolated.pull()
	var published: Dictionary = isolated.dispatch("reveal",1,initial.value.board.revision)
	assert_true(published.ok,str(published))
	assert_false(isolated.advance_preparation(published.value.board.revision).ok,"the double refuses its first completion")
	var terminal: Dictionary = isolated.pull()
	assert_true(terminal.ok)
	assert_true(terminal.value.settled)
	state.day_changed.emit(state.day+1)
	var refreshed: Dictionary = isolated.pull()
	assert_true(refreshed.ok,str(refreshed))
	assert_false(refreshed.value.settled)
	assert_false(refreshed.value.board.terminal)


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
	assert_eq(resumed.value.actions, ACTIONS + ["new_board"])
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


func test_terminal_foresight_includes_final_click_and_survives_settlement_clear_and_retry() -> void:
	for fail_first: bool in [false, true]:
		var owner := TerminalClearingOwner.new()
		if not fail_first: owner.completion_calls.append({})
		var isolated := PORT.new()
		assert_true(isolated.configure(owner, issuer, state, catalog).ok)
		var active: Dictionary = isolated.pull()
		assert_true(active.ok, str(active))
		assert_eq(active.value.register.foresight, 300, "three BV and the implicit first click")
		var published: Dictionary = isolated.dispatch("reveal", 1, active.value.board.revision)
		assert_true(published.ok, str(published))
		assert_eq(published.value.register.foresight, 150, "the metric is known before settlement")
		var terminal: Dictionary = isolated.advance_preparation(published.value.board.revision)
		assert_eq(terminal.ok, not fail_first)
		assert_eq(terminal.value.register.foresight, 150, "terminal Reveal is the second accepted click")
		assert_true(terminal.value.board.terminal)
		var public_board: Dictionary = terminal.value.board.duplicate(true)
		var changed: Dictionary = public_board.duplicate(true)
		changed.revision += 1
		assert_false(isolated._board_port.get_terminal_foresight(changed).ok,
			"a different projection cannot borrow the retained final metric")
		var held: Dictionary = isolated.pull()
		assert_true(held.ok, str(held))
		assert_eq(owner.snapshot.phase, "NONE")
		assert_eq(held.value.board, public_board)
		assert_eq(held.value.register.foresight, 150)
		assert_eq(isolated.pull(), held)
		assert_true(isolated.dispatch("new_board", -1, held.value.board.revision).ok)
		assert_null(isolated.pull().value.register.foresight, "the next untouched board has no metric")


func test_unpaid_tier_change_and_untouched_new_board_never_generate_or_spend() -> void:
	var initial: Dictionary = port.pull()
	var rounds: int = state.minesweeper_rounds_left
	var motivation: int = state.get_stat("motivation")
	var calls: Array = generation.call_log.duplicate(true)
	var selected: Dictionary = port.select_difficulty("expert",initial.value.board.revision)
	assert_true(selected.ok,str(selected))
	if not selected.ok: return
	assert_eq(selected.value.register.difficulty,"expert")
	assert_eq(selected.value.board.width,22)
	assert_eq(coordinator.get_state().value.phase,"UNPAID_UNSTARTED")
	assert_eq(state.minesweeper_rounds_left,rounds)
	assert_eq(state.get_stat("motivation"),motivation)
	assert_eq(generation.call_log,calls)
	assert_false("new_board" in selected.value.actions)
	var before: Dictionary = coordinator.get_state().value
	var counter: int = root_store.next_counter
	assert_true(port.select_difficulty("expert",selected.value.board.revision).ok)
	assert_true(port.dispatch("new_board",-1,selected.value.board.revision).ok)
	assert_eq(root_store.next_counter,counter)
	assert_eq(coordinator.get_state().value,before)


func test_unpaid_flags_without_capacity_preserve_no_flag_and_untouched_new_board_is_noop() -> void:
	state.set_stat("motivation",0)
	var initial: Dictionary = port.pull()
	assert_true(initial.ok,str(initial))
	assert_eq(initial.value.board.cells[2].actions,["flag"])
	var flagged: Dictionary = port.dispatch("flag",2,initial.value.board.revision)
	assert_true(flagged.ok,str(flagged))
	if not flagged.ok: return
	assert_eq(flagged.value.register.no_flag,"lost")
	assert_null(flagged.value.register.foresight)
	assert_false("new_board" in flagged.value.actions)
	var before: Dictionary = coordinator.get_state().value
	var counter: int = root_store.next_counter
	assert_true(port.dispatch("new_board",-1,flagged.value.board.revision).ok)
	assert_eq(coordinator.get_state().value,before)
	assert_eq(root_store.next_counter,counter)
	var unflagged: Dictionary = port.dispatch("unflag",2,flagged.value.board.revision)
	assert_true(unflagged.ok,str(unflagged))
	assert_eq(unflagged.value.register.no_flag,"lost")
	assert_eq(state.minesweeper_rounds_left,2)
	assert_eq(state.get_stat("motivation"),0)
	assert_true(generation.call_log.is_empty())


func test_paid_replacement_and_paid_tier_change_keep_one_cost_and_accept_exact_retry() -> void:
	var initial: Dictionary = port.pull()
	var active: Dictionary = port.dispatch("reveal",0,initial.value.board.revision)
	assert_true(active.ok,str(active))
	if not active.ok: return
	assert_true("new_board" in active.value.actions)
	var identity: Dictionary = coordinator.get_state().value.identity.duplicate(true)
	var rounds: int = state.minesweeper_rounds_left
	var motivation: int = state.get_stat("motivation")
	# Replacement uses the full-snapshot seam, not the legacy first-Reveal fake.
	var durable := ReplacementCheckpoint.new()
	assert_true(coordinator.configure_durable_checkpoint(durable,
		preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd"),
		preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()).ok)
	var failed: Dictionary = port.dispatch("new_board",-1,active.value.board.revision)
	assert_false(failed.ok)
	var counter: int = root_store.next_counter
	var retried: Dictionary = port.dispatch("new_board",-1,active.value.board.revision)
	assert_true(retried.ok,str(retried))
	if not retried.ok: return
	assert_eq(root_store.next_counter,counter,"Replacement retry reuses its admitted command and frozen candidate.")
	assert_eq(coordinator.get_state().value.phase,"PAID_UNSTARTED")
	assert_eq(durable.disk.desktop.board,coordinator.get_state().value)
	assert_eq(coordinator.get_state().value.identity,identity)
	assert_false("new_board" in retried.value.actions)
	assert_eq(retried.value.register.no_flag,"intact")
	assert_null(retried.value.register.foresight)
	assert_eq(state.minesweeper_rounds_left,rounds)
	assert_eq(state.get_stat("motivation"),motivation)
	var changed: Dictionary = port.select_difficulty("expert",retried.value.board.revision)
	assert_true(changed.ok,str(changed))
	assert_eq(changed.value.register.difficulty,"expert")
	assert_eq(changed.value.board.width,22)
	assert_eq(state.minesweeper_rounds_left,rounds)
	assert_eq(state.get_stat("motivation"),motivation)


func test_stale_configuration_revision_or_live_session_is_refused_before_allocation() -> void:
	var initial: Dictionary = port.pull()
	var counter: int = root_store.next_counter
	assert_false(port.select_difficulty("expert",initial.value.board.revision+1).ok)
	assert_eq(root_store.next_counter,counter)
	# The session marker is local admission evidence, not a manufactured live Run identity.
	port._presented_session = {"day":state.day,"session":{"stale":true}}
	assert_false(port.select_difficulty("expert",initial.value.board.revision).ok)
	assert_eq(root_store.next_counter,counter)
	assert_eq(coordinator.get_state().value.phase,"NONE")


func test_first_paid_reveal_resolves_exact_journal_after_saved_shell_flag_prefix() -> void:
	var initial: Dictionary = port.pull()
	var marked: Dictionary = port.dispatch("flag",2,initial.value.board.revision)
	assert_true(marked.ok,str(marked))
	if not marked.ok: return
	var active: Dictionary = port.dispatch("reveal",0,marked.value.board.revision)
	assert_true(active.ok,str(active))
	if not active.ok: return
	assert_eq(active.value.register.no_flag,"lost")
	assert_eq(active.value.register.difficulty,"beginner")
	assert_eq(active.value.board.cells[2].mark,"flag")
	var snapshot: Dictionary = coordinator.get_state().value
	var receipts := 0
	for entry: Dictionary in snapshot.command_receipts.values():
		if entry.command_kind != "first_reveal": continue
		receipts += 1
		assert_eq(entry.result.value.receipt.board_revision,1)
	assert_eq(receipts,1)
	state.minesweeper_selected_difficulty = "expert"
	var reloaded_projection: Dictionary = port.pull()
	assert_true(reloaded_projection.ok,str(reloaded_projection))
	assert_eq(reloaded_projection.value.register.difficulty,"beginner",
		"The paid receipt and its exact accepted shell prefix preserve the frozen difficulty.")
	assert_eq(state.minesweeper_rounds_left,1)


func _retained_terminal_owner() -> RetainedTerminalOwner:
	var owner := RetainedTerminalOwner.new()
	assert_true(owner.reveal({"cell_index":1,"transaction_id":"fixture-terminal"}).ok)
	owner.settled = true
	owner.snapshot.revision += 1
	return owner


func test_cold_retained_terminal_inspection_never_reissues_completion_and_survives_navigation() -> void:
	var owner := _retained_terminal_owner()
	var isolated := PORT.new()
	assert_true(isolated.configure(owner,issuer,state,catalog).ok)
	var before: Dictionary = owner.snapshot.duplicate(true)
	var counter: int = root_store.next_counter
	var terminal: Dictionary = isolated.pull()
	assert_true(terminal.ok,str(terminal))
	if not terminal.ok: return
	assert_true(terminal.value.settled)
	assert_eq(terminal.value.actions,["new_board","assignments","rules"])
	assert_eq(terminal.value.register.difficulty_enabled,[])
	assert_eq(terminal.value.board.revision,owner.snapshot.revision)
	assert_true(isolated.set_foreground(false,terminal.value.board.revision).ok)
	assert_true(isolated.set_foreground(true,terminal.value.board.revision).ok)
	var cold := PORT.new()
	assert_true(cold.configure(owner,issuer,state,catalog).ok)
	assert_eq(cold.pull(),terminal)
	assert_eq(owner.snapshot,before)
	assert_eq(root_store.next_counter,counter)
	assert_true(owner.completion_calls.is_empty())
	assert_true(owner.dismissal_calls.is_empty())


func test_settlement_retry_adopts_retained_owner_revision_before_dismissal_admission() -> void:
	var owner := RetainedTerminalOwner.new()
	var isolated := PORT.new()
	assert_true(isolated.configure(owner,issuer,state,catalog).ok)
	var initial: Dictionary = isolated.pull()
	assert_true(initial.ok,str(initial))
	var published: Dictionary = isolated.dispatch("reveal",1,initial.value.board.revision)
	assert_true(published.ok,str(published))
	assert_false(published.value.settled)
	var failed: Dictionary = isolated.advance_preparation(published.value.board.revision)
	assert_false(failed.ok)
	assert_false(failed.value.settled)
	var counter: int = root_store.next_counter
	var retried: Dictionary = isolated.pull()
	assert_true(retried.ok,str(retried))
	if not retried.ok: return
	assert_true(retried.value.settled)
	assert_eq(retried.value.board.revision,owner.snapshot.revision)
	assert_eq(retried.value.board.revision,failed.value.board.revision+1)
	assert_eq(retried.value.board.cells,failed.value.board.cells)
	assert_eq(owner.completion_calls.size(),2)
	assert_eq(owner.completion_calls[0],owner.completion_calls[1])
	assert_eq(root_store.next_counter,counter)
	assert_eq(isolated.pull(),retried)
	assert_eq(owner.completion_calls.size(),2)


func test_retained_terminal_new_board_commits_owner_dismissal_and_keeps_exact_failed_request() -> void:
	var owner := _retained_terminal_owner()
	var isolated := PORT.new()
	assert_true(isolated.configure(owner,issuer,state,catalog).ok)
	var terminal: Dictionary = isolated.pull()
	assert_true(terminal.ok,str(terminal))
	if not terminal.ok: return
	var before: Dictionary = owner.snapshot.duplicate(true)
	var failed: Dictionary = isolated.dispatch("new_board",-1,terminal.value.board.revision)
	assert_false(failed.ok)
	assert_eq(failed.value,terminal.value)
	assert_eq(owner.snapshot,before,"Failed durable dismissal preserves the inspectable owner.")
	assert_eq(owner.dismissal_calls.size(),1)
	var counter: int = root_store.next_counter
	var cold := PORT.new()
	assert_true(cold.configure(owner,issuer,state,catalog).ok)
	assert_eq(cold.pull(),terminal,"An unsaved dismissal never hides the terminal on reload.")
	var retried: Dictionary = isolated.dispatch("new_board",-1,terminal.value.board.revision)
	assert_true(retried.ok,str(retried))
	if not retried.ok: return
	assert_false(retried.value.settled)
	assert_false(retried.value.board.terminal)
	assert_eq(owner.snapshot.phase,"NONE")
	assert_eq(owner.dismissal_calls.size(),2)
	assert_eq(owner.dismissal_calls[0],owner.dismissal_calls[1])
	assert_eq(root_store.next_counter,counter)
	assert_true(owner.completion_calls.is_empty())
	assert_false(cold.pull().value.board.terminal,"A cached view follows canonical dismissal.")


func test_real_prepared_debug_projection_renders_free_flags_and_only_forced_reveal() -> void:
	state.inventory = {"debug_key":1}
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024,720)
	add_child_autofree(viewport)
	var panel: Control = PANEL.new()
	viewport.add_child(panel)
	assert_true(panel.configure())
	assert_true(panel.bind(port))
	assert_true(panel.refresh())
	var rounds: int = state.minesweeper_rounds_left
	var motivation: int = state.get_stat("motivation")
	var begun: Dictionary = port.advance_preparation(panel.public_view.board.revision)
	assert_true(begun.ok,str(begun))
	if not begun.ok: return
	assert_true(panel.present(begun.value))
	assert_true(panel.public_view.board.custody)
	var slices: Array[Dictionary] = [{"done":true,"layout":{"schema_version":1,
		"width":8,"height":8,"mine_indices":[1,2,3,4,5,6,7,8,9,10],"mine_count":10},
		"forced_cell":0,"proof_sha256":null}]
	generation.arm_search_slices(slices)
	var certified: Dictionary = port.advance_preparation(panel.public_view.board.revision)
	assert_true(certified.ok,str(certified))
	if not certified.ok: return
	assert_true(panel.present(certified.value),"The actual certified composite must pass Grid/Cell validation.")
	assert_false(panel.public_view.board.custody)
	assert_eq(panel.public_view.board.cells[0].actions,["reveal","flag"])
	assert_true(panel.public_view.board.cells[0].bracketed)
	for index in range(1,64):
		assert_eq(panel.public_view.board.cells[index].actions,["flag"])
		assert_false(panel.public_view.board.cells[index].bracketed)
	var frozen: Dictionary = coordinator.get_state().value.candidate.layout.duplicate(true)
	for index: int in [0,12]:
		var flagged: Dictionary = port.dispatch("flag",index,panel.public_view.board.revision)
		assert_true(flagged.ok,str(flagged))
		if not flagged.ok: return
		assert_true(panel.present(flagged.value))
		assert_eq(panel.public_view.board.cells[index].actions,["unflag"])
	for index: int in [0,12]:
		var unflagged: Dictionary = port.dispatch("unflag",index,panel.public_view.board.revision)
		assert_true(unflagged.ok,str(unflagged))
		if not unflagged.ok: return
		assert_true(panel.present(unflagged.value))
	assert_eq(coordinator.get_state().value.candidate.layout,frozen)
	assert_eq(panel.public_view.register.no_flag,"lost")
	assert_null(panel.public_view.register.foresight)
	assert_false("new_board" in panel.public_view.actions)
	assert_eq(state.minesweeper_rounds_left,rounds)
	assert_eq(state.get_stat("motivation"),motivation)
	var revealed: Dictionary = port.dispatch("reveal",0,panel.public_view.board.revision)
	assert_true(revealed.ok,str(revealed))
	if not revealed.ok: return
	assert_true(panel.present(revealed.value))
	assert_eq(state.minesweeper_rounds_left,rounds-1)
	assert_eq(state.get_stat("motivation"),motivation-1)

func test_real_retained_terminal_difficulty_publishes_next_legal_board_without_payment() -> void:
	var initial: Dictionary = port.pull()
	var active: Dictionary = port.dispatch("reveal",0,initial.value.board.revision)
	assert_true(active.ok,str(active))
	port.dispatch("reveal",1,active.value.board.revision)
	var terminal: Dictionary = coordinator.get_state().value
	assert_true(terminal.board.board.terminal)
	# This legacy checkpoint fake retains only a marker; use its accepted receipt
	# to model the full production terminal inspection snapshot.
	for entry: Dictionary in terminal.command_receipts.values():
		if str(entry.command_kind)=="first_reveal":
			terminal.board.paid_start_receipt=entry.result.value.receipt.duplicate(true)
	var transaction: Dictionary = issuer.issue(&"transaction_id")
	var settled: Dictionary = coordinator._project_completion_board(terminal.identity,terminal,"exploded",transaction.value.token)
	var restored: Dictionary = coordinator._board_state.prepare_restore(settled)
	assert_true(restored.ok,str(restored))
	assert_true(coordinator._board_state.commit(restored.value.candidate).ok)
	# Observe this cold-restored fixture with a fresh port, without its deliberately
	# failed pre-restore completion request.
	port = PORT.new()
	assert_true(port.configure(coordinator,issuer,state,catalog).ok)
	var shown: Dictionary = port.pull()
	assert_true(shown.ok,str(shown))
	if not shown.ok: return
	assert_true(shown.value.settled)
	assert_eq(shown.value.register.difficulty_enabled,["beginner","intermediate","expert"])
	var rounds: int = state.minesweeper_rounds_left
	var motivation: int = state.get_stat("motivation")
	var selected: Dictionary = port.select_difficulty("expert",shown.value.board.revision)
	assert_true(selected.ok,str(selected))
	if not selected.ok: return
	assert_false(selected.value.settled)
	assert_eq(selected.value.board.width,22)
	assert_eq(selected.value.register.difficulty,"expert")
	assert_eq(state.minesweeper_rounds_left,rounds)
	assert_eq(state.get_stat("motivation"),motivation)


func test_terminal_dispatch_holds_the_unsettled_board_and_the_pump_settles_it_next() -> void:
	var owner := TerminalClearingOwner.new()
	owner.completion_calls.append({})
	var isolated := PORT.new()
	assert_true(isolated.configure(owner,issuer,state,catalog).ok)
	var initial: Dictionary = isolated.pull()
	assert_true(initial.ok,str(initial))
	var published: Dictionary = isolated.dispatch("reveal",1,initial.value.board.revision)
	assert_true(published.ok,str(published))
	assert_true(published.value.board.terminal)
	assert_true(published.value.board.custody)
	assert_false(published.value.settled,"dwm-634.1: the click returns the terminal board before settlement")
	assert_eq(published.value.actions,[])
	assert_eq(owner.completion_calls.size(),1,"only the seeded call exists: nothing settled inside the click")
	assert_true(isolated.has_pending_settlement())
	var settled: Dictionary = isolated.advance_preparation(published.value.board.revision)
	assert_true(settled.ok,str(settled))
	assert_true(settled.get("advanced",false),"the pump reports the settled view as a change")
	assert_true(settled.value.settled)
	assert_eq(settled.value.board,published.value.board,"settlement keeps the exact painted board")
	assert_eq(settled.value.actions,["new_board","assignments","rules"])
	assert_eq(owner.completion_calls.size(),2)
	assert_false(isolated.has_pending_settlement())
	assert_eq(isolated.advance_preparation(settled.value.board.revision),{"ok":true,"advanced":false})
