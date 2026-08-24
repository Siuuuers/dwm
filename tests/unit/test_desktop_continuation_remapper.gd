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
