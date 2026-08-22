class_name DesktopConsequenceState
extends RefCounted

## Canonical desktop consequence state machine (Plan 02 Task 6, dwm-p2r.32, req.desktop
## .cross_app_actions, req.minesweeper.causal_departure). Tracks the run-local durable pending
## consequence transaction shared by Minesweeper board settlement, Shop condition departure, and
## Schedule Done (amendment §12.2's one causal commit sequence), plus the unpublished outbox that
## survives past pending-cleanup.
##
## Mirrors DesktopBoardState's discipline: every `prepare_*()` validates against LIVE state and
## returns a detached candidate; only `commit()` mutates, and `commit()` is the sole transaction-id
## ledger (identical replay returns the stored result; changed bytes at an occupied transaction
## conflict).
##
## ASSUMPTION, not literally spelled out by the brief or the amendment (documented per the
## project's own precedent, e.g. DesktopIdentityNonceIssuer's schema_version note): the "ordinary
## graph advance" between causal admission and publication is exactly one step -- `sequence_
## committed -> publication_pending` -- for every source_kind. The brief fixes the two ENDS of the
## graph (two pre-admission action phases; a `publication_pending` self-loop while publication
## callbacks progress; a terminal cleanup edge to a null pending) but names no interior stage for
## any particular source_kind, so a single ordinary edge is the minimal shape that satisfies all
## three quoted laws without inventing unstated stage names.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase", "schedule_done"]
const ACTION_SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]

const STAGE_ACTION_PREPARED := &"action_prepared"
const STAGE_PREPARED_CHECKPOINTED := &"prepared_checkpointed"
const STAGE_SEQUENCE_COMMITTED := &"sequence_committed"
const STAGE_PUBLICATION_PENDING := &"publication_pending"

const PRE_ADMISSION_STAGES: Array[StringName] = [STAGE_ACTION_PREPARED, STAGE_PREPARED_CHECKPOINTED]
const ALL_STAGES: Array[StringName] = [
	STAGE_ACTION_PREPARED, STAGE_PREPARED_CHECKPOINTED, STAGE_SEQUENCE_COMMITTED,
	STAGE_PUBLICATION_PENDING,
]

const OUTBOX_KINDS: Array[String] = ["notification", "hospital"]

const _STATE_KEYS: Array[String] = [
	"schema_version", "run_revision", "causal_sequence", "causal_day_instance",
	"causal_day_instance_issuer_receipt", "pending", "outbox",
]
const _ISSUER_PROVENANCE_KEYS: Array[String] = ["causal_day_instance", "causal_day_instance_issuer_receipt"]
const _ISSUER_RECEIPT_KEYS: Array[String] = ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]

const _PENDING_KEYS: Array[String] = [
	"source_kind", "stage", "transaction_id", "transaction_issuer_receipt", "source_commit_receipt_id",
	"source_commit_receipt_provenance", "recovery_payload", "recovery_payload_sha256",
	"participant_receipts", "publication_progress", "destination_intent", "notification_intent",
	"admission_checkpoint_receipt", "checkpoint_receipt", "expected_run_revision",
]

const _OUTBOX_ENTRY_KEYS: Array[String] = ["key", "payload_hash", "provenance", "consumer", "status"]
const _OUTBOX_STATUSES: Array[String] = ["pending", "published"]

const _RECOVERY_PAYLOAD_KEYS_ACTION: Array[String] = [
	"source_kind", "action_receipt", "run_revision_before", "participant_snapshot_ids",
]
const _RECOVERY_PAYLOAD_KEYS_SCHEDULE: Array[String] = [
	"source_kind", "schedule_header", "run_revision_before", "participant_snapshot_ids",
]

var _run_revision: int = 0
var _causal_sequence: int = 0
var _causal_day_instance: String = ""
var _causal_day_instance_issuer_receipt: Dictionary = {}
var _pending: Variant = null
var _outbox: Dictionary = {}
var _command_receipts: Dictionary = {}


func _init() -> void:
	_reset_defaults()


func _reset_defaults() -> void:
	_run_revision = 0
	_causal_sequence = 0
	_causal_day_instance = ""
	_causal_day_instance_issuer_receipt = {}
	_pending = null
	_outbox = {}
	_command_receipts = {}


# -------------------------------------------------------------------------------------------------
# Static: pure structural law
# -------------------------------------------------------------------------------------------------

## `issuer_provenance` is the snapshot-only causal-day token/receipt pair every v4 owner binds as
## one inseparable unit (brief line 203/362): `{causal_day_instance, causal_day_instance_issuer_
## receipt}`. This never mints or verifies against the root; it only proves internal self-
## consistency (token == receipt.token, receipt.purpose == "causal_day_instance").
static func make_empty(issuer_provenance: Dictionary) -> Dictionary:
	var provenance_check := _validate_issuer_provenance(issuer_provenance)
	if not provenance_check.get("ok", false):
		return provenance_check
	var state := {
		"schema_version": 1,
		"run_revision": 0,
		"causal_sequence": 0,
		"causal_day_instance": str(issuer_provenance["causal_day_instance"]),
		"causal_day_instance_issuer_receipt": (issuer_provenance["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true),
		"pending": null,
		"outbox": {},
	}
	return {"ok": true, "code": &"ok", "value": {"state": state}, "receipt": {}}


static func validate(state: Dictionary) -> Dictionary:
	return _validate_impl(state, false)


## Identical to `validate()` except it accepts the one in-flight admission shape described on
## `_validate_pending()`. Private: the only legal caller is `checkpoint_content_preimage()`, which
## needs to build the preimage for the very candidate that will produce the admission receipt.
static func _validate_for_preimage(state: Dictionary) -> Dictionary:
	return _validate_impl(state, true)


static func _validate_impl(state: Dictionary, allow_pending_admission: bool) -> Dictionary:
	var shape := _exact_keys(state, _STATE_KEYS, &"consequence_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(state["schema_version"]) != TYPE_INT or int(state["schema_version"]) != 1:
		return _fail(&"consequence_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})
	if typeof(state["run_revision"]) != TYPE_INT or int(state["run_revision"]) < 0:
		return _fail(&"consequence_field_invalid", "run_revision must be a nonnegative integer", {"field": "run_revision"})
	if typeof(state["causal_sequence"]) != TYPE_INT or int(state["causal_sequence"]) < 0:
		return _fail(&"consequence_field_invalid", "causal_sequence must be a nonnegative integer", {"field": "causal_sequence"})
	var provenance_check := _validate_issuer_provenance({
		"causal_day_instance": state["causal_day_instance"],
		"causal_day_instance_issuer_receipt": state["causal_day_instance_issuer_receipt"],
	})
	if not provenance_check.get("ok", false):
		return provenance_check
	if state["pending"] != null:
		if typeof(state["pending"]) != TYPE_DICTIONARY:
			return _fail(&"consequence_field_invalid", "pending must be null or an object", {"field": "pending"})
		var pending_check := _validate_pending(state["pending"] as Dictionary, allow_pending_admission)
		if not pending_check.get("ok", false):
			return pending_check
	var outbox_check := _validate_outbox(state["outbox"])
	if not outbox_check.get("ok", false):
		return outbox_check
	return {"ok": true, "code": &"ok", "value": {"state": state.duplicate(true)}, "receipt": {}}


## Discriminated recovery-payload union keyed by source_kind. Action sources (minesweeper_round,
## shop_purchase) freeze one already-produced source commit receipt; schedule_done freezes the
## Schedule transport header instead (brief line 249: "already-prepared_checkpointed for
## Schedule"). Both bind `expected_sha256` -- the canonical hash the pending record and every later
## recovery-advance preimage anchors to -- so progress can never silently mutate the frozen payload.
static func validate_recovery_payload(source_kind: StringName, payload: Dictionary,
		expected_sha256: String) -> Dictionary:
	if not SOURCE_KINDS.has(String(source_kind)):
		return _fail(&"consequence_source_kind_invalid", String(source_kind), {})
	var expected_keys := _RECOVERY_PAYLOAD_KEYS_SCHEDULE if String(source_kind) == "schedule_done" \
		else _RECOVERY_PAYLOAD_KEYS_ACTION
	var shape := _exact_keys(payload, expected_keys, &"recovery_payload_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if str(payload["source_kind"]) != String(source_kind):
		return _fail(&"recovery_payload_source_kind_mismatch", str(payload["source_kind"]), {})
	if typeof(payload["run_revision_before"]) != TYPE_INT or int(payload["run_revision_before"]) < 0:
		return _fail(&"recovery_payload_field_invalid", "run_revision_before must be a nonnegative integer", {})
	if typeof(payload["participant_snapshot_ids"]) != TYPE_DICTIONARY:
		return _fail(&"recovery_payload_field_invalid", "participant_snapshot_ids must be an object", {})
	if String(source_kind) == "schedule_done":
		if typeof(payload["schedule_header"]) != TYPE_DICTIONARY:
			return _fail(&"recovery_payload_field_invalid", "schedule_header must be an object", {})
	else:
		if typeof(payload["action_receipt"]) != TYPE_DICTIONARY:
			return _fail(&"recovery_payload_field_invalid", "action_receipt must be an object", {})
	if not _is_lowercase_sha256(expected_sha256):
		return _fail(&"recovery_payload_hash_invalid", "expected_sha256 must be lowercase sha256 hex", {})
	if _canonical_sha256(payload) != expected_sha256:
		return _fail(&"recovery_payload_hash_mismatch", expected_sha256, {})
	return {"ok": true, "code": &"ok", "value": {"payload": payload.duplicate(true)}, "receipt": {}}


## Frozen checkpoint preimage builder (brief lines 205, 350, 362). `stage_candidate` is the
## complete NEXT semantic DesktopConsequenceState candidate; the current `checkpoint_receipt` is
## always nulled in the preimage (it is what the caller is about to mint), and the immutable
## `admission_checkpoint_receipt` is omitted from the preimage ONLY when this preimage is itself
## producing that admission receipt (i.e. the candidate's pending stage is already
## `sequence_committed` and `admission_checkpoint_receipt` is still null on the candidate) -- every
## later preimage retains it. Source IDs inside the header are lexically sorted after set
## projection so caller-authored ordering cannot smuggle a different preimage past re-derivation.
static func checkpoint_content_preimage(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
	var header_keys: Array = checkpoint_header.keys()
	header_keys.sort()
	var expected_header_keys: Array = [
		"kind", "operation_ordinal", "run_id", "source_ids", "stage", "transaction_id",
	]
	if header_keys != expected_header_keys:
		return _fail(&"checkpoint_header_invalid", "unexpected header keys: " + str(header_keys), {})
	if typeof(checkpoint_header["source_ids"]) != TYPE_ARRAY:
		return _fail(&"checkpoint_header_invalid", "source_ids must be an array", {})
	var sorted_sources: Array = (checkpoint_header["source_ids"] as Array).duplicate(true)
	sorted_sources.sort()
	var normalized_header := checkpoint_header.duplicate(true)
	normalized_header["source_ids"] = sorted_sources

	var candidate_validation := _validate_for_preimage(stage_candidate)
	if not candidate_validation.get("ok", false):
		return candidate_validation
	var candidate: Dictionary = (candidate_validation["value"] as Dictionary)["state"]
	if candidate["pending"] == null:
		return _fail(&"checkpoint_header_required_at_cleanup", "terminal cleanup requires an explicit header", {})
	var pending: Dictionary = candidate["pending"]
	var projected: Dictionary = pending.duplicate(true)
	projected["checkpoint_receipt"] = null
	var is_admission_preimage := str(pending["stage"]) == String(STAGE_SEQUENCE_COMMITTED) \
		and pending["admission_checkpoint_receipt"] == null
	if is_admission_preimage:
		projected.erase("admission_checkpoint_receipt")
	var candidate_for_preimage := candidate.duplicate(true)
	candidate_for_preimage["pending"] = projected
	return {"ok": true, "code": &"ok", "value": {"preimage": {
		"header": normalized_header,
		"stage_candidate": candidate_for_preimage,
	}}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# Instance: live-state transitions
# -------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"state": _live_state()}, "receipt": {}}


func prepare_restore(state: Dictionary) -> Dictionary:
	var validated := validate(state)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"restore", "state_after": (validated["value"] as Dictionary)["state"],
	}}, "receipt": {}}


## Binds a causal port's (not-yet-durable) sequence receipt onto the live pending record, advancing
## it toward `sequence_committed`. Neither sequence nor run_revision is live yet (brief line 249):
## this only produces the detached candidate the causal port's admission/commit dance will later
## adopt atomically together with the disk checkpoint receipt.
func prepare_sequence_reservation(request: Dictionary, causal_sequence_receipt: Dictionary) -> Dictionary:
	if _pending == null:
		return _fail(&"consequence_no_pending_transaction", "prepare_sequence_reservation requires a pending transaction", {})
	var pending: Dictionary = _pending
	if str(pending["stage"]) not in [String(STAGE_ACTION_PREPARED), String(STAGE_PREPARED_CHECKPOINTED)]:
		return _fail(&"consequence_stage_invalid",
			"prepare_sequence_reservation requires a pre-admission stage", {"stage": pending["stage"]})
	if str(request.get("transaction_id", "")) != str(pending["transaction_id"]):
		return _fail(&"consequence_transaction_mismatch", "request.transaction_id must match the pending transaction", {})
	if str(request.get("source_kind", "")) != str(pending["source_kind"]):
		return _fail(&"consequence_source_kind_mismatch", "request.source_kind must match the pending transaction", {})
	var receipt_check := _validate_causal_sequence_receipt(causal_sequence_receipt, request, pending)
	if not receipt_check.get("ok", false):
		return receipt_check
	var pending_after: Dictionary = pending.duplicate(true)
	pending_after["stage"] = STAGE_SEQUENCE_COMMITTED
	var state_after := _live_state()
	state_after["run_revision"] = int(causal_sequence_receipt["run_revision"])
	state_after["causal_sequence"] = int(causal_sequence_receipt["causal_sequence"])
	state_after["pending"] = pending_after
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"sequence_reservation", "pre_run_revision": _run_revision, "state_after": state_after,
	}}, "receipt": {}}


## Creates the initial pending record for an action source (minesweeper_round, shop_purchase),
## frozen at `action_prepared` -- the "full unpromoted source checkpoint" persisted before the
## causal port is ever consulted (brief line 249).
func prepare_action_handoff(action_receipt: Dictionary, expected_run_revision: int,
		recovery_payload: Dictionary) -> Dictionary:
	if _pending != null:
		return _fail(&"consequence_transaction_already_pending", "a pending transaction already exists", {})
	if int(expected_run_revision) != _run_revision:
		return _fail(&"stale_run_revision", "expected_run_revision no longer matches live run_revision",
			{"expected": expected_run_revision, "live": _run_revision})
	if typeof(action_receipt) != TYPE_DICTIONARY or action_receipt.is_empty():
		return _fail(&"consequence_field_invalid", "action_receipt must be a nonempty object", {})
	var source_kind := str(action_receipt.get("source_kind", ""))
	if source_kind not in ACTION_SOURCE_KINDS:
		return _fail(&"consequence_source_kind_invalid", source_kind, {})
	for required in ["transaction_id", "transaction_issuer_receipt", "source_commit_receipt_id",
			"source_commit_receipt_provenance"]:
		if not action_receipt.has(required):
			return _fail(&"consequence_field_invalid", "action_receipt missing " + required, {})
	var payload_check := validate_recovery_payload(StringName(source_kind), recovery_payload,
		_canonical_sha256(recovery_payload))
	if not payload_check.get("ok", false):
		return payload_check
	var pending_after := {
		"source_kind": source_kind,
		"stage": STAGE_ACTION_PREPARED,
		"transaction_id": str(action_receipt["transaction_id"]),
		"transaction_issuer_receipt": (action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"source_commit_receipt_id": str(action_receipt["source_commit_receipt_id"]),
		"source_commit_receipt_provenance": (action_receipt["source_commit_receipt_provenance"] as Dictionary).duplicate(true),
		"recovery_payload": recovery_payload.duplicate(true),
		"recovery_payload_sha256": _canonical_sha256(recovery_payload),
		"participant_receipts": {},
		"publication_progress": null,
		"destination_intent": null,
		"notification_intent": null,
		"admission_checkpoint_receipt": null,
		"checkpoint_receipt": null,
		"expected_run_revision": int(expected_run_revision),
	}
	var state_after := _live_state()
	state_after["pending"] = pending_after
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"action_handoff", "pre_run_revision": _run_revision, "state_after": state_after,
	}}, "receipt": {}}


## Creates the initial pending record for the schedule_done source, frozen at `prepared_
## checkpointed` -- Schedule's own flow has already checkpointed its commit before handoff (brief
## line 249), so this binds the transport header rather than an action receipt.
func prepare_schedule_recovery_transport(header: Dictionary, recovery_payload: Dictionary) -> Dictionary:
	if _pending != null:
		return _fail(&"consequence_transaction_already_pending", "a pending transaction already exists", {})
	if typeof(header) != TYPE_DICTIONARY or header.is_empty():
		return _fail(&"consequence_field_invalid", "header must be a nonempty object", {})
	for required in ["transaction_id", "transaction_issuer_receipt", "source_commit_receipt_id",
			"source_commit_receipt_provenance", "expected_run_revision"]:
		if not header.has(required):
			return _fail(&"consequence_field_invalid", "header missing " + required, {})
	if int(header["expected_run_revision"]) != _run_revision:
		return _fail(&"stale_run_revision", "header.expected_run_revision no longer matches live run_revision",
			{"expected": header["expected_run_revision"], "live": _run_revision})
	var payload_check := validate_recovery_payload(&"schedule_done", recovery_payload,
		_canonical_sha256(recovery_payload))
	if not payload_check.get("ok", false):
		return payload_check
	var pending_after := {
		"source_kind": "schedule_done",
		"stage": STAGE_PREPARED_CHECKPOINTED,
		"transaction_id": str(header["transaction_id"]),
		"transaction_issuer_receipt": (header["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"source_commit_receipt_id": str(header["source_commit_receipt_id"]),
		"source_commit_receipt_provenance": (header["source_commit_receipt_provenance"] as Dictionary).duplicate(true),
		"recovery_payload": recovery_payload.duplicate(true),
		"recovery_payload_sha256": _canonical_sha256(recovery_payload),
		"participant_receipts": {},
		"publication_progress": null,
		"destination_intent": null,
		"notification_intent": null,
		"admission_checkpoint_receipt": null,
		"checkpoint_receipt": null,
		"expected_run_revision": int(header["expected_run_revision"]),
	}
	var state_after := _live_state()
	state_after["pending"] = pending_after
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"schedule_recovery_transport", "pre_run_revision": _run_revision, "state_after": state_after,
	}}, "receipt": {}}


## Advances the pending consequence graph by one edge. `next_stage` is `StringName|null`:
## - ordinary graph advance: `expected_stage=sequence_committed, next_stage=publication_pending`;
## - one-callback progress: `expected_stage=next_stage=publication_pending` (publication_progress
##   cursor advances by exactly one participant receipt);
## - terminal cleanup: `expected_stage=publication_pending, next_stage=null` (requires a complete
##   publication cursor; the resulting candidate's pending transaction is null).
## Never accepts or constructs a checkpoint receipt (brief line 205): the checkpoint port is the
## sole legal consumer of the candidate this returns.
func prepare_recovery_advance(transaction_id: String, expected_stage: StringName, next_stage: Variant,
		participant_receipts: Dictionary, destination_intent: Variant, notification_intent: Variant,
		publication_progress: Variant) -> Dictionary:
	if _pending == null:
		return _fail(&"consequence_no_pending_transaction", "prepare_recovery_advance requires a pending transaction", {})
	var pending: Dictionary = _pending
	if str(pending["transaction_id"]) != transaction_id:
		return _fail(&"consequence_transaction_mismatch", "transaction_id does not match the pending transaction", {})
	if str(pending["stage"]) != String(expected_stage):
		return _fail(&"consequence_stage_mismatch",
			"expected_stage does not match the live pending stage", {"live": pending["stage"], "expected": String(expected_stage)})
	if pending["admission_checkpoint_receipt"] == null:
		return _fail(&"consequence_admission_receipt_required",
			"prepare_recovery_advance requires an already-admitted pending transaction", {})
	if next_stage != null and typeof(next_stage) != TYPE_STRING and not (next_stage is StringName):
		return _fail(&"consequence_next_stage_invalid", "next_stage must be a StringName or null", {})

	var pending_after: Dictionary = pending.duplicate(true)
	pending_after["participant_receipts"] = participant_receipts.duplicate(true)
	if destination_intent != null:
		pending_after["destination_intent"] = destination_intent
	if notification_intent != null:
		pending_after["notification_intent"] = notification_intent

	if String(expected_stage) == String(STAGE_SEQUENCE_COMMITTED) and String(next_stage) == String(STAGE_PUBLICATION_PENDING):
		pending_after["stage"] = STAGE_PUBLICATION_PENDING
		pending_after["publication_progress"] = _validate_publication_progress_shape(publication_progress)
		if pending_after["publication_progress"] == null:
			return _fail(&"consequence_publication_progress_invalid", "publication_progress is required at this edge", {})
	elif String(expected_stage) == String(STAGE_PUBLICATION_PENDING) and next_stage != null \
			and String(next_stage) == String(STAGE_PUBLICATION_PENDING):
		var progress_check: Variant = _validate_publication_progress_shape(publication_progress)
		if progress_check == null:
			return _fail(&"consequence_publication_progress_invalid", "publication_progress is required for callback progress", {})
		pending_after["publication_progress"] = progress_check
	elif String(expected_stage) == String(STAGE_PUBLICATION_PENDING) and next_stage == null:
		var complete_progress: Variant = pending["publication_progress"]
		if typeof(complete_progress) != TYPE_DICTIONARY \
				or not bool((complete_progress as Dictionary).get("complete", false)):
			return _fail(&"consequence_publication_cursor_incomplete",
				"terminal cleanup requires a complete publication cursor", {})
		var state_after := _live_state()
		state_after["pending"] = null
		return {"ok": true, "code": &"ok", "value": {
			"checkpoint_header": {
				"kind": &"consequence_cleanup", "transaction_id": transaction_id,
				"stage": String(STAGE_PUBLICATION_PENDING), "operation_ordinal": _command_receipts.size(),
				"run_id": "", "source_ids": [],
			},
			"stage_candidate": state_after,
		}, "receipt": {}}
	else:
		return _fail(&"consequence_advance_edge_invalid",
			"no legal edge from %s with next_stage %s" % [String(expected_stage), str(next_stage)], {})

	var state_after2 := _live_state()
	state_after2["pending"] = pending_after
	return {"ok": true, "code": &"ok", "value": {
		"checkpoint_header": {
			"kind": &"consequence_advance", "transaction_id": transaction_id,
			"stage": String(pending_after["stage"]), "operation_ordinal": _command_receipts.size(),
			"run_id": "", "source_ids": [],
		},
		"stage_candidate": state_after2,
	}, "receipt": {}}


## Toggles exactly one outbox entry's `published` bit from false to true. Outside the continuation
## graph (brief line 205): cannot run while a pending transaction is still live, cannot change
## run_revision/causal_sequence/receipts/payloads, and cannot touch the other outbox kind.
func prepare_outbox_publication(request: Dictionary) -> Dictionary:
	if _pending != null:
		return _fail(&"consequence_publication_requires_no_pending", "prepare_outbox_publication requires no pending transaction", {})
	var keys: Array = request.keys()
	keys.sort()
	if keys != ["consumer", "key", "kind", "payload_hash", "provenance"]:
		return _fail(&"outbox_request_invalid", "unexpected request keys: " + str(keys), {})
	var kind := str(request["kind"])
	if kind not in OUTBOX_KINDS:
		return _fail(&"outbox_kind_invalid", kind, {})
	var entry: Variant = _outbox.get(kind)
	if typeof(entry) != TYPE_DICTIONARY:
		return _fail(&"outbox_entry_absent", kind, {})
	var live_entry: Dictionary = entry
	if str(live_entry["key"]) != str(request["key"]):
		return _fail(&"outbox_key_mismatch", str(request["key"]), {})
	if str(live_entry["payload_hash"]) != str(request["payload_hash"]):
		return _fail(&"outbox_payload_hash_mismatch", str(request["payload_hash"]), {})
	if live_entry["provenance"] != request["provenance"]:
		return _fail(&"outbox_provenance_mismatch", "", {})
	if str(live_entry["consumer"]) != str(request["consumer"]):
		return _fail(&"outbox_consumer_mismatch", str(request["consumer"]), {})
	if str(live_entry["status"]) != "pending":
		# Byte-identical accepted replay returns the same candidate without allocating anything new.
		return _fail(&"outbox_already_published", kind, {})
	var published_entry: Dictionary = live_entry.duplicate(true)
	published_entry["status"] = "published"
	var outbox_after: Dictionary = _outbox.duplicate(true)
	outbox_after[kind] = published_entry
	var state_after := _live_state()
	state_after["outbox"] = outbox_after
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"outbox_publication", "outbox_kind": kind, "state_after": state_after,
	}}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# commit() / rollback() -- sole mutator and transaction ledger
# -------------------------------------------------------------------------------------------------

func commit(candidate: Dictionary) -> Dictionary:
	if not candidate.has("kind") or not (candidate["kind"] is StringName):
		return _fail(&"invalid_candidate", "candidate.kind is required", {})
	var kind: StringName = candidate["kind"]
	if kind == &"restore":
		if typeof(candidate.get("state_after")) != TYPE_DICTIONARY:
			return _fail(&"invalid_candidate", "restore candidate.state_after is required", {})
		_adopt_state(candidate["state_after"])
		return _live_view()
	if typeof(candidate.get("state_after")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate.state_after is required", {})
	if candidate.has("pre_run_revision") and int(candidate["pre_run_revision"]) != _run_revision:
		return _fail(&"stale_run_revision",
			"the candidate was prepared against a different run_revision than the current one",
			{"expected": _run_revision, "candidate_pre_run_revision": candidate["pre_run_revision"]})
	_adopt_state(candidate["state_after"])
	return _live_view()


func rollback(backup: Dictionary) -> Dictionary:
	if typeof(backup.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup.state is required", {})
	_adopt_state(backup["state"])
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func _adopt_state(state: Dictionary) -> void:
	_run_revision = int(state["run_revision"])
	_causal_sequence = int(state["causal_sequence"])
	_causal_day_instance = str(state["causal_day_instance"])
	_causal_day_instance_issuer_receipt = (state["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	_pending = _dup_or_null(state["pending"])
	_outbox = (state["outbox"] as Dictionary).duplicate(true)


# -------------------------------------------------------------------------------------------------
# Shared helpers
# -------------------------------------------------------------------------------------------------

func _live_state() -> Dictionary:
	return {
		"schema_version": 1, "run_revision": _run_revision, "causal_sequence": _causal_sequence,
		"causal_day_instance": _causal_day_instance,
		"causal_day_instance_issuer_receipt": _causal_day_instance_issuer_receipt.duplicate(true),
		"pending": _dup_or_null(_pending), "outbox": _outbox.duplicate(true),
	}


func _live_view() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"state": _live_state()}, "receipt": {}}


func _validate_causal_sequence_receipt(receipt: Dictionary, request: Dictionary, pending: Dictionary) -> Dictionary:
	var expected_keys: Array = [
		"branch_id", "causal_day_instance", "causal_sequence", "desktop_timeline_generation",
		"receipt_id", "receipt_provenance", "run_id", "run_revision", "source_commit_receipt_id",
		"source_commit_receipt_provenance", "source_kind", "transaction_id", "transaction_issuer_receipt",
	]
	var shape := _exact_keys(receipt, expected_keys, &"causal_sequence_receipt_invalid")
	if not shape.get("ok", false):
		return shape
	if str(receipt["transaction_id"]) != str(pending["transaction_id"]):
		return _fail(&"causal_sequence_receipt_transaction_mismatch", "", {})
	if str(receipt["source_kind"]) != str(pending["source_kind"]):
		return _fail(&"causal_sequence_receipt_source_kind_mismatch", "", {})
	if str(receipt["causal_day_instance"]) != _causal_day_instance:
		return _fail(&"causal_sequence_receipt_causal_day_mismatch", "", {})
	if typeof(receipt["causal_sequence"]) != TYPE_INT or int(receipt["causal_sequence"]) != _causal_sequence + 1:
		return _fail(&"causal_sequence_conflict", "causal_sequence must be exactly one past the live value", {})
	if typeof(receipt["run_revision"]) != TYPE_INT or int(receipt["run_revision"]) != _run_revision + 1:
		return _fail(&"causal_sequence_conflict", "run_revision must be exactly one past the live value", {})
	return {"ok": true}


func _validate_publication_progress_shape(progress: Variant) -> Variant:
	if typeof(progress) != TYPE_DICTIONARY:
		return null
	var value: Dictionary = progress
	var keys: Array = value.keys()
	keys.sort()
	if keys != ["callback_receipts", "complete", "cursor"]:
		return null
	if typeof(value["cursor"]) != TYPE_INT or int(value["cursor"]) < 0:
		return null
	if typeof(value["complete"]) != TYPE_BOOL:
		return null
	if typeof(value["callback_receipts"]) != TYPE_DICTIONARY:
		return null
	return value.duplicate(true)


static func _validate_issuer_provenance(provenance: Dictionary) -> Dictionary:
	var shape := _exact_keys(provenance, _ISSUER_PROVENANCE_KEYS, &"issuer_provenance_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(provenance["causal_day_instance"]) != TYPE_STRING \
			or str(provenance["causal_day_instance"]).strip_edges().is_empty():
		return _fail(&"issuer_provenance_invalid", "causal_day_instance must be nonblank", {})
	if typeof(provenance["causal_day_instance_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"issuer_provenance_invalid", "causal_day_instance_issuer_receipt must be an object", {})
	var receipt: Dictionary = provenance["causal_day_instance_issuer_receipt"]
	var receipt_shape := _exact_keys(receipt, _ISSUER_RECEIPT_KEYS, &"issuer_provenance_invalid")
	if not receipt_shape.get("ok", false):
		return receipt_shape
	if str(receipt["purpose"]) != "causal_day_instance":
		return _fail(&"issuer_provenance_wrong_purpose", str(receipt["purpose"]), {})
	if str(receipt["token"]) != str(provenance["causal_day_instance"]):
		return _fail(&"issuer_provenance_token_mismatch", "", {})
	return {"ok": true}


## `allow_pending_admission` relaxes exactly one rule: at stage `sequence_committed` with both
## receipts still null, this is the in-flight admission candidate the checkpoint preimage itself is
## about to mint a receipt for (a live DesktopConsequenceState may never carry this shape --
## `validate()` always calls with `allow_pending_admission=false`; only `checkpoint_content_
## preimage()`'s own admission-preimage branch calls with `true`).
static func _validate_pending(pending: Dictionary, allow_pending_admission: bool) -> Dictionary:
	var shape := _exact_keys(pending, _PENDING_KEYS, &"pending_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if str(pending["source_kind"]) not in SOURCE_KINDS:
		return _fail(&"consequence_source_kind_invalid", str(pending["source_kind"]), {})
	if not (pending["stage"] is StringName) and typeof(pending["stage"]) != TYPE_STRING:
		return _fail(&"pending_field_invalid", "stage must be a StringName", {})
	if String(pending["stage"]) not in ["action_prepared", "prepared_checkpointed", "sequence_committed", "publication_pending"]:
		return _fail(&"pending_stage_invalid", String(pending["stage"]), {})
	if typeof(pending["transaction_id"]) != TYPE_STRING or str(pending["transaction_id"]).strip_edges().is_empty():
		return _fail(&"pending_field_invalid", "transaction_id must be nonblank", {})
	if typeof(pending["transaction_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"pending_field_invalid", "transaction_issuer_receipt must be an object", {})
	if typeof(pending["source_commit_receipt_id"]) != TYPE_STRING or str(pending["source_commit_receipt_id"]).strip_edges().is_empty():
		return _fail(&"pending_field_invalid", "source_commit_receipt_id must be nonblank", {})
	if typeof(pending["source_commit_receipt_provenance"]) != TYPE_DICTIONARY:
		return _fail(&"pending_field_invalid", "source_commit_receipt_provenance must be an object", {})
	if typeof(pending["recovery_payload"]) != TYPE_DICTIONARY:
		return _fail(&"pending_field_invalid", "recovery_payload must be an object", {})
	if not _is_lowercase_sha256(pending["recovery_payload_sha256"]):
		return _fail(&"pending_field_invalid", "recovery_payload_sha256 must be lowercase sha256 hex", {})
	if _canonical_sha256(pending["recovery_payload"]) != str(pending["recovery_payload_sha256"]):
		return _fail(&"pending_recovery_payload_hash_mismatch", "", {})
	if typeof(pending["participant_receipts"]) != TYPE_DICTIONARY:
		return _fail(&"pending_field_invalid", "participant_receipts must be an object", {})
	var stage_string := String(pending["stage"])
	var pre_admission := stage_string in ["action_prepared", "prepared_checkpointed"]
	if pre_admission:
		if pending["admission_checkpoint_receipt"] != null:
			return _fail(&"pending_admission_receipt_forbidden",
				"admission_checkpoint_receipt must be null before sequence_committed", {})
		if pending["checkpoint_receipt"] != null:
			return _fail(&"pending_checkpoint_receipt_forbidden",
				"checkpoint_receipt must be null before admission", {})
	else:
		var is_in_flight_admission := allow_pending_admission and stage_string == "sequence_committed" \
			and pending["admission_checkpoint_receipt"] == null and pending["checkpoint_receipt"] == null
		if not is_in_flight_admission:
			if typeof(pending["admission_checkpoint_receipt"]) != TYPE_DICTIONARY:
				return _fail(&"pending_admission_receipt_required",
					"admission_checkpoint_receipt must be set once admitted", {})
			if typeof(pending["checkpoint_receipt"]) != TYPE_DICTIONARY:
				return _fail(&"pending_checkpoint_receipt_required", "checkpoint_receipt must be set once admitted", {})
	if stage_string == "publication_pending":
		if typeof(pending["publication_progress"]) != TYPE_DICTIONARY:
			return _fail(&"pending_publication_progress_required",
				"publication_progress must be set while publication_pending", {})
	else:
		if pending["publication_progress"] != null:
			return _fail(&"pending_publication_progress_forbidden",
				"publication_progress must be null outside publication_pending", {})
	if typeof(pending["expected_run_revision"]) != TYPE_INT or int(pending["expected_run_revision"]) < 0:
		return _fail(&"pending_field_invalid", "expected_run_revision must be a nonnegative integer", {})
	return {"ok": true}


static func _validate_outbox(outbox: Variant) -> Dictionary:
	if typeof(outbox) != TYPE_DICTIONARY:
		return _fail(&"outbox_invalid", "outbox must be an object", {})
	var value: Dictionary = outbox
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or str(key) not in OUTBOX_KINDS:
			return _fail(&"outbox_kind_invalid", str(key), {})
		if typeof(value[key]) != TYPE_DICTIONARY:
			return _fail(&"outbox_entry_invalid", str(key), {})
		var entry: Dictionary = value[key]
		var shape := _exact_keys(entry, _OUTBOX_ENTRY_KEYS, &"outbox_entry_member_set_invalid")
		if not shape.get("ok", false):
			return shape
		if str(entry["status"]) not in _OUTBOX_STATUSES:
			return _fail(&"outbox_status_invalid", str(entry["status"]), {})
	return {"ok": true}


static func _dup_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	return (value as Dictionary).duplicate(true)


static func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _canonical_sha256(value: Variant) -> String:
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


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
