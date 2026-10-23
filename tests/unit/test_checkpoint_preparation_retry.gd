extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/unit/test_checkpoint_validation_reuse.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILE_OPS := preload("res://tests/support/FakeFileOps.gd")
const FINAL := "checkpoint-reuse/autosave.json"
var fixture: Node

class FailColdRereadFiles extends "res://tests/support/FakeFileOps.gd":
	var final_reads := 0
	func read_bytes(path: String) -> Dictionary:
		if path == "checkpoint-reuse/autosave.json":
			final_reads += 1
			if final_reads == 2: fail_after(operation_count() + 1)
		return super.read_bytes(path)

func before_each() -> void:
	fixture = autofree(FIXTURE.new())
	fixture.gut = gut

func _inputs(wired: Dictionary, money: int) -> Dictionary:
	var snapshot: Dictionary = wired.snapshot.duplicate(true)
	snapshot["gameplay"]["money"] = money
	var input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
		"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop", "schedule_view", "command_receipts"]:
		input[key] = snapshot[key]
	return {"snapshot_input": input, "dialogic_checkpoint": {}, "route_id": "main",
		"active_app_id": snapshot.active_app_id, "audio_context": snapshot.audio_context,
		"content_version": snapshot.content_version}

func _prepare(wired: Dictionary, money: int) -> Dictionary:
	return wired.port.prepare(_inputs(wired, money), &"post_result", {"kind": &"autosave", "reason": &"automatic"})

func _saved() -> Dictionary:
	var wired: Dictionary = fixture._wired()
	var prepared := _prepare(wired, 100)
	assert_true(prepared.ok, str(prepared))
	if prepared.ok: assert_true(wired.port.commit(prepared.value.candidate).ok)
	return wired

func _cold_saved(fail_reread: bool = false) -> Dictionary:
	var saved := _saved()
	var cold: Dictionary = fixture._wired()
	var persisted: Dictionary = saved.files.snapshot_persisted()
	cold.files = FailColdRereadFiles.new(persisted) if fail_reread else FILE_OPS.new(persisted)
	# A genuinely new storage owner has never leased these existing durable bytes.
	cold.storage = STORAGE.new("checkpoint-reuse", cold.files)
	cold.manager._storage = cold.storage
	var state: Dictionary = saved.manager._journal.capture_state()
	assert_true(cold.manager._journal.restore_state(state.value.backup).ok)
	return cold

func test_cold_existing_autosave_reconciles_and_rereads_before_first_preparation_succeeds() -> void:
	var wired := _cold_saved()
	var before: Dictionary = wired.manager._journal.capture_state()
	var disk: Dictionary = wired.files.snapshot_persisted()
	var text: String = (disk[FINAL] as PackedByteArray).get_string_from_utf8()
	var prepared := _prepare(wired, 101)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(prepared.value.candidate.storage_backup, {
		"relative_path": "autosave.json", "existed": true,
		"validated_text": text, "sha256": text.sha256_text()})
	assert_eq(wired.manager._journal.capture_state(), before)
	assert_eq(wired.files.snapshot_persisted(), disk)
	var reads := 0
	for row: Dictionary in wired.files.operation_trace():
		if row.operation == &"read_bytes" and row.path == FINAL: reads += 1
		assert_false(row.operation in [&"write_bytes", &"rename_path", &"remove_path", &"flush_path"], str(row))
	assert_eq(reads, 2, "real reconciliation validates the final, then a leased physical reread proves the backup")
	assert_gt(int(wired.port.validations.get(text, 0)), 0, "cold bytes receive actual document validation")
	assert_true(wired.port.commit(prepared.value.candidate).ok)
	assert_eq(wired.manager._journal.peek_next_sequence(wired.snapshot.run_id).value.checkpoint_sequence, 3)

func test_cold_corrupt_or_ambiguous_autosave_preserves_all_artifacts_and_journal() -> void:
	for corrupt_marker: bool in [false, true]:
		var wired := _cold_saved()
		var corrupt_path := FINAL + ".txn.json" if corrupt_marker else FINAL
		wired.files._persisted[corrupt_path] = "{broken".to_utf8_buffer()
		var disk: Dictionary = wired.files.snapshot_persisted()
		var before: Dictionary = wired.manager._journal.capture_state()
		var refused := _prepare(wired, 101)
		assert_false(refused.ok)
		assert_eq(refused.code, &"indeterminate_transaction", str(refused))
		assert_true(refused.get("fatal", false))
		assert_eq(wired.files.snapshot_persisted(), disk)
		assert_eq(wired.manager._journal.capture_state(), before)

func test_cold_leased_reread_failure_refuses_current_preparation_without_committing() -> void:
	var wired := _cold_saved(true)
	var disk: Dictionary = wired.files.snapshot_persisted()
	var before: Dictionary = wired.manager._journal.capture_state()
	var refused := _prepare(wired, 101)
	assert_false(refused.ok)
	assert_eq(refused.code, &"reconcile_required", str(refused))
	assert_false(refused.get("fatal", false))
	assert_false(refused.get("reason", "") == &"lease_missing", "the leased reread was attempted and failed")
	assert_eq(wired.files.final_reads, 2, "no retry loop hides the failed physical reread")
	assert_eq(wired.files.snapshot_persisted(), disk)
	assert_eq(wired.manager._journal.capture_state(), before)
	var retry := _prepare(wired, 101)
	assert_true(retry.ok, str(retry))
	assert_eq(wired.files.snapshot_persisted(), disk)
	assert_eq(wired.manager._journal.capture_state(), before)

func test_transient_prepare_read_failure_keeps_explicit_retry_and_exact_candidate_without_journal_or_disk_mutation() -> void:
	var wired := _saved()
	var expected := _prepare(wired, 101)
	assert_true(expected.ok, str(expected))
	if not expected.ok: return
	var before: Dictionary = wired.manager._journal.capture_state()
	var disk: Dictionary = wired.files.snapshot_persisted()
	var trace_start: int = wired.files.operation_trace().size()
	wired.files.fail_after(wired.files.operation_count() + 1)
	var failed := _prepare(wired, 101)
	assert_false(failed.ok)
	assert_eq(failed.code, &"reconcile_required", str(failed))
	assert_false(failed.get("fatal", false))
	assert_eq(wired.manager._journal.capture_state(), before)
	assert_eq(wired.files.snapshot_persisted(), disk)
	var reads := 0
	for row: Dictionary in wired.files.operation_trace().slice(trace_start):
		if row.operation == &"read_bytes": reads += 1
		assert_false(row.operation in [&"write_bytes", &"rename_path", &"remove_path", &"flush_path"], str(row))
	assert_gt(reads, 1, "failed read is followed by real validated reconciliation, never a synthetic lease")
	var retry := _prepare(wired, 101)
	assert_true(retry.ok, str(retry))
	if not retry.ok: return
	assert_eq(retry.value.candidate, expected.value.candidate)
	assert_true(wired.port.commit(retry.value.candidate).ok)
	assert_eq(wired.manager._journal.peek_next_sequence(wired.snapshot.run_id).value.checkpoint_sequence, 3)

func test_corrupt_durable_final_is_refused_with_artifacts_and_journal_preserved() -> void:
	var wired := _saved()
	wired.files._persisted[FINAL] = "{broken".to_utf8_buffer()
	var disk: Dictionary = wired.files.snapshot_persisted()
	var before: Dictionary = wired.manager._journal.capture_state()
	for attempt: int in range(2):
		var refused := _prepare(wired, 101)
		assert_false(refused.ok)
		assert_eq(refused.code, &"indeterminate_transaction", str(refused))
		assert_true(refused.get("fatal", false), "storage reconciliation owns this refusal; no failed commit is fabricated")
		assert_eq(wired.files.snapshot_persisted(), disk)
		assert_eq(wired.manager._journal.capture_state(), before)

func test_changed_but_valid_bytes_refuse_current_attempt_then_require_explicit_new_preparation() -> void:
	var wired := _saved()
	var current: PackedByteArray = wired.files._persisted[FINAL]
	# This remains the same valid document but changes its durable hash behind the lease.
	wired.files._persisted[FINAL] = (current.get_string_from_utf8() + " ").to_utf8_buffer()
	var disk: Dictionary = wired.files.snapshot_persisted()
	var before: Dictionary = wired.manager._journal.capture_state()
	var refused := _prepare(wired, 101)
	assert_false(refused.ok)
	assert_eq(refused.code, &"reconcile_required", str(refused))
	assert_false(refused.get("fatal", false))
	assert_eq(wired.files.snapshot_persisted(), disk, "reconciliation does not overwrite changed valid bytes")
	assert_eq(wired.manager._journal.capture_state(), before)
	# Established storage law permits explicit new preparation against reconciled valid data;
	# it never turns the original failed attempt into success or advances its journal.
	var retry := _prepare(wired, 101)
	assert_true(retry.ok, str(retry))
	assert_eq(wired.files.snapshot_persisted(), disk)
	assert_eq(wired.manager._journal.capture_state(), before)
