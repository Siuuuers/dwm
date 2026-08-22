class_name GameStateDesktopBoardPort
extends RefCounted

## Production GameState-facing desktop-board state port (Plan 02 Task 5, dwm-p2r.32,
## req.minesweeper.round_contract). Delivered under this renamed path per the controller's
## coexistence ruling: the brief's `GameStateMinesweeperPort.gd` path is owned by the retained
## .9-era round transaction and is never read or edited by this file.
##
## Receives its GameState object by injection (configure()) and mutates only detached candidates
## via the prepare/commit/rollback pattern GameState already uses for its Schedule commit seam
## (capture_schedule_commit_state / prepare_schedule_commit_candidate / commit_schedule_commit_
## candidate / rollback_schedule_commit_state) -- this port never installs a raw setter, never
## touches `stats`/`minesweeper_rounds_left` outside prepare_*()/commit()/rollback(), and never
## calls SaveManager, ApplicationBootstrap, or any storage path. Full production wiring into
## GameState/ApplicationBootstrap is Task 9's job; this file is untested directly by Task 5's own
## suite (no dedicated unit test is in its Create set) -- Task 5 proves the coordinator contract
## exclusively against FakeDesktopBoardStatePort.
##
## TWO DELIBERATE, EXPLICITLY-FLAGGED SCOPING GAPS (both because their real sources do not exist
## anywhere in this codebase yet, confirmed absent as of Task 5):
##
## 1. `branch_id`, `desktop_timeline_generation`, and `causal_day_instance` are NOT yet fields on
##    GameState/RunLifecycle -- the plan adds them to the v4 Run snapshot only in Task 6. Since this
##    port may not edit GameState.gd, it cannot derive them from there. They are supplied instead as
##    `desktop_identity_context` at configure() time by whoever wires this port into production
##    (Task 6/9), never invented or derived here.
## 2. Per-difficulty board dimensions/base mine count have no registered difficulty adapter
##    anywhere in this codebase yet (confirmed: no manifest, no registry script). `_DIFFICULTY_
##    DIMENSIONS` below is an explicitly-labeled placeholder table just large enough to satisfy this
##    port's own typed contract; it is not player-facing difficulty balance and a future task
##    replacing it with a real registered adapter is expected, per the frozen board spec's own text
##    ("This plan validates dimensions and base mines supplied by the registered difficulty adapter;
##    it does not invent or revise player-facing difficulty balance").
##
## "starts-today" (frozen contracts: "increments starts-today once") has no existing GameState
## field either, and is not one of the first-Reveal receipt's exact keys -- it is kept entirely as
## this port's OWN bookkeeping (`_starts_today`, keyed by causal_day_instance), never written onto
## GameState, so it costs zero edits to autoload/GameState.gd.

const _CAPABILITY_RULES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const _BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")

const _STAT_MOTIVATION := "motivation"
const _STAT_PRESSURE := "pressure"

## PLACEHOLDER pending a real registered difficulty adapter -- see class doc gap 2.
const _DIFFICULTY_DIMENSIONS := {
	"beginner": {"width": 9, "height": 9, "base_mine_count": 10},
	"intermediate": {"width": 16, "height": 16, "base_mine_count": 40},
	"expert": {"width": 30, "height": 16, "base_mine_count": 99},
}

var _game_state: Object = null
var _identity_issuer: Object = null
var _desktop_identity_context: Dictionary = {}
var _starts_today: Dictionary = {}


## Additive configuration seam beyond the frozen 8-method interface (needed since GameState and
## the identity issuer arrive by injection, never constructed here). Idempotent on identical
## replay; a changed owner is refused before any mutation.
func configure(game_state: Object, identity_issuer: Object, desktop_identity_context: Dictionary) -> Dictionary:
	if game_state == null or not game_state.has_method("get_stat"):
		return _fail(&"invalid_game_state", "game_state must expose get_stat", {})
	if identity_issuer == null or not identity_issuer.has_method("issue"):
		return _fail(&"invalid_identity_issuer", "identity_issuer must expose issue", {})
	var context_shape := _exact_keys(desktop_identity_context,
		["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"],
		&"invalid_desktop_identity_context")
	if not context_shape.get("ok", false):
		return context_shape
	if _game_state != null or _identity_issuer != null:
		if _game_state != game_state or _identity_issuer != identity_issuer \
				or _desktop_identity_context != desktop_identity_context:
			return _fail(&"port_already_configured", "a configured port never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_game_state = game_state
	_identity_issuer = identity_issuer
	_desktop_identity_context = desktop_identity_context.duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func guard_external(_operation_id: StringName) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func capture() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var motivation: int = _game_state.get_stat(_STAT_MOTIVATION)
	var rounds_left: int = int(_game_state.minesweeper_rounds_left)
	var round_floor: int = int(_game_state.minesweeper_round_floor)
	var causal_day_instance: String = str(_desktop_identity_context["causal_day_instance"])
	var next_ordinal: int = int(_starts_today.get(causal_day_instance, 0)) + 1
	var eligible: bool = motivation > 0 and rounds_left > round_floor and next_ordinal >= 1 and next_ordinal <= 5
	return {"ok": true, "code": &"ok", "value": {
		"run_id": str(_desktop_identity_context["run_id"]),
		"branch_id": str(_desktop_identity_context["branch_id"]),
		"desktop_timeline_generation": int(_desktop_identity_context["desktop_timeline_generation"]),
		"causal_day_instance": causal_day_instance, "next_app_round_ordinal": next_ordinal,
		"eligible": eligible, "motivation": motivation, "rounds_left": rounds_left,
		"backup": {
			"motivation": motivation, "rounds_left": rounds_left, "starts_today": _starts_today.duplicate(true),
		},
	}, "receipt": {}}


func prepare_spec(difficulty_id: String, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if not _DIFFICULTY_DIMENSIONS.has(difficulty_id):
		return _fail(&"unregistered_difficulty", difficulty_id, {})
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY:
		return _fail(&"invalid_transaction_issuer_receipt", "", {})
	var captured := capture()
	if not captured.get("ok", false):
		return captured
	var facts: Dictionary = captured["value"]
	var identity := {
		"run_id": str(facts["run_id"]), "branch_id": str(facts["branch_id"]),
		"desktop_timeline_generation": int(facts["desktop_timeline_generation"]),
		"causal_day_instance": str(facts["causal_day_instance"]),
		"app_round_ordinal": int(facts["next_app_round_ordinal"]),
	}
	var dimensions: Dictionary = _DIFFICULTY_DIMENSIONS[difficulty_id]
	var owned := _CAPABILITY_RULES.resolve_owned(_game_state.inventory)
	if not owned.get("ok", false):
		return owned
	var pressure: int = _game_state.get_stat(_STAT_PRESSURE)
	var penalty_points_today: int = int(_game_state.penalty_points_today)
	var spec_inputs := _CAPABILITY_RULES.build_spec_inputs((owned["value"] as Dictionary), pressure,
		penalty_points_today)
	if not spec_inputs.get("ok", false):
		return spec_inputs
	var inputs: Dictionary = spec_inputs["value"]

	var board_token := _mint(&"board_id", "board_token")
	if not board_token.get("ok", false):
		return board_token
	var placement_nonce := _mint(&"placement_nonce", "placement_nonce")
	if not placement_nonce.get("ok", false):
		return placement_nonce
	var debug_nonce := _mint(&"debug_nonce", "debug_nonce")
	if not debug_nonce.get("ok", false):
		return debug_nonce
	var explosion_nonce := _mint(&"explosion_nonce", "explosion_nonce")
	if not explosion_nonce.get("ok", false):
		return explosion_nonce

	var requested_mine_count: int = int(dimensions["base_mine_count"]) + int(inputs["effective_extra_mines"])
	var spec := {
		"schema_version": 1, "board_kind": "desktop", "board_token": board_token["value"]["token"],
		"board_token_receipt_id": board_token["value"]["receipt_id"], "difficulty_id": difficulty_id,
		"width": int(dimensions["width"]), "height": int(dimensions["height"]),
		"base_mine_count": int(dimensions["base_mine_count"]), "pressure": pressure,
		"penalty_points_today": penalty_points_today, "raw_extra_mines": int(inputs["raw_extra_mines"]),
		"requested_mine_count": requested_mine_count, "capability_ids": inputs["capability_ids"],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": placement_nonce["value"]["token"],
		"placement_nonce_receipt_id": placement_nonce["value"]["receipt_id"],
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": debug_nonce["value"]["token"],
		"debug_nonce_receipt_id": debug_nonce["value"]["receipt_id"],
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": explosion_nonce["value"]["token"],
		"explosion_nonce_receipt_id": explosion_nonce["value"]["receipt_id"],
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}
	var validated := _BOARD_SCHEMA.validate_spec(spec)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok",
		"value": {"identity": identity, "spec": (validated["value"] as Dictionary)["spec"]}, "receipt": {}}


func prepare_first_reveal(board_candidate: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary, expected_checkpoint_id: String) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var captured := capture()
	if not captured.get("ok", false):
		return captured
	var facts: Dictionary = captured["value"]
	if not bool(facts["eligible"]):
		return _fail(&"insufficient_capacity", "no eligible ordinal or capacity remains", {})
	var motivation: int = int(facts["motivation"])
	var rounds_left: int = int(facts["rounds_left"])
	var board: Dictionary = board_candidate["board"]
	var layout_view := {
		"schema_version": 1, "width": board["width"], "height": board["height"],
		"mine_indices": board["mine_indices"], "mine_count": board["mine_count"],
	}
	var layout_sha256: String = JSON.stringify(layout_view).sha256_text()
	var receipt := {
		"receipt_id": "board_start.%s" % transaction_id,
		"receipt_provenance": {
			"child_kind": "board_start",
			"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
			"ordinal": 0, "source_ids": [transaction_id],
		},
		"transaction_id": transaction_id, "transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"identity": (board_candidate["identity"] as Dictionary).duplicate(true),
		"difficulty_id": str(board_candidate["difficulty_id"]), "first_cell": int(board_candidate["cell_index"]),
		"board_revision": int(board["revision"]), "rounds_before": rounds_left, "rounds_after": rounds_left - 1,
		"motivation_before": motivation, "motivation_after": motivation - 1, "layout_sha256": layout_sha256,
		"proof_sha256": board_candidate.get("proof_sha256", null), "checkpoint_id": expected_checkpoint_id,
	}
	var causal_day_instance: String = str(facts["causal_day_instance"])
	var run_candidate := {
		"transaction_id": transaction_id, "motivation": motivation - 1, "rounds_left": rounds_left - 1,
		"starts_today": (_starts_today.duplicate(true) as Dictionary),
	}
	(run_candidate["starts_today"] as Dictionary)[causal_day_instance] = \
		int((run_candidate["starts_today"] as Dictionary).get(causal_day_instance, 0)) + 1
	return {"ok": true, "code": &"ok", "value": {
		"run_candidate": run_candidate, "receipt": receipt.duplicate(true),
		"snapshot_input": {"transaction_id": transaction_id, "run_id": str(facts["run_id"])},
		"publication": {"transaction_id": transaction_id, "receipt": receipt.duplicate(true)},
	}, "receipt": {}}


func prepare_board_only(board_candidate: Dictionary, transaction_id: String,
		_transaction_issuer_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if typeof(board_candidate) != TYPE_DICTIONARY:
		return _fail(&"invalid_board_candidate", "", {})
	return {"ok": true, "code": &"ok",
		"value": {"run_candidate": {"transaction_id": transaction_id, "board_only": true}}, "receipt": {}}


func commit(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if candidate.get("board_only", false):
		return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": {}}
	if candidate.has("motivation"):
		_game_state.set_stat(_STAT_MOTIVATION, int(candidate["motivation"]))
	if candidate.has("rounds_left"):
		_game_state.minesweeper_rounds_left = int(candidate["rounds_left"])
	if candidate.has("starts_today"):
		_starts_today = (candidate["starts_today"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": {}}


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	_game_state.set_stat(_STAT_MOTIVATION, int(backup["motivation"]))
	_game_state.minesweeper_rounds_left = int(backup["rounds_left"])
	_starts_today = (backup["starts_today"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func publish(_publication: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": {}}


func _mint(purpose: StringName, label: String) -> Dictionary:
	var issued: Dictionary = _identity_issuer.call(&"issue", purpose)
	if not issued.get("ok", false):
		return issued
	var value: Dictionary = issued["value"]
	var receipt: Dictionary = value["issuer_receipt"]
	return {"ok": true, "code": &"ok",
		"value": {"token": str(value["token"]), "receipt_id": str(receipt["receipt_id"])}, "receipt": {}}


func _require_configured() -> Dictionary:
	if _game_state == null or _identity_issuer == null:
		return _fail(&"port_not_configured", "GameStateDesktopBoardPort.configure() was never called", {})
	return {"ok": true}


func _exact_keys(value: Dictionary, expected: Array, code: StringName) -> Dictionary:
	if value.size() != expected.size():
		return _fail(code, "expected %d members, saw %d" % [expected.size(), value.size()], {"size": value.size()})
	for key: String in expected:
		if not value.has(key):
			return _fail(code, "missing member: %s" % key, {"missing": key})
	return {"ok": true}


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
