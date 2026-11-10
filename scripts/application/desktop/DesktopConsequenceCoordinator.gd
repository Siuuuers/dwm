class_name DesktopConsequenceCoordinator
extends RefCounted


const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _GATE_OWNER := &"causal_transaction"
const _ACTION_SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]
const _SOURCE_RECOVERY_METHODS: Array[String] = [
	"validate_recovery_action", "commit_recovery_action", "publish_recovery_action", "release_recovery_lease",
]
const _ACCEPT_REQUEST_KEYS: Array[String] = [
	"action_receipt", "action_candidate", "prepared_checkpoint_receipt", "expected_run_revision",
	"expected_board_identity", "expected_board_revision",
]

const _DESTINATION_INTENT_KEYS: Array[String] = [
	"intent_id", "intent_id_provenance", "kind", "day", "causal_day_instance",
	"source_condition_receipt_id", "source_condition_receipt_provenance",
	"accepted_unfulfilled_sources", "terminal_cause", "terminal_provenance", "prerequisite_receipt_ids",
]
const _DESTINATION_INTENT_KINDS: Array[String] = ["hospital_day", "day7_terminal"]
const _NOTIFICATION_INTENT_KEYS: Array[String] = [
	"intent_id", "intent_id_provenance", "action_kind", "action_commit_receipt_id",
	"action_commit_receipt_provenance", "source_condition_receipt_id", "source_condition_receipt_provenance",
]
const _NOTIFICATION_INTENT_ACTION_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]
const _ORDINAL_STAGE_LAW: Dictionary = {1: "action_prepared", 2: "sequence_committed"}

var _state_port: Object = null
var _causal_sequence_port: Object = null
var _board_fate_port: Object = null
var _checkpoint_port: Object = null
var _mutation_gate: ApplicationMutationGate = null
var _identity_issuer: Object = null

var _minesweeper_round_source_port: Object = null
var _shop_purchase_source_port: Object = null
var _condition_policy_port: Object = null
var _schedule_view_port: Object = null
var _notification_consumer := Callable()
var _notification_publisher := Callable()
var _completion_checkpoint_capture := Callable()
var _completion_checkpoints: Dictionary = {}
var _recovery_gate_token := ""

var _accepted: Dictionary = {}

var _committed_condition_receipts: Dictionary = {}

var _profile_enabled: bool = false


func _init() -> void:
	_profile_enabled = OS.get_environment("DWM_CONSEQUENCE_PROFILE") == "1"



func configure(state_port: Object, causal_sequence_port: Object, board_fate_port: Object,
		checkpoint_port: Object, mutation_gate: ApplicationMutationGate) -> Dictionary:
	if state_port == null or not _has_all_methods(state_port, ["capture", "prepare_restore", "commit",
			"prepare_recovery_advance", "prepare_sequence_reservation"]):
		return _fail(&"invalid_state_port", "an exact consequence-state capability is required", {})
	if causal_sequence_port == null or not _has_all_methods(causal_sequence_port,
			["prepare_reservation", "prepare_admission", "commit", "rollback", "publish"]):
		return _fail(&"invalid_causal_sequence_port", "an exact causal-sequence-port capability is required", {})
	if board_fate_port == null or not _has_all_methods(board_fate_port, ["prepare_causal_departure",
			"prepare_projected_causal_departure", "capture", "commit", "rollback", "publish"]):
		return _fail(&"invalid_board_fate_port", "an exact board-fate-port capability is required", {})
	if checkpoint_port == null or not _has_all_methods(checkpoint_port,
			["prepare_consequence_checkpoint", "commit_consequence_checkpoint"]):
		return _fail(&"invalid_checkpoint_port", "an exact checkpoint-port capability is required", {})
	if mutation_gate == null:
		return _fail(&"invalid_mutation_gate", "mutation_gate is required", {})
	if _state_port != null or _causal_sequence_port != null or _board_fate_port != null \
			or _checkpoint_port != null or _mutation_gate != null:
		if _state_port != state_port or _causal_sequence_port != causal_sequence_port \
				or _board_fate_port != board_fate_port or _checkpoint_port != checkpoint_port \
				or _mutation_gate != mutation_gate:
			return _fail(&"consequence_coordinator_already_configured",
				"a configured coordinator never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_state_port = state_port
	_causal_sequence_port = causal_sequence_port
	_board_fate_port = board_fate_port
	_checkpoint_port = checkpoint_port
	_mutation_gate = mutation_gate
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func configure_notification_consumer(consumer: Callable, publisher: Callable) -> Dictionary:
	if not consumer.is_valid() or not publisher.is_valid(): return _fail(&"invalid_notification_consumer", "", {})
	if _notification_consumer.is_valid() and (_notification_consumer != consumer or _notification_publisher != publisher):
		return _fail(&"notification_consumer_already_configured", "", {})
	_notification_consumer = consumer
	_notification_publisher = publisher
	return {"ok": true}


func configure_completion_checkpoint_capture(capture_inputs: Callable) -> Dictionary:
	if not capture_inputs.is_valid() or _checkpoint_port == null \
			or not _has_all_methods(_checkpoint_port, ["prepare", "commit"]):
		return _fail(&"invalid_completion_checkpoint_capture", "a full checkpoint capture and port are required", {})
	if _completion_checkpoint_capture.is_valid() and _completion_checkpoint_capture != capture_inputs:
		return _fail(&"completion_checkpoint_capture_already_configured", "the retained capture cannot be replaced", {})
	_completion_checkpoint_capture = capture_inputs
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func configure_action_source_ports(minesweeper_round_source_port: Object,
		shop_purchase_source_port: Object) -> Dictionary:
	if minesweeper_round_source_port == null \
			or not _has_all_methods(minesweeper_round_source_port, _SOURCE_RECOVERY_METHODS):
		return _fail(&"invalid_minesweeper_round_source_port",
			"an exact recovery-method capability is required", {})
	if shop_purchase_source_port == null \
			or not _has_all_methods(shop_purchase_source_port, _SOURCE_RECOVERY_METHODS):
		return _fail(&"invalid_shop_purchase_source_port",
			"an exact recovery-method capability is required", {})
	if minesweeper_round_source_port == shop_purchase_source_port:
		return _fail(&"action_source_ports_must_be_distinct",
			"one object may not claim both source-kind roles", {})
	if _minesweeper_round_source_port != null or _shop_purchase_source_port != null:
		if _minesweeper_round_source_port != minesweeper_round_source_port \
				or _shop_purchase_source_port != shop_purchase_source_port:
			return _fail(&"action_source_ports_already_configured",
				"configured source ports never adopt a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"configured": true, "already_configured": true}, "receipt": {}}
	_minesweeper_round_source_port = minesweeper_round_source_port
	_shop_purchase_source_port = shop_purchase_source_port
	return {"ok": true, "code": &"ok", "value": {"configured": true, "already_configured": false}, "receipt": {}}


func configure_condition_departure_ports(condition_policy_port: Object, schedule_view_port: Object) -> Dictionary:
	if _minesweeper_round_source_port == null or _shop_purchase_source_port == null:
		return _fail(&"action_source_ports_unconfigured", "configure_action_source_ports() is required first", {})
	if condition_policy_port == null or not condition_policy_port.has_method("evaluate"):
		return _fail(&"invalid_condition_policy_port", "an exact evaluate() capability is required", {})
	if schedule_view_port == null or not _has_all_methods(schedule_view_port,
			["prepare_condition_departure", "commit_condition_departure"]):
		return _fail(&"invalid_schedule_view_port", "an exact ScheduleView-departure capability is required", {})
	if _condition_policy_port != null or _schedule_view_port != null:
		if _condition_policy_port != condition_policy_port or _schedule_view_port != schedule_view_port:
			return _fail(&"condition_departure_ports_already_configured",
				"a configured departure seam never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_condition_policy_port = condition_policy_port
	_schedule_view_port = schedule_view_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func configure_identity_issuer(identity_issuer: Object) -> Dictionary:
	if identity_issuer == null or not identity_issuer.has_method("derive_child"):
		return _fail(&"invalid_identity_issuer", "an exact anchored-child-derivation capability is required", {})
	if _identity_issuer != null:
		if _identity_issuer != identity_issuer:
			return _fail(&"identity_issuer_already_configured",
				"a configured identity issuer never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


@warning_ignore("unused_parameter")
func configure_schedule_departure_ports(schedule_port: Object, day_start_port: Object,
		schedule_view_port: Object, terminal_intent_port: Object,
		publication_port: Object) -> Dictionary:
	return _fail(&"not_configured",
		"the Schedule-departure extension is Plan 03 Task 6 work; this Ruling 18-A stub binds nothing",
		{})


@warning_ignore("unused_parameter")
func request_schedule_departure(raw_request: Dictionary) -> Dictionary:
	return _fail(&"not_configured",
		"request_schedule_departure requires the Task-6 Schedule-departure composition",
		{})


func committed_condition_receipt(causal_day_instance: String) -> Dictionary:
	var receipt: Variant = _committed_condition_receipts.get(causal_day_instance)
	return (receipt as Dictionary).duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else {}



func accept_prepared_action(request: Dictionary) -> Dictionary:
	var profile_tick := _settlement_profile_start()
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var shape := _exact_keys(request, _ACCEPT_REQUEST_KEYS, &"accept_prepared_action_request_invalid")
	if not shape.get("ok", false):
		return shape

	var receipt_valid := _ACTION_RECEIPT.validate(request["action_receipt"])
	if not receipt_valid.get("ok", false):
		return receipt_valid
	var action_receipt: Dictionary = (receipt_valid["value"] as Dictionary)["receipt"]
	var source_kind := str(action_receipt["action_kind"])
	if source_kind not in _ACTION_SOURCE_KINDS:
		return _fail(&"action_source_kind_invalid", source_kind, {})
	var transaction_id := str(action_receipt["transaction_id"])
	var request_fingerprint := _canonical_sha256(request)
	profile_tick = _settlement_profile_phase("accept", "request_fingerprint", profile_tick)

	if _accepted.has(transaction_id):
		var recorded: Dictionary = _accepted[transaction_id]
		if str(recorded["request_fingerprint"]) == request_fingerprint:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"action_receipt_conflict",
			"this action/transaction identity was already accepted with different bytes", {})

	if not bool(_mutation_gate.is_internal_owner_active(_GATE_OWNER)):
		return _fail(&"causal_transaction_lease_required",
			"accept_prepared_action requires the source participant to already hold the causal_transaction lease", {})

	if _condition_policy_port == null or _schedule_view_port == null:
		var abandoned := _abandon_pre_admission(transaction_id, source_kind)
		if not abandoned.get("ok", false):
			return abandoned
		return _fail(&"condition_departure_ports_unconfigured",
			"configure_condition_departure_ports() is required before admission", {})
	if _identity_issuer == null:
		return _fail(&"identity_issuer_unconfigured",
			"configure_identity_issuer() is required before admission", {})

	var captured: Dictionary = _state_port.call(&"capture")
	if not captured.get("ok", false):
		return captured
	var live_state: Dictionary = (captured["value"] as Dictionary)["state"]
	var pending: Variant = live_state.get("pending")
	if pending == null or str((pending as Dictionary).get("transaction_id", "")) != transaction_id \
			or str((pending as Dictionary).get("source_kind", "")) != source_kind:
		return _fail(&"consequence_no_matching_pending_transaction",
			"accept_prepared_action requires a matching action_prepared pending transaction", {})
	var pending_dict: Dictionary = pending

	var recovery_payload_so_far: Variant = pending_dict.get("recovery_payload")
	var already_admission_ready: bool = typeof(recovery_payload_so_far) == TYPE_DICTIONARY \
		and str((recovery_payload_so_far as Dictionary).get("payload_phase", "")) == "admission_ready"

	var result: Dictionary
	profile_tick = _settlement_profile_phase("accept", "admission_checks", profile_tick)
	if str(pending_dict["stage"]) == "action_prepared" and not already_admission_ready:
		result = _prepare_and_admit(action_receipt, source_kind, transaction_id, request, live_state, pending_dict)
	elif str(pending_dict["stage"]) == "action_prepared" and already_admission_ready:
		result = _resume_and_admit(action_receipt, source_kind, transaction_id, pending_dict)
	else:
		result = _resume_forward(action_receipt, source_kind, transaction_id, live_state, pending_dict)

	if bool(result.get("ok", false)):
		_accepted[transaction_id] = {"request_fingerprint": request_fingerprint, "result": result.duplicate(true)}
	_settlement_profile_phase("accept", "prepare_and_forward_inclusive", profile_tick)
	return result


func _abandon_pre_admission(transaction_id: String, source_kind: String) -> Dictionary:
	var captured: Dictionary = _state_port.call(&"capture")
	if not captured.get("ok", false):
		return captured
	var live_state: Dictionary = (captured["value"] as Dictionary)["state"]
	var pending: Variant = live_state.get("pending")
	if pending == null or str((pending as Dictionary).get("transaction_id", "")) != transaction_id \
			or str((pending as Dictionary).get("source_kind", "")) != source_kind:
		return _fail(&"consequence_no_matching_pending_transaction",
			"pre-admission abandonment requires a matching pending transaction", {})
	if str((pending as Dictionary).get("stage", "")) != "action_prepared":
		return _fail(&"consequence_abandon_requires_pre_admission_stage",
			"pre-admission abandonment requires an unadmitted pending transaction",
			{"stage": str((pending as Dictionary).get("stage", ""))})

	if _checkpoint_port.has_method("abandon_pending_consequence_checkpoint"):
		var checkpoint_abandoned: Dictionary = _checkpoint_port.call(&"abandon_pending_consequence_checkpoint", transaction_id)
		if not checkpoint_abandoned.get("ok", false):
			return checkpoint_abandoned

	var state_after: Dictionary = live_state.duplicate(true)
	state_after["pending"] = null
	var prepared: Dictionary = _state_port.call(&"prepare_restore", state_after)
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = _state_port.call(&"commit", (prepared["value"] as Dictionary)["candidate"])
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "code": &"consequence_pre_admission_abandoned",
		"value": {"transaction_id": transaction_id, "source_kind": source_kind}, "receipt": {}}


func _prepare_and_admit(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		request: Dictionary, live_state: Dictionary, pending_dict: Dictionary) -> Dictionary:
	var profile_tick := _settlement_profile_start()
	var prepared_checkpoint_receipt: Dictionary = request["prepared_checkpoint_receipt"]
	if typeof(prepared_checkpoint_receipt) != TYPE_DICTIONARY or prepared_checkpoint_receipt.is_empty():
		return _fail(&"invalid_prepared_checkpoint_receipt", "prepared_checkpoint_receipt must be a nonempty object", {})

	var action_candidate: Dictionary = request["action_candidate"]
	var reservation_request := {
		"branch_id": str(action_receipt["branch_id"]), "causal_day_instance": str(action_receipt["causal_day_instance"]),
		"desktop_timeline_generation": int(action_receipt["desktop_timeline_generation"]),
		"expected_last_sequence": int(live_state["causal_sequence"]),
		"expected_run_revision": int(request["expected_run_revision"]),
		"run_id": str(action_receipt["run_id"]), "source_commit_receipt_id": str(action_receipt["commit_receipt_id"]),
		"source_commit_receipt_provenance": (action_receipt["commit_receipt_provenance"] as Dictionary).duplicate(true),
		"source_kind": source_kind, "transaction_id": transaction_id,
		"transaction_issuer_receipt": (action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
	}
	var reserved: Dictionary = _causal_sequence_port.call(&"prepare_reservation", reservation_request)
	if not reserved.get("ok", false):
		return reserved
	var causal_sequence_receipt: Dictionary = reserved["value"]["causal_sequence_receipt"]
	var sequence_candidate: Dictionary = reserved["value"]["sequence_candidate"]
	profile_tick = _settlement_profile_phase("prepare", "reservation", profile_tick)

	var condition_evaluated: Dictionary = _condition_policy_port.call(&"evaluate", {
		"action_receipt": action_receipt, "causal_sequence_receipt": causal_sequence_receipt,
	})
	if not condition_evaluated.get("ok", false):
		return condition_evaluated
	var condition_value: Dictionary = condition_evaluated["value"]
	var condition_receipt: Dictionary = condition_value["condition_receipt"]
	var is_departure := str(condition_receipt["decision"]) != "no_departure"

	var destination_intent: Variant = condition_value.get("destination_intent")
	var notification_intent: Variant = condition_value.get("notification_intent")
	var intent_pairing := _validate_intent_pairing(is_departure, destination_intent, notification_intent)
	if not intent_pairing.get("ok", false):
		return intent_pairing

	var board_fate_receipt: Variant = null
	var board_candidate: Variant = null
	var schedule_view_before: Variant = null
	var schedule_view_after: Variant = null
	var schedule_view_before_sha256: Variant = null
	var schedule_view_after_sha256: Variant = null
	profile_tick = _settlement_profile_phase("prepare", "condition_policy", profile_tick)
	if is_departure:
		var projected := _build_projected_board_candidate(source_kind, action_receipt, action_candidate)
		if not projected.get("ok", false):
			return projected
		var projected_board_candidate: Dictionary = (projected["value"] as Dictionary)["board_candidate"]
		var departure_request := {
			"command_id": transaction_id,
			"command_issuer_receipt": (action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
			"run_id": str(action_receipt["run_id"]), "branch_id": str(action_receipt["branch_id"]),
			"causal_day_instance": str(action_receipt["causal_day_instance"]), "reason": "condition_departure",
			"expected_board_identity": request["expected_board_identity"],
			"expected_board_revision": int(request["expected_board_revision"]),
			"source_action_receipt": action_receipt, "projected_board_candidate": projected_board_candidate,
			"projected_board_candidate_sha256": _canonical_sha256(projected_board_candidate),
		}
		var fate_prepared: Dictionary = _board_fate_port.call(&"prepare_projected_causal_departure", departure_request)
		if not fate_prepared.get("ok", false):
			return fate_prepared
		board_candidate = fate_prepared["value"]["board_candidate"]
		board_fate_receipt = fate_prepared["value"]["board_fate_receipt"]

		var view_prepared: Dictionary = _schedule_view_port.call(&"prepare_condition_departure", {
			"condition_receipt": condition_receipt, "causal_sequence_receipt": causal_sequence_receipt,
		})
		if not view_prepared.get("ok", false):
			return view_prepared
		schedule_view_before = view_prepared["value"]["schedule_view_before"]
		schedule_view_after = view_prepared["value"]["schedule_view_after"]
		schedule_view_before_sha256 = _canonical_sha256(schedule_view_before)
		schedule_view_after_sha256 = _canonical_sha256(schedule_view_after)

	profile_tick = _settlement_profile_phase("prepare", "departure_preparation", profile_tick)
	var recovery_built := _build_admission_ready_payload(source_kind, action_receipt, action_candidate,
		condition_receipt, board_candidate, board_fate_receipt, schedule_view_before, schedule_view_after,
		schedule_view_before_sha256, schedule_view_after_sha256, is_departure, reservation_request, sequence_candidate,
		destination_intent, notification_intent)
	var recovery_payload: Dictionary = recovery_built["recovery_payload"]

	var recovery_payload_sha256 := _canonical_sha256(recovery_payload)
	var pending_after: Dictionary = pending_dict.duplicate(true)
	pending_after["recovery_payload"] = recovery_payload.duplicate(true)
	pending_after["recovery_payload_sha256"] = recovery_payload_sha256
	var state_after_ordinal1: Dictionary = live_state.duplicate(true)
	state_after_ordinal1["pending"] = pending_after

	var header1 := {
		"kind": &"consequence_admission_ready", "operation_ordinal": 1, "run_id": str(action_receipt["run_id"]),
		"source_ids": [transaction_id], "stage": "action_prepared", "transaction_id": transaction_id,
	}
	var pairing1 := _validate_ordinal_stage_pairing(header1)
	if not pairing1.get("ok", false):
		return pairing1
	profile_tick = _settlement_profile_phase("prepare", "recovery_payload", profile_tick)
	var checkpoint1: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint", header1,
		state_after_ordinal1, recovery_payload_sha256)
	profile_tick = _settlement_profile_phase("prepare", "checkpoint1_prepare", profile_tick)
	if not checkpoint1.get("ok", false):
		return checkpoint1
	var committed1: Dictionary = _checkpoint_port.call(&"commit_consequence_checkpoint",
		(checkpoint1["value"] as Dictionary)["candidate"], (checkpoint1["value"] as Dictionary)["checkpoint_receipt"])
	if not committed1.get("ok", false):
		return committed1
	profile_tick = _settlement_profile_phase("prepare", "checkpoint1_commit", profile_tick)

	var live_adopt_prepared: Dictionary = _state_port.call(&"prepare_restore", state_after_ordinal1,
		recovery_payload_sha256)
	if not live_adopt_prepared.get("ok", false):
		return live_adopt_prepared
	var live_adopted: Dictionary = _state_port.call(&"commit", (live_adopt_prepared["value"] as Dictionary)["candidate"])
	if not live_adopted.get("ok", false):
		return live_adopted
	_settlement_profile_phase("prepare", "live_restore1", profile_tick)

	return _admit_and_forward(action_receipt, source_kind, transaction_id, reservation_request,
		sequence_candidate, causal_sequence_receipt, recovery_payload, pending_after)


func _resume_and_admit(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		pending_dict: Dictionary) -> Dictionary:
	var recovery_payload: Dictionary = pending_dict["recovery_payload"]
	var reservation_request: Dictionary = recovery_payload["causal_sequence_reservation_request"]
	var reserved: Dictionary = _causal_sequence_port.call(&"prepare_reservation", reservation_request)
	if not reserved.get("ok", false):
		return reserved
	var causal_sequence_receipt: Dictionary = reserved["value"]["causal_sequence_receipt"]
	var sequence_candidate: Dictionary = reserved["value"]["sequence_candidate"]
	if sequence_candidate != (recovery_payload["causal_sequence_reservation_candidate"] as Dictionary):
		return _fail(&"consequence_resume_reservation_mismatch",
			"the replayed reservation no longer matches the durable admission-ready payload", {})
	return _admit_and_forward(action_receipt, source_kind, transaction_id, reservation_request,
		sequence_candidate, causal_sequence_receipt, recovery_payload, pending_dict)


func _admit_and_forward(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		reservation_request: Dictionary, sequence_candidate: Dictionary, causal_sequence_receipt: Dictionary,
		recovery_payload: Dictionary, pending_after: Dictionary) -> Dictionary:
	var profile_tick := _settlement_profile_start()
	var prepared_state: Dictionary = _state_port.call(&"prepare_sequence_reservation", reservation_request, causal_sequence_receipt)
	profile_tick = _settlement_profile_phase("admit", "sequence_state_prepare", profile_tick)
	if not prepared_state.get("ok", false):
		return prepared_state
	var state_after_ordinal2: Dictionary = ((prepared_state["value"] as Dictionary)["candidate"] as Dictionary)["state_after"]
	var header2 := {
		"kind": &"consequence_admission", "operation_ordinal": 2, "run_id": str(action_receipt["run_id"]),
		"source_ids": [transaction_id], "stage": "sequence_committed", "transaction_id": transaction_id,
	}
	var pairing2 := _validate_ordinal_stage_pairing(header2)
	if not pairing2.get("ok", false):
		return pairing2
	var checkpoint2: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint", header2,
		state_after_ordinal2, str(pending_after["recovery_payload_sha256"]))
	profile_tick = _settlement_profile_phase("admit", "checkpoint2_prepare", profile_tick)
	if not checkpoint2.get("ok", false):
		return checkpoint2
	var admission_checkpoint_candidate := {
		"candidate": (checkpoint2["value"] as Dictionary)["candidate"],
		"checkpoint_receipt": (checkpoint2["value"] as Dictionary)["checkpoint_receipt"],
	}
	var admission_prepared: Dictionary = _causal_sequence_port.call(&"prepare_admission",
		sequence_candidate, admission_checkpoint_candidate, str(pending_after["recovery_payload_sha256"]))
	profile_tick = _settlement_profile_phase("admit", "admission_prepare", profile_tick)
	if not admission_prepared.get("ok", false):
		return admission_prepared
	var admitted: Dictionary = _causal_sequence_port.call(&"commit", (admission_prepared["value"] as Dictionary)["candidate"])
	if not admitted.get("ok", false):
		return admitted
	_settlement_profile_phase("admit", "admission_commit", profile_tick)

	return _resume_forward(action_receipt, source_kind, transaction_id, {}, {})


func _resume_forward(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		live_state: Dictionary, pending_dict: Dictionary) -> Dictionary:
	var profile_tick := _settlement_profile_start()
	if pending_dict.is_empty():
		var captured: Dictionary = _state_port.call(&"capture")
		if not captured.get("ok", false):
			return captured
		live_state = (captured["value"] as Dictionary)["state"]
		var pending: Variant = live_state.get("pending")
		if pending == null or str((pending as Dictionary).get("transaction_id", "")) != transaction_id:
			return _fail(&"consequence_no_matching_pending_transaction",
				"forward recovery requires a matching pending transaction", {})
		pending_dict = pending

	var recovery_payload: Dictionary = pending_dict["recovery_payload"]
	var source_port: Object = _minesweeper_round_source_port if source_kind == "minesweeper_round" else _shop_purchase_source_port
	var action_candidate: Dictionary = recovery_payload["action_candidate"]
	var is_departure: bool = recovery_payload["board_candidate"] != null
	var destination_intent: Variant = recovery_payload.get("destination_intent")
	var notification_intent: Variant = recovery_payload.get("notification_intent")

	if is_departure and _board_fate_port.has_method("prepare_recovery_departure"):
		var projected: Dictionary = _build_projected_board_candidate(source_kind, action_receipt, action_candidate)
		if not projected.get("ok", false): return projected
		var recovered_fate: Dictionary = _board_fate_port.prepare_recovery_departure(action_receipt,
			projected.value.board_candidate, recovery_payload.board_candidate,
			_board_fate_receipt_from_payload(recovery_payload))
		if not recovered_fate.get("ok", false): return recovered_fate

	profile_tick = _settlement_profile_phase("forward", "capture_and_recovery_prepare", profile_tick)
	var source_committed: Dictionary = source_port.call(&"commit_recovery_action", action_candidate, action_receipt)
	if not source_committed.get("ok", false):
		return source_committed
	profile_tick = _settlement_profile_phase("forward", "source_commit_inclusive", profile_tick)

	var schedule_view_commit_receipt: Variant = null
	if is_departure:
		var board_candidate: Dictionary = recovery_payload["board_candidate"]
		var board_committed: Dictionary = _board_fate_port.call(&"commit", board_candidate)
		if not board_committed.get("ok", false):
			return board_committed

		var condition_receipt_for_view: Dictionary = recovery_payload["condition_candidate"]
		var view_committed: Dictionary = _schedule_view_port.call(&"commit_condition_departure", {
			"condition_receipt": condition_receipt_for_view,
			"schedule_view_before": recovery_payload["schedule_view_before"],
			"schedule_view_before_sha256": recovery_payload["schedule_view_before_sha256"],
			"schedule_view_after": recovery_payload["schedule_view_after"],
			"schedule_view_after_sha256": recovery_payload["schedule_view_after_sha256"],
		})
		if not view_committed.get("ok", false):
			return view_committed
		schedule_view_commit_receipt = (view_committed["receipt"] as Dictionary).duplicate(true)

	profile_tick = _settlement_profile_phase("forward", "departure_commits", profile_tick)
	if str(pending_dict["stage"]) != "publication_pending":
		var advanced := _advance_to_publication_pending(transaction_id, pending_dict, destination_intent, notification_intent)
		if not advanced.get("ok", false):
			return advanced
		pending_dict = advanced["pending_dict"]

	profile_tick = _settlement_profile_phase("forward", "publication_pending_inclusive", profile_tick)
	var publication_plan: Array = recovery_payload["publication_plan"]
	var progress: Dictionary = pending_dict["publication_progress"]
	while int(progress["next_callback_index"]) < publication_plan.size():
		var index: int = int(progress["next_callback_index"])
		var recipe: Dictionary = publication_plan[index]
		var callback_result := _run_publication_callback(recipe, recovery_payload, action_receipt, source_port, pending_dict)
		if _profile_enabled:
			profile_tick = _settlement_profile_phase("forward", "publish_" + str(recipe["participant"]), profile_tick)
		if not callback_result.get("ok", false):
			return callback_result
		var advanced_progress := _advance_publication_progress(transaction_id, str(recipe["participant"]),
			(callback_result["disposition"] as String), (callback_result["source_receipt"] as Dictionary), progress)
		if not advanced_progress.get("ok", false):
			return advanced_progress
		progress = advanced_progress["progress"]
		if _profile_enabled:
			profile_tick = _settlement_profile_phase("forward", "progress_" + str(recipe["participant"]), profile_tick)

	var cleaned := _terminal_cleanup(transaction_id)
	if not cleaned.get("ok", false):
		return cleaned
	profile_tick = _settlement_profile_phase("forward", "cleanup_inclusive", profile_tick)

	var source_released: Dictionary = source_port.call(&"release_recovery_lease")
	if not source_released.get("ok", false):
		return source_released
	var recovery_released := _release_recovery_gate()
	if not recovery_released.get("ok", false):
		return recovery_released
	if _notification_publisher.is_valid(): _notification_publisher.call()

	var causal_sequence: int = int(((recovery_payload["causal_sequence_reservation_candidate"] as Dictionary)
		["causal_sequence_receipt"] as Dictionary)["causal_sequence"])
	var board_fate_receipt: Variant = (_board_fate_receipt_from_payload(recovery_payload) if is_departure else null)
	var condition_receipt: Dictionary = recovery_payload["condition_candidate"]
	_committed_condition_receipts[str(action_receipt["causal_day_instance"])] = \
		condition_receipt.duplicate(true)
	var value := {
		"causal_sequence": causal_sequence, "condition_receipt": condition_receipt.duplicate(true),
		"board_fate_receipt": board_fate_receipt, "schedule_view_commit_receipt": schedule_view_commit_receipt,
		"destination_intent": destination_intent, "notification_intent": notification_intent,
	}
	var receipt_built := _build_action_consequence_receipt(action_receipt, transaction_id, causal_sequence, is_departure)
	_settlement_profile_phase("forward", "release_and_receipt", profile_tick)
	if not receipt_built.get("ok", false):
		return receipt_built
	return {"ok": true, "code": &"action_consequence_accepted", "value": value, "receipt": receipt_built["receipt"]}


func _advance_to_publication_pending(transaction_id: String, pending_dict: Dictionary,
		destination_intent: Variant, notification_intent: Variant) -> Dictionary:
	var recovery_payload: Dictionary = pending_dict["recovery_payload"]
	var callback_ids: Array[String] = []
	for recipe: Variant in (recovery_payload["publication_plan"] as Array):
		callback_ids.append(str((recipe as Dictionary)["participant"]))
	var publication_progress := {
		"publication_plan_sha256": str(recovery_payload["publication_plan_sha256"]),
		"callback_ids": callback_ids, "next_callback_index": 0, "callback_receipts": {},
	}
	var advanced: Dictionary = _state_port.call(&"prepare_recovery_advance", transaction_id, &"sequence_committed",
		&"publication_pending", {}, destination_intent, notification_intent, publication_progress)
	if not advanced.get("ok", false):
		return advanced
	var advance_value: Dictionary = advanced["value"]
	var checkpointed := _checkpoint_and_adopt(advance_value["checkpoint_header"],
		advance_value["stage_candidate"], str(advance_value.get("proven_recovery_payload_sha256", "")))
	if not checkpointed.get("ok", false):
		return checkpointed
	return {"ok": true, "pending_dict": (checkpointed["state_after"]["pending"] as Dictionary)}


func _run_publication_callback(recipe: Dictionary, recovery_payload: Dictionary, action_receipt: Dictionary,
		source_port: Object, pending_dict: Dictionary) -> Dictionary:
	var participant := str(recipe["participant"])
	match participant:
		"causal_sequence":
			var reservation_candidate: Dictionary = recovery_payload["causal_sequence_reservation_candidate"]
			var causal_sequence_receipt: Dictionary = reservation_candidate["causal_sequence_receipt"]
			var published: Dictionary = _causal_sequence_port.call(&"publish", {
				"causal_sequence_receipt": causal_sequence_receipt,
				"admission_checkpoint_receipt": pending_dict["admission_checkpoint_receipt"],
			})
			if not published.get("ok", false):
				return published
			return {"ok": true, "disposition": "published", "source_receipt": published["receipt"]}
		"action_source":
			var published: Dictionary = source_port.call(&"publish_recovery_action",
				{"action_candidate_sha256": str(recovery_payload["action_candidate_sha256"]), "action_receipt": action_receipt})
			if not published.get("ok", false):
				return published
			return {"ok": true, "disposition": "published", "source_receipt": published["receipt"]}
		"board_fate":
			var published: Dictionary = _board_fate_port.call(&"publish", {
				"board_candidate": recovery_payload["board_candidate"],
				"board_fate_receipt": _board_fate_receipt_from_payload(recovery_payload),
			})
			if not published.get("ok", false):
				return published
			return {"ok": true, "disposition": "published", "source_receipt": published["receipt"]}
		_:
			return _fail(&"consequence_publication_participant_invalid", participant, {})


func _board_fate_receipt_from_payload(recovery_payload: Dictionary) -> Dictionary:
	for recipe: Variant in (recovery_payload["publication_plan"] as Array):
		var entry: Dictionary = recipe
		if str(entry["participant"]) == "board_fate":
			return (entry["publication"] as Dictionary)["board_fate_receipt"]
	return {}


func _action_receipt_from_payload(recovery_payload: Dictionary) -> Dictionary:
	for recipe: Variant in (recovery_payload["publication_plan"] as Array):
		var entry: Dictionary = recipe
		if str(entry["participant"]) == "action_source":
			return (entry["publication"] as Dictionary)["action_receipt"]
	return {}


func _advance_publication_progress(transaction_id: String, callback_id: String, disposition: String,
		source_receipt: Dictionary, progress: Dictionary) -> Dictionary:
	var callback_receipts: Dictionary = (progress["callback_receipts"] as Dictionary).duplicate(true)
	callback_receipts[callback_id] = {"callback_id": callback_id, "source_receipt": source_receipt, "disposition": disposition}
	var next_index: int = int(progress["next_callback_index"]) + 1
	var new_progress := {
		"publication_plan_sha256": str(progress["publication_plan_sha256"]),
		"callback_ids": (progress["callback_ids"] as Array).duplicate(true),
		"next_callback_index": next_index, "callback_receipts": callback_receipts,
	}
	var advanced: Dictionary = _state_port.call(&"prepare_recovery_advance", transaction_id, &"publication_pending",
		&"publication_pending", {}, null, null, new_progress)
	if not advanced.get("ok", false):
		return advanced
	var advance_value: Dictionary = advanced["value"]
	var checkpointed := _checkpoint_and_adopt(advance_value["checkpoint_header"],
		advance_value["stage_candidate"], str(advance_value.get("proven_recovery_payload_sha256", "")))
	if not checkpointed.get("ok", false):
		return checkpointed
	var pending_after: Dictionary = checkpointed["state_after"]["pending"]
	return {"ok": true, "progress": (pending_after["publication_progress"] as Dictionary).duplicate(true)}


func _terminal_cleanup(transaction_id: String) -> Dictionary:
	var advanced: Dictionary = _state_port.call(&"prepare_recovery_advance", transaction_id, &"publication_pending",
		null, {}, null, null, null)
	if not advanced.get("ok", false):
		return advanced
	var advance_value: Dictionary = advanced["value"]
	var notification := _accept_completion_notification(advance_value["stage_candidate"])
	if not notification.get("ok", false): return notification
	advance_value["stage_candidate"] = notification["value"]["state"]
	var completed := _checkpoint_completion(transaction_id, advance_value["stage_candidate"])
	if not completed.get("ok", false):
		return completed
	var checkpointed := _checkpoint_and_adopt(advance_value["checkpoint_header"], advance_value["stage_candidate"])
	if not checkpointed.get("ok", false):
		return checkpointed
	_completion_checkpoints.erase(transaction_id)
	return {"ok": true}


func _accept_completion_notification(completed: Dictionary) -> Dictionary:
	var entry: Variant = completed.get("outbox", {}).get("notification")
	if not _notification_consumer.is_valid() or not entry is Dictionary \
			or entry.get("status") != "pending":
		return {"ok": true, "value": {"state": completed}}
	var accepted: Dictionary = _notification_consumer.call(entry.duplicate(true))
	if not accepted.get("ok", false): return accepted
	var detached := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd").new()
	var restored: Dictionary = detached.prepare_restore(completed)
	if not restored.get("ok", false): return restored
	detached.commit(restored.value.candidate)
	var published: Dictionary = detached.prepare_outbox_publication({
		"kind": "notification", "key": entry.key, "payload_hash": entry.payload_hash,
		"provenance": entry.provenance.duplicate(true), "consumer": "desktop_notification",
	})
	if not published.get("ok", false): return published
	return {"ok": true, "value": {"state": published.value.candidate.state_after}}


func _checkpoint_completion(transaction_id: String, stage_candidate: Dictionary) -> Dictionary:
	var profile_tick := _settlement_profile_start()
	if not _completion_checkpoint_capture.is_valid():
		return {"ok": true}
	if not _mutation_gate.is_internal_owner_active(_GATE_OWNER):
		return _fail(&"causal_transaction_lease_required", "completion checkpoint requires the causal lease", {})
	if not _completion_checkpoints.has(transaction_id):
		var captured: Dictionary = _completion_checkpoint_capture.call(stage_candidate.duplicate(true))
		profile_tick = _settlement_profile_phase("completion_save", "capture", profile_tick)
		if not captured.get("ok", false):
			return captured
		var inputs: Variant = (captured.get("value", {}) as Dictionary).get("checkpoint_inputs")
		if typeof(inputs) != TYPE_DICTIONARY:
			return _fail(&"invalid_completion_checkpoint_capture", "capture must supply checkpoint_inputs", {})
		var projected: Variant = (inputs as Dictionary).get("snapshot_input", {}).get("desktop", {}).get("consequence")
		if projected != stage_candidate:
			return _fail(&"completion_checkpoint_candidate_mismatch", "capture must retain the exact completed consequence", {})
		var prepared: Dictionary = _checkpoint_port.call(&"prepare", inputs, &"post_result",
			{"kind": &"autosave", "reason": &"automatic"})
		profile_tick = _settlement_profile_phase("completion_save", "prepare", profile_tick)
		if not prepared.get("ok", false):
			return prepared
		_completion_checkpoints[transaction_id] = {
			"candidate": prepared["value"]["candidate"], "committed": false,
		}
	var retained: Dictionary = _completion_checkpoints[transaction_id]
	if not bool(retained["committed"]):
		var committed: Dictionary = _checkpoint_port.call(&"commit", retained["candidate"])
		if not committed.get("ok", false):
			return committed
		retained["committed"] = true
	_settlement_profile_phase("completion_save", "commit_inclusive", profile_tick)
	return {"ok": true}


func _acquire_recovery_gate() -> Dictionary:
	if _mutation_gate.is_internal_owner_active(_GATE_OWNER):
		return {"ok": true}
	var acquired := _mutation_gate.acquire(_GATE_OWNER)
	if not acquired.get("ok", false):
		return acquired
	_recovery_gate_token = str(acquired["value"]["token"])
	return {"ok": true}


func _release_recovery_gate() -> Dictionary:
	if _recovery_gate_token.is_empty():
		return {"ok": true}
	var released := _mutation_gate.release(_GATE_OWNER, _recovery_gate_token)
	if released.get("ok", false):
		_recovery_gate_token = ""
	return released


func _checkpoint_and_adopt(checkpoint_header: Dictionary, stage_candidate: Dictionary,
		proven_recovery_payload_sha256: String = "") -> Dictionary:
	var profile_tick := _settlement_profile_start()
	var profile_scope := ""
	if _profile_enabled:
		profile_scope = "ordinal_" + str(checkpoint_header.get("operation_ordinal"))
	var checkpoint: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint", checkpoint_header,
		stage_candidate, proven_recovery_payload_sha256)
	profile_tick = _settlement_profile_phase(profile_scope, "prepare", profile_tick)
	if not checkpoint.get("ok", false):
		return checkpoint
	var committed: Dictionary = _checkpoint_port.call(&"commit_consequence_checkpoint",
		(checkpoint["value"] as Dictionary)["candidate"], (checkpoint["value"] as Dictionary)["checkpoint_receipt"])
	if not committed.get("ok", false):
		return committed
	profile_tick = _settlement_profile_phase(profile_scope, "commit", profile_tick)
	var live_prepared: Dictionary = _state_port.call(&"prepare_restore", stage_candidate,
		proven_recovery_payload_sha256)
	profile_tick = _settlement_profile_phase(profile_scope, "live_restore", profile_tick)
	if not live_prepared.get("ok", false):
		return live_prepared
	var live_committed: Dictionary = _state_port.call(&"commit", (live_prepared["value"] as Dictionary)["candidate"])
	if not live_committed.get("ok", false):
		return live_committed
	_settlement_profile_phase(profile_scope, "live_commit", profile_tick)
	return {"ok": true, "state_after": stage_candidate}


func _settlement_profile_start() -> int:
	if not _profile_enabled: return 0
	return Time.get_ticks_usec()


func _settlement_profile_phase(scope: String, phase: String, tick: int) -> int:
	if not _profile_enabled: return 0
	print("DWM_CONSEQUENCE_PROFILE " + JSON.stringify({
		"scope": scope, "phase": phase, "elapsed_us": Time.get_ticks_usec() - tick,
	}))
	return Time.get_ticks_usec()



const _STAGE_RANK: Dictionary = {
	"action_prepared": 0, "prepared_checkpointed": 0, "sequence_committed": 1, "publication_pending": 2,
}

func adopt_durable_checkpoint_if_live_is_behind() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if not _checkpoint_port.has_method("read_pending_consequence_checkpoint"):
		return {"ok": true, "code": &"ok", "value": {"adopted": false}, "receipt": {}}
	var read: Dictionary = _checkpoint_port.call(&"read_pending_consequence_checkpoint")
	if not read.get("ok", false):
		return read
	if not bool((read["value"] as Dictionary).get("found", false)):
		return {"ok": true, "code": &"ok", "value": {"adopted": false}, "receipt": {}}
	var checkpointed_state: Dictionary = (read["value"] as Dictionary)["stage_candidate"]
	var checkpointed_pending: Dictionary = checkpointed_state["pending"]

	var captured: Dictionary = _state_port.call(&"capture")
	if not captured.get("ok", false):
		return captured
	var live_state: Dictionary = (captured["value"] as Dictionary)["state"]
	var live_pending: Variant = live_state.get("pending")
	var live_is_behind: bool
	if live_pending == null:
		live_is_behind = true
	elif str((live_pending as Dictionary).get("transaction_id", "")) != str(checkpointed_pending["transaction_id"]):
		live_is_behind = false
	else:
		var live_rank: int = int(_STAGE_RANK.get(str((live_pending as Dictionary).get("stage", "")), -1))
		var checkpoint_rank: int = int(_STAGE_RANK.get(str(checkpointed_pending["stage"]), -1))
		live_is_behind = checkpoint_rank > live_rank
	if not live_is_behind:
		return {"ok": true, "code": &"ok", "value": {"adopted": false}, "receipt": {}}

	var prepared: Dictionary = _state_port.call(&"prepare_restore", checkpointed_state)
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = _state_port.call(&"commit", (prepared["value"] as Dictionary)["candidate"])
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "code": &"ok", "value": {"adopted": true}, "receipt": {}}


func resume_pending() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if _minesweeper_round_source_port == null or _shop_purchase_source_port == null:
		return _fail(&"action_source_ports_unconfigured", "configure_action_source_ports() is required first", {})
	var adopted := adopt_durable_checkpoint_if_live_is_behind()
	if not adopted.get("ok", false):
		return adopted
	var captured: Dictionary = _state_port.call(&"capture")
	if not captured.get("ok", false):
		return captured
	var live_state: Dictionary = (captured["value"] as Dictionary)["state"]
	var pending: Variant = live_state.get("pending")
	if pending == null:
		return {"ok": true, "code": &"ok", "value": {"resumed": false}, "receipt": {}}
	var pending_dict: Dictionary = pending
	var source_kind := str(pending_dict["source_kind"])
	if source_kind not in _ACTION_SOURCE_KINDS:
		return {"ok": true, "code": &"ok", "value": {"resumed": false}, "receipt": {}}
	if str(pending_dict["stage"]) == "action_prepared":
		var retained_payload: Dictionary = pending_dict["recovery_payload"]
		if str(retained_payload.get("payload_phase", "")) == "admission_ready":
			var admission_lease := _acquire_recovery_gate()
			if not admission_lease.get("ok", false):
				return admission_lease
			var admitted := _resume_and_admit(_action_receipt_from_payload(retained_payload),
				source_kind, str(pending_dict["transaction_id"]), pending_dict)
			if not admitted.get("ok", false):
				return admitted
			return {"ok": true, "code": &"ok", "value": {"resumed": true, "source_kind": source_kind}, "receipt": {}}
		var abandoned := _abandon_pre_admission(str(pending_dict["transaction_id"]), source_kind)
		if not abandoned.get("ok", false):
			return abandoned
		return {"ok": true, "code": &"ok", "value": {"resumed": false, "abandoned": true}, "receipt": {}}
	if str(pending_dict["stage"]) != "sequence_committed" and str(pending_dict["stage"]) != "publication_pending":
		return _fail(&"consequence_resume_requires_admitted_transaction",
			"resume_pending only resumes an already-admitted action-source transaction", {})

	var recovery_payload: Dictionary = pending_dict["recovery_payload"]
	var action_receipt: Dictionary = _action_receipt_from_payload(recovery_payload)
	var transaction_id := str(pending_dict["transaction_id"])
	var leased := _acquire_recovery_gate()
	if not leased.get("ok", false):
		return leased
	var result := _resume_forward(action_receipt, source_kind, transaction_id, live_state, pending_dict)
	if not result.get("ok", false):
		return result
	return {"ok": true, "code": &"ok", "value": {"resumed": true, "source_kind": source_kind}, "receipt": {}}



func _build_projected_board_candidate(source_kind: String, action_receipt: Dictionary,
		action_candidate: Dictionary) -> Dictionary:
	if source_kind == "minesweeper_round":
		if typeof(action_candidate.get("board_projection")) != TYPE_DICTIONARY:
			return _fail(&"action_candidate_missing_board_projection",
				"a minesweeper_round action_candidate must carry board_projection", {})
		return {"ok": true, "value": {"board_candidate": (action_candidate["board_projection"] as Dictionary).duplicate(true)}}
	var captured: Dictionary = _board_fate_port.call(&"capture")
	if not captured.get("ok", false):
		return captured
	return {"ok": true, "value": {"board_candidate": ((captured["value"] as Dictionary)["backup"] as Dictionary).duplicate(true)}}


func _build_admission_ready_payload(source_kind: String, action_receipt: Dictionary, action_candidate: Dictionary,
		condition_receipt: Dictionary, board_candidate: Variant, board_fate_receipt: Variant,
		schedule_view_before: Variant, schedule_view_after: Variant, schedule_view_before_sha256: Variant,
		schedule_view_after_sha256: Variant, is_departure: bool, reservation_request: Dictionary,
		sequence_candidate: Dictionary, destination_intent: Variant, notification_intent: Variant) -> Dictionary:
	var transaction_id := str(action_receipt["transaction_id"])
	var action_candidate_sha256 := _canonical_sha256(action_candidate)
	var condition_candidate_sha256 := _canonical_sha256(condition_receipt)

	var publication_plan: Array = [
		{"participant": "causal_sequence", "source_kind": source_kind,
			"publication": {"causal_sequence_receipt": {}}},
		{"participant": "action_source", "source_kind": source_kind,
			"publication": {"action_candidate_sha256": action_candidate_sha256, "action_receipt": action_receipt}},
	]
	var callback_ids: Array[String] = ["causal_sequence", "action_source"]
	if is_departure:
		publication_plan.append({"participant": "board_fate", "source_kind": source_kind,
			"publication": {"board_candidate": board_candidate, "board_fate_receipt": board_fate_receipt}})
		callback_ids.append("board_fate")
	var publication_plan_sha256 := _canonical_sha256(publication_plan)

	var consequence_preview := {
		"publication_plan_sha256": publication_plan_sha256, "callback_ids": callback_ids,
		"next_callback_index": 0, "callback_receipts": {},
	}

	var recovery_payload := {
		"schema_version": 1, "source_kind": source_kind, "payload_phase": "admission_ready",
		"action_candidate": action_candidate.duplicate(true), "action_candidate_sha256": action_candidate_sha256,
		"condition_candidate": condition_receipt.duplicate(true), "condition_candidate_sha256": condition_candidate_sha256,
		"board_candidate": board_candidate, "board_candidate_sha256": (_canonical_sha256(board_candidate) if is_departure else null),
		"schedule_view_before": schedule_view_before, "schedule_view_before_sha256": schedule_view_before_sha256,
		"schedule_view_after": schedule_view_after, "schedule_view_after_sha256": schedule_view_after_sha256,
		"consequence_candidate": consequence_preview, "consequence_candidate_sha256": _canonical_sha256(consequence_preview),
		"publication_plan": publication_plan, "publication_plan_sha256": publication_plan_sha256,
		"causal_sequence_reservation_request": reservation_request.duplicate(true),
		"causal_sequence_reservation_candidate": sequence_candidate.duplicate(true),
		"destination_intent": ((destination_intent as Dictionary).duplicate(true) if destination_intent != null else null),
		"notification_intent": ((notification_intent as Dictionary).duplicate(true) if notification_intent != null else null),
	}
	return {"recovery_payload": recovery_payload}


func _validate_intent_pairing(is_departure: bool, destination_intent: Variant, notification_intent: Variant) -> Dictionary:
	if destination_intent != null:
		if typeof(destination_intent) != TYPE_DICTIONARY:
			return _fail(&"destination_intent_invalid", "destination_intent must be null or an object", {})
		var destination_shape := _exact_keys(destination_intent as Dictionary, _DESTINATION_INTENT_KEYS, &"destination_intent_invalid")
		if not destination_shape.get("ok", false):
			return destination_shape
		if str((destination_intent as Dictionary)["kind"]) not in _DESTINATION_INTENT_KINDS:
			return _fail(&"destination_intent_kind_invalid", str((destination_intent as Dictionary)["kind"]), {})
	if notification_intent != null:
		if typeof(notification_intent) != TYPE_DICTIONARY:
			return _fail(&"notification_intent_invalid", "notification_intent must be null or an object", {})
		var notification_shape := _exact_keys(notification_intent as Dictionary, _NOTIFICATION_INTENT_KEYS, &"notification_intent_invalid")
		if not notification_shape.get("ok", false):
			return notification_shape
		if str((notification_intent as Dictionary)["action_kind"]) not in _NOTIFICATION_INTENT_ACTION_KINDS:
			return _fail(&"notification_intent_action_kind_invalid", str((notification_intent as Dictionary)["action_kind"]), {})
	if is_departure:
		if destination_intent == null:
			return _fail(&"destination_intent_required_for_departure",
				"a departure requires exactly one destination intent", {})
		if notification_intent != null:
			return _fail(&"notification_intent_forbidden_for_departure",
				"a departure suppresses notification", {})
	else:
		if destination_intent != null:
			return _fail(&"destination_intent_forbidden_for_no_departure",
				"a no-departure never calls the view port", {})
	return {"ok": true}


func _validate_ordinal_stage_pairing(header: Dictionary) -> Dictionary:
	var ordinal := int(header["operation_ordinal"])
	var expected_stage: Variant = _ORDINAL_STAGE_LAW.get(ordinal)
	if expected_stage == null or str(header["stage"]) != String(expected_stage):
		return _fail(&"consequence_checkpoint_ordinal_stage_invalid",
			"operation_ordinal %d must pair with stage %s" % [ordinal, str(expected_stage)],
			{"operation_ordinal": ordinal, "stage": str(header["stage"])})
	return {"ok": true}


func _build_action_consequence_receipt(action_receipt: Dictionary, transaction_id: String,
		causal_sequence: int, is_departure: bool) -> Dictionary:
	if _identity_issuer == null:
		return _fail(&"identity_issuer_unconfigured",
			"configure_identity_issuer() is required before accept_prepared_action() can complete", {})
	var parent_receipt_id := str((action_receipt["transaction_issuer_receipt"] as Dictionary).get("receipt_id", ""))
	var derived: Dictionary = _identity_issuer.call(&"derive_child", {
		"child_kind": "action_consequence", "ordinal": 0, "parent_receipt_id": parent_receipt_id,
		"source_ids": _sorted_unique([transaction_id, str(action_receipt["commit_receipt_id"]), str(causal_sequence)]),
	})
	if not derived.get("ok", false):
		return derived
	var derived_value: Dictionary = derived["value"]
	return {"ok": true, "receipt": {
		"receipt_id": str(derived_value["child_id"]),
		"receipt_provenance": (derived_value["provenance"] as Dictionary).duplicate(true),
		"action_commit_receipt_id": str(action_receipt["commit_receipt_id"]),
		"action_commit_receipt_provenance": (action_receipt["commit_receipt_provenance"] as Dictionary).duplicate(true),
		"causal_sequence": causal_sequence,
		"disposition": ("departure_committed" if is_departure else "no_departure"),
	}}


static func _sorted_unique(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[str(value)] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


func _require_configured() -> Dictionary:
	if _state_port == null or _causal_sequence_port == null or _board_fate_port == null \
			or _checkpoint_port == null or _mutation_gate == null:
		return _fail(&"consequence_coordinator_not_configured", "DesktopConsequenceCoordinator.configure() was never called", {})
	return {"ok": true}


static func _has_all_methods(target: Object, methods: Array[String]) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}



func release_runtime_dependencies() -> void:
	_minesweeper_round_source_port = null
