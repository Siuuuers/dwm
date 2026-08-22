class_name DesktopCausalSequencePort
extends RefCounted

## Shared causal-admission port (Plan 02 Task 6, dwm-p2r.32, amendment §12.2). One durable run-local
## causal-sequence compare-and-swap shared by Minesweeper round completion, Shop condition
## departure, and Schedule Done: "whichever complete transaction obtains the next sequence position
## commits first" -- terminal board completion first means a later Shop/condition action sees no
## active board to forfeit; Shop/condition departure first atomically forfeits the started board and
## a later completion is stale and rejected. Validation time, presentation time, and signal-arrival
## order can never decide this.
##
## Two-phase by design: `prepare_reservation()` proposes `causal_sequence`/`run_revision` and is
## PURE (nothing is allocated yet); `commit()` is the sole atomic point that (1) durably commits the
## admission checkpoint through the injected checkpoint port and (2) only then forward-applies the
## same sequence receipt to live `DesktopConsequenceState` -- brief line 249's "final compare-and-
## swap/admission point shared by every source kind".
##
## ASSUMPTION (documented per this project's convention for brief text that fixes the shape but not
## every internal mechanism): `causal_sequence_receipt.receipt_id`/`receipt_provenance` are derived
## locally by a pure canonical hash over the admitted fields, NOT minted by the desktop issuer --
## `configure()`'s frozen three-argument signature has no issuer parameter, so this port cannot
## reach one. This mirrors `DesktopIdentity.fingerprint()`'s existing precedent for a pure,
## non-issuer identity derivation elsewhere in this codebase.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _GATE_OWNER := &"causal_transaction"
const _REQUEST_KEYS: Array[String] = [
	"branch_id", "causal_day_instance", "desktop_timeline_generation", "expected_last_sequence",
	"expected_run_revision", "run_id", "source_commit_receipt_id", "source_commit_receipt_provenance",
	"source_kind", "transaction_id", "transaction_issuer_receipt",
]
const _SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase", "schedule_done"]
const _CHECKPOINT_METHODS: Array[String] = ["prepare_consequence_checkpoint", "commit_consequence_checkpoint"]

var _state: Object = null
var _mutation_gate: Object = null
var _admission_checkpoint_port: Object = null
var _publication_ledger: Object = null
## Keyed by transaction_id -> {"request": Dictionary, "causal_sequence_receipt": Dictionary}.
## Cleared on successful commit(); survives across prepare_admission() calls for the same
## transaction so commit() can repeat identity/source/last-sequence/run-revision validation.
var _pending_reservations: Dictionary = {}
var _committed_transaction_ids: Dictionary = {}
## Monotonic: incremented once per successful commit(). A rollback() whose backup predates the
## current generation names a capture taken before some OTHER transaction's admission checkpoint
## already committed, so undoing it now would be exactly the "rewind after admission" the brief
## forbids -- even though that other transaction's id never appears in the stale backup itself.
var _commit_generation := 0


func configure_publication_ledger(publication_ledger: Object) -> Dictionary:
	if publication_ledger == null or not publication_ledger.has_method("record_before_emit"):
		return _fail(&"invalid_publication_ledger", "publication_ledger must expose record_before_emit", {})
	if _publication_ledger != null:
		if _publication_ledger == publication_ledger:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"publication_ledger_already_configured", "a different publication ledger is already bound", {})
	_publication_ledger = publication_ledger
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Fail-closed ledger configuration (brief line 362): `configure()` refuses to complete until
## `configure_publication_ledger()` has already succeeded, so a misconfigured port can never reach
## a state where `publish()` might silently skip the at-most-once boundary.
func configure(state: Object, mutation_gate: Object, admission_checkpoint_port: Object) -> Dictionary:
	if state == null or not state.has_method("prepare_sequence_reservation") or not state.has_method("commit"):
		return _fail(&"invalid_state", "state must expose the DesktopConsequenceState surface", {})
	if mutation_gate == null or not mutation_gate.has_method("is_internal_owner_active"):
		return _fail(&"invalid_mutation_gate", "mutation_gate must expose is_internal_owner_active", {})
	for method_name: String in _CHECKPOINT_METHODS:
		if admission_checkpoint_port == null or not admission_checkpoint_port.has_method(method_name):
			return _fail(&"invalid_admission_checkpoint_port", "checkpoint port is missing " + method_name, {})
	if _publication_ledger == null:
		return _fail(&"publication_ledger_not_configured", "configure_publication_ledger() is required before configure()", {})
	if _state != null:
		if _state == state and _mutation_gate == mutation_gate and _admission_checkpoint_port == admission_checkpoint_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"port_already_configured", "a configured port never adopts a replacement owner", {})
	_state = state
	_mutation_gate = mutation_gate
	_admission_checkpoint_port = admission_checkpoint_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Pure. Proposes `causal_sequence=expected_last_sequence+1` and `run_revision=expected_run_
## revision+1` against the LIVE consequence state; allocates nothing. An identical replay (same
## transaction_id, byte-equal request) returns the original candidate/receipt; a changed request at
## an occupied transaction_id conflicts; a stale `expected_last_sequence`/`expected_run_revision`
## rejects with its own distinct code.
func prepare_reservation(request: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.is_empty():
		return ready
	var shape := _exact_keys(request, _REQUEST_KEYS, &"causal_reservation_request_invalid")
	if not shape.get("ok", false):
		return shape
	if str(request["source_kind"]) not in _SOURCE_KINDS:
		return _fail(&"causal_source_kind_invalid", str(request["source_kind"]), {})
	var transaction_id := str(request["transaction_id"])
	if _pending_reservations.has(transaction_id):
		var recorded: Dictionary = _pending_reservations[transaction_id]
		if recorded["request"] == request:
			return {"ok": true, "code": &"ok", "value": {
				"sequence_candidate": _sequence_candidate(recorded),
				"causal_sequence_receipt": (recorded["causal_sequence_receipt"] as Dictionary).duplicate(true),
			}, "receipt": (recorded["causal_sequence_receipt"] as Dictionary).duplicate(true)}
		return _fail(&"causal_sequence_conflict",
			"transaction_id is already reserved with a different request", {})
	# Post-commit replay (IMPORTANT 2): a byte-identical retry of an already-committed transaction
	# replays the original prepare_reservation() success rather than falling through to live
	# validation, where expected_last_sequence/expected_run_revision are now stale by construction
	# (commit() already advanced them). Changed bytes at the same transaction_id conflict.
	if _committed_transaction_ids.has(transaction_id):
		var committed_record: Dictionary = _committed_transaction_ids[transaction_id]
		if committed_record["request"] == request:
			return (committed_record["result"] as Dictionary).duplicate(true)
		return _fail(&"causal_sequence_conflict",
			"transaction_id was already committed with a different request", {})

	var live: Dictionary = _state.call(&"capture")
	if not live.get("ok", false):
		return live
	var live_state: Dictionary = (live["value"] as Dictionary)["state"]
	if int(request["expected_last_sequence"]) != int(live_state["causal_sequence"]):
		return _fail(&"causal_sequence_stale",
			"expected_last_sequence no longer matches the live causal_sequence", {})
	if int(request["expected_run_revision"]) != int(live_state["run_revision"]):
		return _fail(&"run_revision_stale",
			"expected_run_revision no longer matches the live run_revision", {})

	var causal_sequence := int(request["expected_last_sequence"]) + 1
	var run_revision := int(request["expected_run_revision"]) + 1
	var receipt := {
		"receipt_id": "", "receipt_provenance": {}, "transaction_id": transaction_id,
		"transaction_issuer_receipt": (request["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"run_id": str(request["run_id"]), "branch_id": str(request["branch_id"]),
		"desktop_timeline_generation": int(request["desktop_timeline_generation"]),
		"causal_day_instance": str(request["causal_day_instance"]), "source_kind": str(request["source_kind"]),
		"source_commit_receipt_id": str(request["source_commit_receipt_id"]),
		"source_commit_receipt_provenance": (request["source_commit_receipt_provenance"] as Dictionary).duplicate(true),
		"causal_sequence": causal_sequence, "run_revision": run_revision,
	}
	var receipt_id := _derive_receipt_id(receipt)
	receipt["receipt_id"] = receipt_id
	receipt["receipt_provenance"] = {"kind": "causal_sequence", "transaction_id": transaction_id,
		"causal_sequence": causal_sequence, "run_revision": run_revision}
	var record := {"request": request.duplicate(true), "causal_sequence_receipt": receipt.duplicate(true)}
	_pending_reservations[transaction_id] = record
	return {"ok": true, "code": &"ok", "value": {
		"sequence_candidate": _sequence_candidate(record), "causal_sequence_receipt": receipt.duplicate(true),
	}, "receipt": receipt.duplicate(true)}


## Binds the prepared sequence candidate to a fully prepared admission checkpoint candidate
## (`SaveManagerCheckpointPort.prepare_consequence_checkpoint()`'s own return value) plus the frozen
## recovery-payload hash. Mutation-free: this only validates that everything ties together and
## returns the combined candidate `commit()` will consume.
func prepare_admission(sequence_candidate: Dictionary, admission_checkpoint_candidate: Dictionary,
		recovery_payload_sha256: String) -> Dictionary:
	var ready := _require_configured()
	if not ready.is_empty():
		return ready
	if typeof(sequence_candidate.get("transaction_id")) != TYPE_STRING:
		return _fail(&"invalid_sequence_candidate", "sequence_candidate.transaction_id is required", {})
	var transaction_id := str(sequence_candidate["transaction_id"])
	if not _pending_reservations.has(transaction_id):
		return _fail(&"causal_reservation_absent", transaction_id, {})
	var recorded: Dictionary = _pending_reservations[transaction_id]
	if _sequence_candidate(recorded) != sequence_candidate:
		return _fail(&"invalid_sequence_candidate", "sequence_candidate does not match the live reservation", {})
	if typeof(admission_checkpoint_candidate.get("candidate")) != TYPE_DICTIONARY \
			or typeof(admission_checkpoint_candidate.get("checkpoint_receipt")) != TYPE_DICTIONARY:
		return _fail(&"invalid_admission_checkpoint_candidate",
			"admission_checkpoint_candidate must carry candidate and checkpoint_receipt", {})
	if not _is_lowercase_sha256(recovery_payload_sha256):
		return _fail(&"invalid_recovery_payload_hash", "recovery_payload_sha256 must be lowercase sha256 hex", {})
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"transaction_id": transaction_id, "sequence_candidate": sequence_candidate.duplicate(true),
		"admission_checkpoint_candidate": admission_checkpoint_candidate.duplicate(true),
		"recovery_payload_sha256": recovery_payload_sha256,
	}}, "receipt": {}}


func capture() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"pending_reservations": _pending_reservations.duplicate(true),
		"commit_generation": _commit_generation,
	}}, "receipt": {}}


## Commits the atomic admission checkpoint first through the injected checkpoint port, and only
## then forward-applies the same sequence receipt to live `DesktopConsequenceState`, setting
## `admission_checkpoint_receipt`/`checkpoint_receipt` atomically together (brief line 249).
func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.is_empty():
		return ready
	if not bool(_mutation_gate.call(&"is_internal_owner_active", _GATE_OWNER)):
		return _fail(&"causal_transaction_lease_required", "commit requires the active causal_transaction lease", {})
	var transaction_id := str(candidate.get("transaction_id", ""))
	if not _pending_reservations.has(transaction_id):
		return _fail(&"causal_reservation_absent", transaction_id, {})
	var recorded: Dictionary = _pending_reservations[transaction_id]
	if _sequence_candidate(recorded) != candidate.get("sequence_candidate"):
		return _fail(&"invalid_candidate", "candidate.sequence_candidate does not match the live reservation", {})

	# Repeat exact identity/source/last-sequence/run-revision validation against current live state.
	var live: Dictionary = _state.call(&"capture")
	if not live.get("ok", false):
		return live
	var live_state: Dictionary = (live["value"] as Dictionary)["state"]
	var request: Dictionary = recorded["request"]
	var receipt: Dictionary = recorded["causal_sequence_receipt"]
	if int(receipt["causal_sequence"]) != int(live_state["causal_sequence"]) + 1 \
			or int(receipt["run_revision"]) != int(live_state["run_revision"]) + 1:
		return _fail(&"causal_sequence_conflict", "the live state has advanced past this reservation", {})

	var admission_checkpoint_candidate: Dictionary = candidate["admission_checkpoint_candidate"]
	var checkpoint_receipt: Dictionary = admission_checkpoint_candidate["checkpoint_receipt"]
	var checkpoint_committed: Dictionary = _admission_checkpoint_port.call(
		&"commit_consequence_checkpoint", admission_checkpoint_candidate["candidate"], checkpoint_receipt)
	if not checkpoint_committed.get("ok", false):
		return checkpoint_committed

	# CRITICAL 1: the admission checkpoint is now durable on disk -- this is the brief's compare-
	# and-swap/admission point (line 249/253). From here forward rollback() must refuse (bumping
	# _commit_generation now, not only after the live calls below also succeed) even if the
	# subsequent live-adoption calls fail, so recovery only ever advances, never rewinds.
	_commit_generation += 1

	var reserved: Dictionary = _state.call(&"prepare_sequence_reservation", request, receipt)
	if not reserved.get("ok", false):
		return _committed_pending_recovery_result(transaction_id, receipt, checkpoint_receipt, reserved)
	var state_after: Dictionary = (reserved["value"] as Dictionary)["candidate"]["state_after"]
	(state_after["pending"] as Dictionary)["admission_checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
	(state_after["pending"] as Dictionary)["checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
	var prepared_restore: Dictionary = _state.call(&"prepare_restore", state_after)
	if not prepared_restore.get("ok", false):
		return _committed_pending_recovery_result(transaction_id, receipt, checkpoint_receipt, prepared_restore)
	var committed: Dictionary = _state.call(&"commit", (prepared_restore["value"] as Dictionary)["candidate"])
	if not committed.get("ok", false):
		return _committed_pending_recovery_result(transaction_id, receipt, checkpoint_receipt, committed)

	var success := {"ok": true, "code": &"ok", "value": {
		"causal_sequence_receipt": receipt.duplicate(true), "admission_checkpoint_receipt": checkpoint_receipt.duplicate(true),
	}, "receipt": {"causal_sequence_receipt": receipt.duplicate(true), "admission_checkpoint_receipt": checkpoint_receipt.duplicate(true)}}
	_committed_transaction_ids[transaction_id] = {"request": request.duplicate(true), "result": success.duplicate(true)}
	_pending_reservations.erase(transaction_id)
	return success


## Disk success followed by live failure (CRITICAL 1): distinct from a pre-checkpoint failure so a
## caller can tell recovery is forward-only. Details carry the admitted checkpoint receipt plus the
## sequence receipt; the pending reservation is deliberately left in place (never erased here) so a
## second commit() of the same candidate can retry the live calls and resume/return coherently.
func _committed_pending_recovery_result(transaction_id: String, causal_sequence_receipt: Dictionary,
		admission_checkpoint_receipt: Dictionary, live_failure: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"code": &"causal_admission_committed_pending_recovery",
		"message": "the admission checkpoint committed to disk but live adoption failed; recovery must advance forward, never rewind",
		"details": {
			"transaction_id": transaction_id,
			"causal_sequence_receipt": causal_sequence_receipt.duplicate(true),
			"admission_checkpoint_receipt": admission_checkpoint_receipt.duplicate(true),
			"live_failure": live_failure.duplicate(true),
		},
	}


## Succeeds only before the admission checkpoint has durably committed for any transaction the
## backup still names as pending; once admitted, recovery must advance forward, never rewind.
func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.is_empty():
		return ready
	var restored_reservations: Variant = backup.get("pending_reservations")
	if typeof(restored_reservations) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup.pending_reservations is required", {})
	if typeof(backup.get("commit_generation")) != TYPE_INT:
		return _fail(&"invalid_backup", "backup.commit_generation is required", {})
	if int(backup["commit_generation"]) != _commit_generation:
		return _fail(&"causal_admission_irreversible",
			"an admission checkpoint has already committed since this backup was captured", {})
	_pending_reservations = (restored_reservations as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


## Records the at-most-once external observation of this admitted causal transaction through the
## configured publication ledger (brief line 362: "each Plan-02 publisher calls only the configured
## ledger's record-before-emit seam"), keyed by `source_kind`.
func publish(publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.is_empty():
		return ready
	var keys: Array = publication.keys()
	keys.sort()
	if keys != ["admission_checkpoint_receipt", "causal_sequence_receipt"]:
		return _fail(&"invalid_publication", "publication must carry exactly causal_sequence_receipt and admission_checkpoint_receipt", {})
	var causal_sequence_receipt: Dictionary = publication["causal_sequence_receipt"]
	var ledger_publication := {"causal_sequence_receipt": causal_sequence_receipt.duplicate(true), "outbox": {}}
	var recorded: Dictionary = _publication_ledger.call(&"record_before_emit", {
		"kind": str(causal_sequence_receipt.get("source_kind", "")),
		"publication": ledger_publication,
		"publication_sha256": _canonical_sha256(ledger_publication),
		"semantic_receipt": causal_sequence_receipt.duplicate(true),
	})
	if not recorded.get("ok", false):
		return recorded
	return {"ok": true, "code": &"ok", "value": {"published": true},
		"receipt": {"causal_sequence_receipt": causal_sequence_receipt.duplicate(true),
			"admission_checkpoint_receipt": (publication["admission_checkpoint_receipt"] as Dictionary).duplicate(true)}}


func _sequence_candidate(record: Dictionary) -> Dictionary:
	return {
		"transaction_id": str((record["request"] as Dictionary)["transaction_id"]),
		"request": (record["request"] as Dictionary).duplicate(true),
		"causal_sequence_receipt": (record["causal_sequence_receipt"] as Dictionary).duplicate(true),
	}


func _derive_receipt_id(receipt_without_id: Dictionary) -> String:
	var preimage := receipt_without_id.duplicate(true)
	preimage.erase("receipt_id")
	preimage.erase("receipt_provenance")
	return "causal_sequence_receipt." + _canonical_sha256(preimage)


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


static func _is_lowercase_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.length() != 64:
		return false
	for codepoint in text.to_utf8_buffer():
		if not (codepoint >= 48 and codepoint <= 57) and not (codepoint >= 97 and codepoint <= 102):
			return false
	return true


func _require_configured() -> Dictionary:
	if _state == null or _mutation_gate == null or _admission_checkpoint_port == null:
		return _fail(&"port_not_configured", "DesktopCausalSequencePort.configure() was never called", {})
	return {}


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
