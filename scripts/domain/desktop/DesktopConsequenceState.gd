class_name DesktopConsequenceState
extends RefCounted


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
	"causal_day_instance_issuer_receipt", "pending", "outbox", "shop_ledger",
]
const _ISSUER_PROVENANCE_KEYS: Array[String] = ["causal_day_instance", "causal_day_instance_issuer_receipt"]
const _ISSUER_RECEIPT_KEYS: Array[String] = ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]

const _SHOP_LEDGER_KEYS: Array[String] = [
	"supportz_branch_purchase_count", "supportz_last_purchase_causal_day_instance",
	"base_completion_receipts",
]
const _BASE_COMPLETION_RECEIPT_KEYS: Array[String] = ["kind", "app_round_ordinal", "causal_day_instance"]
const _BASE_COMPLETION_ORDINALS := [1, 2]

const _PENDING_KEYS: Array[String] = [
	"source_kind", "stage", "transaction_id", "transaction_issuer_receipt", "source_commit_receipt_id",
	"source_commit_receipt_provenance", "recovery_payload", "recovery_payload_sha256",
	"participant_receipts", "publication_progress", "destination_intent", "notification_intent",
	"admission_checkpoint_receipt", "checkpoint_receipt", "expected_run_revision",
]

const _OUTBOX_ENTRY_KEYS_LEGACY: Array[String] = ["consumer", "key", "payload_hash", "provenance", "status"]
const _OUTBOX_ENTRY_KEYS: Array[String] = [
	"action_receipt", "causal_sequence", "condition_receipt", "consumer", "key", "payload",
	"payload_hash", "provenance", "status",
]
const _OUTBOX_STATUSES: Array[String] = ["pending", "published"]

const _RECOVERY_PAYLOAD_KEYS_ACTION: Array[String] = [
	"source_kind", "action_receipt", "run_revision_before", "participant_snapshot_ids",
]
const _RECOVERY_PAYLOAD_KEYS_SCHEDULE: Array[String] = [
	"source_kind", "schedule_header", "run_revision_before", "participant_snapshot_ids",
]
const _RECOVERY_PAYLOAD_KEYS_ACTION_ADMISSION_READY: Array[String] = [
	"schema_version", "source_kind", "payload_phase", "action_candidate", "action_candidate_sha256",
	"condition_candidate", "condition_candidate_sha256", "board_candidate", "board_candidate_sha256",
	"schedule_view_before", "schedule_view_before_sha256", "schedule_view_after", "schedule_view_after_sha256",
	"consequence_candidate", "consequence_candidate_sha256", "publication_plan", "publication_plan_sha256",
	"causal_sequence_reservation_request", "causal_sequence_reservation_candidate",
	"destination_intent", "notification_intent",
]

var _run_revision: int = 0
var _causal_sequence: int = 0
var _causal_day_instance: String = ""
var _causal_day_instance_issuer_receipt: Dictionary = {}
var _pending: Variant = null
var _outbox: Dictionary = {}
var _command_receipts: Dictionary = {}
var _shop_ledger: Dictionary = _empty_shop_ledger()
var _proven_pending_payload_sha256: String = ""


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
	_shop_ledger = _empty_shop_ledger()
	_proven_pending_payload_sha256 = ""


static func _empty_shop_ledger() -> Dictionary:
	return {
		"supportz_branch_purchase_count": 0, "supportz_last_purchase_causal_day_instance": "",
		"base_completion_receipts": [],
	}



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
		"shop_ledger": _empty_shop_ledger(),
	}
	return {"ok": true, "code": &"ok", "value": {"state": state}, "receipt": {}}


static func validate(state: Dictionary, proven_recovery_payload_sha256: String = "") -> Dictionary:
	return _validate_impl(state, false, proven_recovery_payload_sha256)


static func _validate_for_preimage(state: Dictionary, proven_recovery_payload_sha256: String = "") -> Dictionary:
	return _validate_impl(state, true, proven_recovery_payload_sha256)


static func _validate_impl(state: Dictionary, allow_pending_admission: bool,
		proven_recovery_payload_sha256: String = "") -> Dictionary:
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
		var pending_check := _validate_pending(state["pending"] as Dictionary, allow_pending_admission,
			proven_recovery_payload_sha256)
		if not pending_check.get("ok", false):
			return pending_check
	var outbox_check := _validate_outbox(state["outbox"])
	if not outbox_check.get("ok", false):
		return outbox_check
	var shop_ledger_check := _validate_shop_ledger(state["shop_ledger"])
	if not shop_ledger_check.get("ok", false):
		return shop_ledger_check
	return {"ok": true, "code": &"ok", "value": {"state": state.duplicate(true)}, "receipt": {}}


static func validate_recovery_payload(source_kind: StringName, payload: Dictionary,
		expected_sha256: String) -> Dictionary:
	if not SOURCE_KINDS.has(String(source_kind)):
		return _fail(&"consequence_source_kind_invalid", String(source_kind), {})
	var is_admission_ready := String(source_kind) in ACTION_SOURCE_KINDS \
		and typeof(payload.get("payload_phase")) == TYPE_STRING and str(payload.get("payload_phase")) == "admission_ready"
	var expected_keys: Array
	if is_admission_ready:
		expected_keys = _RECOVERY_PAYLOAD_KEYS_ACTION_ADMISSION_READY
	elif String(source_kind) == "schedule_done":
		expected_keys = _RECOVERY_PAYLOAD_KEYS_SCHEDULE
	else:
		expected_keys = _RECOVERY_PAYLOAD_KEYS_ACTION
	var shape := _exact_keys(payload, expected_keys, &"recovery_payload_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if str(payload["source_kind"]) != String(source_kind):
		return _fail(&"recovery_payload_source_kind_mismatch", str(payload["source_kind"]), {})
	if is_admission_ready:
		if typeof(payload["schema_version"]) != TYPE_INT or int(payload["schema_version"]) != 1:
			return _fail(&"recovery_payload_field_invalid", "schema_version must be exactly 1", {})
	else:
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


static func checkpoint_content_preimage(checkpoint_header: Dictionary, stage_candidate: Dictionary,
		proven_recovery_payload_sha256: String = "") -> Dictionary:
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

	var candidate_validation := _validate_for_preimage(stage_candidate, proven_recovery_payload_sha256)
	if not candidate_validation.get("ok", false):
		return candidate_validation
	var candidate: Dictionary = (candidate_validation["value"] as Dictionary)["state"]
	if candidate["pending"] == null:
		return {"ok": true, "code": &"ok", "value": {"preimage": {
			"header": normalized_header,
			"stage_candidate": candidate,
		}}, "receipt": {}}
	var pending: Dictionary = candidate["pending"]
	pending["checkpoint_receipt"] = null
	var is_admission_preimage := str(pending["stage"]) == String(STAGE_SEQUENCE_COMMITTED) \
		and pending["admission_checkpoint_receipt"] == null
	if is_admission_preimage:
		pending.erase("admission_checkpoint_receipt")
	return {"ok": true, "code": &"ok", "value": {"preimage": {
		"header": normalized_header,
		"stage_candidate": candidate,
	}}, "receipt": {}}



func capture() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"state": _live_state()}, "receipt": {}}


func prepare_restore(state: Dictionary, proven_recovery_payload_sha256: String = "") -> Dictionary:
	var validated := validate(state, proven_recovery_payload_sha256)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"restore", "state_after": (validated["value"] as Dictionary)["state"],
		"proven_recovery_payload_sha256": proven_recovery_payload_sha256,
	}}, "receipt": {}}


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
		"transaction_id": str(pending["transaction_id"]),
		"request_fingerprint": _canonical_sha256({"request": request, "causal_sequence_receipt": causal_sequence_receipt}),
	}}, "receipt": {}}


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
		"transaction_id": str(action_receipt["transaction_id"]),
		"request_fingerprint": _canonical_sha256({
			"action_receipt": action_receipt, "expected_run_revision": expected_run_revision,
			"recovery_payload": recovery_payload,
		}),
	}}, "receipt": {}}


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
		"transaction_id": str(header["transaction_id"]),
		"request_fingerprint": _canonical_sha256({"header": header, "recovery_payload": recovery_payload}),
	}}, "receipt": {}}


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
		var plan_hash_check := _check_publication_plan_hash(pending, pending_after["publication_progress"])
		if not plan_hash_check.get("ok", false):
			return plan_hash_check
	elif String(expected_stage) == String(STAGE_PUBLICATION_PENDING) and next_stage != null \
			and String(next_stage) == String(STAGE_PUBLICATION_PENDING):
		var progress_check: Variant = _validate_publication_progress_shape(publication_progress)
		if progress_check == null:
			return _fail(&"consequence_publication_progress_invalid", "publication_progress is required for callback progress", {})
		var plan_hash_check2 := _check_publication_plan_hash(pending, progress_check)
		if not plan_hash_check2.get("ok", false):
			return plan_hash_check2
		pending_after["publication_progress"] = progress_check
	elif String(expected_stage) == String(STAGE_PUBLICATION_PENDING) and next_stage == null:
		var complete_progress: Variant = pending["publication_progress"]
		if typeof(complete_progress) != TYPE_DICTIONARY:
			return _fail(&"consequence_publication_cursor_incomplete",
				"terminal cleanup requires a complete publication cursor", {})
		var complete_dict: Dictionary = complete_progress
		var is_complete: bool = int(complete_dict["next_callback_index"]) >= (complete_dict["callback_ids"] as Array).size()
		if not is_complete:
			return _fail(&"consequence_publication_cursor_incomplete",
				"terminal cleanup requires a complete publication cursor", {})
		var state_after := _live_state()
		var retained := _retain_pending_intents(pending, state_after)
		if not retained.get("ok", false):
			return retained
		state_after = retained["value"]["state"]
		state_after["pending"] = null
		return {"ok": true, "code": &"ok", "value": {
			"checkpoint_header": {
				"kind": &"consequence_cleanup", "transaction_id": transaction_id,
				"stage": String(STAGE_PUBLICATION_PENDING),
				"operation_ordinal": 12,
				"run_id": "",
				"source_ids": [transaction_id],
			},
			"proven_recovery_payload_sha256": _proven_pending_payload_sha256,
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
			"stage": String(pending_after["stage"]),
			"operation_ordinal": _operation_ordinal(
				str(pending["source_kind"]), expected_stage, next_stage, publication_progress),
			"run_id": "",
			"source_ids": [transaction_id],
		},
		"proven_recovery_payload_sha256": _proven_pending_payload_sha256,
		"stage_candidate": state_after2,
	}, "receipt": {}}


static func _operation_ordinal(source_kind: String, expected_stage: StringName, next_stage: Variant,
		publication_progress: Variant) -> int:
	var is_action := source_kind in ACTION_SOURCE_KINDS
	if String(expected_stage) == String(STAGE_SEQUENCE_COMMITTED) and String(next_stage) == String(STAGE_PUBLICATION_PENDING):
		return 8 if is_action else 6
	if String(expected_stage) == String(STAGE_PUBLICATION_PENDING) and next_stage != null \
			and String(next_stage) == String(STAGE_PUBLICATION_PENDING):
		var progress: Dictionary = publication_progress as Dictionary
		var base := 9 if is_action else 7
		return base + int(progress.get("next_callback_index", 1)) - 1
	return 0


static func _check_publication_plan_hash(pending: Dictionary, progress: Dictionary) -> Dictionary:
	var recovery_payload: Dictionary = pending.get("recovery_payload", {})
	var expected: Variant = recovery_payload.get("publication_plan_sha256")
	if typeof(expected) != TYPE_STRING:
		return {"ok": true}
	if str(expected) != str(progress.get("publication_plan_sha256", "")):
		return _fail(&"consequence_publication_plan_hash_mismatch",
			"publication_progress.publication_plan_sha256 does not match the admitted publication_plan_sha256", {})
	return {"ok": true}


const CHECKPOINT_ORDINAL_STAGE_LAW: Dictionary = {
	0: "action_prepared", 1: "action_prepared", 2: "sequence_committed",
	8: "publication_pending", 9: "publication_pending", 10: "publication_pending",
	11: "publication_pending", 12: "publication_pending",
}


static func validate_checkpoint_ordinal_stage(operation_ordinal: int, stage: String) -> Dictionary:
	var expected: Variant = CHECKPOINT_ORDINAL_STAGE_LAW.get(operation_ordinal)
	if expected == null or stage != String(expected):
		return _fail(&"consequence_checkpoint_ordinal_stage_invalid",
			"operation_ordinal %d must pair with stage %s" % [operation_ordinal, str(expected)],
			{"operation_ordinal": operation_ordinal, "stage": stage})
	return {"ok": true}


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


func _retain_pending_intents(pending: Dictionary, state_after: Dictionary) -> Dictionary:
	var outbox: Dictionary = (state_after["outbox"] as Dictionary).duplicate(true)
	var pairs := [
		{"slot": "hospital", "intent": pending.get("destination_intent")},
		{"slot": "notification", "intent": pending.get("notification_intent")},
	]
	for pair: Dictionary in pairs:
		var raw: Variant = pair["intent"]
		if raw == null:
			continue
		if typeof(raw) != TYPE_DICTIONARY:
			return _fail(&"outbox_intent_invalid", str(pair["slot"]), {})
		var built := _durable_outbox_record(str(pair["slot"]), raw as Dictionary, pending)
		if not built.get("ok", false):
			return built
		var record: Dictionary = built["value"]["record"]
		var occupied: Variant = outbox.get(str(pair["slot"]))
		if typeof(occupied) == TYPE_DICTIONARY and occupied != record \
				and str(occupied.get("status", "")) != "published":
			return _fail(&"outbox_slot_occupied", str(pair["slot"]), {})
		outbox[str(pair["slot"])] = record
	var detached := state_after.duplicate(true)
	detached["outbox"] = outbox
	return {"ok": true, "code": &"ok", "value": {"state": detached}, "receipt": {}}


func _durable_outbox_record(slot: String, intent: Dictionary, pending: Dictionary) -> Dictionary:
	var intent_id := str(intent.get("intent_id", ""))
	var provenance: Variant = intent.get("intent_id_provenance")
	if intent_id.strip_edges().is_empty() or typeof(provenance) != TYPE_DICTIONARY:
		return _fail(&"outbox_intent_invalid", slot, {})
	var recovery: Dictionary = pending.get("recovery_payload", {})
	var action_receipt: Variant = recovery.get("action_receipt")
	if typeof(action_receipt) != TYPE_DICTIONARY:
		for raw_recipe: Variant in (recovery.get("publication_plan", []) as Array):
			if typeof(raw_recipe) != TYPE_DICTIONARY:
				continue
			var recipe: Dictionary = raw_recipe
			if str(recipe.get("participant", "")) == "action_source" \
					and typeof(recipe.get("publication")) == TYPE_DICTIONARY:
				action_receipt = (recipe["publication"] as Dictionary).get("action_receipt")
				break
	if typeof(action_receipt) != TYPE_DICTIONARY:
		return _fail(&"outbox_action_receipt_missing", intent_id, {})
	var condition_receipt: Variant = recovery.get("condition_candidate")
	if typeof(condition_receipt) != TYPE_DICTIONARY:
		condition_receipt = {
			"receipt_id": str(intent.get("source_condition_receipt_id", "")),
			"receipt_provenance": (intent.get("source_condition_receipt_provenance", {}) as Dictionary).duplicate(true),
		}
	if str((condition_receipt as Dictionary).get("receipt_id", "")).strip_edges().is_empty():
		return _fail(&"outbox_condition_receipt_missing", intent_id, {})
	var consumer := "desktop_notification"
	if slot == "hospital":
		consumer = "condition_hospital" if str(intent.get("kind", "")) == "hospital_day" \
			else "day7_terminal"
	var record := {
		"action_receipt": (action_receipt as Dictionary).duplicate(true),
		"causal_sequence": _causal_sequence,
		"condition_receipt": (condition_receipt as Dictionary).duplicate(true),
		"consumer": consumer,
		"key": intent_id,
		"payload": intent.duplicate(true),
		"payload_hash": _canonical_sha256(intent),
		"provenance": (provenance as Dictionary).duplicate(true),
		"status": "pending",
	}
	return {"ok": true, "code": &"ok", "value": {"record": record}, "receipt": {}}


func prepare_record_base_completion(receipt: Dictionary) -> Dictionary:
	var receipt_check := _validate_base_completion_receipt(receipt)
	if not receipt_check.get("ok", false):
		return receipt_check
	var normalized := {
		"kind": "complete", "app_round_ordinal": int(receipt["app_round_ordinal"]),
		"causal_day_instance": str(receipt["causal_day_instance"]),
	}
	var existing: Array = (_shop_ledger["base_completion_receipts"] as Array).duplicate(true)
	if not existing.has(normalized):
		existing.append(normalized)
	var state_after := _live_state()
	(state_after["shop_ledger"] as Dictionary)["base_completion_receipts"] = existing
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"shop_ledger_base_completion", "state_after": state_after,
	}}, "receipt": {}}


func prepare_record_supportz_purchase(transaction_id: String, causal_day_instance: String) -> Dictionary:
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonblank", {})
	if causal_day_instance.strip_edges().is_empty():
		return _fail(&"invalid_causal_day_instance", "causal_day_instance must be nonblank", {})
	var state_after := _live_state()
	var ledger: Dictionary = state_after["shop_ledger"]
	ledger["supportz_branch_purchase_count"] = int(ledger["supportz_branch_purchase_count"]) + 1
	ledger["supportz_last_purchase_causal_day_instance"] = causal_day_instance
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"shop_ledger_supportz_purchase", "state_after": state_after,
		"transaction_id": transaction_id,
		"request_fingerprint": _canonical_sha256({"causal_day_instance": causal_day_instance}),
	}}, "receipt": {}}


func supportz_eligibility_state(causal_day_instance: String) -> Dictionary:
	if causal_day_instance.strip_edges().is_empty():
		return _fail(&"invalid_causal_day_instance", "causal_day_instance must be nonblank", {})
	var projected: Array = []
	for entry: Variant in (_shop_ledger["base_completion_receipts"] as Array):
		var record: Dictionary = entry
		projected.append({
			"kind": str(record["kind"]), "app_round_ordinal": int(record["app_round_ordinal"]),
			"causal_day_instance": str(record["causal_day_instance"]),
		})
	return {"ok": true, "code": &"ok", "value": {"state": {
		"causal_day_instance": causal_day_instance,
		"completion_receipts": projected,
		"branch_purchase_count": int(_shop_ledger["supportz_branch_purchase_count"]),
		"daily_purchase_done": str(_shop_ledger["supportz_last_purchase_causal_day_instance"]) == causal_day_instance,
	}}, "receipt": {}}



func commit(candidate: Dictionary) -> Dictionary:
	if not candidate.has("kind") or not (candidate["kind"] is StringName):
		return _fail(&"invalid_candidate", "candidate.kind is required", {})
	var kind: StringName = candidate["kind"]
	if kind == &"restore":
		if typeof(candidate.get("state_after")) != TYPE_DICTIONARY:
			return _fail(&"invalid_candidate", "restore candidate.state_after is required", {})
		_adopt_state(candidate["state_after"], str(candidate.get("proven_recovery_payload_sha256", "")))
		return _live_view()
	if typeof(candidate.get("state_after")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate.state_after is required", {})

	var ledger_key := _ledger_key(candidate)
	if not ledger_key.is_empty():
		var request_fingerprint := str(candidate.get("request_fingerprint", ""))
		if _command_receipts.has(ledger_key):
			var recorded: Dictionary = _command_receipts[ledger_key]
			if str(recorded["request_fingerprint"]) == request_fingerprint:
				return (recorded["result"] as Dictionary).duplicate(true)
			return _fail(&"consequence_command_conflict",
				"this transaction's operation was already committed with different bytes", {"key": ledger_key})

	if candidate.has("pre_run_revision") and int(candidate["pre_run_revision"]) != _run_revision:
		return _fail(&"stale_run_revision",
			"the candidate was prepared against a different run_revision than the current one",
			{"expected": _run_revision, "candidate_pre_run_revision": candidate["pre_run_revision"]})
	_adopt_state(candidate["state_after"], str(candidate.get("proven_recovery_payload_sha256", "")))
	var result := _live_view()
	if not ledger_key.is_empty():
		_command_receipts[ledger_key] = {
			"request_fingerprint": str(candidate.get("request_fingerprint", "")),
			"result": result.duplicate(true),
		}
	return result


static func _ledger_key(candidate: Dictionary) -> String:
	var transaction_id := str(candidate.get("transaction_id", ""))
	if transaction_id.is_empty():
		return ""
	return transaction_id + "@" + String(candidate["kind"])


func rollback(backup: Dictionary) -> Dictionary:
	if typeof(backup.get("state")) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup.state is required", {})
	_adopt_state(backup["state"])
	_proven_pending_payload_sha256 = ""
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func _adopt_state(state: Dictionary, proven_recovery_payload_sha256: String = "") -> void:
	_run_revision = int(state["run_revision"])
	_causal_sequence = int(state["causal_sequence"])
	_causal_day_instance = str(state["causal_day_instance"])
	_causal_day_instance_issuer_receipt = (state["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	_pending = _dup_or_null(state["pending"])
	_outbox = (state["outbox"] as Dictionary).duplicate(true)
	_shop_ledger = (state["shop_ledger"] as Dictionary).duplicate(true)
	if _pending == null:
		_proven_pending_payload_sha256 = ""
	elif not proven_recovery_payload_sha256.is_empty():
		_proven_pending_payload_sha256 = proven_recovery_payload_sha256
	elif str((_pending as Dictionary).get("recovery_payload_sha256", "")) != _proven_pending_payload_sha256:
		_proven_pending_payload_sha256 = ""



func _live_state() -> Dictionary:
	return {
		"schema_version": 1, "run_revision": _run_revision, "causal_sequence": _causal_sequence,
		"causal_day_instance": _causal_day_instance,
		"causal_day_instance_issuer_receipt": _causal_day_instance_issuer_receipt.duplicate(true),
		"pending": _dup_or_null(_pending), "outbox": _outbox.duplicate(true),
		"shop_ledger": _shop_ledger.duplicate(true),
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
	if keys != ["callback_ids", "callback_receipts", "next_callback_index", "publication_plan_sha256"]:
		return null
	if typeof(value["publication_plan_sha256"]) != TYPE_STRING or not _is_lowercase_sha256(str(value["publication_plan_sha256"])):
		return null
	if typeof(value["callback_ids"]) != TYPE_ARRAY:
		return null
	for callback_id: Variant in (value["callback_ids"] as Array):
		if typeof(callback_id) != TYPE_STRING:
			return null
	if typeof(value["next_callback_index"]) != TYPE_INT or int(value["next_callback_index"]) < 0 \
			or int(value["next_callback_index"]) > (value["callback_ids"] as Array).size():
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


static func _validate_pending(pending: Dictionary, allow_pending_admission: bool,
		proven_recovery_payload_sha256: String = "") -> Dictionary:
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
	if proven_recovery_payload_sha256.is_empty() \
			or proven_recovery_payload_sha256 != str(pending["recovery_payload_sha256"]):
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
		var keys: Array = entry.keys()
		keys.sort()
		if keys != _OUTBOX_ENTRY_KEYS_LEGACY and keys != _OUTBOX_ENTRY_KEYS:
			return _fail(&"outbox_entry_member_set_invalid", "unexpected outbox entry members", {})
		if str(entry["status"]) not in _OUTBOX_STATUSES:
			return _fail(&"outbox_status_invalid", str(entry["status"]), {})
		if keys == _OUTBOX_ENTRY_KEYS:
			if typeof(entry["payload"]) != TYPE_DICTIONARY \
					or typeof(entry["action_receipt"]) != TYPE_DICTIONARY \
					or typeof(entry["condition_receipt"]) != TYPE_DICTIONARY \
					or typeof(entry["causal_sequence"]) != TYPE_INT:
				return _fail(&"outbox_entry_invalid", "a durable outbox record retains its causal payload and receipts", {})
			if str(entry["payload_hash"]) != _canonical_sha256(entry["payload"]):
				return _fail(&"outbox_payload_hash_mismatch", str(entry["key"]), {})
	return {"ok": true}


static func _validate_shop_ledger(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(&"shop_ledger_invalid", "shop_ledger must be an object", {})
	var shape := _exact_keys(value, _SHOP_LEDGER_KEYS, &"shop_ledger_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	var ledger: Dictionary = value
	if typeof(ledger["supportz_branch_purchase_count"]) != TYPE_INT \
			or int(ledger["supportz_branch_purchase_count"]) < 0:
		return _fail(&"shop_ledger_field_invalid",
			"supportz_branch_purchase_count must be a nonnegative integer", {})
	if typeof(ledger["supportz_last_purchase_causal_day_instance"]) != TYPE_STRING:
		return _fail(&"shop_ledger_field_invalid",
			"supportz_last_purchase_causal_day_instance must be a string", {})
	if typeof(ledger["base_completion_receipts"]) != TYPE_ARRAY:
		return _fail(&"shop_ledger_field_invalid", "base_completion_receipts must be an array", {})
	for entry: Variant in (ledger["base_completion_receipts"] as Array):
		var receipt_check := _validate_base_completion_receipt(entry)
		if not receipt_check.get("ok", false):
			return receipt_check
	return {"ok": true}


static func _validate_base_completion_receipt(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return _fail(&"base_completion_receipt_invalid", "every base completion receipt must be an object", {})
	var shape := _exact_keys(entry, _BASE_COMPLETION_RECEIPT_KEYS, &"base_completion_receipt_invalid")
	if not shape.get("ok", false):
		return shape
	var receipt: Dictionary = entry
	if str(receipt["kind"]) != "complete":
		return _fail(&"base_completion_receipt_invalid", "kind must be complete", {})
	if typeof(receipt["app_round_ordinal"]) != TYPE_INT \
			or not _BASE_COMPLETION_ORDINALS.has(int(receipt["app_round_ordinal"])):
		return _fail(&"base_completion_receipt_invalid", "app_round_ordinal must be 1 or 2", {})
	if typeof(receipt["causal_day_instance"]) != TYPE_STRING \
			or str(receipt["causal_day_instance"]).strip_edges().is_empty():
		return _fail(&"base_completion_receipt_invalid", "causal_day_instance must be nonblank", {})
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
