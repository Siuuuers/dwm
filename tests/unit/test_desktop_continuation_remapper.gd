extends "res://addons/gut/test.gd"

## DesktopContinuationRemapper (Plan 02 Task 6, dwm-p2r.32, req.desktop.cross_app_actions),
## amendment plan lines 287-291, controller ruling GAP 1 (bead addendum 9): table-driven over the
## members v4 actually has today; the "current-causal-day base-completion and Supportz records"
## clause is Task 7's (amendment SS8.3) and is not implemented here.

const REMAPPER_PATH := "res://scripts/domain/desktop/DesktopContinuationRemapper.gd"
const IDENTITY_PATH := "res://scripts/domain/desktop/DesktopIdentity.gd"
const CANONICAL_JSON_PATH := "res://scripts/validation/CanonicalJsonWriter.gd"

# Cross-check against the REAL issuer (not the hand-computed preimage in _child_provenance()
# below): the remapper's _child_id() duplicates DesktopIdentityNonceIssuer._child_id()'s formula
# byte-for-byte (that file's own frozen public surface forbids adding a shared static), so nothing
# short of loading the genuine issuer proves the two never drift.
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

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
		"pending": pending, "outbox": {}, "shop_ledger": {"supportz_branch_purchase_count": 0,
			"supportz_last_purchase_causal_day_instance": "", "base_completion_receipts": []},
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


func test_prepare_rekeys_compact_and_full_command_receipts_without_inventing_metadata() -> void:
	if not _exists(): return
	var compact_id := "old-tx-compact"
	var first_id := "old-tx-first"
	var latest_id := "old-tx-latest"
	var unknown_id := "old-tx-unknown"
	var source_commit := _child_provenance(_transaction_receipt(compact_id), "board_start", 0, [])
	var snapshot := _snapshot(compact_id, source_commit)
	var board: Dictionary = snapshot["desktop"]["board"]
	var old_identity_fp := str(board["command_receipts"][compact_id]["identity_fingerprint"])
	var compact_receipt := {
		"request_fingerprint": "compact-fingerprint",
		"result": {"ok": true, "code": &"board_command_already_applied",
			"value": {"already_applied": true, "revision": 1}, "receipt": {}},
	}
	var first_receipt := {
		"request_fingerprint": "first-fingerprint", "identity_fingerprint": old_identity_fp,
		"pre_revision": 0, "post_revision": 1, "command_kind": "first_reveal",
		"result": {"ok": true, "code": &"first_reveal_committed",
			"value": {"receipt": {"checkpoint_id": "checkpoint.fixture-first"}}, "receipt": {}},
	}
	var latest_receipt := {
		"request_fingerprint": "latest-fingerprint", "identity_fingerprint": old_identity_fp,
		"pre_revision": 2, "post_revision": 3, "command_kind": "visibility",
		"result": {"ok": true, "code": &"ok", "value": {"visible": true}, "receipt": {}},
	}
	var unknown_receipt := {
		"request_fingerprint": "unknown-fingerprint", "command_kind": "future_command",
		"result": {"ok": true, "value": {"opaque": ["retained"]}},
		"future_metadata": {"must_survive": true},
	}
	board["command_receipts"] = {}
	board["command_receipts"][compact_id] = compact_receipt.duplicate(true)
	board["command_receipts"][first_id] = first_receipt.duplicate(true)
	board["command_receipts"][latest_id] = latest_receipt.duplicate(true)
	board["command_receipts"][unknown_id] = unknown_receipt.duplicate(true)
	var frozen_snapshot: Dictionary = snapshot.duplicate(true)
	var bundle := _bundle(compact_id, "new-tx-compact")
	var target_ids := {}
	target_ids[first_id] = "new-tx-first"
	target_ids[latest_id] = "new-tx-latest"
	target_ids[unknown_id] = "new-tx-unknown"
	for old_id: String in target_ids:
		var new_id := str(target_ids[old_id])
		bundle["transaction_remap"][old_id] = {
			"source_transaction_id": old_id, "new_transaction_id": new_id,
			"new_transaction_issuer_receipt": _transaction_receipt(new_id),
		}

	var prepared: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-compact", bundle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false): return
	var candidate: Dictionary = prepared["value"]["snapshot"]
	var remapped_board: Dictionary = candidate["desktop"]["board"]
	var receipts: Dictionary = remapped_board["command_receipts"]
	for old_id: String in [compact_id, first_id, latest_id, unknown_id]:
		assert_false(receipts.has(old_id), "the source command key is retired: " + old_id)
	for new_id: String in ["new-tx-compact", "new-tx-first", "new-tx-latest", "new-tx-unknown"]:
		assert_true(receipts.has(new_id), "the declared replacement command key exists: " + new_id)
	assert_eq(receipts["new-tx-compact"], compact_receipt,
		"a compact receipt remains exactly its two-key content")
	assert_eq(receipts["new-tx-unknown"], unknown_receipt,
		"an opaque command with no identity metadata is rekeyed without reinterpretation")
	var new_identity_fp: Dictionary = _identity().call("fingerprint", remapped_board["identity"])
	var expected_first: Dictionary = first_receipt.duplicate(true)
	expected_first["identity_fingerprint"] = str(new_identity_fp["value"]["fingerprint"])
	var expected_latest: Dictionary = latest_receipt.duplicate(true)
	expected_latest["identity_fingerprint"] = str(new_identity_fp["value"]["fingerprint"])
	assert_eq(receipts["new-tx-first"], expected_first,
		"full first-Reveal evidence keeps its result while its present identity is updated")
	assert_eq(receipts["new-tx-latest"], expected_latest,
		"the latest full routine result keeps its result while its present identity is updated")
	assert_eq(snapshot, frozen_snapshot, "preparation does not mutate the source receipt ledger")

	var validated: Dictionary = _remapper().call("validate_remap", snapshot, candidate)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	assert_eq(snapshot, frozen_snapshot, "independent reproduction leaves the source detached")
	var remapped_compact_value: Dictionary = receipts["new-tx-compact"]["result"]["value"]
	remapped_compact_value["revision"] = 999
	assert_eq(snapshot["desktop"]["board"]["command_receipts"][compact_id], compact_receipt,
		"mutating the prepared compact receipt cannot leak into the source")


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


## The remapper's own `_child_id()` fail-closed branch (`remap_child_source_ids_malformed`) --
## nothing else in this repository reaches that code. It is genuinely reachable, not defensive
## padding: `_validate_sorted_unique_nonblank()` checks only array/nonblank/unique/sorted, so a
## code point in the surrogate range sails straight through it; a source_id with no
## `transaction_remap` entry is then handed to `_child_id()` verbatim; and there
## `CanonicalJsonWriter._emit_string()` refuses it (`invalid_surrogate`). Failing closed is the
## whole point -- the alternative is minting a child id off some substituted canonicalization,
## i.e. an id `DesktopIdentityNonceIssuer._child_id()`, whose frozen preimage the remapper
## duplicates, would have refused to mint at all.
##
## CONSTRUCTION NOTE: the surrogate has to arrive via `get_string_from_utf16()`, the one route
## that PRESERVES an unpaired lead surrogate (the engine logs a Unicode WARNING, not an error,
## and GUT's error watcher does not trip on it). Godot closes every other door:
## `String.chr(0xD800)` substitutes U+FFFD, `get_string_from_utf8()` substitutes U+FFFD per byte,
## `JSON.parse_string()` rejects a backslash-u escape naming a surrogate outright, and the
## GDScript tokenizer rejects that same escape in source at PARSE time -- which is why this
## string cannot simply be written as a literal here.
func test_prepare_rejects_a_source_id_that_is_not_canonically_representable() -> void:
	if not _exists(): return
	var utf16 := PackedByteArray()
	utf16.append(0x00)
	utf16.append(0xD8)  # U+D800, an unpaired lead surrogate, little-endian
	var lone_surrogate: String = utf16.get_string_from_utf16()

	# Pin both halves of the reachability argument so this test cannot pass for another reason.
	assert_eq(lone_surrogate.length(), 1, "the fixture must be exactly one code point")
	assert_eq(lone_surrogate.unicode_at(0), 0xD800,
		"the fixture must really carry a lone surrogate, not a U+FFFD substitution")
	var canonical: Dictionary = load(CANONICAL_JSON_PATH).call("stringify", [lone_surrogate])
	assert_false(canonical.get("ok", true), "the canonical writer must refuse the fixture source_id")
	assert_eq(canonical.get("code", &""), &"invalid_surrogate")

	# The snapshot fixture canonicalizes the whole recovery payload, so build it from a
	# representable provenance and swap the malformed record onto the pending only.
	var old_transaction_receipt := _transaction_receipt("old-tx-surrogate")
	var clean_provenance := _child_provenance(old_transaction_receipt, "board_start", 0, ["opaque-id"])
	var snapshot := _snapshot("old-tx-surrogate", clean_provenance)
	var malformed_provenance := {
		"schema_version": 1, "parent_receipt_id": str(old_transaction_receipt["receipt_id"]),
		"child_kind": "board_start", "ordinal": 0, "source_ids": [lone_surrogate],
		"child_id": "board_start.deadbeef",
	}
	var pending: Dictionary = snapshot["desktop"]["consequence"]["pending"]
	pending["source_commit_receipt_provenance"] = malformed_provenance
	pending["source_commit_receipt_id"] = str(malformed_provenance["child_id"])

	var bundle := _bundle("old-tx-surrogate", "new-tx-surrogate")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-surrogate", bundle)
	assert_false(result.get("ok", true),
		"a source_id that cannot be canonicalized must fail closed, not mint a child id anyway")
	assert_eq(result["code"], &"remap_child_source_ids_malformed")


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


# ---------------------------------------------------------------------------------------------
# Cross-check against the REAL DesktopIdentityNonceIssuer (item 4 of the truthfulness
# remediation): the remapper's _child_id() duplicates the issuer's own frozen preimage formula
# rather than importing it (that file's frozen public surface forbids adding a shared static),
# and until now nothing in this suite ever loaded the real issuer to prove the duplicate still
# agrees with the original. A silent drift here would produce restored children that the real
# issuer's own validate_child() rejects, discovered only at a later restore.
# ---------------------------------------------------------------------------------------------

func _real_issuer(namespace_hex: String, next_counter: int) -> Object:
	var root: Object = FAKE_ROOT_STORE.new(namespace_hex, next_counter)
	var issuer: Object = ISSUER.new()
	assert_true(issuer.configure(root).get("ok", false), "issuer configure must succeed")
	return issuer


func test_prepare_rederives_a_source_commit_child_through_the_real_issuer_byte_for_byte() -> void:
	if not _exists(): return
	var issuer := _real_issuer("3333333333333333333333333333333333333333333333333333333333333333", 1)

	var parent: Dictionary = issuer.issue(&"transaction_id")
	assert_true(parent.get("ok", false), JSON.stringify(parent))
	var parent_receipt: Dictionary = parent["receipt"]
	var old_tx := str((parent["value"] as Dictionary)["token"])

	# A real anchored child, derived by the genuine issuer -- not the hand-computed preimage
	# `_child_provenance()` uses elsewhere in this file.
	var derived: Dictionary = issuer.derive_child({
		"parent_receipt_id": parent_receipt["receipt_id"], "child_kind": "board_start",
		"ordinal": 0, "source_ids": [],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	var real_child_id := str((derived["value"] as Dictionary)["child_id"])
	var real_provenance: Dictionary = (derived["value"] as Dictionary)["provenance"]

	var snapshot := _snapshot(old_tx, real_provenance)
	# An identity remap: old_tx maps to itself under the EXACT SAME real parent receipt, so
	# _rederive_anchored_child() is exercised with the identical preimage the real issuer used --
	# proving the remapper's duplicated formula agrees with the original, not just with itself.
	var bundle := {
		"transaction_id": old_tx, "transaction_issuer_receipt": parent_receipt,
		"branch_id": "branch-new", "desktop_timeline_generation": 1,
		"causal_day_instance": "causal-day-new",
		"causal_day_instance_issuer_receipt": _issuer_receipt("causal_day_instance", "causal-day-new"),
		"transaction_remap": {
			old_tx: {"source_transaction_id": old_tx, "new_transaction_id": old_tx,
				"new_transaction_issuer_receipt": parent_receipt},
		},
	}

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-real-issuer", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var pending: Dictionary = (result["value"] as Dictionary)["snapshot"]["desktop"]["consequence"]["pending"]
	var new_provenance: Dictionary = pending["source_commit_receipt_provenance"]

	assert_eq(str(pending["source_commit_receipt_id"]), real_child_id,
		"the remapper's duplicated preimage formula must reproduce the real issuer's own child id byte-for-byte")
	assert_eq(str(new_provenance["child_id"]), real_child_id)

	# The strongest cross-check: feed the remapper's OWN output back into the REAL issuer.
	# validate_child() independently recomputes the child id from the provenance's own members
	# and compares it to the stored child_id -- exactly the rejection a live restore would hit if
	# the two duplicated formulas had drifted.
	var revalidated: Dictionary = issuer.validate_child(new_provenance, &"board_start")
	assert_true(revalidated.get("ok", false),
		"the real issuer must accept the remapper's re-derived provenance as authentic: "
			+ JSON.stringify(revalidated))


func test_prepare_rejects_a_historical_source_commit_with_an_unregistered_child_kind() -> void:
	if not _exists(): return
	var old_transaction_receipt := _transaction_receipt("old-tx-badkind")
	# Shape-valid (exact _PROVENANCE_KEYS member set) but a child_kind that is not a member of the
	# real issuer's frozen CHILD_KINDS union -- the real issuer's own derive_child()/validate_child()
	# would refuse this at the door; the remapper must too, not silently re-derive a child id under
	# a kind the issuer would never have minted.
	var bad_provenance := {
		"schema_version": 1, "parent_receipt_id": str(old_transaction_receipt["receipt_id"]),
		"child_kind": "not_a_registered_kind", "ordinal": 0, "source_ids": [],
		"child_id": "not_a_registered_kind.deadbeef",
	}
	var snapshot := _snapshot("old-tx-badkind", bad_provenance)
	var bundle := _bundle("old-tx-badkind", "new-tx-badkind")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-badkind", bundle)
	assert_false(result.get("ok", true), "an unregistered historical child_kind must reject")
	assert_eq(result["code"], &"remap_child_kind_unregistered")


## The cross-check the remapper's own `_CHILD_KINDS` comment names: that duplicated list is a
## hand-copy of `DesktopIdentityNonceIssuer.CHILD_KINDS` (the domain layer must not depend on the
## application-layer issuer), so nothing but a direct member-for-member comparison against the
## real issuer can prove the copy has not drifted. Drift is silent and expensive: a kind added to
## the issuer but not here makes `_rederive_anchored_child()` reject a child the issuer legitimately
## minted, and a kind left here after the issuer dropped it makes the remapper re-derive an id under
## a kind the issuer would refuse -- either way discovered only at a live restore.
func test_the_remappers_duplicated_child_kinds_equal_the_real_issuers_child_kinds_exactly() -> void:
	if not _exists(): return
	var constants: Dictionary = _remapper().get_script_constant_map()
	assert_true(constants.has("_CHILD_KINDS"), "the remapper must still declare _CHILD_KINDS")
	var duplicated: Array = constants["_CHILD_KINDS"]
	var authoritative: Array = ISSUER.CHILD_KINDS
	assert_eq(duplicated.size(), authoritative.size(),
		"the duplicate must carry exactly as many kinds as the real issuer")
	for index in range(authoritative.size()):
		var mirrored: String = str(duplicated[index]) if index < duplicated.size() else "<missing>"
		assert_eq(mirrored, str(authoritative[index]),
			"kind %d must match the real issuer's CHILD_KINDS in the same position" % index)
	assert_eq(duplicated, authoritative,
		"the domain-layer duplicate must equal DesktopIdentityNonceIssuer.CHILD_KINDS exactly")


# =================================================================================================
# AMENDMENT PLAN 03 TASK 4 (dwm-oyo.3) STEP 1 -- the v5 schedule_view/lifecycle RED net (ledger 4.9)
#
# Forty-six appended rows. `_snapshot()` and `_bundle()` above are DELIBERATELY UNTOUCHED so the
# seventeen shipped tests stay byte-green under the new v5 gate; every v5 fixture below is built by
# a sibling builder that never reaches into them.
#
# RED VALIDITY (plan Global Constraints line 40): the DesktopContinuationRemapper Step-1 skeleton
# already compiles and answers the typed `not_implemented` envelope for any snapshot carrying a v5
# region (`_carries_v5_regions`, ledger 3.12 S1-A/S1-B), so every failure below is a typed
# wrong-behaviour result, never a missing preload, a parse error or a load failure. Ledger section
# 4.0 rule 1 is why every rejection row also asserts `code != &"not_implemented"`: without it the
# skeleton satisfies the entire refusal matrix forever and nothing here is falsifiable.
#
# Ledger section 2.2 DOES freeze this module's refusal literals (unlike ConditionHospitalPlan /
# ConditionHospitalState / RunLifecycle, which rule 2 covers), so rows whose fault maps
# unambiguously onto one of them pin that literal; the rest assert distinctness only.
# =================================================================================================

const WARNING_POLICY_PATH := "res://scripts/domain/schedule/ScheduleWarningPolicy.gd"
const VIEW_STATE_PATH := "res://scripts/domain/schedule/ScheduleViewState.gd"
const REGISTRY_PATH := "res://scripts/domain/schedule/ScheduleActionRegistry.gd"
const CONTROLLER_PATH := "res://scripts/application/schedule/ScheduleViewController.gd"

## The two allocation tokens `_snapshot()` and `_bundle()` above already hard-code. Named here so a
## v5 fixture can never drift away from the v4 fixture it extends.
const OLD_CAUSAL := "causal-day-old"
const NEW_CAUSAL := "causal-day-new"
const RUN_ID := "run-remap"

## The twelve v5 `_REMAP_TABLE` rows, transcribed from the working tree (ledger 4.9 row R9). The
## ledger names the COUNT ("twelve rows") and the file names the PATHS, so this list is the binding
## between them: a renamed or dropped region breaks R9 loudly instead of silently narrowing scope.
const V5_REGION_PATHS: Array = [
	"schedule_view.causal_day_instance",
	"schedule_view.pending_warning.opened_by_transaction_id+receipt",
	"schedule_view.pending_warning.activation_id+provenance",
	"schedule_view.pending_warning.attempt_receipts",
	"schedule_view.consumed_warning_receipts",
	"schedule_view.condition_departure_receipts",
	"lifecycle.active_condition_hospital_plan.transaction_id+receipt",
	"lifecycle.active_condition_hospital_plan.stages.*.stage_key+identity+receipt",
	"lifecycle.active_condition_hospital_plan.destination_record",
	"lifecycle.condition_hospital_history",
	"lifecycle.terminal_intent_handoff",
	"desktop.consequence.pending.recovery_payload.schedule_view_before+after",
]

## Immutable order and ordinals (ledger 1.3.2). Stages are never removed or renumbered.
const HOSPITAL_STAGE_IDS: Array = [
	"close_invitation_sources", "present_hospital", "resolve_deferred_pair",
	"present_deferred_pair", "advance_day", "autosave_new_day",
]


# ---- v5 builders (siblings of _snapshot()/_bundle(), never edits of them) ----

## P(name,value) -- the projection spelling ScheduleViewController._p() owns and the remapper must
## duplicate at Step 4 (ledger 3.12, Tier B). This file computes it a THIRD time so row R26 is a
## genuine three-way cross-check rather than a comparison of one implementation with itself.
func _p(name: String, value: Variant) -> String:
	var emitted: Dictionary = load(CANONICAL_JSON_PATH).call("stringify", value)
	return name + "=" + str(emitted.get("value", ""))


func _v5_entry(draft_entry_id: String, slot_index: int, action_id: String, day: int) -> Dictionary:
	return {
		"action_id": action_id, "action_kind": "ordinary", "day": day,
		"draft_entry_id": draft_entry_id, "participants": [], "slot_index": slot_index,
		"source_receipt_id": null,
	}


## The bare seven-key ScheduleViewState view (ledger 1.2) -- no wrapper, no schema_version, no
## embedded registry fingerprint.
func _v5_view(day: int, causal_day_instance: String, overrides: Dictionary = {}) -> Dictionary:
	var view := {
		"causal_day_instance": causal_day_instance,
		"condition_departure_receipts": {},
		"consumed_warning_receipts": {},
		"date_entry_seen": false,
		"day": day,
		"entries": [_v5_entry("draft-1", 0, "rest", day)],
		"pending_warning": null,
	}
	for key: String in overrides:
		view[key] = overrides[key]
	return view


## The exact twelve-key ScheduleWarningPolicy context (ledger 1.2.3). Internally consistent by
## construction: board_identity mirrors the context's own four shared members and the effective base
## ordinal is the board identity's own, so any fault a row injects is the only fault present.
func _warning_context(branch_id: String, generation: int, causal_day_instance: String,
		run_id: String = RUN_ID) -> Dictionary:
	return {
		"accepted_unscheduled_date_ids": [],
		"base_opportunity_remaining": true,
		"base_round_ordinal": 1,
		"board_identity": {
			"app_round_ordinal": 1, "branch_id": branch_id,
			"causal_day_instance": causal_day_instance,
			"desktop_timeline_generation": generation, "run_id": run_id,
		},
		"board_phase": "SETTLING",
		"branch_id": branch_id,
		"causal_day_instance": causal_day_instance,
		"desktop_timeline_generation": generation,
		"eligible_unread_date_message_ids": [],
		"motivation": 2,
		"run_id": run_id,
		"unfinished_base_board": false,
	}


## The stored preimage, byte-for-byte the shape ScheduleWarningPolicy.warning_state_fingerprint()
## hashes: EXACTLY {view_projection, context} with the four-member projection.
func _warning_preimage(view: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"view_projection": {
			"day": int(view["day"]),
			"causal_day_instance": str(view["causal_day_instance"]),
			"entries": (view["entries"] as Array).duplicate(true),
			"date_entry_seen": bool(view["date_entry_seen"]),
		},
		"context": context.duplicate(true),
	}


func _warning_digest(preimage: Dictionary) -> String:
	return _sha256(preimage)


## The six-key activation child: kind "warning", ordinal 0, source_ids the sorted projection pair.
func _activation_provenance(warning_kind: String, digest: String,
		opened_receipt: Dictionary) -> Dictionary:
	var source_ids: Array = [
		_p("warning_kind", warning_kind), _p("warning_state_fingerprint", digest),
	]
	source_ids.sort()
	return _child_provenance(opened_receipt, "warning", 0, source_ids)


## The exact nine-key pending activation record (ledger 1.2.3).
func _pending_warning(warning_kind: String, view: Dictionary, context: Dictionary,
		opened_transaction_id: String, attempt_receipts: Dictionary = {}) -> Dictionary:
	var preimage := _warning_preimage(view, context)
	var digest := _warning_digest(preimage)
	var opened_receipt := _transaction_receipt(opened_transaction_id)
	var activation := _activation_provenance(warning_kind, digest, opened_receipt)
	return {
		"activation_id": str(activation["child_id"]),
		"activation_id_provenance": activation,
		"attempt_receipts": attempt_receipts,
		"opened_by_transaction_id": opened_transaction_id,
		"opened_by_transaction_issuer_receipt": opened_receipt,
		"state": "pending",
		"warning_fingerprint_preimage": preimage,
		"warning_kind": warning_kind,
		"warning_state_fingerprint": digest,
	}


## The ten-key terminal warning receipt, plus the eleventh `failure_code` iff navigation_failed.
## The two source_ids recipes are the frozen ones: dismissed carries the outcome and the digest,
## a navigation outcome carries the intent and no digest at all.
func _terminal_receipt(pending: Dictionary, terminal_result: String, transaction_id: String,
		intent: String = "") -> Dictionary:
	var transaction_receipt := _transaction_receipt(transaction_id)
	var activation_id := str(pending["activation_id"])
	var warning_kind := str(pending["warning_kind"])
	var digest := str(pending["warning_state_fingerprint"])
	var source_ids: Array = []
	var child_kind := "navigation"
	if terminal_result == "dismissed":
		child_kind = "warning"
		source_ids = [
			_p("activation_id", activation_id), _p("warning_state_fingerprint", digest),
			_p("warning_kind", warning_kind), _p("outcome", "dismissed"),
		]
	else:
		source_ids = [
			_p("activation_id", activation_id), _p("warning_kind", warning_kind),
			_p("intent", intent),
		]
	source_ids.sort()
	var provenance := _child_provenance(transaction_receipt, child_kind, 0, source_ids)
	var receipt := {
		"receipt_id": str(provenance["child_id"]),
		"receipt_provenance": provenance,
		"activation_id": activation_id,
		"activation_id_provenance": (pending["activation_id_provenance"] as Dictionary).duplicate(true),
		"warning_fingerprint_preimage": (pending["warning_fingerprint_preimage"] as Dictionary).duplicate(true),
		"warning_state_fingerprint": digest,
		"warning_kind": warning_kind,
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_receipt,
		"terminal_result": terminal_result,
	}
	if terminal_result == "navigation_failed":
		receipt["failure_code"] = "navigation_refused"
	return receipt


## The consumed index key ScheduleWarningPolicy.next_warning() itself reads.
func _consumed_key(digest: String, warning_kind: String) -> String:
	return digest + "|" + warning_kind


## The exact five-key append-only condition-departure ledger value (ledger 1.2.4).
func _ledger_entry(provenance: Dictionary, before_sha256: String,
		after_sha256: String) -> Dictionary:
	return {
		"disposition": "condition_departure_view_committed",
		"schedule_view_after_sha256": after_sha256,
		"schedule_view_before_sha256": before_sha256,
		"source_condition_receipt_id": str(provenance["child_id"]),
		"source_condition_receipt_provenance": provenance,
	}


## The v4 five-key outbox envelope DesktopConsequenceState owns and Task 4 may not widen (D-8).
func _outbox_entry(outbox_kind: String, payload: Dictionary, status: String) -> Dictionary:
	return {
		"key": outbox_kind, "payload_hash": _sha256(payload),
		"provenance": {"origin": "condition_hospital", "outbox_kind": outbox_kind},
		"consumer": "oyo6", "status": status,
	}


## The v5 SIX-member record that carries its own payload, because the v4 envelope has none and
## Task 4 cannot add one (ledger 1.3.5 / D-8). "Unpublished" is `status`, never a boolean.
func _destination_record(outbox_kind: String, payload: Dictionary, status: String) -> Dictionary:
	var record := _outbox_entry(outbox_kind, payload, status)
	record["payload"] = payload.duplicate(true)
	return record


func _hospital_payload(accepted_sources: Array) -> Dictionary:
	return {"kind": "hospital_day", "accepted_unfulfilled_sources": accepted_sources.duplicate(true)}


## One of the six stage records: exactly six sorted keys, with the pending/active/completed
## nullability partition of ledger 1.3.2. The advance_day stage's `prepared` IS the target day
## allocation -- that is what makes the "one allocation is never both source and target" law
## falsifiable in-document; every other stage's prepared is an opaque Task-7 payload.
func _hospital_stage(index: int, state: String, resolution_receipt_id: String,
		parent_receipt: Dictionary, target_causal_day_instance: String) -> Dictionary:
	var stage_id := str(HOSPITAL_STAGE_IDS[index])
	var stage := {
		"prepared": null, "receipt": null, "stage_id": stage_id, "stage_identity": null,
		"stage_key": resolution_receipt_id + ":" + stage_id, "state": state,
	}
	if state == "pending":
		return stage
	var identity := _child_provenance(parent_receipt, "day_resolution_stage", index,
		[_p("stage_id", stage_id)])
	# The shipped producer's envelope (ConditionHospitalState.prepare_stage_identity) and the
	# shipped validator's law (ConditionHospitalPlan._stage_member_error): RULING T4-AD item 1.
	stage["stage_identity"] = {
		"child_id": str(identity["child_id"]), "input_receipt_ids": [],
		"provenance": identity,
	}
	if index == 4:
		stage["prepared"] = {
			"stage_id": stage_id,
			"target_causal_day_instance": target_causal_day_instance,
			"target_causal_day_instance_issuer_receipt":
				_issuer_receipt("causal_day_instance", target_causal_day_instance),
		}
	else:
		stage["prepared"] = {"stage_id": stage_id, "opaque_task7_payload": true}
	if state == "completed":
		stage["receipt"] = {
			"receipt_id": str(identity["child_id"]), "receipt_provenance": identity,
			"resolution_kind": "condition_hospital",
			"resolution_receipt_id": resolution_receipt_id, "stage_id": stage_id,
			"stage_index": index, "input_receipt_ids": [],
			"output": {"opaque_task7_output": true},
		}
	return stage


## The exact seventeen-key ConditionHospitalPlan value (ledger 1.3.1). `cursor` is the completed
## prefix count; `stage4_state` overrides the prefix rule for the advance_day stage alone, which is
## the one stage whose state decides whether a split top-level identity is legal (ledger 1.3.3).
func _condition_hospital_plan(cursor: int, stage4_state: String,
		overrides: Dictionary = {}) -> Dictionary:
	var transaction_id := str(overrides.get("transaction_id", "old-hospital-tx"))
	var transaction_receipt: Dictionary = overrides.get("transaction_issuer_receipt",
		_transaction_receipt(transaction_id))
	var causal := str(overrides.get("causal_day_instance", OLD_CAUSAL))
	var source_day := int(overrides.get("source_day", 3))
	var accepted_sources: Array = overrides.get("accepted_sources", [
		{"action_id": "solo:priscilla:day3", "receipt_id": "src-priscilla"},
		{"action_id": "solo:sylvia:day3", "receipt_id": "src-sylvia"},
	])
	var resolution_provenance := _child_provenance(transaction_receipt, "hospital_resolution", 0,
		[_p("source_day", source_day)])
	var resolution_receipt_id := str(resolution_provenance["child_id"])
	var condition_provenance := _child_provenance(transaction_receipt, "condition", 0, [])
	var target := str(overrides.get("stage4_target", NEW_CAUSAL))
	var stages: Array = []
	for index: int in range(HOSPITAL_STAGE_IDS.size()):
		var state := "pending"
		if index < cursor:
			state = "completed"
		elif index == cursor:
			state = "active"
		if index == 4 and not stage4_state.is_empty():
			state = stage4_state
		stages.append(_hospital_stage(index, state, resolution_receipt_id, transaction_receipt,
			target))
	var plan := {
		"accepted_sources": accepted_sources.duplicate(true),
		"action_receipt": {
			"transaction_id": str(overrides.get("action_transaction_id", transaction_id)),
			"transaction_issuer_receipt": transaction_receipt.duplicate(true),
		},
		"branch_id": str(overrides.get("branch_id", "branch-old")),
		"causal_day_instance": causal,
		"causal_day_instance_issuer_receipt": _issuer_receipt("causal_day_instance", causal),
		"condition_receipt": {
			"receipt_id": str(condition_provenance["child_id"]),
			"receipt_provenance": condition_provenance, "decision": "hospital_day",
		},
		"cursor": cursor,
		"desktop_timeline_generation": int(overrides.get("desktop_timeline_generation", 0)),
		"destination_record": _destination_record("hospital",
			_hospital_payload(accepted_sources), "pending"),
		"resolution_kind": "condition_hospital",
		"resolution_receipt": {
			"receipt_id": resolution_receipt_id, "receipt_provenance": resolution_provenance,
			"resolution_kind": "condition_hospital",
		},
		"run_id": RUN_ID,
		"schema_version": 1,
		"source_day": source_day,
		"stages": stages,
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_receipt.duplicate(true),
	}
	return plan


## The exact ten-key retirement receipt (ledger 1.3.4). completed_plan_sha256 is the section-2.6
## canonical digest of the sibling plan, so a mutated history record is detectable in-document.
func _retirement_receipt(plan: Dictionary) -> Dictionary:
	var resolution_receipt: Dictionary = plan["resolution_receipt"]
	var resolution_receipt_id := str(resolution_receipt["receipt_id"])
	var stages: Array = plan["stages"]
	var autosave_stage: Dictionary = stages[5]
	var autosave_receipt: Dictionary = autosave_stage["receipt"]
	var advance_stage: Dictionary = stages[4]
	var advance_prepared: Dictionary = advance_stage["prepared"]
	var provenance := _child_provenance(plan["transaction_issuer_receipt"], "hospital_resolution",
		1, [_p("resolution_receipt_id", resolution_receipt_id)])
	return {
		"receipt_id": str(provenance["child_id"]),
		"receipt_provenance": provenance,
		"resolution_kind": "condition_hospital",
		"resolution_receipt_id": resolution_receipt_id,
		"completed_plan_sha256": _sha256(plan),
		"autosave_stage_receipt_id": str(autosave_receipt["receipt_id"]),
		"source_day": int(plan["source_day"]),
		"target_day": int(plan["source_day"]) + 1,
		"target_causal_day_instance": str(advance_prepared["target_causal_day_instance"]),
		"disposition": "condition_hospital_plan_retired",
	}


## One condition_hospital_history entry, keyed by its own completed plan's resolution receipt id.
func _history_record(plan: Dictionary) -> Dictionary:
	var resolution_receipt: Dictionary = plan["resolution_receipt"]
	return {
		str(resolution_receipt["receipt_id"]): {
			"completed_plan": plan.duplicate(true),
			"retirement_receipt": _retirement_receipt(plan),
		},
	}


## The exact seven-key terminal_intent_handoff (ledger 1.3.5): receipt-free, unpublished by
## `status`, and carrying an outbox record whose payload IS the intent.
func _terminal_handoff(source_transaction_id: String,
		source_kind: String = "schedule_done") -> Dictionary:
	var intent := {"kind": "day7_terminal", "day": 7, "variant": "normal"}
	return {
		"destination_outbox_record": _destination_record("notification", intent, "pending"),
		"schema_version": 1,
		"source_kind": source_kind,
		"source_transaction_id": source_transaction_id,
		"source_transaction_issuer_receipt": _transaction_receipt(source_transaction_id),
		"status": "pending_oyo6",
		"terminal_intent": intent,
	}


## The thirteen-key v5 lifecycle aggregate (ledger 1.3). The remapper never validates it -- these
## bytes exist so a v5 fixture is a real document rather than a two-key stub.
func _lifecycle(overrides: Dictionary = {}) -> Dictionary:
	var lifecycle := {
		"active_condition_hospital_plan": null,
		"active_resolution_plan": null,
		"branch_id": "branch-old",
		"causal_day_instance": OLD_CAUSAL,
		"causal_day_instance_issuer_receipt": _issuer_receipt("causal_day_instance", OLD_CAUSAL),
		"condition_hospital_history": {},
		"day": 3,
		"desktop_timeline_generation": 0,
		"ending_plan": null,
		"restore_provenance": null,
		"run_id": RUN_ID,
		"state": "PLAYING",
		"terminal_intent_handoff": null,
	}
	for key: String in overrides:
		lifecycle[key] = overrides[key]
	return lifecycle


## A v5 snapshot: the shipped v4 fixture plus the two regions v5 adds. `options` may carry
## "schedule_view" and/or "lifecycle" override dictionaries.
func _v5_snapshot(old_tx: String, old_source_commit: Dictionary,
		options: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot(old_tx, old_source_commit)
	snapshot["schedule_view"] = options.get("schedule_view",
		_v5_view(3, OLD_CAUSAL))
	snapshot["lifecycle"] = _lifecycle(options.get("lifecycle", {}))
	return snapshot


## A bundle whose transaction_remap covers every (old -> new) pair in `mapping`. The bundle root is
## the FIRST pair, matching _bundle()'s own shape; insertion order is preserved so the mapping's
## first key is deterministic.
func _multi_bundle(mapping: Dictionary) -> Dictionary:
	var keys: Array = mapping.keys()
	var first_old := str(keys[0])
	var bundle := _bundle(first_old, str(mapping[first_old]))
	var remap: Dictionary = bundle["transaction_remap"]
	for old_id: Variant in keys:
		var new_id := str(mapping[old_id])
		remap[str(old_id)] = {
			"source_transaction_id": str(old_id), "new_transaction_id": new_id,
			"new_transaction_issuer_receipt": _transaction_receipt(new_id),
		}
	return bundle


func _registry() -> Dictionary:
	var loaded: Dictionary = load(REGISTRY_PATH).call("load_current")
	assert_true(loaded.get("ok", false),
		"the shipped schedule action registry must load (compile hazard H10): " + str(loaded))
	var value: Dictionary = loaded.get("value", {})
	return {"registry": value.get("registry"),
		"fingerprint": str(value.get("registry_fingerprint", ""))}


# ---- shared rejection assertions (ledger 4.0 rule 1) ----

## A rejection is a rejection AND is not the Step-1 skeleton's own typed `not_implemented`.
func _assert_refuses(result: Dictionary, label: String) -> void:
	assert_false(result.get("ok", true), label + ": the v5 remap must reject")
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		label + ": the Step-1 skeleton must not satisfy this rejection")


## The same, plus the frozen section-2.2 literal, for the faults whose code is unambiguous.
func _assert_refuses_with(result: Dictionary, code: StringName, label: String) -> void:
	_assert_refuses(result, label)
	assert_eq(result.get("code", &"not_implemented"), code,
		label + ": the frozen refusal literal, so a rename is a visible break")


## The two mutants plan line 564 demands of EVERY condition-Hospital cursor position, asserted
## INDEPENDENTLY so no single or-guard can satisfy both halves at once: a receipt that mixes the
## source and target allocations, and a stale dependent hash.
func _assert_hospital_mutants_reject(snapshot: Dictionary, bundle: Dictionary,
		label: String) -> void:
	var mixed := snapshot.duplicate(true)
	var mixed_lifecycle: Dictionary = mixed["lifecycle"]
	var mixed_plan: Dictionary = mixed_lifecycle["active_condition_hospital_plan"]
	mixed_plan["transaction_issuer_receipt"] = _transaction_receipt("new-hospital-tx")
	var mixed_result: Dictionary = _remapper().call("prepare", mixed, "restore-" + label, bundle)
	_assert_refuses_with(mixed_result, &"remap_condition_hospital_identity_split_invalid",
		label + " mixed source/target receipt")

	var stale := snapshot.duplicate(true)
	var stale_lifecycle: Dictionary = stale["lifecycle"]
	var stale_plan: Dictionary = stale_lifecycle["active_condition_hospital_plan"]
	var stale_record: Dictionary = stale_plan["destination_record"]
	stale_record["payload_hash"] = "c".repeat(64)
	var stale_result: Dictionary = _remapper().call("prepare", stale, "restore-" + label, bundle)
	_assert_refuses_with(stale_result, &"remap_condition_hospital_plan_invalid",
		label + " stale dependent hash")


## The history counterpart: after the retirement checkpoint the record is immutable, so the same
## two mutants must reject from inside condition_hospital_history instead of the active slot.
func _assert_history_mutants_reject(snapshot: Dictionary, bundle: Dictionary,
		history_key: String, label: String) -> void:
	var mixed := snapshot.duplicate(true)
	var mixed_lifecycle: Dictionary = mixed["lifecycle"]
	var mixed_history: Dictionary = mixed_lifecycle["condition_hospital_history"]
	var mixed_entry: Dictionary = mixed_history[history_key]
	var mixed_plan: Dictionary = mixed_entry["completed_plan"]
	mixed_plan["transaction_issuer_receipt"] = _transaction_receipt("new-hospital-tx")
	var mixed_result: Dictionary = _remapper().call("prepare", mixed, "restore-" + label, bundle)
	_assert_refuses_with(mixed_result, &"remap_history_mutated",
		label + " mixed source/target receipt in history")

	var stale := snapshot.duplicate(true)
	var stale_lifecycle: Dictionary = stale["lifecycle"]
	var stale_history: Dictionary = stale_lifecycle["condition_hospital_history"]
	var stale_entry: Dictionary = stale_history[history_key]
	var stale_retirement: Dictionary = stale_entry["retirement_receipt"]
	stale_retirement["completed_plan_sha256"] = "d".repeat(64)
	var stale_result: Dictionary = _remapper().call("prepare", stale, "restore-" + label, bundle)
	_assert_refuses_with(stale_result, &"remap_history_mutated",
		label + " stale completed_plan digest in history")


# ---- typed navigation into a prepare() result ----
#
# At Step 1 prepare() answers the four-key failure envelope with NO "value" member, so every reader
# below degrades to an empty Dictionary and the row fails as a clean assertion rather than an
# "Invalid access to key" crash. Nothing here reaches through a Variant.

func _prepared_snapshot(result: Dictionary) -> Dictionary:
	var value: Dictionary = result.get("value", {})
	return value.get("snapshot", {})


func _prepared_view(result: Dictionary) -> Dictionary:
	var snapshot := _prepared_snapshot(result)
	return snapshot.get("schedule_view", {})


func _prepared_pending_warning(result: Dictionary) -> Dictionary:
	var view := _prepared_view(result)
	var pending: Variant = view.get("pending_warning")
	if typeof(pending) != TYPE_DICTIONARY:
		return {}
	return pending


func _prepared_lifecycle(result: Dictionary) -> Dictionary:
	var snapshot := _prepared_snapshot(result)
	return snapshot.get("lifecycle", {})


func _prepared_consequence_pending(result: Dictionary) -> Dictionary:
	var snapshot := _prepared_snapshot(result)
	var desktop: Dictionary = snapshot.get("desktop", {})
	var consequence: Dictionary = desktop.get("consequence", {})
	var pending: Variant = consequence.get("pending")
	if typeof(pending) != TYPE_DICTIONARY:
		return {}
	return pending


func _census_ids(collected: Dictionary) -> Array:
	var value: Dictionary = collected.get("value", {})
	return value.get("transaction_ids", [])


# ---- census (R1-R8): the five v5 root families, each only when present, all in one set ----

func test_collect_includes_the_pending_warning_activation_root() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c1"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var snapshot := _v5_snapshot("old-tx-c1", source_commit, {"schedule_view": view})
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	var ids := _census_ids(collected)
	assert_true(ids.has("old-warning-tx"),
		"C1: pending_warning.opened_by_transaction_id is a rewindable root")
	assert_eq(ids, ["old-tx-c1", "old-warning-tx"],
		"sorted, unique, and no root invented beyond the two the document names")


func test_collect_includes_a_pending_condition_departure_root_exactly_once() -> void:
	if not _exists(): return
	var pending_receipt := _transaction_receipt("old-tx-c2")
	var source_commit := _child_provenance(pending_receipt, "board_start", 0, [])
	var condition_provenance := _child_provenance(pending_receipt, "condition", 0, [])
	var entry := _ledger_entry(condition_provenance, "a".repeat(64), "b".repeat(64))
	var view := _v5_view(3, OLD_CAUSAL, {
		"condition_departure_receipts": {str(entry["source_condition_receipt_id"]): entry},
	})
	var snapshot := _v5_snapshot("old-tx-c2", source_commit, {"schedule_view": view})
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	var ids := _census_ids(collected)
	var occurrences := 0
	for candidate: Variant in ids:
		if str(candidate) == "old-tx-c2":
			occurrences += 1
	assert_eq(occurrences, 1,
		"the ledger entry is keyed by a condition CHILD and contributes no id of its own, so the "
			+ "live pending root arrives exactly once")
	assert_eq(ids, ["old-tx-c2"], "no child id is ever mistaken for a rewindable root")


func test_collect_includes_every_failed_attempt_and_consumed_terminal_root() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c3"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	pending["attempt_receipts"] = {
		"old-attempt-tx": _terminal_receipt(pending, "navigation_failed", "old-attempt-tx",
			"hospital"),
	}
	var consumed_activation := _pending_warning("accepted_date", view, context,
		"old-consumed-open-tx")
	var consumed := _terminal_receipt(consumed_activation, "dismissed", "old-consumed-tx")
	view["pending_warning"] = pending
	view["consumed_warning_receipts"] = {
		_consumed_key(str(consumed_activation["warning_state_fingerprint"]), "accepted_date"):
			consumed,
	}
	var snapshot := _v5_snapshot("old-tx-c3", source_commit, {"schedule_view": view})
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	var ids := _census_ids(collected)
	assert_true(ids.has("old-attempt-tx"), "C2: every attempt_receipts key is a rewindable root")
	assert_true(ids.has("old-consumed-tx"),
		"C3: every consumed terminal receipt's transaction_id is a rewindable root")
	assert_false(ids.has("old-consumed-open-tx"),
		"the consumed activation's OPENING root is intentionally historical (ledger R15/OQ-1) and "
			+ "has no persisted home, so it is never collected")
	assert_eq(ids.size(), 4, "exactly the four roots the document still references")


func test_collect_includes_a_nonnull_active_condition_hospital_root() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c4"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "")
	var snapshot := _v5_snapshot("old-tx-c4", source_commit, {
		"lifecycle": {"active_condition_hospital_plan": plan},
	})
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	var ids := _census_ids(collected)
	assert_true(ids.has("old-hospital-tx"),
		"C4: a nonnull active plan's transaction_id is a rewindable root")
	assert_eq(ids, ["old-hospital-tx", "old-tx-c4"], "sorted and unique")


func test_collect_excludes_completed_condition_hospital_history_roots() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c5"), "board_start", 0, [])
	var retired := _condition_hospital_plan(6, "completed",
		{"transaction_id": "old-history-tx", "causal_day_instance": "causal-day-ancestor"})
	var snapshot := _v5_snapshot("old-tx-c5", source_commit, {
		"lifecycle": {"condition_hospital_history": _history_record(retired)},
	})
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	var ids := _census_ids(collected)
	assert_false(ids.has("old-history-tx"),
		"completed history is immutable and non-rewindable; collecting its root is a defect")
	assert_eq(ids, ["old-tx-c5"], "only the still-live board root survives the census")


func test_collect_rejects_an_attempt_key_that_disagrees_with_its_receipt_transaction_id() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c6"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var attempt := _terminal_receipt(pending, "navigation_failed", "old-attempt-tx", "hospital")
	pending["attempt_receipts"] = {"old-other-tx": attempt}
	view["pending_warning"] = pending
	assert_ne(str(attempt["transaction_id"]), "old-other-tx",
		"the fixture must really disagree with its own index key")
	var snapshot := _v5_snapshot("old-tx-c6", source_commit, {"schedule_view": view})
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	_assert_refuses_with(collected, &"remap_warning_key_stale",
		"R6 an attempt key that disagrees with its record is a refusal, never a silent union")


func test_collect_includes_a_nonnull_terminal_intent_handoff_root() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c7"), "board_start", 0, [])
	var snapshot := _v5_snapshot("old-tx-c7", source_commit, {
		"lifecycle": {
			"day": 7, "state": "TERMINAL_PENDING",
			"terminal_intent_handoff": _terminal_handoff("old-terminal-tx"),
		},
	})
	# TERMINAL_PENDING clears the live pending transaction, so C5 is the ONLY thing that keeps the
	# handoff's root inside the mapping; without it the remap refuses remap_dangling_transaction and
	# the state is unrestorable (ledger 3.12, RESOLVED R14/CF-1).
	var consequence: Dictionary = snapshot["desktop"]["consequence"]
	consequence["pending"] = null
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	var ids := _census_ids(collected)
	assert_true(ids.has("old-terminal-tx"),
		"C5: terminal_intent_handoff.source_transaction_id is a rewindable root")
	assert_eq(ids, ["old-terminal-tx", "old-tx-c7"], "sorted and unique")


func test_collect_leaves_a_v4_snapshot_census_byte_identical() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-c8"), "board_start", 0, [])
	var snapshot := _snapshot("old-tx-c8", source_commit)
	var frozen := snapshot.duplicate(true)
	var collected: Dictionary = _remapper().call("collect_rewindable_transaction_ids", snapshot)
	assert_true(collected.get("ok", false), JSON.stringify(collected))
	assert_eq(_census_ids(collected), ["old-tx-c8"],
		"the arrival of the five v5 root families must not change a v4 census")
	assert_eq(snapshot, frozen, "the census never mutates its argument")
	assert_false(snapshot.has("schedule_view"),
		"an absent schedule_view is legal mid-migration and is never synthesized")


# ---- the registration table (R9-R10) ----

func test_remap_table_declares_every_v5_region() -> void:
	if not _exists(): return
	var table: Array = (_remapper().get_script_constant_map() as Dictionary)["_REMAP_TABLE"]
	var paths: Array = []
	for row: Dictionary in table:
		paths.append(str(row["path"]))
	assert_eq(V5_REGION_PATHS.size(), 12, "ledger 3.12 S1-D freezes exactly twelve v5 rows")
	for expected: String in V5_REGION_PATHS:
		assert_true(paths.has(expected), "the table must declare the v5 region " + expected)
	var declared := 0
	for path: String in paths:
		if V5_REGION_PATHS.has(path):
			declared += 1
	assert_eq(declared, V5_REGION_PATHS.size(),
		"each v5 region is declared exactly once, so a reviewer finds every region in one place")


func test_remap_table_marks_the_v5_regions_handled() -> void:
	if not _exists(): return
	var table: Array = (_remapper().get_script_constant_map() as Dictionary)["_REMAP_TABLE"]
	var handled: Dictionary = {}
	for row: Dictionary in table:
		handled[str(row["path"])] = bool(row.get("handled", false))
	assert_eq(handled.size(), table.size(), "every table path is distinct")
	# RED BY DESIGN at Step 1: S1-D lands all twelve as handled:false with a nonempty reason so the
	# shipped table test stays green; Step 4 flips them and this row goes green with it.
	for expected: String in V5_REGION_PATHS:
		assert_true(bool(handled.get(expected, false)),
			"Step 4 flips this v5 region to handled: " + expected)


# ---- warnings (R11-R19) ----

func test_prepare_rekeys_consumed_warning_receipts_to_the_recomputed_digest() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r11"), "board_start", 0, [])
	var old_context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var activation := _pending_warning("accepted_date", view, old_context, "old-consumed-open-tx")
	var consumed := _terminal_receipt(activation, "dismissed", "old-consumed-tx")
	var old_digest := str(activation["warning_state_fingerprint"])
	view["consumed_warning_receipts"] = {_consumed_key(old_digest, "accepted_date"): consumed}
	var snapshot := _v5_snapshot("old-tx-r11", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r11": "new-tx-r11", "old-consumed-tx": "new-consumed-tx"})

	var new_digest := _warning_digest(
		_warning_preimage(_v5_view(3, NEW_CAUSAL), _warning_context("branch-new", 1, NEW_CAUSAL)))
	assert_ne(new_digest, old_digest, "the remapped preimage must really produce a new digest")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r11", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_view := _prepared_view(result)
	var consumed_map: Dictionary = remapped_view.get("consumed_warning_receipts", {})
	assert_true(consumed_map.has(_consumed_key(new_digest, "accepted_date")),
		"a stale consumed key silently suppresses a warning ScheduleWarningPolicy.next_warning() "
			+ "would otherwise raise")
	assert_false(consumed_map.has(_consumed_key(old_digest, "accepted_date")),
		"the old key is gone, not left beside the new one")

	var malformed := snapshot.duplicate(true)
	var malformed_view: Dictionary = malformed["schedule_view"]
	malformed_view["schedule_view_sha256"] = "e".repeat(64)
	var malformed_result: Dictionary = _remapper().call("prepare", malformed, "restore-txn-r11",
		bundle)
	_assert_refuses_with(malformed_result, &"remap_schedule_view_invalid", "R11 an eighth view key")


func test_prepare_rekeys_attempt_receipts_to_the_new_transaction_id() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r12"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	pending["attempt_receipts"] = {
		"old-attempt-tx": _terminal_receipt(pending, "navigation_failed", "old-attempt-tx",
			"hospital"),
	}
	view["pending_warning"] = pending
	var snapshot := _v5_snapshot("old-tx-r12", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({
		"old-tx-r12": "new-tx-r12", "old-warning-tx": "new-warning-tx",
		"old-attempt-tx": "new-attempt-tx",
	})
	assert_eq((bundle["transaction_remap"] as Dictionary).size(), 3,
		"the fixture bundle must cover every collected root")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r12", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_pending := _prepared_pending_warning(result)
	var attempts: Dictionary = remapped_pending.get("attempt_receipts", {})
	assert_true(attempts.has("new-attempt-tx"),
		"a stale attempt key silently re-warns after a restore")
	assert_false(attempts.has("old-attempt-tx"), "the old key is gone")
	var attempt: Dictionary = attempts.get("new-attempt-tx", {})
	assert_eq(str(attempt.get("transaction_id", "")), "new-attempt-tx",
		"the record's own transaction_id moves with its key")
	var live_activation_id := str(remapped_pending.get("activation_id", ""))
	assert_ne(live_activation_id, str(pending["activation_id"]),
		"the live activation really was re-derived under the mapped opened root")
	assert_eq(str(attempt.get("activation_id", "")), live_activation_id,
		"an attempt receipt mirrors the LIVE activation, never the historical one")
	var expected_sources: Array = [
		_p("activation_id", live_activation_id), _p("warning_kind", "base_minesweeper"),
		_p("intent", "hospital"),
	]
	expected_sources.sort()
	var expected_receipt := _child_provenance(_transaction_receipt("new-attempt-tx"), "navigation", 0,
		expected_sources)
	assert_eq(str(attempt.get("receipt_id", "")), str(expected_receipt["child_id"]),
		"the attempt receipt is re-derived under the mapped attempt root with the new activation "
			+ "projection")
	assert_eq(attempt.get("receipt_provenance", {}), expected_receipt,
		"its six-key provenance is emitted in the frozen insertion order")


func test_prepare_recomputes_the_warning_fingerprint_from_the_remapped_stored_preimage() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r13"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var snapshot := _v5_snapshot("old-tx-r13", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r13": "new-tx-r13", "old-warning-tx": "new-warning-tx"})

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r13", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_pending := _prepared_pending_warning(result)
	var preimage: Dictionary = remapped_pending.get("warning_fingerprint_preimage", {})
	assert_eq(str(remapped_pending.get("warning_state_fingerprint", "")), _sha256(preimage),
		"the fingerprint is the canonical digest of the record's OWN remapped preimage -- a "
			+ "post-condition on the target, not only a pre-condition on the source")
	var projection: Dictionary = preimage.get("view_projection", {})
	assert_eq(str(projection.get("causal_day_instance", "")), NEW_CAUSAL,
		"exactly the five named identity members move")
	var remapped_context: Dictionary = preimage.get("context", {})
	assert_eq(str(remapped_context.get("run_id", "")), RUN_ID, "run_id is never rewritten")
	assert_eq(str(remapped_context.get("branch_id", "")), "branch-new",
		"context.branch_id is one of the five")


func test_prepare_never_substitutes_the_live_view_or_context_for_the_stored_preimage() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r14"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var captured_view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", captured_view, context, "old-warning-tx")
	# The live view moves on AFTER capture: a second entry lands. The stored preimage must still
	# describe the one-entry state it was captured over.
	var live_view := _v5_view(3, OLD_CAUSAL)
	var live_entries: Array = live_view["entries"]
	live_entries.append(_v5_entry("draft-2", 1, "training", 3))
	live_view["pending_warning"] = pending
	assert_eq(live_entries.size(), 2, "the fixture must really diverge from the captured projection")
	var snapshot := _v5_snapshot("old-tx-r14", source_commit, {"schedule_view": live_view})
	var bundle := _multi_bundle({"old-tx-r14": "new-tx-r14", "old-warning-tx": "new-warning-tx"})

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r14", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_pending := _prepared_pending_warning(result)
	var preimage: Dictionary = remapped_pending.get("warning_fingerprint_preimage", {})
	var projection: Dictionary = preimage.get("view_projection", {})
	var projected_entries: Array = projection.get("entries", [])
	assert_eq(projected_entries.size(), 1,
		"the stored preimage is taken verbatim; the live view is never substituted for it")
	assert_eq(projected_entries, captured_view["entries"],
		"the captured entries survive byte-for-byte")


func test_prepare_rejects_a_string_edited_warning_preimage() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r15"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var preimage: Dictionary = pending["warning_fingerprint_preimage"]
	var edited_context: Dictionary = preimage["context"]
	edited_context["motivation"] = 5
	assert_ne(_sha256(preimage), str(pending["warning_state_fingerprint"]),
		"the fixture must really have been edited out from under its own digest")
	view["pending_warning"] = pending
	var snapshot := _v5_snapshot("old-tx-r15", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r15": "new-tx-r15", "old-warning-tx": "new-warning-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r15", bundle)
	_assert_refuses_with(result, &"remap_warning_fingerprint_mismatch",
		"R15 a hand-edited stored preimage")


func test_prepare_rejects_a_string_edited_activation_provenance() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r16"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var provenance: Dictionary = pending["activation_id_provenance"]
	var source_ids: Array = provenance["source_ids"]
	source_ids[0] = str(source_ids[0]) + "-hand-edited"
	assert_eq(source_ids.size(), 2,
		"the fixture keeps the projection pair; only its bytes were edited")
	view["pending_warning"] = pending
	var snapshot := _v5_snapshot("old-tx-r16", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r16": "new-tx-r16", "old-warning-tx": "new-warning-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r16", bundle)
	_assert_refuses_with(result, &"remap_child_id_mismatch",
		"R16 a Tier-B provenance is rebuilt from facts, never repaired by editing its string")


func test_prepare_rederives_the_activation_child_under_the_mapped_parent_receipt() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r17"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var snapshot := _v5_snapshot("old-tx-r17", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r17": "new-tx-r17", "old-warning-tx": "new-warning-tx"})

	var new_digest := _warning_digest(
		_warning_preimage(_v5_view(3, NEW_CAUSAL), _warning_context("branch-new", 1, NEW_CAUSAL)))
	var expected := _activation_provenance("base_minesweeper", new_digest,
		_transaction_receipt("new-warning-tx"))
	assert_eq(str(expected["child_kind"]), "warning", "kind and ordinal never change")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r17", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_pending := _prepared_pending_warning(result)
	assert_eq(str(remapped_pending.get("activation_id", "")), str(expected["child_id"]),
		"the live activation child is re-derived under the mapped parent receipt AND the new digest")
	assert_eq(remapped_pending.get("activation_id_provenance", {}), expected,
		"the six-key provenance is emitted in the frozen insertion order")


func test_prepare_rederives_a_navigation_terminal_receipt_with_the_new_activation_projection() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r18"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var activation := _pending_warning("unread_invitation", view, context, "old-consumed-open-tx")
	var consumed := _terminal_receipt(activation, "navigation_committed", "old-consumed-tx",
		"open_messages")
	var old_digest := str(activation["warning_state_fingerprint"])
	var historical_activation_id := str(activation["activation_id"])
	view["consumed_warning_receipts"] = {_consumed_key(old_digest, "unread_invitation"): consumed}
	var snapshot := _v5_snapshot("old-tx-r18", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r18": "new-tx-r18", "old-consumed-tx": "new-consumed-tx"})
	var consumed_provenance: Dictionary = consumed["receipt_provenance"]
	assert_eq(str(consumed_provenance["child_kind"]), "navigation",
		"a navigation outcome anchors a navigation child, not a warning child")

	var new_digest := _warning_digest(
		_warning_preimage(_v5_view(3, NEW_CAUSAL), _warning_context("branch-new", 1, NEW_CAUSAL)))
	var expected_source_ids: Array = [
		_p("activation_id", historical_activation_id), _p("warning_kind", "unread_invitation"),
		_p("intent", "open_messages"),
	]
	expected_source_ids.sort()
	var expected := _child_provenance(_transaction_receipt("new-consumed-tx"), "navigation", 0,
		expected_source_ids)

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r18", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_view := _prepared_view(result)
	var remapped_map: Dictionary = remapped_view.get("consumed_warning_receipts", {})
	var remapped: Dictionary = remapped_map.get(_consumed_key(new_digest, "unread_invitation"), {})
	assert_eq(str(remapped.get("activation_id", "")), historical_activation_id,
		"the consumed activation is intentionally historical and is preserved byte-for-byte")
	assert_eq(remapped.get("activation_id_provenance", {}), activation["activation_id_provenance"],
		"its provenance survives too; the opening receipt has no persisted home to re-derive from")
	assert_eq(str(remapped.get("warning_state_fingerprint", "")), new_digest,
		"the digest IS recomputed, so the consumed record is deliberately mixed")
	assert_eq(str(remapped.get("receipt_id", "")), str(expected["child_id"]),
		"the terminal receipt is re-derived under the mapped terminal root")


func test_prepare_rejects_a_warning_context_that_disagrees_with_the_mapped_board_identity() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r19"), "board_start", 0, [])
	# Internally consistent (board_identity mirrors its own context) but describing a branch the
	# snapshot's board never had, so the ONLY fault is the disagreement with the mapped owners.
	var foreign_context := _warning_context("branch-foreign", 7, "causal-day-foreign")
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, foreign_context,
		"old-warning-tx")
	var foreign_identity: Dictionary = foreign_context["board_identity"]
	assert_eq(str(foreign_identity["branch_id"]), "branch-foreign",
		"the fixture context is self-consistent; it disagrees only with the board")
	var snapshot := _v5_snapshot("old-tx-r19", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r19": "new-tx-r19", "old-warning-tx": "new-warning-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r19", bundle)
	_assert_refuses_with(result, &"remap_warning_context_mismatch",
		"R19 a remapped context is validated against the mapped owners")


# ---- ledger and payload (R20-R24) ----

func test_prepare_rekeys_the_pending_condition_departure_receipt_to_the_rederived_condition_id() -> void:
	if not _exists(): return
	var pending_receipt := _transaction_receipt("old-tx-r20")
	var source_commit := _child_provenance(pending_receipt, "board_start", 0, [])
	var condition_provenance := _child_provenance(pending_receipt, "condition", 0, [])
	var entry := _ledger_entry(condition_provenance, "a".repeat(64), "b".repeat(64))
	var old_key := str(entry["source_condition_receipt_id"])
	var view := _v5_view(3, OLD_CAUSAL, {"condition_departure_receipts": {old_key: entry}})
	var snapshot := _v5_snapshot("old-tx-r20", source_commit, {"schedule_view": view})
	var bundle := _bundle("old-tx-r20", "new-tx-r20")
	var expected := _child_provenance(_transaction_receipt("new-tx-r20"), "condition", 0, [])
	assert_ne(str(expected["child_id"]), old_key,
		"the condition child really changes when its parent receipt does")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r20", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_view := _prepared_view(result)
	var ledger: Dictionary = remapped_view.get("condition_departure_receipts", {})
	assert_true(ledger.has(str(expected["child_id"])),
		"the one entry tied to the live pending root is rekeyed to the re-derived condition id")
	assert_false(ledger.has(old_key), "the old key is gone, not left beside the new one")
	var remapped_entry: Dictionary = ledger.get(str(expected["child_id"]), {})
	assert_eq(str(remapped_entry.get("source_condition_receipt_id", "")), str(expected["child_id"]),
		"the index key still equals the receipt's own source id")
	assert_eq(str(remapped_entry.get("disposition", "")), "condition_departure_view_committed",
		"disposition stays exactly the frozen literal")


func test_prepare_leaves_every_unrelated_completed_ledger_entry_byte_identical() -> void:
	if not _exists(): return
	var pending_receipt := _transaction_receipt("old-tx-r21")
	var source_commit := _child_provenance(pending_receipt, "board_start", 0, [])
	var live_entry := _ledger_entry(_child_provenance(pending_receipt, "condition", 0, []),
		"a".repeat(64), "b".repeat(64))
	var historical_receipt := _transaction_receipt("old-history-tx", "ancestornamespace", 9)
	var historical_entry := _ledger_entry(
		_child_provenance(historical_receipt, "condition", 0, []), "c".repeat(64), "d".repeat(64))
	var historical_key := str(historical_entry["source_condition_receipt_id"])
	var frozen_historical := historical_entry.duplicate(true)
	var view := _v5_view(3, OLD_CAUSAL, {"condition_departure_receipts": {
		str(live_entry["source_condition_receipt_id"]): live_entry,
		historical_key: historical_entry,
	}})
	var snapshot := _v5_snapshot("old-tx-r21", source_commit, {"schedule_view": view})
	var bundle := _bundle("old-tx-r21", "new-tx-r21")
	assert_ne(historical_key, str(live_entry["source_condition_receipt_id"]),
		"the fixture carries two genuinely different ledger entries")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r21", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_view := _prepared_view(result)
	var ledger: Dictionary = remapped_view.get("condition_departure_receipts", {})
	assert_true(ledger.has(historical_key), "an entry with no live pending root keeps its key")
	assert_eq(ledger.get(historical_key, {}), frozen_historical,
		"every other ledger entry survives == against its source bytes")


func test_prepare_recomputes_both_view_hashes_from_the_remapped_recovery_payload() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r22"), "board_start", 0, [])
	var snapshot := _v5_snapshot("old-tx-r22", source_commit)
	var consequence: Dictionary = snapshot["desktop"]["consequence"]
	var pending: Dictionary = consequence["pending"]
	var payload: Dictionary = pending["recovery_payload"]
	var before_view := _v5_view(3, OLD_CAUSAL)
	var after_view := _v5_view(3, OLD_CAUSAL)
	var after_entries: Array = after_view["entries"]
	after_entries.append(_v5_entry("draft-2", 1, "training", 3))
	payload["schedule_view_before"] = before_view
	payload["schedule_view_before_sha256"] = _sha256(before_view)
	payload["schedule_view_after"] = after_view
	payload["schedule_view_after_sha256"] = _sha256(after_view)
	pending["recovery_payload_sha256"] = _sha256(payload)
	var bundle := _bundle("old-tx-r22", "new-tx-r22")
	assert_ne(str(payload["schedule_view_before_sha256"]),
		str(payload["schedule_view_after_sha256"]),
		"the fixture's two frozen view pairs really differ")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r22", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var remapped_pending := _prepared_consequence_pending(result)
	var remapped_payload: Dictionary = remapped_pending.get("recovery_payload", {})
	var remapped_before: Dictionary = remapped_payload.get("schedule_view_before", {})
	var remapped_after: Dictionary = remapped_payload.get("schedule_view_after", {})
	assert_eq(str(remapped_before.get("causal_day_instance", "")), NEW_CAUSAL,
		"the admission-ready view members are remapped, not ridden through unremapped")
	assert_eq(str(remapped_payload.get("schedule_view_before_sha256", "")),
		_sha256(remapped_before), "the before hash is recomputed from the remapped view")
	assert_eq(str(remapped_payload.get("schedule_view_after_sha256", "")),
		_sha256(remapped_after), "the after hash is recomputed from the remapped view")
	assert_eq(str(remapped_pending.get("recovery_payload_sha256", "")), _sha256(remapped_payload),
		"the payload digest is recomputed after the view members move")


func test_prepare_rejects_a_ledger_hash_that_disagrees_with_the_remapped_payload() -> void:
	if not _exists(): return
	var pending_receipt := _transaction_receipt("old-tx-r23")
	var source_commit := _child_provenance(pending_receipt, "board_start", 0, [])
	var before_view := _v5_view(3, OLD_CAUSAL)
	var after_view := _v5_view(3, OLD_CAUSAL)
	var after_entries: Array = after_view["entries"]
	after_entries.append(_v5_entry("draft-2", 1, "training", 3))
	var entry := _ledger_entry(_child_provenance(pending_receipt, "condition", 0, []),
		_sha256(before_view), "f".repeat(64))
	var view := _v5_view(3, OLD_CAUSAL, {
		"condition_departure_receipts": {str(entry["source_condition_receipt_id"]): entry},
	})
	var snapshot := _v5_snapshot("old-tx-r23", source_commit, {"schedule_view": view})
	var consequence: Dictionary = snapshot["desktop"]["consequence"]
	var pending: Dictionary = consequence["pending"]
	var payload: Dictionary = pending["recovery_payload"]
	payload["schedule_view_before"] = before_view
	payload["schedule_view_before_sha256"] = _sha256(before_view)
	payload["schedule_view_after"] = after_view
	payload["schedule_view_after_sha256"] = _sha256(after_view)
	pending["recovery_payload_sha256"] = _sha256(payload)
	assert_ne(str(entry["schedule_view_after_sha256"]), _sha256(after_view),
		"exactly one of the ledger's two hashes disagrees with the payload it describes")
	var bundle := _bundle("old-tx-r23", "new-tx-r23")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r23", bundle)
	_assert_refuses_with(result, &"remap_ledger_payload_mismatch",
		"R23 the ledger's two hashes must equal the payload's own recomputed pair")


func test_the_view_ledger_is_excluded_from_the_optimistic_fingerprint_preimage() -> void:
	var registry := _registry()
	var bare := _v5_view(3, OLD_CAUSAL)
	var with_ledger := bare.duplicate(true)
	var entry := _ledger_entry(
		_child_provenance(_transaction_receipt("old-tx-r24"), "condition", 0, []),
		"a".repeat(64), "b".repeat(64))
	with_ledger["condition_departure_receipts"] = {
		str(entry["source_condition_receipt_id"]): entry,
	}
	var view_state: Script = load(VIEW_STATE_PATH)
	var bare_fingerprint: Dictionary = view_state.call("fingerprint", bare, registry["registry"],
		registry["fingerprint"])
	var ledger_fingerprint: Dictionary = view_state.call("fingerprint", with_ledger,
		registry["registry"], registry["fingerprint"])
	assert_true(bare_fingerprint.get("ok", false), JSON.stringify(bare_fingerprint))
	assert_true(ledger_fingerprint.get("ok", false), JSON.stringify(ledger_fingerprint))
	var bare_value: Dictionary = bare_fingerprint.get("value", {})
	var ledger_value: Dictionary = ledger_fingerprint.get("value", {})
	assert_eq(str(ledger_value.get("fingerprint", "")), str(bare_value.get("fingerprint", "")),
		"the append-only ledger is excluded from the optimistic preimage -- the structural reason a "
			+ "recovery remap can never fabricate a different view expectation")


# ---- real-owner cross-checks (R25-R26) ----

func test_the_remappers_warning_digest_equals_the_real_schedule_warning_policy_digest() -> void:
	if not _exists(): return
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var preimage := _warning_preimage(view, context)
	var remapper_digest := str(_remapper().call("_canonical_sha256", preimage))
	var policy: Dictionary = load(WARNING_POLICY_PATH).call("warning_state_fingerprint", view,
		context)
	assert_true(policy.get("ok", false), JSON.stringify(policy))
	assert_eq(remapper_digest.length(), 64, "a lowercase sha256 hex digest")
	var policy_value: Dictionary = policy.get("value", {})
	assert_eq(remapper_digest, str(policy_value.get("fingerprint", "")),
		"the remapper computes its own canonical hash (S1-E: warning_state_fingerprint needs a full "
			+ "seven-key view and is unusable here), so nothing but this cross-check proves the two "
			+ "shipped spellings of the one section-2.6 recipe stay byte-identical")


func test_the_remappers_projection_helper_equals_the_real_controllers_p() -> void:
	if not _exists(): return
	var source := FileAccess.get_file_as_string(REMAPPER_PATH)
	var controller: Object = load(CONTROLLER_PATH).new()
	var samples: Array = [
		["warning_kind", "base_minesweeper"],
		["ordinal", 4],
		["source_ids", ["a-id", "b-id"]],
	]
	for sample: Array in samples:
		var field := str(sample[0])
		assert_eq(_p(field, sample[1]), str(controller.call("_p", field, sample[1])),
			"this file's own third copy must already agree with the real controller: " + field)
	assert_true(source.contains("static func _p("),
		"Step 4 gives the domain-layer remapper its own _p() duplicate (ledger 3.12, Tier B), "
			+ "because _p is private on the application-layer ScheduleViewController")
	if not source.contains("static func _p("):
		return
	for duplicated: Array in samples:
		var duplicated_field := str(duplicated[0])
		assert_eq(str(_remapper().call("_p", duplicated_field, duplicated[1])),
			str(controller.call("_p", duplicated_field, duplicated[1])),
			"the remapper duplicate must equal ScheduleViewController._p() exactly: "
				+ duplicated_field)


func _prepared_consequence(result: Dictionary) -> Dictionary:
	var snapshot := _prepared_snapshot(result)
	var desktop: Dictionary = snapshot.get("desktop", {})
	return desktop.get("consequence", {})


# ---- the condition-Hospital matrix (R27-R34): one row per plan-enumerated cursor position ----
#
# Plan line 564 enumerates the positions and adds "each case rejects a mixed source/target receipt
# or stale dependent hash". Every row below therefore carries BOTH mutants through
# _assert_hospital_mutants_reject(), asserted independently, so no single or-guard can leave one of
# the two operands permanently untested.

func test_prepare_preserves_the_condition_hospital_cursor_and_prepared_receipt_partition() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r27"), "board_start", 0, [])
	var plan := _condition_hospital_plan(0, "pending")
	var snapshot := _v5_snapshot("old-tx-r27", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r27": "new-tx-r27", "old-hospital-tx": "new-hospital-tx"})
	var source_stages: Array = plan["stages"]
	assert_eq(source_stages.size(), 6, "stages are never removed or renumbered")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r27", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped_plan: Dictionary = lifecycle.get("active_condition_hospital_plan", {})
	assert_eq(int(remapped_plan.get("cursor", -1)), 0, "cursor is never changed by a remap")
	var stages: Array = remapped_plan.get("stages", [])
	assert_eq(stages.size(), 6, "the six stages survive the remap")
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		if index == 0:
			assert_not_null(stage.get("stage_identity"), "the cursor record is active")
			assert_not_null(stage.get("prepared"), "an active stage carries its prepared payload")
			assert_eq(stage.get("receipt"), null, "an active stage has no receipt yet")
		else:
			assert_eq(stage.get("state"), "pending", "the state sequence is a prefix, never a gap")
			assert_eq(stage.get("stage_identity"), null, "a pending stage is all three null")
			assert_eq(stage.get("prepared"), null, "a pending stage is all three null")
			assert_eq(stage.get("receipt"), null, "a pending stage is all three null")

	var drifted := snapshot.duplicate(true)
	var drifted_lifecycle: Dictionary = drifted["lifecycle"]
	var drifted_plan: Dictionary = drifted_lifecycle["active_condition_hospital_plan"]
	drifted_plan["cursor"] = 3
	var drifted_result: Dictionary = _remapper().call("prepare", drifted, "restore-txn-r27", bundle)
	_assert_refuses_with(drifted_result, &"remap_condition_hospital_cursor_mismatch",
		"R27 cursor must equal the completed prefix")
	_assert_hospital_mutants_reject(snapshot, bundle, "r27")


func test_prepare_carries_a_committed_allocator_root_with_stage_four_still_pending_as_recovery() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r27a"), "board_start", 0, [])
	# The plan's distinct legal state: the allocator root is committed, stage 4 has NOT run, so the
	# identity-split law still forbids a split and the not-yet-adopted target is not live.
	var plan := _condition_hospital_plan(4, "pending")
	var snapshot := _v5_snapshot("old-tx-r27a", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r27a": "new-tx-r27a", "old-hospital-tx": "new-hospital-tx"})
	var source_stages: Array = plan["stages"]
	var source_stage_four: Dictionary = source_stages[4]
	assert_eq(str(source_stage_four["state"]), "pending",
		"the fixture really is the committed-root / stage-four-pending state")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r27a", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped_plan: Dictionary = lifecycle.get("active_condition_hospital_plan", {})
	assert_eq(int(remapped_plan.get("cursor", -1)), 4, "the committed prefix is carried as recovery")
	assert_eq(str(remapped_plan.get("causal_day_instance", "")), NEW_CAUSAL,
		"cursor 4 with stage 4 pending forbids a split, so the live source identity is mapped")
	assert_eq(str(remapped_plan.get("transaction_id", "")), "new-hospital-tx",
		"the still-live source identity is mapped exactly once")
	var stages: Array = remapped_plan.get("stages", [])
	var stage_four: Dictionary = stages[4] if stages.size() > 4 else {}
	assert_eq(str(stage_four.get("state", "")), "pending",
		"the not-yet-adopted target is never treated as live")
	assert_eq(stage_four.get("prepared"), null,
		"a pending advance_day stage carries no target allocation at all")
	_assert_hospital_mutants_reject(snapshot, bundle, "r27a")


func test_prepare_rejects_an_active_stage_four_paired_with_source_current_live_state() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r28"), "board_start", 0, [])
	# The one illegal shape at the checkpoint/live transition: ONE allocation used as both the
	# plan's own source token and its stage-4 target (ledger 1.3.3, final bullet).
	var illegal := _condition_hospital_plan(4, "active",
		{"causal_day_instance": "causal-day-ancestor", "stage4_target": "causal-day-ancestor"})
	var illegal_snapshot := _v5_snapshot("old-tx-r28", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": illegal}})
	var bundle := _multi_bundle({"old-tx-r28": "new-tx-r28", "old-hospital-tx": "new-hospital-tx"})
	var illegal_stages: Array = illegal["stages"]
	var illegal_stage_four: Dictionary = illegal_stages[4]
	var illegal_prepared: Dictionary = illegal_stage_four["prepared"]
	assert_eq(str(illegal_prepared["target_causal_day_instance"]),
		str(illegal["causal_day_instance"]),
		"the fixture really uses one allocation as both source and target")
	var illegal_result: Dictionary = _remapper().call("prepare", illegal_snapshot,
		"restore-txn-r28", bundle)
	_assert_refuses_with(illegal_result, &"remap_condition_hospital_identity_split_invalid",
		"R28 an active stage four paired with its own source-current live state")

	var legal := _condition_hospital_plan(4, "active",
		{"causal_day_instance": "causal-day-ancestor"})
	var legal_snapshot := _v5_snapshot("old-tx-r28", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": legal}})
	var legal_result: Dictionary = _remapper().call("prepare", legal_snapshot, "restore-txn-r28",
		bundle)
	assert_true(legal_result.get("ok", false),
		"stage 4 active IS the one legal split: " + JSON.stringify(legal_result))
	_assert_hospital_mutants_reject(legal_snapshot, bundle, "r28")


func test_prepare_rejects_a_nonstage_four_active_stage_paired_with_split_identities() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r29"), "board_start", 0, [])
	var illegal := _condition_hospital_plan(2, "pending",
		{"causal_day_instance": "causal-day-ancestor"})
	var illegal_snapshot := _v5_snapshot("old-tx-r29", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": illegal}})
	var bundle := _multi_bundle({"old-tx-r29": "new-tx-r29", "old-hospital-tx": "new-hospital-tx"})
	assert_ne(str(illegal["causal_day_instance"]), OLD_CAUSAL,
		"the fixture really splits the plan identity from the lifecycle's own")
	var illegal_result: Dictionary = _remapper().call("prepare", illegal_snapshot,
		"restore-txn-r29", bundle)
	_assert_refuses_with(illegal_result, &"remap_condition_hospital_identity_split_invalid",
		"R29 a split identity at an active stage other than four")

	var legal := _condition_hospital_plan(2, "pending")
	var legal_snapshot := _v5_snapshot("old-tx-r29", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": legal}})
	var legal_result: Dictionary = _remapper().call("prepare", legal_snapshot, "restore-txn-r29",
		bundle)
	assert_true(legal_result.get("ok", false),
		"an unsplit plan at cursor 2 is lawful: " + JSON.stringify(legal_result))
	_assert_hospital_mutants_reject(legal_snapshot, bundle, "r29")


func test_prepare_preserves_the_historical_source_identity_after_completed_stage_four() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r30"), "board_start", 0, [])
	var plan := _condition_hospital_plan(5, "completed",
		{"causal_day_instance": "causal-day-ancestor"})
	var snapshot := _v5_snapshot("old-tx-r30", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r30": "new-tx-r30", "old-hospital-tx": "new-hospital-tx"})
	assert_eq(int(plan["cursor"]), 5, "cursor >= 5 is the second half of the legal split")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r30", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped_plan: Dictionary = lifecycle.get("active_condition_hospital_plan", {})
	assert_eq(str(remapped_plan.get("causal_day_instance", "")), "causal-day-ancestor",
		"the plan's top-level source identity is historical ancestry and is never rewritten")
	assert_eq(str(lifecycle.get("causal_day_instance", "")), NEW_CAUSAL,
		"the lifecycle's own live identity DOES move, which is what makes the split visible")
	_assert_hospital_mutants_reject(snapshot, bundle, "r30")


func test_prepare_recomputes_every_stage_key_from_the_rederived_resolution_receipt() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r31"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	var snapshot := _v5_snapshot("old-tx-r31", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r31": "new-tx-r31", "old-hospital-tx": "new-hospital-tx"})
	var expected_resolution := _child_provenance(_transaction_receipt("new-hospital-tx"),
		"hospital_resolution", 0, [_p("source_day", 3)])
	var expected_resolution_id := str(expected_resolution["child_id"])
	var source_resolution: Dictionary = plan["resolution_receipt"]
	assert_ne(expected_resolution_id, str(source_resolution["receipt_id"]),
		"the resolution receipt really is re-derived under the mapped root")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r31", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped_plan: Dictionary = lifecycle.get("active_condition_hospital_plan", {})
	var remapped_resolution: Dictionary = remapped_plan.get("resolution_receipt", {})
	assert_eq(str(remapped_resolution.get("receipt_id", "")), expected_resolution_id,
		"the resolution receipt is re-derived before any stage key is recomputed")
	var expected_condition := _child_provenance(_transaction_receipt("new-hospital-tx"),
		"condition", 0, [])
	var remapped_condition: Dictionary = remapped_plan.get("condition_receipt", {})
	assert_eq(str(remapped_condition.get("receipt_id", "")), str(expected_condition["child_id"]),
		"the plan's condition receipt is re-derived under the mapped root")
	assert_eq(remapped_condition.get("receipt_provenance", {}), expected_condition,
		"with its six-key provenance in the frozen insertion order")
	assert_eq(str(remapped_condition.get("decision", "")), "hospital_day",
		"decision is semantic and never moves")
	var stages: Array = remapped_plan.get("stages", [])
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		assert_eq(str(stage.get("stage_key", "")),
			expected_resolution_id + ":" + str(HOSPITAL_STAGE_IDS[index]),
			"stage_key is the resolution receipt id plus the stage id, never a transaction id, "
				+ "issuer root, receipt id or checkpoint identity")
	_assert_hospital_mutants_reject(snapshot, bundle, "r31")


func test_prepare_rederives_stage_five_references_hashes_and_children_from_the_mapped_target() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r32a"), "board_start", 0, [])
	var bundle := _multi_bundle({"old-tx-r32a": "new-tx-r32a", "old-hospital-tx": "new-hospital-tx"})
	var mapped_parent := _transaction_receipt("new-hospital-tx")
	var expected_identity := _child_provenance(mapped_parent, "day_resolution_stage", 5,
		[_p("stage_id", "autosave_new_day")])
	assert_eq(str(HOSPITAL_STAGE_IDS[5]), "autosave_new_day", "stage 5 is the autosave stage")

	# BEFORE stage 5: the cursor sits on it, so it carries an identity and a prepared payload only.
	var before_plan := _condition_hospital_plan(5, "completed",
		{"causal_day_instance": "causal-day-ancestor"})
	var before_snapshot := _v5_snapshot("old-tx-r32a", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": before_plan}})
	var before_result: Dictionary = _remapper().call("prepare", before_snapshot,
		"restore-txn-r32a-before", bundle)
	assert_true(before_result.get("ok", false), JSON.stringify(before_result))
	var before_lifecycle := _prepared_lifecycle(before_result)
	var before_remapped: Dictionary = before_lifecycle.get("active_condition_hospital_plan", {})
	var before_stages: Array = before_remapped.get("stages", [])
	var before_stage: Dictionary = before_stages[5] if before_stages.size() > 5 else {}
	assert_eq(before_stage.get("stage_identity", {}),
		{"child_id": str(expected_identity["child_id"]), "input_receipt_ids": [],
			"provenance": expected_identity},
		"the stage-5 child is re-derived from the mapped target, never carried stale, inside the "
			+ "producer's three-key envelope")
	assert_eq(before_stage.get("receipt"), null, "the active stage still has no receipt")

	# AFTER stage 5: completed, so the receipt id must equal the re-derived child id.
	var after_plan := _condition_hospital_plan(6, "completed",
		{"causal_day_instance": "causal-day-ancestor"})
	var after_snapshot := _v5_snapshot("old-tx-r32a", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": after_plan}})
	var after_result: Dictionary = _remapper().call("prepare", after_snapshot,
		"restore-txn-r32a-after", bundle)
	assert_true(after_result.get("ok", false), JSON.stringify(after_result))
	var after_lifecycle := _prepared_lifecycle(after_result)
	var after_remapped: Dictionary = after_lifecycle.get("active_condition_hospital_plan", {})
	var after_stages: Array = after_remapped.get("stages", [])
	var after_stage: Dictionary = after_stages[5] if after_stages.size() > 5 else {}
	var after_receipt: Dictionary = after_stage.get("receipt", {})
	assert_eq(str(after_receipt.get("receipt_id", "")), str(expected_identity["child_id"]),
		"a completed stage's receipt_id equals its re-derived stage_identity child_id")
	assert_eq(after_receipt.get("receipt_provenance", {}), expected_identity,
		"and its receipt_provenance is byte-equal to the re-derived provenance")
	var expected_resolution_after := _child_provenance(mapped_parent, "hospital_resolution", 0,
		[_p("source_day", 3)])
	assert_eq(str(after_receipt.get("resolution_receipt_id", "")),
		str(expected_resolution_after["child_id"]),
		"a completed stage receipt names the RE-DERIVED resolution receipt, never the old one")
	_assert_hospital_mutants_reject(before_snapshot, bundle, "r32a-before")
	_assert_hospital_mutants_reject(after_snapshot, bundle, "r32a-after")


func test_prepare_keeps_accepted_sources_in_their_frozen_order_after_rederivation() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r32"), "board_start", 0, [])
	# Deliberately NOT in lexical order: the miss ordinal derives from the frozen creation order, so
	# a re-sort after re-derivation silently renumbers every hospital_miss child.
	var frozen_order: Array = [
		{"action_id": "solo:sylvia:day3", "receipt_id": "src-sylvia"},
		{"action_id": "group:priscilla_lavinia:day3", "receipt_id": "src-group"},
		{"action_id": "solo:priscilla:day3", "receipt_id": "src-priscilla"},
	]
	var plan := _condition_hospital_plan(2, "pending", {"accepted_sources": frozen_order})
	var snapshot := _v5_snapshot("old-tx-r32", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r32": "new-tx-r32", "old-hospital-tx": "new-hospital-tx"})
	var first_source: Dictionary = frozen_order[0]
	assert_eq(str(first_source["action_id"]), "solo:sylvia:day3",
		"the fixture order really is not the lexical one")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r32", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped_plan: Dictionary = lifecycle.get("active_condition_hospital_plan", {})
	assert_eq(remapped_plan.get("accepted_sources", []), frozen_order,
		"accepted_sources is NOT re-sorted after re-derivation")
	var record: Dictionary = remapped_plan.get("destination_record", {})
	var payload: Dictionary = record.get("payload", {})
	assert_eq(payload.get("accepted_unfulfilled_sources", []), frozen_order,
		"the destination record's accepted-source binding keeps the same frozen order")
	_assert_hospital_mutants_reject(snapshot, bundle, "r32")


func test_prepare_follows_the_post_advance_rule_at_cursor_six_before_and_after_the_retirement_checkpoint() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r33a"), "board_start", 0, [])
	# BEFORE the retirement checkpoint: the completed plan is still in the ACTIVE slot and follows
	# the post-advance rule -- historical identity, split legal, never rewritten.
	var complete := _condition_hospital_plan(6, "completed",
		{"causal_day_instance": "causal-day-ancestor"})
	var before_snapshot := _v5_snapshot("old-tx-r33a", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": complete}})
	var before_bundle := _multi_bundle({
		"old-tx-r33a": "new-tx-r33a", "old-hospital-tx": "new-hospital-tx",
	})
	assert_eq(int(complete["cursor"]), 6, "a complete plan has cursor 6 and six completed stages")
	var before_result: Dictionary = _remapper().call("prepare", before_snapshot,
		"restore-txn-r33a-before", before_bundle)
	assert_true(before_result.get("ok", false), JSON.stringify(before_result))
	var before_lifecycle := _prepared_lifecycle(before_result)
	var before_plan: Dictionary = before_lifecycle.get("active_condition_hospital_plan", {})
	assert_eq(str(before_plan.get("causal_day_instance", "")), "causal-day-ancestor",
		"cursor 6 before retirement still follows the post-advance rule")
	_assert_hospital_mutants_reject(before_snapshot, before_bundle, "r33a-before")

	# AFTER the retirement checkpoint: the record is immutable history and is not rewindable at all.
	var retired := _condition_hospital_plan(6, "completed", {
		"transaction_id": "old-history-tx", "causal_day_instance": "causal-day-ancestor",
	})
	var history := _history_record(retired)
	var history_key := str(history.keys()[0])
	var after_snapshot := _v5_snapshot("old-tx-r33a", source_commit,
		{"lifecycle": {"condition_hospital_history": history}})
	var after_bundle := _bundle("old-tx-r33a", "new-tx-r33a")
	var frozen_history := history.duplicate(true)
	var after_result: Dictionary = _remapper().call("prepare", after_snapshot,
		"restore-txn-r33a-after", after_bundle)
	assert_true(after_result.get("ok", false), JSON.stringify(after_result))
	var after_lifecycle := _prepared_lifecycle(after_result)
	assert_eq(after_lifecycle.get("condition_hospital_history", {}), frozen_history,
		"after the retirement checkpoint the record is immutable history")
	_assert_history_mutants_reject(after_snapshot, after_bundle, history_key, "r33a-after")


func test_prepare_rejects_an_abandoned_future_stage_receipt() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r33"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	var stages: Array = plan["stages"]
	var completed_stage: Dictionary = stages[1]
	var future_stage: Dictionary = stages[4]
	# A receipt left behind on a stage the cursor has not reached: an abandoned future receipt.
	future_stage["receipt"] = (completed_stage["receipt"] as Dictionary).duplicate(true)
	assert_eq(str(future_stage["state"]), "pending",
		"the fixture keeps the stage pending while planting a receipt on it")
	var snapshot := _v5_snapshot("old-tx-r33", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r33": "new-tx-r33", "old-hospital-tx": "new-hospital-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r33", bundle)
	_assert_refuses_with(result, &"remap_abandoned_future_receipt",
		"R33 a receipt on a stage the cursor has not reached")

	var clean := _condition_hospital_plan(2, "pending")
	var clean_snapshot := _v5_snapshot("old-tx-r33", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": clean}})
	_assert_hospital_mutants_reject(clean_snapshot, bundle, "r33")


func test_prepare_leaves_condition_hospital_history_byte_identical() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r34"), "board_start", 0, [])
	var retired := _condition_hospital_plan(6, "completed", {
		"transaction_id": "old-history-tx", "causal_day_instance": "causal-day-ancestor",
	})
	var history := _history_record(retired)
	var history_key := str(history.keys()[0])
	var frozen_history := history.duplicate(true)
	var snapshot := _v5_snapshot("old-tx-r34", source_commit,
		{"lifecycle": {"condition_hospital_history": history}})
	var bundle := _bundle("old-tx-r34", "new-tx-r34")
	var retirement: Dictionary = (frozen_history[history_key] as Dictionary)["retirement_receipt"]
	assert_eq(str(retirement["resolution_receipt_id"]), history_key,
		"the retirement receipt's resolution_receipt_id is the map key")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r34", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	assert_eq(lifecycle.get("condition_hospital_history", {}), frozen_history,
		"condition_hospital_history is duplicated, never remapped, and compares == to its source")
	_assert_history_mutants_reject(snapshot, bundle, history_key, "r34")
	# RULING T4-AD item 13: the token law ALONE. The mixed receipt also moves the plan's digest, so
	# the sha law above masks it; recomputing completed_plan_sha256 over the mutated plan satisfies
	# the sha law and leaves the issuer-token law as the only refusal.
	var token_only := snapshot.duplicate(true)
	var token_lifecycle: Dictionary = token_only["lifecycle"]
	var token_history: Dictionary = token_lifecycle["condition_hospital_history"]
	var token_entry: Dictionary = token_history[history_key]
	var token_plan: Dictionary = token_entry["completed_plan"]
	token_plan["transaction_issuer_receipt"] = _transaction_receipt("new-hospital-tx")
	var token_retirement: Dictionary = token_entry["retirement_receipt"]
	token_retirement["completed_plan_sha256"] = _sha256(token_plan)
	var token_result: Dictionary = _remapper().call("prepare", token_only, "restore-txn-r34", bundle)
	_assert_refuses_with(token_result, &"remap_history_mutated",
		"R34 a history plan whose issuer receipt token is not its own transaction_id, with a lawful digest")


# ---- outbox and terminal handoff (R35-R37) ----

func test_prepare_requires_the_live_outbox_to_match_the_remapped_destination_record() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r35"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	var snapshot := _v5_snapshot("old-tx-r35", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var consequence: Dictionary = snapshot["desktop"]["consequence"]
	var record: Dictionary = plan["destination_record"]
	var payload: Dictionary = record["payload"]
	consequence["outbox"] = {"hospital": _outbox_entry("hospital", payload, "pending")}
	var bundle := _multi_bundle({"old-tx-r35": "new-tx-r35", "old-hospital-tx": "new-hospital-tx"})
	assert_eq(str(record["status"]), "pending",
		"unpublished is expressed over status, never a published boolean (D-8)")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r35", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped_plan: Dictionary = lifecycle.get("active_condition_hospital_plan", {})
	var remapped_record: Dictionary = remapped_plan.get("destination_record", {})
	var remapped_consequence := _prepared_consequence(result)
	var remapped_outbox: Dictionary = remapped_consequence.get("outbox", {})
	var live: Dictionary = remapped_outbox.get("hospital", {})
	for shared: String in ["key", "payload_hash", "provenance", "consumer"]:
		assert_eq(live.get(shared), remapped_record.get(shared),
			"the live outbox and the remapped destination record agree on " + shared)
	assert_eq(str(live.get("status", "")), str(remapped_record.get("status", "")),
		"byte-equal, or differing only by the publication bit")

	var drifted := snapshot.duplicate(true)
	var drifted_consequence: Dictionary = drifted["desktop"]["consequence"]
	var drifted_outbox: Dictionary = drifted_consequence["outbox"]
	var drifted_entry: Dictionary = drifted_outbox["hospital"]
	drifted_entry["payload_hash"] = "0".repeat(64)
	var drifted_result: Dictionary = _remapper().call("prepare", drifted, "restore-txn-r35", bundle)
	_assert_refuses_with(drifted_result, &"remap_outbox_mismatch",
		"R35 a live outbox that is neither byte-equal nor a single publication bit apart")


func test_prepare_rejects_a_publication_bit_flip_without_a_remapped_acceptance() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r36"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	var snapshot := _v5_snapshot("old-tx-r36", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var consequence: Dictionary = snapshot["desktop"]["consequence"]
	var record: Dictionary = plan["destination_record"]
	var payload: Dictionary = record["payload"]
	# The publication bit is flipped on the live side while the plan's own record stays pending and
	# no delivery-ledger acceptance proves the transition.
	consequence["outbox"] = {"hospital": _outbox_entry("hospital", payload, "published")}
	var bundle := _multi_bundle({"old-tx-r36": "new-tx-r36", "old-hospital-tx": "new-hospital-tx"})
	assert_eq(str(record["status"]), "pending",
		"the fixture differs from the live entry by exactly the publication bit")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r36", bundle)
	_assert_refuses_with(result, &"remap_acceptance_missing",
		"R36 a publication bit flip needs the remapped delivery-ledger acceptance to prove it")


func test_prepare_remaps_a_nonnull_terminal_intent_handoff_root_intent_and_outbox_together() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r37"), "board_start", 0, [])
	var handoff := _terminal_handoff("old-terminal-tx")
	var snapshot := _v5_snapshot("old-tx-r37", source_commit, {
		"lifecycle": {"day": 7, "state": "TERMINAL_PENDING", "terminal_intent_handoff": handoff},
	})
	var consequence: Dictionary = snapshot["desktop"]["consequence"]
	consequence["pending"] = null
	var bundle := _multi_bundle({
		"old-tx-r37": "new-tx-r37", "old-terminal-tx": "new-terminal-tx",
	})
	assert_eq(str(handoff["status"]), "pending_oyo6", "the handoff status is the exact literal")

	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r37", bundle)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var lifecycle := _prepared_lifecycle(result)
	var remapped: Dictionary = lifecycle.get("terminal_intent_handoff", {})
	assert_eq(str(remapped.get("source_transaction_id", "")), "new-terminal-tx",
		"the handoff root is remapped")
	var remapped_receipt: Dictionary = remapped.get("source_transaction_issuer_receipt", {})
	assert_eq(str(remapped_receipt.get("token", "")), "new-terminal-tx",
		"root and receipt move together")
	var remapped_record: Dictionary = remapped.get("destination_outbox_record", {})
	assert_eq(remapped_record.get("payload", {}), remapped.get("terminal_intent", {}),
		"the outbox record's payload stays byte-equal to the intent it delivers")
	assert_eq(str(remapped_record.get("payload_hash", "")),
		_sha256(remapped.get("terminal_intent", {})),
		"the record's payload_hash is recomputed from the remapped intent")
	assert_eq(str(remapped_record.get("status", "")), "pending", "the record stays unpublished")
	assert_eq(int(remapped.get("schema_version", 0)), 1, "the handoff schema version is exactly 1")
	assert_false(remapped.has("checkpoint_id"),
		"the handoff is receipt-free: no checkpoint id, receipt or receipt-derived hash")

	var divergent := snapshot.duplicate(true)
	var divergent_lifecycle: Dictionary = divergent["lifecycle"]
	var divergent_handoff: Dictionary = divergent_lifecycle["terminal_intent_handoff"]
	var divergent_record: Dictionary = divergent_handoff["destination_outbox_record"]
	divergent_record["payload"] = {"kind": "day7_terminal", "day": 7, "variant": "condition"}
	var divergent_result: Dictionary = _remapper().call("prepare", divergent, "restore-txn-r37",
		bundle)
	_assert_refuses_with(divergent_result, &"remap_terminal_handoff_invalid",
		"R37 the outbox payload must stay byte-equal to the intent")


# ---- validate_remap, provenance and purity (R38-R43) ----

func test_validate_remap_accepts_its_own_v5_prepare_output() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r38"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var snapshot := _v5_snapshot("old-tx-r38", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r38": "new-tx-r38", "old-warning-tx": "new-warning-tx"})
	var prepared: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r38", bundle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var candidate := _prepared_snapshot(prepared)
	var validated: Dictionary = _remapper().call("validate_remap", snapshot, candidate)
	assert_true(validated.get("ok", false),
		"validate_remap must derive the C1-C5 pairs from the candidate's own v5 regions and harvest "
			+ "the real remapped receipts, not the {} shortcut: " + JSON.stringify(validated))


func test_validate_remap_rejects_a_v5_candidate_with_a_hand_edited_fingerprint() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r39"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var snapshot := _v5_snapshot("old-tx-r39", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r39": "new-tx-r39", "old-warning-tx": "new-warning-tx"})
	var prepared: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r39", bundle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var tampered := _prepared_snapshot(prepared).duplicate(true)
	var tampered_view: Dictionary = tampered.get("schedule_view", {})
	var tampered_pending: Dictionary = tampered_view.get("pending_warning", {})
	tampered_pending["warning_state_fingerprint"] = "9".repeat(64)
	var validated: Dictionary = _remapper().call("validate_remap", snapshot, tampered)
	_assert_refuses_with(validated, &"remap_not_reproducible",
		"R39 a hand-edited fingerprint cannot be reproduced from the source")


func test_validate_remap_rejects_a_v5_candidate_with_a_stale_consumed_key() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r40"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var activation := _pending_warning("accepted_date", view, context, "old-consumed-open-tx")
	var consumed := _terminal_receipt(activation, "dismissed", "old-consumed-tx")
	var old_digest := str(activation["warning_state_fingerprint"])
	view["consumed_warning_receipts"] = {_consumed_key(old_digest, "accepted_date"): consumed}
	var snapshot := _v5_snapshot("old-tx-r40", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r40": "new-tx-r40", "old-consumed-tx": "new-consumed-tx"})
	var prepared: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r40", bundle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var stale := _prepared_snapshot(prepared).duplicate(true)
	var stale_view: Dictionary = stale.get("schedule_view", {})
	var stale_map: Dictionary = stale_view.get("consumed_warning_receipts", {})
	for key: Variant in stale_map.keys():
		var record: Variant = stale_map[key]
		stale_map.erase(key)
		stale_map[_consumed_key(old_digest, "accepted_date")] = record
	var validated: Dictionary = _remapper().call("validate_remap", snapshot, stale)
	_assert_refuses_with(validated, &"remap_warning_key_stale",
		"R40 a candidate carrying the pre-remap consumed key silently suppresses a live warning")


func test_prepare_v5_source_ids_change_the_continuation_operation_remap_receipt() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r41"), "board_start", 0, [])
	var v4_snapshot := _snapshot("old-tx-r41", source_commit)
	var v4_bundle := _bundle("old-tx-r41", "new-tx-r41")
	var v4_result: Dictionary = _remapper().call("prepare", v4_snapshot, "restore-txn-r41",
		v4_bundle)
	assert_true(v4_result.get("ok", false), JSON.stringify(v4_result))
	var v4_value: Dictionary = v4_result.get("value", {})
	var v4_provenance: Dictionary = v4_value.get("remap_receipt_provenance", {})
	assert_eq(v4_provenance.get("source_ids", []), ["old-tx-r41"],
		"the v4 mapping carries exactly one key")

	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var v5_snapshot := _v5_snapshot("old-tx-r41", source_commit, {"schedule_view": view})
	var v5_bundle := _multi_bundle({"old-tx-r41": "new-tx-r41", "old-warning-tx": "new-warning-tx"})
	var v5_result: Dictionary = _remapper().call("prepare", v5_snapshot, "restore-txn-r41",
		v5_bundle)
	assert_true(v5_result.get("ok", false), JSON.stringify(v5_result))
	var v5_value: Dictionary = v5_result.get("value", {})
	var v5_provenance: Dictionary = v5_value.get("remap_receipt_provenance", {})
	assert_eq(v5_provenance.get("source_ids", []), ["old-tx-r41", "old-warning-tx"],
		"C1-C5 enlarge transaction_remap, so the continuation_operation child's source_ids grow")
	assert_ne(str(v5_value.get("remap_receipt_id", "")), str(v4_value.get("remap_receipt_id", "")),
		"the same board state yields a different remap receipt once the v5 roots join the mapping "
			+ "-- that is the whole binding, and no new field is needed to express it")


func test_prepare_is_a_pure_function_of_a_v5_snapshot() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r42"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	view["pending_warning"] = _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	var plan := _condition_hospital_plan(2, "pending")
	var snapshot := _v5_snapshot("old-tx-r42", source_commit, {
		"schedule_view": view, "lifecycle": {"active_condition_hospital_plan": plan},
	})
	var bundle := _multi_bundle({
		"old-tx-r42": "new-tx-r42", "old-warning-tx": "new-warning-tx",
		"old-hospital-tx": "new-hospital-tx",
	})
	var frozen := snapshot.duplicate(true)
	var first: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r42", bundle)
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(snapshot, frozen, "prepare() never mutates its v5 snapshot argument")
	var second: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r42", bundle)
	assert_eq(_prepared_snapshot(second), _prepared_snapshot(first),
		"a second call over the same two inputs reproduces the same bytes")


func test_prepare_rejects_a_dangling_v5_transaction_reference() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r43"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	var action_receipt: Dictionary = plan["action_receipt"]
	action_receipt["transaction_id"] = "old-hospital-orphan"
	action_receipt["transaction_issuer_receipt"] = _transaction_receipt("old-hospital-orphan")
	var snapshot := _v5_snapshot("old-tx-r43", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r43": "new-tx-r43", "old-hospital-tx": "new-hospital-tx"})
	var remap: Dictionary = bundle["transaction_remap"]
	assert_false(remap.has("old-hospital-orphan"),
		"the orphan is referenced by the plan but is not a collected root, so nothing maps it")
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r43", bundle)
	_assert_refuses_with(result, &"remap_dangling_transaction",
		"R43 a v5 reference with no remap entry fails closed, exactly as the v4 recovery-payload "
			+ "reference already does")

# ---- R44-R47: RULING T4-AD pins ----

func test_prepare_rejects_a_string_edited_terminal_receipt_provenance() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r44"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var activation := _pending_warning("unread_invitation", view, context, "old-consumed-open-tx")
	var consumed := _terminal_receipt(activation, "navigation_committed", "old-consumed-tx",
		"open_messages")
	var provenance: Dictionary = consumed["receipt_provenance"]
	var source_ids: Array = provenance["source_ids"]
	source_ids[0] = str(source_ids[0]) + "-hand-edited"
	assert_eq(source_ids.size(), 3, "the fixture keeps the projection triple; only its bytes were edited")
	view["consumed_warning_receipts"] = {
		_consumed_key(str(activation["warning_state_fingerprint"]), "unread_invitation"): consumed,
	}
	var snapshot := _v5_snapshot("old-tx-r44", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({"old-tx-r44": "new-tx-r44", "old-consumed-tx": "new-consumed-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r44", bundle)
	_assert_refuses_with(result, &"remap_child_id_mismatch",
		"R44 a terminal receipt's stored provenance is rebuilt from facts, never repaired by editing its string")


func test_validate_remap_accepts_a_v5_candidate_with_attempt_and_consumed_roots() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r45"), "board_start", 0, [])
	var context := _warning_context("branch-old", 0, OLD_CAUSAL)
	var view := _v5_view(3, OLD_CAUSAL)
	var pending := _pending_warning("base_minesweeper", view, context, "old-warning-tx")
	pending["attempt_receipts"] = {
		"old-attempt-tx": _terminal_receipt(pending, "navigation_failed", "old-attempt-tx",
			"hospital"),
	}
	var consumed_activation := _pending_warning("accepted_date", view, context,
		"old-consumed-open-tx")
	var consumed := _terminal_receipt(consumed_activation, "dismissed", "old-consumed-tx")
	view["pending_warning"] = pending
	view["consumed_warning_receipts"] = {
		_consumed_key(str(consumed_activation["warning_state_fingerprint"]), "accepted_date"):
			consumed,
	}
	var snapshot := _v5_snapshot("old-tx-r45", source_commit, {"schedule_view": view})
	var bundle := _multi_bundle({
		"old-tx-r45": "new-tx-r45", "old-warning-tx": "new-warning-tx",
		"old-attempt-tx": "new-attempt-tx", "old-consumed-tx": "new-consumed-tx",
	})
	var prepared: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r45", bundle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var validated: Dictionary = _remapper().call("validate_remap", snapshot, _prepared_snapshot(prepared))
	assert_true(validated.get("ok", false),
		"validate_remap must pair the attempt and consumed roots from the candidate's own terminal "
			+ "family and harvest their receipts: " + JSON.stringify(validated))


func test_prepare_refuses_an_active_plan_beside_a_lifecycle_missing_its_identity_receipt() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r46"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	var snapshot := _v5_snapshot("old-tx-r46", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var lifecycle: Dictionary = snapshot["lifecycle"]
	lifecycle.erase("causal_day_instance_issuer_receipt")
	var bundle := _multi_bundle({"old-tx-r46": "new-tx-r46", "old-hospital-tx": "new-hospital-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r46", bundle)
	_assert_refuses_with(result, &"remap_condition_hospital_plan_invalid",
		"R46 an unsplit plan can only move together with a lifecycle that carries all four identity members")


func test_prepare_rejects_an_unsplit_plan_whose_issuer_receipt_disagrees_with_the_lifecycle() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r47"), "board_start", 0, [])
	var plan := _condition_hospital_plan(2, "pending")
	plan["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal_day_instance", "causal-day-other")
	assert_eq(str(plan["causal_day_instance"]), OLD_CAUSAL,
		"the fixture disagrees ONLY on the fifth member, the issuer receipt")
	var snapshot := _v5_snapshot("old-tx-r47", source_commit,
		{"lifecycle": {"active_condition_hospital_plan": plan}})
	var bundle := _multi_bundle({"old-tx-r47": "new-tx-r47", "old-hospital-tx": "new-hospital-tx"})
	var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r47", bundle)
	_assert_refuses_with(result, &"remap_condition_hospital_identity_split_invalid",
		"R47 the unsplit law compares all five members RunLifecycle compares, the issuer receipt included")

func test_prepare_rejects_an_unsplit_plan_whose_branch_or_run_disagrees_with_the_lifecycle() -> void:
	if not _exists(): return
	var source_commit := _child_provenance(_transaction_receipt("old-tx-r48"), "board_start", 0, [])
	var bundle := _multi_bundle({"old-tx-r48": "new-tx-r48", "old-hospital-tx": "new-hospital-tx"})
	# Each of the three non-causal members disagrees ALONE, so the receipt law (R47) cannot mask the
	# four-member equality law: the causal day and its issuer receipt stay the lifecycle's own.
	for field: String in ["branch_id", "desktop_timeline_generation", "run_id"]:
		var plan := _condition_hospital_plan(2, "pending")
		plan[field] = 9 if field == "desktop_timeline_generation" else "disagreeing-value"
		assert_eq(str(plan["causal_day_instance"]), OLD_CAUSAL,
			"the fixture disagrees only on " + field)
		var snapshot := _v5_snapshot("old-tx-r48", source_commit,
			{"lifecycle": {"active_condition_hospital_plan": plan}})
		var result: Dictionary = _remapper().call("prepare", snapshot, "restore-txn-r48", bundle)
		_assert_refuses_with(result, &"remap_condition_hospital_identity_split_invalid",
			"R48 an unsplit plan whose " + field + " is not the lifecycle's own")
