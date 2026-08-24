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
##
## KNOWN GAP, LEFT OPEN AND FLAGGED (dwm-p2r.35.3 remediation, finding A-C3 review note; not fixed by
## this remediation -- see that finding's own writeup for why): `DesktopConsequenceState.pending
## .participant_receipts` is threaded through every `prepare_recovery_advance()` call in this file
## (`_advance_to_publication_pending()`, `_advance_publication_progress()`, `_terminal_cleanup()`) but
## every one of those call sites passes a literal `{}`, and `prepare_recovery_advance()` itself
## unconditionally overwrites `pending_after["participant_receipts"]` with whatever it is handed
## (`DesktopConsequenceState.gd`, inside `prepare_recovery_advance()`) -- so this field is durably
## persisted as an always-empty dictionary at every stage, never the per-participant receipts its own
## name implies. This coordinator does retain the equivalent information durably elsewhere (per-
## callback publication receipts live in `pending.publication_progress.callback_receipts`; the
## admission-time causal/action/board-fate receipts live inside `recovery_payload`'s own free-form
## additions and `publication_plan` recipes -- see `_action_receipt_from_payload()`/
## `_board_fate_receipt_from_payload()` above), so no recovery path in THIS plan actually reads
## `participant_receipts` back. But nothing establishes that `participant_receipts` is dead-by-design
## rather than dead-by-oversight, and a downstream plan that reads this file's own doc comments or the
## frozen `DesktopContinuationOperationJournal` interface signature (which names an unrelated,
## differently-shaped `participant_receipts` field of its own) could reasonably expect THIS field to
## carry real per-participant presence rules it never does. Populating it correctly would mean
## inventing an unstated semantic convention for what belongs in it -- the frozen contracts text never
## defines presence rules for this exact field (unlike `action_receipt`/`condition_receipt`/
## `board_fate_receipt`/etc., whose presence-by-stage IS frozen) -- which is a genuine design decision
## beyond this remediation wave's scope, not a mechanical wiring fix. Left exactly as found;
## explicitly flagged here so a future plan is told, not left to discover it the hard way.

const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _GATE_OWNER := &"causal_transaction"
const _ACTION_SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]
## dwm-p2r.35.7 remediation (finding 3): added `release_recovery_lease` -- see _resume_forward()'s own
## doc comment on why the causal_transaction release moved out of publish_recovery_action() and into
## this fourth, coordinator-driven method.
const _SOURCE_RECOVERY_METHODS: Array[String] = [
	"validate_recovery_action", "commit_recovery_action", "publish_recovery_action", "release_recovery_lease",
]
const _ACCEPT_REQUEST_KEYS: Array[String] = [
	"action_receipt", "action_candidate", "prepared_checkpoint_receipt", "expected_run_revision",
	"expected_board_identity", "expected_board_revision",
]

## Review-fix pass (dwm-p2r.32.8, CRITICAL 1/2): the frozen `destination_intent`/`notification_intent`
## shapes and the (ordinal, stage) pairing this coordinator itself authors (IMPORTANT 3).
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
## Review-fix pass (dwm-p2r.32.8, CRITICAL 1) additive DI seam -- see configure_identity_issuer()'s
## own doc comment.
var _identity_issuer: Object = null

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


## Review-fix pass (dwm-p2r.32.8) additive DI seam beyond configure()'s frozen 5-argument signature
## (own design choice, matching MinesweeperRoundCoordinator's own established
## configure_durable_checkpoint()/configure_consequence_checkpoint() precedent for "the frozen seam is
## too narrow, add a second one"): accept_prepared_action()'s own outer receipt_id/receipt_provenance
## (CRITICAL 1) needs a derive_child()-capable issuer, which the frozen configure() has no parameter
## for.
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

	# dwm-p2r.35.7 remediation (finding 1): moved after receipt validation/transaction_id extraction
	# (was checked first, before this coordinator had any idea which transaction it was even
	# targeting) so pre-admission abandonment (plan02-frozen-contracts.md line 2271) can target only
	# the matching pending transaction, never a blind global abandon. See _abandon_pre_admission()'s
	# own doc comment for what "abandoned" means here.
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


## dwm-p2r.35.7 remediation (finding 1): plan02-frozen-contracts.md line 2271 -- "Until Plan 03 injects
## its real condition policy and sole ScheduleView/route composition, a merely pre-admission
## accept_prepared_action() returns condition_departure_ports_unconfigured before causal admission,
## marks only the already-durable unpromoted source checkpoint abandoned through the injected
## checkpoint port, releases causal_transaction, and commits no live participant; it never creates or
## promotes a consequence checkpoint." This method performs the first and third of those: marking the
## checkpoint port's own durable record abandoned, and clearing DesktopConsequenceState's own pending
## bookkeeping back to null through the state port's established prepare_restore()/commit()
## "live-adopt" seam (the SAME seam _checkpoint_and_adopt()/adopt_durable_checkpoint_if_live_is_behind()
## already use elsewhere in this file) -- a bookkeeping cleanup of this coordinator's OWN transaction
## ledger, never "committing a participant" in this file's own established vocabulary (source/board/
## view -- see _resume_forward()'s three forward-commit steps). It calls neither
## prepare_consequence_checkpoint() nor commit_consequence_checkpoint(): no new ordinal is ever
## created or promoted, matching the frozen law's own closing clause exactly. Releasing the actual
## `causal_transaction` gate TOKEN is the caller's job: this coordinator never acquires that lease
## itself (only the source participant does, and only it retains the token to release it with) -- see
## MinesweeperRoundCoordinator._call_accept_and_finalize()'s own release on this exact failure code.
##
## Returns ok:true on successful abandonment (a coordinator-internal disposition, never surfaced to
## an external caller directly) or a genuine failure if no matching pre-admission pending exists to
## abandon. Both callers -- this method's own condition_departure_ports_unconfigured branch above,
## and resume_pending()'s pre-admission branch below -- translate a successful abandonment into
## their own appropriate public result.
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

	# CRITICAL 2 (Review-fix pass): read and validate the intents the policy evaluated alongside
	# condition_receipt, instead of discarding them here as before.
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
		schedule_view_before_sha256, schedule_view_after_sha256, is_departure, reservation_request, sequence_candidate,
		destination_intent, notification_intent)
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
	var pairing1 := _validate_ordinal_stage_pairing(header1)
	if not pairing1.get("ok", false):
		return pairing1
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
	var pairing2 := _validate_ordinal_stage_pairing(header2)
	if not pairing2.get("ok", false):
		return pairing2
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
	# CRITICAL 2 (Review-fix pass): retained on recovery_payload by _build_admission_ready_payload()
	# so a reconstructed coordinator resuming forward recovery (resume_pending()) reads the SAME
	# intents the policy evaluated during the original _prepare_and_admit() pass, never recomputes them.
	var destination_intent: Variant = recovery_payload.get("destination_intent")
	var notification_intent: Variant = recovery_payload.get("notification_intent")

	# 1. Commit the action source (its sole live commit).
	var source_committed: Dictionary = source_port.call(&"commit_recovery_action", action_candidate, action_receipt)
	if not source_committed.get("ok", false):
		return source_committed

	# 2. Board fate (departure only).
	var schedule_view_commit_receipt: Variant = null
	if is_departure:
		var board_candidate: Dictionary = recovery_payload["board_candidate"]
		var board_committed: Dictionary = _board_fate_port.call(&"commit", board_candidate)
		if not board_committed.get("ok", false):
			return board_committed

		# 3. ScheduleView (departure only).
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

	# 4. Advance to publication_pending if not already there. CRITICAL 2 (Review-fix pass): this is
	# the ONE edge that persists destination_intent/notification_intent onto the durable pending
	# record -- DesktopConsequenceState.prepare_recovery_advance() only overwrites pending.destination_
	# intent/notification_intent when passed non-null, so every LATER advance below (which always
	# passes null) leaves whatever was set here untouched, landing both fields in the persisted
	# pending record exactly once per transaction, replay-safe under crash-then-resume.
	if str(pending_dict["stage"]) != "publication_pending":
		var advanced := _advance_to_publication_pending(transaction_id, pending_dict, destination_intent, notification_intent)
		if not advanced.get("ok", false):
			return advanced
		pending_dict = advanced["pending_dict"]

	# 5. Run every publication callback in order.
	var publication_plan: Array = recovery_payload["publication_plan"]
	var progress: Dictionary = pending_dict["publication_progress"]
	while int(progress["next_callback_index"]) < publication_plan.size():
		var index: int = int(progress["next_callback_index"])
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

	# dwm-p2r.35.7 remediation (finding 3): release causal_transaction HERE -- after terminal cleanup,
	# not inside the action_source publish callback (index 1 of up to 3) -- so board-fate publish and
	# terminal cleanup itself both run under the still-active lease, matching DesktopBoardFatePort's
	# own class-doc invariant that the coordinator holds this lease across one departure's whole
	# prepare-to-publish span. The source port is the actual token holder (this coordinator never
	# acquires the lease itself, only checks is_internal_owner_active); release_recovery_lease() is
	# idempotent when no token is held (e.g. a resume_pending()-driven forward recovery in a fresh
	# process, which never acquired one in the first place).
	source_port.call(&"release_recovery_lease")

	# CRITICAL 1 (Review-fix pass): return the frozen accept_prepared_action() success shape exactly,
	# never the fabricated {action_receipt,source_kind,departure} shape this returned before. Every
	# ingredient below is already durably retained on recovery_payload/publication_plan or just
	# computed above, so this assembly is itself replay-safe (a second _resume_forward() call for the
	# same transaction reaches the same bytes).
	var causal_sequence: int = int(((recovery_payload["causal_sequence_reservation_candidate"] as Dictionary)
		["causal_sequence_receipt"] as Dictionary)["causal_sequence"])
	var board_fate_receipt: Variant = (_board_fate_receipt_from_payload(recovery_payload) if is_departure else null)
	var condition_receipt: Dictionary = recovery_payload["condition_candidate"]
	var value := {
		"causal_sequence": causal_sequence, "condition_receipt": condition_receipt.duplicate(true),
		"board_fate_receipt": board_fate_receipt, "schedule_view_commit_receipt": schedule_view_commit_receipt,
		"destination_intent": destination_intent, "notification_intent": notification_intent,
	}
	var receipt_built := _build_action_consequence_receipt(action_receipt, transaction_id, causal_sequence, is_departure)
	if not receipt_built.get("ok", false):
		return receipt_built
	return {"ok": true, "code": &"action_consequence_accepted", "value": value, "receipt": receipt_built["receipt"]}


func _advance_to_publication_pending(transaction_id: String, pending_dict: Dictionary,
		destination_intent: Variant, notification_intent: Variant) -> Dictionary:
	# dwm-p2r.35.7 remediation (finding 5): the frozen shape (plan02-frozen-contracts.md lines 311-317)
	# carries its own admitted publication_plan_sha256/callback_ids -- both already durable inside
	# recovery_payload since ordinal 1, never recomputed here.
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


## Review-fix pass (dwm-p2r.32.8) bug fix -- see resume_pending()'s own doc comment at its call site.
## Mirrors _board_fate_receipt_from_payload()'s identical recovery pattern: the full action_receipt is
## not a top-level recovery_payload field, but IS durably retained inside publication_plan's own
## "action_source" recipe, present for every payload_phase=admission_ready payload regardless of
## departure/no-departure.
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
	# dwm-p2r.35.7 remediation (finding 5): the frozen shape carries no "complete" member of its own --
	# completeness is derived (next_callback_index >= callback_ids.size()) wherever needed, not stored.
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


# -------------------------------------------------------------------------------------------------
# resume_pending() -- empty-process restart. Uses only restored source kind, action candidate/hash,
# action receipt, publication recipe, and the retained production source object.
# -------------------------------------------------------------------------------------------------

## Stage rank for `adopt_durable_checkpoint_if_live_is_behind()`'s own "is live behind the durable
## checkpoint" comparison -- the pre-admission pair collapses to the same rank since neither is ever
## the checkpoint's own stage (the checkpoint port only ever stores an ordinal>=1 header; ordinal 0's
## own pre-admission document is never adopted here, matching the frozen law that a pre-admission
## checkpoint carries no live mutation obligation).
const _STAGE_RANK: Dictionary = {
	"action_prepared": 0, "prepared_checkpointed": 0, "sequence_committed": 1, "publication_pending": 2,
}

## dwm-p2r.35.3 remediation (finding A-C3, "no reader"): the durable admission checkpoint
## (SaveManagerCheckpointPort's desktop-consequence-checkpoint.json) is the ONLY thing guaranteed
## durable at the exact moment a source-kind transaction is admitted -- "the admission checkpoint is
## now durable on disk... From here forward this coordinator never rewinds" (DesktopCausalSequencePort
## .commit()'s own CRITICAL-1 comment). The containing v4 RunSnapshot autosave, by contrast, only
## captures whatever was live at ITS OWN last write: a crash between admission-checkpoint-commit and
## the next autosave leaves the durably admitted transaction invisible to ordinary Restore/New-Run
## bootstrap, and resume_pending() below -- driven entirely by the state port's own live capture() --
## would silently see nothing pending.
##
## Called at the top of resume_pending() (also reachable directly, e.g. for a caller that wants to
## adopt without immediately forward-recovering). Reads the checkpoint port's own durable record and,
## ONLY when live state does not already reflect an equally or more advanced record for the SAME
## transaction, adopts it through the state port's own capture()/prepare_restore()/commit() seam --
## never a raw dictionary write -- so every later step (including resume_pending()'s own forward
## recovery) then sees it exactly as if the RunSnapshot itself had captured it. Never regresses: live
## state already at or ahead of the durable checkpoint (or already tracking a DIFFERENT transaction --
## which the exclusive `causal_transaction` gate owner should make impossible, but this stays
## conservative rather than guessing) is left untouched.
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
	# dwm-p2r.35.7 remediation (finding 1): a restored pre-admission pending (stage="action_prepared")
	# previously hard-FAILED resume_pending() here -- and since ApplicationBootstrap propagates that
	# failure straight out of _configure_desktop_production_graph() (autoload/ApplicationBootstrap.gd,
	# _configure_desktop_production_graph()'s own `if not resumed.get("ok", false): return resumed`),
	# a run restored with a minesweeper_round/shop_purchase pending at action_prepared could never
	# even finish booting, let alone start a fresh transaction afterward (prepare_action_handoff()
	# refuses while ANY pending exists). This coordinator's own bootstrap never configures the
	# condition-departure ports (plan02-frozen-contracts.md line 2271: "construct but leave both
	# production condition-departure slots fail-closed" -- Plan 03's own job), so a pre-admission
	# pending found here can only ever be abandoned, never genuinely re-admitted without the original
	# caller's request bytes (which this restart has no route back to). Abandonment gives it that
	# legitimate path forward instead of deadlocking bootstrap.
	if str(pending_dict["stage"]) == "action_prepared":
		if _condition_policy_port != null and _schedule_view_port != null:
			# Not reachable in this plan's own production bootstrap (see above), but stays honest
			# rather than silently discarding a transaction that could, in principle, still be
			# re-admitted by whichever caller originally drove it -- that re-admission needs the
			# original request bytes this coordinator was never given.
			return _fail(&"consequence_resume_pre_admission_requires_original_request",
				"resume_pending cannot re-run policy evaluation for a pre-admission pending without the original request", {})
		var abandoned := _abandon_pre_admission(str(pending_dict["transaction_id"]), source_kind)
		if not abandoned.get("ok", false):
			return abandoned
		return {"ok": true, "code": &"ok", "value": {"resumed": false, "abandoned": true}, "receipt": {}}
	if str(pending_dict["stage"]) != "sequence_committed" and str(pending_dict["stage"]) != "publication_pending":
		return _fail(&"consequence_resume_requires_admitted_transaction",
			"resume_pending only resumes an already-admitted action-source transaction", {})

	var recovery_payload: Dictionary = pending_dict["recovery_payload"]
	# Review-fix pass (dwm-p2r.32.8) bug fix, discovered by the new CRITICAL 2 forward-recovery-replay
	# test: recovery_payload has never carried a top-level "action_receipt" key (its only keys are the
	# frozen admission-ready 17 plus this task's own free-form additions) -- this line has read an
	# absent key since the original implementation, unreachable until a test actually drove
	# resume_pending() over a transaction with a live pending recovery_payload (the pre-existing test
	# only exercised the trivial "no pending transaction" branch). The full action_receipt IS durably
	# retained, inside publication_plan's own "action_source" recipe (brief line 367's own
	# publication_plan; mirrors _board_fate_receipt_from_payload()'s identical recovery pattern).
	var action_receipt: Dictionary = _action_receipt_from_payload(recovery_payload)
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
		# Own free-form additions (not part of the frozen 17-key admission-ready shape, but
		# DesktopConsequenceState._validate_pending() places no exact-key requirement on
		# recovery_payload's own internal shape -- only that it is a Dictionary matching its own
		# hash): the exact causal-sequence reservation inputs/outputs, retained so a crash between
		# the ordinal-1 write and the admission CAS can deterministically replay
		# prepare_reservation() without re-running policy/board-fate/view preparation.
		"causal_sequence_reservation_request": reservation_request.duplicate(true),
		"causal_sequence_reservation_candidate": sequence_candidate.duplicate(true),
		# CRITICAL 2 (Review-fix pass, dwm-p2r.32.8): another free-form addition alongside the pair
		# above, for the identical reason -- a reconstructed coordinator's _resume_forward() must read
		# the SAME intents _prepare_and_admit() validated, never recompute them from a policy port it
		# may not even have live access to during forward recovery.
		"destination_intent": ((destination_intent as Dictionary).duplicate(true) if destination_intent != null else null),
		"notification_intent": ((notification_intent as Dictionary).duplicate(true) if notification_intent != null else null),
	}
	return {"recovery_payload": recovery_payload}


## CRITICAL 2 (Review-fix pass): shape-validates each nonnull intent against its frozen exact-key
## contract, then enforces the brief's own departure/no-departure pairing law -- "a DEPARTURE enqueues
## exactly one destination intent and suppresses notification; a NO-DEPARTURE may enqueue zero-or-one
## notification intent and never calls the view port" -- so a misbehaving/misarmed condition policy
## can never smuggle an invalid combination past this coordinator.
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


## IMPORTANT 3 (Review-fix pass) -- CORRECTED (dwm-p2r.35.3 remediation, finding A-C3): this comment
## previously justified leaving ordinal 0 (authored by the two source participants,
## MinesweeperRoundCoordinator/MinesweeperShopPurchaseParticipant) and ordinals 8-12 (authored by
## DesktopConsequenceState.prepare_recovery_advance(), reached only through this file's own
## _checkpoint_and_adopt()) unguarded, by asserting "the checkpoint port's occupied-slot conflict law
## already rejects a rewrite of an already-written (transaction_id, ordinal) with different bytes."
## That law did not exist at the time this was written -- SaveManagerCheckpointPort.
## commit_consequence_checkpoint() unconditionally overwrote one fixed-path document on every write,
## tracked no slot, and could never return consequence_checkpoint_conflict. Even with that law now
## implemented (it protects only against a REWRITE of an already-occupied slot, never a WRONG
## ordinal/stage pairing on a slot's first write), the actual fix is that SaveManagerCheckpointPort
## .prepare_consequence_checkpoint() itself now cross-checks EVERY checkpoint header --
## DesktopConsequenceState.validate_checkpoint_ordinal_stage(), covering ordinals 0, 1, 2, and 8-12 --
## since that method is the one place every author's write already passes through, regardless of
## which file authors the header. This coordinator's own check below remains as a fast, early-fail
## convenience for the two ordinals (1, 2) it directly authors as literal dict headers -- most prone
## to a copy-paste mistake, since nothing else forces their ordinal and stage string to agree -- not
## because it is the only guard.
func _validate_ordinal_stage_pairing(header: Dictionary) -> Dictionary:
	var ordinal := int(header["operation_ordinal"])
	var expected_stage: Variant = _ORDINAL_STAGE_LAW.get(ordinal)
	if expected_stage == null or str(header["stage"]) != String(expected_stage):
		return _fail(&"consequence_checkpoint_ordinal_stage_invalid",
			"operation_ordinal %d must pair with stage %s" % [ordinal, str(expected_stage)],
			{"operation_ordinal": ordinal, "stage": str(header["stage"])})
	return {"ok": true}


## CRITICAL 1 (Review-fix pass): derives accept_prepared_action()'s own outer receipt_id/receipt_
## provenance through the injected identity issuer, mirroring MinesweeperRoundCoordinator._build_
## round_action_receipt()'s established derive_child() pattern exactly -- same parent_receipt_id
## source (the action's own transaction_issuer_receipt), same ordinal-0 convention. PROMINENT FLAG
## (see the Task-8 report's Review-fix pass section): "action_consequence" is not one of the 22
## originally frozen CHILD_KINDS members -- no existing kind represents this coordinator's own outer
## envelope receipt, since every existing kind is either a domain artifact or one of the ingredient
## receipts this envelope already carries by name -- so CHILD_KINDS was extended additively by one
## member (dwm-p2r.32.8) to cover it, with matching enumeration-test coverage.
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
