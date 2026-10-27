extends "res://addons/gut/test.gd"
## Bounded ordering integration: real GameState day preparation/adoption, issuer,
## allocator, lifecycle, board and consequence owners. Native staging is injected;
## checkpoint transport uses real JsonFileStorage over retained FakeFileOps. The
## connected creator/loader separately proves full Save9 and native restoration.
const GAME := preload("res://autoload/GameState.gd")
const FIXTURE := preload("res://tests/support/SceneTransitionIdentityFixture.gd")
const BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

class NativeEntry extends RefCounted:
	var refuse := false
	var calls := 0
	var reading := {"schema_version": 5, "player_progress": {"story_day": 1}}
	func capture_reading_checkpoint(_include_native: bool) -> Dictionary:
		return {"ok": true, "value": {"reading_session": reading.duplicate(true)}}
	func commit_day_entry(_staged: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": not refuse, "code": &"TEST.native_refused"}

class CheckpointTransport extends RefCounted:
	var storage: RefCounted
	var refuse := false
	var writes := 0
	func commit_scene_event(candidate: Dictionary, checkpoint: Dictionary) -> Dictionary:
		if refuse: return {"ok": false, "code": &"TEST.before_write_refused"}
		var encoded: Dictionary = WRITER.stringify({"candidate": candidate, "checkpoint": checkpoint})
		if not encoded.ok: return encoded
		var written: Dictionary = storage.write_atomic("day-target.json", encoded.value, STRICT.parse_object)
		if written.get("ok", false): writes += 1
		return written

var game: Node
var fixture: RefCounted
var board: RefCounted
var consequence: RefCounted
var gate: RefCounted
var transport: RefCounted
var native: RefCounted
var before: Dictionary
var day_plan: Dictionary
var trigger: Dictionary

func after_each() -> void:
	if is_instance_valid(game): game.free()

func _ok(result: Dictionary, context: String) -> bool:
	assert_true(result.get("ok", false), context + ": " + str(result))
	return result.get("ok", false)

func _desktop() -> Dictionary:
	return {"board": board.capture(), "consequence": consequence.capture().value.state}

func _setup() -> bool:
	fixture = FIXTURE.new()
	var next: Dictionary = fixture.bundle.scene_programme.entries[0].duplicate(true)
	next.entry_id = "TEST.next"
	next.markers = []
	fixture.bundle.scene_programme.entries.push_front(next)
	fixture.bundle.scene_programme["story_days"] = {"TEST.next": 2, "TEST.scene": 1}
	fixture.bundle.targets[0].target.entry_id = "TEST.next"
	fixture.bundle.targets[0].target.label = "TEST.next"
	if not _ok(fixture.setup(), "real allocator fixture"): return false
	var identity: Dictionary = FIXTURE.identity(fixture.lifecycle)
	game = GAME.new()
	game._identity_issuer = fixture.issuer
	gate = GATE.new()
	if not _ok(game.configure_mutation_gate(gate), "gate"): return false
	var lifecycle := identity.duplicate(true)
	lifecycle.merge({"restore_provenance": null, "state": "PLAYING", "scene_assignment": {
		"creation_transaction_id": "TEST.creation", "form": "sweet", "predecessor_assignment_sha256": null,
		"predecessor_run_id": null, "rng_nonce": 0, "ruleset_id": "scene.new_run.alternating.v1", "selection_kind": "initial_random"}})
	if not _ok(game._run_lifecycle.configure_scene_issuer(fixture.issuer), "lifecycle issuer"): return false
	if not _ok(game._run_lifecycle.commit_restore(lifecycle), "scene lifecycle"): return false
	game._apply_gameplay_silent(GAME.make_scene_new_run_gameplay())
	game.minesweeper_rounds_left = 0
	game.minesweeper_app_rounds_finished_today = 2
	game.minesweeper_money_earned_today = 12
	game.money = 12
	game._scene_snapshot_references = {"registration_sha256": "TEST", "active_occurrence_id": "TEST.source", "active_admission_receipt_id": "TEST.source"}
	game._command_receipts = fixture.command_receipts.duplicate(true)
	game._live_session_active = true
	game._live_session_run_id = identity.run_id
	game._run_configuration_installed = true
	board = BOARD.new()
	if not _ok(board.configure_scene_payments(fixture.issuer), "board issuer"): return false
	var shell: Dictionary = board.prepare_unpaid_shell({"transaction_id": "TEST.shell", "expected_revision": 0,
		"identity": null, "request_fingerprint": "TEST.shell"}, "beginner", {"flagged_indices": [], "actions": []})
	if not _ok(shell, "unfinished unpaid shell"): return false
	if not _ok(board.commit(shell.value.candidate), "install shell"): return false
	consequence = CONSEQUENCE.new()
	var empty: Dictionary = CONSEQUENCE.make_empty({"causal_day_instance": identity.causal_day_instance,
		"causal_day_instance_issuer_receipt": identity.causal_day_instance_issuer_receipt})
	if not _ok(empty, "consequence empty"): return false
	var prepared: Dictionary = consequence.prepare_restore(empty.value.state)
	if not _ok(prepared, "consequence prepare"): return false
	if not _ok(consequence.commit(prepared.value.candidate), "consequence restore"): return false
	if not _ok(game.configure_desktop_snapshot_provider(_desktop), "desktop provider"): return false
	if not _ok(game.configure_scene_day_runtime(fixture.port, board, consequence), "day binding"): return false
	before = game.capture_run_snapshot_input().duplicate(true)
	trigger = fixture.command_receipts[fixture.event.command_id].duplicate(true)
	native = NativeEntry.new()
	game._scene_event_bridge = native
	prepared = game._prepare_scene_day_renewal(trigger, "TEST.target", fixture.bundle, identity)
	if not _ok(prepared, "day preparation"): return false
	day_plan = prepared.value
	assert_eq(game.capture_run_snapshot_input(), before, "allocation does not adopt gameplay or board")
	transport = CheckpointTransport.new()
	transport.storage = fixture.storage
	game._narrative_checkpoint_port = transport
	return true

func _stage(lease: String) -> void:
	var candidate := before.duplicate(true)
	candidate.lifecycle = day_plan.lifecycle.duplicate(true)
	candidate.gameplay = day_plan.gameplay.duplicate(true)
	candidate.desktop = day_plan.desktop.duplicate(true)
	candidate.scene.active_occurrence_id = "TEST.target"
	candidate.scene.active_admission_receipt_id = "TEST.target"
	game._scene_entry_operation = {"lease": lease, "live_session": game._live_session_fact(),
		"binding": {"target_id": "TEST.target", "trigger_command_id": fixture.event.command_id},
		"prior_receipts": before.command_receipts.duplicate(true), "prior_input": before.duplicate(true),
		"day_plan": day_plan.duplicate(true), "candidate": candidate,
		"staged": {"narrative_checkpoint": {"TEST": "staged target"}}, "admitted": {"entry_id": "TEST.next"}}

func test_refused_checkpoint_retains_board_counters_and_identity_then_retry_adopts_once() -> void:
	if not _setup(): return
	var allocated_root: Dictionary = fixture.issuer.capture_root()
	var again: Dictionary = game._prepare_scene_day_renewal(trigger, "TEST.target", fixture.bundle, FIXTURE.identity(fixture.lifecycle))
	if not _ok(again, "same day preparation retry"): return
	assert_eq(again.value, day_plan)
	assert_eq(fixture.issuer.capture_root(), allocated_root, "no second allocation")
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	if not _ok(lease, "lease"): return
	_stage(lease.value.token)
	transport.refuse = true
	var refused: Dictionary = game._commit_scene_target_owned()
	assert_false(refused.get("ok", false))
	assert_eq(refused.get("code"), &"TEST.before_write_refused")
	assert_eq(game.capture_run_snapshot_input(), before, "all live participants retain the old day")
	assert_eq(native.calls, 0)
	assert_eq(transport.writes, 0)
	transport.refuse = false
	if not _ok(game._commit_scene_target_owned(), "retry target checkpoint"): return
	assert_eq(transport.writes, 1)
	assert_eq(native.calls, 1)
	assert_eq(game.money, 12, "abandonment pays nothing")
	assert_eq(game.minesweeper_rounds_left, 2)
	assert_eq(game.minesweeper_app_rounds_finished_today, 0)
	assert_eq(game.minesweeper_money_earned_today, 0)
	assert_eq(board.capture().phase, "NONE")
	assert_eq(board.capture().revision, before.desktop.board.revision + 1)
	assert_eq(game._run_lifecycle.to_dict().causal_day_instance, day_plan.identity.causal_day_instance)
	assert_eq(consequence.capture().value.state.causal_day_instance, day_plan.identity.causal_day_instance)
	assert_eq(fixture.issuer.capture_root(), allocated_root)
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)

func test_committed_checkpoint_native_failure_latches_fatal_and_retains_recoverable_target() -> void:
	if not _setup(): return
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	if not _ok(lease, "lease"): return
	_stage(lease.value.token)
	native.refuse = true
	var failed: Dictionary = game._commit_scene_target_owned()
	assert_false(failed.get("ok", false))
	assert_true(failed.get("committed", false))
	assert_eq(failed.get("code"), &"scene_entry_activation_failed")
	assert_false(gate.guard_external(&"test").ok, "fatal state bars another command")
	var reread: Dictionary = fixture.storage.read_text("day-target.json")
	if not _ok(reread, "durable target bytes"): return
	var parsed: Dictionary = STRICT.parse_object(reread.value)
	if not _ok(parsed, "durable target parse"): return
	var saved: Dictionary = parsed.value.candidate
	var recovered_lifecycle := LIFECYCLE.new()
	assert_true(recovered_lifecycle.configure_scene_issuer(fixture.issuer).ok)
	assert_true(recovered_lifecycle.commit_restore(saved.lifecycle).ok)
	var recovered_board := BOARD.new()
	var prepared: Dictionary = recovered_board.prepare_restore_scene(saved.desktop.board, fixture.issuer)
	if not _ok(prepared, "fresh owner board preparation"): return
	assert_true(recovered_board.commit(prepared.value.candidate).ok)
	var recovered_consequence := CONSEQUENCE.new()
	prepared = recovered_consequence.prepare_restore(saved.desktop.consequence)
	if not _ok(prepared, "fresh consequence preparation"): return
	assert_true(recovered_consequence.commit(prepared.value.candidate).ok)
	assert_eq(recovered_lifecycle.to_dict().causal_day_instance, day_plan.identity.causal_day_instance)
	assert_eq(recovered_consequence.capture().value.state.causal_day_instance, day_plan.identity.causal_day_instance)
	assert_eq(recovered_board.capture().phase, "NONE")
	assert_eq(saved.gameplay.minesweeper_rounds_left, 2)
	assert_eq(saved.gameplay.minesweeper_money_earned_today, 0)
	assert_eq(saved.gameplay.money, 12)
	assert_eq(transport.writes, 1)
	assert_eq(native.calls, 1)


# Payment integration uses production generation and GameState allowance ownership.
# Checkpoint transport remains the existing in-memory seam; this is not full Save9 E2E.
func _payment_coordinator() -> RefCounted:
	var port = preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd").new()
	if not _ok(port.configure(game, fixture.issuer, game.capture_desktop_identity_context), "live payment port"): return null
	if not _ok(port.configure_consequence_state_port(consequence), "live consequence port"): return null
	var coordinator = preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd").new()
	coordinator._board_state = board
	var generator = preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new()
	var checkpoint = preload("res://tests/support/FakeMinesweeperCheckpointPort.gd").new()
	if not _ok(coordinator.configure(port, checkpoint, generator, fixture.issuer), "payment coordinator"): return null
	var durable = preload("res://tests/unit/test_desktop_paid_replacement.gd").Durable.new()
	if not _ok(coordinator.configure_durable_checkpoint(durable,
		preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd"), consequence), "payment checkpoint"): return null
	return coordinator


func _payment_request(coordinator: RefCounted, difficulty: String = "") -> Dictionary:
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	assert_true(issued.ok)
	var state: Dictionary = board.capture()
	var request := {"transaction_id": issued.value.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"expected_identity": state.identity, "expected_revision": state.revision}
	if not difficulty.is_empty():
		request["difficulty_id"] = difficulty
		if state.phase in ["NONE", "UNPAID_UNSTARTED"]:
			var entry: Dictionary = coordinator.get_entry_context(difficulty)
			assert_true(entry.ok, str(entry))
			request.expected_identity = entry.value.identity
	return request


func _certify_payment_board(coordinator: RefCounted, paid: bool, remaining: int) -> bool:
	# The production operation budget bounds preparation; permit enough slices for fallback.
	for _slice in 2048:
		if board.capture().phase != "PREPARING": break
		if not _ok(coordinator.run_debug_preparation_slice(_payment_request(coordinator)), "production Debug slice"): return false
		assert_eq(board.capture().round_paid, paid)
		assert_eq(game.minesweeper_rounds_left, remaining, "preparation never debits allowance")
	assert_eq(board.capture().phase, "PREPARED_UNSTARTED")
	return board.capture().phase == "PREPARED_UNSTARTED"


func test_next_day_debug_round_one_does_not_inherit_yesterdays_payment() -> void:
	if not _setup(): return
	game.minesweeper_rounds_left = 2
	game.minesweeper_app_rounds_finished_today = 0
	var coordinator := _payment_coordinator()
	if coordinator == null: return
	var request := _payment_request(coordinator, "beginner")
	var first_identity: Dictionary = request.expected_identity.duplicate(true)
	request["cell_index"] = 0
	if not _ok(coordinator.reveal(request), "Day1 paid Reveal"): return
	assert_true(board.capture().round_paid)
	assert_false(board.capture().board.has("paid_start_receipt"))
	assert_eq(board.capture().board.spec.difficulty_id, "beginner")
	assert_eq(game.minesweeper_rounds_left, 1)
	before = game.capture_run_snapshot_input().duplicate(true)
	var renewal: Dictionary = game._prepare_scene_day_renewal(trigger, "TEST.target", fixture.bundle, FIXTURE.identity(fixture.lifecycle))
	if not _ok(renewal, "renew paid day"): return
	day_plan = renewal.value
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	if not _ok(lease, "day lease"): return
	_stage(lease.value.token)
	if not _ok(game._commit_scene_target_owned(), "actual day adoption"): return
	if not _ok(gate.release(&"causal_transaction", lease.value.token), "release day lease"): return
	assert_eq(board.capture().phase, "NONE")
	assert_false(board.capture().round_paid, "discarding yesterday's board clears its payment")
	assert_eq(game.minesweeper_rounds_left, 2)
	game.inventory["debug_key"] = 1
	request = _payment_request(coordinator, "beginner")
	assert_eq(request.expected_identity.run_id, first_identity.run_id)
	assert_eq(request.expected_identity.app_round_ordinal, 1)
	assert_eq(request.expected_identity.app_round_ordinal, first_identity.app_round_ordinal)
	assert_ne(request.expected_identity.causal_day_instance, first_identity.causal_day_instance)
	if not _ok(coordinator.begin_debug_preparation(request), "unpaid next-day Debug preparation"): return
	assert_false(board.capture().round_paid)
	assert_eq(game.minesweeper_rounds_left, 2)
	if not _certify_payment_board(coordinator, false, 2): return
	request = _payment_request(coordinator, "beginner")
	request["cell_index"] = board.capture().candidate.forced_cell
	var revealed: Dictionary = coordinator.reveal(request)
	if not _ok(revealed, "Day2 first Reveal"): return
	assert_true(board.capture().round_paid)
	assert_eq(game.minesweeper_rounds_left, 1, "exactly one Day2 debit")
	var after: Dictionary = board.capture()
	assert_eq(coordinator.reveal(request), revealed, "acknowledged retry returns the same result")
	assert_eq(board.capture(), after)
	assert_eq(game.minesweeper_rounds_left, 1, "retry cannot debit twice")


func _restore_payment_board(saved: Dictionary) -> bool:
	var player := saved.duplicate(true)
	player.erase("command_receipts")
	var encoded: Dictionary = WRITER.stringify(player)
	if not _ok(encoded, "encode payment snapshot"): return false
	var decoded: Dictionary = STRICT.parse_object(encoded.value)
	if not _ok(decoded, "decode payment snapshot"): return false
	var restored := BOARD.new()
	var participant = preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(restored, fixture.issuer)
	var prepared: Dictionary = participant.prepare({"schema_version": 9, "state": decoded.value})
	if not _ok(prepared, "prepare fresh payment owner"): return false
	if not _ok(participant.apply_silent(prepared.value.board_plan), "adopt restored payment board"): return false
	if not _ok(participant.finalize(), "finalize payment participant"): return false
	var restored_live: Dictionary = restored.capture()
	assert_true(restored_live.command_receipts.is_empty(), "player restore starts a fresh live command session")
	restored_live.erase("command_receipts")
	assert_eq(WRITER.stringify(restored_live).value, encoded.value, "serialized current state stays byte-equal")
	board = restored
	# Fixture replaces its participant owner; the snapshot-provider callable reads this same board.
	game._scene_day_board = board
	return true


func test_paid_debug_preparing_and_certified_restore_preserve_spec_and_never_charge_again() -> void:
	if not _setup(): return
	game.minesweeper_rounds_left = 2
	game.minesweeper_app_rounds_finished_today = 0
	var coordinator := _payment_coordinator()
	if coordinator == null: return
	var request := _payment_request(coordinator, "beginner")
	request["cell_index"] = 0
	if not _ok(coordinator.reveal(request), "original paid Reveal"): return
	var original_identity: Dictionary = board.capture().identity.duplicate(true)
	game.inventory["debug_key"] = 1
	if not _ok(coordinator.replace_board(_payment_request(coordinator, "beginner")), "paid F5 replacement"): return
	assert_eq(board.capture().identity, original_identity)
	assert_true(board.capture().round_paid)
	if not _ok(coordinator.begin_debug_preparation(_payment_request(coordinator, "beginner")), "paid Debug preparation"): return
	var preparing: Dictionary = board.capture()
	assert_eq(preparing.phase, "PREPARING")
	assert_true(preparing.round_paid)
	assert_false(preparing.candidate.has("paid_start_receipt"))
	assert_eq(game.minesweeper_rounds_left, 1)
	if not _restore_payment_board(preparing): return
	# Changed live inputs cannot reconstruct or replace the frozen recipe on restoration.
	game.inventory.erase("debug_key")
	game.minesweeper_selected_difficulty = "expert"
	coordinator = _payment_coordinator()
	if coordinator == null: return
	assert_eq(board.capture().candidate.spec, preparing.candidate.spec)
	assert_eq(WRITER.stringify(board.capture().candidate.frontier).value,
		WRITER.stringify(preparing.candidate.frontier).value)
	if not _certify_payment_board(coordinator, true, 1): return
	var certified: Dictionary = board.capture()
	assert_false(certified.candidate.has("paid_start_receipt"))
	if not _restore_payment_board(certified): return
	coordinator = _payment_coordinator()
	if coordinator == null: return
	request = _payment_request(coordinator, "beginner")
	request["cell_index"] = certified.candidate.forced_cell
	if not _ok(coordinator.reveal(request), "restored paid certified Reveal"): return
	assert_true(board.capture().round_paid)
	assert_eq(board.capture().board.spec, preparing.candidate.spec)
	assert_eq(board.capture().identity, original_identity)
	assert_eq(game.minesweeper_rounds_left, 1, "restored paid Reveal consumes no further allowance")


func test_scene_first_reveal_ignores_storage_failure_and_consumes_allowance_once() -> void:
	if not _setup(): return
	game.minesweeper_rounds_left = 2
	game.minesweeper_app_rounds_finished_today = 0
	var coordinator := _payment_coordinator()
	if coordinator == null: return
	var request := _payment_request(coordinator, "beginner")
	request["cell_index"] = 0
	var durable: RefCounted = coordinator._durable_checkpoint_port
	var prior_disk: Dictionary = durable.disk.duplicate(true)
	var prior_journal: Dictionary = durable.journal.duplicate(true)
	durable.fail_write = true
	var retried: Dictionary = coordinator.reveal(request)
	if not _ok(retried, "first Reveal publishes live despite unavailable storage"): return
	assert_eq(durable.prepares, 0)
	assert_eq(durable.writes, 0)
	assert_eq(durable.disk, prior_disk)
	assert_eq(durable.journal, prior_journal)
	assert_true(durable.fail_write, "no write consumed the configured storage fault")
	assert_eq(retried, {"ok": true, "code": &"first_reveal_committed",
		"value": {"revision": board.capture().revision}, "receipt": {}},
		"genuine live retry retains only its acknowledgement, not a board/payment/publication archive")
	assert_true(board.capture().round_paid)
	assert_eq(game.minesweeper_rounds_left, 1)
	assert_eq(coordinator.reveal(request), retried)
	assert_eq(game.minesweeper_rounds_left, 1)

func test_recovered_story_day_highwater_skips_renewal_for_already_reached_day() -> void:
	if not _setup(): return
	var retained: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	for reading: Dictionary in [
		{"schema_version": 5, "player_progress": {"story_day": 2}},
		{"schema_version": 7, "story_day": 3}]:
		native.reading = reading
		var repeated: Dictionary = game._prepare_scene_day_renewal(trigger, "TEST.target",
			fixture.bundle, FIXTURE.identity(fixture.lifecycle))
		if not _ok(repeated, "recovered day already reached"): return
		assert_eq(repeated.value, {}, "no renewal plan or new causal day")
		assert_eq(game.capture_run_snapshot_input(), retained, "reading fallback preserves board, counters and identity")
