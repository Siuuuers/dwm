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
	prepared = game._prepare_scene_day_renewal(trigger, "TEST.target", fixture.bundle, identity)
	if not _ok(prepared, "day preparation"): return false
	day_plan = prepared.value
	assert_eq(game.capture_run_snapshot_input(), before, "allocation does not adopt gameplay or board")
	transport = CheckpointTransport.new()
	transport.storage = fixture.storage
	native = NativeEntry.new()
	game._narrative_checkpoint_port = transport
	game._scene_event_bridge = native
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
