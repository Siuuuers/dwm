extends "res://addons/gut/test.gd"
## Admission diagnostics with real journal validators and memory storage. The retained
## Save9 envelope deliberately lacks Run semantics: early inspection may classify it,
## but no ordinary Load may accept it. Physical pair recovery has integration coverage.
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const RESTORE := preload("res://tests/unit/test_scene_restore_journal.gd")
const MATERIALS := preload("res://tests/unit/test_new_run_materials.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class ObservedStorage extends RESTORE.MemoryStorage:
	var reads := 0
	func reconcile(path: String, parser: Callable) -> Dictionary:
		reads += 1
		return super.reconcile(path, parser)

func _hash(value: Variant) -> String:
	return WRITER.stringify(value).value.sha256_text()

func _restore_operation(journal: RefCounted) -> Dictionary:
	var tx := "transaction_id." + "a".repeat(64)
	var snapshot := {"schema_version": 9, "checkpoint_id": "selected"}
	var bundle := {"checkpoint_kind": "manual_save", "snapshot": snapshot}
	var document := {"schema_version": 9, "kind": "slot", "slot_id": 1, "save_reason": "manual",
		"current_snapshot": bundle, "recovery_journal": []}
	var locator := {"slot_id": "slot:1", "checkpoint_id": "selected",
		"bundle_id": _hash(bundle), "document_sha256": _hash(snapshot)}
	var request := {"kind": "scene_restore", "transaction_id": tx,
		"source_locator": locator, "selected_document": document,
		"allocation_candidate_fingerprint": "b".repeat(64), "initial_context": null,
		"initial_context_sha256": null, "new_run_materials": null,
		"transaction_issuer_receipt": {"counter": 0, "namespace": "e".repeat(64),
			"numeric_value": null, "purpose": "transaction_id", "receipt_id": "issuer_receipt." + "f".repeat(64), "token": tx}}
	request["request_fingerprint"] = _hash({"kind": "scene_restore", "transaction_id": tx,
		"source_locator": locator, "selected_document": document})
	# Pure construction is not admission; every test below uses the real loader.
	return journal._intent_candidate(request)

func _advance_request(operation: Dictionary) -> Dictionary:
	return {"transaction_id": operation.transaction_id, "request_fingerprint": operation.request_fingerprint,
		"expected_stage": JOURNAL.STAGE_INTENT, "next_stage": JOURNAL.STAGE_ALLOCATED,
		"expected_next_participant_index": 0, "allocation_receipt": {"diagnostic": true},
		"participant_name": null, "participant_receipt": null, "failure": null}

func _scope_and_full_read(return_failure: bool) -> void:
	var storage := ObservedStorage.new()
	var loader := RESTORE.SourceLoader.new()
	var journal := JOURNAL.new()
	assert_true(journal.configure(storage, loader).ok)
	var operation := _restore_operation(journal)
	storage.text = WRITER.stringify({"schema_version": 5, "operations": {operation.transaction_id: operation}}).value
	var original := storage.text
	var result: Dictionary = journal.with_creation_storage_recovery(func() -> Dictionary:
		var listed: Dictionary = journal.list_incomplete()
		assert_true(listed.get("ok", false), str(listed))
		if not listed.get("ok", false): return listed
		assert_eq(listed.value, [{"kind": "scene_restore", "transaction_id": operation.transaction_id}])
		assert_eq(journal.get_operation(operation.transaction_id).get("code"), &"creation_storage_recovery_only")
		assert_eq(journal.advance(_advance_request(operation)).get("code"), &"creation_storage_recovery_only")
		assert_eq(journal.reconcile_startup(operation.transaction_id, RESTORE.IssuerShapeOnly.new()).get("code"), &"creation_storage_recovery_only")
		assert_eq(journal.acknowledge_scene_activation(operation.transaction_id, operation.request_fingerprint).get("code"), &"creation_storage_recovery_only")
		assert_eq(journal.with_creation_storage_recovery(func(): return {"ok": true}).get("code"), &"creation_storage_recovery_busy")
		return {"ok": false, "code": &"TEST.callback_failure"} if return_failure else {"ok": true})
	assert_eq(result.ok, not return_failure)
	if return_failure: assert_eq(result.code, &"TEST.callback_failure")
	var prior_reads := storage.reads
	var ordinary: Dictionary = journal.get_operation(operation.transaction_id)
	assert_false(ordinary.get("ok", false), "Early envelope admission must not become ordinary Run admission.")
	assert_ne(ordinary.get("code"), &"creation_storage_recovery_only", "Scope ended even after callback refusal.")
	assert_gt(storage.reads, prior_reads, "Full admission rereads physical bytes, not the partial validation cache.")
	assert_eq(storage.text, original)
	assert_eq(storage.writes, 0)
	assert_eq(loader.calls, [])

func test_successful_scope_does_not_cache_partial_restore_admission() -> void:
	_scope_and_full_read(false)

func test_failed_scope_does_not_cache_partial_restore_admission() -> void:
	_scope_and_full_read(true)

func test_early_scope_rejects_changed_source_hash_and_request_binding() -> void:
	for damage: String in ["snapshot_hash", "request_fingerprint", "slot"]:
		var storage := ObservedStorage.new()
		var journal := JOURNAL.new()
		assert_true(journal.configure(storage, RESTORE.SourceLoader.new()).ok)
		var operation := _restore_operation(journal)
		if damage == "snapshot_hash": operation.source_locator.document_sha256 = "0".repeat(64)
		elif damage == "request_fingerprint": operation.request_fingerprint = "0".repeat(64)
		else: operation.source_locator.slot_id = "slot:2"
		storage.text = WRITER.stringify({"schema_version": 5, "operations": {operation.transaction_id: operation}}).value
		var original := storage.text
		var result: Dictionary = journal.with_creation_storage_recovery(func(): return journal.list_incomplete())
		assert_false(result.get("ok", false), damage)
		assert_eq(storage.text, original)
		assert_eq(storage.writes, 0)

func test_creation_recovery_can_reconcile_and_record_ordered_pair_targets() -> void:
	var built: Dictionary = MATERIALS.make_valid_fixture()
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return
	var fixture: Dictionary = built.value
	var storage := ObservedStorage.new()
	var loader := RESTORE.SourceLoader.new()
	var journal := JOURNAL.new()
	assert_true(journal.configure(storage, loader).ok)
	var prepared: Dictionary = journal.prepare_intent(MATERIALS.make_intent_request(fixture))
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_true(journal.commit_intent(prepared.value).ok)
	var result: Dictionary = journal.with_creation_storage_recovery(func() -> Dictionary:
		var recovered: Dictionary = journal.reconcile_startup(fixture.transaction_id, RESTORE.IssuerShapeOnly.new())
		assert_true(recovered.get("ok", false), str(recovered))
		if not recovered.get("ok", false): return recovered
		var fetched: Dictionary = journal.get_operation(fixture.transaction_id)
		assert_true(fetched.get("ok", false), str(fetched))
		if not fetched.get("ok", false): return fetched
		var request := _advance_request(fetched.value)
		request.allocation_receipt = fixture.allocation_candidate
		var allocated: Dictionary = journal.advance(request)
		assert_true(allocated.get("ok", false), str(allocated))
		if not allocated.get("ok", false): return allocated
		for target: String in JOURNAL.NEW_RUN_TARGET_ORDER:
			var recorded: Dictionary = journal.record_new_run_target(fixture.transaction_id, fixture.request_fingerprint,
				StringName(target), journal._expected_new_run_target_revision(allocated.value, target))
			assert_true(recorded.get("ok", false), str(recorded))
			if not recorded.get("ok", false): return recorded
		return {"ok": true})
	assert_true(result.get("ok", false), str(result))
	var reread: Dictionary = journal.get_operation(fixture.transaction_id)
	assert_true(reread.get("ok", false), str(reread))
	if not reread.get("ok", false): return
	assert_eq(reread.value.new_run_materials, fixture.materials)
	assert_eq(reread.value.stage, JOURNAL.STAGE_ALLOCATED, "Early scope did not publish live participant activation.")
	assert_eq(reread.value.new_run_targets, {"identity": fixture.allocation_fingerprint,
		"autosave": fixture.materials.autosave.outgoing_hash, "profile": fixture.materials.profile.outgoing_hash})
	assert_eq(loader.calls, [])
