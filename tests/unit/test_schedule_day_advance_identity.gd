extends "res://addons/gut/test.gd"

const GAME := preload("res://autoload/GameState.gd")
const PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const ALLOCATOR := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const RECEIPTS := preload("res://tests/support/DayResolutionReceiptFixtures.gd")
const VIEW_FIXTURE := preload("res://tests/support/ScheduleRestoreFixture.gd")

class Manager extends RefCounted:
	var _journal := JOURNAL.new()
	var _storage: RefCounted
	var _restore_participants := {}

class Checkpoint extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var reject_once := false
	var saved_inputs: Dictionary = {}
	func prepare(inputs: Dictionary, kind: StringName, disk: Dictionary) -> Dictionary:
		saved_inputs = inputs.duplicate(true)
		return super.prepare(inputs, kind, disk)
	func commit(candidate: Dictionary) -> Dictionary:
		if reject_once:
			reject_once = false
			return {"ok": false, "code": &"injected_checkpoint_commit_failure"}
		return super.commit(candidate)

func _new_root(files: Object, suffix: String = "11") -> Object:
	var root := ROOT.new()
	assert_true(root.configure(STORAGE.new("schedule-day-root", files),
		preload("res://tests/support/FakeDesktopNamespaceSource.gd").new(suffix.repeat(32))).get("ok", false))
	var loaded: Dictionary = root.load_or_create()
	assert_true(loaded.get("ok", false), str(loaded))
	return root

static func _start_sources(resolution_id: String, day: int, causal: String) -> Array:
	var facts := {"role": "day_resolution.start", "resolution_id": resolution_id,
		"source_day": day, "causal_day_instance": causal, "schedule_commit_receipt_id": null,
		"board_fate_receipt_id": null, "schedule_entry_ids": []}
	var sources: Array = []
	for key: String in facts:
		sources.append(key + "=" + str(preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(facts[key]).value))
	sources.sort()
	return sources

func _wired(day: int = 1, restored: Dictionary = {}, saved_files: Dictionary = {}) -> Dictionary:
	var files := FakeFileOps.new(saved_files)
	var root: Object = _new_root(files)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(root).get("ok", false))
	var allocator := ALLOCATOR.new()
	assert_true(allocator.configure(issuer).get("ok", false))
	var game: Node = GAME.new()
	autofree(game)
	game.reset_game()
	if restored.is_empty():
		var source: Dictionary = root.issue(&"causal_day_instance").value.issuer_receipt
		var transaction: Dictionary = root.issue(&"transaction_id").value.issuer_receipt
		game._run_lifecycle.reset("schedule-run", "schedule-branch", 0, str(source.token),
			{"causal_day_instance_issuer_receipt": source}, false)
		var lifecycle: Dictionary = game._run_lifecycle.to_dict()
		lifecycle["day"] = day
		var prepared: Dictionary = game._run_lifecycle.prepare_restore(lifecycle)
		assert_true(prepared.get("ok", false), str(prepared))
		assert_true(game._run_lifecycle.commit_restore(prepared.value.candidate).get("ok", false))
		# A real root-derived start is the persisted prerequisite; earlier semantic stages are
		# already completed fixtures so this test isolates the actual increment/save boundary.
		var child: Dictionary = issuer.derive_child({"parent_receipt_id": transaction.receipt_id,
			"child_kind": "day_resolution_stage", "ordinal": 0,
			"source_ids": _start_sources(str(transaction.token), day, str(source.token))})
		assert_true(child.get("ok", false), str(child))
		var start := {"receipt_id": child.value.child_id, "receipt_provenance": child.value.provenance,
			"resolution_id": transaction.token, "source_day": day, "causal_day_instance": source.token,
			"schedule_commit_receipt_id": null, "board_fate_receipt_id": null, "schedule_entry_ids": []}
		assert_true(game._run_lifecycle.begin_day_resolution(str(transaction.token), {"entries": []}, [], null, null,
			{"command_id": "done.fixture", "resolution_issuer_receipt": transaction,
				"day_resolution_start_receipt": start}).get("ok", false))
		if day < 7:
			while true:
				var next: Dictionary = game._run_lifecycle.resume_resolution()
				if str(next.value.stage.stage_id) == "increment_day": break
				var begun: Dictionary = game._run_lifecycle.begin_next_stage()
				assert_true(game._run_lifecycle.complete_active_stage(str(begun.value.stage.transaction_id),
					RECEIPTS.for_stage(str(begun.value.stage.stage_id), day)).get("ok", false))
	else:
		var prepared: Dictionary = game._run_lifecycle.prepare_restore(restored.lifecycle)
		assert_true(prepared.get("ok", false), str(prepared))
		assert_true(game._run_lifecycle.commit_restore(prepared.value.candidate).get("ok", false))
	var current: Dictionary = game._run_lifecycle.to_dict()
	var view_fixture: Dictionary = VIEW_FIXTURE.create(issuer)
	assert_true(view_fixture.get("ok", false), str(view_fixture))
	var view: Object = view_fixture.value.view
	assert_true(view.open_day(int(current.day), str(current.causal_day_instance)).get("ok", false))
	var board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	var consequence := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()
	var empty: Dictionary = consequence.make_empty({"causal_day_instance": current.causal_day_instance,
		"causal_day_instance_issuer_receipt": current.causal_day_instance_issuer_receipt})
	assert_true(consequence.commit(consequence.prepare_restore(empty.value.state).value.candidate).get("ok", false))
	game._desktop_snapshot = {"board": board.capture(), "consequence": consequence.capture().value.state}
	var port := PORT.new(game)
	port._identity_issuer = issuer
	assert_true(port.configure_day_advance_owners(view, board, consequence).get("ok", false))
	if not restored.is_empty():
		assert_true(port.commit(restored).get("ok", false))
	var manager := Manager.new()
	manager._storage = STORAGE.new("schedule-day-save", files)
	manager._restore_participants = {"schedule_view": view_fixture.value.participant}
	assert_true(manager._journal.reset(str(current.run_id)).get("ok", false))
	var gate := GATE.new()
	var checkpoint := Checkpoint.new(manager)
	assert_true(checkpoint.configure_fatal_latch(gate).get("ok", false))
	# A cold owner must reconcile the actual document before reading a rollback backup,
	# and seed the journal from that document so later checkpoints keep its sequence/history.
	var reconciled: Dictionary = manager._storage.reconcile("autosave.json", checkpoint._validate_document_text)
	assert_true(reconciled.get("ok", false), str(reconciled))
	if reconciled.get("ok", false) and reconciled.get("exists", false):
		var seeded: Dictionary = manager._journal.prepare_seed(reconciled.value, reconciled.value.current_snapshot)
		assert_true(seeded.get("ok", false), str(seeded))
		if seeded.get("ok", false):
			assert_true(manager._journal.commit_prepared(seeded.value.candidate).get("ok", false))
	var coordinator := COORDINATOR.new()
	assert_true(coordinator.configure(port, checkpoint, gate).get("ok", false))
	assert_true(coordinator.configure_day_advance_identity_port(allocator).get("ok", false))
	coordinator._run_id = str(current.run_id)
	return {"files": files, "root": root, "issuer": issuer, "game": game, "port": port,
		"allocator": allocator, "coordinator": coordinator, "checkpoint": checkpoint,
		"manager": manager, "view": view, "board": board, "consequence": consequence}

func test_real_increment_durably_changes_pair_and_every_canonical_desktop_owner() -> void:
	var wired := _wired()
	var before: Dictionary = wired.game._run_lifecycle.to_dict()
	var result: Dictionary = wired.coordinator.resume()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var after: Dictionary = wired.game._run_lifecycle.to_dict()
	assert_eq(int(after.day), 2)
	assert_ne(after.causal_day_instance, before.causal_day_instance)
	assert_true(wired.issuer.verify_issued(after.causal_day_instance_issuer_receipt, &"causal_day_instance").get("ok", false))
	assert_eq(wired.view.snapshot().value.view.causal_day_instance, after.causal_day_instance)
	assert_eq(wired.consequence.capture().value.state.causal_day_instance, after.causal_day_instance)
	assert_eq(wired.board.capture().phase, "NONE")
	var text: Dictionary = wired.manager._storage.read_text("autosave.json")
	assert_true(text.get("ok", false), str(text))
	var document: Dictionary = wired.checkpoint._validate_document_text(str(text.value))
	assert_true(document.get("ok", false), str(document))
	if not document.get("ok", false): return
	var saved: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(saved.lifecycle.causal_day_instance, after.causal_day_instance)
	assert_eq(saved.lifecycle.causal_day_instance_issuer_receipt, after.causal_day_instance_issuer_receipt)
	var root_before: Dictionary = wired.root.capture().value
	assert_true(wired.coordinator.resume().get("ok", false))
	assert_eq(wired.root.capture().value, root_before, "completed replay cannot allocate again")

func test_checkpoint_failure_and_cold_retry_reuse_one_irreversible_allocation() -> void:
	var wired := _wired()
	wired.checkpoint.reject_once = true
	var before: Dictionary = wired.port.capture().value.backup
	var rejected: Dictionary = wired.coordinator.resume()
	assert_eq(rejected.get("code"), &"injected_checkpoint_commit_failure", str(rejected))
	assert_eq(wired.game.day, 1)
	assert_eq(wired.game._run_lifecycle.to_dict().causal_day_instance, before.lifecycle.causal_day_instance)
	assert_eq(wired.view.snapshot().value.view, before.schedule_view)
	var root: Dictionary = wired.root.capture().value
	assert_eq(root.day_advance_allocation_receipts.size(), 1)
	var allocated: Dictionary = root.day_advance_allocation_receipts.values()[0]
	var source_backup: Dictionary = wired.port.capture().value.backup
	var fresh := _wired(1, source_backup, wired.files.snapshot_persisted())
	var resumed: Dictionary = fresh.coordinator.resume()
	assert_true(resumed.get("ok", false), str(resumed))
	if not resumed.get("ok", false): return
	assert_eq(fresh.game._run_lifecycle.to_dict().causal_day_instance, allocated.target_causal_day_instance)
	assert_eq(fresh.root.capture().value, root, "cold retry never replaces the durable allocation")

func test_completed_increment_candidate_restores_exact_pair_without_another_root_write() -> void:
	var wired := _wired()
	var begun: Dictionary = wired.port.begin_next_stage()
	var allocated: Dictionary = wired.coordinator._allocate_day_advance()
	assert_true(allocated.get("ok", false), str(allocated))
	if not allocated.get("ok", false): return
	var prepared: Dictionary = wired.port.prepare_completion(str(begun.value.stage.transaction_id), allocated.value.receipt)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(wired.game.day, 1, "preparation is detached")
	var recorded: Dictionary = wired.checkpoint.prepare(prepared.value.snapshot_input,
		&"day_resolution_stage", COORDINATOR._disk_write_for("increment_day"))
	assert_true(recorded.get("ok", false), str(recorded))
	if not recorded.get("ok", false): return
	assert_true(wired.checkpoint.commit(recorded.value.candidate).get("ok", false))
	var root: Dictionary = wired.root.capture().value
	var fresh := _wired(2, prepared.value.run_candidate, wired.files.snapshot_persisted())
	assert_eq(fresh.game.day, 2)
	assert_eq(fresh.game._run_lifecycle.to_dict(), prepared.value.run_candidate.lifecycle)
	var resumed: Dictionary = fresh.coordinator.resume()
	assert_true(resumed.get("ok", false), str(resumed))
	assert_eq(fresh.root.capture().value, root)

func test_day_seven_refuses_allocation_and_changed_target_receipt_is_not_adopted() -> void:
	var terminal := _wired(7)
	var root_before: Dictionary = terminal.root.capture().value
	assert_eq(terminal.coordinator._allocate_day_advance().get("code"), &"day_advance_source_conflict")
	assert_eq(terminal.root.capture().value, root_before)
	var wired := _wired()
	var begun: Dictionary = wired.port.begin_next_stage()
	var allocated: Dictionary = wired.coordinator._allocate_day_advance()
	assert_true(allocated.get("ok", false), str(allocated))
	if not allocated.get("ok", false): return
	var changed: Dictionary = allocated.value.receipt.duplicate(true)
	changed.value["target_causal_day_instance"] = "foreign.causal"
	var refused: Dictionary = wired.port.prepare_completion(str(begun.value.stage.transaction_id), changed)
	assert_eq(refused.get("code"), &"day_advance_allocation_conflict")
	assert_eq(wired.game.day, 1)

# Mirrors the actual restore identity boundary using real durable allocations and the production
# pure remapper. It deliberately leaves the Schedule plan and all completed stage bytes frozen.
func _restore_branch(wired: Dictionary) -> Dictionary:
	var source: Dictionary = wired.game._run_lifecycle.to_dict()
	var snapshot: Dictionary = wired.game.capture_run_snapshot_input()
	snapshot["schedule_view"] = wired.view.snapshot().value.view
	var remapper := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
	var census: Dictionary = remapper.collect_rewindable_transaction_ids(snapshot)
	assert_true(census.get("ok", false), str(census))
	if not census.get("ok", false): return census
	var issued: Dictionary = wired.issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	if not issued.get("ok", false): return issued
	var request := {"transaction_id": issued.value.token,
		"transaction_issuer_receipt": issued.value.issuer_receipt, "kind": "restore",
		"existing_run_id": source.run_id, "source_desktop_timeline_generation": source.desktop_timeline_generation,
		"remap_source_transaction_ids": census.value.transaction_ids}
	var proposed: Dictionary = wired.issuer.prepare_continuation_allocation(request)
	assert_true(proposed.get("ok", false), str(proposed))
	if not proposed.get("ok", false): return proposed
	var committed: Dictionary = wired.issuer.commit_continuation_allocation(proposed.value)
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false): return committed
	var allocation: Dictionary = committed.value
	var bundle := {"transaction_id": issued.value.token, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"branch_id": allocation.branch_id, "desktop_timeline_generation": allocation.desktop_timeline_generation,
		"causal_day_instance": allocation.causal_day_instance,
		"causal_day_instance_issuer_receipt": allocation.causal_day_instance_issuer_receipt,
		"transaction_remap": allocation.transaction_remap}
	var remapped: Dictionary = remapper.prepare(snapshot, str(issued.value.token), bundle)
	assert_true(remapped.get("ok", false), str(remapped))
	if not remapped.get("ok", false): return remapped
	var enriched := bundle.duplicate(true)
	enriched["run_id"] = source.run_id
	enriched["allocation_receipt_id"] = issued.value.issuer_receipt.receipt_id
	enriched["remap_receipt_id"] = remapped.value.remap_receipt_id
	enriched["remap_receipt_provenance"] = remapped.value.remap_receipt_provenance
	var lifecycle := preload("res://scripts/domain/run/RunLifecycle.gd").new()
	var prepared: Dictionary = lifecycle.prepare_restore(remapped.value.snapshot.lifecycle)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return prepared
	assert_true(lifecycle.commit_restore(prepared.value.candidate).get("ok", false))
	var continuation: Dictionary = lifecycle.prepare_continuation_remap(str(issued.value.token), enriched, {
		"branch_id": source.branch_id, "desktop_timeline_generation": source.desktop_timeline_generation,
		"causal_day_instance": source.causal_day_instance,
		"causal_day_instance_issuer_receipt": source.causal_day_instance_issuer_receipt})
	assert_true(continuation.get("ok", false), str(continuation))
	if not continuation.get("ok", false): return continuation
	var candidate := {}
	for key: String in ["contacts", "gameplay", "committed_schedule", "schedule_view", "desktop"]:
		candidate[key] = remapped.value.snapshot[key]
	candidate["lifecycle"] = continuation.value.candidate
	var installed: Dictionary = wired.port.commit(candidate)
	assert_true(installed.get("ok", false), str(installed))
	return installed

func test_repeated_real_restore_uses_verified_current_branch_without_rewriting_schedule_history() -> void:
	var wired := _wired()
	var original: Dictionary = wired.game._run_lifecycle.to_dict()
	assert_true(_restore_branch(wired).get("ok", false))
	var first_source: Dictionary = wired.game._run_lifecycle.to_dict()
	assert_eq(first_source.active_resolution_plan, original.active_resolution_plan)
	var first: Dictionary = wired.coordinator._allocate_day_advance()
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var first_allocation: Dictionary = first.value.receipt.value.day_advance_identity_receipt
	assert_ne(first_allocation.source_resolution_receipt_id,
		original.active_resolution_plan.day_resolution_start_receipt.receipt_id)
	assert_true(wired.issuer.validate_child(first_allocation.source_resolution_receipt_provenance,
		&"day_resolution_stage").get("ok", false))
	assert_true(_restore_branch(wired).get("ok", false))
	var second_source: Dictionary = wired.game._run_lifecycle.to_dict()
	assert_eq(second_source.active_resolution_plan, original.active_resolution_plan,
		"completed evidence and frozen presentation command ancestry are unchanged after two Loads")
	assert_ne(second_source.causal_day_instance, first_source.causal_day_instance)
	var second: Dictionary = wired.coordinator._allocate_day_advance()
	assert_true(second.get("ok", false), str(second))
	if not second.get("ok", false): return
	var second_allocation: Dictionary = second.value.receipt.value.day_advance_identity_receipt
	assert_ne(second_allocation.allocation_key, first_allocation.allocation_key)
	assert_eq(second_allocation.source_causal_day_instance, second_source.causal_day_instance)
	var root: Dictionary = wired.root.capture().value
	assert_eq(root.day_advance_allocation_receipts.size(), 2)
	assert_eq(wired.coordinator._allocate_day_advance().value.receipt, second.value.receipt)
	assert_eq(wired.root.capture().value, root, "same restored branch retries the exact allocation")
	var forged := second_source.duplicate(true)
	forged.restore_provenance["remap_receipt_id"] = "foreign.proof"
	assert_eq(wired.port.prepare_day_advance_source(forged).get("code"), &"day_advance_restore_unverified")
	forged = second_source.duplicate(true)
	forged.active_resolution_plan.day_resolution_start_receipt["causal_day_instance"] = second_source.causal_day_instance
	assert_eq(wired.port.prepare_day_advance_source(forged).get("code"), &"day_advance_source_unverified",
		"the original causal token cannot be edited to bypass restore verification")
	forged = second_source.duplicate(true)
	forged.active_resolution_plan.day_resolution_start_receipt["receipt_id"] = "foreign.start"
	assert_false(wired.port.prepare_day_advance_source(forged).get("ok", true))
	assert_eq(wired.root.capture().value, root, "invalid provenance never reaches allocation")
	var completed: Dictionary = wired.coordinator.resume()
	assert_true(completed.get("ok", false), str(completed))
	if not completed.get("ok", false): return
	assert_eq(wired.game.day, 2)
	assert_eq(wired.game._run_lifecycle.to_dict().causal_day_instance, second_allocation.target_causal_day_instance)
	assert_eq(wired.root.capture().value, root)
