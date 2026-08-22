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
const _BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")

const _PHASE_NONE := "NONE"
const _PHASE_PREPARING := "PREPARING"
const _PHASE_PREPARED_UNSTARTED := "PREPARED_UNSTARTED"
const _PHASE_ACTIVE_VISIBLE := "ACTIVE_VISIBLE"
const _PHASE_ACTIVE_SUSPENDED := "ACTIVE_SUSPENDED"
const _PHASE_SETTLING := "SETTLING"

const _PHASES: Array[String] = [
	_PHASE_NONE, _PHASE_PREPARING, _PHASE_PREPARED_UNSTARTED,
	_PHASE_ACTIVE_VISIBLE, _PHASE_ACTIVE_SUSPENDED, _PHASE_SETTLING,
]

## Which of {identity, candidate, board, settlement} must be non-null per phase, per the frozen
## Canonical desktop state phase-invariant table.
const _PHASE_INVARIANTS := {
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
	if snapshot["identity"] != null:
		var identity_valid := _IDENTITY.validate(snapshot["identity"])
		if not identity_valid.get("ok", false):
			return identity_valid
	if typeof(snapshot["command_receipts"]) != TYPE_DICTIONARY:
		return _fail(&"snapshot_field_invalid", "command_receipts must be a dictionary", {"field": "command_receipts"})
	if typeof(snapshot["terminal_receipts"]) != TYPE_DICTIONARY:
		return _fail(&"snapshot_field_invalid", "terminal_receipts must be a dictionary", {"field": "terminal_receipts"})
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": &"restore", "snapshot_after": snapshot.duplicate(true),
	}}, "receipt": {}}


func prepare_debug_candidate(input: Dictionary, generation: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase != _PHASE_NONE:
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
	return _envelope(input, &"debug_slice_certified", _PHASE_PREPARED_UNSTARTED, _identity,
		certified_candidate, null, null)


func prepare_first_reveal(input: Dictionary, materialized: Dictionary,
		paid_start_receipt: Dictionary) -> Dictionary:
	var basics := _validate_common(input)
	if not basics.get("ok", false):
		return basics
	if _phase != _PHASE_NONE and _phase != _PHASE_PREPARED_UNSTARTED:
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
	if _phase == _PHASE_NONE:
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
		if int(input["cell_index"]) != int(live_candidate["forced_cell"]):
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
	# MinesweeperBoardReducer.first_reveal() is the pure forced-cell materializer: it never appends
	# an action-ledger entry (that starts with the first ROUTINE command), so a freshly materialized
	# first-Reveal board always carries revision 0 and an empty action ledger.
	if int(board["revision"]) != 0 or not (board["actions"] as Array).is_empty():
		return _fail(&"invalid_materialized_input", "a first-Reveal board must carry no action-ledger entries", {})
	if not (board["revealed_indices"] as Array).has(int(input["cell_index"])):
		return _fail(&"invalid_materialized_input", "the forced cell must be revealed", {})
	if typeof(paid_start_receipt) != TYPE_DICTIONARY or paid_start_receipt.is_empty():
		return _fail(&"invalid_paid_start_receipt", "paid_start_receipt must be a nonempty dictionary", {})

	var board_after := {"board": board, "paid_start_receipt": paid_start_receipt.duplicate(true)}
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
		_phase = String(snapshot["phase"])
		_revision = int(snapshot["revision"])
		_identity = _dup_or_null(snapshot["identity"])
		_candidate = _dup_or_null(snapshot["candidate"])
		_board = _dup_or_null(snapshot["board"])
		_settlement = _dup_or_null(snapshot["settlement"])
		_command_receipts = (snapshot["command_receipts"] as Dictionary).duplicate(true)
		_terminal_receipts = (snapshot["terminal_receipts"] as Dictionary).duplicate(true)
		return {"ok": true, "code": &"ok", "value": _state_view(), "receipt": {}}

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

	_phase = String(candidate["phase_after"])
	_identity = _dup_or_null(candidate.get("identity_after"))
	_candidate = _dup_or_null(candidate.get("candidate_after"))
	_board = _dup_or_null(candidate.get("board_after"))
	_settlement = _dup_or_null(candidate.get("settlement_after"))
	_revision += 1

	var result: Dictionary = _state_view()
	if candidate.has("result_override"):
		result = (candidate["result_override"] as Dictionary).duplicate(true)

	if transaction_id != "":
		_command_receipts[transaction_id] = {
			"request_fingerprint": request_fingerprint,
			"identity_fingerprint": str(candidate.get("identity_fingerprint", "")),
			"pre_revision": int(candidate["pre_revision"]), "post_revision": _revision,
			"command_kind": String(kind), "result": result.duplicate(true),
		}
	return result.duplicate(true)


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
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"kind": kind, "transaction_id": str(input["transaction_id"]),
		"request_fingerprint": str(input["request_fingerprint"]),
		"identity_fingerprint": identity_fp, "pre_revision": _revision, "phase_after": phase_after,
		"identity_after": _dup_or_null(identity_after), "candidate_after": _dup_or_null(candidate_after),
		"board_after": _dup_or_null(board_after), "settlement_after": _dup_or_null(settlement_after),
	}}, "receipt": {}}


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
