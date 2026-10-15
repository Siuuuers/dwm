class_name DesktopBoardState
extends RefCounted

## Canonical desktop Minesweeper board state machine (Plan 02 Task 5, dwm-p2r.32, req.minesweeper
## .board_lifecycle). Closed phases NONE -> PREPARING -> PREPARED_UNSTARTED -> ACTIVE_VISIBLE
## <-> ACTIVE_SUSPENDED -> SETTLING, driven entirely by prepare_*()/commit() candidates -- no
## method ever mutates `_phase`/`_identity`/`_candidate`/`_board`/`_settlement` directly outside
## commit(). Every frozen input, command revision, preparation frontier, cell, mine, proof,
## terminal result, and settlement field is plain Dictionary/Array/primitive domain data, never
## live Node state.
##
## `commit()` is the sole transaction-id ledger: a repeat of an already-recorded transaction_id
## with an IDENTICAL request fingerprint replays the stored result verbatim (duplicate request
## equality, no re-mutation); a repeat with a DIFFERENT fingerprint conflicts; every prepare_*()
## also independently checks `expected_revision` against the live top-level revision counter
## (stale revision) before it will build a candidate at all.
##
## The `board` slot is a wrapper `{"board": <MinesweeperBoardSchema-valid board>, "paid_start_
## receipt": <opaque>}` rather than stuffing the paid receipt into the schema-valid board dict
## itself, because MinesweeperBoardSchema.validate_board() rejects any board with extra members.

const _IDENTITY := preload("res://scripts/domain/desktop/DesktopIdentity.gd")
const _INSPECTION_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")

const _CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")
const _REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const _PHASE_UNPAID := "UNPAID_UNSTARTED"
const _PHASE_PAID := "PAID_UNSTARTED"
const _PHASE_NONE := "NONE"
const _PHASE_PREPARING := "PREPARING"
const _PHASE_PREPARED_UNSTARTED := "PREPARED_UNSTARTED"
const _PHASE_ACTIVE_VISIBLE := "ACTIVE_VISIBLE"
const _PHASE_ACTIVE_SUSPENDED := "ACTIVE_SUSPENDED"
const _PHASE_SETTLING := "SETTLING"

const _PHASES: Array[String] = [
	_PHASE_NONE, _PHASE_UNPAID, _PHASE_PAID, _PHASE_PREPARING, _PHASE_PREPARED_UNSTARTED,
	_PHASE_ACTIVE_VISIBLE, _PHASE_ACTIVE_SUSPENDED, _PHASE_SETTLING,
]

## Which of {identity, candidate, board, settlement} must be non-null per phase, per the frozen
## Canonical desktop state phase-invariant table.
const _PHASE_INVARIANTS := {
	_PHASE_UNPAID: {"identity": false, "candidate": true, "board": false, "settlement": false},
	_PHASE_PAID: {"identity": true, "candidate": true, "board": false, "settlement": false},
	_PHASE_NONE: {"identity": false, "candidate": false, "board": false, "settlement": false},
	_PHASE_PREPARING: {"identity": true, "candidate": true, "board": false, "settlement": false},
	_PHASE_PREPARED_UNSTARTED: {"identity": true, "candidate": true, "board": false, "settlement": false},
	_PHASE_ACTIVE_VISIBLE: {"identity": true, "candidate": false, "board": true, "settlement": false},
	_PHASE_ACTIVE_SUSPENDED: {"identity": true, "candidate": false, "board": true, "settlement": false},
	_PHASE_SETTLING: {"identity": true, "candidate": false, "board": true, "settlement": true},
}

const _CAPTURE_KEYS: Array[String] = [
	"schema_version", "phase", "revision", "identity", "candidate", "board", "settlement",
	"command_receipts", "terminal_receipts",
]

var _phase: String = _PHASE_NONE
var _revision: int = 0
var _identity: Variant = null
var _candidate: Variant = null
var _board: Variant = null
var _settlement: Variant = null
var _command_receipts: Dictionary = {}
var _terminal_receipts: Dictionary = {}
# Recomputed at mutation/restore boundaries; idle reads do not hash the board.
var _settled_inspection := false
# Explicit Run9 admission. Legacy owners retain their separately admitted contract.
# A configures the actual retained issuer before scene restore or live commands.
var _scene_payment_issuer: Object = null

const _PAYMENT_KEYS: Array[String] = [
	"receipt_id", "receipt_provenance", "transaction_id", "transaction_issuer_receipt",
	"identity", "difficulty_id", "first_cell", "board_revision", "rounds_before", "rounds_after",
	"layout_sha256", "proof_sha256", "checkpoint_id",
]


func configure_scene_payments(issuer: Object) -> Dictionary:
	if issuer == null or not issuer.has_method(&"verify_issued") or not issuer.has_method(&"validate_child"):
		return _fail(&"scene_payment_issuer_required", "", {})
	if _scene_payment_issuer != null and _scene_payment_issuer != issuer:
		return _fail(&"scene_payment_issuer_already_configured", "", {})
	# Configure before installing data; never bless an already installed legacy board.
	if _scene_payment_issuer == null and (_phase != _PHASE_NONE or _revision != 0 \
			or _identity != null or _candidate != null or _board != null or _settlement != null \
			or not _command_receipts.is_empty() or not _terminal_receipts.is_empty()):
		return _fail(&"scene_payment_configuration_requires_empty_state", "", {})
	_scene_payment_issuer = issuer
	return {"ok": true}


func prepare_restore_scene(snapshot: Dictionary, issuer: Object) -> Dictionary:
	var configured := configure_scene_payments(issuer)
	if not configured.ok: return configured
	return prepare_restore(snapshot)


func _init() -> void:
	reset()


func reset() -> void:
	_phase = _PHASE_NONE
	_revision = 0
	_identity = null
	_candidate = null
	_board = null
	_settlement = null
	_command_receipts = {}
	_terminal_receipts = {}
	_settled_inspection = false


## Cheap foreground-pump readiness; full commands still use detached capture().
func preparation_header() -> Dictionary:
	return {"phase": _phase, "revision": _revision}


func capture() -> Dictionary:
	return {
		"schema_version": 1, "phase": _phase, "revision": _revision,
		"identity": _dup_or_null(_identity), "candidate": _dup_or_null(_candidate),
		"board": _dup_or_null(_board), "settlement": _dup_or_null(_settlement),
		"command_receipts": _command_receipts.duplicate(true),
		"terminal_receipts": _terminal_receipts.duplicate(true),
	}


# ---------------------------------------------------------------------------------------------
# prepare_*() -- every method validates against LIVE state and returns a detached candidate; none
# mutates internal state. Only commit() mutates.
# ---------------------------------------------------------------------------------------------

func prepare_restore(snapshot: Dictionary) -> Dictionary:
	var shape := _exact_keys(snapshot, _CAPTURE_KEYS, &"snapshot_member_set_invalid")
	if not shape.get("ok", false):
		return shape
	if typeof(snapshot["schema_version"]) != TYPE_INT or int(snapshot["schema_version"]) != 1:
		return _fail(&"snapshot_field_invalid", "schema_version must be exactly 1", {"field": "schema_version"})
	var phase: Variant = snapshot["phase"]
	if typeof(phase) != TYPE_STRING or not _PHASES.has(String(phase)):
		return _fail(&"snapshot_field_invalid", "phase must be one of the closed set", {"field": "phase"})
	if typeof(snapshot["revision"]) != TYPE_INT or int(snapshot["revision"]) < 0:
		return _fail(&"snapshot_field_invalid", "revision must be a nonnegative integer", {"field": "revision"})
	var invariant_check := _validate_phase_invariants(String(phase), snapshot["identity"],
		snapshot["candidate"], snapshot["board"], snapshot["settlement"])
	if not invariant_check.get("ok", false):
		return invariant_check
	if String(phase) in [_PHASE_UNPAID, _PHASE_PAID]:
		var shell_check := _validate_candidate_shell(snapshot["candidate"], String(phase))
		if not shell_check.get("ok", false): return shell_check
	if snapshot["identity"] != null:
		var identity_valid := _IDENTITY.validate(snapshot["identity"])
		if not identity_valid.get("ok", false):
			return identity_valid
	if typeof(snapshot["command_receipts"]) != TYPE_DICTIONARY:
		return _fail(&"snapshot_field_invalid", "command_receipts must be a dictionary", {"field": "command_receipts"})
	if typeof(snapshot["terminal_receipts"]) != TYPE_DICTIONARY:
		return _fail(&"snapshot_field_invalid", "terminal_receipts must be a dictionary", {"field": "terminal_receipts"})
	if _scene_payment_issuer != null:
		var payments := _validate_scene_payments(snapshot)
		if not payments.ok: return payments
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"restore", "snapshot_after": snapshot.duplicate(true),
	}}, "receipt": {}}


func prepare_debug_candidate(input: Dictionary, generation: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase not in [_PHASE_NONE, _PHASE_UNPAID, _PHASE_PAID]:
		return _fail(&"debug_candidate_requires_none_phase",
			"a Debug candidate may only begin while the board is NONE", {"phase": _phase})
	var revision_check := _check_revision(input)
	if not revision_check.get("ok", false):
		return revision_check
	var identity: Dictionary = input["identity"]
	var identity_valid := _IDENTITY.validate(identity)
	if not identity_valid.get("ok", false):
		return identity_valid
	if not input.has("spec") or typeof(input["spec"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_debug_input", "input.spec is required", {})
	var spec_valid := _BOARD_SCHEMA.validate_spec(input["spec"])
	if not spec_valid.get("ok", false):
		return spec_valid
	var frontier_check := _exact_keys(generation, ["frontier"], &"invalid_generation_frontier")
	if not frontier_check.get("ok", false):
		return frontier_check
	if typeof(generation["frontier"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_generation_frontier", "generation.frontier must be a dictionary", {})

	var candidate_after := {"spec": (spec_valid["value"] as Dictionary)["spec"],
		"frontier": (generation["frontier"] as Dictionary).duplicate(true)}
	if _phase == _PHASE_PAID:
		if input.identity != _identity or input.spec != _candidate.spec: return _fail(&"identity_mismatch", "", {})
		candidate_after["paid_start_receipt"] = _candidate.paid_start_receipt.duplicate(true)
	if _phase in [_PHASE_UNPAID, _PHASE_PAID]:
		candidate_after.merge(shell_state())
	return _envelope(input, &"debug_begin", _PHASE_PREPARING, identity, candidate_after, null, null)


func prepare_debug_slice(input: Dictionary, generation: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase != _PHASE_PREPARING:
		return _fail(&"debug_slice_requires_preparing_phase",
			"a Debug slice may only run while the board is PREPARING", {"phase": _phase})
	var revision_check := _check_revision(input)
	if not revision_check.get("ok", false):
		return revision_check
	var identity_check := _check_identity_matches_live(input)
	if not identity_check.get("ok", false):
		return identity_check

	var spec: Dictionary = (_candidate as Dictionary)["spec"]
	var done: Variant = generation.get("done")
	if typeof(done) != TYPE_BOOL:
		return _fail(&"invalid_generation_progress", "generation.done must be a boolean", {})
	if not done:
		var progress_shape := _exact_keys(generation, ["done", "frontier"], &"invalid_generation_progress")
		if not progress_shape.get("ok", false):
			return progress_shape
		if typeof(generation["frontier"]) != TYPE_DICTIONARY:
			return _fail(&"invalid_generation_progress", "generation.frontier must be a dictionary", {})
		var candidate_after := {"spec": spec.duplicate(true), "frontier": (generation["frontier"] as Dictionary).duplicate(true)}
		_copy_preparation_shell(candidate_after)
		return _envelope(input, &"debug_slice_progress", _PHASE_PREPARING, _identity, candidate_after, null, null)

	var certified_shape := _exact_keys(generation, ["done", "layout", "forced_cell", "proof_sha256"],
		&"invalid_generation_progress")
	if not certified_shape.get("ok", false):
		return certified_shape
	var layout_valid := _BOARD_SCHEMA.validate_layout(generation["layout"], spec)
	if not layout_valid.get("ok", false):
		return layout_valid
	var layout: Dictionary = (layout_valid["value"] as Dictionary)["layout"]
	var forced_cell: Variant = generation["forced_cell"]
	if typeof(forced_cell) != TYPE_INT:
		return _fail(&"invalid_generation_progress", "generation.forced_cell must be an integer", {})
	var total_cells: int = int(layout["width"]) * int(layout["height"])
	if int(forced_cell) < 0 or int(forced_cell) >= total_cells:
		return _fail(&"invalid_generation_progress", "generation.forced_cell is out of range", {})
	if (layout["mine_indices"] as Array).has(int(forced_cell)):
		return _fail(&"invalid_generation_progress", "generation.forced_cell must never be a mine", {})
	var proof_sha256: Variant = generation["proof_sha256"]
	if proof_sha256 != null and typeof(proof_sha256) != TYPE_STRING:
		return _fail(&"invalid_generation_progress", "generation.proof_sha256 must be a string or null", {})

	var certified_candidate := {
		"spec": spec.duplicate(true), "layout": layout, "forced_cell": int(forced_cell),
		"proof_sha256": proof_sha256,
	}
	_copy_preparation_shell(certified_candidate)
	return _envelope(input, &"debug_slice_certified", _PHASE_PREPARED_UNSTARTED, _identity,
		certified_candidate, null, null)


func prepare_first_reveal(input: Dictionary, materialized: Dictionary,
		paid_start_receipt: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase not in [_PHASE_NONE, _PHASE_UNPAID, _PHASE_PAID, _PHASE_PREPARED_UNSTARTED]:
		return _fail(&"first_reveal_requires_none_or_prepared_phase",
			"first Reveal may only run from NONE or PREPARED_UNSTARTED", {"phase": _phase})
	var revision_check := _check_revision(input)
	if not revision_check.get("ok", false):
		return revision_check
	if not input.has("cell_index") or typeof(input["cell_index"]) != TYPE_INT:
		return _fail(&"invalid_first_reveal_input", "input.cell_index is required", {})
	if not input.has("spec") or typeof(input["spec"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_first_reveal_input", "input.spec is required", {})
	var spec_valid := _BOARD_SCHEMA.validate_spec(input["spec"])
	if not spec_valid.get("ok", false):
		return spec_valid
	var spec: Dictionary = (spec_valid["value"] as Dictionary)["spec"]

	var identity: Dictionary
	if _phase in [_PHASE_NONE, _PHASE_UNPAID]:
		if _phase == _PHASE_UNPAID and str(_candidate.difficulty_id) != str(spec.difficulty_id):
			return _fail(&"difficulty_mismatch", "", {})
		if not input.has("identity") or typeof(input["identity"]) != TYPE_DICTIONARY:
			return _fail(&"invalid_first_reveal_input", "input.identity is required", {})
		var identity_valid := _IDENTITY.validate(input["identity"])
		if not identity_valid.get("ok", false):
			return identity_valid
		identity = input["identity"]
	else:
		var identity_check := _check_identity_matches_live(input)
		if not identity_check.get("ok", false):
			return identity_check
		identity = _identity
		var live_candidate: Dictionary = _candidate
		if spec != live_candidate["spec"]:
			return _fail(&"spec_mismatch", "the adopted spec must match the certified candidate", {})
		if _phase == _PHASE_PREPARED_UNSTARTED and int(input["cell_index"]) != int(live_candidate["forced_cell"]):
			return _fail(&"forced_cell_mismatch",
				"cell_index must equal the certified candidate's forced cell", {})

	if typeof(materialized) != TYPE_DICTIONARY or not materialized.has("layout") or not materialized.has("board"):
		return _fail(&"invalid_materialized_input", "materialized.layout and materialized.board are required", {})
	var layout_valid := _BOARD_SCHEMA.validate_layout(materialized["layout"], spec)
	if not layout_valid.get("ok", false):
		return layout_valid
	if _phase == _PHASE_PREPARED_UNSTARTED:
		var live_candidate2: Dictionary = _candidate
		if (layout_valid["value"] as Dictionary)["layout"] != live_candidate2["layout"]:
			return _fail(&"layout_mismatch", "the materialized layout must match the certified candidate", {})
	var board_valid := _BOARD_SCHEMA.validate_board(materialized["board"])
	if not board_valid.get("ok", false):
		return board_valid
	var board: Dictionary = (board_valid["value"] as Dictionary)["board"]
	# First Reveal remains one implicit action; accepted pre-Reveal Flag/Unflag actions
	# are retained verbatim, including flags that were later removed.
	var shell := shell_state()
	if int(board["revision"]) != shell.actions.size() or board.actions != shell.actions or board.flagged_indices != shell.flagged_indices:
		return _fail(&"invalid_materialized_input", "first Reveal must retain the saved shell history", {})
	if not (board["revealed_indices"] as Array).has(int(input["cell_index"])):
		return _fail(&"invalid_materialized_input", "the forced cell must be revealed", {})
	if typeof(paid_start_receipt) != TYPE_DICTIONARY or paid_start_receipt.is_empty():
		return _fail(&"invalid_paid_start_receipt", "paid_start_receipt must be a nonempty dictionary", {})

	if _candidate is Dictionary and _candidate.has("paid_start_receipt") and paid_start_receipt != _candidate.paid_start_receipt:
		return _fail(&"paid_start_receipt_mismatch", "", {})
	if _scene_payment_issuer != null and not (_candidate is Dictionary and _candidate.has("paid_start_receipt")):
		if not _same_typed(paid_start_receipt.get("transaction_id"), input.transaction_id):
			return _fail(&"paid_start_transaction_mismatch", "", {})
		var expected_proof: Variant = _candidate.get("proof_sha256") if _phase == _PHASE_PREPARED_UNSTARTED else null
		if not _same_typed(paid_start_receipt.get("proof_sha256"), expected_proof):
			return _fail(&"paid_start_proof_mismatch", "", {})
	var board_after := {"board": board, "paid_start_receipt": paid_start_receipt.duplicate(true)}
	if _phase == _PHASE_PAID or (_candidate is Dictionary and _candidate.has("paid_start_receipt")):
		board_after["spec"] = spec.duplicate(true)
	return _envelope(input, &"first_reveal", _PHASE_ACTIVE_VISIBLE, identity, null, board_after, null)


func prepare_board_command(input: Dictionary, reduced_board: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase != _PHASE_ACTIVE_VISIBLE:
		return _fail(&"board_command_requires_active_visible_phase",
			"a board command may only run while the board is ACTIVE_VISIBLE", {"phase": _phase})
	var revision_check := _check_revision(input)
	if not revision_check.get("ok", false):
		return revision_check
	var identity_check := _check_identity_matches_live(input)
	if not identity_check.get("ok", false):
		return identity_check
	var kind: Variant = input.get("kind")
	if not (kind is StringName) or not [&"reveal", &"set_flag", &"chord"].has(kind):
		return _fail(&"invalid_board_command_kind", "input.kind must be reveal, set_flag, or chord", {})
	var board_valid := _BOARD_SCHEMA.validate_board(reduced_board)
	if not board_valid.get("ok", false):
		return board_valid
	var board: Dictionary = (board_valid["value"] as Dictionary)["board"]
	var live_board: Dictionary = _board
	var board_after := {"board": board, "paid_start_receipt": (live_board["paid_start_receipt"] as Dictionary).duplicate(true)}
	if live_board.has("spec"): board_after["spec"] = live_board.spec.duplicate(true)
	return _envelope(input, &"board_command", _PHASE_ACTIVE_VISIBLE, _identity, null, board_after, null)


func prepare_visibility(input: Dictionary, visible: bool) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase != _PHASE_ACTIVE_VISIBLE and _phase != _PHASE_ACTIVE_SUSPENDED:
		return _fail(&"visibility_requires_active_phase",
			"visibility may only change while the board is ACTIVE_VISIBLE or ACTIVE_SUSPENDED",
			{"phase": _phase})
	var revision_check := _check_revision(input)
	if not revision_check.get("ok", false):
		return revision_check
	var identity_check := _check_identity_matches_live(input)
	if not identity_check.get("ok", false):
		return identity_check
	var phase_after := _PHASE_ACTIVE_VISIBLE if visible else _PHASE_ACTIVE_SUSPENDED
	var board_after: Dictionary = (_board as Dictionary).duplicate(true)
	return _envelope(input, &"visibility", phase_after, _identity, null, board_after, null)


func prepare_settlement(input: Dictionary, settlement: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase != _PHASE_ACTIVE_VISIBLE:
		return _fail(&"settlement_requires_active_visible_phase",
			"settlement may only run while the board is ACTIVE_VISIBLE", {"phase": _phase})
	var live_board: Dictionary = _board
	if not bool((live_board["board"] as Dictionary)["terminal"]):
		return _fail(&"settlement_requires_terminal_board", "the live board must be terminal", {})
	var revision_check := _check_revision(input)
	if not revision_check.get("ok", false):
		return revision_check
	var identity_check := _check_identity_matches_live(input)
	if not identity_check.get("ok", false):
		return identity_check
	if typeof(settlement) != TYPE_DICTIONARY or settlement.is_empty():
		return _fail(&"invalid_settlement", "settlement must be a nonempty dictionary", {})
	var board_after: Dictionary = live_board.duplicate(true)
	return _envelope(input, &"settlement", _PHASE_SETTLING, _identity, null, board_after,
		settlement.duplicate(true))


# ---------------------------------------------------------------------------------------------
# commit() -- the sole mutator and the sole transaction-id ledger.
# ---------------------------------------------------------------------------------------------

func commit(candidate: Dictionary) -> Dictionary:
	if not candidate.has("kind") or not (candidate["kind"] is StringName):
		return _fail(&"invalid_candidate", "candidate.kind is required", {})
	var kind: StringName = candidate["kind"]

	if kind == &"restore":
		if not candidate.has("snapshot_after") or typeof(candidate["snapshot_after"]) != TYPE_DICTIONARY:
			return _fail(&"invalid_candidate", "restore candidate.snapshot_after is required", {})
		var snapshot: Dictionary = candidate["snapshot_after"]
		if _scene_payment_issuer != null:
			var checked := prepare_restore(snapshot)
			if not checked.ok: return checked
		_phase = String(snapshot["phase"])
		_revision = int(snapshot["revision"])
		_identity = _dup_or_null(snapshot["identity"])
		_candidate = _dup_or_null(snapshot["candidate"])
		_board = _dup_or_null(snapshot["board"])
		_settlement = _dup_or_null(snapshot["settlement"])
		_command_receipts = (snapshot["command_receipts"] as Dictionary).duplicate(true)
		_terminal_receipts = (snapshot["terminal_receipts"] as Dictionary).duplicate(true)
		_settled_inspection = is_settled_inspection(snapshot)
		return _state_view()

	var transaction_id := str(candidate.get("transaction_id", ""))
	var request_fingerprint := str(candidate.get("request_fingerprint", ""))
	if transaction_id != "" and _command_receipts.has(transaction_id):
		var recorded: Dictionary = _command_receipts[transaction_id]
		if str(recorded["request_fingerprint"]) == request_fingerprint:
			return (recorded["result"] as Dictionary).duplicate(true)
		return _fail(&"transaction_conflict",
			"transaction_id was already used for a different request", {"transaction_id": transaction_id})

	for required in ["pre_revision", "phase_after"]:
		if not candidate.has(required):
			return _fail(&"invalid_candidate", "candidate.%s is required" % required, {})
	if int(candidate["pre_revision"]) != _revision:
		return _fail(&"stale_revision",
			"the candidate was prepared against a different revision than the current one",
			{"expected": _revision, "candidate_pre_revision": candidate["pre_revision"]})
	if _scene_payment_issuer != null:
		if candidate.has("result_override") and not candidate.result_override is Dictionary:
			return _fail(&"invalid_scene_board_result", "", {})
		var checked := _validate_scene_payments(_scene_candidate_snapshot(candidate))
		if not checked.ok: return checked

	_phase = String(candidate["phase_after"])
	_identity = _dup_or_null(candidate.get("identity_after"))
	_candidate = _dup_or_null(candidate.get("candidate_after"))
	_board = _dup_or_null(candidate.get("board_after"))
	_settlement = _dup_or_null(candidate.get("settlement_after"))
	_revision += 1
	_settled_inspection = is_settled_inspection(capture())

	var result: Dictionary = _state_view()
	if candidate.has("result_override"):
		result = (candidate["result_override"] as Dictionary).duplicate(true)

	_compact_prior_command_results()
	if transaction_id != "":
		_command_receipts[transaction_id] = {
			"request_fingerprint": request_fingerprint,
			"identity_fingerprint": str(candidate.get("identity_fingerprint", "")),
			"pre_revision": int(candidate["pre_revision"]), "post_revision": _revision,
			"command_kind": String(kind), "result": result.duplicate(true),
		}
	return result.duplicate(true)


func _compact_prior_command_results() -> void:
	# Only the latest accepted command needs its exact retry response. Retain older receipt
	# fingerprints and acknowledgement results so repeats complete and changed requests conflict,
	# without copying every historical board into each capture/save. First-Reveal receipts keep
	# their paid-start/publication proof. Legacy full results compact only on a new accepted input.
	for entry: Variant in _command_receipts.values():
		if not entry is Dictionary or str(entry.get("command_kind", "")) not in ["board_command", "visibility"]: continue
		if not entry.get("result") is Dictionary or not entry.get("post_revision") is int: continue
		var prior: Dictionary = entry.result
		if str(prior.get("code", "")) != "board_command_already_applied":
			entry["result"] = {"ok": true, "code": &"board_command_already_applied",
				"value": {"already_applied": true, "revision": int(entry["post_revision"])}, "receipt": {}}
		# Only the known full receipt loses metadata. Preserve opaque extensions and malformed
		# legacy entries on their existing result-compaction path; minimal receipts skip above.
		if entry.size() != 6 or not entry.has_all(["request_fingerprint", "identity_fingerprint", "pre_revision"]): continue
		if typeof(entry.request_fingerprint) != TYPE_STRING or typeof(entry.identity_fingerprint) != TYPE_STRING \
				or typeof(entry.pre_revision) != TYPE_INT: continue
		for field: String in ["command_kind", "identity_fingerprint", "pre_revision", "post_revision"]:
			entry.erase(field)


# ---------------------------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------------------------

func _validate_common(input: Dictionary) -> Dictionary:
	if not input.has("transaction_id") or typeof(input["transaction_id"]) != TYPE_STRING \
			or str(input["transaction_id"]).strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "input.transaction_id must be a nonblank string", {})
	if not input.has("expected_revision") or typeof(input["expected_revision"]) != TYPE_INT:
		return _fail(&"invalid_expected_revision", "input.expected_revision must be an integer", {})
	if not input.has("identity") or typeof(input["identity"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity", "input.identity is required", {})
	# The caller (coordinator, or a direct test) owns what "the request" conceptually is -- e.g. the
	# coordinator's own public request dict, which has a different shape than this `input` -- so the
	# fingerprint used for duplicate/conflict detection is supplied here rather than recomputed from
	# `input` itself.
	if not input.has("request_fingerprint") or typeof(input["request_fingerprint"]) != TYPE_STRING \
			or str(input["request_fingerprint"]).strip_edges().is_empty():
		return _fail(&"invalid_request_fingerprint", "input.request_fingerprint must be a nonblank string", {})
	return {"ok": true}


func _check_revision(input: Dictionary) -> Dictionary:
	if int(input["expected_revision"]) != _revision:
		return _fail(&"stale_revision", "expected_revision no longer matches the live revision",
			{"expected_revision": input["expected_revision"], "live_revision": _revision})
	return {"ok": true}


func _check_identity_matches_live(input: Dictionary) -> Dictionary:
	if input["identity"] != _identity:
		return _fail(&"identity_mismatch", "input.identity does not match the live attempt identity", {})
	return {"ok": true}


func _envelope(input: Dictionary, kind: StringName, phase_after: String, identity_after: Variant,
		candidate_after: Variant, board_after: Variant, settlement_after: Variant) -> Dictionary:
	var identity_fp := ""
	if identity_after != null:
		var fp := _IDENTITY.fingerprint(identity_after)
		if fp.get("ok", false):
			identity_fp = str((fp["value"] as Dictionary)["fingerprint"])
	var prepared := {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": kind, "transaction_id": str(input["transaction_id"]),
		"request_fingerprint": str(input["request_fingerprint"]),
		"identity_fingerprint": identity_fp, "pre_revision": _revision, "phase_after": phase_after,
		"identity_after": _dup_or_null(identity_after), "candidate_after": _dup_or_null(candidate_after),
		"board_after": _dup_or_null(board_after), "settlement_after": _dup_or_null(settlement_after),
	}}, "receipt": {}}
	if _scene_payment_issuer != null:
		var checked := _validate_scene_payments(_scene_candidate_snapshot(prepared.value.candidate))
		if not checked.ok: return checked
	return prepared


func _state_view() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"phase": _phase, "revision": _revision, "identity": _dup_or_null(_identity),
		"candidate": _dup_or_null(_candidate), "board": _dup_or_null(_board),
		"settlement": _dup_or_null(_settlement),
	}, "receipt": {}}


func _validate_phase_invariants(phase: String, identity: Variant, candidate: Variant,
		board: Variant, settlement: Variant) -> Dictionary:
	var expected: Dictionary = _PHASE_INVARIANTS[phase]
	var slots: Dictionary = {
		"identity": identity, "candidate": candidate, "board": board, "settlement": settlement,
	}
	for slot: String in slots.keys():
		var value: Variant = slots[slot]
		if value != null and typeof(value) != TYPE_DICTIONARY:
			return _fail(&"snapshot_field_invalid", "%s must be a dictionary or null" % slot, {"field": slot})
		if bool(expected[slot]) != (value != null):
			return _fail(&"snapshot_phase_invariant_violated",
				"phase %s requires %s to be %s" % [phase, slot, "non-null" if expected[slot] else "null"],
				{"phase": phase, "slot": slot})
	return {"ok": true}


func _dup_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	return (value as Dictionary).duplicate(true)


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


## An unpaid shell contains no allocation or hidden layout. A paid replacement keeps
## the original payment receipt and ordinal while freezing only the new layout spec.
func shell_state() -> Dictionary:
	if _candidate is Dictionary:
		return {"flagged_indices": _candidate.get("flagged_indices", []).duplicate(true),
			"actions": _candidate.get("actions", []).duplicate(true)}
	return {"flagged_indices": [], "actions": []}


func prepare_unpaid_shell(input: Dictionary, difficulty: String, shell: Dictionary) -> Dictionary:
	var checked := _validate_shell_input(input)
	if not checked.ok: return checked
	if _phase not in [_PHASE_NONE, _PHASE_UNPAID, _PHASE_PREPARED_UNSTARTED] or (_candidate is Dictionary and _candidate.has("paid_start_receipt")): return _fail(&"unpaid_shell_requires_unpaid_phase", "", {})
	var dimensions := _CATALOG.lookup("desktop_app", difficulty)
	if not dimensions.ok: return dimensions
	var valid := _BOARD_SCHEMA.validate_shell(shell, dimensions.value.width, dimensions.value.height)
	if not valid.ok: return valid
	var candidate: Dictionary = valid.value.shell.duplicate(true)
	candidate["difficulty_id"] = difficulty
	candidate["width"] = int(dimensions.value.width)
	candidate["height"] = int(dimensions.value.height)
	return _envelope(input, &"shell", _PHASE_UNPAID, null, candidate, null, null)


func prepare_paid_replacement(input: Dictionary, spec: Dictionary) -> Dictionary:
	var checked := _validate_shell_input(input)
	if not checked.ok: return checked
	if _phase not in [_PHASE_PAID, _PHASE_ACTIVE_VISIBLE, _PHASE_PREPARED_UNSTARTED]: return _fail(&"replacement_requires_paid_phase", "", {})
	if _phase == _PHASE_PREPARED_UNSTARTED and not _candidate.has("paid_start_receipt"): return _fail(&"replacement_requires_paid_phase", "", {})
	if _phase == _PHASE_ACTIVE_VISIBLE and bool(_board.board.terminal): return _fail(&"terminal_board_cannot_replace", "", {})
	var valid := _BOARD_SCHEMA.validate_spec(spec)
	if not valid.ok: return valid
	if valid.value.spec.board_kind != "desktop": return _fail(&"invalid_board_kind", "", {})
	var receipt: Dictionary = _board.paid_start_receipt if _phase == _PHASE_ACTIVE_VISIBLE else _candidate.paid_start_receipt
	var candidate := {"spec": valid.value.spec, "paid_start_receipt": receipt.duplicate(true), "flagged_indices": [], "actions": []}
	return _envelope(input, &"replace_board", _PHASE_PAID, _identity, candidate, null, null)


func prepare_shell_flag(input: Dictionary, shell: Dictionary) -> Dictionary:
	var checked := _validate_shell_input(input)
	if not checked.ok: return checked
	if _phase == _PHASE_UNPAID: return prepare_unpaid_shell(input, str(_candidate.difficulty_id), shell)
	if _phase not in [_PHASE_PAID, _PHASE_PREPARED_UNSTARTED]: return _fail(&"shell_flag_requires_unstarted_phase", "", {})
	var valid := _BOARD_SCHEMA.validate_shell(shell, int(_candidate.spec.width), int(_candidate.spec.height))
	if not valid.ok: return valid
	var candidate: Dictionary = _candidate.duplicate(true)
	candidate["flagged_indices"] = valid.value.shell.flagged_indices
	candidate["actions"] = valid.value.shell.actions
	return _envelope(input, &"shell", _phase, _identity, candidate, null, null)


func _validate_shell_input(input: Dictionary) -> Dictionary:
	# Only the unpaid shell permits a null identity; active command validation stays strict.
	var copy := input.duplicate(true)
	if copy.get("identity") == null: copy["identity"] = {}
	var checked := _validate_common(copy)
	if not checked.ok: return checked
	checked = _check_revision(input)
	if not checked.ok: return checked
	return _check_identity_matches_live(input)


func _validate_candidate_shell(candidate: Dictionary, phase: String) -> Dictionary:
	var width: int
	var height: int
	if phase == _PHASE_UNPAID:
		var shape := _exact_keys(candidate, ["difficulty_id", "width", "height", "flagged_indices", "actions"], &"invalid_unpaid_shell")
		if not shape.ok: return shape
		if not candidate.difficulty_id is String: return _fail(&"invalid_unpaid_shell", "", {})
		var dimensions := _CATALOG.lookup("desktop_app", candidate.difficulty_id)
		if not dimensions.ok: return dimensions
		width = int(dimensions.value.width)
		height = int(dimensions.value.height)
		if typeof(candidate.width) != TYPE_INT or typeof(candidate.height) != TYPE_INT or candidate.width != width or candidate.height != height:
			return _fail(&"invalid_unpaid_shell", "", {})
	else:
		var shape := _exact_keys(candidate, ["spec", "paid_start_receipt", "flagged_indices", "actions"], &"invalid_paid_shell")
		if not shape.ok: return shape
		if not candidate.spec is Dictionary or not candidate.paid_start_receipt is Dictionary or candidate.paid_start_receipt.is_empty():
			return _fail(&"invalid_paid_shell", "", {})
		var valid := _BOARD_SCHEMA.validate_spec(candidate.spec)
		if not valid.ok: return valid
		if valid.value.spec.board_kind != "desktop": return _fail(&"invalid_board_kind", "", {})
		width = int(valid.value.spec.width)
		height = int(valid.value.spec.height)
	return _BOARD_SCHEMA.validate_shell({"flagged_indices": candidate.flagged_indices, "actions": candidate.actions}, width, height)


func _copy_preparation_shell(target: Dictionary) -> void:
	for key: String in ["flagged_indices", "actions", "paid_start_receipt"]:
		if _candidate.has(key): target[key] = _candidate[key].duplicate(true)


## Existing active phases retain read-only inspection; the receipt binds the exact
## wrapper including payment/current spec, independent of branch/visibility revision.
func has_settled_inspection() -> bool:
	return _settled_inspection


static func inspection_board_sha256(wrapper: Dictionary) -> String:
	if not wrapper.get("board") is Dictionary or not wrapper.get("paid_start_receipt") is Dictionary: return ""
	var normalized: Dictionary = _inspection_normalize(wrapper)
	var checked := _BOARD_SCHEMA.validate_board(normalized.board)
	if not checked.get("ok", false) or not bool(checked.value.board.terminal): return ""
	var emitted := _INSPECTION_JSON.stringify(normalized)
	return str(emitted.value).sha256_text() if emitted.get("ok", false) else ""


static func is_settled_inspection(snapshot: Dictionary) -> bool:
	if str(snapshot.get("phase", "")) not in [_PHASE_ACTIVE_VISIBLE, _PHASE_ACTIVE_SUSPENDED]: return false
	if not snapshot.get("identity") is Dictionary or not snapshot.get("board") is Dictionary: return false
	if not snapshot.get("terminal_receipts") is Dictionary: return false
	var wrapper: Dictionary = snapshot.board
	if not wrapper.get("board") is Dictionary or not bool(wrapper.board.get("terminal", false)): return false
	var expected := ""
	for record: Variant in snapshot.terminal_receipts.values():
		if not record is Dictionary or str(record.get("kind", "")) != "complete": continue
		if int(record.get("app_round_ordinal", -1)) != int(snapshot.identity.get("app_round_ordinal", -2)): continue
		if str(record.get("outcome", "")) != str(wrapper.board.get("outcome", "")): continue
		var binding := str(record.get("board_sha256", ""))
		if binding.length() != 64: continue
		if expected.is_empty(): expected = inspection_board_sha256(wrapper)
		if not expected.is_empty() and binding == expected: return true
	return false


static func dismissed_inspection_snapshot(snapshot: Dictionary) -> Dictionary:
	var cleared := snapshot.duplicate(true)
	cleared["phase"] = _PHASE_NONE
	cleared["revision"] = int(snapshot.revision) + 1
	for key: String in ["identity", "candidate", "board", "settlement"]: cleared[key] = null
	return cleared


func prepare_dismiss_inspection(input: Dictionary) -> Dictionary:
	var common := _validate_common(input)
	if not common.ok: return common
	var revision := _check_revision(input)
	if not revision.ok: return revision
	var identity := _check_identity_matches_live(input)
	if not identity.ok: return identity
	if not _settled_inspection: return _fail(&"settled_inspection_required", "", {})
	return _envelope(input, &"dismiss_inspection", _PHASE_NONE, null, null, null, null)


## Match saved integral-number normalization before strict canonical serialization.
## The writer also canonicalizes StringName keys/values and ordinary/typed arrays.
static func _inspection_normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return str(value)
		TYPE_FLOAT:
			if is_finite(value) and value == floorf(value): return int(value)
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value: items.append(_inspection_normalize(item))
			return items
		TYPE_DICTIONARY:
			var fields: Dictionary = {}
			for key: Variant in value: fields[key] = _inspection_normalize(value[key])
			return fields
	return value



# Prospective state only; preparation and refused commits cannot mutate live data.
func _scene_candidate_snapshot(candidate: Dictionary) -> Dictionary:
	var projected := capture()
	projected.phase = str(candidate.get("phase_after", ""))
	projected.revision = _revision + 1
	for slot: String in ["identity", "candidate", "board", "settlement"]:
		projected[slot] = candidate.get(slot + "_after")
	var result := {"ok": true, "code": &"ok", "value": {
		"phase": projected.phase, "revision": projected.revision, "identity": projected.identity,
		"candidate": projected.candidate, "board": projected.board, "settlement": projected.settlement}, "receipt": {}}
	if candidate.has("result_override"):
		result = candidate.result_override
	projected.command_receipts[str(candidate.get("transaction_id", ""))] = {
		"request_fingerprint": candidate.get("request_fingerprint"),
		"identity_fingerprint": candidate.get("identity_fingerprint"),
		"pre_revision": candidate.get("pre_revision"), "post_revision": projected.revision,
		"command_kind": str(candidate.get("kind", "")), "result": result}
	return projected


func _validate_scene_payments(snapshot: Dictionary) -> Dictionary:
	if not _PHASES.has(snapshot.get("phase")):
		return _fail(&"invalid_scene_payment_phase", "", {})
	var slots := _validate_phase_invariants(snapshot.phase, snapshot.get("identity"),
		snapshot.get("candidate"), snapshot.get("board"), snapshot.get("settlement"))
	if not slots.ok: return slots
	# First-Reveal records are never compacted. Their receipt is the payment anchor;
	# command-map keys and current identities may have been remapped by authenticated Load.
	var anchors: Dictionary = {}
	var retained: Array[Dictionary] = []
	for entry: Variant in snapshot.command_receipts.values():
		if not entry is Dictionary or not entry.get("result") is Dictionary:
			return _fail(&"invalid_scene_board_result", "", {})
		var result: Dictionary = entry.result
		if str(result.get("code", "")) == "first_reveal_committed":
			if str(entry.get("command_kind", "")) != "first_reveal" \
					or not _exact_keys(result, ["ok", "code", "value", "receipt"], &"invalid_paid_result").ok \
					or typeof(result.ok) != TYPE_BOOL or not result.ok or not result.value is Dictionary \
					or not _exact_keys(result.value, ["receipt", "publication"], &"invalid_paid_result").ok \
					or not result.receipt is Dictionary or not result.receipt.is_empty() \
					or not result.value.receipt is Dictionary or not result.value.publication is Dictionary:
				return _fail(&"invalid_paid_result", "", {})
			var payment: Dictionary = result.value.receipt
			var checked := _validate_payment(payment, true)
			if not checked.ok: return checked
			var publication: Dictionary = result.value.publication
			if not _exact_keys(publication, ["transaction_id", "receipt"], &"invalid_paid_publication").ok \
					or not _same_typed(publication.transaction_id, payment.transaction_id) \
					or not _same_typed(publication.receipt, payment):
				return _fail(&"invalid_paid_publication", "", {})
			if anchors.has(payment.receipt_id) and not _same_typed(anchors[payment.receipt_id], payment):
				return _fail(&"conflicting_payment_anchor", "", {})
			anchors[payment.receipt_id] = payment
			continue
		var acknowledgement_kinds := {"board_configuration_committed": ["shell", "replace_board", "dismiss_inspection"],
			"shell_flag_committed": ["shell"], "paid_reveal_committed": ["first_reveal"]}
		var code := str(result.get("code", ""))
		if acknowledgement_kinds.has(code):
			if not str(entry.get("command_kind", "")) in acknowledgement_kinds[code] \
					or not _exact_keys(result, ["ok", "code", "value"], &"invalid_board_acknowledgement").ok \
					or typeof(result.ok) != TYPE_BOOL or not result.ok or not result.value is Dictionary \
					or not _exact_keys(result.value, ["revision"], &"invalid_board_acknowledgement").ok \
					or typeof(result.value.revision) != TYPE_INT or result.value.revision < 1:
				return _fail(&"invalid_board_acknowledgement", "", {})
			continue
		if str(result.get("code", "")) == "board_command_already_applied":
			if not _exact_keys(result, ["ok", "code", "value", "receipt"], &"invalid_compacted_board_result").ok \
					or typeof(result.ok) != TYPE_BOOL or not result.ok or not result.value is Dictionary \
					or not _exact_keys(result.value, ["already_applied", "revision"], &"invalid_compacted_board_result").ok \
					or typeof(result.value.already_applied) != TYPE_BOOL or not result.value.already_applied \
					or typeof(result.value.revision) != TYPE_INT or result.value.revision < 0 \
					or not result.receipt is Dictionary or not result.receipt.is_empty():
				return _fail(&"invalid_compacted_board_result", "", {})
			continue
		# Composer retains a direct state view; the board owner retains its result envelope.
		var view: Dictionary = result
		if result.has("value"):
			if not _exact_keys(result, ["ok", "code", "value", "receipt"], &"invalid_scene_board_result").ok \
					or typeof(result.ok) != TYPE_BOOL or not result.ok or not result.value is Dictionary \
					or not result.receipt is Dictionary or not result.receipt.is_empty():
				return _fail(&"invalid_scene_board_result", "", {})
			view = result.value
		if not _exact_keys(view, ["phase", "revision", "identity", "candidate", "board", "settlement"], &"invalid_scene_board_result").ok:
			return _fail(&"invalid_scene_board_result", "", {})
		retained.append(view)
		if str(entry.get("command_kind", "")) == "first_reveal" and view.get("board") is Dictionary \
				and not view.board.has("spec"):
			var wrapper: Dictionary = view.board
			if not wrapper.get("paid_start_receipt") is Dictionary: return _fail(&"invalid_paid_start_receipt", "", {})
			var payment: Dictionary = wrapper.paid_start_receipt
			var checked := _validate_payment(payment, true)
			if not checked.ok: return checked
			checked = _validate_original_payment_board(wrapper, view.identity, payment)
			if not checked.ok: return checked
			var id: String = payment.receipt_id
			if anchors.has(id) and not _same_typed(anchors[id], payment):
				return _fail(&"conflicting_payment_anchor", "", {})
			anchors[id] = payment
	for view: Dictionary in retained:
		var checked := _validate_payment_slots(view, anchors, true)
		if not checked.ok: return checked
	return _validate_payment_slots(snapshot, anchors, false)


func _validate_payment_slots(view: Dictionary, anchors: Dictionary, historical: bool) -> Dictionary:
	if not _PHASES.has(view.get("phase")):
		return _fail(&"invalid_scene_payment_phase", "", {})
	var invariant := _validate_phase_invariants(view.phase, view.get("identity"), view.get("candidate"), view.get("board"), view.get("settlement"))
	if not invariant.ok: return invariant
	for key: String in ["candidate", "board"]:
		var slot: Variant = view.get(key)
		if slot == null: continue
		if not slot is Dictionary: return _fail(&"invalid_scene_payment_slot", "", {})
		var required: bool = key == "board" or view.phase == _PHASE_PAID
		if not historical and key == "candidate" and view.get("identity") is Dictionary:
			for payment: Dictionary in anchors.values():
				if _same_typed(view.identity.get("run_id"), payment.identity.run_id) \
						and _same_typed(view.identity.get("app_round_ordinal"), payment.identity.app_round_ordinal): required = true
		if not slot.has("paid_start_receipt"):
			if required: return _fail(&"paid_start_receipt_required", "", {})
			continue
		if not slot.paid_start_receipt is Dictionary: return _fail(&"invalid_paid_start_receipt", "", {})
		var payment: Dictionary = slot.paid_start_receipt
		var valid := _validate_payment(payment, historical)
		if not valid.ok: return valid
		if not anchors.has(payment.receipt_id) or not _same_typed(anchors[payment.receipt_id], payment):
			return _fail(&"payment_anchor_missing_or_changed", "", {})
		if not view.get("identity") is Dictionary or not _IDENTITY.validate(view.identity).ok \
				or not _same_typed(view.identity.run_id, payment.identity.run_id) \
				or not _same_typed(view.identity.app_round_ordinal, payment.identity.app_round_ordinal):
			return _fail(&"payment_identity_mismatch", "", {})
		if key == "board":
			var expected: Array = ["board", "paid_start_receipt", "spec"] if slot.has("spec") else ["board", "paid_start_receipt"]
			if not _exact_keys(slot, expected, &"invalid_paid_board_wrapper").ok or not slot.get("board") is Dictionary \
					or not _BOARD_SCHEMA.validate_board(slot.board).ok:
				return _fail(&"invalid_paid_board_wrapper", "", {})
			# Only an explicit replacement spec permits a layout different from the anchor.
			if not slot.has("spec"):
				if _payment_layout_hash(slot.board) != payment.layout_sha256 \
						or slot.board.revision < payment.board_revision or not slot.board.revealed_indices.has(payment.first_cell):
					return _fail(&"payment_layout_mismatch", "", {})
		if slot.has("spec"):
			if not slot.spec is Dictionary or not _BOARD_SCHEMA.validate_spec(slot.spec).ok or slot.spec.board_kind != "desktop":
				return _fail(&"invalid_payment_spec", "", {})
			if key == "board" and (slot.board.width != slot.spec.width or slot.board.height != slot.spec.height):
				return _fail(&"replacement_board_spec_mismatch", "", {})
	return {"ok": true}


func _validate_payment(payment: Dictionary, historical: bool) -> Dictionary:
	var keys: Array[String] = _PAYMENT_KEYS.duplicate()
	var legacy: bool = historical and payment.has("motivation_before")
	if legacy: keys.append_array(["motivation_before", "motivation_after"])
	if not _exact_keys(payment, keys, &"invalid_paid_start_receipt").ok:
		return _fail(&"invalid_paid_start_receipt", "unexpected current or historical payment keys", {})
	for key: String in ["receipt_id", "transaction_id", "difficulty_id", "layout_sha256", "checkpoint_id"]:
		if typeof(payment[key]) != TYPE_STRING or payment[key].is_empty(): return _fail(&"invalid_paid_start_receipt", key, {})
	for key: String in ["first_cell", "board_revision", "rounds_before", "rounds_after"]:
		if typeof(payment[key]) != TYPE_INT: return _fail(&"invalid_paid_start_receipt", key, {})
	if payment.first_cell < 0 or payment.board_revision < 0 or payment.rounds_before - 1 != payment.rounds_after:
		return _fail(&"invalid_payment_debit", "", {})
	var dimensions := _CATALOG.lookup("desktop_app", payment.difficulty_id)
	if not dimensions.ok or payment.first_cell >= int(dimensions.value.width) * int(dimensions.value.height):
		return _fail(&"invalid_payment_cell", "", {})
	if legacy and (typeof(payment.motivation_before) != TYPE_INT or typeof(payment.motivation_after) != TYPE_INT \
			or payment.motivation_before < 1 or payment.motivation_after != payment.motivation_before - 1):
		return _fail(&"invalid_historical_payment_debit", "", {})
	if not _sha256(payment.layout_sha256) or (payment.proof_sha256 != null and not _sha256(payment.proof_sha256)):
		return _fail(&"invalid_payment_digest", "", {})
	if not payment.identity is Dictionary or not _IDENTITY.validate(payment.identity).ok \
			or not payment.transaction_issuer_receipt is Dictionary or not payment.receipt_provenance is Dictionary:
		return _fail(&"invalid_payment_provenance", "", {})
	var issued: Dictionary = _scene_payment_issuer.verify_issued(payment.transaction_issuer_receipt, &"transaction_id")
	if not issued.get("ok", false): return issued
	var provenance: Dictionary = payment.receipt_provenance
	if typeof(provenance.get("schema_version")) != TYPE_INT or typeof(provenance.get("ordinal")) != TYPE_INT:
		return _fail(&"invalid_payment_provenance", "", {})
	var child: Dictionary = _scene_payment_issuer.validate_child(provenance, &"board_start")
	if not child.get("ok", false): return child
	if not _same_typed(payment.transaction_issuer_receipt.get("token"), payment.transaction_id) \
			or not _same_typed(provenance.get("parent_receipt_id"), payment.transaction_issuer_receipt.get("receipt_id")) \
			or not _same_typed(provenance.get("ordinal"), 0) \
			or not _same_typed(provenance.get("source_ids"), [payment.transaction_id]) \
			or not _same_typed(provenance.get("child_id"), payment.receipt_id):
		return _fail(&"invalid_payment_provenance", "", {})
	return {"ok": true}


func _validate_original_payment_board(wrapper: Dictionary, identity: Variant, payment: Dictionary) -> Dictionary:
	if not _exact_keys(wrapper, ["board", "paid_start_receipt"], &"invalid_original_payment_board").ok \
			or not wrapper.get("board") is Dictionary or not _BOARD_SCHEMA.validate_board(wrapper.board).ok:
		return _fail(&"invalid_original_payment_board", "", {})
	var board: Dictionary = wrapper.board
	var dimensions := _CATALOG.lookup("desktop_app", payment.difficulty_id)
	if not dimensions.ok: return dimensions
	if not _same_typed(identity, payment.identity) or board.width != dimensions.value.width or board.height != dimensions.value.height \
			or payment.first_cell >= board.width * board.height or not board.revealed_indices.has(payment.first_cell) \
			or board.mine_indices.has(payment.first_cell) or board.revision != payment.board_revision \
			or _payment_layout_hash(board) != payment.layout_sha256:
		return _fail(&"original_payment_board_mismatch", "", {})
	return {"ok": true}


static func _payment_layout_hash(board: Dictionary) -> String:
	# Match the original producer's member order; never reseal historical receipts.
	return JSON.stringify({"schema_version": 1, "width": board.width, "height": board.height,
		"mine_indices": board.mine_indices, "mine_count": board.mine_count}).sha256_text()


static func _sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true


static func _same_typed(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _same_typed(left[key], right[key]): return false
			var matching_key_type := false
			for other: Variant in right:
				if typeof(key) == typeof(other) and key == other:
					matching_key_type = true
					break
			if not matching_key_type: return false
		return true
	if left is Array:
		if left.size() != right.size(): return false
		for index: int in left.size():
			if not _same_typed(left[index], right[index]): return false
		return true
	return left == right
