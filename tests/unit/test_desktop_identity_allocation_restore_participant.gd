extends "res://addons/gut/test.gd"

## DesktopIdentityAllocationRestoreParticipant (Plan 02 Task 6, dwm-p2r.32, Phase C), amendment plan
## lines 287-293. Exercised against the REAL DesktopIdentityNonceIssuer/DesktopIssuerRootStore stack
## (over JsonFileStorage/FakeFileOps), matching this codebase's own established substrate choice for
## identity-issuer-dependent suites (test_desktop_issuer_root_store.gd) -- a hand-rolled issuer double
## would verify the double's idea of allocation instead of the real one's.

const PARTICIPANT_PATH := "res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"
const CANONICAL_JSON_PATH := "res://scripts/validation/CanonicalJsonWriter.gd"

const ROOT := "sandbox/identity-allocation-participant"
const NAMESPACE_A := "1111111111111111111111111111111111111111111111111111111111111111"


class FakeSourceLoader extends RefCounted:
	var context: Dictionary = {}
	var context_sha256: String = ""
	var calls := 0

	func load_context(_locator: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": true, "code": &"ok", "value": {"context": context.duplicate(true), "context_sha256": context_sha256}}


func _exists() -> bool:
	return ResourceLoader.exists(PARTICIPANT_PATH, "Script")

func _sha256(value: Variant) -> String:
	var canonical: Dictionary = load(CANONICAL_JSON_PATH).call("stringify", value)
	assert_true(canonical.get("ok", false))
	return str(canonical["value"]).sha256_text()

func _fresh_issuer() -> RefCounted:
	var file_ops: FakeFileOps = FakeFileOps.new()
	var storage := JsonFileStorage.new(ROOT, file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new(NAMESPACE_A)
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer

func _empty_board() -> Dictionary:
	return {"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null, "candidate": null,
		"board": null, "settlement": null, "command_receipts": {}, "terminal_receipts": {}}

func _snapshot_with_no_pending(causal_day_instance: String, causal_day_receipt: Dictionary) -> Dictionary:
	return {"lifecycle": {}, "desktop": {"board": _empty_board(), "consequence": {
		"schema_version": 1, "run_revision": 0, "causal_sequence": 0,
		"causal_day_instance": causal_day_instance, "causal_day_instance_issuer_receipt": causal_day_receipt,
		"pending": null, "outbox": {},
	}}}

## Builds a well-formed prepare() input against a REAL issuer that has already minted the restore
## transaction receipt (mirroring how the brief documents this participant's caller: the transaction
## is minted BEFORE this participant is ever consulted), plus the exact allocation_candidate_
## fingerprint the participant is independently expected to reproduce.
func _happy_path_rig() -> Dictionary:
	var issuer := _fresh_issuer()
	var transaction_issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(transaction_issued.get("ok", false), JSON.stringify(transaction_issued))
	var restore_transaction_id: String = str(transaction_issued["value"]["token"])
	var transaction_issuer_receipt: Dictionary = transaction_issued["value"]["issuer_receipt"]

	var loader := FakeSourceLoader.new()
	loader.context = _snapshot_with_no_pending("causal-day-source", {
		"receipt_id": "issuer_receipt.fixture-causal-day-source", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-source", "numeric_value": null,
	})
	loader.context_sha256 = _sha256(loader.context)

	var request := {
		"existing_run_id": "run-restore-1", "kind": "restore", "remap_source_transaction_ids": [],
		"source_desktop_timeline_generation": 0, "transaction_id": restore_transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
	}
	var prepared_allocation: Dictionary = issuer.prepare_continuation_allocation(request)
	assert_true(prepared_allocation.get("ok", false), JSON.stringify(prepared_allocation))
	var raw_candidate: Dictionary = prepared_allocation["value"]
	var fingerprint := _sha256(raw_candidate)

	var input := {
		"restore_transaction_id": restore_transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt,
		"source_locator": {"bundle_id": "0".repeat(64), "checkpoint_id": "checkpoint-1",
			"document_sha256": loader.context_sha256, "slot_id": "quick"},
		"existing_run_id": "run-restore-1", "source_desktop_timeline_generation": 0,
		"remap_source_transaction_ids": [], "allocation_candidate_fingerprint": fingerprint,
	}
	return {"issuer": issuer, "loader": loader, "input": input, "raw_candidate": raw_candidate}

func _participant(issuer: Object, loader: Object) -> RefCounted:
	return load(PARTICIPANT_PATH).new(issuer, loader)

func test_participant_exists() -> void:
	assert_true(_exists(), "DesktopIdentityAllocationRestoreParticipant.gd must exist")

func test_prepare_rejects_an_incomplete_input_shape() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var participant := _participant(rig["issuer"], rig["loader"])
	var incomplete: Dictionary = (rig["input"] as Dictionary).duplicate(true)
	incomplete.erase("existing_run_id")
	var result: Dictionary = participant.prepare(incomplete)
	assert_false(result.get("ok", true), "a missing input key must reject")

func test_prepare_succeeds_and_reproduces_the_frozen_fingerprint() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var participant := _participant(rig["issuer"], rig["loader"])
	var result: Dictionary = participant.prepare(rig["input"])
	assert_true(result.get("ok", false), JSON.stringify(result))
	var candidate: Dictionary = (result["value"] as Dictionary)["candidate"]
	assert_eq(candidate["restore_transaction_id"], (rig["input"] as Dictionary)["restore_transaction_id"])
	var bundle: Dictionary = candidate["identity_allocation_bundle"]
	assert_eq(bundle["run_id"], "run-restore-1", "restore carries the existing run_id forward")
	assert_true(str(bundle["remap_receipt_id"]).begins_with("continuation_operation."))
	assert_eq(rig["loader"].calls, 1, "the source is reloaded exactly once")

func test_prepare_rejects_a_source_hash_mismatch() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	(rig["loader"] as FakeSourceLoader).context_sha256 = "0".repeat(64)
	var participant := _participant(rig["issuer"], rig["loader"])
	var result: Dictionary = participant.prepare(rig["input"])
	assert_false(result.get("ok", true), "a source whose hash no longer matches its locator must reject")
	assert_eq(result["code"], &"source_hash_mismatch")

func test_prepare_rejects_a_remap_source_transaction_ids_mismatch() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var input: Dictionary = (rig["input"] as Dictionary).duplicate(true)
	input["remap_source_transaction_ids"] = ["phantom-tx"]
	var participant := _participant(rig["issuer"], rig["loader"])
	var result: Dictionary = participant.prepare(input)
	assert_false(result.get("ok", true), "a remap set that does not match the reloaded document must reject")
	assert_eq(result["code"], &"remap_source_transaction_ids_mismatch")

func test_prepare_rejects_a_stale_allocation_candidate_fingerprint() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var input: Dictionary = (rig["input"] as Dictionary).duplicate(true)
	input["allocation_candidate_fingerprint"] = "0".repeat(64)
	var participant := _participant(rig["issuer"], rig["loader"])
	var result: Dictionary = participant.prepare(input)
	assert_false(result.get("ok", true), "a caller-authored fingerprint that does not reproduce must reject")
	assert_eq(result["code"], &"allocation_candidate_fingerprint_mismatch")

func test_apply_silent_durably_commits_and_replays_idempotently() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var participant := _participant(rig["issuer"], rig["loader"])
	var prepared: Dictionary = participant.prepare(rig["input"])
	assert_true(prepared.get("ok", false))
	var candidate: Dictionary = (prepared["value"] as Dictionary)["candidate"]

	var applied: Dictionary = participant.apply_silent(candidate)
	assert_true(applied.get("ok", false), JSON.stringify(applied))
	assert_true((applied["value"] as Dictionary).has("allocation_receipt"))

	var replayed: Dictionary = participant.apply_silent(candidate)
	assert_true(replayed.get("ok", false), "an identical replay of the same candidate must succeed idempotently")
	assert_eq(replayed["value"]["allocation_receipt"], applied["value"]["allocation_receipt"])

func test_apply_silent_rejects_a_malformed_plan() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var participant := _participant(rig["issuer"], rig["loader"])
	assert_false(participant.apply_silent({}).get("ok", true), "apply_silent requires plan.raw_root_candidate")

func test_rollback_silent_never_reports_reversal() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var participant := _participant(rig["issuer"], rig["loader"])
	var rolled: Dictionary = participant.rollback_silent({})
	assert_true(rolled.get("ok", false))
	assert_true(bool((rolled["value"] as Dictionary)["retained_allocation"]),
		"a failed restore may burn identities but this participant never claims to undo it")

func test_capture_and_finalize_are_trivially_successful() -> void:
	if not _exists(): return
	var rig := _happy_path_rig()
	var participant := _participant(rig["issuer"], rig["loader"])
	assert_true(participant.capture().get("ok", false))
	assert_true(participant.finalize().get("ok", false))
