extends "res://addons/gut/test.gd"
## Admission diagnostics with real journal validators and memory storage. The retained
## Save9 envelope deliberately lacks Run semantics: early inspection may classify it,
## but no ordinary Load may accept it. New Run pair recovery is retired.
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const RESTORE := preload("res://tests/unit/test_scene_restore_journal.gd")
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
	var document := {"schema_version": 9, "kind": "slot", "slot_id": 1,
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

func test_early_scope_ignores_optional_metadata_without_rewriting_retained_operation() -> void:
	var storage := ObservedStorage.new()
	var journal := JOURNAL.new()
	assert_true(journal.configure(storage, RESTORE.SourceLoader.new()).ok)
	var operation := _restore_operation(journal)
	operation.selected_document["save_reason"] = {"obsolete": true}
	operation.selected_document["saved_time"] = "invalid-time"
	operation.request_fingerprint = _hash({"kind": "scene_restore", "transaction_id": operation.transaction_id,
		"source_locator": operation.source_locator, "selected_document": operation.selected_document})
	storage.text = WRITER.stringify({"schema_version": 5, "operations": {operation.transaction_id: operation}}).value
	var original := storage.text
	var result: Dictionary = journal.with_creation_storage_recovery(func(): return journal.list_incomplete())
	assert_true(result.ok, str(result))
	assert_eq(storage.text, original, "retired metadata never rewrites immutable retry bytes")
	assert_eq(storage.writes, 0)


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

func test_startup_scope_retires_obsolete_load_before_listing_creation_recovery() -> void:
	var storage := ObservedStorage.new()
	var loader := RESTORE.SourceLoader.new()
	var journal := JOURNAL.new()
	assert_true(journal.configure(storage, loader).ok)
	var operation := _restore_operation(journal)
	operation.selected_document = {"obsolete": "no current story admission"}
	storage.text = WRITER.stringify({"schema_version": 5,
		"operations": {operation.transaction_id: operation}}).value
	var result: Dictionary = journal.with_creation_storage_recovery(func() -> Dictionary:
		var retired: Dictionary = journal.retire_scene_restore_operations()
		assert_true(retired.ok, str(retired))
		if not retired.ok: return retired
		assert_eq(retired.value.removed, 1)
		assert_eq(storage.reads, 1)
		var listed: Dictionary = journal.list_incomplete()
		assert_true(listed.ok, str(listed))
		if listed.ok: assert_eq(listed.value, [])
		assert_eq(storage.reads, 1, "early recovery uses the already admitted transition result")
		assert_false(journal.prepare_intent({}).ok, "ordinary producers remain barred in early recovery")
		return listed)
	assert_true(result.ok, str(result))
	assert_eq(storage.writes, 1)
	assert_eq(loader.calls, [])
	assert_true(journal.retire_scene_restore_operations().ok)
	assert_eq(storage.reads, 1, "normal startup phase does not repeat the transition")
	assert_eq(journal.list_incomplete().value, [])
	assert_eq(storage.reads, 2, "normal validation still gets its own read")
