extends RefCounted

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

const _STATE_PORT_METHODS: Array[String] = [
	"guard_external", "capture", "prepare_spec", "prepare_first_reveal", "prepare_board_only",
	"commit", "rollback", "publish",
]
const _CHECKPOINT_PORT_METHODS: Array[String] = [
	"capture", "preview_checkpoint_id", "prepare_checkpoint", "commit_checkpoint",
	"seal_checkpoint", "rollback",
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


func _init() -> void:
	_board_state = _BOARD_STATE.new()


func configure(state_port: Object, checkpoint_port: Object,
		generation_port: Object, identity_issuer: Object) -> Dictionary:
	if state_port == null or not _has_all_methods(state_port, _STATE_PORT_METHODS):
		return _fail(&"invalid_state_port", "an exact state-port capability is required", {})
	if checkpoint_port == null or not _has_all_methods(checkpoint_port, _CHECKPOINT_PORT_METHODS):
		return _fail(&"invalid_checkpoint_port", "an exact checkpoint-port capability is required", {})
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
