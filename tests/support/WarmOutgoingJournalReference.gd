extends "res://scripts/infrastructure/save/CheckpointJournal.gd"
## Frozen accepted proof-learning control. The warm benchmark pairs this method with the accepted
## port, so its baseline does not inherit the candidate's normalization reuse. Every other journal
## method remains shared and is checked by exact whole-source reconstruction before measurement.
## Do not modernize this method; its source and bytes are bound to the accepted Git blob.

const SOURCE_COMMIT := "226d3da868784baacc6fc33f58823f95b5815a51"
const JOURNAL_SOURCE_PATH := "scripts/infrastructure/save/CheckpointJournal.gd"
const JOURNAL_SOURCE_SHA256 := "617aa35fe71b426c8c0b643b9fdda2e65322f5e37e652fb98bf7f78f64e7c344"
const REMEMBER_METHOD_SHA256 := "70a0dcfb3e8668366339d986a2b96949a0b6a36b31fad67957f33a3698c994d4"

func remember_written_retained_bundle(checkpoint_id: String, text: String,
		document_bundle: Dictionary) -> bool:
	if text.is_empty() or document_bundle.is_empty():
		return false
	var retained := get_retained_bundle(checkpoint_id)
	if retained.is_empty() or not CANONICAL_JSON._deep_same(retained, document_bundle):
		return false
	# Full document validation preserves primitive fallback entries even when their snapshot is
	# unusable. Prove the stronger invariant needed by the future builder fast path exactly once.
	var keys: Array = document_bundle.keys()
	keys.sort()
	if keys != ["checkpoint_kind", "snapshot"] or document_bundle.get("snapshot") is not Dictionary:
		return false
	var kind := str(document_bundle.get("checkpoint_kind", ""))
	if kind != "line" and kind not in SEMANTIC_KINDS:
		return false
	var validated := RUN_SNAPSHOT_SCHEMA.validate(document_bundle["snapshot"])
	if not validated.get("ok", false) or not CANONICAL_JSON._deep_same(
			document_bundle["snapshot"], validated["value"]["candidate"]):
		return false
	_bundle_proofs[checkpoint_id] = {"text": text, "document_bundle": document_bundle.duplicate(true)}
	return true
