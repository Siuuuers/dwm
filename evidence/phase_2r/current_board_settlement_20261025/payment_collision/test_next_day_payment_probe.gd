extends "res://tests/integration/test_scene_day_commit_ordering.gd"

func test_next_day_payment_probe() -> void:
	if not _setup(): return
	game.minesweeper_rounds_left = 2
	game.minesweeper_app_rounds_finished_today = 0
	var port = load("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd").new()
	if not _ok(port.configure(game, fixture.issuer, game.capture_desktop_identity_context), "live port"): return
	var coordinator = load("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd").new()
	coordinator._board_state = board
	var generator = load("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new()
	var checkpoint = load("res://tests/support/FakeMinesweeperCheckpointPort.gd").new()
	if not _ok(coordinator.configure(port, checkpoint, generator, fixture.issuer), "coordinator"): return
	var durable = load("res://tests/unit/test_desktop_paid_replacement.gd").Durable.new()
	if not _ok(coordinator.configure_durable_checkpoint(durable, load("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd"), consequence), "durable fixture seam"): return
	var entry: Dictionary = coordinator.get_entry_context("beginner")
	if not _ok(entry, "day one entry"): return
	var first_identity: Dictionary = entry.value.identity.duplicate(true)
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	var result: Dictionary = coordinator.reveal({"transaction_id": issued.value.token,
		"transaction_issuer_receipt": issued.value.issuer_receipt, "expected_identity": first_identity,
		"expected_revision": board.capture().revision, "difficulty_id": "beginner", "cell_index": 0})
	if not _ok(result, "actual first reveal"): return
	before = game.capture_run_snapshot_input().duplicate(true)
	result = game._prepare_scene_day_renewal(trigger, "TEST.target", fixture.bundle, FIXTURE.identity(fixture.lifecycle))
	if not _ok(result, "renew paid day"): return
	day_plan = result.value
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	if not _ok(lease, "day lease"): return
	_stage(lease.value.token)
	if not _ok(game._commit_scene_target_owned(), "actual day adoption"): return
	if not _ok(gate.release(&"causal_transaction", lease.value.token), "release"): return
	game.inventory["debug_key"] = 1
	entry = coordinator.get_entry_context("beginner")
	if not _ok(entry, "next day entry"): return
	issued = fixture.issuer.issue(&"transaction_id")
	var remaining: int = game.minesweeper_rounds_left
	result = coordinator.begin_debug_preparation({"transaction_id": issued.value.token,
		"transaction_issuer_receipt": issued.value.issuer_receipt, "expected_identity": entry.value.identity,
		"expected_revision": board.capture().revision, "difficulty_id": "beginner"})
	print("PAYMENT_PROBE ", JSON.stringify({"first": first_identity, "next": entry.value.identity,
		"result": result, "before_rounds": remaining, "after_rounds": game.minesweeper_rounds_left}))
	assert_ne(first_identity.causal_day_instance, entry.value.identity.causal_day_instance)
	assert_eq(first_identity.app_round_ordinal, entry.value.identity.app_round_ordinal)
	assert_eq(result.get("code"), &"paid_start_receipt_required")
