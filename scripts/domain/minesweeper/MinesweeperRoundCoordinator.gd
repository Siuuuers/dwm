class_name MinesweeperRoundCoordinator
extends RefCounted

# Frozen Phase 2R Minesweeper round coordinator. GameState's begin/complete
# round methods delegate here. Every public operation calls state_port.guard_external
# as its FIRST operation before any normalization, lookup, validation, capture, or
# port call; a failed guard is propagated unchanged. Recovery failures irreversibly
# latch and return only the gate's retained APPLICATION_FATAL.

const CONTRACT := preload("res://scripts/domain/minesweeper/MinesweeperRoundContract.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const STATE_METHODS: Array[String] = [
	"capture", "prepare_begin", "prepare_complete", "finalize_complete",
	"prepare_abort", "commit", "rollback", "publish", "latch_fatal",
	"is_fatal_latched", "guard_external",
]
const SAVE_METHODS: Array[String] = [
	"capture", "preview_checkpoint_id", "prepare_checkpoint", "commit_checkpoint",
	"rollback", "acquire_board_lock", "release_board_lock", "owns_board_lock",
]

const FAILURE_CODES: Array[StringName] = [
	&"NOT_CONFIGURED", &"INVALID_REQUEST", &"ROUND_ALREADY_ACTIVE", &"NO_APP_ROUND_AVAILABLE",
	&"INSUFFICIENT_MOTIVATION", &"DATING_ROUTE_NOT_ACTIVE", &"ROUND_ID_MISMATCH",
	&"INVALID_RESULT", &"INVALID_TRANSACTION_ID", &"TRANSACTION_ID_CONFLICT",
	&"PRE_BOARD_CHECKPOINT_FAILED", &"PRE_BOARD_AUTOSAVE_FAILED", &"SAVE_LOCK_FAILED",
	&"STATE_PREPARE_FAILED", &"CHECKPOINT_PREPARE_FAILED", &"STATE_COMMIT_FAILED",
	&"CHECKPOINT_COMMIT_FAILED", &"ROUND_START_PUBLICATION_FAILED",
	&"COMPLETION_COMMITTED_UNPUBLISHED", &"LOCK_RELEASE_PENDING", &"ABORT_FAILED",
]

## Domain-availability verdicts the state port alone can reach. They are this coordinator's own
## closed codes, so a prepare_begin failure carrying one is surfaced unchanged rather than being
## flattened into the generic STATE_PREPARE_FAILED.
const DOMAIN_AVAILABILITY_CODES: Array[StringName] = [
	&"NO_APP_ROUND_AVAILABLE", &"INSUFFICIENT_MOTIVATION", &"DATING_ROUTE_NOT_ACTIVE",
]


var _save_port: Object = null
var _state_port: Object = null
var _configured := false
var _active_round: Dictionary = {}
var _completed_records: Dictionary = {}
var _pending: Dictionary = {}


func _not_configured() -> Dictionary:
	return {"ok": false, "code": &"NOT_CONFIGURED"}


func _guard_first(operation_id: StringName) -> Dictionary:
	var g: Dictionary = _state_port.guard_external(operation_id)
	if not g.get("ok", false):
		return g
	return {"ok": true}


func configure(save_port: Object, state_port: Object) -> Dictionary:
	if save_port == null or state_port == null:
		return {"ok": false, "code": &"INVALID_REQUEST", "message": "both ports required"}
	for m in STATE_METHODS:
		if not state_port.has_method(m):
			return {"ok": false, "code": &"INVALID_REQUEST", "message": "state port missing " + m}
	for m in SAVE_METHODS:
		if not save_port.has_method(m):
			return {"ok": false, "code": &"INVALID_REQUEST", "message": "save port missing " + m}
	_save_port = save_port
	_state_port = state_port
	_configured = true
	return {"ok": true, "code": &"ok"}


func get_active_round() -> Dictionary:
	if _active_round.is_empty():
		return {"ok": false, "code": &"no_active_round"}
	return {"ok": true, "code": &"ok", "value": _active_round.duplicate(true)}


func _normalize_result_for_identity(result: Variant) -> Dictionary:
	if not (result is Dictionary) or result.size() != 1 or not result.has("outcome"):
		return {"ok": false, "code": &"INVALID_RESULT"}
	var outcome: Variant = result.get("outcome")
	if outcome is StringName:
		outcome = String(outcome)
	if typeof(outcome) != TYPE_STRING or not (StringName(outcome) in CONTRACT.OUTCOMES):
		return {"ok": false, "code": &"INVALID_RESULT"}
	return {"ok": true, "value": {"outcome": outcome}}


# Projects ordered recovery diagnostics through the shared projector, validates the
# full failure, substitutes only the invariant fallback on a projector/validation
# miss, latches exactly once, then returns the gate's final guard result unchanged.
#
# The context carries ONLY stable round/transaction identifiers -- never candidate bytes,
# port results, or anything else that could smuggle a non-primitive past the fence.
func _recover_and_latch(phase: String, raw_diagnostics: Array,
		round_id: String = "", transaction_id: String = "") -> Dictionary:
	var context := {}
	if round_id != "":
		context["round_id"] = round_id
	if transaction_id != "":
		context["transaction_id"] = transaction_id
	var projected := PROJECTOR.project_failure("minesweeper", phase, &"ROLLBACK_FAILED",
		context, raw_diagnostics)
	var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
	if projected.get("ok", false):
		var failure: Dictionary = projected["value"]["failure"]
		if PROJECTOR.validate_failure(failure).get("ok", false):
			candidate = failure
	_state_port.latch_fatal(candidate)
	return _state_port.guard_external(&"minesweeper_recovery")


# Runs EVERY required recovery action in the frozen order, recording one raw diagnostic per
# attempt, and continues even after an earlier attempt has already failed. When all of them
# succeed the caller's ordinary nonfatal failure stands; otherwise the irreversible
# projection -> validation/fallback -> one latch -> final guard sequence takes over and its
# retained APPLICATION_FATAL is returned instead.
#
# `actions` is an ordered Array of [owner_id, operation, Callable].
func _recover_then(actions: Array, phase: String, nonfatal: Dictionary,
		round_id: String = "", transaction_id: String = "") -> Dictionary:
	var diagnostics: Array = []
	var all_ok := true
	for action: Variant in actions:
		var entry := action as Array
		var result: Dictionary = (entry[2] as Callable).call()
		diagnostics.append({
			"owner_id": str(entry[0]), "operation": str(entry[1]), "result": result,
		})
		if not result.get("ok", false):
			all_ok = false
	if all_ok:
		return nonfatal
	return _recover_and_latch(phase, diagnostics, round_id, transaction_id)


func begin_round(request: Variant) -> Dictionary:
	if not _configured:
		return _not_configured()
	var g := _guard_first(&"minesweeper_begin_round")
	if not g.get("ok", false):
		return g
	var validated := CONTRACT.validate_start_request(request)
	if not validated.get("ok", false):
		return {"ok": false, "code": &"INVALID_REQUEST"}
	if not _active_round.is_empty():
		return {"ok": false, "code": &"ROUND_ALREADY_ACTIVE"}
	var backup: Dictionary = _state_port.capture()
	if not backup.get("ok", false):
		return backup
	var bk: Dictionary = backup["value"]["backup"]
	var run_id: String = str(bk.get("run_id", "run-1"))
	var day: int = int(bk.get("day", 1))
	var ordinal: int = int(bk.get("next_ordinal", 1))
	var round_id: String = CONTRACT.build_round_id(run_id, day, ordinal)
	var prepared: Dictionary = _state_port.prepare_begin(validated["value"], round_id)
	if not prepared.get("ok", false):
		# No round is consumed and nothing durable has happened yet, so an availability verdict
		# reaches the caller as itself; every other cause stays generic with its nested reason.
		var cause: StringName = StringName(str(prepared.get("code", &"")))
		if cause in DOMAIN_AVAILABILITY_CODES:
			return {"ok": false, "code": cause, "details": {"cause": prepared}}
		return {"ok": false, "code": &"STATE_PREPARE_FAILED"}
	# Pre-board checkpoint + autosave as one recoverable transaction.
	var s_cap: Dictionary = _save_port.capture()
	if not s_cap.get("ok", false):
		return {"ok": false, "code": &"PRE_BOARD_CHECKPOINT_FAILED"}
	var preview: Dictionary = _save_port.preview_checkpoint_id(run_id)
	if not preview.get("ok", false):
		return {"ok": false, "code": &"PRE_BOARD_CHECKPOINT_FAILED"}
	# The pre-board checkpoint is DURABLE: it writes autosave.json before the round is consumed
	# or the lock acquired, so the frozen disk_write is the autosave/pre_board pairing.
	var prep_ckpt: Dictionary = _save_port.prepare_checkpoint(prepared["value"]["pre_board_checkpoint_inputs"],
		&"pre_board", {"kind": &"autosave", "reason": &"pre_board"})
	if not prep_ckpt.get("ok", false):
		return {"ok": false, "code": &"PRE_BOARD_CHECKPOINT_FAILED"}
	var ckpt_commit: Dictionary = _save_port.commit_checkpoint(prep_ckpt["value"]["candidate"])
	if not ckpt_commit.get("ok", false):
		return {"ok": false, "code": &"PRE_BOARD_AUTOSAVE_FAILED", "details": {"cause": ckpt_commit}}
	var lock: Dictionary = _save_port.acquire_board_lock()
	if not lock.get("ok", false):
		_save_port.rollback(s_cap["value"])
		return {"ok": false, "code": &"SAVE_LOCK_FAILED", "details": {"cause": lock}}
	var comm: Dictionary = _state_port.commit(prepared["value"]["candidate"])
	if not comm.get("ok", false):
		# The durable pre-board checkpoint/autosave stays valid; only the state candidate and the
		# lock unwind. Both attempts always run, in this frozen order.
		return _recover_then([
			["minesweeper_state", "rollback", func() -> Dictionary: return _state_port.rollback(backup["value"])],
			["minesweeper_save", "release_board_lock", func() -> Dictionary: return _save_port.release_board_lock()],
		], "begin_state_commit",
			{"ok": false, "code": &"STATE_COMMIT_FAILED", "details": {"cause": comm}}, round_id)
	var active_round: Dictionary = prepared["value"]["active_round"]
	var start_receipt := {"round_id": round_id, "context": active_round.get("context", &"app"),
		"difficulty": active_round.get("difficulty", &"beginner"), "day": active_round.get("day", day),
		"ordinal": active_round.get("ordinal", ordinal)}
	var round_started := {"event_id": "round_started", "round_id": round_id,
		"context": str(start_receipt["context"]), "difficulty": str(start_receipt["difficulty"]),
		"day": int(start_receipt["day"]), "ordinal": int(start_receipt["ordinal"])}
	var pub: Dictionary = _state_port.publish(start_receipt, [round_started])
	if not pub.get("ok", false):
		# Pre-emission failpoint: nothing was emitted. Roll the committed active candidate back
		# FIRST and release the lock SECOND, leaving the durable pre-board record intact. No
		# publication is retried automatically.
		return _recover_then([
			["minesweeper_state", "rollback", func() -> Dictionary: return _state_port.rollback(backup["value"])],
			["minesweeper_save", "release_board_lock", func() -> Dictionary: return _save_port.release_board_lock()],
		], "round_start_publication",
			{"ok": false, "code": &"ROUND_START_PUBLICATION_FAILED", "details": {"cause": pub}}, round_id)
	_active_round = active_round
	return {"ok": true, "code": &"ok", "value": active_round.duplicate(true)}


func complete_round(round_id: String, result: Variant, transaction_id: String) -> Dictionary:
	if not _configured:
		return _not_configured()
	var g := _guard_first(&"minesweeper_complete_round")
	if not g.get("ok", false):
		return g
	if transaction_id == "" or transaction_id == null:
		return {"ok": false, "code": &"INVALID_TRANSACTION_ID"}
	var normalized := _normalize_result_for_identity(result)
	if not normalized.get("ok", false):
		return {"ok": false, "code": &"INVALID_RESULT"}
	# 1) Already-completed duplicate: return detached stored receipt, zero calls.
	if _completed_records.has(transaction_id):
		var stored: Dictionary = _completed_records[transaction_id]
		if round_id != stored["receipt"].get("round_id", "") or normalized["value"] != stored["normalized_result"]:
			return {"ok": false, "code": &"TRANSACTION_ID_CONFLICT"}
		return {"ok": true, "code": &"ok", "value": stored["receipt"].duplicate(true)}
	# 2) Pending duplicate: resume only the recorded phase.
	if not _pending.is_empty():
		if round_id != _pending.get("round_id", "") or transaction_id != _pending.get("transaction_id", "") \
				or normalized["value"] != _pending.get("normalized_result", {}):
			return {"ok": false, "code": &"TRANSACTION_ID_CONFLICT"}
		return _resume_pending()
	# 3) Fresh completion against the active round.
	if _active_round.is_empty() or round_id != _active_round.get("round_id", ""):
		return {"ok": false, "code": &"ROUND_ID_MISMATCH"}
	var vres := CONTRACT.validate_result(_active_round, result)
	if not vres.get("ok", false):
		return {"ok": false, "code": &"INVALID_RESULT"}
	var s_backup: Dictionary = _state_port.capture()
	if not s_backup.get("ok", false):
		return s_backup
	var w_backup: Dictionary = _save_port.capture()
	if not w_backup.get("ok", false):
		return w_backup
	var prepared: Dictionary = _state_port.prepare_complete(_active_round, result, transaction_id)
	if not prepared.get("ok", false):
		return {"ok": false, "code": &"STATE_PREPARE_FAILED"}
	var preview: Dictionary = _save_port.preview_checkpoint_id(str(_active_round.get("run_id", "run-1")))
	if not preview.get("ok", false):
		return {"ok": false, "code": &"CHECKPOINT_PREPARE_FAILED"}
	var finalized: Dictionary = _state_port.finalize_complete(prepared, preview["value"]["checkpoint_id"])
	if not finalized.get("ok", false):
		return {"ok": false, "code": &"CHECKPOINT_PREPARE_FAILED"}
	var prep_ckpt: Dictionary = _save_port.prepare_checkpoint(finalized["value"]["post_result_checkpoint_inputs"],
		&"post_result", {"kind": &"none", "reason": &"stage"})
	if not prep_ckpt.get("ok", false):
		return {"ok": false, "code": &"CHECKPOINT_PREPARE_FAILED"}
	var ckpt_commit: Dictionary = _save_port.commit_checkpoint(prep_ckpt["value"]["candidate"])
	if not ckpt_commit.get("ok", false):
		# Nothing committed yet: restore the save side only. Still pre-durable, so a successful
		# recovery leaves state, journal, sequence, signals, active round and lock byte-equal.
		return _recover_then([
			["minesweeper_save", "rollback", func() -> Dictionary: return _save_port.rollback(w_backup["value"])],
		], "completion_checkpoint_commit",
			{"ok": false, "code": &"CHECKPOINT_COMMIT_FAILED", "details": {"cause": ckpt_commit}},
			round_id, transaction_id)
	var state_commit: Dictionary = _state_port.commit(finalized["value"]["candidate"])
	if not state_commit.get("ok", false):
		# Reverse order: the state port committed last, so it unwinds first, then the checkpoint
		# that preceded it. Every attempt runs even after an earlier one has failed.
		return _recover_then([
			["minesweeper_state", "rollback", func() -> Dictionary: return _state_port.rollback(s_backup["value"])],
			["minesweeper_save", "rollback", func() -> Dictionary: return _save_port.rollback(w_backup["value"])],
		], "completion_state_commit",
			{"ok": false, "code": &"STATE_COMMIT_FAILED", "details": {"cause": state_commit}},
			round_id, transaction_id)
	_pending = {
		"round_id": round_id, "transaction_id": transaction_id, "phase": &"publish",
		"receipt": finalized["value"]["domain_receipt"].duplicate(true),
		"domain_events": (finalized["value"]["domain_events"] as Array).duplicate(true),
		"checkpoint_id": finalized["value"]["domain_receipt"].get("checkpoint_id", ""),
		"normalized_result": normalized["value"].duplicate(true),
	}
	return _resume_pending()


func _resume_pending() -> Dictionary:
	if _pending.get("phase", &"") == &"publish":
		var pub: Dictionary = _state_port.publish(_pending["receipt"], _pending["domain_events"])
		if not pub.get("ok", false):
			return {"ok": false, "code": &"COMPLETION_COMMITTED_UNPUBLISHED",
				"value": _pending["receipt"].duplicate(true)}
		_pending["phase"] = &"release_lock"
	var rel: Dictionary = _save_port.release_board_lock()
	if not rel.get("ok", false):
		return {"ok": false, "code": &"LOCK_RELEASE_PENDING",
			"value": _pending["receipt"].duplicate(true)}
	_completed_records[_pending["transaction_id"]] = {
		"receipt": _pending["receipt"].duplicate(true),
		"normalized_result": _pending["normalized_result"].duplicate(true),
	}
	var detached: Dictionary = _pending["receipt"].duplicate(true)
	_active_round = {}
	_pending = {}
	return {"ok": true, "code": &"ok", "value": detached}


func abort_round(round_id: String, reason: StringName, transaction_id: String) -> Dictionary:
	if not _configured:
		return _not_configured()
	var g := _guard_first(&"minesweeper_abort_round")
	if not g.get("ok", false):
		return g
	if _active_round.is_empty() or round_id != _active_round.get("round_id", ""):
		return {"ok": false, "code": &"ROUND_ID_MISMATCH"}
	if not _pending.is_empty():
		return {"ok": false, "code": &"ABORT_FAILED", "details": {"reason": "post-durable pending exists"}}
	var prepared: Dictionary = _state_port.prepare_abort(_active_round, reason, transaction_id)
	if not prepared.get("ok", false):
		return {"ok": false, "code": &"ABORT_FAILED"}
	# Both recovery actions always run, in the frozen order, and the lock is released only after
	# the rollback has been attempted. A failure of either uses the same projector path.
	var restored: Dictionary = _state_port.rollback(prepared["value"]["candidate"])
	var released: Dictionary = _save_port.release_board_lock() if restored.get("ok", false) else {"ok": true, "code": &"skipped"}
	if not (restored.get("ok", false) and released.get("ok", false)):
		var diagnostics: Array = [
			{"owner_id": "minesweeper_state", "operation": "rollback", "result": restored},
		]
		if not restored.get("ok", false):
			diagnostics.append({"owner_id": "minesweeper_save", "operation": "release_board_lock",
				"result": _save_port.release_board_lock()})
		else:
			diagnostics.append({"owner_id": "minesweeper_save", "operation": "release_board_lock",
				"result": released})
		return _recover_and_latch("abort_recovery", diagnostics, round_id, transaction_id)
	_active_round = {}
	return {"ok": true, "code": &"ok", "value": prepared["value"]["abort_receipt"].duplicate(true)}
