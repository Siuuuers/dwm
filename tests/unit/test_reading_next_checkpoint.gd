extends "res://addons/gut/test.gd"
## The real autosave/journal path with exact semantic Next source/destination.
## FileOps injection tests a bounded post-promotion failure, not an OS crash.
const ADAPTER := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const MANAGER := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const CONTEXT := preload("res://tests/support/FakeNarrativeCheckpointContext.gd")
const FIXTURE := preload("res://tests/support/ReadingNextFixture.gd")
const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

class CheckedPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var refuse_after_commit := false
	var reenter := Callable()
	var commit_count := 0
	func commit(candidate: Dictionary) -> Dictionary:
		commit_count += 1
		if reenter.is_valid(): reenter.call()
		var result := super.commit(candidate)
		if result.get("ok", false) and refuse_after_commit:
			refuse_after_commit = false
			return {"ok": false, "code": &"fixture_postcommit_refusal"}
		return result

class PromotedReadFailure extends "res://tests/support/FakeFileOps.gd":
	var armed := false
	var blocked := false
	func rename_path(from_path: String, to_path: String) -> Dictionary:
		var result := super.rename_path(from_path, to_path)
		if result.ok and armed and from_path.ends_with("autosave.json.next") and to_path.ends_with("autosave.json"):
			blocked = true
		return result
	func read_bytes(path: String) -> Dictionary:
		if blocked: return {"ok": false, "code": &"fixture_postpromotion_read_refusal"}
		return super.read_bytes(path)

func _fixture(files: RefCounted = null) -> Dictionary:
	var made := TemporaryStorage.create("reading_next_checkpoint")
	assert_true(made.ok, str(made))
	if not made.ok: return {}
	var root := str(made.value).path_join("saves")
	var ops: RefCounted = files if files != null else OPS.new()
	var storage := STORAGE.new(root, ops)
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage).ok)
	var gate := GATE.new()
	var real := CheckedPort.new(manager)
	assert_true(real.configure_fatal_latch(gate).ok)
	var snapshot := FIXTURE.snapshot()
	var admitted := RUN_SCHEMA.validate(snapshot)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return {}
	assert_true(manager._journal.reset(snapshot.run_id).ok)
	var context := CONTEXT.new()
	context.snapshot_input_value = FIXTURE.snapshot_input(snapshot)
	context.route_id_value = "dating"
	context.content_version_value = snapshot.content_version
	context.audio_context_value = snapshot.audio_context.duplicate(true)
	var adapter := ADAPTER.new()
	assert_true(adapter.configure(real, context.provider_callables()).ok)
	var plan := FIXTURE.plan(snapshot.narrative_checkpoint)
	var source := FIXTURE.checkpoint_for(snapshot.narrative_checkpoint, plan, "source")
	var destination := FIXTURE.checkpoint_for(snapshot.narrative_checkpoint, plan, "destination")
	return {"root": root, "ops": ops, "storage": storage, "manager": manager, "gate": gate,
		"real": real, "context": context, "adapter": adapter, "source": source, "destination": destination,
		"operation_id": source.reading_session.next_operation.operation_id}

func _commit(f: Dictionary, phase: String) -> Dictionary:
	return f.adapter.commit_reading_next(f[phase], f.operation_id, phase)

func _validate_text(text: String) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.ok: return parsed
	var checked := DOCUMENT.validate(parsed.value)
	if not checked.ok: return checked
	return {"ok": true, "value": checked.value.candidate}

func _cold_checkpoint(f: Dictionary) -> Dictionary:
	var cold := STORAGE.new(f.root, OPS.new(f.ops.snapshot_persisted()))
	var reconciled := cold.reconcile("autosave.json", _validate_text)
	assert_true(reconciled.ok, str(reconciled))
	if not reconciled.ok: return {}
	var read := cold.read_text("autosave.json")
	assert_true(read.ok, str(read))
	if not read.ok: return {}
	var checked := _validate_text(read.value)
	assert_true(checked.ok, str(checked))
	return checked.value.current_snapshot.snapshot.narrative_checkpoint if checked.ok else {}

func test_next_persists_source_then_destination_through_real_autosave_schema() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var source := _commit(f, "source")
	assert_true(source.ok, str(source))
	if not source.ok: return
	assert_eq(source.receipt.operation_id, f.operation_id)
	assert_eq(_cold_checkpoint(f), f.source, "source survives a fresh storage owner before any seek")
	var destination := _commit(f, "destination")
	assert_true(destination.ok, str(destination))
	if not destination.ok: return
	assert_ne(source.value.checkpoint_id, destination.value.checkpoint_id)
	assert_eq(_cold_checkpoint(f), f.destination, "destination is exact, not a re-evaluated live scan")
	var calls: int = f.real.commit_count
	assert_eq(_commit(f, "destination").get("code"), &"reading_next_source_not_committed")
	assert_eq(f.real.commit_count, calls, "a completed operation cannot reuse old adapter receipts")
	var fresh_source := _commit(f, "source")
	assert_true(fresh_source.ok)
	assert_ne(fresh_source.value.checkpoint_id, source.value.checkpoint_id,
		"a later activation with identical semantic bytes must persist its source again")
	assert_eq(_cold_checkpoint(f), f.source)

func test_next_refuses_missing_source_and_changed_command_before_storage() -> void:
	var f := _fixture()
	if f.is_empty(): return
	assert_eq(_commit(f, "destination").get("code"), &"reading_next_source_not_committed")
	assert_eq(f.real.commit_count, 0)
	assert_eq(f.adapter.commit_reading_next(f.source, "foreign", "source").get("code"), &"reading_next_operation_mismatch")
	assert_true(_commit(f, "source").ok)
	var altered: Dictionary = f.source.duplicate(true)
	altered.transaction_id = "conflicting:transaction"
	assert_false(f.adapter.commit_reading_next(altered, f.operation_id, "source").ok)
	assert_eq(_cold_checkpoint(f), f.source)

func test_next_destination_rejects_unrelated_autosave_or_restored_journal() -> void:
	for change: String in ["autosave", "restore"]:
		var f := _fixture()
		if f.is_empty(): return
		var original: Dictionary = f.manager._journal.capture_state().value.backup
		assert_true(_commit(f, "source").ok)
		if change == "autosave":
			var inputs := {"snapshot_input": f.context.snapshot_input_value, "dialogic_checkpoint": {},
				"route_id": "dating", "active_app_id": null, "audio_context": f.context.audio_context_value,
				"content_version": f.context.content_version_value}
			var prepared: Dictionary = f.real.prepare(inputs, &"safe_marker", {"kind": &"autosave", "reason": &"automatic"})
			assert_true(prepared.ok, str(prepared))
			if not prepared.ok: continue
			assert_true(f.real.commit(prepared.value.candidate).ok)
		else:
			assert_true(f.manager._journal.restore_state(original).ok)
		var bytes: String = f.storage.read_text("autosave.json").value
		assert_eq(_commit(f, "destination").get("code"), &"reading_next_source_changed", change)
		assert_eq(f.storage.read_text("autosave.json").value, bytes)
		assert_true(_commit(f, "source").ok, "new activation writes a new safe source")
		assert_true(_commit(f, "destination").ok)

func test_next_postwrite_failure_restores_both_disk_and_journal_and_allows_exact_retry() -> void:
	var f := _fixture()
	if f.is_empty(): return
	assert_true(_commit(f, "source").ok)
	var before: Dictionary = f.manager._journal.capture_state().value.backup
	var bytes: String = f.storage.read_text("autosave.json").value
	f.real.refuse_after_commit = true
	var failed := _commit(f, "destination")
	assert_eq(failed.get("code"), &"fixture_postcommit_refusal")
	assert_eq(f.manager._journal.capture_state().value.backup, before)
	assert_eq(f.storage.read_text("autosave.json").value, bytes, "journal-only rollback would leave destination bytes")
	assert_eq(_cold_checkpoint(f), f.source)
	assert_false(f.gate.is_fatal_latched())
	assert_true(_commit(f, "destination").ok, "failed attempts never enter the duplicate receipt map")
	assert_eq(_cold_checkpoint(f), f.destination)

func test_next_failed_first_write_restores_absence_and_grants_no_destination_credit() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var before: Dictionary = f.manager._journal.capture_state().value.backup
	f.real.refuse_after_commit = true
	assert_eq(_commit(f, "source").get("code"), &"fixture_postcommit_refusal")
	assert_false(f.storage.exists("autosave.json"))
	assert_eq(f.manager._journal.capture_state().value.backup, before)
	assert_eq(_commit(f, "destination").get("code"), &"reading_next_source_not_committed")
	assert_true(_commit(f, "source").ok)
	assert_eq(_cold_checkpoint(f), f.source)

func test_next_indeterminate_promotion_latches_gate_and_cold_storage_recovers_exact_destination() -> void:
	var ops := PromotedReadFailure.new()
	var f := _fixture(ops)
	if f.is_empty(): return
	assert_true(_commit(f, "source").ok)
	ops.armed = true
	var failed := _commit(f, "destination")
	assert_false(failed.ok)
	assert_true(ops.blocked, "the injected refusal occurred after actual promotion")
	assert_true(f.gate.is_fatal_latched(), "unprovable rollback cannot release mutation custody")
	assert_false(_commit(f, "destination").ok)
	assert_eq(_cold_checkpoint(f), f.destination, "fresh reconciliation follows the durable marker, not the failed live receipt")

func test_next_reentrant_checkpoint_writes_refuse_until_outer_commit_finishes() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var refusals: Array = []
	f.real.reenter = func() -> void:
		refusals.append(_commit(f, "source"))
		refusals.append(f.adapter.commit_current_boundary({"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start",
			"narrative_checkpoint": {"timeline_id": "T", "event": {"event_id": null}, "boundary": {"transaction_id": ""}}}))
	var committed := _commit(f, "source")
	assert_true(committed.ok, str(committed))
	assert_eq(refusals.size(), 2)
	for failure: Dictionary in refusals: assert_eq(failure.get("code"), &"transaction_in_progress")
	assert_eq(f.real.commit_count, 1)
