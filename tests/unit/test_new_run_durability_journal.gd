extends "res://addons/gut/test.gd"

const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const STORAGE := preload("res://tests/support/FakeDesktopContinuationJournalStorage.gd")
const FIXTURE := preload("res://tests/unit/test_new_run_materials.gd")

const STAGE_INTENT := "intent_committed"
const STAGE_ALLOCATED := "identity_allocation_committed"
const STAGE_APPLYING := "participants_applying"
const STAGE_ABORTED := "aborted"
const JOURNAL_PATH := "desktop-continuation-operations.json"

var _storage: RefCounted
var _journal: RefCounted
var _fixture: Dictionary


class UnusedSourceLoader extends RefCounted:
	func load_context(_source_locator: Variant) -> Dictionary:
		return {"ok": false, "code": &"unexpected_restore_source_read"}


class PostPromotionFailureStorage extends RefCounted:
	var inner: RefCounted = STORAGE.new()
	var fail_after_next_write: bool = false
	var write_count: int:
		get:
			return inner.write_count

	func write_atomic(relative_path: String, text: String, validator: Callable,
			keep_backup: bool = true) -> Dictionary:
		var written: Dictionary = inner.write_atomic(relative_path, text, validator, keep_backup)
		if written.get("ok", false) and fail_after_next_write:
			fail_after_next_write = false
			return {"ok": false, "code": &"fixture_post_promotion_failure",
				"message": "destination was promoted before the adapter reported failure"}
		return written

	func reconcile(relative_path: String, validator: Callable) -> Dictionary:
		return inner.reconcile(relative_path, validator)

	func describe_root() -> String:
		return inner.describe_root()


class ProvingIssuer extends RefCounted:
	var expected: Dictionary

	func _init(receipt: Dictionary) -> void:
		expected = receipt.duplicate(true)

	func verify_issued(receipt: Dictionary, purpose: StringName) -> Dictionary:
		if purpose != &"transaction_id" or receipt != expected:
			return {"ok": false, "code": &"fixture_receipt_mismatch"}
		return {"ok": true, "value": {"receipt": expected.duplicate(true)}}


func before_each() -> void:
	_storage = STORAGE.new()
	_journal = JOURNAL.new()
	assert_true(_journal.configure(_storage, UnusedSourceLoader.new()).get("ok", false))
	var built: Dictionary = FIXTURE.make_valid_fixture()
	assert_true(built.get("ok", false), str(built))
	_fixture = built.get("value", {})


func test_complete_intent_is_the_durable_decision_and_survives_restart_byte_exact() -> void:
	if _fixture.is_empty():
		return
	var request: Dictionary = FIXTURE.make_intent_request(_fixture)
	var prepared: Dictionary = _journal.prepare_intent(request)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(_storage.write_count, 0, "preparation is mutation-free")
	assert_eq(prepared["value"]["new_run_materials"], _fixture["materials"])
	assert_eq(prepared["value"]["new_run_targets"],
		{"identity": null, "autosave": null, "profile": null})
	assert_true(_journal.commit_intent(prepared["value"]).get("ok", false))
	assert_eq(_storage.write_count, 1, "one durable write establishes the complete New Run decision")

	_storage.restart()
	var restarted: RefCounted = JOURNAL.new()
	assert_true(restarted.configure(_storage, UnusedSourceLoader.new()).get("ok", false))
	var recovered: Dictionary = restarted.get_operation(_fixture["transaction_id"])
	assert_true(recovered.get("ok", false), str(recovered))
	assert_eq(recovered["value"], prepared["value"],
		"restart recovers the exact frozen allocation, Autosave bytes, and Profile bytes")
	assert_eq(recovered["value"]["stage"], STAGE_INTENT)


func test_target_readback_proofs_are_strictly_ordered_exact_and_gate_participant_apply() -> void:
	if not _commit_and_allocate():
		return
	var early_apply: Dictionary = _journal.advance(_advance(STAGE_ALLOCATED, STAGE_APPLYING))
	assert_false(early_apply.get("ok", true))
	assert_eq(early_apply.get("code"), &"new_run_targets_unproven")
	var writes_before: int = _storage.write_count
	assert_false(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"autosave",
		_fixture["materials"]["autosave"]["outgoing_hash"]).get("ok", true),
		"Autosave proof cannot overtake identity proof")
	assert_false(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", "f".repeat(64)).get("ok", true),
		"a readback hash must equal the frozen target hash")
	assert_eq(_storage.write_count, writes_before, "rejected proofs write nothing")

	var identity: Dictionary = _journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", _fixture["allocation_fingerprint"])
	assert_true(identity.get("ok", false), str(identity))
	var after_identity_writes: int = _storage.write_count
	assert_true(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", _fixture["allocation_fingerprint"]).get("ok", false))
	assert_eq(_storage.write_count, after_identity_writes, "an identical proof replay is write-free")
	assert_true(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"autosave",
		_fixture["materials"]["autosave"]["outgoing_hash"]).get("ok", false))
	assert_true(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"profile",
		_fixture["materials"]["profile"]["outgoing_hash"]).get("ok", false))
	var applying: Dictionary = _journal.advance(_advance(STAGE_ALLOCATED, STAGE_APPLYING))
	assert_true(applying.get("ok", false), str(applying))
	assert_eq(applying["value"]["stage"], STAGE_APPLYING)
	assert_eq(applying["value"]["new_run_targets"], {
		"identity": _fixture["allocation_fingerprint"],
		"autosave": _fixture["materials"]["autosave"]["outgoing_hash"],
		"profile": _fixture["materials"]["profile"]["outgoing_hash"],
	})
	assert_false(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"profile",
		_fixture["materials"]["profile"]["outgoing_hash"]).get("ok", true),
		"proof recording closes before live participant application")


func test_failed_target_persistence_returns_no_proof_and_exact_retry_advances_same_operation() -> void:
	if not _commit_and_allocate():
		return
	_storage.fail_next_write(&"fixture_target_write_failed")
	var failed: Dictionary = _journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", _fixture["allocation_fingerprint"])
	assert_false(failed.get("ok", true))
	var retained: Dictionary = _journal.get_operation(_fixture["transaction_id"])
	assert_true(retained.get("ok", false), str(retained))
	assert_eq(retained["value"]["new_run_targets"],
		{"identity": null, "autosave": null, "profile": null},
		"a failed proof write does not advance memory ahead of durable state")
	var retried: Dictionary = _journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", _fixture["allocation_fingerprint"])
	assert_true(retried.get("ok", false), str(retried))
	assert_eq(retried["value"]["new_run_targets"]["identity"], _fixture["allocation_fingerprint"])


func test_post_promotion_failure_invalidates_cache_and_retry_observes_durable_target() -> void:
	var ambiguous: RefCounted = PostPromotionFailureStorage.new()
	_storage = ambiguous
	_journal = JOURNAL.new()
	assert_true(_journal.configure(_storage, UnusedSourceLoader.new()).get("ok", false))
	if not _commit_and_allocate():
		return
	ambiguous.fail_after_next_write = true
	var reported: Dictionary = _journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", _fixture["allocation_fingerprint"])
	assert_false(reported.get("ok", true), "the caller sees the adapter's ambiguous failure")
	var reconciled: Dictionary = _journal.get_operation(_fixture["transaction_id"])
	assert_true(reconciled.get("ok", false), str(reconciled))
	assert_eq(reconciled["value"]["stage"], STAGE_ALLOCATED)
	assert_eq(reconciled["value"]["new_run_materials"], _fixture["materials"],
		"reconciliation retains the complete prior operation")
	assert_eq(reconciled["value"]["new_run_targets"]["identity"], _fixture["allocation_fingerprint"],
		"same-process read observes the target that was physically promoted")
	var writes_before_retry: int = ambiguous.write_count
	assert_true(_journal.record_new_run_target(_fixture["transaction_id"],
		_fixture["request_fingerprint"], &"identity", _fixture["allocation_fingerprint"]).get("ok", false))
	assert_eq(ambiguous.write_count, writes_before_retry, "exact retry is idempotent after reconciliation")


func test_new_run_intent_cannot_abort_and_startup_reconciliation_retains_the_decision() -> void:
	if not _commit_intent():
		return
	var abort: Dictionary = _advance(STAGE_INTENT, STAGE_ABORTED)
	abort["failure"] = {"code": "cancelled", "message": "fixture cancellation", "details": {}}
	assert_false(_journal.advance(abort).get("ok", true),
		"a committed full New Run intent is already the forward-only durability decision")
	var writes_before: int = _storage.write_count
	var issuer: RefCounted = ProvingIssuer.new(_fixture["transaction_issuer_receipt"])
	var reconciled: Dictionary = _journal.reconcile_startup(_fixture["transaction_id"], issuer)
	assert_true(reconciled.get("ok", false), str(reconciled))
	assert_eq(_storage.write_count, writes_before)
	var retained: Dictionary = _journal.get_operation(_fixture["transaction_id"])
	assert_eq(retained["value"]["stage"], STAGE_INTENT)
	assert_eq(retained["value"]["new_run_materials"], _fixture["materials"])


func test_schema_v2_journal_is_refused_without_conversion() -> void:
	_storage.seed(JOURNAL_PATH, JSON.stringify({"schema_version": 2, "operations": {}}))
	var restarted: RefCounted = JOURNAL.new()
	assert_true(restarted.configure(_storage, UnusedSourceLoader.new()).get("ok", false))
	var loaded: Dictionary = restarted.list_incomplete()
	assert_false(loaded.get("ok", true))
	assert_eq(loaded.get("code"), &"journal_schema_invalid")


func _commit_intent() -> bool:
	var prepared: Dictionary = _journal.prepare_intent(FIXTURE.make_intent_request(_fixture))
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return false
	var committed: Dictionary = _journal.commit_intent(prepared["value"])
	assert_true(committed.get("ok", false), str(committed))
	return committed.get("ok", false)


func _commit_and_allocate() -> bool:
	if not _commit_intent():
		return false
	var allocated: Dictionary = _journal.advance(_advance(
		STAGE_INTENT, STAGE_ALLOCATED, _fixture["allocation_candidate"]))
	assert_true(allocated.get("ok", false), str(allocated))
	return allocated.get("ok", false)


func _advance(expected_stage: String, next_stage: String,
		allocation_receipt: Variant = null) -> Dictionary:
	return {
		"allocation_receipt": allocation_receipt,
		"expected_next_participant_index": 0,
		"expected_stage": expected_stage,
		"failure": null,
		"next_stage": next_stage,
		"participant_name": null,
		"participant_receipt": null,
		"request_fingerprint": _fixture["request_fingerprint"],
		"transaction_id": _fixture["transaction_id"],
	}