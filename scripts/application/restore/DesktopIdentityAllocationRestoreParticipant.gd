class_name DesktopIdentityAllocationRestoreParticipant
extends RefCounted

## Selected-Load identity allocation participant (Plan 02 Task 6, dwm-p2r.32, Phase C), amendment
## plan lines 287-293. Prepares BEFORE any live participant (SaveManager's forward order is
## `identity_allocation -> run -> desktop_consequence -> desktop_board -> profile -> localization
## -> audio -> route -> narrative`, brief line 382): it is the sole producer of the enriched
## identity_allocation_bundle that RunRestoreParticipant/DesktopConsequenceRestoreParticipant/
## DesktopBoardRestoreParticipant each build their own candidate from.
##
## Collaborators are injected rather than owned, mirroring this codebase's existing DI pattern
## (SaveManager.configure_identity_issuer, RouteRestoreParticipant.configure_desktop_host, ...):
##   issuer          -- DesktopIdentityNonceIssuer: prepare_continuation_allocation/
##                       commit_continuation_allocation.
##   source_loader   -- duck-typed to the same contract DesktopContinuationOperationJournal.
##                       reconcile_startup() already uses: load_context(locator) ->
##                       {ok, value:{context, context_sha256}}. Reloads and hash-verifies the exact
##                       document being restored, independent of whatever GameState's live memory
##                       currently holds.
##
## The external DesktopContinuationOperationJournal's intent_committed -> identity_allocation_
## committed -> participants_applying[...] -> participants_applied -> completed advance() sequence
## is NOT driven from inside this (or any other) individual participant: it is SaveManager's own
## orchestration, exactly like backup capture/apply/rollback ordering already is across every other
## participant today. This participant owns only its own durable side effect -- committing the root
## allocation -- and returns the receipt SaveManager needs for its own advance() call.
##
## apply_silent()'s root commit is irreversible (plan line 287: "failed restore may burn identities
## but can never reuse them"), so rollback_silent() never decrements the counter or deletes receipts
## -- it only reports {retained_allocation:true}, exactly as specified.

const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _PREPARE_INPUT_KEYS: Array[String] = [
	"restore_transaction_id", "transaction_issuer_receipt", "source_locator", "existing_run_id",
	"source_desktop_timeline_generation", "remap_source_transaction_ids", "allocation_candidate_fingerprint",
]

var _issuer: Object = null
var _source_loader: Object = null

func _init(issuer: Object, source_loader: Object) -> void:
	_issuer = issuer
	_source_loader = source_loader

## Mutation-free: reloads+hash-verifies the source, reruns the rewindable-transaction census against
## THAT reloaded document (never live memory), asks the issuer for the raw continuation-allocation
## candidate, remaps the reloaded snapshot with DesktopContinuationRemapper, and requires the whole
## proposal to match the caller's own frozen `allocation_candidate_fingerprint` before returning it.
func prepare(input: Dictionary) -> Dictionary:
	var shape := _exact_keys(input, _PREPARE_INPUT_KEYS)
	if not shape.get("ok", false):
		return shape
	var restore_transaction_id := str(input["restore_transaction_id"])
	if restore_transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_restore_transaction_id", "restore_transaction_id must be nonblank")

	# SaveManager resolves scene restores from their durable retained document.
	# Legacy loaders preserve their existing locator-only contract.
	var loaded: Dictionary
	if _source_loader.has_method("load_restore_context"):
		loaded = _source_loader.call(&"load_restore_context", restore_transaction_id, input["source_locator"])
	else:
		loaded = _source_loader.call(&"load_context", input["source_locator"])
	if not loaded.get("ok", false):
		return loaded
	var payload: Dictionary = loaded.get("value", {})
	if not payload.has("context") or typeof(payload["context"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_source_context", "the reloaded source carries no context")
	var reloaded_snapshot: Dictionary = payload["context"]
	var locator: Dictionary = input["source_locator"]
	if str(payload.get("context_sha256", "")) != str(locator.get("document_sha256", "")):
		return _fail(&"source_hash_mismatch", "the reloaded document no longer matches its recorded hash")

	var collected: Dictionary = REMAPPER.collect_rewindable_transaction_ids(reloaded_snapshot)
	if not collected.get("ok", false):
		return collected
	var live_ids: Array = (collected["value"] as Dictionary)["transaction_ids"]
	var supplied_ids: Variant = input["remap_source_transaction_ids"]
	if typeof(supplied_ids) != TYPE_ARRAY or (supplied_ids as Array) != live_ids:
		return _fail(&"remap_source_transaction_ids_mismatch",
			"remap_source_transaction_ids does not match the reloaded document's rewindable set")

	var request := {
		"existing_run_id": str(input["existing_run_id"]), "kind": "restore",
		"remap_source_transaction_ids": live_ids,
		"source_desktop_timeline_generation": int(input["source_desktop_timeline_generation"]),
		"transaction_id": restore_transaction_id,
		"transaction_issuer_receipt": input["transaction_issuer_receipt"],
	}
	var prepared_allocation: Dictionary = _issuer.call(&"prepare_continuation_allocation", request)
	if not prepared_allocation.get("ok", false):
		return prepared_allocation
	var raw_candidate: Dictionary = prepared_allocation["value"]

	var raw_bundle := {
		"transaction_id": restore_transaction_id,
		"transaction_issuer_receipt": input["transaction_issuer_receipt"],
		"branch_id": str(raw_candidate["branch_id"]),
		"desktop_timeline_generation": int(raw_candidate["desktop_timeline_generation"]),
		"causal_day_instance": str(raw_candidate["causal_day_instance"]),
		"causal_day_instance_issuer_receipt": raw_candidate["causal_day_instance_issuer_receipt"],
		"transaction_remap": raw_candidate["transaction_remap"],
	}
	var remapped: Dictionary = REMAPPER.prepare(reloaded_snapshot, restore_transaction_id, raw_bundle)
	if not remapped.get("ok", false):
		return remapped
	var remap_value: Dictionary = remapped["value"]

	var enriched_bundle := raw_bundle.duplicate(true)
	enriched_bundle["run_id"] = str(raw_candidate["run_id"])
	enriched_bundle["allocation_receipt_id"] = str((input["transaction_issuer_receipt"] as Dictionary).get("receipt_id", ""))
	enriched_bundle["remap_receipt_id"] = str(remap_value["remap_receipt_id"])
	enriched_bundle["remap_receipt_provenance"] = remap_value["remap_receipt_provenance"]

	var candidate_fingerprint := _canonical_sha256(raw_candidate)
	if candidate_fingerprint.is_empty():
		return _fail(&"allocation_candidate_not_canonicalizable", "the raw allocation candidate is not canonically representable")
	if candidate_fingerprint != str(input["allocation_candidate_fingerprint"]):
		return _fail(&"allocation_candidate_fingerprint_mismatch",
			"the reproduced allocation candidate does not match the frozen fingerprint")

	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"restore_transaction_id": restore_transaction_id,
		"raw_root_candidate": raw_candidate,
		"identity_allocation_bundle": enriched_bundle,
		"remapped_snapshot": remap_value["snapshot"],
	}}}

## Irreversible durable side effect. Never mutates local state itself: everything it commits lives
## in the issuer root and the external continuation journal.
func capture() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {}}

## Durably commits the root allocation. Repeats the exact request/candidate the issuer's own
## commit_continuation_allocation() re-validates, so an identical retry (SaveManager re-applying
## after a crash between this commit and the journal's own STAGE_ALLOCATED advance) replays the same
## bundle rather than re-minting one. SaveManager is responsible for advancing the external journal
## from intent_committed to identity_allocation_committed with the returned allocation_receipt.
func apply_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("raw_root_candidate")) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity_allocation_plan", "apply_silent requires plan.raw_root_candidate")
	var committed: Dictionary = _issuer.call(&"commit_continuation_allocation", plan["raw_root_candidate"])
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "code": &"ok", "value": {"allocation_receipt": committed["value"]}}

## Never decrements the counter or deletes receipts (plan line 287): once a restore transaction's
## identity has been durably allocated, that identity is burned whether or not the restore itself
## ultimately succeeds.
func rollback_silent(_backup: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"retained_allocation": true}}

func finalize() -> Dictionary:
	return {"ok": true, "code": &"ok"}

static func _exact_keys(value: Dictionary, expected: Array[String]) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	var sorted_expected := expected.duplicate()
	sorted_expected.sort()
	if keys != sorted_expected:
		return _fail(&"invalid_identity_allocation_input", "unexpected input keys: " + str(keys))
	return {"ok": true}

static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

