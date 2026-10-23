extends GutTest

const COORDINATOR := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const OLD_CHECKPOINT := preload("res://tests/support/FakeMinesweeperCheckpointPort.gd")
const GENERATION := preload("res://tests/support/FakeMinesweeperGenerationPort.gd")
const DURABLE_FIXTURE := preload("res://tests/unit/test_desktop_paid_replacement.gd")
const COMPOSER := preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const LAYOUT := {"schema_version": 1, "width": 3, "height": 3, "mine_count": 1, "mine_indices": [4]}

class StatePort extends "res://tests/support/FakeDesktopBoardStatePort.gd":
	var board_owner: RefCounted
	func capture_base_snapshot_input() -> Dictionary:
		return {"ok": true, "value": {"snapshot_input": {"desktop": {"board": board_owner.capture()},
			"gameplay": {"motivation": motivation, "rounds": rounds_left}}}}

var coordinator: RefCounted
var state: StatePort
var generator: RefCounted
var issuer: RefCounted
var durable: RefCounted

func before_each() -> void:
	coordinator = COORDINATOR.new()
	state = StatePort.new()
	state.board_owner = coordinator._board_state
	generator = GENERATION.new()
	issuer = ISSUER.new()
	assert_true(issuer.configure(ROOT_STORE.new("22".repeat(32), 1)).ok)
	state.identity_issuer = issuer
	assert_true(coordinator.configure(state, OLD_CHECKPOINT.new(), generator, issuer).ok)
	durable = DURABLE_FIXTURE.Durable.new()
	assert_true(coordinator.configure_durable_checkpoint(durable, COMPOSER, CONSEQUENCE.new()).ok)

func _request() -> Dictionary:
	var context: Dictionary = coordinator.get_preparation_context().value
	var issued: Dictionary = issuer.issue(&"transaction_id")
	var request := {"transaction_id": str(issued.value.token), "transaction_issuer_receipt": issued.value.issuer_receipt,
		"expected_identity": context.identity, "expected_revision": int(context.revision)}
	if context.action == "begin": request["difficulty_id"] = context.difficulty_id
	return request

func test_readiness_is_pure_and_never_pays_or_generates() -> void:
	var before: Dictionary = coordinator.get_state().value
	assert_eq(coordinator.get_preparation_context().value.action, "none")
	state.generation_capabilities = ["first_cell_safe", "forced_no_guess"]
	for index in 3: assert_eq(coordinator.get_preparation_context().value.action, "begin")
	assert_eq(coordinator.get_state().value, before)
	assert_eq(generator.call_log, [])
	assert_eq(durable.writes, 0)
	assert_eq(state.motivation, 7)
	assert_eq(state.rounds_left, 2)
	state.motivation = 0
	assert_eq(coordinator.get_preparation_context().value.action, "none")

func test_failed_begin_write_rolls_back_and_exact_retry_reuses_frozen_spec() -> void:
	state.generation_capabilities = ["first_cell_safe", "forced_no_guess"]
	var request := _request()
	var before: Dictionary = coordinator.get_state().value
	var disk_before: Dictionary = durable.disk.duplicate(true)
	durable.fail_write = true
	assert_false(coordinator.begin_debug_preparation(request).ok)
	assert_eq(coordinator.get_state().value, before)
	assert_eq(durable.disk, disk_before)
	assert_eq(durable.rollbacks, 1)
	assert_eq(generator.call_log.size(), 1)
	assert_false(coordinator.begin_debug_preparation(_request()).ok)
	assert_eq(generator.call_log.size(), 1)
	assert_true(coordinator.begin_debug_preparation(request).ok)
	assert_eq(generator.call_log.size(), 1, "Retry does not generate a replacement frontier")
	assert_eq(coordinator.get_state().value.phase, "PREPARING")
	assert_eq(durable.disk.desktop.board, coordinator.get_state().value)
	assert_eq(state.motivation, 7)
	assert_eq(state.rounds_left, 2)

func test_each_bounded_slice_is_saved_and_failed_certification_write_reuses_result() -> void:
	state.generation_capabilities = ["first_cell_safe", "forced_no_guess"]
	assert_true(coordinator.begin_debug_preparation(_request()).ok)
	var slices: Array[Dictionary] = [
		{"done": false, "frontier": {"cursor": 1}},
		{"done": true, "layout": LAYOUT, "forced_cell": 0, "proof_sha256": null}]
	generator.arm_search_slices(slices)
	assert_true(coordinator.run_debug_preparation_slice(_request()).ok)
	assert_eq(durable.disk.desktop.board.candidate.frontier, {"cursor": 1})
	var request := _request()
	var before: Dictionary = coordinator.get_state().value
	durable.fail_write = true
	assert_false(coordinator.run_debug_preparation_slice(request).ok)
	assert_eq(coordinator.get_state().value, before)
	var calls: int = generator.call_log.size()
	assert_true(coordinator.run_debug_preparation_slice(request).ok)
	assert_eq(generator.call_log.size(), calls)
	assert_eq(coordinator.get_state().value.phase, "PREPARED_UNSTARTED")
	assert_eq(coordinator.get_state().value.candidate.layout, LAYOUT)
	assert_eq(durable.disk.desktop.board, coordinator.get_state().value)
	assert_eq(coordinator.get_preparation_context().value.action, "none")
	assert_eq(state.motivation, 7)
	assert_eq(state.rounds_left, 2)

func test_generation_adapter_cannot_bypass_debug_certification() -> void:
	var adapter := preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new()
	assert_eq(adapter.materialize({"capability_ids": ["forced_no_guess"]}, 0).code, &"debug_preparation_required")
