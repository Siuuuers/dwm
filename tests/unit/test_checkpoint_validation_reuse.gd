extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ROOT := "checkpoint-reuse"
const FINAL := ROOT + "/autosave.json"

class CountingPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var validations := {}
	var reuse := true
	func _validate_document_text(text: String) -> Dictionary:
		validations[text] = int(validations.get(text, 0)) + 1
		return super._validate_document_text(text)
	func _cached_document_text_validator(text: String, cache: Dictionary) -> Dictionary:
		if not reuse: return _document_text_validator(text)
		return super._cached_document_text_validator(text, cache)

class Manager extends RefCounted:
	var _journal := JOURNAL.new()
	var _storage: RefCounted
	var _restore_participants := {}

class CorruptFiles extends "res://tests/support/FakeFileOps.gd":
	var corrupt_suffix := ""
	var promoted := false
	var backup_moved := false
	var corrupted := false
	func rename_path(from_path: String, to_path: String) -> Dictionary:
		var result := super.rename_path(from_path, to_path)
		if result.get("ok", false):
			if from_path.ends_with(".next"): promoted = true
			if to_path.ends_with(".bak"): backup_moved = true
		return result
	func read_bytes(path: String) -> Dictionary:
		var eligible := path.ends_with("autosave.json.next") if corrupt_suffix == ".next" else false
		if corrupt_suffix == ".bak": eligible = path.ends_with(".bak") and backup_moved
		if corrupt_suffix == "final": eligible = path.ends_with("autosave.json") and promoted
		if eligible and not corrupted and _persisted.has(path):
			_persisted[path] = "{broken".to_utf8_buffer()
			corrupted = true
		return super.read_bytes(path)

class ChangedRereadStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var alter_reread := false
	var fail_reread := false
	func read_text(relative_path: String) -> Dictionary:
		var result := super.read_text(relative_path)
		if fail_reread: return {"ok": false, "code": &"injected_reread_failure"}
		if alter_reread and result.get("ok", false):
			# Still schema-valid JSON; exact written bytes differ.
			result["value"] = str(result["value"]) + " "
		return result

func _snapshot() -> Dictionary:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v6_desktop_prepared.json"))
	assert_true(parsed.get("ok", false), str(parsed))
	var validated := SNAPSHOT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), str(validated))
	return validated.get("value", {}).get("candidate", {})

func _wired(reuse: bool = true, changed_reread: bool = false) -> Dictionary:
	var files := CorruptFiles.new()
	var storage: RefCounted = ChangedRereadStorage.new(ROOT, files) if changed_reread else STORAGE.new(ROOT, files)
	var manager := Manager.new()
	manager._storage = storage
	var port := CountingPort.new(manager)
	port.reuse = reuse
	var gate := GATE.new()
	assert_true(port.configure_fatal_latch(gate).get("ok", false))
	var snapshot := _snapshot()
	assert_true(manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	return {"files": files, "storage": storage, "manager": manager, "port": port, "snapshot": snapshot, "gate": gate}

func _prepare(wired: Dictionary, money: int) -> Dictionary:
	var snapshot: Dictionary = wired.snapshot.duplicate(true)
	snapshot["gameplay"]["money"] = money
	var input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop", "schedule_view", "command_receipts"]:
		input[key] = snapshot[key]
	var prepared: Dictionary = wired.port.prepare({"snapshot_input": input, "dialogic_checkpoint": {},
		"route_id": "main", "active_app_id": snapshot.active_app_id, "audio_context": snapshot.audio_context,
		"content_version": snapshot.content_version}, &"post_result", {"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), str(prepared))
	return prepared.get("value", {}).get("candidate", {})

func _validation_count(port: CountingPort) -> int:
	var total := 0
	for count: int in port.validations.values(): total += count
	return total

func test_reuse_preserves_saved_bytes_and_every_disk_operation_across_three_commits() -> void:
	var cached := _wired()
	var uncached := _wired(false)
	for money: int in [101, 102, 103]:
		cached.port.validations.clear()
		uncached.port.validations.clear()
		var candidate := _prepare(cached, money)
		var reference := _prepare(uncached, money)
		var committed: Dictionary = cached.port.commit(candidate)
		var original: Dictionary = uncached.port.commit(reference)
		assert_true(committed.get("ok", false), str(committed))
		assert_eq(committed, original)
		assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted())
		assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(),
			"all physical reads, hashes, writes, flushes and rename boundaries remain")
		assert_lt(_validation_count(cached.port), _validation_count(uncached.port))
		for count: int in cached.port.validations.values(): assert_eq(count, 1)
		assert_eq(cached.port.validations.size(), money - 100,
			"each prepare/commit validates each distinct current, previous and older backup once")

func test_cache_is_exact_text_success_only_and_detaches_nested_results() -> void:
	var wired := _wired()
	var candidate := _prepare(wired, 200)
	var text: String = WRITER.stringify(candidate.autosave_document).value + "\n"
	var cache := {}
	wired.port.validations.clear()
	var first: Dictionary = wired.port._cached_document_text_validator(text, cache)
	assert_true(first.get("ok", false), str(first))
	first["value"]["current_snapshot"]["snapshot"]["gameplay"]["money"] = 999
	var repeated: Dictionary = wired.port._cached_document_text_validator(text, cache)
	assert_eq(repeated.value.current_snapshot.snapshot.gameplay.money, 200)
	assert_eq(wired.port.validations[text], 1)
	var spaced: Dictionary = wired.port._cached_document_text_validator(text + " ", cache)
	assert_true(spaced.get("ok", false), str(spaced))
	assert_eq(wired.port.validations[text + " "], 1, "no JSON normalization in cache keys")
	var broken := "{\"schema_version\":1,\"schema_version\":1}"
	var rejected: Dictionary = wired.port._cached_document_text_validator(broken, cache)
	assert_false(rejected.get("ok", true))
	assert_eq(wired.port._cached_document_text_validator(broken, cache), rejected)
	assert_eq(wired.port.validations[broken], 2, "failed validation never becomes a cached result")
	assert_false(cache.has(broken))

func test_corrupt_next_final_and_backup_keep_existing_recovery_results_and_disk_trace() -> void:
	for suffix: String in [".next", "final", ".bak"]:
		var cached := _wired()
		var uncached := _wired(false)
		for wired: Dictionary in [cached, uncached]:
			assert_true(wired.port.commit(_prepare(wired, 300)).get("ok", false))
			wired.files.promoted = false
			wired.files.backup_moved = false
		var candidate := _prepare(cached, 301)
		var reference := _prepare(uncached, 301)
		cached.files.corrupt_suffix = suffix
		uncached.files.corrupt_suffix = suffix
		var committed: Dictionary = cached.port.commit(candidate)
		var original: Dictionary = uncached.port.commit(reference)
		assert_true(cached.files.corrupted, suffix)
		assert_eq(committed, original, suffix)
		assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted(), suffix)
		assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(), suffix)
		assert_eq(cached.manager._journal.capture_state(), uncached.manager._journal.capture_state(), suffix)
		assert_gt(int(cached.port.validations.get("{broken", 0)), 0, "changed text is strictly validated")

func test_schema_valid_changed_reread_is_rejected_before_journal_commit() -> void:
	var wired := _wired(true, true)
	var candidate := _prepare(wired, 400)
	var before: Dictionary = wired.manager._journal.capture_state()
	wired.storage.alter_reread = true
	var result: Dictionary = wired.port.commit(candidate)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"reread_mismatch")
	assert_eq(wired.manager._journal.capture_state(), before)
	var persisted: Dictionary = wired.files.snapshot_persisted()
	assert_true(persisted.has(FINAL), "disk write completed; journal must wait for exact reread")

func test_failed_reread_retry_has_a_fresh_validation_scope_and_commits_once() -> void:
	var wired := _wired(true, true)
	var candidate := _prepare(wired, 500)
	var before: Dictionary = wired.manager._journal.capture_state()
	wired.storage.fail_reread = true
	assert_eq(wired.port.commit(candidate).get("code"), &"injected_reread_failure")
	assert_eq(wired.manager._journal.capture_state(), before)
	wired.storage.fail_reread = false
	wired.port.validations.clear()
	var result: Dictionary = wired.port.commit(candidate)
	assert_true(result.get("ok", false), str(result))
	assert_eq(_validation_count(wired.port), 1, "retry must validate exact text again")
	assert_eq(wired.manager._journal.peek_next_sequence(wired.snapshot.run_id).value.checkpoint_sequence, 2)

func test_prepared_validation_is_not_reused_after_a_process_frame() -> void:
	var wired := _wired()
	assert_true(wired.port.commit(_prepare(wired, 600)).get("ok", false))
	var old_text: String = wired.storage.read_text("autosave.json").value
	var candidate := _prepare(wired, 601)
	wired.port.validations.clear()
	await get_tree().process_frame
	var committed: Dictionary = wired.port.commit(candidate)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(wired.port.validations.get(old_text, 0), 1,
		"a yielded prepare cannot carry semantic validation into a later frame")

func test_new_prepare_and_released_custody_discard_prepared_validation() -> void:
	for interruption: String in ["failed_prepare", "released_lease", "reconfigure", "rollback"]:
		var wired := _wired()
		assert_true(wired.port.commit(_prepare(wired, 700)).get("ok", false))
		var old_text: String = wired.storage.read_text("autosave.json").value
		var backup: Dictionary = wired.port.capture().value.backup
		var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
		assert_true(lease.get("ok", false), str(lease))
		var candidate := _prepare(wired, 701)
		match interruption:
			"failed_prepare":
				var failed: Dictionary = wired.port.prepare({}, &"post_result", {"kind": &"none"})
				assert_false(failed.get("ok", true))
			"released_lease":
				assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))
				lease = wired.gate.acquire(&"causal_transaction")
				assert_true(lease.get("ok", false), str(lease))
			"reconfigure":
				assert_true(wired.port.configure_fatal_latch(wired.gate).get("ok", false))
			"rollback":
				assert_true(wired.port.rollback(backup).get("ok", false))
		wired.port.validations.clear()
		var committed: Dictionary = wired.port.commit(candidate)
		assert_true(committed.get("ok", false), str(committed))
		assert_eq(wired.port.validations.get(old_text, 0), 1, interruption)
		assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))

func test_mutated_outgoing_document_fails_and_retry_revalidates_preimage() -> void:
	var baseline_code: StringName = &""
	for reuse: bool in [false, true]:
		var wired := _wired(reuse)
		assert_true(wired.port.commit(_prepare(wired, 800)).get("ok", false))
		var old_text: String = wired.storage.read_text("autosave.json").value
		var candidate := _prepare(wired, 801)
		var invalid: Dictionary = candidate.duplicate(true)
		# This field is explicitly required to be an object by the save contract.
		# Money is only checked as a primitive here, so changing its type was not invalid.
		invalid["autosave_document"]["current_snapshot"]["snapshot"]["gameplay"]["narrative_variables"] = "invalid"
		var before: Dictionary = wired.manager._journal.capture_state()
		var rejected: Dictionary = wired.port.commit(invalid)
		assert_false(rejected.get("ok", true), "schema-invalid outgoing data must fail; reuse=%s" % reuse)
		if rejected.get("ok", false): return
		if not reuse: baseline_code = StringName(str(rejected.get("code", "")))
		assert_eq(StringName(str(rejected.get("code", ""))), baseline_code,
			"cached path must retain the uncached rejection")
		assert_true(wired.manager._journal.capture_state() == before,
			"invalid outgoing data cannot commit the prepared journal")
		# Rejected write_atomic consumes its read lease. Inspect durable fixture bytes;
		# the same-candidate commit below performs the real fresh reconciliation.
		var retained: Dictionary = wired.files.snapshot_persisted()
		assert_true(retained.get(FINAL, PackedByteArray()) == old_text.to_utf8_buffer(),
			"invalid outgoing data leaves every preimage byte unchanged")
		wired.port.validations.clear()
		var committed: Dictionary = wired.port.commit(candidate)
		assert_true(committed.get("ok", false), str(committed.get("code", "")))
		if reuse:
			assert_eq(wired.port.validations.get(old_text, 0), 1,
				"a failed commit consumes the prepared proof before retry")
