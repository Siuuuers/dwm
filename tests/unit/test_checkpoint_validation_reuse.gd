extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ROOT := "checkpoint-reuse"
const FINAL := ROOT + "/autosave.json"
const PORT_SOURCE := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const WITNESS := "_witness_document_text_validator"

class CountingPort extends "res://scripts/application/run/SaveManagerCheckpointPort.gd":
	var validations := {}
	var reuse := true
	func _validate_document_text(text: String) -> Dictionary:
		validations[text] = int(validations.get(text, 0)) + 1
		return super._validate_document_text(text)
	func _cached_document_text_validator(text: String, cache: Dictionary) -> Dictionary:
		if not reuse: return _document_text_validator(text)
		return super._cached_document_text_validator(text, cache)
	func _cached_document_text_proof(text: String, cache: Dictionary) -> Dictionary:
		if not reuse: return _document_text_validator(text)
		return super._cached_document_text_proof(text, cache)

# dwm-634.3: the storage witness is the third reader of the exact-text proofs, and commit() seeds the
# outgoing text into the cache it binds, so suppressing the proven-document memo is not enough to
# keep a reference port cold. This is the ONLY double that declares the witness, so that `_wired()`'s
# reuse=true port -- the one the witness rows below interrogate -- still answers has_method() and
# dispatches from the production port itself. Nothing here calls `super` on the witness: that would
# not compile against a port which does not declare one yet.
class UncachedPort extends CountingPort:
	func _witness_document_text_validator(text: String, _cache: Dictionary) -> Dictionary:
		return _document_text_validator(text)

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
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	assert_true(parsed.get("ok", false), str(parsed))
	parsed.value["schema_version"] = SNAPSHOT.SCHEMA_VERSION
	var validated := SNAPSHOT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), str(validated))
	return validated.get("value", {}).get("candidate", {})

func _wired(reuse: bool = true, changed_reread: bool = false) -> Dictionary:
	var files := CorruptFiles.new()
	var storage: RefCounted = ChangedRereadStorage.new(ROOT, files) if changed_reread else STORAGE.new(ROOT, files)
	var manager := Manager.new()
	manager._storage = storage
	var port: CountingPort = CountingPort.new(manager) if reuse else UncachedPort.new(manager)
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

func _apply_json_normalization_variants(candidate: Dictionary) -> void:
	var document: Dictionary = candidate["autosave_document"]
	document.erase("save_reason")
	document[&"save_reason"] = &"automatic"
	document["kind"] = &"autosave"
	document["schema_version"] = float(document["schema_version"])
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	snapshot["route_id"] = &"main"
	var effect_ids: Array[StringName] = []
	snapshot["applied_effect_transaction_ids"] = effect_ids
	var journal: Array[Dictionary] = [{&"probe": [9223372036854775807,
		-9223372036854775807 - 1, 1.0, 0.1, -0.0, &"nested"]}]
	document["recovery_journal"] = journal

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
		assert_eq(_validation_count(cached.port), 0,
			"the detached schema-valid current candidate needs no strict text parse")
		assert_gt(_validation_count(uncached.port), 0,
			"reuse=false still forces the original strict text validator")

func test_detached_candidate_normalization_matches_uncached_bytes_and_physical_trace() -> void:
	var cached := _wired()
	var uncached := _wired(false)
	var candidate := _prepare(cached, 111)
	var reference := _prepare(uncached, 111)
	_apply_json_normalization_variants(candidate)
	_apply_json_normalization_variants(reference)
	cached.port.validations.clear()
	uncached.port.validations.clear()
	var committed: Dictionary = cached.port.commit(candidate)
	var original: Dictionary = uncached.port.commit(reference)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(committed, original)
	assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted(),
		"normalization cannot alter canonical persisted bytes")
	assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(),
		"normalization cannot alter physical storage operations")
	assert_eq(_validation_count(cached.port), 0,
		"StringName, typed arrays and integral floats use the detached schema result")
	assert_gt(_validation_count(uncached.port), 0,
		"the reference path still parses its exact outgoing text")
	var parsed: Dictionary = STRICT.parse_object(
		(cached.files.snapshot_persisted()[FINAL] as PackedByteArray).get_string_from_utf8())
	assert_true(parsed.get("ok", false), str(parsed))
	var validated: Dictionary = DOCUMENT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), str(validated))
	var normalized: Dictionary = validated.get("value", {}).get("candidate", {})
	var proven: Dictionary = cached.port._cached_document_text_validator(
		(cached.files.snapshot_persisted()[FINAL] as PackedByteArray).get_string_from_utf8(), {})
	assert_true(proven.get("ok", false), str(proven))
	assert_true(WRITER._deep_same(proven.get("value"), normalized),
		"cached validation preserves exact nested types and values of the strict reference")
	assert_eq(typeof(normalized.get("schema_version")), TYPE_INT)
	assert_eq(typeof(normalized.get("kind")), TYPE_STRING)
	assert_eq(typeof(normalized.get("save_reason")), TYPE_STRING)
	assert_eq(typeof(normalized["current_snapshot"]["snapshot"].get("route_id")), TYPE_STRING)
	assert_false((normalized["recovery_journal"] as Array).is_typed())
	assert_false((normalized["current_snapshot"]["snapshot"]["applied_effect_transaction_ids"] as Array).is_typed())

func test_non_object_outgoing_values_match_uncached_failure_without_physical_mutation() -> void:
	for wrong: Variant in [[], "document", 7]:
		var cached := _wired()
		var uncached := _wired(false)
		var candidate := _prepare(cached, 121)
		var reference := _prepare(uncached, 121)
		candidate["autosave_document"] = wrong
		reference["autosave_document"] = wrong
		var cached_before_files: Dictionary = cached.files.snapshot_persisted()
		var reference_before_files: Dictionary = uncached.files.snapshot_persisted()
		var cached_before_trace: Array = cached.files.operation_trace()
		var reference_before_trace: Array = uncached.files.operation_trace()
		var cached_before_journal: Dictionary = cached.manager._journal.capture_state()
		var reference_before_journal: Dictionary = uncached.manager._journal.capture_state()
		var rejected: Dictionary = cached.port.commit(candidate)
		var original: Dictionary = uncached.port.commit(reference)
		assert_eq(rejected, original, "wrong top-level value: %s" % str(wrong))
		assert_eq(rejected.get("code"), &"outgoing_validation_failed")
		assert_eq(cached.files.snapshot_persisted(), cached_before_files)
		assert_eq(uncached.files.snapshot_persisted(), reference_before_files)
		assert_eq(cached.files.operation_trace(), cached_before_trace)
		assert_eq(uncached.files.operation_trace(), reference_before_trace)
		assert_eq(cached.manager._journal.capture_state(), cached_before_journal)
		assert_eq(uncached.manager._journal.capture_state(), reference_before_journal)
		assert_gt(_validation_count(cached.port), 0,
			"a non-object candidate must fall through to strict text validation")
		assert_gt(_validation_count(uncached.port), 0)

func test_schema_invalid_and_canonical_invalid_candidates_preserve_reference_precedence() -> void:
	for invalid_kind: String in ["schema", "canonical"]:
		var cached := _wired()
		var uncached := _wired(false)
		var candidate := _prepare(cached, 131)
		var reference := _prepare(uncached, 131)
		for value: Dictionary in [candidate, reference]:
			if invalid_kind == "schema":
				value["autosave_document"]["current_snapshot"]["snapshot"]["gameplay"]["narrative_variables"] = "invalid"
			else:
				# The value is also schema-invalid, but canonical emission owns this earlier failure.
				value["autosave_document"]["kind"] = Vector2.ONE
		var cached_before_files: Dictionary = cached.files.snapshot_persisted()
		var reference_before_files: Dictionary = uncached.files.snapshot_persisted()
		var cached_before_trace: Array = cached.files.operation_trace()
		var reference_before_trace: Array = uncached.files.operation_trace()
		var cached_before_journal: Dictionary = cached.manager._journal.capture_state()
		var reference_before_journal: Dictionary = uncached.manager._journal.capture_state()
		var rejected: Dictionary = cached.port.commit(candidate)
		var original: Dictionary = uncached.port.commit(reference)
		assert_eq(rejected, original, invalid_kind)
		assert_eq(rejected.get("code"),
			&"outgoing_validation_failed" if invalid_kind == "schema" else &"canonical_serialization_failed")
		assert_eq(cached.files.snapshot_persisted(), cached_before_files)
		assert_eq(uncached.files.snapshot_persisted(), reference_before_files)
		assert_eq(cached.files.operation_trace(), cached_before_trace)
		assert_eq(uncached.files.operation_trace(), reference_before_trace)
		assert_eq(cached.manager._journal.capture_state(), cached_before_journal)
		assert_eq(uncached.manager._journal.capture_state(), reference_before_journal)
		if invalid_kind == "schema":
			assert_gt(_validation_count(cached.port), 0,
				"schema failures cannot enter the success-only exact-text cache")
			assert_gt(_validation_count(uncached.port), 0)
		else:
			assert_eq(_validation_count(cached.port), 0,
				"canonical failure must happen before any text validation")
			assert_eq(_validation_count(uncached.port), 0)

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
		# dwm-634.1: the write reads back only the promoted final. Candidate and backup bytes are
		# proven by the next reconcile, so their read-time corruption hooks never fire here.
		assert_eq(cached.files.corrupted, suffix == "final", suffix)
		assert_eq(committed, original, suffix)
		assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted(), suffix)
		assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(), suffix)
		assert_eq(cached.manager._journal.capture_state(), uncached.manager._journal.capture_state(), suffix)
		if suffix == "final":
			assert_gt(int(cached.port.validations.get("{broken", 0)), 0, "changed text is strictly validated")
		else:
			assert_true(committed.get("ok", false), suffix)
			assert_eq(int(cached.port.validations.get("{broken", 0)), 0, "%s is not read back at write time" % suffix)

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
	assert_eq(_validation_count(wired.port), 0,
		"retry must rebuild a detached schema proof without reparsing its exact text")
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
	# dwm-634.2: validation is a pure function of the exact text; a document proven by its own
	# reread-verified commit stays proven across frames.
	assert_eq(wired.port.validations.get(old_text, 0), 0,
		"a committed document is not validated again in a later frame")

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
		# dwm-634.2: a failed prepare or a released lease changes no proven document; reconfigure
		# and rollback forget every proven document.
		var revalidated: int = 1 if interruption in ["reconfigure", "rollback"] else 0
		assert_eq(wired.port.validations.get(old_text, 0), revalidated, interruption)
		assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))

func test_committed_documents_are_remembered_bounded_and_forgotten_on_capability_change() -> void:
	var wired := _wired()
	var texts: Array[String] = []
	for money: int in [900, 901, 902, 903]:
		assert_true(wired.port.commit(_prepare(wired, money)).get("ok", false))
		texts.append(str(wired.storage.read_text("autosave.json").value))
	# Four commits: current 903, previous 902, older backup 901 are proven; 900 has left the memo.
	var cache := {}
	wired.port.validations.clear()
	for text: String in texts.slice(1):
		assert_true(wired.port._cached_document_text_validator(text, cache).get("ok", false))
	assert_eq(_validation_count(wired.port), 0, "the last three committed documents are proven")
	assert_true(wired.port._cached_document_text_validator(texts[0], cache).get("ok", false))
	assert_eq(wired.port.validations.get(texts[0], 0), 1, "the memo is bounded to the last three documents")
	wired.port.validations.clear()
	wired.gate.capability_changed.emit({})
	assert_true(wired.port._cached_document_text_validator(texts[3], {}).get("ok", false))
	assert_eq(wired.port.validations.get(texts[3], 0), 1, "a capability change forgets every proven document")

func test_a_failed_commit_proves_nothing() -> void:
	var wired := _wired(true, true)
	assert_true(wired.port.commit(_prepare(wired, 950)).get("ok", false))
	var candidate := _prepare(wired, 951)
	var outgoing: String = WRITER.stringify(candidate.autosave_document).value + "\n"
	wired.storage.alter_reread = true
	assert_eq(wired.port.commit(candidate).get("code"), &"reread_mismatch")
	wired.storage.alter_reread = false
	wired.port.validations.clear()
	assert_true(wired.port._cached_document_text_validator(outgoing, {}).get("ok", false))
	assert_eq(wired.port.validations.get(outgoing, 0), 1, "a document whose commit failed is validated again")

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
			# dwm-634.2: the prepared proof is consumed, but the previous document stays proven by
			# its own earlier commit; a failed commit changes nothing about that file.
			assert_eq(wired.port.validations.get(old_text, 0), 0,
				"a proven previous document survives a failed commit")


# -------------------------------------------------------------------------------------------------
# A6: _capture_storage_backup() reads nothing but `ok` from the validation of the document already on
# disk, yet _cached_document_text_validator() hands it a 450 KB deep copy of the whole proven
# candidate to do it. A proof variant answers the question without the copy. Everything else must be
# untouched: the same physical operations, the same bytes, the same refusals returned verbatim, and
# the cold-miss seed still written into the prepare-side cache -- that seed is what keeps
# write_atomic()'s reconcile from parsing the existing document a second time.
# -------------------------------------------------------------------------------------------------

func _commit_round(cached: Dictionary, uncached: Dictionary, money: int) -> void:
	cached.port.validations.clear()
	uncached.port.validations.clear()
	var candidate := _prepare(cached, money)
	var reference := _prepare(uncached, money)
	var committed: Dictionary = cached.port.commit(candidate)
	var original: Dictionary = uncached.port.commit(reference)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(committed, original, "the proof path returns the reference result")
	assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted(),
		"the proof path writes the reference bytes")
	assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(),
		"all physical reads, hashes, writes, flushes and rename boundaries remain")


func test_storage_backup_proof_keeps_every_validation_and_disk_operation_without_copying_the_proof() -> void:
	var cached := _wired()
	var uncached := _wired(false)

	for money: int in [201, 202, 203]:
		_commit_round(cached, uncached, money)
		assert_eq(_validation_count(cached.port), 0,
			"a warm backup proof parses nothing: the existing document was proven at its own commit")
		assert_gt(_validation_count(uncached.port), 0,
			"reuse=false still forces the original strict text validator")

	# Cold miss: nothing is proven any more, so the document already on disk must be parsed once.
	cached.port._forget_proven_documents()
	uncached.port._forget_proven_documents()
	_commit_round(cached, uncached, 204)
	var cold_count := _validation_count(cached.port)
	assert_gt(cold_count, 0, "a cold backup proof really does parse the existing document")
	assert_true(cold_count <= _validation_count(uncached.port),
		"a cold proof never parses more than the reuse=false reference")

	# ...and the next commit is warm again, because that cold parse was remembered.
	_commit_round(cached, uncached, 205)
	assert_eq(_validation_count(cached.port), 0,
		"the cold parse was remembered, so the following backup proof is free again")

	var text := (cached.files.snapshot_persisted()[FINAL] as PackedByteArray).get_string_from_utf8()
	assert_true(cached.port.has_method("_cached_document_text_proof"),
		"the backup proof path exists: _capture_storage_backup needs only ok, never a 450 KB value")

	# A cold proof still seeds the prepare-side cache with the FULL validation, because that seed is
	# what write_atomic()'s reconcile reuses instead of parsing the existing document again.
	cached.port._forget_proven_documents()
	var seed_cache := {}
	var cold: Dictionary = cached.port._cached_document_text_proof(text, seed_cache)
	assert_true(cold.get("ok", false), str(cold))
	assert_true(seed_cache.has(text), "a cold proof seeds the cache it was given")
	assert_true((seed_cache[text] as Dictionary).has("value"),
		"the seed is the whole validation, so a later validator call can answer from it")
	assert_true(WRITER._deep_same((seed_cache[text] as Dictionary).get("value"),
		cached.port._cached_document_text_validator(text, {}).get("value")),
		"the seeded value is the one the validator itself would have produced")

	# A hit answers the only question _capture_storage_backup asks, and carries no copy of the proof.
	var hit: Dictionary = cached.port._cached_document_text_proof(text, seed_cache)
	assert_true(hit.get("ok", false), str(hit))
	assert_false(hit.has("value"), "a proof hit answers ok without copying the proven candidate")
	assert_eq(hit.get("code"), &"ok")

	# Refusals are returned verbatim: _capture_storage_backup returns the refusal it is handed.
	var broken := "{broken"
	var refused: Dictionary = cached.port._cached_document_text_proof(broken, {})
	assert_false(refused.get("ok", true), "a proof of an unparseable document refuses")
	assert_eq(refused, cached.port._document_text_validator(broken),
		"the refusal is the validator's own, unchanged")


# -------------------------------------------------------------------------------------------------
# A7: the storage lease for an outgoing text must describe the bytes that text actually is. On the
# splice path the bytes of recovery_journal[k] come from the journal's remembered text for that
# bundle -- _splice_autosave_text() reads nothing from the in-memory bundle but its checkpoint_id --
# while the seed handed to write_atomic() is built by validating the in-memory document. The two
# agree only as long as nobody touches the retained journal between prepare and commit.
# -------------------------------------------------------------------------------------------------

func _written_text(wired: Dictionary) -> String:
	return (wired.files.snapshot_persisted()[FINAL] as PackedByteArray).get_string_from_utf8()


func _strict_candidate(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT.parse_object(text)
	assert_true(parsed.get("ok", false), str(parsed))
	var validated: Dictionary = DOCUMENT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), str(validated))
	return validated["value"]["candidate"]


func test_three_bundle_seed_equals_a_strict_reparse_of_the_written_document() -> void:
	var wired := _wired()
	for money: int in [301, 302, 303]:
		var candidate := _prepare(wired, money)
		assert_true(wired.port.commit(candidate).get("ok", false))

	var written_text := _written_text(wired)
	var reparsed := _strict_candidate(written_text)
	var retained: Array = wired.manager._journal.capture_state()["value"]["backup"]["earlier"]
	assert_eq((reparsed["recovery_journal"] as Array).size(), retained.size(),
		"the written document carries exactly the journal's retained earlier bundles")
	assert_gt(retained.size(), 1, "the fixture must reach a three-bundle document")
	for bundle: Dictionary in retained:
		var remembered: String = wired.manager._journal.get_retained_bundle_text(
			str((bundle["snapshot"] as Dictionary)["checkpoint_id"]))
		assert_false(remembered.is_empty(), "every earlier bundle kept the text its own commit proved")
		assert_true(written_text.find(remembered) >= 0,
			"the written bytes really are the spliced remembered texts, not a fresh emission")

	var proven: Dictionary = wired.port._cached_document_text_validator(written_text, {})
	assert_true(proven.get("ok", false), str(proven))
	assert_true(WRITER._deep_same(proven.get("value"), reparsed),
		"the lease for these bytes is what a strict re-parse of them produces")
	assert_false((proven["value"]["recovery_journal"] as Array).is_typed(),
		"the leased journal is a plain untyped Array, as validate() composes it")
	assert_false((reparsed["recovery_journal"] as Array).is_typed())


func test_a_journal_bundle_mutated_between_prepare_and_commit_cannot_diverge_the_lease_from_the_bytes() -> void:
	var wired := _wired()
	for money: int in [401, 402]:
		var warmup := _prepare(wired, money)
		assert_true(wired.port.commit(warmup).get("ok", false))

	var candidate := _prepare(wired, 403)
	var journal_candidate: Dictionary = candidate["journal_candidate"]
	var retained_current: Dictionary = (journal_candidate["current"] as Dictionary).duplicate(true)
	var retained_earlier: Array = (journal_candidate["earlier"] as Array).duplicate(true)
	assert_gt(retained_earlier.size(), 0, "the fixture must produce at least one earlier bundle")

	var document: Dictionary = candidate["autosave_document"]
	var entries: Array = document["recovery_journal"]
	assert_eq(entries.size(), retained_earlier.size())
	var committed_money := int(((retained_earlier[0] as Dictionary)["snapshot"] as Dictionary)
		["gameplay"]["money"])
	# The caller keeps the candidate and edits a bundle the journal already committed.
	((entries[0] as Dictionary)["snapshot"] as Dictionary)["gameplay"]["money"] = 999999
	assert_true(int(((entries[0] as Dictionary)["snapshot"] as Dictionary)["gameplay"]["money"])
		!= committed_money, "the mutation really did change the in-memory journal bundle")

	wired.port.validations.clear()
	var committed: Dictionary = wired.port.commit(candidate)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(_validation_count(wired.port), 0,
		"the outgoing text was leased from the seed rather than parsed, so the seed IS the lease")

	# The bytes are the journal's own: the full writer over the bundles the journal retained.
	var written_text := _written_text(wired)
	var expected_document: Dictionary = DOCUMENT.build(
		&"autosave", null, &"automatic", retained_current, retained_earlier)
	assert_true(expected_document.get("ok", false), str(expected_document))
	var expected_emitted: Dictionary = WRITER.stringify(expected_document["value"])
	assert_true(expected_emitted.get("ok", false), str(expected_emitted))
	assert_eq(written_text, str(expected_emitted["value"]) + "\n",
		"the written bytes are the full writer over the JOURNAL-retained bundles")

	var reparsed := _strict_candidate(written_text)
	assert_eq(int((((reparsed["recovery_journal"] as Array)[0] as Dictionary)["snapshot"] as Dictionary)
		["gameplay"]["money"]), committed_money,
		"the bytes carry the bundle's committed money, never the mutated in-memory copy")

	var proven: Dictionary = wired.port._cached_document_text_validator(written_text, {})
	assert_true(proven.get("ok", false), str(proven))
	assert_eq(int((((proven["value"]["recovery_journal"] as Array)[0] as Dictionary)["snapshot"]
		as Dictionary)["gameplay"]["money"]), committed_money,
		"a lease for these bytes cannot report a value the bytes never had")
	assert_true(WRITER._deep_same(proven.get("value"), reparsed),
		"the storage lease for a text must deep-equal a strict re-parse of that same text")


# -------------------------------------------------------------------------------------------------
# Reviewer finding on the splice: commit() remembers the canonical text of the document's CURRENT
# bundle under the id the journal just committed, but the document's bundle and the journal's are two
# objects (`build()` composes the document's from `RunSnapshotSchema.validate()`'s fresh candidate),
# and a caller may edit the document's copy in place between prepare and commit. Those edited bytes
# are written and accepted -- that is the law -- but the journal then holds an UNEDITED bundle under
# the id whose remembered text is edited. The next autosave splices that text while the lease is
# composed from the retained bundle, so lease and bytes diverge again. A text may only be remembered
# for a bundle it actually describes.
# -------------------------------------------------------------------------------------------------

func test_an_edited_current_bundle_is_written_but_never_remembered_for_a_later_splice() -> void:
	var wired := _wired()
	var candidate := _prepare(wired, 501)
	var first_id := str(candidate["checkpoint_id"])
	var document: Dictionary = candidate["autosave_document"]
	var journal_current: Dictionary = candidate["journal_candidate"]["current"]
	var edited_money := 987654

	# The caller edits the outgoing current bundle in place after prepare. It stays schema-valid, so
	# these bytes are written and accepted.
	((document["current_snapshot"] as Dictionary)["snapshot"] as Dictionary)["gameplay"]["money"] = edited_money
	assert_eq(int((journal_current["snapshot"] as Dictionary)["gameplay"]["money"]), 501,
		"the journal candidate still holds the UNEDITED bundle: the document's is its own object")

	var committed: Dictionary = wired.port.commit(candidate)
	assert_true(committed.get("ok", false), str(committed))
	var first_text := _written_text(wired)
	assert_eq(int((_strict_candidate(first_text)["current_snapshot"] as Dictionary)["snapshot"]
		["gameplay"]["money"]), edited_money, "the edited bundle is what was written, as today")
	assert_eq(wired.manager._journal.get_retained_bundle_text(first_id), "",
		"a text that does not describe the bundle the journal retained is not remembered")

	# With nothing remembered for that bundle, the next autosave is emitted by the whole-document
	# writer over the bundles the journal actually holds -- and its lease describes those bytes.
	var second := _prepare(wired, 502)
	var second_journal: Dictionary = second["journal_candidate"]
	var retained_current: Dictionary = (second_journal["current"] as Dictionary).duplicate(true)
	var retained_earlier: Array = (second_journal["earlier"] as Array).duplicate(true)
	assert_gt(retained_earlier.size(), 0, "the edited bundle is retained history by now")
	assert_true(wired.port.commit(second).get("ok", false))

	var second_text := _written_text(wired)
	var expected_document: Dictionary = DOCUMENT.build(
		&"autosave", null, &"automatic", retained_current, retained_earlier)
	assert_true(expected_document.get("ok", false), str(expected_document))
	var expected_emitted: Dictionary = WRITER.stringify(expected_document["value"])
	assert_true(expected_emitted.get("ok", false), str(expected_emitted))
	assert_eq(second_text, str(expected_emitted["value"]) + "\n",
		"the bytes are the full writer over the JOURNAL-retained bundles")
	var reparsed := _strict_candidate(second_text)
	assert_eq(int((((reparsed["recovery_journal"] as Array)[0] as Dictionary)["snapshot"] as Dictionary)
		["gameplay"]["money"]), 501,
		"the retained bundle, not the edit, is what the journal entry says")
	var proven: Dictionary = wired.port._cached_document_text_validator(second_text, {})
	assert_true(proven.get("ok", false), str(proven))
	assert_true(WRITER._deep_same(proven.get("value"), reparsed),
		"the lease for these bytes deep-equals a strict re-parse of them")

	# Guard, green today and after: an UNEDITED commit is still remembered, or the gate would have
	# silently disabled the splice for every save rather than only for edited bundles.
	var third := _prepare(wired, 503)
	var third_id := str(third["checkpoint_id"])
	assert_true(wired.port.commit(third).get("ok", false))
	assert_false(wired.manager._journal.get_retained_bundle_text(third_id).is_empty(),
		"an unedited current bundle is still remembered for the next splice")


# -------------------------------------------------------------------------------------------------
# A8 (dwm-634.3): storage reads nothing from the validations this port hands it on the commit,
# rollback and read-repair paths but `ok` and whether the value is a Dictionary -- the port itself
# discards every one of those values. Each hit on an already-proven text nonetheless deep-copies the
# whole ~450 KB candidate several times over (_classify_document per artifact, reconcile's return,
# the final read-back, write_atomic's own return). A witness answers those calls with an EMPTY
# value. A text that is not proven still takes the full validation, so every refusal, its order and
# the bytes on disk are exactly what they were.
# -------------------------------------------------------------------------------------------------

func _witness_call(port: CountingPort, text: String, cache: Dictionary) -> Dictionary:
	var result: Variant = port.call(WITNESS, text, cache)
	assert_eq(typeof(result), TYPE_DICTIONARY, "the witness answers with a Dictionary")
	if typeof(result) != TYPE_DICTIONARY:
		return {}
	return result as Dictionary


func _function_source(source: String, name: String) -> String:
	var start := source.find("\nfunc " + name + "(")
	assert_gt(start, -1, "the port declares func %s()" % name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 1)
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _assert_binds(body: String, needle: String, message: String) -> void:
	assert_true(body.find(needle) >= 0, "%s -- expected the source to carry `%s`" % [message, needle])


func test_witness_answers_a_proven_document_with_an_empty_value() -> void:
	var wired := _wired()
	assert_true(wired.port.commit(_prepare(wired, 1001)).get("ok", false))
	assert_true(wired.port.has_method(WITNESS),
		"dwm-634.3: the port must declare %s() for the storage calls whose value it discards" % WITNESS)
	if not wired.port.has_method(WITNESS):
		return
	var committed_text: String = str(wired.storage.read_text("autosave.json").value)
	assert_false(committed_text.is_empty(), "the committed document is readable through storage")
	wired.port.validations.clear()
	var witnessed := _witness_call(wired.port, committed_text, {})
	assert_true(witnessed.get("ok", false), str(witnessed))
	assert_eq(witnessed.get("code"), &"ok")
	assert_eq(typeof(witnessed.get("value")), TYPE_DICTIONARY,
		"_classify_document() refuses a validation whose value is not a Dictionary")
	assert_true((witnessed.get("value") as Dictionary).is_empty(),
		"a proven document is witnessed without a copy of the candidate")
	assert_eq(wired.port.validations.get(committed_text, 0), 0,
		"a proven document is not parsed a second time")


func test_witness_validates_an_unknown_document_exactly_like_the_validator() -> void:
	var wired := _wired()
	assert_true(wired.port.has_method(WITNESS),
		"dwm-634.3: the port must declare %s()" % WITNESS)
	if not wired.port.has_method(WITNESS):
		return
	var candidate := _prepare(wired, 1002)
	var emitted: Dictionary = WRITER.stringify(candidate.autosave_document)
	assert_true(emitted.get("ok", false), str(emitted))
	# Never written, never committed, never proven: a cold text takes the whole validation.
	var unknown := str(emitted["value"]) + "\n"
	var cache := {}
	wired.port.validations.clear()
	var witnessed := _witness_call(wired.port, unknown, cache)
	assert_true(witnessed.get("ok", false), str(witnessed))
	assert_eq(wired.port.validations.get(unknown, 0), 1, "an unknown document is parsed in full")
	assert_eq(typeof(witnessed.get("value")), TYPE_DICTIONARY)
	assert_false((witnessed.get("value") as Dictionary).is_empty(),
		"an unknown document is witnessed with the whole candidate, as storage saw before")
	var reference: Dictionary = wired.port._document_text_validator(unknown)
	assert_true(reference.get("ok", false), str(reference))
	var witnessed_canonical: Dictionary = WRITER.stringify(witnessed.get("value"))
	var reference_canonical: Dictionary = WRITER.stringify(reference.get("value"))
	assert_true(witnessed_canonical.get("ok", false), str(witnessed_canonical))
	assert_eq(str(witnessed_canonical.get("value")), str(reference_canonical.get("value")),
		"the cold value is the validator's own candidate, compared by canonical text")
	assert_true(cache.has(unknown), "a cold witness seeds the cache it was given")
	assert_true((cache[unknown] as Dictionary).has("value"),
		"the seed is the whole validation, so this call's later classifications answer from it")
	wired.port.validations.clear()
	var repeated := _witness_call(wired.port, unknown, cache)
	assert_true(repeated.get("ok", false), str(repeated))
	assert_true((repeated.get("value") as Dictionary).is_empty(), "a seeded text is witnessed empty")
	assert_eq(wired.port.validations.get(unknown, 0), 0, "a seeded text is not parsed again")
	var broken := "{\"schema_version\":1,\"schema_version\":1}"
	var refused := _witness_call(wired.port, broken, {})
	assert_false(refused.get("ok", true), "an invalid document is refused")
	assert_eq(refused.get("code"), wired.port._document_text_validator(broken).get("code"),
		"the refusal carries the validator's own code")
	assert_eq(refused, wired.port._document_text_validator(broken),
		"the whole refusal is returned verbatim; storage quotes its message")


func test_commit_and_rollback_hand_storage_the_witness() -> void:
	var source := FileAccess.get_file_as_string(PORT_SOURCE)
	assert_false(source.is_empty(), "the port source is readable")
	var commit_source := _function_source(source, "commit")
	_assert_binds(commit_source, WITNESS + ".bind(validated_texts)", "commit() binds the witness")
	_assert_binds(commit_source, "AUTOSAVE_RELATIVE_PATH, outgoing_text, witness)",
		"commit() hands write_atomic() the witness")
	_assert_binds(commit_source, "witness.call(reread_text)",
		"commit() validates its own reread with the witness; it reads nothing but ok")
	var rollback_source := _function_source(source, "rollback")
	_assert_binds(rollback_source, WITNESS + ".bind({})", "rollback() binds the witness")
	_assert_binds(rollback_source, "str(descriptor.get(\"validated_text\", \"\")), witness)",
		"rollback() hands write_atomic() the witness")
	_assert_binds(rollback_source, "reconcile(relative_path, witness)",
		"rollback() hands reconcile() the witness")
	var repair_source := _function_source(source, "_capture_storage_backup")
	_assert_binds(repair_source, "relative_path, " + WITNESS + ".bind(validated_texts))",
		"the read-repair reconcile takes the witness; only its refusal is read")


func test_externally_corrupted_autosave_is_refused_and_rolled_back_like_the_reference() -> void:
	var cached := _wired()
	var uncached := _wired(false)
	assert_true(cached.port.commit(_prepare(cached, 1003)).get("ok", false))
	assert_true(uncached.port.commit(_prepare(uncached, 1003)).get("ok", false))
	var candidate := _prepare(cached, 1004)
	var reference := _prepare(uncached, 1004)
	var cached_backup := {"journal_backup": cached.port.capture().value.backup,
		"storage_backup": candidate.storage_backup}
	var uncached_backup := {"journal_backup": uncached.port.capture().value.backup,
		"storage_backup": reference.storage_backup}

	# Corrupted outside the port: the bytes change with no file operation of its own, so nothing the
	# port proved describes them any more.
	cached.files._persisted[FINAL] = "{broken".to_utf8_buffer()
	uncached.files._persisted[FINAL] = "{broken".to_utf8_buffer()
	cached.port.validations.clear()
	uncached.port.validations.clear()
	var refused: Dictionary = cached.port.commit(candidate)
	var original: Dictionary = uncached.port.commit(reference)
	assert_false(refused.get("ok", true), "a corrupt final artifact is refused")
	assert_eq(refused.get("code"), original.get("code"), "the witness path refuses with the reference code")
	assert_gt(int(cached.port.validations.get("{broken", 0)), 0,
		"an unproven text is still strictly parsed: the witness never witnesses what it has not proven")
	assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted(),
		"the refusal preserves the reference bytes")
	assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(),
		"the refusal performs the reference physical operations")
	assert_eq(cached.manager._journal.capture_state(), uncached.manager._journal.capture_state())

	var rolled: Dictionary = cached.port.rollback(cached_backup)
	var rolled_reference: Dictionary = uncached.port.rollback(uncached_backup)
	assert_eq(rolled.get("ok", false), rolled_reference.get("ok", false), "rollback agrees on the outcome")
	assert_eq(rolled.get("code"), rolled_reference.get("code"), "rollback agrees on the code")
	assert_eq(cached.files.snapshot_persisted(), uncached.files.snapshot_persisted(),
		"rollback leaves the reference bytes")
	assert_eq(cached.files.operation_trace(), uncached.files.operation_trace(),
		"rollback performs the reference physical operations")
