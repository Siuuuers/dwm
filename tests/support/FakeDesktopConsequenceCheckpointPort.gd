class_name FakeDesktopConsequenceCheckpointPort
extends RefCounted

## Task-8 contract fake for `SaveManagerCheckpointPort`'s consequence-checkpoint subset
## (`prepare_consequence_checkpoint`/`commit_consequence_checkpoint`), extending
## `test_desktop_causal_sequence_port.gd`'s own established `FakeAdmissionCheckpointPort` pattern
## (Task 6) into a standalone, reusable double.
##
## `DesktopConsequenceState.checkpoint_content_preimage(checkpoint_header, stage_candidate)` accepts
## an EXACT 6-key header (`kind,operation_ordinal,run_id,source_ids,stage,transaction_id`) and returns
## `{header, stage_candidate}` -- not the richer preimage shape the frozen contracts prose describes
## conceptually for the real checkpoint port's OWN receipt fields (`transaction_issuer_receipt`,
## `recovery_payload_sha256`, etc.). `DesktopConsequenceState._validate_pending()` itself places no
## exact-key requirement on `checkpoint_receipt`/`admission_checkpoint_receipt` beyond "a Dictionary",
## so -- mirroring the established fake's own precedent exactly -- this double keeps the checkpoint
## receipt a simple, self-consistent `{receipt_id, header, content_sha256}` shape rather than
## reconstructing the full production receipt (which needs an identity issuer this fake does not
## have). Adds keyed occupied-slot conflict detection at `(transaction_id, header)` beyond the
## established precedent, since Task 8 exercises repeated/duplicate checkpoint writes the Task-6
## suite never needed to.

const _STATE_SCRIPT := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Keyed by "transaction_id:operation_ordinal" -> {"candidate":Dictionary,"receipt":Dictionary}.
var committed: Dictionary = {}
## Ordered list of every committed record, in commit order (for tests asserting call ordering).
var commit_log: Array[Dictionary] = []
var fail_next_commit := false
var fail_next_prepare := false
## dwm-p2r.35.7 remediation (finding 1): mirrors SaveManagerCheckpointPort's own abandoned-set --
## transaction_id -> true, disjoint from `committed`.
var abandoned: Dictionary = {}


func prepare_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
	if fail_next_prepare:
		fail_next_prepare = false
		return {"ok": false, "code": &"forced_failure", "message": "test-forced prepare failure", "details": {}}
	var preimage: Dictionary = _STATE_SCRIPT.checkpoint_content_preimage(checkpoint_header, stage_candidate)
	if not preimage.get("ok", false):
		return preimage
	var preimage_value: Dictionary = (preimage["value"] as Dictionary)["preimage"]
	var content_sha256: String = _canonical_sha256(preimage_value)
	var transaction_id := str(checkpoint_header["transaction_id"])
	var ordinal := int(checkpoint_header["operation_ordinal"])
	var checkpoint_id := "desktop_consequence_checkpoint.fake." + transaction_id + "." + str(ordinal)
	var checkpoint_receipt := {
		"receipt_id": "consequence_checkpoint.fake." + content_sha256,
		"header": (preimage_value["header"] as Dictionary).duplicate(true),
		"content_sha256": content_sha256,
		"checkpoint_id": checkpoint_id,
	}
	# dwm-p2r.35.3 remediation (finding A-C3): mirrors SaveManagerCheckpointPort's own fix -- the stored
	# candidate carries the just-minted receipt attached to its pending record (both fields at
	# admission; only checkpoint_receipt at a later forward/progress operation) rather than the raw,
	# receipt-free input, so a stored candidate here stays loadable by DesktopConsequenceState.validate()
	# exactly like production now guarantees. Pre-admission stages are left untouched (validate()
	# requires both fields null there).
	var receipt_attached_candidate: Dictionary = stage_candidate.duplicate(true)
	var pending: Variant = receipt_attached_candidate.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var pending_dict: Dictionary = (pending as Dictionary).duplicate(true)
		if str(pending_dict.get("stage", "")) not in ["action_prepared", "prepared_checkpointed"]:
			pending_dict["checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
			if pending_dict.get("admission_checkpoint_receipt") == null:
				pending_dict["admission_checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
			receipt_attached_candidate["pending"] = pending_dict
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"document": {"stage_candidate": receipt_attached_candidate}},
		"checkpoint_receipt": checkpoint_receipt,
	}, "receipt": checkpoint_receipt.duplicate(true)}


func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
	if fail_next_commit:
		fail_next_commit = false
		return {"ok": false, "code": &"forced_failure", "message": "test-forced commit failure", "details": {}}
	var key := str(checkpoint_receipt.get("checkpoint_id", checkpoint_receipt.get("receipt_id", "")))
	if committed.has(key):
		var recorded: Dictionary = committed[key]
		if recorded["candidate"] == checkpoint_candidate and recorded["receipt"] == checkpoint_receipt:
			return {"ok": true, "code": &"ok",
				"value": {"checkpoint_receipt": (recorded["receipt"] as Dictionary).duplicate(true)},
				"receipt": (recorded["receipt"] as Dictionary).duplicate(true)}
		return {"ok": false, "code": &"consequence_checkpoint_conflict", "message": "", "details": {}}
	var record := {"candidate": checkpoint_candidate.duplicate(true), "receipt": checkpoint_receipt.duplicate(true)}
	committed[key] = record
	commit_log.append(record)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt.duplicate(true)},
		"receipt": checkpoint_receipt.duplicate(true)}


## dwm-p2r.35.7 remediation (finding 1): abandonment mirrors SaveManagerCheckpointPort's own
## abandon_pending_consequence_checkpoint() -- requires an existing pre-admission record, idempotent
## on replay, marks the transaction_id rather than writing a new committed record.
func abandon_pending_consequence_checkpoint(transaction_id: String) -> Dictionary:
	if bool(abandoned.get(transaction_id, false)):
		return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": true}, "receipt": {}}
	var latest_ordinal := -1
	var latest_stage := ""
	for record: Dictionary in committed.values():
		var header: Dictionary = (record["receipt"] as Dictionary)["header"]
		if str(header["transaction_id"]) != transaction_id:
			continue
		var ordinal := int(header["operation_ordinal"])
		if ordinal > latest_ordinal:
			latest_ordinal = ordinal
			latest_stage = str(header["stage"])
	if latest_ordinal < 0:
		return {"ok": false, "code": &"consequence_checkpoint_not_found", "message": "", "details": {}}
	if latest_stage not in ["action_prepared", "prepared_checkpointed"]:
		return {"ok": false, "code": &"consequence_checkpoint_not_pre_admission", "message": "", "details": {}}
	abandoned[transaction_id] = true
	return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": false}, "receipt": {}}


## dwm-p2r.35.3 remediation (finding A-C3): mirrors SaveManagerCheckpointPort.
## read_pending_consequence_checkpoint()'s own logic -- keep only each transaction_id's highest-
## ordinal committed record, then return the one (there should be at most one, under the exclusive
## `causal_transaction` gate) whose stage_candidate.pending is still nonnull.
func read_pending_consequence_checkpoint() -> Dictionary:
	var latest_by_transaction: Dictionary = {}
	for record: Dictionary in committed.values():
		var header: Dictionary = (record["receipt"] as Dictionary)["header"]
		var transaction_id := str(header["transaction_id"])
		var ordinal := int(header["operation_ordinal"])
		if not latest_by_transaction.has(transaction_id) \
				or ordinal > int(((latest_by_transaction[transaction_id]["receipt"] as Dictionary)["header"] as Dictionary)["operation_ordinal"]):
			latest_by_transaction[transaction_id] = record
	var pending_transaction_ids: Array = []
	for transaction_id: String in latest_by_transaction.keys():
		if bool(abandoned.get(transaction_id, false)):
			continue
		var record: Dictionary = latest_by_transaction[transaction_id]
		var stage_candidate: Dictionary = ((record["candidate"] as Dictionary)["document"] as Dictionary)["stage_candidate"]
		if stage_candidate.get("pending") != null:
			pending_transaction_ids.append(transaction_id)
	if pending_transaction_ids.is_empty():
		return {"ok": true, "code": &"ok", "value": {"found": false}}
	if pending_transaction_ids.size() > 1:
		return {"ok": false, "code": &"consequence_checkpoint_multiple_pending_transactions",
			"message": str(pending_transaction_ids), "details": {}}
	var chosen: String = pending_transaction_ids[0]
	var chosen_record: Dictionary = latest_by_transaction[chosen]
	var chosen_candidate: Dictionary = ((chosen_record["candidate"] as Dictionary)["document"] as Dictionary)["stage_candidate"]
	return {"ok": true, "code": &"ok", "value": {"found": true, "stage_candidate": chosen_candidate.duplicate(true)}}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()
