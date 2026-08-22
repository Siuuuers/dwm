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
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"document": {"stage_candidate": stage_candidate.duplicate(true)}},
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


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()
