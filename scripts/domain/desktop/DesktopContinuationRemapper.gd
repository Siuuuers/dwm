class_name DesktopContinuationRemapper
extends RefCounted

## Selected-Load snapshot identity remapper (Plan 02 Task 6, dwm-p2r.32, req.desktop
## .cross_app_actions), amendment plan lines 287-291.
##
## TABLE-DRIVEN SCOPE, resolving the brief's "current-causal-day base-completion and Supportz
## records" clause (controller ruling, bead addendum 9). Amendment SS8.3 places them in Task 7 -- a
## per-branch Supportz purchase count, a per-causal-day purchase flag, and base-completion receipts
## that MinesweeperCapabilityRules.supportz_eligible() consumes -- and Task 7 has since landed them
## on DesktopConsequenceState as the single `shop_ledger` member (see that file's own class doc).
## _REMAP_TABLE's `shop_ledger` row is `handled: true`: none of its three members is a transaction id
## or an anchored child provenance (a purchase count and opaque historical causal_day_instance
## tokens), so _remap_consequence()'s existing duplicate(true) already carries it forward correctly.
##
## Every row this remapper actually HANDLES operates on a member RunSnapshotSchema v4 already
## declares (DesktopBoardState._CAPTURE_KEYS / DesktopConsequenceState's own _STATE_KEYS/
## _PENDING_KEYS/outbox union). Two categories are explicitly DEFERRED rather than guessed at, each
## with its row's own `reason`:
##  - admission_checkpoint_receipt/checkpoint_receipt are content-hash-immutable records anchored to
##    a historical `SaveManagerCheckpointPort.commit_consequence_checkpoint()` preimage; remapping
##    their bytes would require rewriting the on-disk consequence-checkpoint document they describe,
##    which is outside a pure in-memory snapshot remap.
##  - destination_intent/notification_intent/outbox provenance-consumer members have no frozen
##    internal shape anywhere in this codebase today, so this remapper does not guess at their
##    contents; it leaves them exactly as captured.
##
## PURITY. No live issuer/root object is called: `derive_child()`'s preimage law (plan line 537,
## mirrored from DesktopIdentityNonceIssuer._child_id -- that file's frozen public surface forbids
## adding a shared static, so the pure formula is duplicated here rather than imported) only needs
## the NEW parent receipt's namespace/counter/receipt_id, which `identity_allocation_bundle` already
## carries. Every remap here is therefore a deterministic function of its two inputs.

const _IDENTITY := preload("res://scripts/domain/desktop/DesktopIdentity.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const CHILD_SCHEMA_VERSION := 1
const _PROVENANCE_KEYS: Array[String] = ["child_id", "child_kind", "ordinal", "parent_receipt_id", "schema_version", "source_ids"]

## Duplicated from DesktopIdentityNonceIssuer.CHILD_KINDS (plan line 537) for the SAME reason
## `_child_id()` below duplicates that file's preimage formula rather than importing it: this is
## domain layer and must not depend on the application-layer issuer. Kept byte-for-byte identical
## by `test_the_remappers_duplicated_child_kinds_equal_the_real_issuers_child_kinds_exactly` in
## tests/unit/test_desktop_continuation_remapper.gd, which loads the REAL issuer and compares this
## list against its own CHILD_KINDS member-for-member, in order.
const _CHILD_KINDS: Array[String] = [
	"schedule_entry", "schedule_commit", "day7_schedule_provenance", "empty_schedule_done",
	"contact_source", "hospital_resolution", "hospital_miss", "sylvia_hospital_witness",
	"day_resolution_stage", "board_command", "board_start", "shop_quote", "desktop_action",
	"causal_sequence", "condition", "board_fate", "destination_intent", "notification_intent",
	"continuation_operation", "warning", "navigation", "terminal_intent", "action_consequence",
]

## Registration seam (bead addendum 9). `handled=true` rows are implemented in `_remap_board()`/
## `_remap_consequence()` below; `handled=false` rows are deliberately deferred, with `reason`
## explaining why, per the scoping above.
const _REMAP_TABLE: Array[Dictionary] = [
	{"path": "desktop.board.identity", "handled": true},
	{"path": "desktop.board.command_receipts", "handled": true},
	{"path": "desktop.board.terminal_receipts", "handled": true},
	{"path": "desktop.consequence.causal_day_instance+receipt", "handled": true},
	{"path": "desktop.consequence.pending.transaction_id+receipt", "handled": true},
	{"path": "desktop.consequence.pending.source_commit_receipt_id+provenance", "handled": true},
	{"path": "desktop.consequence.pending.recovery_payload", "handled": true},
	{"path": "desktop.consequence.pending.admission_checkpoint_receipt", "handled": false,
		"reason": "content-hash-immutable; remapping requires rewriting the on-disk consequence checkpoint document"},
	{"path": "desktop.consequence.pending.checkpoint_receipt", "handled": false,
		"reason": "see admission_checkpoint_receipt"},
	{"path": "desktop.consequence.pending.destination_intent", "handled": false,
		"reason": "no frozen member shape exists yet"},
	{"path": "desktop.consequence.pending.notification_intent", "handled": false,
		"reason": "no frozen member shape exists yet"},
	{"path": "desktop.consequence.outbox.*.provenance/consumer", "handled": false,
		"reason": "no frozen member shape exists yet"},
	{"path": "desktop.consequence.shop_ledger", "handled": true},
]


## Every root transaction id this snapshot's rewindable (board command/terminal ledger, and the
## one live consequence pending transaction, if any) structures currently reference. Sorted, unique.
static func collect_rewindable_transaction_ids(snapshot: Dictionary) -> Dictionary:
	var desktop_check := _require_desktop(snapshot)
	if not desktop_check.get("ok", false):
		return desktop_check
	var desktop: Dictionary = desktop_check["value"]
	var board: Dictionary = desktop["board"]
	var consequence: Dictionary = desktop["consequence"]
	var ids: Dictionary = {}
	for key: String in ["command_receipts", "terminal_receipts"]:
		var receipts: Variant = board.get(key, {})
		if typeof(receipts) == TYPE_DICTIONARY:
			for transaction_id: Variant in (receipts as Dictionary).keys():
				ids[str(transaction_id)] = true
	var pending: Variant = consequence.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var transaction_id: Variant = (pending as Dictionary).get("transaction_id")
		if typeof(transaction_id) == TYPE_STRING and not str(transaction_id).strip_edges().is_empty():
			ids[str(transaction_id)] = true
	var sorted_ids: Array = ids.keys()
	sorted_ids.sort()
	return {"ok": true, "code": &"ok", "value": {"transaction_ids": sorted_ids}, "receipt": {}}


## `identity_allocation_bundle` here is the RAW continuation-allocation bundle (brief lines
## 259-283: transaction_id/transaction_issuer_receipt/branch_id/desktop_timeline_generation/
## causal_day_instance/causal_day_instance_issuer_receipt/transaction_remap), NOT yet enriched with
## the remap_receipt_id/remap_receipt_provenance this method itself produces --
## DesktopIdentityAllocationRestoreParticipant merges this method's receipt onto that bundle before
## handing the ENRICHED bundle to RunLifecycle.prepare_continuation_remap() and the consequence/
## board participants.
static func prepare(snapshot: Dictionary, restore_transaction_id: String,
		identity_allocation_bundle: Dictionary) -> Dictionary:
	if restore_transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_restore_transaction_id", "restore_transaction_id must be nonblank", {})
	var bundle_check := _require_bundle_keys(identity_allocation_bundle)
	if not bundle_check.get("ok", false):
		return bundle_check
	var desktop_check := _require_desktop(snapshot)
	if not desktop_check.get("ok", false):
		return desktop_check
	var desktop: Dictionary = desktop_check["value"]

	var transaction_remap: Dictionary = identity_allocation_bundle["transaction_remap"]
	var remap_check := _validate_transaction_remap_matches_snapshot(snapshot, transaction_remap)
	if not remap_check.get("ok", false):
		return remap_check

	var board_result := _remap_board(desktop["board"], identity_allocation_bundle, transaction_remap)
	if not board_result.get("ok", false):
		return board_result
	var consequence_result := _remap_consequence(desktop["consequence"], identity_allocation_bundle, transaction_remap)
	if not consequence_result.get("ok", false):
		return consequence_result

	var remapped_snapshot: Dictionary = snapshot.duplicate(true)
	var remapped_desktop: Dictionary = desktop.duplicate(true)
	remapped_desktop["board"] = board_result["value"]
	remapped_desktop["consequence"] = consequence_result["value"]
	remapped_snapshot["desktop"] = remapped_desktop

	var source_ids: Array = transaction_remap.keys()
	source_ids.sort()
	var parent_receipt: Dictionary = identity_allocation_bundle["transaction_issuer_receipt"]
	var remap_receipt_id_check := _child_id(parent_receipt, "continuation_operation", 0, source_ids)
	if not remap_receipt_id_check.get("ok", false):
		return remap_receipt_id_check
	var remap_receipt_id: String = remap_receipt_id_check["value"]
	var remap_receipt_provenance := {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")),
		"child_kind": "continuation_operation",
		"ordinal": 0,
		"source_ids": source_ids,
		"child_id": remap_receipt_id,
	}
	return {"ok": true, "code": &"ok", "value": {
		"snapshot": remapped_snapshot,
		"remap_receipt_id": remap_receipt_id,
		"remap_receipt_provenance": remap_receipt_provenance,
	}, "receipt": remap_receipt_provenance.duplicate(true)}


## Independent second opinion: re-derives the implied transaction map purely by diffing `source`
## against `candidate` (board command/terminal receipt key correspondence by insertion order, plus
## the consequence pending transaction_id if present), requires that implied map to be internally
## consistent (no missing/extra/multiply-mapped/dangling/unsorted-set entries), then rebuilds an
## equivalent raw bundle from those facts and requires `prepare()` against it to reproduce `candidate`
## byte-for-byte.
static func validate_remap(source: Dictionary, candidate: Dictionary) -> Dictionary:
	var source_desktop_check := _require_desktop(source)
	if not source_desktop_check.get("ok", false):
		return source_desktop_check
	var candidate_desktop_check := _require_desktop(candidate)
	if not candidate_desktop_check.get("ok", false):
		return candidate_desktop_check
	var source_desktop: Dictionary = source_desktop_check["value"]
	var candidate_desktop: Dictionary = candidate_desktop_check["value"]

	var derived := _derive_transaction_map(source_desktop, candidate_desktop)
	if not derived.get("ok", false):
		return derived
	var transaction_remap: Dictionary = derived["value"]

	var source_identity: Dictionary = (source_desktop["board"] as Dictionary).get("identity", {})
	var candidate_identity: Dictionary = (candidate_desktop["board"] as Dictionary).get("identity", {})
	if typeof(source_identity) != TYPE_DICTIONARY or typeof(candidate_identity) != TYPE_DICTIONARY:
		return _fail(&"remap_identity_missing", "both source and candidate must carry a board identity to validate a remap", {})

	var candidate_consequence: Dictionary = candidate_desktop["consequence"]
	var pending: Variant = candidate_consequence.get("pending")
	var receipt_source: Dictionary = {}
	if typeof(pending) == TYPE_DICTIONARY and typeof((pending as Dictionary).get("transaction_issuer_receipt")) == TYPE_DICTIONARY:
		receipt_source = (pending as Dictionary)["transaction_issuer_receipt"]
	var rebuilt_bundle := {
		"transaction_id": str(receipt_source.get("token", "")),
		"transaction_issuer_receipt": receipt_source,
		"branch_id": str(candidate_identity.get("branch_id", "")),
		"desktop_timeline_generation": int(candidate_identity.get("desktop_timeline_generation", 0)),
		"causal_day_instance": str(candidate_consequence.get("causal_day_instance", "")),
		"causal_day_instance_issuer_receipt": candidate_consequence.get("causal_day_instance_issuer_receipt", {}),
		"transaction_remap": transaction_remap,
	}
	if receipt_source.is_empty():
		# No pending transaction survived into the candidate to anchor the remap receipt against
		# (e.g. the whole remap happened while nothing was mid-flight): fall back to any one of the
		# remapped board receipts as the anchor, matching the same "restore transaction" identity.
		for entry: Variant in transaction_remap.values():
			rebuilt_bundle["transaction_issuer_receipt"] = (entry as Dictionary).get("new_transaction_issuer_receipt", {})
			rebuilt_bundle["transaction_id"] = str((entry as Dictionary).get("new_transaction_id", ""))
			break
	var restore_transaction_id := str(rebuilt_bundle["transaction_id"])
	if restore_transaction_id.is_empty():
		return _fail(&"remap_unverifiable", "no transaction receipt is available to re-anchor the remap for validation", {})
	var reproduced := prepare(source, restore_transaction_id, rebuilt_bundle)
	if not reproduced.get("ok", false):
		return reproduced
	if (reproduced["value"] as Dictionary)["snapshot"] != candidate:
		return _fail(&"remap_not_reproducible", "the candidate is not a lawful remap of the source", {})
	return {"ok": true, "code": &"ok", "value": {"transaction_remap": transaction_remap}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# Board
# -------------------------------------------------------------------------------------------------

static func _remap_board(board: Dictionary, bundle: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var remapped: Dictionary = board.duplicate(true)
	var identity: Variant = board.get("identity")
	var new_identity: Dictionary = {}
	if typeof(identity) == TYPE_DICTIONARY and not (identity as Dictionary).is_empty():
		var remapped_identity := _IDENTITY.remap(identity, str(bundle["branch_id"]),
			int(bundle["desktop_timeline_generation"]), str(bundle["causal_day_instance"]))
		if not remapped_identity.get("ok", false):
			return remapped_identity
		new_identity = (remapped_identity["value"] as Dictionary)["identity"]
		remapped["identity"] = new_identity
	for key: String in ["command_receipts", "terminal_receipts"]:
		var receipts: Variant = board.get(key, {})
		if typeof(receipts) != TYPE_DICTIONARY:
			continue
		var rekeyed: Dictionary = {}
		for old_id: Variant in (receipts as Dictionary).keys():
			var record: Dictionary = (receipts[old_id] as Dictionary).duplicate(true)
			var mapping: Variant = transaction_remap.get(str(old_id))
			var new_id := str(old_id)
			if typeof(mapping) == TYPE_DICTIONARY:
				new_id = str((mapping as Dictionary)["new_transaction_id"])
			if record.has("identity_fingerprint") and not new_identity.is_empty():
				var fp := _IDENTITY.fingerprint(new_identity)
				if fp.get("ok", false):
					record["identity_fingerprint"] = str((fp["value"] as Dictionary)["fingerprint"])
			rekeyed[new_id] = record
		remapped[key] = rekeyed
	return {"ok": true, "code": &"ok", "value": remapped}


# -------------------------------------------------------------------------------------------------
# Consequence
# -------------------------------------------------------------------------------------------------

static func _remap_consequence(consequence: Dictionary, bundle: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var remapped: Dictionary = consequence.duplicate(true)
	remapped["causal_day_instance"] = str(bundle["causal_day_instance"])
	remapped["causal_day_instance_issuer_receipt"] = (bundle["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	var pending: Variant = consequence.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var remapped_pending := _remap_pending(pending as Dictionary, transaction_remap)
		if not remapped_pending.get("ok", false):
			return remapped_pending
		remapped["pending"] = remapped_pending["value"]
	# Task 7 (dwm-p2r.32.7) registration seam filled in: shop_ledger's three members are a plain
	# purchase count and opaque HISTORICAL causal_day_instance tokens (the branch's running Supportz
	# count and completion log; none is a transaction id or an anchored child provenance), so no
	# rewrite is needed beyond the duplicate() above -- unlike board/pending's rewindable transaction
	# references, remapping a NEW branch identity never changes what already happened on past days.
	return {"ok": true, "code": &"ok", "value": remapped}


static func _remap_pending(pending: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var remapped: Dictionary = pending.duplicate(true)
	var old_transaction_id := str(pending.get("transaction_id", ""))
	var mapping: Variant = transaction_remap.get(old_transaction_id)
	if typeof(mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction", "pending.transaction_id has no remap entry: " + old_transaction_id, {})
	var new_receipt: Dictionary = (mapping as Dictionary)["new_transaction_issuer_receipt"]
	remapped["transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
	remapped["transaction_issuer_receipt"] = (new_receipt as Dictionary).duplicate(true)

	var provenance: Variant = pending.get("source_commit_receipt_provenance")
	if typeof(provenance) == TYPE_DICTIONARY:
		var rederived := _rederive_anchored_child(provenance as Dictionary, new_receipt, transaction_remap)
		if not rederived.get("ok", false):
			return rederived
		remapped["source_commit_receipt_id"] = (rederived["value"] as Dictionary)["child_id"]
		remapped["source_commit_receipt_provenance"] = (rederived["value"] as Dictionary)["provenance"]

	var payload: Variant = pending.get("recovery_payload")
	if typeof(payload) == TYPE_DICTIONARY:
		var remapped_payload := _remap_recovery_payload(payload as Dictionary, transaction_remap)
		if not remapped_payload.get("ok", false):
			return remapped_payload
		remapped["recovery_payload"] = remapped_payload["value"]
		var hash := _canonical_sha256(remapped_payload["value"])
		if hash.is_empty():
			return _fail(&"remap_payload_not_canonicalizable", "the remapped recovery_payload is not canonically representable", {})
		remapped["recovery_payload_sha256"] = hash
	# admission_checkpoint_receipt / checkpoint_receipt: deliberately untouched (see _REMAP_TABLE).
	return {"ok": true, "code": &"ok", "value": remapped}


static func _remap_recovery_payload(payload: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var remapped: Dictionary = payload.duplicate(true)
	for embedded_key: String in ["action_receipt", "schedule_header"]:
		var embedded: Variant = payload.get(embedded_key)
		if typeof(embedded) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = (embedded as Dictionary).duplicate(true)
		var old_id := str(record.get("transaction_id", ""))
		var mapping: Variant = transaction_remap.get(old_id)
		if typeof(mapping) != TYPE_DICTIONARY:
			return _fail(&"remap_dangling_transaction",
				"recovery_payload.%s.transaction_id has no remap entry: %s" % [embedded_key, old_id], {})
		var new_receipt: Dictionary = (mapping as Dictionary)["new_transaction_issuer_receipt"]
		record["transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
		record["transaction_issuer_receipt"] = (new_receipt as Dictionary).duplicate(true)
		var provenance: Variant = record.get("source_commit_receipt_provenance")
		if typeof(provenance) == TYPE_DICTIONARY:
			var rederived := _rederive_anchored_child(provenance as Dictionary, new_receipt, transaction_remap)
			if not rederived.get("ok", false):
				return rederived
			record["source_commit_receipt_id"] = (rederived["value"] as Dictionary)["child_id"]
			record["source_commit_receipt_provenance"] = (rederived["value"] as Dictionary)["provenance"]
		remapped[embedded_key] = record
	return {"ok": true, "code": &"ok", "value": remapped}


## Re-derives an anchored-child id/provenance (plan line 537) under a NEW parent receipt, keeping
## the child's own kind/ordinal unchanged. Any source_ids member that is itself a real rewindable
## transaction ID is recursively remapped through `transaction_remap` (brief line 291: "recursively
## mapped/sorted source IDs") -- this branch's own GameStateDesktopBoardPort anchors its board_start
## children with source_ids=[transaction_id], a REAL transaction id, not an opaque hash, so passing
## every source_id through unchanged (the prior behavior here) silently staled that id past a
## restore. A source_id absent from transaction_remap is genuinely opaque (a content-derived hash
## with no remap entry) and passes through unchanged. The result is lexically re-sorted and
## revalidated non-blank/unique/sorted, matching derive_child()'s own precondition that source IDs
## arrive already sorted rather than being repaired by the issuer; a malformed historical record
## (unsorted, blank, or duplicated) rejects rather than being silently renormalized.
static func _rederive_anchored_child(provenance: Dictionary, new_parent_receipt: Dictionary,
		transaction_remap: Dictionary) -> Dictionary:
	var keys: Array = provenance.keys()
	keys.sort()
	var expected := _PROVENANCE_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _fail(&"remap_provenance_invalid", "unexpected provenance keys: " + str(keys), {})
	var child_kind := str(provenance["child_kind"])
	if not _CHILD_KINDS.has(child_kind):
		return _fail(&"remap_child_kind_unregistered", child_kind, {})
	var ordinal := int(provenance["ordinal"])
	var source_ids_check := _validate_sorted_unique_nonblank(provenance["source_ids"])
	if not source_ids_check.get("ok", false):
		return source_ids_check
	var source_ids: Array = source_ids_check["value"]

	var mapped_source_ids: Array = []
	for source_id: Variant in source_ids:
		var key := str(source_id)
		var mapping: Variant = transaction_remap.get(key)
		if typeof(mapping) == TYPE_DICTIONARY:
			mapped_source_ids.append(str((mapping as Dictionary)["new_transaction_id"]))
		else:
			mapped_source_ids.append(key)
	mapped_source_ids.sort()
	var mapped_check := _validate_sorted_unique_nonblank(mapped_source_ids)
	if not mapped_check.get("ok", false):
		return mapped_check

	var new_child_id_check := _child_id(new_parent_receipt, child_kind, ordinal, mapped_source_ids)
	if not new_child_id_check.get("ok", false):
		return new_child_id_check
	var new_child_id: String = new_child_id_check["value"]
	var new_provenance := {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(new_parent_receipt.get("receipt_id", "")),
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": mapped_source_ids,
		"child_id": new_child_id,
	}
	return {"ok": true, "code": &"ok", "value": {"child_id": new_child_id, "provenance": new_provenance}}


## Shared precondition/postcondition check mirroring derive_child()'s own law (plan line 487):
## source IDs must already be sorted, unique, and nonblank -- callers (and, here, historical
## persisted records) may not submit an unsorted or duplicated set for silent repair.
static func _validate_sorted_unique_nonblank(source_ids: Variant) -> Dictionary:
	if typeof(source_ids) != TYPE_ARRAY:
		return _fail(&"remap_source_ids_invalid", "source_ids must be an array", {})
	var ids: Array = (source_ids as Array).duplicate(true)
	var seen: Dictionary = {}
	var previous := ""
	for index: int in range(ids.size()):
		var value := str(ids[index])
		if value.strip_edges().is_empty():
			return _fail(&"remap_source_ids_invalid", "source_ids must be nonblank", {})
		if seen.has(value):
			return _fail(&"remap_source_ids_invalid", "source_ids must be unique", {"duplicate": value})
		seen[value] = true
		if index > 0 and value < previous:
			return _fail(&"remap_source_ids_invalid", "source_ids must already be lexically sorted", {})
		previous = value
	return {"ok": true, "value": ids}


# -------------------------------------------------------------------------------------------------
# Shared helpers
# -------------------------------------------------------------------------------------------------

static func _require_desktop(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot.get("desktop")) != TYPE_DICTIONARY:
		return _fail(&"remap_snapshot_invalid", "snapshot.desktop is required", {})
	var desktop: Dictionary = snapshot["desktop"]
	if typeof(desktop.get("board")) != TYPE_DICTIONARY or typeof(desktop.get("consequence")) != TYPE_DICTIONARY:
		return _fail(&"remap_snapshot_invalid", "snapshot.desktop.board and .consequence are required", {})
	return {"ok": true, "value": desktop}


static func _require_bundle_keys(bundle: Dictionary) -> Dictionary:
	for key: String in ["transaction_id", "transaction_issuer_receipt", "branch_id",
			"desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt",
			"transaction_remap"]:
		if not bundle.has(key):
			return _fail(&"invalid_identity_allocation_bundle", "identity_allocation_bundle missing " + key, {})
	if typeof(bundle["transaction_remap"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity_allocation_bundle", "transaction_remap must be an object", {})
	if typeof(bundle["transaction_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity_allocation_bundle", "transaction_issuer_receipt must be an object", {})
	return {"ok": true}


## Missing/extra/multiply-mapped/dangling/unsorted-set/string-edited identities all reject (brief
## line 291): the rewindable set collected fresh from `snapshot` must equal EXACTLY the
## `transaction_remap` key set, and every remap record must be internally self-consistent.
static func _validate_transaction_remap_matches_snapshot(snapshot: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var collected := collect_rewindable_transaction_ids(snapshot)
	if not collected.get("ok", false):
		return collected
	var rewindable: Array = (collected["value"] as Dictionary)["transaction_ids"]
	var mapped_keys: Array = transaction_remap.keys()
	mapped_keys.sort()
	if rewindable != mapped_keys:
		return _fail(&"remap_source_set_mismatch",
			"transaction_remap's key set does not exactly equal the snapshot's rewindable transactions",
			{"expected": rewindable, "actual": mapped_keys})
	var seen_targets: Dictionary = {}
	for source_id: Variant in transaction_remap.keys():
		var record: Variant = transaction_remap[source_id]
		if typeof(record) != TYPE_DICTIONARY:
			return _fail(&"remap_record_invalid", "transaction_remap record must be an object: " + str(source_id), {})
		var value: Dictionary = record
		if str(value.get("source_transaction_id", "")) != str(source_id):
			return _fail(&"remap_record_invalid", "source_transaction_id must equal the map key: " + str(source_id), {})
		var new_id := str(value.get("new_transaction_id", ""))
		if new_id.is_empty():
			return _fail(&"remap_record_invalid", "new_transaction_id must be nonblank: " + str(source_id), {})
		if typeof(value.get("new_transaction_issuer_receipt")) != TYPE_DICTIONARY:
			return _fail(&"remap_record_invalid", "new_transaction_issuer_receipt must be an object: " + str(source_id), {})
		if seen_targets.has(new_id):
			return _fail(&"remap_target_multiply_mapped", new_id, {})
		seen_targets[new_id] = true
	return {"ok": true}


## validate_remap()'s independent re-derivation: pairs source/candidate board command/terminal
## receipt keys by POSITION (both dictionaries preserve insertion order, and prepare() inserts
## remapped entries in the same order it iterated the source), plus the one live consequence
## pending transaction_id if present. Any positional mismatch, size mismatch, or a target reused
## across sources fails closed rather than guessing at a correspondence.
static func _derive_transaction_map(source_desktop: Dictionary, candidate_desktop: Dictionary) -> Dictionary:
	var map: Dictionary = {}
	var source_board: Dictionary = source_desktop["board"]
	var candidate_board: Dictionary = candidate_desktop["board"]
	for key: String in ["command_receipts", "terminal_receipts"]:
		var source_receipts: Variant = source_board.get(key, {})
		var candidate_receipts: Variant = candidate_board.get(key, {})
		if typeof(source_receipts) != TYPE_DICTIONARY or typeof(candidate_receipts) != TYPE_DICTIONARY:
			return _fail(&"remap_unverifiable", key + " must be an object on both source and candidate", {})
		var source_keys: Array = (source_receipts as Dictionary).keys()
		var candidate_keys: Array = (candidate_receipts as Dictionary).keys()
		if source_keys.size() != candidate_keys.size():
			return _fail(&"remap_unverifiable", key + " cardinality differs between source and candidate", {})
		for index: int in range(source_keys.size()):
			var old_id := str(source_keys[index])
			var new_id := str(candidate_keys[index])
			if map.has(old_id) and str(map[old_id]) != new_id:
				return _fail(&"remap_target_conflict", old_id, {})
			map[old_id] = new_id
	var source_pending: Variant = (source_desktop["consequence"] as Dictionary).get("pending")
	var candidate_pending: Variant = (candidate_desktop["consequence"] as Dictionary).get("pending")
	if typeof(source_pending) == TYPE_DICTIONARY and typeof(candidate_pending) == TYPE_DICTIONARY:
		var old_id := str((source_pending as Dictionary).get("transaction_id", ""))
		var new_id := str((candidate_pending as Dictionary).get("transaction_id", ""))
		if not old_id.is_empty():
			if map.has(old_id) and str(map[old_id]) != new_id:
				return _fail(&"remap_target_conflict", old_id, {})
			map[old_id] = new_id
			var receipt: Variant = (candidate_pending as Dictionary).get("transaction_issuer_receipt")
			if typeof(receipt) == TYPE_DICTIONARY:
				var transaction_remap: Dictionary = {}
				for existing_old: Variant in map.keys():
					transaction_remap[str(existing_old)] = {
						"source_transaction_id": str(existing_old),
						"new_transaction_id": str(map[existing_old]),
						"new_transaction_issuer_receipt": receipt if str(existing_old) == old_id else {},
					}
				return {"ok": true, "value": transaction_remap}
	var transaction_remap: Dictionary = {}
	for old_id: Variant in map.keys():
		transaction_remap[str(old_id)] = {
			"source_transaction_id": str(old_id), "new_transaction_id": str(map[old_id]),
			"new_transaction_issuer_receipt": {},
		}
	return {"ok": true, "value": transaction_remap}


## Mirrors DesktopIdentityNonceIssuer._child_id()'s frozen preimage (plan line 537) exactly,
## INCLUDING its fail-closed behavior on a non-canonicalizable `source_ids`: the issuer's own
## `_child_id()` returns `child_source_ids_malformed` rather than guessing, so this duplicate
## fails closed too instead of silently substituting a placeholder "[]" for an uncanonicalizable
## value. That file's own header forbids adding a shared static to its frozen public surface, so
## the pure, domain-separated formula is duplicated here rather than imported -- it needs only the
## (already remapped) parent receipt's namespace/counter/receipt_id, never a live root/issuer
## object.
static func _child_id(parent_receipt: Dictionary, child_kind: String, ordinal: int, source_ids: Array) -> Dictionary:
	var canonical: Dictionary = _CANONICAL_JSON.stringify(source_ids)
	if not canonical.get("ok", false):
		return _fail(&"remap_child_source_ids_malformed",
			str(canonical.get("message", "source IDs are not canonically representable")), {})
	var canonical_ids := str(canonical["value"])
	return {"ok": true, "value": "%s.%s" % [child_kind, _sha256_hex("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
		str(parent_receipt.get("namespace", "")),
		int(parent_receipt.get("counter", 0)),
		str(parent_receipt.get("receipt_id", "")),
		child_kind, ordinal, canonical_ids,
	])]}


static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
