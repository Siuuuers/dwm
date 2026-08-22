class_name DesktopConsequenceCoordinator
extends RefCounted

## Prepared-action causal consequence coordinator (Plan 02 Task 8, dwm-p2r.32,
## req.desktop.cross_app_actions, req.minesweeper.causal_departure, req.minesweeper.round_contract).
## Consumes Task 6's `DesktopCausalSequencePort`/`ApplicationMutationGate` and Task 8's own
## `DesktopBoardFatePort` unchanged. Dispatches only by the validated, persisted
## `pending_transaction.source_kind` -- it never infers a source from candidate shape, current board,
## or receipt naming.
##
## RULING A (checkpoint ordinal/stage convention, owned by this task): a pre-admission action-source
## transaction crosses exactly TWO physically distinct checkpoint writes that both keep
## `DesktopConsequenceState.pending.stage="action_prepared"` (Task 6's own documented collapse of the
## frozen contract's two-stage `action_checkpointed(0) -> action_prepared(1)` span into one live
## stage string) -- ordinal 0 is the SOURCE PARTICIPANT's own durable, unpromoted checkpoint
## (`payload_phase="source_checkpoint"`, written by `MinesweeperShopPurchaseParticipant.prepare_purchase()`
## or `MinesweeperRoundCoordinator.complete_round()` BEFORE this coordinator is ever consulted), and
## ordinal 1 is THIS coordinator's own complete admission-ready payload
## (`payload_phase="admission_ready"`), written here in `accept_prepared_action()` and never
## overwriting ordinal 0's bytes. This is exactly the convention Task 7's Shop participant already
## established for its own ordinal-0 write (`operation_ordinal=0` with `stage="action_prepared"`) --
## Task 8 applies the SAME convention to `MinesweeperRoundCoordinator.complete_round()`'s own ordinal-0
## write, and adds the matching ordinal-1 write here, uniformly for both source kinds.
## `payload_phase` (inside `recovery_payload`, not `DesktopConsequenceState.pending.stage`) is the
## real signal distinguishing "durable but not yet admission-ready" (0) from "admission-ready" (1);
## no ordinal/stage cross-validation is added inside `DesktopConsequenceState.gd` itself (out of this
## task's file scope, and the checkpoint port's own occupied-slot conflict law already protects
## against an ordinal being silently overwritten with different bytes).
##
## RULING B (receipt/ledger conventions): `MinesweeperRoundCoordinator.complete_round()` reuses
## `action_id`/`action_id_provenance` byte-for-byte as `commit_receipt_id`/`commit_receipt_provenance`
## on its own `DesktopActionReceipt`, exactly matching the Shop participant's own documented
## convention (Task 7 report: "Plan 02's frozen production derivation table... has no row for a
## distinct commit-identity"). Its `publish_recovery_action()` records through the SAME publication
## ledger `action_source` kind, keyed `"action_source:" + action_receipt.commit_receipt_id`, matching
## `MinesweeperShopPurchaseParticipant.publish()`'s own established key convention exactly -- both
## source kinds share the ledger's one `action_source` kind coherently.
##
## SCOPE NOTE (own documented judgment call, not literally spelled out): the frozen recovery_payload's
## `consequence_candidate`/`consequence_candidate_sha256` pair (nonnull for every `payload_phase=
## admission_ready` payload regardless of departure decision -- brief line 367) has no other concrete
## definition anywhere in the frozen contracts text once its own containing `pending_transaction` is
## excluded as self-referential. This coordinator resolves it as a detached PREVIEW of what
## `pending.publication_progress` will look like once `sequence_committed -> publication_pending`
## fires: `{publication_plan_sha256, callback_ids, next_callback_index:0, callback_receipts:{}}` --
## genuinely a "consequence" planning artifact prepared alongside `publication_plan` before admission,
## and the one candidate/hash pair every payload_phase=admission_ready payload needs regardless of
## departure/no-departure, matching that law exactly.

const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _GATE_OWNER := &"causal_transaction"
const _ACTION_SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]
const _SOURCE_RECOVERY_METHODS: Array[String] = [
	"validate_recovery_action", "commit_recovery_action", "publish_recovery_action",
]
const _ACCEPT_REQUEST_KEYS: Array[String] = [
	"action_receipt", "action_candidate", "prepared_checkpoint_receipt", "expected_run_revision",
	"expected_board_identity", "expected_board_revision",
]

var _state_port: Object = null
var _causal_sequence_port: Object = null
var _board_fate_port: Object = null
var _checkpoint_port: Object = null
var _mutation_gate: ApplicationMutationGate = null

var _minesweeper_round_source_port: Object = null
var _shop_purchase_source_port: Object = null
var _condition_policy_port: Object = null
var _schedule_view_port: Object = null

## Same-process idempotency ledger for `accept_prepared_action()`, keyed by `action_receipt
## .transaction_id`: `{"request_fingerprint":String,"result":Dictionary}`. Cross-restart resumption
## does not depend on this map -- it depends only on `DesktopConsequenceState`'s own durable pending
## record, which `resume_pending()` reads fresh.
var _accepted: Dictionary = {}


# -------------------------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------------------------

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


## Mandatory before either condition/departure configure seam or `resume_pending()`. Retains exactly
## the existing production `MinesweeperRoundCoordinator` for `minesweeper_round` and
## `MinesweeperShopPurchaseParticipant` for `shop_purchase`; validates all three recovery methods on
## both, and rejects one object claiming both roles.
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


# -------------------------------------------------------------------------------------------------
# accept_prepared_action() -- validate -> reserve -> evaluate policy -> (departure: board fate +
# ScheduleView) -> checkpoint ordinal 1 -> admission CAS -> forward commit -> publish -> cleanup.
# -------------------------------------------------------------------------------------------------

func accept_prepared_action(request: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var shape := _exact_keys(request, _ACCEPT_REQUEST_KEYS, &"accept_prepared_action_request_invalid")
	if not shape.get("ok", false):
		return shape
	if _condition_policy_port == null or _schedule_view_port == null:
		return _fail(&"condition_departure_ports_unconfigured",
			"configure_condition_departure_ports() is required before admission", {})

	var receipt_valid := _ACTION_RECEIPT.validate(request["action_receipt"])
	if not receipt_valid.get("ok", false):
		return receipt_valid
	var action_receipt: Dictionary = (receipt_valid["value"] as Dictionary)["receipt"]
	var source_kind := str(action_receipt["action_kind"])
	if source_kind not in _ACTION_SOURCE_KINDS:
		return _fail(&"action_source_kind_invalid", source_kind, {})
	var transaction_id := str(action_receipt["transaction_id"])
	var request_fingerprint := _canonical_sha256(request)

	if _accepted.has(transaction_id):
		var recorded: Dictionary = _accepted[transaction_id]
		if str(recorded["request_fingerprint"]) == request_fingerprint:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"action_receipt_conflict",
			"this action/transaction identity was already accepted with different bytes", {})

	if not bool(_mutation_gate.is_internal_owner_active(_GATE_OWNER)):
		return _fail(&"causal_transaction_lease_required",
			"accept_prepared_action requires the source participant to already hold the causal_transaction lease", {})

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
	if str(pending_dict["stage"]) == "action_prepared" and not already_admission_ready:
		result = _prepare_and_admit(action_receipt, source_kind, transaction_id, request, live_state, pending_dict)
	elif str(pending_dict["stage"]) == "action_prepared" and already_admission_ready:
		# Ordinal 1 is durable but the admission CAS itself did not complete before a crash: replay
		# the reservation deterministically (prepare_reservation() is byte-identical-replay-safe at
		# the same transaction_id) rather than re-running policy/board-fate/view preparation again.
		result = _resume_and_admit(action_receipt, source_kind, transaction_id, pending_dict)
	else:
		result = _resume_forward(action_receipt, source_kind, transaction_id, live_state, pending_dict)

	if bool(result.get("ok", false)):
		_accepted[transaction_id] = {"request_fingerprint": request_fingerprint, "result": result.duplicate(true)}
	return result


## Fresh admission path: reservation -> policy -> (departure: board fate + view) -> ordinal-1
## checkpoint -> live-adopt -> admission CAS -> forward.
func _prepare_and_admit(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		request: Dictionary, live_state: Dictionary, pending_dict: Dictionary) -> Dictionary:
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

	var condition_evaluated: Dictionary = _condition_policy_port.call(&"evaluate", {
		"action_receipt": action_receipt, "causal_sequence_receipt": causal_sequence_receipt,
	})
	if not condition_evaluated.get("ok", false):
		return condition_evaluated
	var condition_value: Dictionary = condition_evaluated["value"]
	var condition_receipt: Dictionary = condition_value["condition_receipt"]
	var is_departure := str(condition_receipt["decision"]) != "no_departure"

	var board_fate_receipt: Variant = null
	var board_candidate: Variant = null
	var schedule_view_before: Variant = null
	var schedule_view_after: Variant = null
	var schedule_view_before_sha256: Variant = null
	var schedule_view_after_sha256: Variant = null
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

	var recovery_built := _build_admission_ready_payload(source_kind, action_receipt, action_candidate,
		condition_receipt, board_candidate, board_fate_receipt, schedule_view_before, schedule_view_after,
		schedule_view_before_sha256, schedule_view_after_sha256, is_departure, reservation_request, sequence_candidate)
	var recovery_payload: Dictionary = recovery_built["recovery_payload"]

	var pending_after: Dictionary = pending_dict.duplicate(true)
	pending_after["recovery_payload"] = recovery_payload.duplicate(true)
	pending_after["recovery_payload_sha256"] = _canonical_sha256(recovery_payload)
	var state_after_ordinal1: Dictionary = live_state.duplicate(true)
	state_after_ordinal1["pending"] = pending_after

	var header1 := {
		"kind": &"consequence_admission_ready", "operation_ordinal": 1, "run_id": str(action_receipt["run_id"]),
		"source_ids": [transaction_id], "stage": "action_prepared", "transaction_id": transaction_id,
	}
	var checkpoint1: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint", header1, state_after_ordinal1)
	if not checkpoint1.get("ok", false):
		return checkpoint1
	var committed1: Dictionary = _checkpoint_port.call(&"commit_consequence_checkpoint",
		(checkpoint1["value"] as Dictionary)["candidate"], (checkpoint1["value"] as Dictionary)["checkpoint_receipt"])
	if not committed1.get("ok", false):
		return committed1

	var live_adopt_prepared: Dictionary = _state_port.call(&"prepare_restore", state_after_ordinal1)
	if not live_adopt_prepared.get("ok", false):
		return live_adopt_prepared
	var live_adopted: Dictionary = _state_port.call(&"commit", (live_adopt_prepared["value"] as Dictionary)["candidate"])
	if not live_adopted.get("ok", false):
		return live_adopted

	return _admit_and_forward(action_receipt, source_kind, transaction_id, reservation_request,
		sequence_candidate, causal_sequence_receipt, recovery_payload, pending_after)


## Ordinal 1 is durable (`recovery_payload.payload_phase=="admission_ready"`) but the admission CAS
## itself never completed before a crash. Replays `prepare_reservation()` deterministically from the
## retained request/candidate rather than re-running policy/board-fate/view preparation.
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


## Repeats the shared last-sequence/run-revision CAS, then dispatches forward recovery in the frozen
## source-kind order.
func _admit_and_forward(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		reservation_request: Dictionary, sequence_candidate: Dictionary, causal_sequence_receipt: Dictionary,
		recovery_payload: Dictionary, pending_after: Dictionary) -> Dictionary:
	var prepared_state: Dictionary = _state_port.call(&"prepare_sequence_reservation", reservation_request, causal_sequence_receipt)
	if not prepared_state.get("ok", false):
		return prepared_state
	var state_after_ordinal2: Dictionary = ((prepared_state["value"] as Dictionary)["candidate"] as Dictionary)["state_after"]
	var header2 := {
		"kind": &"consequence_admission", "operation_ordinal": 2, "run_id": str(action_receipt["run_id"]),
		"source_ids": [transaction_id], "stage": "sequence_committed", "transaction_id": transaction_id,
	}
	var checkpoint2: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint", header2, state_after_ordinal2)
	if not checkpoint2.get("ok", false):
		return checkpoint2
	var admission_checkpoint_candidate := {
		"candidate": (checkpoint2["value"] as Dictionary)["candidate"],
		"checkpoint_receipt": (checkpoint2["value"] as Dictionary)["checkpoint_receipt"],
	}
	var admission_prepared: Dictionary = _causal_sequence_port.call(&"prepare_admission",
		sequence_candidate, admission_checkpoint_candidate, str(pending_after["recovery_payload_sha256"]))
	if not admission_prepared.get("ok", false):
		return admission_prepared
	var admitted: Dictionary = _causal_sequence_port.call(&"commit", (admission_prepared["value"] as Dictionary)["candidate"])
	if not admitted.get("ok", false):
		return admitted

	return _resume_forward(action_receipt, source_kind, transaction_id, {}, {})


## Forward-only recovery from `sequence_committed` onward, driven entirely by the LIVE persisted
## pending record (never a process-local cache): commit action candidate -> board fate (departure
## only) -> ScheduleView (departure only) -> publication callbacks -> terminal cleanup. `live_state`/
## `pending_dict` are accepted for the fresh-admission call path's convenience but are re-read from a
## live capture when empty, so a genuinely reconstructed coordinator resumes identically.
func _resume_forward(action_receipt: Dictionary, source_kind: String, transaction_id: String,
		live_state: Dictionary, pending_dict: Dictionary) -> Dictionary:
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

	# 1. Commit the action source (its sole live commit).
	var source_committed: Dictionary = source_port.call(&"commit_recovery_action", action_candidate, action_receipt)
	if not source_committed.get("ok", false):
		return source_committed

	# 2. Board fate (departure only).
	if is_departure:
		var board_candidate: Dictionary = recovery_payload["board_candidate"]
		var board_committed: Dictionary = _board_fate_port.call(&"commit", board_candidate)
		if not board_committed.get("ok", false):
			return board_committed

		# 3. ScheduleView (departure only).
		var condition_receipt: Dictionary = recovery_payload["condition_candidate"]
		var view_committed: Dictionary = _schedule_view_port.call(&"commit_condition_departure", {
			"condition_receipt": condition_receipt,
			"schedule_view_before": recovery_payload["schedule_view_before"],
			"schedule_view_before_sha256": recovery_payload["schedule_view_before_sha256"],
			"schedule_view_after": recovery_payload["schedule_view_after"],
			"schedule_view_after_sha256": recovery_payload["schedule_view_after_sha256"],
		})
		if not view_committed.get("ok", false):
			return view_committed

	# 4. Advance to publication_pending if not already there.
	if str(pending_dict["stage"]) != "publication_pending":
		var advanced := _advance_to_publication_pending(transaction_id, pending_dict)
		if not advanced.get("ok", false):
			return advanced
		pending_dict = advanced["pending_dict"]

	# 5. Run every publication callback in order.
	var publication_plan: Array = recovery_payload["publication_plan"]
	var progress: Dictionary = pending_dict["publication_progress"]
	while int(progress["cursor"]) < publication_plan.size():
		var index: int = int(progress["cursor"])
		var recipe: Dictionary = publication_plan[index]
		var callback_result := _run_publication_callback(recipe, recovery_payload, action_receipt, source_port, pending_dict)
		if not callback_result.get("ok", false):
			return callback_result
		var advanced_progress := _advance_publication_progress(transaction_id, str(recipe["participant"]),
			(callback_result["disposition"] as String), (callback_result["source_receipt"] as Dictionary), progress)
		if not advanced_progress.get("ok", false):
			return advanced_progress
		progress = advanced_progress["progress"]

	# 6. Terminal cleanup, once the cursor is complete.
	var cleaned := _terminal_cleanup(transaction_id)
	if not cleaned.get("ok", false):
		return cleaned

	return {"ok": true, "code": &"action_consequence_accepted", "value": {
		"action_receipt": action_receipt.duplicate(true), "source_kind": source_kind, "departure": is_departure,
	}, "receipt": {}}


func _advance_to_publication_pending(transaction_id: String, pending_dict: Dictionary) -> Dictionary:
	var publication_progress := {
		"cursor": 0, "complete": false, "callback_receipts": {},
	}
	var advanced: Dictionary = _state_port.call(&"prepare_recovery_advance", transaction_id, &"sequence_committed",
		&"publication_pending", {}, null, null, publication_progress)
	if not advanced.get("ok", false):
		return advanced
	var advance_value: Dictionary = advanced["value"]
	var checkpointed := _checkpoint_and_adopt(advance_value["checkpoint_header"], advance_value["stage_candidate"])
	if not checkpointed.get("ok", false):
		return checkpointed
	return {"ok": true, "pending_dict": (checkpointed["state_after"]["pending"] as Dictionary)}


## `pending_dict` supplies the two fields the causal-sequence callback materializes at publish time
## rather than reading from its own recipe (frozen contract: "the coordinator reads the immutable
## admission receipt from the pending record, never from a recipe, and materializes the
## causal-sequence call as exactly {causal_sequence_receipt,admission_checkpoint_receipt}") --
## `admission_checkpoint_receipt` lives on the pending record itself; `causal_sequence_receipt` is
## recovered from this coordinator's own retained reservation candidate (see the class-doc SCOPE NOTE
## on `recovery_payload`'s free-form additions).
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


## `board_fate_receipt` is not itself a separate recovery_payload field (see the class-doc SCOPE
## NOTE): it is recovered from the departure's own publication_plan recipe, the one place its exact
## bytes are durably retained.
func _board_fate_receipt_from_payload(recovery_payload: Dictionary) -> Dictionary:
	for recipe: Variant in (recovery_payload["publication_plan"] as Array):
		var entry: Dictionary = recipe
		if str(entry["participant"]) == "board_fate":
			return (entry["publication"] as Dictionary)["board_fate_receipt"]
	return {}


func _advance_publication_progress(transaction_id: String, callback_id: String, disposition: String,
		source_receipt: Dictionary, progress: Dictionary) -> Dictionary:
	var callback_receipts: Dictionary = (progress["callback_receipts"] as Dictionary).duplicate(true)
	callback_receipts[callback_id] = {"callback_id": callback_id, "source_receipt": source_receipt, "disposition": disposition}
	var next_cursor: int = int(progress["cursor"]) + 1
	var new_progress := {
		"cursor": next_cursor, "complete": next_cursor >= _publication_plan_size(transaction_id),
		"callback_receipts": callback_receipts,
	}
	var advanced: Dictionary = _state_port.call(&"prepare_recovery_advance", transaction_id, &"publication_pending",
		&"publication_pending", {}, null, null, new_progress)
	if not advanced.get("ok", false):
		return advanced
	var advance_value: Dictionary = advanced["value"]
	var checkpointed := _checkpoint_and_adopt(advance_value["checkpoint_header"], advance_value["stage_candidate"])
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
	var checkpointed := _checkpoint_and_adopt(advance_value["checkpoint_header"], advance_value["stage_candidate"])
	if not checkpointed.get("ok", false):
		return checkpointed
	return {"ok": true}


func _checkpoint_and_adopt(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
	var checkpoint: Dictionary = _checkpoint_port.call(&"prepare_consequence_checkpoint", checkpoint_header, stage_candidate)
	if not checkpoint.get("ok", false):
		return checkpoint
	var committed: Dictionary = _checkpoint_port.call(&"commit_consequence_checkpoint",
		(checkpoint["value"] as Dictionary)["candidate"], (checkpoint["value"] as Dictionary)["checkpoint_receipt"])
	if not committed.get("ok", false):
		return committed
	var live_prepared: Dictionary = _state_port.call(&"prepare_restore", stage_candidate)
	if not live_prepared.get("ok", false):
		return live_prepared
	var live_committed: Dictionary = _state_port.call(&"commit", (live_prepared["value"] as Dictionary)["candidate"])
	if not live_committed.get("ok", false):
		return live_committed
	return {"ok": true, "state_after": stage_candidate}


func _publication_plan_size(transaction_id: String) -> int:
	var captured: Dictionary = _state_port.call(&"capture")
	if not captured.get("ok", false):
		return -1
	var live_state: Dictionary = (captured["value"] as Dictionary)["state"]
	var pending: Variant = live_state.get("pending")
	if pending == null or str((pending as Dictionary).get("transaction_id", "")) != transaction_id:
		return -1
	return ((pending as Dictionary)["recovery_payload"] as Dictionary)["publication_plan"].size()


# -------------------------------------------------------------------------------------------------
# resume_pending() -- empty-process restart. Uses only restored source kind, action candidate/hash,
# action receipt, publication recipe, and the retained production source object.
# -------------------------------------------------------------------------------------------------

func resume_pending() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if _minesweeper_round_source_port == null or _shop_purchase_source_port == null:
		return _fail(&"action_source_ports_unconfigured", "configure_action_source_ports() is required first", {})
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
	if str(pending_dict["stage"]) != "sequence_committed" and str(pending_dict["stage"]) != "publication_pending":
		return _fail(&"consequence_resume_requires_admitted_transaction",
			"resume_pending only resumes an already-admitted action-source transaction", {})

	var recovery_payload: Dictionary = pending_dict["recovery_payload"]
	var action_receipt: Dictionary = recovery_payload["action_receipt"]
	var transaction_id := str(pending_dict["transaction_id"])
	var result := _resume_forward(action_receipt, source_kind, transaction_id, live_state, pending_dict)
	if not result.get("ok", false):
		return result
	return {"ok": true, "code": &"ok", "value": {"resumed": true, "source_kind": source_kind}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# Shared helpers
# -------------------------------------------------------------------------------------------------

## `minesweeper_round`'s projection is the source's own already-NONE post-completion candidate,
## carried inside `action_candidate.board_projection` (added by `MinesweeperRoundCoordinator
## .complete_round()`). `shop_purchase` never touches the board: its projection is the port's own
## current live board capture, read through `DesktopBoardFatePort.capture()`.
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
		sequence_candidate: Dictionary) -> Dictionary:
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
		# Own free-form additions (not part of the frozen 17-key admission-ready shape, but
		# DesktopConsequenceState._validate_pending() places no exact-key requirement on
		# recovery_payload's own internal shape -- only that it is a Dictionary matching its own
		# hash): the exact causal-sequence reservation inputs/outputs, retained so a crash between
		# the ordinal-1 write and the admission CAS can deterministically replay
		# prepare_reservation() without re-running policy/board-fate/view preparation.
		"causal_sequence_reservation_request": reservation_request.duplicate(true),
		"causal_sequence_reservation_candidate": sequence_candidate.duplicate(true),
	}
	return {"recovery_payload": recovery_payload}


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
