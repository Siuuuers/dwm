class_name DesktopBoardFatePort
extends RefCounted

## Reversible board-fate participant (Plan 02 Task 8, dwm-p2r.32, req.minesweeper.causal_departure,
## req.desktop.cross_app_actions). Turns a departing board (Schedule Done's live board, or a
## condition-driven action's already-validated projected board) into exactly one of three fates --
## `none` (no playable board), `discarded_unstarted` (an unstarted PREPARING/PREPARED_UNSTARTED
## candidate is dropped), `forfeited_started` (an ACTIVE_VISIBLE/ACTIVE_SUSPENDED board is
## abandoned, retaining paid round/motivation, granting nothing) -- against ONE shared, externally
## owned `DesktopBoardState` instance (the "sole board owner"), following the exact reversible
## capture/prepare/commit/rollback/publish contract every other Plan-02 participant already uses.
##
## `DesktopBoardState` has no dedicated discard/forfeit transition of its own (and this task does
## not add one): a departure instead builds a complete, phase-invariant-valid target snapshot
## (`phase=NONE`, every phase-gated slot null, `terminal_receipts` gaining one new entry keyed by
## this departure's own `board_fate_receipt.receipt_id`) and adopts it through
## `DesktopBoardState.prepare_restore()`/`commit()` -- the SAME general "adopt an arbitrary valid
## snapshot" seam `DesktopBoardRestoreParticipant` already uses for save restore. `fate=none` never
## builds a new snapshot at all: the board is already NONE (a `minesweeper_round` projection is
## ALWAYS exactly the source participant's own post-completion `NONE` candidate; a live
## `schedule_done` board or a `shop_purchase` projection may simply already be NONE), so the
## candidate is that unchanged snapshot.
##
## OWNERSHIP WIRING (own design choice, matching this codebase's established precedent -- see
## Task 6's own C2/D handoff note on reconnecting `MinesweeperRoundCoordinator._board_state` after
## restore): `MinesweeperRoundCoordinator` owns its `DesktopBoardState` privately and exposes no
## public accessor; this port is never given a second, independent `DesktopBoardState` of its own.
## Whoever wires this port (a test, or eventually Task 9's Bootstrap) passes the coordinator's OWN
## retained `_board_state` object directly into `configure()`, exactly as the existing test
## precedent already reconnects that same private member directly. Two owners never race for the
## one board: `DesktopConsequenceCoordinator` holds the shared `causal_transaction` lease for the
## whole prepare/commit/publish span, and this port's own commit()/rollback() add a second,
## self-contained guard -- a monotonic `_commit_generation` counter (mirroring
## `DesktopCausalSequencePort`'s own CRITICAL-1 precedent) that forbids rollback once ANY departure
## has since committed.
##
## IDEMPOTENCY: prepared departures are ledgered by `command_id` (the one identity every request
## shape carries); committed/published departures are additionally indexed by the canonical hash of
## their own `board_candidate` so `commit()`/`publish()` can accept the frozen "bare candidate, no
## wrapper" shape and still recover which prepared record it belongs to. KNOWN LIMITATION,
## documented rather than silently accepted: two DIFFERENT `command_id`s that both resolve to
## `fate=none` from an already-`NONE` board produce byte-identical `board_candidate` values (no
## board-fate marker is embedded when nothing changes), so the candidate-hash index cannot always
## distinguish between them if both are prepared before either is committed. This is not reachable
## in production -- `DesktopConsequenceCoordinator` holds the exclusive `causal_transaction` lease
## across one departure's whole prepare-to-publish span, so only one departure is ever in flight --
## and is called out here rather than papered over.
##
## dwm-p2r.35.7 remediation (finding 3), CONFIRMED rather than corrected: this paragraph's own
## "prepare-to-publish span" assumption was, until this remediation, silently violated by both
## action sources' `publish_recovery_action()` (each released the lease immediately after its own
## callback -- index 1 of up to 3 -- leaving THIS port's board-fate publish and the coordinator's
## terminal cleanup running unleased). The release now happens only in the new
## `release_recovery_lease()`, called by `DesktopConsequenceCoordinator._resume_forward()` after
## terminal cleanup succeeds, so this paragraph's own invariant is now actually enforced end-to-end,
## not merely assumed.

const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const _BOARD_STATE_SCRIPT := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _SCHEDULE_REQUEST_KEYS: Array[String] = [
	"command_id", "command_issuer_receipt", "run_id", "branch_id", "causal_day_instance", "reason",
	"expected_board_identity", "expected_board_revision",
]
const _PROJECTED_REQUEST_KEYS: Array[String] = [
	"command_id", "command_issuer_receipt", "run_id", "branch_id", "causal_day_instance", "reason",
	"expected_board_identity", "expected_board_revision",
	"source_action_receipt", "projected_board_candidate", "projected_board_candidate_sha256",
]
const _ACTION_KINDS: Array[String] = ["minesweeper_round", "shop_purchase"]
const _PUBLICATION_KEYS: Array[String] = ["board_candidate", "board_fate_receipt"]

var _publication_ledger: Object = null
var _board_state: Object = null
var _identity_issuer: Object = null

## Keyed by command_id -> {"request":Dictionary,"result":Dictionary,"board_candidate_hash":String}.
var _prepared: Dictionary = {}
## Keyed by canonical board_candidate hash -> command_id (see KNOWN LIMITATION above).
var _prepared_by_candidate_hash: Dictionary = {}
## Keyed by command_id -> {"candidate":Dictionary,"result":Dictionary}.
var _committed: Dictionary = {}
## Keyed by canonical backup hash -> the `_commit_generation` value at capture time.
var _capture_generations: Dictionary = {}
var _commit_generation := 0


# -------------------------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------------------------

func configure_publication_ledger(publication_ledger: Object) -> Dictionary:
	if publication_ledger == null or not publication_ledger.has_method("record_before_emit"):
		return _fail(&"invalid_publication_ledger", "publication_ledger must expose record_before_emit", {})
	if _publication_ledger != null:
		if _publication_ledger == publication_ledger:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"publication_ledger_already_configured", "a different publication ledger is already bound", {})
	_publication_ledger = publication_ledger
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Additive DI seam beyond the frozen board-fate interface (own design choice -- see the class doc's
## OWNERSHIP WIRING note): `board_state` must be the SAME shared `DesktopBoardState` instance the
## round coordinator privately owns, duck-typed to its `capture`/`prepare_restore`/`commit` surface;
## `identity_issuer` is duck-typed to `derive_child`. Fail-closed on the publication ledger, mirroring
## every other Plan-02 port's own configure() ordering.
func configure(board_state: Object, identity_issuer: Object) -> Dictionary:
	if board_state == null or not _has_all_methods(board_state, ["capture", "prepare_restore", "commit"]):
		return _fail(&"invalid_board_state", "an exact board-state capability is required", {})
	if identity_issuer == null or not identity_issuer.has_method("derive_child"):
		return _fail(&"invalid_identity_issuer", "an exact identity-issuer capability is required", {})
	if _publication_ledger == null:
		return _fail(&"publication_ledger_not_configured", "configure_publication_ledger() is required before configure()", {})
	if _board_state != null or _identity_issuer != null:
		if _board_state != board_state or _identity_issuer != identity_issuer:
			return _fail(&"board_fate_port_already_configured", "a configured port never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_board_state = board_state
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


# -------------------------------------------------------------------------------------------------
# prepare_causal_departure() -- reason=schedule_done exactly. Derives fate from the LIVE board.
# -------------------------------------------------------------------------------------------------

func prepare_causal_departure(request: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var shape := _exact_keys(request, _SCHEDULE_REQUEST_KEYS, &"board_fate_request_invalid")
	if not shape.get("ok", false):
		return shape
	if str(request["reason"]) != "schedule_done":
		return _fail(&"board_fate_reason_invalid",
			"prepare_causal_departure requires reason=schedule_done", {})
	var type_check := _validate_common_request_types(request)
	if not type_check.get("ok", false):
		return type_check
	var command_id := str(request["command_id"])

	var ledger_hit := _prepared_lookup(command_id, request)
	if ledger_hit.has("result"):
		return ledger_hit["result"]

	var live: Dictionary = (_board_state.call(&"capture") as Dictionary).duplicate(true)
	var pre_state_check := _check_pre_state(request, live)
	if not pre_state_check.get("ok", false):
		return pre_state_check

	var fate := _fate_for_phase(str(live["phase"]))
	if fate == &"":
		return _fail(&"board_fate_settling_not_resumable",
			"SETTLING may not derive causal departure fate outside a resumed transaction", {})

	return _finish_prepare(request, command_id, live, fate, null)


# -------------------------------------------------------------------------------------------------
# prepare_projected_causal_departure() -- reason=condition_departure exactly. Coordinator-only seam:
# derives fate from the ALREADY-VALIDATED projected candidate, never the live board directly.
# -------------------------------------------------------------------------------------------------

func prepare_projected_causal_departure(request: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var shape := _exact_keys(request, _PROJECTED_REQUEST_KEYS, &"board_fate_request_invalid")
	if not shape.get("ok", false):
		return shape
	if str(request["reason"]) != "condition_departure":
		return _fail(&"board_fate_reason_invalid",
			"prepare_projected_causal_departure requires reason=condition_departure", {})
	var type_check := _validate_common_request_types(request)
	if not type_check.get("ok", false):
		return type_check
	if typeof(request["source_action_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"board_fate_request_invalid", "source_action_receipt must be an object", {})
	if typeof(request["projected_board_candidate"]) != TYPE_DICTIONARY:
		return _fail(&"board_fate_request_invalid", "projected_board_candidate must be an object", {})
	if typeof(request["projected_board_candidate_sha256"]) != TYPE_STRING:
		return _fail(&"board_fate_request_invalid", "projected_board_candidate_sha256 must be a string", {})
	var command_id := str(request["command_id"])

	var ledger_hit := _prepared_lookup(command_id, request)
	if ledger_hit.has("result"):
		return ledger_hit["result"]

	var receipt_valid := _ACTION_RECEIPT.validate(request["source_action_receipt"])
	if not receipt_valid.get("ok", false):
		return receipt_valid
	var source_action_receipt: Dictionary = (receipt_valid["value"] as Dictionary)["receipt"]

	if str(source_action_receipt["transaction_id"]) != command_id:
		return _fail(&"board_fate_action_mismatch",
			"command_id must equal the source action's transaction_id", {})
	if source_action_receipt["transaction_issuer_receipt"] != request["command_issuer_receipt"]:
		return _fail(&"board_fate_action_mismatch",
			"command_issuer_receipt must equal the source action's transaction_issuer_receipt", {})
	if str(source_action_receipt["run_id"]) != str(request["run_id"]) \
			or str(source_action_receipt["branch_id"]) != str(request["branch_id"]) \
			or str(source_action_receipt["causal_day_instance"]) != str(request["causal_day_instance"]):
		return _fail(&"board_fate_action_mismatch",
			"the source action's run/branch/day identity must match the request", {})

	var projected_board_candidate: Dictionary = request["projected_board_candidate"]
	if _canonical_sha256(projected_board_candidate) != str(request["projected_board_candidate_sha256"]):
		return _fail(&"board_fate_projection_hash_mismatch",
			"projected_board_candidate_sha256 does not match the canonical projected candidate", {})

	var shape_valid := _BOARD_STATE_SCRIPT.new().prepare_restore(projected_board_candidate)
	if not shape_valid.get("ok", false):
		return _fail(&"board_fate_projection_invalid",
			"projected_board_candidate is not a valid board snapshot", shape_valid.get("details", {}))

	var action_kind := str(source_action_receipt["action_kind"])
	var live: Dictionary = (_board_state.call(&"capture") as Dictionary).duplicate(true)
	if action_kind == "minesweeper_round":
		if str(projected_board_candidate["phase"]) != "NONE":
			return _fail(&"board_fate_projection_invalid",
				"a minesweeper_round projection must already be phase NONE", {})
	elif action_kind == "shop_purchase":
		if projected_board_candidate != live:
			return _fail(&"board_fate_projection_invalid",
				"a shop_purchase projection must be byte-equal to the current board", {})
	else:
		return _fail(&"board_fate_source_kind_invalid", action_kind, {})

	var pre_state_check := _check_pre_state(request, live)
	if not pre_state_check.get("ok", false):
		return pre_state_check

	var fate := _fate_for_phase(str(projected_board_candidate["phase"]))
	if fate == &"":
		return _fail(&"board_fate_settling_not_resumable",
			"SETTLING may not derive causal departure fate outside a resumed transaction", {})

	return _finish_prepare(request, command_id, projected_board_candidate, fate, source_action_receipt)


## Rebuilds only the process-local preparation cache from an admitted, frozen departure.
## Call before the action source commits, after installing its exact source checkpoint on cold
## startup. No condition policy is evaluated and no owner is mutated. A temporary preparation
## keeps mismatched frozen bytes from poisoning this port's retained command or candidate indexes.
func prepare_recovery_departure(action_receipt: Dictionary, projected_board: Dictionary,
		board_candidate: Dictionary, board_fate_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var valid_action := _ACTION_RECEIPT.validate(action_receipt)
	if not valid_action.get("ok", false):
		return valid_action
	var action: Dictionary = valid_action["value"]["receipt"]
	var command_id := str(action["transaction_id"])
	var candidate_hash := _canonical_sha256(board_candidate)
	var receipt_hash := _canonical_sha256(board_fate_receipt)
	if candidate_hash.is_empty() or receipt_hash.is_empty():
		return _fail(&"board_fate_recovery_mismatch", "frozen departure must canonicalize", {})
	if _prepared.has(command_id):
		var retained: Dictionary = _prepared[command_id]
		var value: Dictionary = retained["result"]["value"]
		if _canonical_sha256(retained["request"].get("source_action_receipt", {})) != _canonical_sha256(action) \
				or _canonical_sha256(value["board_candidate"]) != candidate_hash \
				or _canonical_sha256(value["board_fate_receipt"]) != receipt_hash:
			return _fail(&"board_fate_recovery_mismatch", "frozen departure differs from retained preparation", {})
		# Warm retries can arrive after the source or fate already changed the board. Keep the
		# original pre-state rather than re-preparing against that advanced owner.
		return (retained["result"] as Dictionary).duplicate(true)
	var live: Dictionary = _board_state.call(&"capture")
	var request := {
		"command_id": command_id, "command_issuer_receipt": action["transaction_issuer_receipt"],
		"run_id": action["run_id"], "branch_id": action["branch_id"],
		"causal_day_instance": action["causal_day_instance"], "reason": "condition_departure",
		"expected_board_identity": live["identity"], "expected_board_revision": int(live["revision"]),
		"source_action_receipt": action, "projected_board_candidate": projected_board,
		"projected_board_candidate_sha256": _canonical_sha256(projected_board),
	}
	var verifier: RefCounted = get_script().new()
	var ledger_ready: Dictionary = verifier.configure_publication_ledger(_publication_ledger)
	if not ledger_ready.get("ok", false):
		return ledger_ready
	var configured: Dictionary = verifier.configure(_board_state, _identity_issuer)
	if not configured.get("ok", false):
		return configured
	var regenerated: Dictionary = verifier.prepare_projected_causal_departure(request)
	if not regenerated.get("ok", false):
		return regenerated
	var regenerated_value: Dictionary = regenerated["value"]
	if _canonical_sha256(regenerated_value["board_candidate"]) != candidate_hash \
			or _canonical_sha256(regenerated_value["board_fate_receipt"]) != receipt_hash:
		return _fail(&"board_fate_recovery_mismatch", "frozen departure does not match the exact source board", {})
	_prepared[command_id] = (verifier._prepared[command_id] as Dictionary).duplicate(true)
	_prepared_by_candidate_hash[candidate_hash] = command_id
	return regenerated.duplicate(true)


# -------------------------------------------------------------------------------------------------
# capture() / commit() / rollback() / publish() -- the shared reversible-participant contract.
# -------------------------------------------------------------------------------------------------

func capture() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var backup: Dictionary = (_board_state.call(&"capture") as Dictionary).duplicate(true)
	_capture_generations[_canonical_sha256(backup)] = _commit_generation
	return {"ok": true, "code": &"ok", "value": {"backup": backup}, "receipt": {}}


func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var hash_key := _canonical_sha256(candidate)
	if not _prepared_by_candidate_hash.has(hash_key):
		return _fail(&"invalid_candidate", "candidate does not match a prepared board_candidate", {})
	var command_id: String = _prepared_by_candidate_hash[hash_key]
	var recorded: Dictionary = _prepared[command_id]
	var request: Dictionary = recorded["request"]
	var board_fate_receipt: Dictionary = \
		((recorded["result"] as Dictionary)["value"] as Dictionary)["board_fate_receipt"]

	if _committed.has(command_id):
		var stored: Dictionary = _committed[command_id]
		if stored["candidate"] == candidate:
			return (stored["result"] as Dictionary).duplicate(true)
		return _fail(&"board_fate_conflict", "candidate was already committed with different bytes", {})

	var live: Dictionary = (_board_state.call(&"capture") as Dictionary).duplicate(true)
	var pre_state_check := _check_commit_pre_state(request, candidate, live)
	if not pre_state_check.get("ok", false):
		return _fail(&"board_fate_conflict", "the current board no longer matches the prepared pre-state", {})

	var prepared_restore: Dictionary = _board_state.call(&"prepare_restore", candidate)
	if not prepared_restore.get("ok", false):
		return prepared_restore
	var committed: Dictionary = _board_state.call(&"commit", (prepared_restore["value"] as Dictionary)["candidate"])
	if not committed.get("ok", false):
		return committed

	var result := {"ok": true, "code": &"ok", "value": {"board_candidate": candidate.duplicate(true)},
		"receipt": board_fate_receipt.duplicate(true)}
	_committed[command_id] = {"candidate": candidate.duplicate(true), "result": result.duplicate(true)}
	_commit_generation += 1
	return result


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var key := _canonical_sha256(backup)
	if not _capture_generations.has(key):
		return _fail(&"board_fate_backup_unknown", "backup does not match a captured backup", {})
	if int(_capture_generations[key]) != _commit_generation:
		return _fail(&"board_fate_rollback_forbidden",
			"an admitted board-fate transaction has already committed since this backup was captured", {})
	var live: Dictionary = (_board_state.call(&"capture") as Dictionary).duplicate(true)
	if live == backup:
		return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}
	var prepared_restore: Dictionary = _board_state.call(&"prepare_restore", backup)
	if not prepared_restore.get("ok", false):
		return _fail(&"board_fate_conflict", "the current board is a third live state", {})
	var committed: Dictionary = _board_state.call(&"commit", (prepared_restore["value"] as Dictionary)["candidate"])
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func publish(publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var keys: Array = publication.keys()
	keys.sort()
	var expected_keys: Array = _PUBLICATION_KEYS.duplicate()
	expected_keys.sort()
	if keys != expected_keys:
		return _fail(&"invalid_publication",
			"publication must carry exactly board_candidate and board_fate_receipt", {})
	var board_candidate: Dictionary = publication["board_candidate"]
	var board_fate_receipt: Dictionary = publication["board_fate_receipt"]

	var hash_key := _canonical_sha256(board_candidate)
	var command_id: String = str(_prepared_by_candidate_hash.get(hash_key, ""))
	if command_id.is_empty() or not _committed.has(command_id):
		return _fail(&"board_fate_conflict", "board_candidate does not match a committed candidate", {})
	var committed: Dictionary = _committed[command_id]
	if committed["candidate"] != board_candidate:
		return _fail(&"board_fate_conflict", "board_candidate does not byte-equal the committed candidate", {})
	var expected_receipt: Dictionary = (committed["result"] as Dictionary)["receipt"]
	if board_fate_receipt != expected_receipt:
		return _fail(&"board_fate_conflict", "board_fate_receipt does not byte-equal the retained receipt", {})
	var live: Dictionary = (_board_state.call(&"capture") as Dictionary).duplicate(true)
	if live != board_candidate:
		return _fail(&"board_fate_conflict", "the current board no longer equals the committed candidate", {})

	var ledger_publication := {
		"board_candidate": board_candidate.duplicate(true), "board_fate_receipt": board_fate_receipt.duplicate(true),
	}
	var recorded: Dictionary = _publication_ledger.call(&"record_before_emit", {
		"kind": "board_fate", "semantic_receipt": board_fate_receipt.duplicate(true),
		"publication": ledger_publication, "publication_sha256": _canonical_sha256(ledger_publication),
	})
	if not recorded.get("ok", false):
		return recorded
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": board_fate_receipt.duplicate(true)}


# -------------------------------------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------------------------------------

static func _fate_for_phase(phase: String) -> StringName:
	match phase:
		"NONE":
			return &"none"
		"PREPARING", "PREPARED_UNSTARTED":
			return &"discarded_unstarted"
		"ACTIVE_VISIBLE", "ACTIVE_SUSPENDED":
			return &"forfeited_started"
		_:
			return &""


func _prepared_lookup(command_id: String, request: Dictionary) -> Dictionary:
	if not _prepared.has(command_id):
		return {}
	var recorded: Dictionary = _prepared[command_id]
	if recorded["request"] == request:
		return {"result": (recorded["result"] as Dictionary).duplicate(true)}
	return {"result": _fail(&"board_fate_conflict", "command_id was already prepared with different bytes", {})}


func _check_pre_state(request: Dictionary, live: Dictionary) -> Dictionary:
	if live["identity"] != request["expected_board_identity"]:
		return _fail(&"board_fate_identity_mismatch",
			"expected_board_identity no longer matches the live board", {})
	if int(live["revision"]) != int(request["expected_board_revision"]):
		return _fail(&"board_fate_stale_revision",
			"expected_board_revision no longer matches the live board", {})
	return {"ok": true}


## FIX (dwm-p2r.35.2 remediation, finding W2): commit()'s own pre-state guard, distinct from prepare's
## `_check_pre_state()`. For a `minesweeper_round`-sourced projected departure, `expected_board_
## identity`/`expected_board_revision` name the board's PRE-completion state -- captured by
## `DesktopConsequenceCoordinator` before the round's own forward-recovery commit runs. Forward
## recovery then always commits the action source FIRST (`MinesweeperRoundCoordinator
## .commit_recovery_action()` adopts `action_candidate.board_projection` -- this exact `candidate`,
## since a minesweeper_round projection is always phase NONE and therefore always `fate=none`, i.e.
## `board_candidate == base_snapshot` -- into the shared `DesktopBoardState`) and board fate SECOND,
## post-admission with no rollback available. Re-checking the ORIGINAL pre-completion identity/
## revision here would therefore always reject a transaction the round coordinator has already
## legitimately advanced. The correct guard is instead "does the live board already equal the exact
## candidate this transaction is about to (no-op, since fate=none) commit" -- validating against the
## prepared candidate's own base rather than the stale original expectation, while every OTHER source
## (`shop_purchase` projected departures, whose action never touches the board; plain `schedule_done`
## live-board departures) keeps the original `_check_pre_state()` guard unchanged, since nothing
## mutates the board between their own prepare and commit.
func _check_commit_pre_state(request: Dictionary, candidate: Dictionary, live: Dictionary) -> Dictionary:
	if request.has("source_action_receipt") \
			and str((request["source_action_receipt"] as Dictionary).get("action_kind", "")) == "minesweeper_round":
		if live != candidate:
			return _fail(&"board_fate_conflict",
				"the live board no longer matches the source's own post-commit projection", {})
		return {"ok": true}
	return _check_pre_state(request, live)


## Builds the board_fate_receipt (child_kind=board_fate, ordinal 0, plan02-frozen-contracts.md line
## 498) and the target `board_candidate` -- unchanged `base_snapshot` for `fate=none`, otherwise a
## fresh phase-NONE snapshot built by `_build_departed_snapshot()` -- then ledgers both by
## `command_id` (and, for later commit()/publish() lookups, by the candidate's own canonical hash).
func _finish_prepare(request: Dictionary, command_id: String, base_snapshot: Dictionary,
		fate: StringName, source_action_receipt: Variant) -> Dictionary:
	var board_identity: Variant = _dup_or_null(base_snapshot["identity"]) if fate != &"none" else null
	var board_revision: int = int(base_snapshot["revision"]) if board_identity != null else -1
	var source_commit_receipt_id: Variant = null
	var source_commit_receipt_provenance: Variant = null
	if source_action_receipt != null:
		var action_receipt: Dictionary = source_action_receipt
		source_commit_receipt_id = str(action_receipt["commit_receipt_id"])
		source_commit_receipt_provenance = (action_receipt["commit_receipt_provenance"] as Dictionary).duplicate(true)

	var source_value_set: Array[String] = [_canonical_sha256({
		"board_identity": board_identity, "board_revision": board_revision,
		"causal_day_instance": str(request["causal_day_instance"]), "fate": String(fate),
	})]
	if source_commit_receipt_id != null:
		source_value_set.append(str(source_commit_receipt_id))
	source_value_set = _sorted_unique(source_value_set)

	var derived: Dictionary = _identity_issuer.call(&"derive_child", {
		"child_kind": "board_fate", "ordinal": 0,
		"parent_receipt_id": str((request["command_issuer_receipt"] as Dictionary).get("receipt_id", "")),
		"source_ids": source_value_set,
	})
	if not derived.get("ok", false):
		return derived
	var derived_value: Dictionary = derived["value"]

	var board_fate_receipt := {
		"receipt_id": str(derived_value["child_id"]),
		"receipt_provenance": (derived_value["provenance"] as Dictionary).duplicate(true),
		"command_id": command_id,
		"command_issuer_receipt": (request["command_issuer_receipt"] as Dictionary).duplicate(true),
		"board_identity": board_identity, "board_revision": board_revision,
		"causal_day_instance": str(request["causal_day_instance"]),
		"source_action_commit_receipt_id": source_commit_receipt_id,
		"source_action_commit_receipt_provenance": source_commit_receipt_provenance,
		"fate": String(fate),
	}

	var board_candidate: Dictionary
	if fate == &"none":
		board_candidate = base_snapshot.duplicate(true)
	else:
		board_candidate = _build_departed_snapshot(base_snapshot, str(board_fate_receipt["receipt_id"]))

	var result := {"ok": true, "code": &"ok", "value": {
		"board_candidate": board_candidate.duplicate(true), "board_fate_receipt": board_fate_receipt.duplicate(true),
	}, "receipt": board_fate_receipt.duplicate(true)}
	var candidate_hash := _canonical_sha256(board_candidate)
	_prepared[command_id] = {
		"request": request.duplicate(true), "result": result.duplicate(true), "board_candidate_hash": candidate_hash,
	}
	_prepared_by_candidate_hash[candidate_hash] = command_id
	return result


## The target phase-NONE snapshot for a discard/forfeit: every phase-gated slot null, command_receipts
## unchanged, and one new terminal_receipts entry (keyed by this departure's own receipt id) retaining
## the fate/identity/revision this board departed from. `revision` advances by one, matching every
## other DesktopBoardState transition's own bookkeeping (own design choice; not itself exposed by any
## frozen board_fate_receipt field).
func _build_departed_snapshot(base_snapshot: Dictionary, board_fate_receipt_id: String) -> Dictionary:
	var terminal_receipts: Dictionary = (base_snapshot["terminal_receipts"] as Dictionary).duplicate(true)
	terminal_receipts[board_fate_receipt_id] = {
		"kind": "board_fate", "board_identity": _dup_or_null(base_snapshot["identity"]),
		"board_revision": int(base_snapshot["revision"]),
	}
	return {
		"schema_version": 1, "phase": "NONE", "revision": int(base_snapshot["revision"]) + 1,
		"identity": null, "candidate": null, "board": null, "settlement": null,
		"command_receipts": (base_snapshot["command_receipts"] as Dictionary).duplicate(true),
		"terminal_receipts": terminal_receipts,
	}


func _validate_common_request_types(request: Dictionary) -> Dictionary:
	if typeof(request["command_id"]) != TYPE_STRING or str(request["command_id"]).strip_edges().is_empty():
		return _fail(&"board_fate_request_invalid", "command_id must be a nonblank string", {})
	if typeof(request["command_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"board_fate_request_invalid", "command_issuer_receipt must be an object", {})
	if typeof(request["run_id"]) != TYPE_STRING or str(request["run_id"]).strip_edges().is_empty():
		return _fail(&"board_fate_request_invalid", "run_id must be a nonblank string", {})
	if typeof(request["branch_id"]) != TYPE_STRING or str(request["branch_id"]).strip_edges().is_empty():
		return _fail(&"board_fate_request_invalid", "branch_id must be a nonblank string", {})
	if typeof(request["causal_day_instance"]) != TYPE_STRING \
			or str(request["causal_day_instance"]).strip_edges().is_empty():
		return _fail(&"board_fate_request_invalid", "causal_day_instance must be a nonblank string", {})
	var identity: Variant = request["expected_board_identity"]
	if identity != null and typeof(identity) != TYPE_DICTIONARY:
		return _fail(&"board_fate_request_invalid", "expected_board_identity must be an object or null", {})
	if typeof(request["expected_board_revision"]) != TYPE_INT:
		return _fail(&"board_fate_request_invalid", "expected_board_revision must be an integer", {})
	return {"ok": true}


static func _dup_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	return (value as Dictionary).duplicate(true)


func _sorted_unique(values: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	for value: String in values:
		seen[value] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


func _require_configured() -> Dictionary:
	if _board_state == null or _identity_issuer == null:
		return _fail(&"board_fate_port_not_configured", "DesktopBoardFatePort.configure() was never called", {})
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
