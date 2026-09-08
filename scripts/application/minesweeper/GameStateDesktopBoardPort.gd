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
## One deliberate, explicitly flagged identity-context gap remains:
##
## 1. `branch_id`, `desktop_timeline_generation`, and `causal_day_instance` are NOT yet fields on
##    GameState/RunLifecycle -- the plan adds them to the v4 Run snapshot only in Task 6. Since this
##    port may not edit GameState.gd, it cannot derive them from there. They are supplied instead as
##    `desktop_identity_context` at configure() time by whoever wires this port into production
##    (Task 6/9), never invented or derived here.
## Board dimensions and base mine counts come from MinesweeperBoardCatalog, the closed current-v1
## host/difficulty source shared with presentation. This desktop port requests only `desktop_app`.
##
## "starts-today" (frozen contracts: "increments starts-today once") has no existing GameState
## field either, and is not one of the first-Reveal receipt's exact keys -- it is kept entirely as
## this port's OWN bookkeeping (`_starts_today`, keyed by causal_day_instance), never written onto
## GameState, so it costs zero edits to autoload/GameState.gd.

const _CAPABILITY_RULES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const _BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const _BOARD_CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")

const _STAT_MOTIVATION := "motivation"
const _STAT_PRESSURE := "pressure"
## Plan 02 Task 8 (dwm-p2r.32) additions, mirroring GameStateMinesweeperShopPort's own established
## constants exactly: MinesweeperRoundCoordinator.complete_round() needs the same condition-triple
## facts Shop's own action receipts already carry.
const _STAT_HEALTH := "health"
const _CONDITION_SEQUELA := "sequela"

var _game_state: Object = null
var _identity_issuer: Object = null
var _desktop_identity_context: Variant = {}
var _starts_today: Dictionary = {}
## Plan 02 Task 6 (dwm-p2r.32), Phase D: additive DI seam beyond the frozen 8-method interface (own
## design choice -- prepare_first_reveal_consequence()'s frozen 4-arg signature has no room for a
## live consequence-state reference, so it is injected here instead, mirroring configure()'s own
## established "additive seam" pattern above). Duck-typed to DesktopConsequenceState's own capture().
var _consequence_state_port: Object = null


## Additive configuration seam beyond the frozen 8-method interface (needed since GameState and
## the identity issuer arrive by injection, never constructed here). Idempotent on identical
## replay; a changed owner is refused before any mutation.
func configure(game_state: Object, identity_issuer: Object, desktop_identity_context: Variant) -> Dictionary:
	if game_state == null or not game_state.has_method("get_stat"):
		return _fail(&"invalid_game_state", "game_state must expose get_stat", {})
	if identity_issuer == null or not identity_issuer.has_method("issue"):
		return _fail(&"invalid_identity_issuer", "identity_issuer must expose issue", {})
	var context_shape: Dictionary
	if desktop_identity_context is Callable:
		context_shape = {"ok": desktop_identity_context.is_valid() and desktop_identity_context.get_argument_count() == 0}
	elif desktop_identity_context is Dictionary:
		context_shape = _exact_keys(desktop_identity_context,
			["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"],
			&"invalid_desktop_identity_context")
	else:
		context_shape = _fail(&"invalid_desktop_identity_context", "", {})
	if not context_shape.get("ok", false):
		return context_shape
	if _game_state != null or _identity_issuer != null:
		if _game_state != game_state or _identity_issuer != identity_issuer \
				or _desktop_identity_context != desktop_identity_context:
			return _fail(&"port_already_configured", "a configured port never adopts a replacement owner", {})
		return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
	_game_state = game_state
	_identity_issuer = identity_issuer
	_desktop_identity_context = desktop_identity_context.duplicate(true) if desktop_identity_context is Dictionary else desktop_identity_context
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Plan 02 Task 6 (dwm-p2r.32), Phase D addition. Idempotent on the same instance; a different one
## is refused, matching every other configure seam in this file.
func configure_consequence_state_port(consequence_state_port: Object) -> Dictionary:
	if consequence_state_port == null or not consequence_state_port.has_method("capture"):
		return _fail(&"invalid_consequence_state_port", "consequence_state_port must expose capture", {})
	if _consequence_state_port != null:
		if _consequence_state_port == consequence_state_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"consequence_state_port_already_configured", "", {})
	_consequence_state_port = consequence_state_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


## Plan 02 Task 6 (dwm-p2r.32), Phase D addition (own design choice): DesktopFirstRevealSnapshotComposer's
## `base_snapshot_input` needs GameState's own full capture; this port is the only production seam
## with a GameState reference, so it exposes a thin, read-only forward here rather than the
## coordinator/caller reaching into GameState directly.
func capture_base_snapshot_input() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	return {"ok": true, "code": &"ok", "value": {"snapshot_input": _game_state.capture_run_snapshot_input()}, "receipt": {}}


func guard_external(_operation_id: StringName) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if _desktop_identity_context is Callable:
		var session: Dictionary = _game_state.validate_live_session(_game_state.capture_live_session().value)
		if not session.get("ok", false): return session
	# Visibility-only restore/navigation remains usable; all canonical play still waits.
	if _operation_id not in [&"resume", &"suspend"] and _game_state.has_method("require_day7_presentations_complete"):
		var presentations: Dictionary = _game_state.require_day7_presentations_complete()
		if not presentations.get("ok", false): return presentations
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func capture() -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var captured_identity := _capture_identity()
	if not captured_identity.get("ok", false): return captured_identity
	var identity_context: Dictionary = captured_identity.value
	var motivation: int = _game_state.get_stat(_STAT_MOTIVATION)
	var rounds_left: int = int(_game_state.minesweeper_rounds_left)
	var round_floor: int = int(_game_state.minesweeper_round_floor)
	var causal_day_instance: String = str(identity_context["causal_day_instance"])
	# Live ports survive Load and use the persisted completed-round count.
	# Fixed-context fixtures retain their isolated preparation bookkeeping.
	var next_ordinal: int = int(_game_state.minesweeper_app_rounds_finished_today) + 1 \
		if _desktop_identity_context is Callable else int(_starts_today.get(causal_day_instance, 0)) + 1
	var eligible: bool = motivation > 0 and rounds_left > round_floor and next_ordinal >= 1 and next_ordinal <= 5
	return {"ok": true, "code": &"ok", "value": {
		"run_id": str(identity_context["run_id"]),
		"branch_id": str(identity_context["branch_id"]),
		"desktop_timeline_generation": int(identity_context["desktop_timeline_generation"]),
		"causal_day_instance": causal_day_instance, "next_app_round_ordinal": next_ordinal,
		"eligible": eligible, "motivation": motivation, "rounds_left": rounds_left,
		"day": int(_game_state.day), "health": _game_state.get_stat(_STAT_HEALTH),
		"pressure": _game_state.get_stat(_STAT_PRESSURE),
		"carried_sequela": (_game_state.condition_effects_today as Array).has(_CONDITION_SEQUELA),
		"backup": {
			"motivation": motivation, "rounds_left": rounds_left, "starts_today": _starts_today.duplicate(true),
		},
	}, "receipt": {}}


## Pure inventory projection; the preparation pump decides when to freeze a spec.
func get_generation_capabilities() -> Dictionary:
	var ready := _require_configured()
	if not ready.ok: return ready
	return _CAPABILITY_RULES.resolve_owned(_game_state.inventory)


func prepare_spec(difficulty_id: String, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var catalog_result: Dictionary = _BOARD_CATALOG.lookup("desktop_app", difficulty_id)
	if not catalog_result.get("ok", false):
		return catalog_result
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
	var dimensions: Dictionary = catalog_result["value"]
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
	# The receipt's own identity is an issuer-derived anchored child of the ledger-verified
	# transaction receipt -- never a hand-built string. "board_start" is a registered CHILD_KINDS
	# member; source_ids is the closed, sorted, nonblank singleton [transaction_id].
	var derived: Dictionary = _identity_issuer.call(&"derive_child", {
		"child_kind": "board_start", "ordinal": 0,
		"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
		"source_ids": [transaction_id],
	})
	if not derived.get("ok", false):
		return derived
	var derived_value: Dictionary = derived["value"]
	var receipt := {
		"receipt_id": str(derived_value["child_id"]),
		"receipt_provenance": (derived_value["provenance"] as Dictionary).duplicate(true),
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


## Plan 02 Task 6 (dwm-p2r.32), Phase D, brief line 295 ("Production first-Reveal candidate law").
## Reuses prepare_first_reveal()'s exact GameState cost/counter law unchanged (its own `board_
## candidate` parameter is the SAME raw `{identity,difficulty_id,cell_index,board,proof_sha256}`
## shape prepare_first_reveal() already takes -- Task 5's own established convention, not the
## DesktopBoardState.prepare_first_reveal() candidate the coordinator separately prepares), then
## additionally returns a DesktopConsequenceState first-Reveal checkpoint marker bound to the
## currently-live consequence run_revision (see the class doc's DESIGN CHOICE note on
## _consequence_state_port -- first Reveal never opens a causal-sequence pending transaction, so
## this marker asserts revision agreement rather than carrying a content change). This method does
## NOT produce the "DesktopBoardState adoption candidate" the brief's prose also mentions -- that is
## DesktopBoardState.prepare_first_reveal()'s OWN output, which the coordinator prepares separately
## (exactly as Task 5's existing _first_reveal() already does) and hands to validate_first_reveal_
## candidates()/the composer directly.
func prepare_first_reveal_consequence(board_candidate: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary, expected_checkpoint_id: String) -> Dictionary:
	var base := prepare_first_reveal(board_candidate, transaction_id, transaction_issuer_receipt, expected_checkpoint_id)
	if not base.get("ok", false):
		return base
	var base_value: Dictionary = base["value"]
	var expected_run_revision := 0
	if _consequence_state_port != null:
		var captured: Dictionary = _consequence_state_port.call(&"capture")
		if not captured.get("ok", false):
			return captured
		expected_run_revision = int(((captured["value"] as Dictionary)["state"] as Dictionary)["run_revision"])
	return {"ok": true, "code": &"ok", "value": {
		"game_state_candidate": (base_value["run_candidate"] as Dictionary).duplicate(true),
		"consequence_candidate": {"expected_run_revision": expected_run_revision},
		"receipt": (base_value["receipt"] as Dictionary).duplicate(true),
		"publication": (base_value["publication"] as Dictionary).duplicate(true),
	}, "receipt": {}}


## Recomputes identity/transaction/revision/checkpoint parity across all three candidates (brief
## line 295: "recomputes their identity, transaction, pre/post revision, paid-start receipt,
## checkpoint ID, and board proof/hash parity"). Read-only; touches no live state.
func validate_first_reveal_candidates(game_state_candidate: Dictionary,
		board_candidate: Dictionary, consequence_candidate: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if typeof(game_state_candidate.get("transaction_id")) != TYPE_STRING \
			or str(game_state_candidate["transaction_id"]).strip_edges().is_empty():
		return _fail(&"invalid_first_reveal_candidates", "game_state_candidate.transaction_id is required", {})
	if typeof(board_candidate.get("transaction_id")) != TYPE_STRING \
			or str(board_candidate["transaction_id"]) != str(game_state_candidate["transaction_id"]):
		return _fail(&"first_reveal_candidate_transaction_mismatch",
			"board_candidate.transaction_id must match game_state_candidate", {})
	if str(board_candidate.get("kind", "")) != "first_reveal":
		return _fail(&"invalid_first_reveal_candidates", "board_candidate must be a first_reveal candidate", {})
	if typeof(board_candidate.get("board_after")) != TYPE_DICTIONARY:
		return _fail(&"invalid_first_reveal_candidates", "board_candidate.board_after is required", {})
	if typeof(consequence_candidate.get("expected_run_revision")) != TYPE_INT:
		return _fail(&"invalid_first_reveal_candidates", "consequence_candidate.expected_run_revision is required", {})
	if _consequence_state_port != null:
		var captured: Dictionary = _consequence_state_port.call(&"capture")
		if not captured.get("ok", false):
			return captured
		var live_revision := int(((captured["value"] as Dictionary)["state"] as Dictionary)["run_revision"])
		if live_revision != int(consequence_candidate["expected_run_revision"]):
			return _fail(&"first_reveal_candidate_revision_mismatch",
				"consequence_candidate.expected_run_revision no longer matches live consequence state", {})
	return {"ok": true, "code": &"ok", "value": {"valid": true}, "receipt": {}}


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
	if candidate.has("selected_difficulty"):
		var selected := _BOARD_CATALOG.lookup("desktop_app", str(candidate.selected_difficulty))
		if not selected.ok: return selected
		_game_state.minesweeper_selected_difficulty = str(candidate.selected_difficulty)
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


func _capture_identity() -> Dictionary:
	var captured: Variant = _desktop_identity_context.call() if _desktop_identity_context is Callable \
		else {"ok": true, "value": _desktop_identity_context.duplicate(true)}
	if not captured is Dictionary or not captured.get("ok", false) or not captured.get("value") is Dictionary:
		return captured if captured is Dictionary else _fail(&"invalid_desktop_identity_context", "", {})
	var shaped := _exact_keys(captured.value,
		["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"], &"invalid_desktop_identity_context")
	return captured if shaped.get("ok", false) else shaped


func get_selected_difficulty() -> String:
	return str(_game_state.minesweeper_selected_difficulty) if _game_state != null else "beginner"
