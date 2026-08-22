extends "res://addons/gut/test.gd"

## DesktopContinuationRemapper (Plan 02 Task 6, dwm-p2r.32, req.desktop.cross_app_actions),
## amendment plan lines 287-291, controller ruling GAP 1 (bead addendum 9): table-driven over the
## members v4 actually has today; the "current-causal-day base-completion and Supportz records"
## clause is Task 7's (amendment SS8.3) and is not implemented here.

const REMAPPER_PATH := "res://scripts/domain/desktop/DesktopContinuationRemapper.gd"
const IDENTITY_PATH := "res://scripts/domain/desktop/DesktopIdentity.gd"
const CANONICAL_JSON_PATH := "res://scripts/validation/CanonicalJsonWriter.gd"

func _exists() -> bool:
	return ResourceLoader.exists(REMAPPER_PATH, "Script")

func _remapper() -> Script:
	return load(REMAPPER_PATH)

func _identity() -> Script:
	return load(IDENTITY_PATH)

func _sha256(value: Variant) -> String:
	var canonical: Dictionary = load(CANONICAL_JSON_PATH).call("stringify", value)
	assert_true(canonical.get("ok", false), "fixture value must be canonicalizable")
	return str(canonical["value"]).sha256_text()

func _board_identity(branch_id: String, generation: int, causal_day_instance: String) -> Dictionary:
	return {"run_id": "run-remap", "branch_id": branch_id,
		"desktop_timeline_generation": generation, "causal_day_instance": causal_day_instance,
		"app_round_ordinal": 1}

func _issuer_receipt(purpose: String, token: String, namespace_value: String = "fixturenamespace", counter: int = 1) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-%s-%s" % [purpose, token], "purpose": purpose,
		"namespace": namespace_value, "counter": counter, "token": token, "numeric_value": null}

func _transaction_receipt(token: String, namespace_value: String = "fixturenamespace", counter: int = 1) -> Dictionary:
	return _issuer_receipt("transaction_id", token, namespace_value, counter)

func _child_provenance(parent_receipt: Dictionary, child_kind: String, ordinal: int, source_ids: Array) -> Dictionary:
	var canonical: Dictionary = load(CANONICAL_JSON_PATH).call("stringify", source_ids)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
		str(parent_receipt.get("namespace", "")), int(parent_receipt.get("counter", 0)),
		str(parent_receipt.get("receipt_id", "")), child_kind, ordinal, str(canonical["value"]),
	]).to_utf8_buffer())
	var child_id := "%s.%s" % [child_kind, context.finish().hex_encode()]
	return {"child_id": child_id, "child_kind": child_kind, "ordinal": ordinal,
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")), "schema_version": 1,
		"source_ids": source_ids}

## A minimal but shape-real v4 snapshot: one board command receipt, one board terminal receipt, and
## one consequence pending action_prepared transaction with a recovery payload -- enough surface to
## exercise every _REMAP_TABLE row this remapper actually handles.
func _snapshot(old_tx: String, old_source_commit: Dictionary) -> Dictionary:
	var old_identity := _board_identity("branch-old", 0, "causal-day-old")
	var command_receipt := old_identity.duplicate(true)
	var fp: Dictionary = _identity().call("fingerprint", old_identity)
	var old_transaction_receipt := _transaction_receipt(old_tx)
	var board := {
		"schema_version": 1, "phase": "SETTLING", "revision": 3, "identity": old_identity,
		"candidate": null,
		"board": {"board": {"terminal": true}, "paid_start_receipt": {"opaque": true}},
		"settlement": {"opaque_settlement": true},
		"command_receipts": {
			old_tx: {"request_fingerprint": "fp-1", "identity_fingerprint": str((fp["value"] as Dictionary)["fingerprint"]),
				"pre_revision": 2, "post_revision": 3, "command_kind": "board_command",
				"result": {"ok": true}},
		},
		"terminal_receipts": {
			old_tx: {"kind": "terminal", "identity_fingerprint": str((fp["value"] as Dictionary)["fingerprint"])},
		},
	}
	var action_receipt := {
		"transaction_id": old_tx, "transaction_issuer_receipt": old_transaction_receipt,
		"source_commit_receipt_id": str(old_source_commit["child_id"]),
		"source_commit_receipt_provenance": old_source_commit,
	}
	var recovery_payload := {
		"source_kind": "minesweeper_round", "action_receipt": action_receipt,
		"run_revision_before": 2, "participant_snapshot_ids": {},
	}
	var pending := {
		"source_kind": "minesweeper_round", "stage": "action_prepared",
		"transaction_id": old_tx, "transaction_issuer_receipt": old_transaction_receipt,
		"source_commit_receipt_id": str(old_source_commit["child_id"]),
		"source_commit_receipt_provenance": old_source_commit,
		"recovery_payload": recovery_payload, "recovery_payload_sha256": _sha256(recovery_payload),
		"participant_receipts": {}, "publication_progress": null, "destination_intent": null,
		"notification_intent": null, "admission_checkpoint_receipt": null, "checkpoint_receipt": null,
		"expected_run_revision": 2,
	}
	var consequence := {
		"schema_version": 1, "run_revision": 2, "causal_sequence": 1,
		"causal_day_instance": "causal-day-old",
		"causal_day_instance_issuer_receipt": _issuer_receipt("causal_day_instance", "causal-day-old"),
		"pending": pending, "outbox": {},
	}
	return {"lifecycle": {}, "desktop": {"board": board, "consequence": consequence}}

func _bundle(old_tx: String, new_tx: String) -> Dictionary:
	var new_transaction_receipt := _transaction_receipt(new_tx)
	return {
		"transaction_id": new_tx, "transaction_issuer_receipt": new_transaction_receipt,
		"branch_id": "branch-new", "desktop_timeline_generation": 1,
		"causal_day_instance": "causal-day-new",
		"causal_day_instance_issuer_receipt": _issuer_receipt("causal_day_instance", "causal-day-new"),
		"transaction_remap": {
			old_tx: {"source_transaction_id": old_tx, "new_transaction_id": new_tx,
				"new_transaction_issuer_receipt": new_transaction_receipt},
		},
	}

func test_remapper_exists() -> void:
	assert_true(_exists(), "DesktopContinuationRemapper.gd must exist")

func test_remap_table_only_marks_current_v4_members_handled() -> void:
	if not _exists(): return
	var table: Array = (_remapper().get_script_constant_map() as Dictionary)["_REMAP_TABLE"]
	assert_true(table.size() > 0, "the registration table must be nonempty")
	var handled_count := 0
	for row: Dictionary in table:
		assert_true(row.has("path") and row.has("handled"), "every row names its path and handled state")
		if not bool(row["handled"]):
			assert_true(str(row.get("reason", "")).length() > 0, "a deferred row must explain why: " + str(row["path"]))
		else:
			handled_count += 1
	assert_true(handled_count > 0, "at least one row must be actively handled")

func test_collect_rewindable_transaction_ids_covers_board_and_pending() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-1"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-1", source_commit)
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	assert_eq((collected["value"] as Dictionary)["transaction_ids"], ["old-tx-1"])

func test_prepare_remaps_board_identity_receipts_and_consequence_pending() -> void:
	if not _exists(): return
	var old_transaction_receipt := _transaction_receipt("old-tx-1")
	var source_commit := _child_provenance(old_transaction_receipt, "board_start", 0, [])
	var snapshot := _snapshot("old-tx-1", source_commit)
	var bundle := _bundle("old-tx-1", "new-tx-1")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-1", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_snapshot: Dictionary = (result["value"] as Dictionary)["snapshot"]
	var board: Dictionary = remapped_snapshot["desktop"]["board"]
	var consequence: Dictionary = remapped_snapshot["desktop"]["consequence"]

	assert_eq((board["identity"] as Dictionary)["branch_id"], "branch-new")
	assert_eq((board["identity"] as Dictionary)["desktop_timeline_generation"], 1)
	assert_eq((board["identity"] as Dictionary)["causal_day_instance"], "causal-day-new")
	assert_true((board["command_receipts"] as Dictionary).has("new-tx-1"), "command receipt re-keyed to the new transaction id")
	assert_false((board["command_receipts"] as Dictionary).has("old-tx-1"), "the old key is gone")
	assert_true((board["terminal_receipts"] as Dictionary).has("new-tx-1"))
	var expected_fp: Dictionary = _identity().call("fingerprint", board["identity"])
	assert_eq((board["command_receipts"]["new-tx-1"] as Dictionary)["identity_fingerprint"],
		str((expected_fp["value"] as Dictionary)["fingerprint"]),
		"identity_fingerprint is recomputed against the NEW identity, not carried over stale")
	# Untouched, opaque board members pass through byte-for-byte.
	assert_eq(board["board"], snapshot["desktop"]["board"]["board"])
	assert_eq(board["settlement"], snapshot["desktop"]["board"]["settlement"])

	assert_eq(consequence["causal_day_instance"], "causal-day-new")
	assert_eq((consequence["causal_day_instance_issuer_receipt"] as Dictionary)["token"], "causal-day-new")
	var pending: Dictionary = consequence["pending"]
	assert_eq(pending["transaction_id"], "new-tx-1")
	assert_eq((pending["transaction_issuer_receipt"] as Dictionary)["token"], "new-tx-1")
	var new_provenance: Dictionary = pending["source_commit_receipt_provenance"]
	assert_eq(new_provenance["child_kind"], "board_start", "child_kind is preserved unchanged")
	assert_eq(new_provenance["ordinal"], 0, "ordinal is preserved unchanged")
	assert_eq(new_provenance["parent_receipt_id"], str((_bundle("old-tx-1", "new-tx-1")["transaction_remap"]["old-tx-1"] as Dictionary)["new_transaction_issuer_receipt"]["receipt_id"]))
	assert_ne(pending["source_commit_receipt_id"], source_commit["child_id"],
		"the anchored child id changes because its parent receipt changed")
	assert_eq(pending["source_commit_receipt_id"], new_provenance["child_id"])

	var payload: Dictionary = pending["recovery_payload"]
	var payload_action: Dictionary = payload["action_receipt"]
	assert_eq(payload_action["transaction_id"], "new-tx-1", "the embedded recovery-payload receipt is remapped too")
	assert_eq(pending["recovery_payload_sha256"], _sha256(payload), "the hash is recomputed after remap, never stale")

	# Deliberately deferred fields pass through unchanged (see _REMAP_TABLE).
	assert_eq(pending["admission_checkpoint_receipt"], null)
	assert_eq(pending["checkpoint_receipt"], null)

	var receipt_shape: Dictionary = (result["value"] as Dictionary)
	assert_true(str(receipt_shape["remap_receipt_id"]).begins_with("continuation_operation."))
	assert_eq((receipt_shape["remap_receipt_provenance"] as Dictionary)["child_kind"], "continuation_operation")
	assert_eq((receipt_shape["remap_receipt_provenance"] as Dictionary)["source_ids"], ["old-tx-1"])

func test_prepare_rejects_a_transaction_remap_missing_a_rewindable_id() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-2"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-2", source_commit)
	var bundle := _bundle("old-tx-2", "new-tx-2")
	(bundle["transaction_remap"] as Dictionary).clear()
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-2", bundle)
	assert_false(result.get("ok", true), "an empty transaction_remap must reject a snapshot with a rewindable transaction")
	assert_eq(result["code"], &"remap_source_set_mismatch")

func test_prepare_rejects_an_extra_transaction_remap_entry() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-3"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-3", source_commit)
	var bundle := _bundle("old-tx-3", "new-tx-3")
	(bundle["transaction_remap"] as Dictionary)["never-referenced"] = {
		"source_transaction_id": "never-referenced", "new_transaction_id": "phantom",
		"new_transaction_issuer_receipt": _transaction_receipt("phantom"),
	}
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-3", bundle)
	assert_false(result.get("ok", true), "an extra remap entry not present in the snapshot must reject")
	assert_eq(result["code"], &"remap_source_set_mismatch")

func test_prepare_rejects_two_sources_mapped_to_the_same_target() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-4"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-4", source_commit)
	# Add a second rewindable transaction via a second board command receipt so two sources exist.
	var board: Dictionary = snapshot["desktop"]["board"]
	(board["command_receipts"] as Dictionary)["old-tx-4b"] = (board["command_receipts"]["old-tx-4"] as Dictionary).duplicate(true)
	var bundle := _bundle("old-tx-4", "new-tx-4")
	(bundle["transaction_remap"] as Dictionary)["old-tx-4b"] = {
		"source_transaction_id": "old-tx-4b", "new_transaction_id": "new-tx-4",
		"new_transaction_issuer_receipt": _transaction_receipt("new-tx-4"),
	}
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-4", bundle)
	assert_false(result.get("ok", true), "two different sources mapped to the same target must reject")
	assert_eq(result["code"], &"remap_target_multiply_mapped")

func test_prepare_is_a_pure_function_of_its_inputs() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-5"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-5", source_commit)
	var frozen_snapshot: Dictionary = snapshot.duplicate(true)
	var bundle := _bundle("old-tx-5", "new-tx-5")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-5", bundle)
	assert_true(result.get("ok", false))
	assert_eq(snapshot, frozen_snapshot, "prepare() never mutates its snapshot argument")

## IMPORTANT 4: source_ids can carry REAL transaction IDs -- GameStateDesktopBoardPort anchors its
## board_start children with source_ids=[transaction_id] (scripts/application/minesweeper/
## GameStateDesktopBoardPort.gd:233), not an opaque hash. The prior _rederive_anchored_child()
## passed source_ids through unchanged, silently staling that id past a restore. The other existing
## tests in this file all use source_ids=[] (empty), which never exercised this branch at all.
func test_prepare_remaps_source_ids_that_are_real_transaction_ids() -> void:
	if not _exists(): return
	var old_transaction_receipt := _transaction_receipt("old-tx-anchor")
	var source_commit := _child_provenance(old_transaction_receipt, "board_start", 0, ["old-tx-anchor"])
	var snapshot := _snapshot("old-tx-anchor", source_commit)
	var bundle := _bundle("old-tx-anchor", "new-tx-anchor")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-anchor", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var pending: Dictionary = (result["value"] as Dictionary)["snapshot"]["desktop"]["consequence"]["pending"]
	var new_provenance: Dictionary = pending["source_commit_receipt_provenance"]
	assert_eq(new_provenance["source_ids"], ["new-tx-anchor"],
		"a source_id that is itself a rewindable transaction id must be remapped, not passed through")

	# Cross-check against the issuer's own formula: re-deriving the child id with the mapped parent
	# receipt AND the mapped source_ids must reproduce the remapped child_id exactly.
	var new_transaction_receipt: Dictionary = (bundle["transaction_remap"]["old-tx-anchor"] as Dictionary)["new_transaction_issuer_receipt"]
	var expected_provenance := _child_provenance(new_transaction_receipt, "board_start", 0, ["new-tx-anchor"])
	assert_eq(pending["source_commit_receipt_id"], expected_provenance["child_id"])
	assert_eq(new_provenance["child_id"], expected_provenance["child_id"])


func test_prepare_leaves_genuinely_opaque_source_ids_unchanged() -> void:
	if not _exists(): return
	var old_transaction_receipt := _transaction_receipt("old-tx-opaque")
	var opaque_hash := "board_command.deadbeefdeadbeefdeadbeefdeadbeef"
	var source_commit := _child_provenance(old_transaction_receipt, "board_start", 0, [opaque_hash])
	var snapshot := _snapshot("old-tx-opaque", source_commit)
	var bundle := _bundle("old-tx-opaque", "new-tx-opaque")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-opaque", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var pending: Dictionary = (result["value"] as Dictionary)["snapshot"]["desktop"]["consequence"]["pending"]
	assert_eq(pending["source_commit_receipt_provenance"]["source_ids"], [opaque_hash],
		"a source_id with no transaction_remap entry is genuinely opaque and must pass through unchanged")


func test_prepare_rejects_an_unsorted_historical_source_ids_record() -> void:
	if not _exists(): return
	var old_transaction_receipt := _transaction_receipt("old-tx-unsorted")
	# A malformed historical provenance: source_ids deliberately out of lexical order.
	var source_commit := _child_provenance(old_transaction_receipt, "board_start", 0, ["z-id", "a-id"])
	var snapshot := _snapshot("old-tx-unsorted", source_commit)
	var bundle := _bundle("old-tx-unsorted", "new-tx-unsorted")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-unsorted", bundle)
	assert_false(result.get("ok", true), "an unsorted historical source_ids record must reject, not be silently renormalized")
	assert_eq(result["code"], &"remap_source_ids_invalid")


func test_prepare_rejects_a_duplicate_historical_source_ids_record() -> void:
	if not _exists(): return
	var old_transaction_receipt := _transaction_receipt("old-tx-dup")
	var source_commit := _child_provenance(old_transaction_receipt, "board_start", 0, ["dup-id", "dup-id"])
	var snapshot := _snapshot("old-tx-dup", source_commit)
	var bundle := _bundle("old-tx-dup", "new-tx-dup")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-dup", bundle)
	assert_false(result.get("ok", true), "a duplicated historical source_ids record must reject")
	assert_eq(result["code"], &"remap_source_ids_invalid")


func test_validate_remap_accepts_its_own_prepare_output_and_rejects_a_tampered_candidate() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-6"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-6", source_commit)
	var bundle := _bundle("old-tx-6", "new-tx-6")
	var prepared: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-6", bundle)
	assert_true(prepared.get("ok", false))
	var candidate: Dictionary = (prepared["value"] as Dictionary)["snapshot"]

	var validated: Dictionary = _remapper().call("validate_remap", snapshot, candidate)
	assert_true(validated.get("ok", false), JSON.stringify(validated))

	var tampered: Dictionary = candidate.duplicate(true)
	var tampered_board: Dictionary = (tampered["desktop"] as Dictionary)["board"].duplicate(true)
	var tampered_identity: Dictionary = (tampered_board["identity"] as Dictionary).duplicate(true)
	tampered_identity["branch_id"] = "branch-tampered"
	tampered_board["identity"] = tampered_identity
	tampered["desktop"] = (tampered["desktop"] as Dictionary).duplicate(true)
	tampered["desktop"]["board"] = tampered_board
	var rejected: Dictionary = _remapper().call("validate_remap", snapshot, tampered)
	assert_false(rejected.get("ok", true), "a hand-edited identity must fail re-derivation")
