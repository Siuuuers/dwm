extends RefCounted

const PERFORMANCE := preload("res://scripts/domain/minesweeper/BoardPerformance.gd")

## Application-level desktop Minesweeper round coordinator (Plan 02 Task 5, dwm-p2r.32,
## req.minesweeper.round_contract). Deliberately WITHOUT class_name: the global name
## `MinesweeperRoundCoordinator` is owned by the frozen, retained
## `scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd`. Callers/tests preload this file by
## path.
##
## Owns exactly one DesktopBoardState instance and drives it, plus the three injected ports and
## the identity issuer, through the frozen operation order: guard -> duplicate/conflict lookup ->
## current-state and request validation -> issuer-backed trusted spec -> materialize/adopt -> pure
## reveal -> preview the checkpoint ID -> prepare the combined GameState candidate/receipt ->
## prepare the checkpoint -> capture backups -> provisionally commit the checkpoint -> commit
## GameState/board -> seal -> publish. Task 5 proves this only against contract fakes: no
## SaveManager lifetime board lock or direct storage call exists here.
##
## Routine reveal/flag/chord and visibility commands share the identity/revision/receipt rules but
## commit only a new stable in-memory DesktopBoardState revision -- they never touch the state or
## checkpoint ports, since no cost or durability changes after first Reveal (req.minesweeper
## .round_contract: "No other board command changes those costs").

const _BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const _REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")

const _GATE_OWNER := &"causal_transaction"
const _COMPLETE_ROUND_REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "expected_identity", "expected_revision",
]
const _BASE_COMPLETION_ORDINALS := [1, 2]

const _STATE_PORT_METHODS: Array[String] = [
	"guard_external", "capture", "prepare_spec", "prepare_first_reveal", "prepare_board_only",
	"commit", "rollback", "publish",
]
const _CHECKPOINT_PORT_METHODS: Array[String] = [
	"capture", "preview_checkpoint_id", "prepare_checkpoint", "commit_checkpoint",
	"seal_checkpoint", "rollback",
]
const _DURABLE_CHECKPOINT_PORT_METHODS: Array[String] = [
	"capture", "preview_checkpoint_id", "prepare_checkpoint", "commit_checkpoint", "rollback",
]
const _GENERATION_PORT_METHODS: Array[String] = ["materialize", "begin_search", "run_search_slice"]
const _ISSUER_METHODS: Array[String] = ["verify_issued"]

const _FIRST_REVEAL_REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "expected_identity", "expected_revision",
	"difficulty_id", "cell_index",
]
const _DEBUG_BEGIN_REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "expected_identity", "expected_revision",
	"difficulty_id",
]
const _GENERIC_REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "expected_identity", "expected_revision",
]
const _CELL_REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "expected_identity", "expected_revision", "cell_index",
]
const _FLAG_REQUEST_KEYS: Array[String] = [
	"transaction_id", "transaction_issuer_receipt", "expected_identity", "expected_revision",
	"cell_index", "flagged",
]

var _board_state: _BOARD_STATE
var _state_port: Object = null
var _checkpoint_port: Object = null
var _generation_port: Object = null
var _identity_issuer: Object = null
var _fatal_failure: Dictionary = {}

## Plan 02 Task 6 (dwm-p2r.32), Phase D additions (brief line 154-156). Deliberately separate from
## the frozen `configure()` above: `configure_durable_checkpoint()` "replaces the Task-5 fake seam
## only after v4 is green... retains the same issuer/generator/state owner identities" (brief line
## 295) -- it swaps ONLY the checkpoint path, never installs a second coordinator, and `reveal()`
## below falls back to the untouched Task-5 fake-checkpoint `_first_reveal()` path whenever this is
## unconfigured (every existing Task-5 test never calls this, so their behavior is byte-for-byte
## unchanged).
var _durable_checkpoint_port: Object = null
var _snapshot_composer: Script = null
var _durable_consequence_state_port: Object = null
## Stored for this coordinator's own causal-sequence publication paths (round completion through
## DesktopCausalSequencePort) -- NOT first Reveal's own publish() step, which is unrelated and
## untouched: DesktopPublicationLedger.record_before_emit() requires a `causal_sequence_receipt`
## field first Reveal's own board_start receipt does not carry (own documented design choice, see
## the class doc above and the task-6 report).
var _publication_ledger: Object = null

## Plan 02 Task 8 (dwm-p2r.32) additions: complete_round()'s own action-source handoff into
## DesktopConsequenceCoordinator, mirroring MinesweeperShopPurchaseParticipant's established shape.
## `_consequence_coordinator`/`_consequence_gate` are the frozen configure_consequence_port() pair;
## `_round_consequence_state_port`/`_round_checkpoint_port` are an additive DI seam beyond that
## frozen 2-arg signature (own design choice -- see configure_consequence_checkpoint()'s own doc
## comment), matching this file's own established configure_durable_checkpoint() precedent for
## "the frozen seam is too narrow, add a second one" situations.
var _consequence_coordinator: Object = null
var _consequence_gate: ApplicationMutationGate = null
var _round_consequence_state_port: Object = null
var _round_checkpoint_port: Object = null
var _consequence_gate_token := ""
var _round_completions: Dictionary = {}
var _reward_port: Object = null
var _source_checkpoint_capture := Callable()
## dwm-p2r.35.7 remediation (findings 1 and 2): the exact accept_prepared_action() request this same
## process retained when it first durably wrote ordinal 0 for a transaction -- mirrors
## MinesweeperShopPurchaseParticipant's own `participant_snapshot_ids` retention pattern, adapted to
## this source's own richer request shape. Consulted only by _recognize_live_round_pending() below,
## when a durable pending record for the SAME transaction already exists (this process's own earlier
## attempt committed ordinal 0 but accept_prepared_action() transiently failed, so
## prepare_action_handoff() cannot run a second time) -- a genuinely fresh process has nothing here to
## replay, which is resume_pending()'s own separate job, not complete_round()'s.
var _round_pending_admission_requests: Dictionary = {}
var _round_request_fingerprints: Dictionary = {}
var _round_recovery_committed: Dictionary = {}


func configure_source_checkpoint_capture(capture_inputs: Callable) -> Dictionary:
	if not capture_inputs.is_valid(): return _fail(&"invalid_source_checkpoint_capture", "", {})
	if _source_checkpoint_capture.is_valid() and _source_checkpoint_capture != capture_inputs:
		return _fail(&"source_checkpoint_capture_already_configured", "", {})
	_source_checkpoint_capture = capture_inputs
	return {"ok": true}


func configure_reward_port(port: Object) -> Dictionary:
	if port == null or not _has_all_methods(port, ["prepare_complete", "commit_desktop_completion", "publish_desktop_completion"]):
		return _fail(&"invalid_reward_port", "", {})
	if _reward_port != null and _reward_port != port:
		return _fail(&"reward_port_already_configured", "", {})
	_reward_port = port
	return {"ok": true}


func _init() -> void:
	_board_state = _BOARD_STATE.new()


func configure(state_port: Object, checkpoint_port: Object,
		generation_port: Object, identity_issuer: Object) -> Dictionary:
	if state_port == null or not _has_all_methods(state_port, _STATE_PORT_METHODS):
		return _fail(&"invalid_state_port", "an exact state-port capability is required", {})
	var has_legacy_checkpoint := checkpoint_port != null and _has_all_methods(
		checkpoint_port, _CHECKPOINT_PORT_METHODS)
	var is_configured_durable_checkpoint := (
		checkpoint_port != null
		and checkpoint_port == _durable_checkpoint_port
		and _has_all_methods(checkpoint_port, _DURABLE_CHECKPOINT_PORT_METHODS)
	)
	if not has_legacy_checkpoint and not is_configured_durable_checkpoint:
		return _fail(&"invalid_checkpoint_port",
			"the checkpoint port must provide legacy seal or be the configured durable port", {})
	if generation_port == null or not _has_all_methods(generation_port, _GENERATION_PORT_METHODS):
		return _fail(&"invalid_generation_port", "an exact generation-port capability is required", {})
	if identity_issuer == null or not _has_all_methods(identity_issuer, _ISSUER_METHODS):
		return _fail(&"invalid_identity_issuer", "an exact identity-issuer capability is required", {})
	if _state_port != null or _checkpoint_port != null or _generation_port != null or _identity_issuer != null:
		if _state_port != state_port or _checkpoint_port != checkpoint_port \
				or _generation_port != generation_port or _identity_issuer != identity_issuer:
			return _fail(&"minesweeper_round_coordinator_already_configured",
				"a configured coordinator never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_state_port = state_port
	_checkpoint_port = checkpoint_port
	_generation_port = generation_port
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Plan 02 Task 6 (dwm-p2r.32), Phase D addition (brief line 154). Idempotent on the same instance.
func configure_publication_ledger(publication_ledger: Object) -> Dictionary:
	if publication_ledger == null or not publication_ledger.has_method("record_before_emit"):
		return _fail(&"invalid_publication_ledger", "publication_ledger must expose record_before_emit", {})
	if _publication_ledger != null:
		if _publication_ledger == publication_ledger:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"publication_ledger_already_configured", "", {})
	_publication_ledger = publication_ledger
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Plan 02 Task 6 (dwm-p2r.32), Phase D addition (brief lines 155-156, 295). Once configured,
## `reveal()`'s first-Reveal dispatch routes through `_first_reveal_durable()` instead of the
## Task-5 fake-checkpoint `_first_reveal()`; `_state_port`/`_generation_port`/`_identity_issuer`
## stay exactly what `configure()` already installed.
func configure_durable_checkpoint(checkpoint_port: Object, snapshot_composer: Script,
		consequence_state_port: Object) -> Dictionary:
	if checkpoint_port == null or not _has_all_methods(checkpoint_port,
			_DURABLE_CHECKPOINT_PORT_METHODS):
		return _fail(&"invalid_durable_checkpoint_port", "an exact durable-checkpoint capability is required", {})
	if snapshot_composer == null or not snapshot_composer.has_method("compose"):
		return _fail(&"invalid_snapshot_composer", "snapshot_composer must expose compose", {})
	if consequence_state_port == null or not consequence_state_port.has_method("capture"):
		return _fail(&"invalid_consequence_state_port", "consequence_state_port must expose capture", {})
	if _durable_checkpoint_port != null:
		if _durable_checkpoint_port == checkpoint_port and _snapshot_composer == snapshot_composer \
				and _durable_consequence_state_port == consequence_state_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"durable_checkpoint_already_configured",
			"a configured durable checkpoint never adopts a replacement owner", {})
	_durable_checkpoint_port = checkpoint_port
	_snapshot_composer = snapshot_composer
	_durable_consequence_state_port = consequence_state_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Plan 02 Task 8 (dwm-p2r.32) frozen addition: `port` is the `DesktopConsequenceCoordinator` this
## coordinator hands completed rounds to via `accept_prepared_action()`.
func configure_consequence_port(port: Object, mutation_gate: ApplicationMutationGate) -> Dictionary:
	if port == null or not port.has_method("accept_prepared_action"):
		return _fail(&"invalid_consequence_port", "an exact accept_prepared_action capability is required", {})
	if mutation_gate == null:
		return _fail(&"invalid_mutation_gate", "mutation_gate is required", {})
	if _consequence_coordinator != null or _consequence_gate != null:
		if _consequence_coordinator != port or _consequence_gate != mutation_gate:
			return _fail(&"consequence_port_already_configured", "a configured consequence port never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_consequence_coordinator = port
	_consequence_gate = mutation_gate
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Additive DI seam beyond `configure_consequence_port()`'s frozen two-argument signature (own design
## choice, matching this file's own established `configure_durable_checkpoint()` precedent):
## `complete_round()` needs a `DesktopConsequenceState`-shaped port (for its own ordinal-0 action
## handoff, mirroring `MinesweeperShopPurchaseParticipant.prepare_purchase()`) and a
## `SaveManagerCheckpointPort`-shaped consequence-checkpoint port -- neither fits inside the frozen
## seam's two parameters.
func configure_consequence_checkpoint(consequence_state_port: Object, checkpoint_port: Object) -> Dictionary:
	if consequence_state_port == null or not _has_all_methods(consequence_state_port,
			["capture", "prepare_action_handoff", "prepare_restore", "commit", "prepare_record_base_completion"]):
		return _fail(&"invalid_consequence_state_port", "an exact consequence-state capability is required", {})
	if checkpoint_port == null or not _has_all_methods(checkpoint_port,
			["prepare_consequence_checkpoint", "commit_consequence_checkpoint"]):
		return _fail(&"invalid_consequence_checkpoint_port", "an exact checkpoint-port capability is required", {})
	if _round_consequence_state_port != null or _round_checkpoint_port != null:
		if _round_consequence_state_port != consequence_state_port or _round_checkpoint_port != checkpoint_port:
			return _fail(&"consequence_checkpoint_already_configured", "a configured checkpoint seam never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_round_consequence_state_port = consequence_state_port
	_round_checkpoint_port = checkpoint_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Derives result/reward inputs from the terminal canonical board only -- callers cannot supply an
## outcome, reward, counter delta, effect, unlock, identity, nonce, or sequence. Acquires
## `causal_transaction` before reading/preparing the terminal action, prepares and durably checkpoints
## the completion candidate (ordinal 0, `stage=action_prepared`, Ruling A) WITHOUT changing live
## board truth, then delegates to `accept_prepared_action()` under the still-active lease. The actual
## board transition to phase NONE happens later, as this action source's own
## `commit_recovery_action()` -- the coordinator's forward-recovery "commit action candidate" step --
## exactly mirroring how the Shop participant's own economy delta is applied only at that boundary.
##
## SCOPE NOTE (own documented judgment call): this task derives only a structural outcome
## classification (`exploded`|`cleared`, read directly from the board reducer's own native `outcome`
## field) and the `base_completion_receipts` Supportz-eligibility side effect Task 7 explicitly
## reserved for Task 8. It does NOT reach into `autoload/GameState.gd`'s legacy money/coin/task/
## contact/group reward pipeline (`finish_minesweeper_app_round()` and friends) -- that pipeline
## operates on a hand-supplied 5-value outcome union the pure board reducer cannot derive, requires
## edits to a file outside this task's own Files list, and sits outside the Interface Map's own
## framing of Task 8 as building "generic action consequence/view recovery ports". `condition_before`/
## `condition_after` mirror the Shop participant's own health/pressure/carried_sequela pattern via
## `GameStateDesktopBoardPort`'s matching Task-8 extension.
func complete_round(request: Dictionary) -> Dictionary:
	var retry_id := str(request.get("transaction_id", ""))
	var own_retry := _consequence_gate_token != "" and _consequence_gate != null \
		and _consequence_gate.is_internal_owner_active(_GATE_OWNER) \
		and _round_pending_admission_requests.has(retry_id)
	if own_retry and str(_round_request_fingerprints.get(retry_id, "")) != _fingerprint(request):
		return _fail(&"transaction_conflict", "completion retry must retain its original request", {})
	var guard := {} if own_retry else _guard(&"complete_round")
	if not guard.is_empty():
		return guard
	if _consequence_coordinator == null or _consequence_gate == null:
		return _fail(&"consequence_port_not_configured", "configure_consequence_port() is required before complete_round()", {})
	if _round_consequence_state_port == null or _round_checkpoint_port == null:
		return _fail(&"consequence_checkpoint_not_configured", "configure_consequence_checkpoint() is required before complete_round()", {})
	var shape := _exact_keys(request, _COMPLETE_ROUND_REQUEST_KEYS, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var fingerprint := _fingerprint(request)

	if _round_completions.has(transaction_id):
		var recorded: Dictionary = _round_completions[transaction_id]
		if str(recorded["fingerprint"]) == fingerprint:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"transaction_conflict", "", {"transaction_id": transaction_id})

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify

	# dwm-p2r.35.7 remediation (findings 1 and 2): recognize a durable pending transaction this same
	# process already handed off (ordinal 0 committed, accept_prepared_action() transiently failed) --
	# mirrors MinesweeperShopPurchaseParticipant.prepare_purchase()'s own established
	# _recognize_live_pending() pattern. prepare_action_handoff() below rejects any second pending
	# outright, so this transaction can never reach it again; only a re-drive of accept_prepared_action()
	# itself can make forward progress.
	var precheck: Dictionary = _round_consequence_state_port.call(&"capture")
	if not precheck.get("ok", false):
		return precheck
	var precheck_pending: Variant = (precheck["value"] as Dictionary)["state"].get("pending")
	if precheck_pending != null:
		var pending: Dictionary = precheck_pending
		if str(pending.get("transaction_id", "")) != transaction_id or str(pending.get("source_kind", "")) != "minesweeper_round":
			return _fail(&"minesweeper_round_requires_no_other_pending_transaction",
				"another desktop causal transaction is already pending", {})
		return _recognize_live_round_pending(transaction_id, fingerprint)

	var captured: Dictionary = _board_state.capture()
	if captured["phase"] != "ACTIVE_VISIBLE":
		return _fail(&"complete_round_requires_active_visible_phase", "", {"phase": captured["phase"]})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})
	if request["expected_identity"] != captured["identity"]:
		return _fail(&"identity_mismatch", "", {})
	var identity: Dictionary = captured["identity"]
	var live_board_wrapper: Dictionary = captured["board"]
	var live_board: Dictionary = live_board_wrapper["board"]
	if not bool(live_board["terminal"]):
		return _fail(&"complete_round_requires_terminal_board", "", {})
	var outcome := str(live_board["outcome"])
	var paid_start_receipt: Dictionary = live_board_wrapper["paid_start_receipt"]

	var acquired_fresh := false
	if not _consequence_gate.is_internal_owner_active(_GATE_OWNER):
		var acquired: Dictionary = _consequence_gate.acquire(_GATE_OWNER)
		if not acquired.get("ok", false):
			return _fail(&"causal_transaction_lease_unavailable",
				"the shared causal_transaction lease is held by another transaction", {})
		_consequence_gate_token = str((acquired["value"] as Dictionary)["token"])
		acquired_fresh = true

	var consequence_captured: Dictionary = _round_consequence_state_port.call(&"capture")
	if not consequence_captured.get("ok", false):
		if acquired_fresh:
			_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
			_consequence_gate_token = ""
		return consequence_captured
	var live_consequence: Dictionary = (consequence_captured["value"] as Dictionary)["state"]

	var board_projection := _project_completion_board(identity, captured, outcome, transaction_id)
	var action_candidate := {
		"transaction_id": transaction_id, "outcome": outcome, "identity": identity.duplicate(true),
		"board_projection": board_projection,
	}
	if _reward_port != null:
		var reasons: Array = PERFORMANCE.perfect_reasons(live_board)
		var reward_outcome: String = "perfect" if not reasons.is_empty() else outcome
		var reward: Dictionary = _reward_port.prepare_complete({
			"context": "app", "difficulty": str(paid_start_receipt.get("difficulty_id", "")),
			"round_id": str(paid_start_receipt.get("receipt_id", "")),
		}, {"outcome": reward_outcome, "perfect_reasons": reasons}, transaction_id)
		if not reward.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return reward
		action_candidate["reward"] = reward.value.duplicate(true)
	# Freeze the complete owning run before admission; the first-reveal save can be older
	# than intervening Contacts, Shop, Schedule and terminal board actions.
	if _source_checkpoint_capture.is_valid():
		var source_inputs: Dictionary = _source_checkpoint_capture.call(live_consequence.duplicate(true))
		if not source_inputs.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return source_inputs
		var source_prepared: Dictionary = _round_checkpoint_port.prepare(source_inputs.value.checkpoint_inputs,
			&"safe_marker", {"kind": &"autosave", "reason": &"automatic"})
		if not source_prepared.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return source_prepared
		var source_committed: Dictionary = _round_checkpoint_port.commit(source_prepared.value.candidate)
		if not source_committed.get("ok", false):
			if acquired_fresh: release_recovery_lease()
			return source_committed
		var source_snapshot: Dictionary = source_prepared.value.candidate.autosave_document.current_snapshot.snapshot
		action_candidate["source_checkpoint"] = {"checkpoint_id": source_snapshot.checkpoint_id,
			"snapshot_sha256": _canonical_sha256(source_snapshot)}
	var action_candidate_sha256 := _canonical_sha256(action_candidate)

	var built_receipt := _build_round_action_receipt(transaction_id, request["transaction_issuer_receipt"],
		identity, paid_start_receipt, action_candidate_sha256, action_candidate.get("reward", {}))
	if not built_receipt.get("ok", false):
		if acquired_fresh:
			_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
			_consequence_gate_token = ""
		return built_receipt
	var action_receipt: Dictionary = (built_receipt["value"] as Dictionary)["receipt"]

	var recovery_payload := {
		"source_kind": "minesweeper_round", "action_receipt": action_receipt.duplicate(true),
		"run_revision_before": int(live_consequence["run_revision"]),
		"participant_snapshot_ids": {"transaction_id": transaction_id, "outcome": outcome},
	}
	var action_receipt_for_handoff := action_receipt.duplicate(true)
	action_receipt_for_handoff["source_kind"] = action_receipt["action_kind"]
	var handoff_prepared: Dictionary = _round_consequence_state_port.call(&"prepare_action_handoff",
		action_receipt_for_handoff, int(live_consequence["run_revision"]), recovery_payload)
	if not handoff_prepared.get("ok", false):
		if acquired_fresh:
			_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
			_consequence_gate_token = ""
		return handoff_prepared
	var handoff_candidate: Dictionary = (handoff_prepared["value"] as Dictionary)["candidate"]

	# Ruling A: ordinal 0, stage "action_prepared" -- matches MinesweeperShopPurchaseParticipant's
	# own established convention for the durable, unpromoted source-only checkpoint exactly.
	var checkpoint_header := {
		"kind": &"minesweeper_round_action_checkpoint", "operation_ordinal": 0, "run_id": str(identity["run_id"]),
		"source_ids": [transaction_id], "stage": "action_prepared", "transaction_id": transaction_id,
	}
	var checkpoint_prepared: Dictionary = _round_checkpoint_port.call(&"prepare_consequence_checkpoint",
		checkpoint_header, handoff_candidate["state_after"])
	if not checkpoint_prepared.get("ok", false):
		if acquired_fresh:
			_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
			_consequence_gate_token = ""
		return checkpoint_prepared
	var checkpoint_value: Dictionary = checkpoint_prepared["value"]
	var checkpoint_committed: Dictionary = _round_checkpoint_port.call(&"commit_consequence_checkpoint",
		checkpoint_value["candidate"], checkpoint_value["checkpoint_receipt"])
	if not checkpoint_committed.get("ok", false):
		if acquired_fresh:
			_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
			_consequence_gate_token = ""
		return checkpoint_committed

	# The disk checkpoint is now durable. From here forward this coordinator never rewinds on
	# failure (mirrors MinesweeperShopPurchaseParticipant's own identical discipline).
	var consequence_committed: Dictionary = _round_consequence_state_port.call(&"commit", handoff_candidate)
	if not consequence_committed.get("ok", false):
		return consequence_committed

	var accept_request := {
		"action_receipt": action_receipt, "action_candidate": action_candidate,
		"prepared_checkpoint_receipt": checkpoint_value["checkpoint_receipt"],
		# Run revision is consequence-state concurrency, inaccessible to presentation callers. The
		# coordinator captured it alongside this exact completion and carries that authoritative value.
		"expected_run_revision": int(live_consequence["run_revision"]),
		"expected_board_identity": identity, "expected_board_revision": int(captured["revision"]),
	}
	# dwm-p2r.35.7 remediation (finding 2): retained so a same-process retry of this now-durably-pending
	# transaction (recognized above by _recognize_live_round_pending()) can replay this exact
	# accept_prepared_action() call without recomputing action_candidate/action_receipt/checkpoint
	# receipt -- prepare_action_handoff() above can never run a second time for this transaction_id.
	_round_pending_admission_requests[transaction_id] = accept_request.duplicate(true)
	_round_request_fingerprints[transaction_id] = fingerprint
	return _call_accept_and_finalize(transaction_id, fingerprint, accept_request)


## dwm-p2r.35.7 remediation (findings 1 and 2): a durable pending record for THIS transaction already
## exists -- either this same process already committed ordinal 0 during an earlier attempt whose
## accept_prepared_action() call transiently failed, or the gate/lease was released by the
## dwm-p2r.35.7 abandonment path below and this is a genuine caller-driven retry. Re-drives
## accept_prepared_action() directly using the exact request this same process retained when it
## first wrote ordinal 0 -- prepare_action_handoff() cannot run a second time (it rejects any
## already-pending transaction). A genuinely fresh process (no retained in-memory request) has
## nothing to replay here; that gap is DesktopConsequenceCoordinator.resume_pending()'s own job.
func _recognize_live_round_pending(transaction_id: String, fingerprint: String) -> Dictionary:
	if not _round_pending_admission_requests.has(transaction_id):
		return _fail(&"minesweeper_round_pending_transaction_unrecognized",
			"a pending transaction exists but this process retains no request to replay it", {})
	if not _consequence_gate.is_internal_owner_active(_GATE_OWNER):
		var acquired: Dictionary = _consequence_gate.acquire(_GATE_OWNER)
		if not acquired.get("ok", false):
			return _fail(&"causal_transaction_lease_unavailable",
				"the shared causal_transaction lease is held by another transaction", {})
		_consequence_gate_token = str((acquired["value"] as Dictionary)["token"])
	var accept_request: Dictionary = _round_pending_admission_requests[transaction_id]
	return _call_accept_and_finalize(transaction_id, fingerprint, accept_request)


## dwm-p2r.35.7 remediation (finding 2): caches ONLY a success -- previously `_round_completions` cached
## every result unconditionally, so a transient accept_prepared_action() failure froze that exact
## failure forever even though the ordinal-0 checkpoint and pending record were already durable and a
## real forward path existed. dwm-p2r.35.7 remediation (finding 1): when accept_prepared_action()
## abandons a pre-admission pending because the condition-departure ports are unconfigured, this
## coordinator -- the actual causal_transaction token holder, since DesktopConsequenceCoordinator
## never acquires the lease itself -- releases it here, completing the frozen law's "releases
## causal_transaction" (plan02-frozen-contracts.md line 2271).
func _call_accept_and_finalize(transaction_id: String, fingerprint: String, accept_request: Dictionary) -> Dictionary:
	var accepted: Dictionary = _consequence_coordinator.call(&"accept_prepared_action", accept_request)
	if bool(accepted.get("ok", false)):
		_round_completions[transaction_id] = {"fingerprint": fingerprint, "result": accepted.duplicate(true)}
	elif str(accepted.get("code", "")) == "condition_departure_ports_unconfigured":
		if _consequence_gate_token != "":
			_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
			_consequence_gate_token = ""
	return accepted


## Task 8 (dwm-p2r.32) frozen action-source recovery surface consumed by
## DesktopConsequenceCoordinator, mirroring MinesweeperShopPurchaseParticipant's own three additions.
func validate_recovery_action(action_candidate: Dictionary, action_receipt: Dictionary) -> Dictionary:
	var validated := _ACTION_RECEIPT.validate(action_receipt)
	if not validated.get("ok", false):
		return validated
	var receipt: Dictionary = (validated["value"] as Dictionary)["receipt"]
	if str(receipt["action_kind"]) != "minesweeper_round":
		return _fail(&"action_receipt_source_kind_mismatch", "", {})
	if str(action_candidate.get("transaction_id", "")) != str(receipt["transaction_id"]):
		return _fail(&"invalid_action_candidate", "action_candidate.transaction_id must match action_receipt", {})
	var action_candidate_sha256 := _canonical_sha256(action_candidate)
	return {"ok": true, "code": &"ok", "value": {"publication": {
		"action_candidate_sha256": action_candidate_sha256, "action_receipt": receipt.duplicate(true),
	}}, "receipt": {}}


## The source's sole live commit for this recovery boundary: adopts `action_candidate.board_projection`
## into the live board (the completed round's own phase-NONE transition -- board_fate is never the
## owner of this transition; it owns only a LATER condition-driven departure of an unrelated board)
## and, for a qualifying ordinal (1 or 2), records the base-completion receipt Task 7 reserved this
## seam for.
func commit_recovery_action(action_candidate: Dictionary, action_receipt: Dictionary) -> Dictionary:
	var validated := _ACTION_RECEIPT.validate(action_receipt)
	if not validated.get("ok", false):
		return validated
	var receipt: Dictionary = (validated["value"] as Dictionary)["receipt"]
	if str(receipt["action_kind"]) != "minesweeper_round":
		return _fail(&"action_receipt_source_kind_mismatch", "", {})
	var transaction_id := str(receipt["transaction_id"])
	if str(action_candidate.get("transaction_id", "")) != transaction_id:
		return _fail(&"invalid_action_candidate", "action_candidate.transaction_id must match action_receipt", {})

	if _round_recovery_committed.has(transaction_id):
		var recorded: Dictionary = _round_recovery_committed[transaction_id]
		if recorded["action_candidate"] == action_candidate and recorded["action_receipt"] == receipt:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"action_receipt_conflict", "this transaction was already committed with different bytes", {})

	if not _consequence_gate.is_internal_owner_active(_GATE_OWNER):
		return _fail(&"causal_transaction_lease_required", "commit_recovery_action requires the active causal_transaction lease", {})

	if action_candidate.has("reward"):
		if _reward_port == null: return _fail(&"reward_port_not_configured", "", {})
		var applied: Dictionary = _reward_port.commit_desktop_completion(action_candidate.reward.prepared_candidate)
		if not applied.get("ok", false): return applied

	var board_projection: Dictionary = action_candidate["board_projection"]
	var prepared_restore: Dictionary = _board_state.prepare_restore(board_projection)
	if not prepared_restore.get("ok", false):
		return prepared_restore
	var board_committed: Dictionary = _board_state.commit((prepared_restore["value"] as Dictionary)["candidate"])
	if not board_committed.get("ok", false):
		return board_committed

	var identity: Dictionary = action_candidate["identity"]
	if int(identity["app_round_ordinal"]) in _BASE_COMPLETION_ORDINALS:
		var recorded_completion: Dictionary = _round_consequence_state_port.call(&"prepare_record_base_completion", {
			"kind": "complete", "app_round_ordinal": int(identity["app_round_ordinal"]),
			"causal_day_instance": str(identity["causal_day_instance"]),
		})
		if not recorded_completion.get("ok", false):
			return recorded_completion
		var ledger_committed: Dictionary = _round_consequence_state_port.call(&"commit",
			(recorded_completion["value"] as Dictionary)["candidate"])
		if not ledger_committed.get("ok", false):
			return ledger_committed

	var result := {"ok": true, "code": &"ok", "value": {"action_receipt": receipt.duplicate(true)}, "receipt": receipt.duplicate(true)}
	_round_recovery_committed[transaction_id] = {
		"action_candidate": action_candidate.duplicate(true), "action_receipt": receipt.duplicate(true), "result": result.duplicate(true),
	}
	return result


## The source's sole audience boundary: records the at-most-once external observation through the
## SAME shared `action_source` publication-ledger kind and key convention
## `MinesweeperShopPurchaseParticipant.publish()`/`publish_recovery_action()` already established
## (Ruling B).
##
## dwm-p2r.35.7 remediation (finding 3): this method used to release the retained `causal_transaction`
## lease here, immediately after recording -- but this is callback index 1 of up to 3 in
## DesktopConsequenceCoordinator's own departure publication plan (causal_sequence, action_source,
## optional board_fate), so releasing here left board-fate publish and terminal cleanup running
## UNLEASED, contradicting `DesktopBoardFatePort`'s own class-doc argument that its one known
## candidate-hash-collision limitation "is not reachable in production" BECAUSE the coordinator holds
## the lease across one departure's whole prepare-to-publish span. The release now happens only in
## `release_recovery_lease()`, which the coordinator calls after terminal cleanup succeeds.
func publish_recovery_action(publication: Dictionary) -> Dictionary:
	var keys: Array = publication.keys()
	keys.sort()
	if keys != ["action_candidate_sha256", "action_receipt"]:
		return _fail(&"invalid_publication", "publication must carry exactly action_candidate_sha256 and action_receipt", {})
	var receipt: Dictionary = publication["action_receipt"]
	var validated := _ACTION_RECEIPT.validate(receipt)
	if not validated.get("ok", false):
		return validated
	receipt = (validated["value"] as Dictionary)["receipt"]
	if _publication_ledger == null:
		return _fail(&"publication_ledger_not_configured", "configure_publication_ledger() is required before publish_recovery_action()", {})
	var ledger_publication := {
		"action_candidate_sha256": str(publication["action_candidate_sha256"]), "action_receipt": receipt.duplicate(true),
	}
	var recorded: Dictionary = _publication_ledger.call(&"record_before_emit", {
		"kind": "action_source", "semantic_receipt": receipt.duplicate(true),
		"publication": ledger_publication, "publication_sha256": _canonical_sha256(ledger_publication),
	})
	if not recorded.get("ok", false):
		return recorded
	if bool(recorded.get("value", {}).get("first_delivery", false)):
		var committed: Dictionary = _round_recovery_committed.get(str(receipt.transaction_id), {})
		var reward: Dictionary = committed.get("action_candidate", {}).get("reward", {})
		if not reward.is_empty():
			var published: Dictionary = _reward_port.publish_desktop_completion(
				reward.prepared_domain_receipt, reward.domain_events)
			if not published.get("ok", false): return published
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": receipt.duplicate(true)}


## dwm-p2r.35.7 remediation (finding 3): the fourth frozen recovery-method addition, called by
## DesktopConsequenceCoordinator._resume_forward() only AFTER terminal cleanup succeeds -- see that
## method's own doc comment for why the release moved out of publish_recovery_action(). Idempotent
## no-op when no token is held (a resume_pending()-driven forward recovery in a fresh process never
## acquired one in the first place, since this coordinator -- not DesktopConsequenceCoordinator -- is
## the actual lease holder).
func release_recovery_lease() -> Dictionary:
	if _consequence_gate_token != "":
		_consequence_gate.release(_GATE_OWNER, _consequence_gate_token)
		_consequence_gate_token = ""
	return {"ok": true, "code": &"ok", "value": {"released": true}, "receipt": {}}


func get_entry_context(difficulty_id: String) -> Dictionary:
	var ready := _ensure_ready()
	if not ready.is_empty():
		return ready
	if difficulty_id.strip_edges().is_empty():
		return _fail(&"invalid_difficulty_id", "difficulty_id must be nonblank", {})
	var state_captured: Dictionary = _board_state.capture()
	var revision: int = state_captured["revision"]
	if state_captured["phase"] != "NONE":
		return {"ok": true, "code": &"ok", "value": {
			"identity": null, "revision": revision, "difficulty_id": difficulty_id, "eligible": false,
		}, "receipt": {}}
	var port_captured: Dictionary = _state_port.call(&"capture")
	if not port_captured.get("ok", false):
		return port_captured
	var facts: Dictionary = port_captured["value"]
	var ordinal: int = int(facts["next_app_round_ordinal"])
	var eligible: bool = bool(facts["eligible"]) and ordinal >= 1 and ordinal <= 5
	var identity: Variant = null
	if ordinal >= 1 and ordinal <= 5:
		identity = {
			"run_id": str(facts["run_id"]), "branch_id": str(facts["branch_id"]),
			"desktop_timeline_generation": int(facts["desktop_timeline_generation"]),
			"causal_day_instance": str(facts["causal_day_instance"]), "app_round_ordinal": ordinal,
		}
	return {"ok": true, "code": &"ok", "value": {
		"identity": identity, "revision": revision, "difficulty_id": difficulty_id, "eligible": eligible,
	}, "receipt": {}}


func begin_debug_preparation(request: Dictionary) -> Dictionary:
	var guard := _guard(&"begin_debug_preparation")
	if not guard.is_empty():
		return guard
	var shape := _exact_keys(request, _DEBUG_BEGIN_REQUEST_KEYS, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var ledger_hit := _ledger_lookup(request, transaction_id)
	if ledger_hit.has("result"):
		return ledger_hit["result"]
	var fingerprint: String = ledger_hit["fingerprint"]

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify
	var captured: Dictionary = _board_state.capture()
	if captured["phase"] != "NONE":
		return _fail(&"debug_candidate_requires_none_phase", "", {"phase": captured["phase"]})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})
	var entry_context := get_entry_context(str(request["difficulty_id"]))
	if not entry_context.get("ok", false):
		return entry_context
	var context_value: Dictionary = entry_context["value"]
	if not bool(context_value["eligible"]) or context_value["identity"] == null:
		return _fail(&"not_eligible", "no eligible ordinal remains for a new Debug candidate", {})
	if request["expected_identity"] != context_value["identity"]:
		return _fail(&"identity_mismatch", "", {})
	var identity: Dictionary = context_value["identity"]

	var spec_prepared: Dictionary = _state_port.call(&"prepare_spec", str(request["difficulty_id"]), transaction_id,
		request["transaction_issuer_receipt"])
	if not spec_prepared.get("ok", false):
		return spec_prepared
	var spec: Dictionary = (spec_prepared["value"] as Dictionary)["spec"]

	var search_begun: Dictionary = _generation_port.call(&"begin_search", spec)
	if not search_begun.get("ok", false):
		return search_begun
	var frontier: Dictionary = (search_begun["value"] as Dictionary)["frontier"]

	var board_input := {
		"transaction_id": transaction_id, "identity": identity,
		"expected_revision": int(request["expected_revision"]), "spec": spec,
		"request_fingerprint": fingerprint,
	}
	var prepared := _board_state.prepare_debug_candidate(board_input, {"frontier": frontier})
	if not prepared.get("ok", false):
		return prepared
	return _board_state.commit((prepared["value"] as Dictionary)["candidate"])


func run_debug_preparation_slice(request: Dictionary) -> Dictionary:
	var guard := _guard(&"run_debug_preparation_slice")
	if not guard.is_empty():
		return guard
	var shape := _exact_keys(request, _GENERIC_REQUEST_KEYS, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var ledger_hit := _ledger_lookup(request, transaction_id)
	if ledger_hit.has("result"):
		return ledger_hit["result"]
	var fingerprint: String = ledger_hit["fingerprint"]

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify
	var captured: Dictionary = _board_state.capture()
	if captured["phase"] != "PREPARING":
		return _fail(&"debug_slice_requires_preparing_phase", "", {"phase": captured["phase"]})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})
	if request["expected_identity"] != captured["identity"]:
		return _fail(&"identity_mismatch", "", {})

	var frontier: Dictionary = (captured["candidate"] as Dictionary)["frontier"]
	var slice_result: Dictionary = _generation_port.call(&"run_search_slice", frontier)
	if not slice_result.get("ok", false):
		return slice_result

	var board_input := {
		"transaction_id": transaction_id, "identity": captured["identity"],
		"expected_revision": int(request["expected_revision"]), "request_fingerprint": fingerprint,
	}
	var prepared := _board_state.prepare_debug_slice(board_input, slice_result["value"])
	if not prepared.get("ok", false):
		return prepared
	return _board_state.commit((prepared["value"] as Dictionary)["candidate"])


func reveal(request: Dictionary) -> Dictionary:
	var guard := _guard(&"reveal")
	if not guard.is_empty():
		return guard
	if request.has("difficulty_id"):
		if _durable_checkpoint_port != null:
			return _first_reveal_durable(request)
		return _first_reveal(request)
	return _routine_command(request, &"reveal")


func set_flag(request: Dictionary) -> Dictionary:
	var guard := _guard(&"set_flag")
	if not guard.is_empty():
		return guard
	return _routine_command(request, &"set_flag")


func chord(request: Dictionary) -> Dictionary:
	var guard := _guard(&"chord")
	if not guard.is_empty():
		return guard
	return _routine_command(request, &"chord")


func suspend(request: Dictionary) -> Dictionary:
	var guard := _guard(&"suspend")
	if not guard.is_empty():
		return guard
	return _visibility_command(request, false)


func resume(request: Dictionary) -> Dictionary:
	var guard := _guard(&"resume")
	if not guard.is_empty():
		return guard
	return _visibility_command(request, true)


func get_state() -> Dictionary:
	var ready := _ensure_ready()
	if not ready.is_empty():
		return ready
	return {"ok": true, "code": &"ok", "value": _board_state.capture(), "receipt": {}}


# ---------------------------------------------------------------------------------------------
# first Reveal -- the one transaction that spans DesktopBoardState, the state port, and the
# checkpoint port.
# ---------------------------------------------------------------------------------------------

func _first_reveal(request: Dictionary) -> Dictionary:
	var shape := _exact_keys(request, _FIRST_REVEAL_REQUEST_KEYS, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var fingerprint := _fingerprint(request)
	var ledger: Dictionary = _board_state.capture()["command_receipts"]
	if ledger.has(transaction_id):
		var entry: Dictionary = ledger[transaction_id]
		if str(entry["request_fingerprint"]) != fingerprint:
			return _fail(&"transaction_conflict", "", {"transaction_id": transaction_id})
		var stored: Dictionary = entry["result"]
		var stored_value: Dictionary = stored.get("value", {})
		return _republish_first_reveal(stored_value)

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify

	var captured: Dictionary = _board_state.capture()
	var phase: String = captured["phase"]
	if phase != "NONE" and phase != "PREPARED_UNSTARTED":
		return _fail(&"first_reveal_requires_none_or_prepared_phase", "", {"phase": phase})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})

	var identity: Dictionary
	if phase == "NONE":
		var entry_context := get_entry_context(str(request["difficulty_id"]))
		if not entry_context.get("ok", false):
			return entry_context
		var context_value: Dictionary = entry_context["value"]
		if not bool(context_value["eligible"]) or context_value["identity"] == null:
			return _fail(&"not_eligible", "no eligible ordinal remains for a new round", {})
		identity = context_value["identity"]
	else:
		identity = captured["identity"]
	if request["expected_identity"] != identity:
		return _fail(&"identity_mismatch", "", {})

	var spec: Dictionary
	var layout: Dictionary
	var proof_sha256: Variant = null
	if phase == "NONE":
		# The spec (board_token + all three nonces) is minted fresh, scoped to THIS transaction --
		# it cannot be re-derived under a different transaction_id, so this call happens only here.
		var spec_prepared: Dictionary = _state_port.call(&"prepare_spec", str(request["difficulty_id"]),
			transaction_id, request["transaction_issuer_receipt"])
		if not spec_prepared.get("ok", false):
			return spec_prepared
		spec = (spec_prepared["value"] as Dictionary)["spec"]
		var materialized: Dictionary = _generation_port.call(&"materialize", spec, int(request["cell_index"]))
		if not materialized.get("ok", false):
			return materialized
		layout = (materialized["value"] as Dictionary)["layout"]
	else:
		# Adopting an already-certified Debug candidate: its spec was minted once, under debug
		# preparation's OWN transaction_id, and is never re-derived under this reveal's different
		# transaction_id -- it is simply the trusted spec this attempt already committed to.
		var live_candidate: Dictionary = captured["candidate"]
		if int(request["cell_index"]) != int(live_candidate["forced_cell"]):
			return _fail(&"forced_cell_mismatch", "", {})
		if str(request["difficulty_id"]) != str((live_candidate["spec"] as Dictionary)["difficulty_id"]):
			return _fail(&"difficulty_mismatch", "", {})
		spec = live_candidate["spec"]
		layout = live_candidate["layout"]
		proof_sha256 = live_candidate.get("proof_sha256")

	var reveal_result := _REDUCER.first_reveal(layout, int(request["cell_index"]))
	if not reveal_result.get("ok", false):
		return reveal_result
	var board: Dictionary = (reveal_result["value"] as Dictionary)["board"]

	var run_id := str(identity["run_id"])
	var preview: Dictionary = _checkpoint_port.call(&"preview_checkpoint_id", run_id)
	if not preview.get("ok", false):
		return preview
	var expected_checkpoint_id := str((preview["value"] as Dictionary)["checkpoint_id"])

	var board_candidate_for_port := {
		"identity": identity, "difficulty_id": str(request["difficulty_id"]),
		"cell_index": int(request["cell_index"]), "board": board, "proof_sha256": proof_sha256,
	}
	var state_prepared: Dictionary = _state_port.call(&"prepare_first_reveal", board_candidate_for_port,
		transaction_id, request["transaction_issuer_receipt"], expected_checkpoint_id)
	if not state_prepared.get("ok", false):
		return state_prepared
	var state_value: Dictionary = state_prepared["value"]
	var run_candidate: Dictionary = state_value["run_candidate"]
	var receipt: Dictionary = state_value["receipt"]
	var publication: Dictionary = state_value["publication"]

	var checkpoint_prepared: Dictionary = _checkpoint_port.call(&"prepare_checkpoint", state_value["snapshot_input"],
		&"board_start", {"kind": &"none", "reason": &"stage"})
	if not checkpoint_prepared.get("ok", false):
		return checkpoint_prepared
	var checkpoint_value: Dictionary = checkpoint_prepared["value"]
	var checkpoint_candidate: Dictionary = checkpoint_value["candidate"]
	if str(checkpoint_value["checkpoint_id"]) != expected_checkpoint_id:
		return _fail(&"checkpoint_id_mismatch", "", {})

	var state_backup_captured: Dictionary = _state_port.call(&"capture")
	if not state_backup_captured.get("ok", false):
		return state_backup_captured
	var state_backup: Dictionary = (state_backup_captured["value"] as Dictionary)["backup"]
	var checkpoint_backup_captured: Dictionary = _checkpoint_port.call(&"capture")
	if not checkpoint_backup_captured.get("ok", false):
		return checkpoint_backup_captured
	var checkpoint_backup: Dictionary = (checkpoint_backup_captured["value"] as Dictionary)["backup"]
	var board_state_backup: Dictionary = _board_state.capture()

	var board_input := {
		"transaction_id": transaction_id, "identity": identity,
		"expected_revision": int(request["expected_revision"]), "cell_index": int(request["cell_index"]),
		"spec": spec, "request_fingerprint": fingerprint,
	}
	var board_prepared := _board_state.prepare_first_reveal(board_input, {"layout": layout, "board": board},
		{"checkpoint_id": expected_checkpoint_id})
	if not board_prepared.get("ok", false):
		return board_prepared
	var board_candidate: Dictionary = (board_prepared["value"] as Dictionary)["candidate"]
	board_candidate["result_override"] = {
		"ok": true, "code": &"first_reveal_committed",
		"value": {"receipt": receipt.duplicate(true), "publication": publication.duplicate(true)},
		"receipt": {},
	}

	var checkpoint_commit: Dictionary = _checkpoint_port.call(&"commit_checkpoint", checkpoint_candidate)
	if not checkpoint_commit.get("ok", false):
		return checkpoint_commit  # nothing applied yet; no charge, no sequence consumed

	var state_commit: Dictionary = _state_port.call(&"commit", run_candidate)
	if not state_commit.get("ok", false):
		return _rollback_participants("state_commit", transaction_id, [
			["checkpoint_port", func(): return _checkpoint_port.call(&"rollback", checkpoint_backup)],
		], state_commit)

	var board_commit := _board_state.commit(board_candidate)
	if not board_commit.get("ok", false):
		return _rollback_participants("board_commit", transaction_id, [
			["state_port", func(): return _state_port.call(&"rollback", state_backup)],
			["checkpoint_port", func(): return _checkpoint_port.call(&"rollback", checkpoint_backup)],
		], board_commit)

	var seal: Dictionary = _checkpoint_port.call(&"seal_checkpoint", checkpoint_candidate)
	if not seal.get("ok", false):
		return _rollback_participants("seal", transaction_id, [
			["board_state", func(): return _restore_board_state(board_state_backup)],
			["state_port", func(): return _state_port.call(&"rollback", state_backup)],
			["checkpoint_port", func(): return _checkpoint_port.call(&"rollback", checkpoint_backup)],
		], seal)

	var published: Dictionary = _state_port.call(&"publish", publication)
	if not published.get("ok", false):
		return _fail(&"FIRST_REVEAL_COMMITTED_UNPUBLISHED", "",
			{"receipt": receipt.duplicate(true)})
	return {"ok": true, "code": &"first_reveal_committed", "value": {"receipt": receipt.duplicate(true)}, "receipt": {}}


## Plan 02 Task 6 (dwm-p2r.32), Phase D (brief Step 6.12's exact production order): guard (already
## run by reveal()) -> duplicate/conflict lookup -> verify issuer receipt -> validate current state/
## request -> purely materialize -> reduce the pure first-Reveal board -> prepare the GameState cost
## candidate and consequence checkpoint marker -> prepare the DesktopBoardState adoption candidate
## -> validate the candidate triple -> capture the base snapshot input -> compose and validate the
## post-commit v4 SaveDocument input -> prepare checkpoint -> commit checkpoint (DURABLE: `disk_write
## = {kind:autosave, reason:pre_board}`, the SAME registered disk-write member SaveManagerCheckpoint
## Port already reserves for exactly this "durable before a round is consumed" law) -> forward-commit
## GameState then board live candidates (consequence is untouched: the marker asserts revision
## agreement, not a content change -- see GameStateDesktopBoardPort's DESIGN CHOICE note) -> publish.
## Nothing is adopted live before checkpoint commit. Mirrors _first_reveal()'s exact rollback
## ordering, substituting the durable checkpoint port for the Task-5 fake one.
func _first_reveal_durable(request: Dictionary) -> Dictionary:
	var shape := _exact_keys(request, _FIRST_REVEAL_REQUEST_KEYS, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var fingerprint := _fingerprint(request)
	var ledger: Dictionary = _board_state.capture()["command_receipts"]
	if ledger.has(transaction_id):
		var entry: Dictionary = ledger[transaction_id]
		if str(entry["request_fingerprint"]) != fingerprint:
			return _fail(&"transaction_conflict", "", {"transaction_id": transaction_id})
		var stored: Dictionary = entry["result"]
		var stored_value: Dictionary = stored.get("value", {})
		return _republish_first_reveal(stored_value)

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify

	var captured: Dictionary = _board_state.capture()
	var phase: String = captured["phase"]
	if phase != "NONE" and phase != "PREPARED_UNSTARTED":
		return _fail(&"first_reveal_requires_none_or_prepared_phase", "", {"phase": phase})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})

	var identity: Dictionary
	if phase == "NONE":
		var entry_context := get_entry_context(str(request["difficulty_id"]))
		if not entry_context.get("ok", false):
			return entry_context
		var context_value: Dictionary = entry_context["value"]
		if not bool(context_value["eligible"]) or context_value["identity"] == null:
			return _fail(&"not_eligible", "no eligible ordinal remains for a new round", {})
		identity = context_value["identity"]
	else:
		identity = captured["identity"]
	if request["expected_identity"] != identity:
		return _fail(&"identity_mismatch", "", {})

	var spec: Dictionary
	var layout: Dictionary
	var proof_sha256: Variant = null
	if phase == "NONE":
		var spec_prepared: Dictionary = _state_port.call(&"prepare_spec", str(request["difficulty_id"]),
			transaction_id, request["transaction_issuer_receipt"])
		if not spec_prepared.get("ok", false):
			return spec_prepared
		spec = (spec_prepared["value"] as Dictionary)["spec"]
		var materialized: Dictionary = _generation_port.call(&"materialize", spec, int(request["cell_index"]))
		if not materialized.get("ok", false):
			return materialized
		layout = (materialized["value"] as Dictionary)["layout"]
	else:
		var live_candidate: Dictionary = captured["candidate"]
		if int(request["cell_index"]) != int(live_candidate["forced_cell"]):
			return _fail(&"forced_cell_mismatch", "", {})
		if str(request["difficulty_id"]) != str((live_candidate["spec"] as Dictionary)["difficulty_id"]):
			return _fail(&"difficulty_mismatch", "", {})
		spec = live_candidate["spec"]
		layout = live_candidate["layout"]
		proof_sha256 = live_candidate.get("proof_sha256")

	var reveal_result := _REDUCER.first_reveal(layout, int(request["cell_index"]))
	if not reveal_result.get("ok", false):
		return reveal_result
	var board: Dictionary = (reveal_result["value"] as Dictionary)["board"]

	var run_id := str(identity["run_id"])
	var preview: Dictionary = _durable_checkpoint_port.call(&"preview_checkpoint_id", run_id)
	if not preview.get("ok", false):
		return preview
	var expected_checkpoint_id := str((preview["value"] as Dictionary)["checkpoint_id"])

	var board_candidate_for_port := {
		"identity": identity, "difficulty_id": str(request["difficulty_id"]),
		"cell_index": int(request["cell_index"]), "board": board, "proof_sha256": proof_sha256,
	}
	var consequence_prepared: Dictionary = _state_port.call(&"prepare_first_reveal_consequence",
		board_candidate_for_port, transaction_id, request["transaction_issuer_receipt"], expected_checkpoint_id)
	if not consequence_prepared.get("ok", false):
		return consequence_prepared
	var prep_value: Dictionary = consequence_prepared["value"]
	var game_state_candidate: Dictionary = prep_value["game_state_candidate"]
	var consequence_candidate: Dictionary = prep_value["consequence_candidate"]
	var receipt: Dictionary = prep_value["receipt"]
	var publication: Dictionary = prep_value["publication"]

	var board_input := {
		"transaction_id": transaction_id, "identity": identity,
		"expected_revision": int(request["expected_revision"]), "cell_index": int(request["cell_index"]),
		"spec": spec, "request_fingerprint": fingerprint,
	}
	var board_prepared := _board_state.prepare_first_reveal(board_input, {"layout": layout, "board": board},
		receipt)
	if not board_prepared.get("ok", false):
		return board_prepared
	var board_candidate: Dictionary = (board_prepared["value"] as Dictionary)["candidate"]

	var validated: Dictionary = _state_port.call(&"validate_first_reveal_candidates",
		game_state_candidate, board_candidate, consequence_candidate)
	if not validated.get("ok", false):
		return validated

	var base_captured: Dictionary = _state_port.call(&"capture_base_snapshot_input")
	if not base_captured.get("ok", false):
		return base_captured
	var base_snapshot_input: Dictionary = (base_captured["value"] as Dictionary)["snapshot_input"]

	var composed: Dictionary = _snapshot_composer.call(&"compose", base_snapshot_input,
		game_state_candidate, board_candidate, consequence_candidate)
	if not composed.get("ok", false):
		return composed
	var post_commit_snapshot_input: Dictionary = (composed["value"] as Dictionary)["snapshot_input"]

	board_candidate["result_override"] = {
		"ok": true, "code": &"first_reveal_committed",
		"value": {"receipt": receipt.duplicate(true), "publication": publication.duplicate(true)},
		"receipt": {},
	}

	var state_backup_captured: Dictionary = _state_port.call(&"capture")
	if not state_backup_captured.get("ok", false):
		return state_backup_captured
	var state_backup: Dictionary = (state_backup_captured["value"] as Dictionary)["backup"]
	var checkpoint_backup_captured: Dictionary = _durable_checkpoint_port.call(&"capture")
	if not checkpoint_backup_captured.get("ok", false):
		return checkpoint_backup_captured
	var checkpoint_backup: Dictionary = (checkpoint_backup_captured["value"] as Dictionary)["backup"]

	var checkpoint_prepared: Dictionary = _durable_checkpoint_port.call(&"prepare_checkpoint",
		post_commit_snapshot_input, &"pre_board", {"kind": &"autosave", "reason": &"pre_board"})
	if not checkpoint_prepared.get("ok", false):
		return checkpoint_prepared
	var checkpoint_value: Dictionary = checkpoint_prepared["value"]
	var checkpoint_candidate: Dictionary = checkpoint_value["candidate"]
	if str(checkpoint_value["checkpoint_id"]) != expected_checkpoint_id:
		return _fail(&"checkpoint_id_mismatch", "", {})

	var checkpoint_commit: Dictionary = _durable_checkpoint_port.call(&"commit_checkpoint", checkpoint_candidate)
	if not checkpoint_commit.get("ok", false):
		return checkpoint_commit  # nothing applied yet; no charge, no sequence consumed

	var state_commit: Dictionary = _state_port.call(&"commit", game_state_candidate)
	if not state_commit.get("ok", false):
		return _rollback_participants("state_commit", transaction_id, [
			["checkpoint_port", func(): return _durable_checkpoint_port.call(&"rollback", checkpoint_backup)],
		], state_commit)

	var board_commit := _board_state.commit(board_candidate)
	if not board_commit.get("ok", false):
		return _rollback_participants("board_commit", transaction_id, [
			["state_port", func(): return _state_port.call(&"rollback", state_backup)],
			["checkpoint_port", func(): return _durable_checkpoint_port.call(&"rollback", checkpoint_backup)],
		], board_commit)

	var published: Dictionary = _state_port.call(&"publish", publication)
	if not published.get("ok", false):
		return _fail(&"FIRST_REVEAL_COMMITTED_UNPUBLISHED", "", {"receipt": receipt.duplicate(true)})
	return {"ok": true, "code": &"first_reveal_committed", "value": {"receipt": receipt.duplicate(true)}, "receipt": {}}


func _republish_first_reveal(stored_value: Dictionary) -> Dictionary:
	var receipt: Dictionary = stored_value.get("receipt", {})
	var publication: Variant = stored_value.get("publication")
	if typeof(publication) == TYPE_DICTIONARY:
		var republish: Dictionary = _state_port.call(&"publish", publication)
		if not republish.get("ok", false):
			return _fail(&"FIRST_REVEAL_COMMITTED_UNPUBLISHED", "", {"receipt": receipt.duplicate(true)})
	return {"ok": true, "code": &"first_reveal_committed", "value": {"receipt": receipt.duplicate(true)}, "receipt": {}}


func _restore_board_state(backup: Dictionary) -> Dictionary:
	var prepared := _board_state.prepare_restore(backup)
	if not prepared.get("ok", false):
		return prepared
	return _board_state.commit((prepared["value"] as Dictionary)["candidate"])


func _rollback_participants(phase: String, transaction_id: String,
		ordered_rollbacks: Array, original_failure: Dictionary) -> Dictionary:
	var diagnostics: Array = []
	var all_ok := true
	for entry: Array in ordered_rollbacks:
		var owner_id: String = entry[0]
		var op: Callable = entry[1]
		var result: Dictionary = op.call()
		diagnostics.append({"owner_id": owner_id, "operation": "rollback", "result": result})
		if not result.get("ok", false):
			all_ok = false
	if all_ok:
		return original_failure
	return _fatal_rollback(phase, transaction_id, diagnostics)


func _fatal_rollback(phase: String, transaction_id: String, raw_diagnostics: Array) -> Dictionary:
	if _fatal_failure.is_empty():
		var projected := _PROJECTOR.project_failure(
			"minesweeper_round_coordinator", phase, "fatal_rollback_failed",
			{"transaction_id": transaction_id}, raw_diagnostics)
		var candidate: Dictionary = _PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false):
			var failure: Dictionary = (projected["value"] as Dictionary)["failure"]
			if _PROJECTOR.validate_failure(failure).get("ok", false):
				candidate = failure
		_fatal_failure = candidate
	return {"ok": false, "code": &"APPLICATION_FATAL", "message": "",
		"details": {"failure": _fatal_failure.duplicate(true)}}


# ---------------------------------------------------------------------------------------------
# routine commands -- DesktopBoardState only, no state/checkpoint port involvement (no cost
# changes after first Reveal).
# ---------------------------------------------------------------------------------------------

func _routine_command(request: Dictionary, kind: StringName) -> Dictionary:
	var keys: Array[String] = _FLAG_REQUEST_KEYS if kind == &"set_flag" else _CELL_REQUEST_KEYS
	var shape := _exact_keys(request, keys, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var ledger_hit := _ledger_lookup(request, transaction_id)
	if ledger_hit.has("result"):
		return ledger_hit["result"]
	var fingerprint: String = ledger_hit["fingerprint"]

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify
	var captured: Dictionary = _board_state.capture()
	if captured["phase"] != "ACTIVE_VISIBLE":
		return _fail(&"board_command_requires_active_visible_phase", "", {"phase": captured["phase"]})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})
	if request["expected_identity"] != captured["identity"]:
		return _fail(&"identity_mismatch", "", {})

	var live_board: Dictionary = ((captured["board"] as Dictionary)["board"] as Dictionary)
	var cell_index := int(request["cell_index"])
	var reduced: Dictionary
	match kind:
		&"reveal":
			reduced = _REDUCER.reveal(live_board, cell_index, transaction_id)
		&"set_flag":
			reduced = _REDUCER.set_flag(live_board, cell_index, bool(request["flagged"]), transaction_id)
		&"chord":
			reduced = _REDUCER.chord(live_board, cell_index, transaction_id)
		_:
			return _fail(&"invalid_board_command_kind", "", {})
	if not reduced.get("ok", false):
		return reduced
	var reduced_board: Dictionary = (reduced["value"] as Dictionary)["board"]

	var board_input := {
		"transaction_id": transaction_id, "identity": captured["identity"],
		"expected_revision": int(request["expected_revision"]), "kind": kind, "cell_index": cell_index,
		"request_fingerprint": fingerprint,
	}
	if kind == &"set_flag":
		board_input["flagged"] = bool(request["flagged"])
	var prepared := _board_state.prepare_board_command(board_input, reduced_board)
	if not prepared.get("ok", false):
		return prepared
	return _board_state.commit((prepared["value"] as Dictionary)["candidate"])


func _visibility_command(request: Dictionary, visible: bool) -> Dictionary:
	var shape := _exact_keys(request, _GENERIC_REQUEST_KEYS, &"invalid_request")
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var ledger_hit := _ledger_lookup(request, transaction_id)
	if ledger_hit.has("result"):
		return ledger_hit["result"]
	var fingerprint: String = ledger_hit["fingerprint"]

	var verify := _verify_transaction(transaction_id, request["transaction_issuer_receipt"])
	if not verify.get("ok", false):
		return verify
	var captured: Dictionary = _board_state.capture()
	var required_phase := "ACTIVE_VISIBLE" if not visible else "ACTIVE_SUSPENDED"
	if captured["phase"] != required_phase:
		return _fail(&"visibility_requires_active_phase", "", {"phase": captured["phase"]})
	if int(request["expected_revision"]) != int(captured["revision"]):
		return _fail(&"stale_revision", "", {})
	if request["expected_identity"] != captured["identity"]:
		return _fail(&"identity_mismatch", "", {})

	var board_input := {
		"transaction_id": transaction_id, "identity": captured["identity"],
		"expected_revision": int(request["expected_revision"]), "request_fingerprint": fingerprint,
	}
	var prepared := _board_state.prepare_visibility(board_input, visible)
	if not prepared.get("ok", false):
		return prepared
	return _board_state.commit((prepared["value"] as Dictionary)["candidate"])


# ---------------------------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------------------------

func _ensure_ready() -> Dictionary:
	if _state_port == null or _checkpoint_port == null or _generation_port == null or _identity_issuer == null:
		return _fail(&"NOT_CONFIGURED", "MinesweeperRoundCoordinator.configure() was never called", {})
	if not _fatal_failure.is_empty():
		return {"ok": false, "code": &"APPLICATION_FATAL", "message": "",
			"details": {"failure": _fatal_failure.duplicate(true)}}
	return {}


func _guard(operation_id: StringName) -> Dictionary:
	var ready := _ensure_ready()
	if not ready.is_empty():
		return ready
	var guarded: Dictionary = _state_port.call(&"guard_external", operation_id)
	if not guarded.get("ok", false):
		return guarded
	return {}


## Read-only duplicate/conflict lookup against DesktopBoardState's own transaction ledger. Only
## first Reveal handles its own duplicate case specially (idempotent re-publish); every other
## command's stored result is safe to replay verbatim. Always returns "fingerprint" (the coordinator
## -level request fingerprint every DesktopBoardState `input` must carry downstream) and, on a
## duplicate or conflict, "result" as well.
func _ledger_lookup(request: Dictionary, transaction_id: String) -> Dictionary:
	var fingerprint := _fingerprint(request)
	var ledger: Dictionary = _board_state.capture()["command_receipts"]
	if not ledger.has(transaction_id):
		return {"fingerprint": fingerprint}
	var entry: Dictionary = ledger[transaction_id]
	if str(entry["request_fingerprint"]) != fingerprint:
		return {"fingerprint": fingerprint,
			"result": _fail(&"transaction_conflict", "", {"transaction_id": transaction_id})}
	return {"fingerprint": fingerprint, "result": (entry["result"] as Dictionary).duplicate(true)}


func _verify_transaction(transaction_id: String, transaction_issuer_receipt: Dictionary) -> Dictionary:
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY:
		return _fail(&"invalid_transaction_issuer_receipt", "", {})
	var verified: Dictionary = _identity_issuer.call(&"verify_issued", transaction_issuer_receipt, &"transaction_id")
	if not verified.get("ok", false):
		return verified
	var receipt: Dictionary = (verified["value"] as Dictionary)["receipt"]
	if str(receipt.get("token", "")) != transaction_id:
		return _fail(&"transaction_id_receipt_mismatch", "", {})
	return {"ok": true}


func _fingerprint(request: Dictionary) -> String:
	var canonical := _CANONICAL_JSON.stringify(request)
	if not canonical.get("ok", false):
		return ""
	return String(canonical["value"]).sha256_text()


## The target phase-NONE snapshot for a completed round: every phase-gated slot null,
## command_receipts unchanged, and one new terminal_receipts entry retaining the outcome/ordinal this
## board completed with. `revision` advances by one, matching DesktopBoardFatePort's own identical
## departed-snapshot bookkeeping convention. Deliberately skips the intermediate SETTLING phase
## (DesktopBoardState has no dedicated completion transition of its own and this task does not add
## one) -- the same hand-built-snapshot pattern DesktopBoardFatePort._build_departed_snapshot()
## already established.
func _project_completion_board(identity: Dictionary, captured: Dictionary, outcome: String,
		transaction_id: String) -> Dictionary:
	var terminal_receipt_id := "round_complete." + transaction_id
	var terminal_receipts: Dictionary = (captured["terminal_receipts"] as Dictionary).duplicate(true)
	terminal_receipts[terminal_receipt_id] = {
		"kind": "complete", "outcome": outcome, "app_round_ordinal": int(identity["app_round_ordinal"]),
	}
	return {
		"schema_version": 1, "phase": "NONE", "revision": int(captured["revision"]) + 1,
		"identity": null, "candidate": null, "board": null, "settlement": null,
		"command_receipts": (captured["command_receipts"] as Dictionary).duplicate(true),
		"terminal_receipts": terminal_receipts,
	}


## Ruling B: `commit_receipt_id`/`commit_receipt_provenance` reuse `action_id`/`action_id_provenance`
## byte-for-byte, matching MinesweeperShopPurchaseParticipant's own established convention exactly.
## `source_commit_receipt_id` is the round's own retained `board_start` paid-receipt (the domain-level
## artifact that authorized exactly this round), mirroring the derivation table's `desktop_action` row
## and Shop's own `shop_quote`-anchored precedent. `condition_before`/`condition_after` mirror the
## Shop participant's own health/pressure/carried_sequela pattern via `_state_port.capture()`'s Task-8
## extension, falling back to zero/false only when a narrower test double omits them (see the class
## doc's SCOPE NOTE).
func _build_round_action_receipt(transaction_id: String, transaction_issuer_receipt: Dictionary,
		identity: Dictionary, paid_start_receipt: Dictionary, action_candidate_sha256: String, reward: Dictionary = {}) -> Dictionary:
	var facts: Dictionary = {}
	var state_captured: Dictionary = _state_port.call(&"capture")
	if state_captured.get("ok", false):
		facts = state_captured["value"]
	var condition := {
		"health": int(facts.get("health", 0)), "pressure": int(facts.get("pressure", 0)),
		"carried_sequela": bool(facts.get("carried_sequela", false)),
	}
	var condition_after := condition.duplicate(true)
	var unlock_receipt_ids: Array = []
	if not reward.is_empty():
		var stats: Dictionary = reward.prepared_candidate.gameplay.stats
		condition_after.health = int(stats.health)
		condition_after.pressure = int(stats.pressure)
		unlock_receipt_ids = reward.prepared_domain_receipt.message_transaction_ids.duplicate()
		var group_id: Variant = reward.prepared_domain_receipt.group_activation_transaction_id
		if group_id != null: unlock_receipt_ids.append(str(group_id))
		unlock_receipt_ids.sort()
	# The Task-5 fake-checkpoint reveal() path (this coordinator's own _first_reveal(), used whenever
	# configure_durable_checkpoint() is unconfigured) stores only {"checkpoint_id":...} as the board's
	# retained paid_start_receipt, not the full board_start receipt _first_reveal_durable() carries;
	# fall back to checkpoint_id so complete_round() derives a nonblank source identity either way.
	var source_commit_receipt_id := str(paid_start_receipt.get("receipt_id", paid_start_receipt.get("checkpoint_id", "")))
	var action_candidate := {
		"schema_version": 1, "action_kind": "minesweeper_round", "run_id": str(identity["run_id"]),
		"branch_id": str(identity["branch_id"]), "desktop_timeline_generation": int(identity["desktop_timeline_generation"]),
		"causal_day_instance": str(identity["causal_day_instance"]), "day": int(facts.get("day", 0)),
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"source_commit_receipt_id": source_commit_receipt_id,
		"source_commit_receipt_provenance": (paid_start_receipt.get("receipt_provenance", {}) as Dictionary).duplicate(true),
		"condition_before": condition.duplicate(true), "condition_after": condition_after,
		"unlock_receipt_ids": unlock_receipt_ids,
	}
	var derived: Dictionary = _identity_issuer.call(&"derive_child", {
		"child_kind": "desktop_action", "ordinal": 0,
		"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
		"source_ids": _sorted_unique(["minesweeper_round", source_commit_receipt_id, action_candidate_sha256]),
	})
	if not derived.get("ok", false):
		return derived
	var derived_value: Dictionary = derived["value"]
	var action_id := str(derived_value["child_id"])
	var action_id_provenance: Dictionary = (derived_value["provenance"] as Dictionary).duplicate(true)
	var receipt := action_candidate.duplicate(true)
	receipt["action_id"] = action_id
	receipt["action_id_provenance"] = action_id_provenance
	receipt["commit_receipt_id"] = action_id
	receipt["commit_receipt_provenance"] = action_id_provenance.duplicate(true)
	var validated := _ACTION_RECEIPT.validate(receipt)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "value": {"receipt": (validated["value"] as Dictionary)["receipt"]}}


func _sorted_unique(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[str(value)] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _has_all_methods(target: Object, methods: Array[String]) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
