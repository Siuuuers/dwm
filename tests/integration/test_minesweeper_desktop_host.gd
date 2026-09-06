extends GutTest
## Real scene/router/host/board owners. Only automatic global Bootstrap mounting is isolated;
## generation and checkpoint use existing memory fixtures, with no production save writes.

const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const PANEL_PORT := preload("res://scripts/application/minesweeper/MinesweeperPanelPort.gd")
const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const STATE_PORT := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")

class IsolatedDesktop extends "res://scripts/ui/ComputerDesktop.gd":
	# Keep all production scene routing; prevent unrelated global Contacts/host auto-injection.
	func _configure_from_bootstrap() -> void:
		pass

var state
var host
var coordinator
var issuer
var root_store
var generation
var panel_port
var catalog
var viewport: SubViewport


func before_each() -> void:
	state = GAME_STATE.new()
	state.reset_game()
	state.set_stat("pressure", 0)
	host = HOST.new()
	host.reset(1)
	root_store = ROOT_STORE.new("42".repeat(32), 1)
	issuer = ISSUER.new()
	assert_true(issuer.configure(root_store).ok)
	var state_port := STATE_PORT.new()
	assert_true(state_port.configure(state, issuer, {
		"run_id": "private-run", "branch_id": "private-branch", "desktop_timeline_generation": 0,
		"causal_day_instance": "private-day",
	}).ok)
	generation = GENERATION.new()
	generation.arm_materialize({"schema_version": 1, "width": 8, "height": 8,
		"mine_indices": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "mine_count": 10})
	coordinator = COORDINATOR.new()
	assert_true(coordinator.configure(state_port, CHECKPOINT.new(), generation, issuer).ok)
	catalog = CATALOG.new()
	panel_port = PANEL_PORT.new()
	assert_true(panel_port.configure(coordinator, issuer, state, catalog).ok)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1024, 720)
	viewport.handle_input_locally = true
	add_child_autofree(viewport)


func after_each() -> void:
	state.free()


func _desktop(configured: bool = true) -> Control:
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(IsolatedDesktop)
	viewport.add_child(desktop)
	if configured:
		assert_true(desktop.configure_minesweeper(panel_port, null, null, host, 1).ok)
	return desktop


func _open_from_launcher(desktop: Control) -> Control:
	desktop.launcher_buttons[&"minesweeper"].pressed.emit()
	var app: Control = desktop.app_window_host.find_child("MinesweeperApp", false, false)
	assert_not_null(app)
	if app != null:
		assert_true(app.is_visible_in_tree())
		assert_eq(host.get_state().active_app_id, &"minesweeper")
		assert_false(desktop.icon_grid.visible)
	return app


func _reveal_first(app: Control) -> void:
	var grid: Control = app.panel.worksheet.grid
	grid.cell_action_requested.emit(&"reveal", 0, grid.projection.revision)
	assert_eq(coordinator.get_state().value.phase, "ACTIVE_VISIBLE")
	assert_eq(state.minesweeper_rounds_left, 1)
	assert_eq(app.panel.register.public_view.rounds, 1)


func test_launcher_reveal_home_reopen_retains_real_session_and_cached_grid() -> void:
	var desktop := _desktop()
	var app := _open_from_launcher(desktop)
	if app == null: return
	await get_tree().process_frame
	_reveal_first(app)
	var grid: Control = app.panel.worksheet.grid
	grid.cell_action_requested.emit(&"flag", 2, grid.projection.revision)
	app.panel.dock.action_requested.emit(&"flag")
	grid.focus_cell(2)
	var retained_cell: Control = grid.cell_nodes[2]
	var board_before: Dictionary = coordinator.get_state().value.board
	var state_before: Dictionary = state.to_save_dict().duplicate(true)
	var generation_before: Array = generation.call_log.duplicate(true)
	assert_true(desktop.return_home().ok)
	assert_eq(coordinator.get_state().value.phase, "ACTIVE_SUSPENDED")
	assert_null(host.get_state().active_app_id)
	assert_false(app.visible)
	assert_true(desktop.icon_grid.visible)
	assert_eq(coordinator.get_state().value.board, board_before)
	var reopened: Dictionary = desktop.open_app(&"minesweeper")
	assert_true(reopened.ok)
	if not reopened.ok: return
	assert_same(reopened.value.app, app)
	assert_same(app.panel.worksheet.grid, grid)
	assert_same(grid.cell_nodes[2], retained_cell)
	assert_eq(coordinator.get_state().value.phase, "ACTIVE_VISIBLE")
	assert_eq(coordinator.get_state().value.board, board_before)
	assert_eq(grid.projection.cells[2].mark, "flag")
	assert_eq(grid.focused_index, 2)
	assert_eq(grid.mode, &"flag")
	assert_eq(app.panel.register.public_view.no_flag, "lost")
	assert_eq(state.to_save_dict(), state_before)
	assert_eq(generation.call_log, generation_before)


func test_app_back_suspends_once_before_host_hides_and_reopens_same_instance() -> void:
	var desktop := _desktop()
	var app := _open_from_launcher(desktop)
	if app == null: return
	_reveal_first(app)
	var board_before: Dictionary = coordinator.get_state().value.board
	var counter_before: int = root_store.next_counter
	app.hide_window()
	assert_eq(root_store.next_counter, counter_before + 1, "App Back and host callback share one suspension.")
	assert_eq(coordinator.get_state().value.phase, "ACTIVE_SUSPENDED")
	assert_null(host.get_state().active_app_id)
	assert_false(app.visible)
	assert_true(desktop.icon_grid.visible)
	var reopened: Dictionary = desktop.open_app(&"minesweeper")
	assert_true(reopened.ok)
	if not reopened.ok: return
	assert_same(reopened.value.app, app)
	assert_eq(root_store.next_counter, counter_before + 2, "Reopening resumes exactly once.")
	assert_eq(coordinator.get_state().value.phase, "ACTIVE_VISIBLE")
	assert_eq(coordinator.get_state().value.board, board_before)
	assert_eq(state.minesweeper_rounds_left, 1)


func test_information_sheets_block_host_home_and_app_back_without_commands() -> void:
	var desktop := _desktop()
	var app := _open_from_launcher(desktop)
	if app == null: return
	_reveal_first(app)
	for action: StringName in [&"rules", &"assignments"]:
		app.panel.dock.action_requested.emit(action)
		assert_not_null(app.panel.worksheet.information_sheet)
		if app.panel.worksheet.information_sheet == null: continue
		var counter_before: int = root_store.next_counter
		var board_before: Dictionary = coordinator.get_state().value
		assert_true(desktop.home_button.disabled)
		assert_false(desktop.return_home().ok)
		app.hide_window()
		assert_true(app.visible)
		assert_false(desktop.icon_grid.visible)
		assert_eq(host.get_state().active_app_id, &"minesweeper")
		assert_eq(root_store.next_counter, counter_before)
		assert_eq(coordinator.get_state().value, board_before)
		app.panel.worksheet.information_sheet.return_requested.emit()
		assert_false(desktop.home_button.disabled)
	assert_true(desktop.return_home().ok)


func test_stale_home_keeps_app_visible_and_host_active_without_allocating_or_spending() -> void:
	var desktop := _desktop()
	var app := _open_from_launcher(desktop)
	if app == null: return
	_reveal_first(app)
	var snapshot: Dictionary = coordinator.get_state().value
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(coordinator.set_flag({
		"transaction_id": issued.value.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"expected_identity": snapshot.identity, "expected_revision": snapshot.revision, "cell_index": 2, "flagged": true,
	}).ok)
	var counter_before: int = root_store.next_counter
	var state_before: Dictionary = state.to_save_dict().duplicate(true)
	var board_before: Dictionary = coordinator.get_state().value
	assert_false(desktop.return_home().ok)
	assert_true(app.visible)
	assert_false(desktop.icon_grid.visible)
	assert_eq(host.get_state().active_app_id, &"minesweeper")
	assert_eq(coordinator.get_state().value, board_before)
	assert_eq(root_store.next_counter, counter_before)
	assert_eq(state.to_save_dict(), state_before)
	assert_eq(app.panel.worksheet.grid.projection.cells[2].mark, "flag", "Refusal refreshes safe current facts.")
	assert_true(desktop.return_home().ok, "A fresh explicit retry may suspend the current board.")


func test_unsettled_terminal_cannot_hide_the_host_or_spend_another_round() -> void:
	var desktop := _desktop()
	var app := _open_from_launcher(desktop)
	if app == null: return
	_reveal_first(app)
	var grid: Control = app.panel.worksheet.grid
	grid.cell_action_requested.emit(&"reveal", 1, grid.projection.revision)
	assert_true(app.panel.public_view.board.custody)
	var counter_before: int = root_store.next_counter
	var state_before: Dictionary = state.to_save_dict().duplicate(true)
	assert_false(desktop.return_home().ok)
	app.hide_window()
	assert_true(app.visible)
	assert_eq(host.get_state().active_app_id, &"minesweeper")
	assert_eq(root_store.next_counter, counter_before)
	assert_eq(state.to_save_dict(), state_before)


func test_unconfigured_production_route_remains_unavailable_without_an_injected_ready_port() -> void:
	var desktop := _desktop(false)
	var counter_before: int = root_store.next_counter
	var state_before: Dictionary = state.to_save_dict().duplicate(true)
	assert_eq(desktop.open_app(&"minesweeper"), {"ok": false, "code": &"desktop_app_unavailable"})
	assert_eq(desktop.app_window_host.get_child_count(), 0)
	assert_true(desktop.icon_grid.visible)
	assert_null(host.get_state().active_app_id)
	assert_eq(root_store.next_counter, counter_before)
	assert_eq(state.to_save_dict(), state_before)


func test_desktop_rejects_port_and_host_rebinding_without_replacing_working_owners() -> void:
	var desktop := _desktop()
	assert_true(desktop.configure_minesweeper(panel_port, null, null, host, 1).ok)
	var replacement := PANEL_PORT.new()
	assert_true(replacement.configure(coordinator, issuer, state, catalog).ok)
	assert_eq(desktop.configure_minesweeper(replacement, null, null, host, 1).code, &"minesweeper_already_configured")
	var other_host := HOST.new()
	other_host.reset(1)
	assert_eq(desktop.configure_minesweeper(panel_port, null, null, other_host, 1).code, &"desktop_owner_mismatch")
	var app := _open_from_launcher(desktop)
	if app == null: return
	_reveal_first(app)
	assert_null(other_host.get_state().active_app_id)
	assert_eq(host.get_state().active_app_id, &"minesweeper")
