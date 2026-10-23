class_name GameStateScheduleWarningContextPort
extends RefCounted

const _INSPECTION_BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")

## The read-only Schedule-warning context assembler (Amendment Plan 03 Task 3 Step 4,
## dwm-oyo.3, plan line 364). configure(game_state, board_state) accepts exactly the
## retained GameState facade and the retained DesktopBoardState owner; snapshot_for(view)
## validates the view's day/causal identity against capture_schedule_warning_state(),
## consumes Plan 02's UNCHANGED raw DesktopBoardState.capture() (it adds no board-owner
## method), subtracts view-represented action IDs into accepted_unscheduled_date_ids, and
## returns the exact twelve-key immutable ScheduleWarningContext. It never locates /root,
## preloads an owner, traverses a scene, or accepts caller-supplied context facts.

const _VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")

## The phases in which a base board counts as unfinished (amendment 10.5; plan line 364).
const UNFINISHED_PHASES: Array = [
	"PAID_UNSTARTED", "PREPARING", "PREPARED_UNSTARTED", "ACTIVE_VISIBLE", "ACTIVE_SUSPENDED",
]

var _configured := false
var _game_state: Object = null
var _board_state: Object = null


func configure(game_state: Object, board_state: Object) -> Dictionary:
	if game_state == null or not game_state.has_method("capture_schedule_warning_state"):
		return _fail(&"invalid_schedule_warning_game_state",
			"the retained GameState warning facade is required", {})
	if board_state == null or not board_state.has_method("capture"):
		return _fail(&"invalid_schedule_warning_board_state",
			"the retained DesktopBoardState owner is required", {})
	if _configured:
		if game_state == _game_state and board_state == _board_state:
			return _ok({"configured": true, "already_configured": true})
		return _fail(&"schedule_warning_context_already_configured",
			"the context owners are retained once and never replaced", {})
	_game_state = game_state
	_board_state = board_state
	_configured = true
	return _ok({"configured": true, "already_configured": false})


func snapshot_for(view: Dictionary) -> Dictionary:
	if not _configured:
		return _fail(&"schedule_warning_context_unconfigured",
			"configure() was never called", {})
	var shape := _view_shape_error(view)
	if not shape.is_empty():
		return shape
	var captured: Dictionary = _game_state.capture_schedule_warning_state()
	if not captured.get("ok", false):
		return captured
	var state: Dictionary = (captured["value"] as Dictionary)["state"]
	if int(view["day"]) != int(state["day"]) \
			or str(view["causal_day_instance"]) != str(state["causal_day_instance"]):
		return _fail(&"schedule_warning_view_state_mismatch",
			"the view must match the canonical day and byte-equal causal identity",
			{"view_day": int(view["day"]), "state_day": int(state["day"])})
	var board: Dictionary = _board_state.capture()
	var projected := _project_board(state, board)
	if not projected.get("ok", false):
		return projected
	var board_facts: Dictionary = projected["value"]
	var scheduled: Dictionary = {}
	for raw: Variant in view["entries"] as Array:
		if typeof(raw) == TYPE_DICTIONARY:
			scheduled[str((raw as Dictionary).get("action_id", ""))] = true
	var accepted: Array = []
	for action_id: Variant in state["accepted_date_action_ids"] as Array:
		if not scheduled.has(str(action_id)):
			accepted.append(str(action_id))
	accepted.sort()
	var unread: Array = []
	for message_id: Variant in state["eligible_unread_date_message_ids"] as Array:
		unread.append(str(message_id))
	unread.sort()
	return _ok({"context": {
		"run_id": str(state["run_id"]),
		"branch_id": str(state["branch_id"]),
		"desktop_timeline_generation": int(state["desktop_timeline_generation"]),
		"causal_day_instance": str(state["causal_day_instance"]),
		"eligible_unread_date_message_ids": unread,
		"accepted_unscheduled_date_ids": accepted,
		"board_identity": board_facts["board_identity"],
		"board_phase": str(board_facts["board_phase"]),
		"base_round_ordinal": board_facts["base_round_ordinal"],
		"base_opportunity_remaining": bool(state["base_opportunity_remaining"]),
		"unfinished_base_board": bool(board_facts["unfinished_base_board"]),
		"motivation": int(state["motivation"]),
	}})


# ---- internals ----

## Shape-level view law only: the port holds no registry, so entry law stays with the
## validators that own it; the port needs the exact envelope, the day, the causal identity,
## and the entries to subtract.
func _view_shape_error(view: Dictionary) -> Dictionary:
	var keys: Array = view.keys()
	keys.sort()
	if keys != _VIEW_STATE.VIEW_KEYS:
		return _fail(&"invalid_schedule_view",
			"the view carries exactly " + str(_VIEW_STATE.VIEW_KEYS), {"field": "keys"})
	if typeof(view["day"]) != TYPE_INT:
		return _fail(&"invalid_schedule_view", "day is a strict int", {"field": "day"})
	if typeof(view["causal_day_instance"]) != TYPE_STRING \
			or str(view["causal_day_instance"]).is_empty():
		return _fail(&"invalid_schedule_view",
			"causal_day_instance is a nonempty String",
			{"field": "causal_day_instance"})
	if typeof(view["entries"]) != TYPE_ARRAY:
		return _fail(&"invalid_schedule_view", "entries is an Array", {"field": "entries"})
	return {}


## Projects Plan 02's unchanged raw board capture: a NONE board is null identity plus phase
## NONE with the effective ordinal falling back to next_app_round_ordinal; an existing
## board must match the run/branch/generation/causal-day context, its ordinal is effective,
## and it is unfinished only for base ordinals 1-2 in the four unfinished-capable phases.
func _project_board(state: Dictionary, board: Dictionary) -> Dictionary:
	var phase := str(board.get("phase", ""))
	var identity: Variant = board.get("identity")
	if identity == null or phase in ["NONE", "UNPAID_UNSTARTED"]:
		if identity != null or phase not in ["NONE", "UNPAID_UNSTARTED"]:
			return _fail(&"invalid_schedule_warning_board_state",
				"a NONE board carries no identity and an identity carries a phase",
				{"phase": phase})
		return {"ok": true, "value": {
			"board_identity": null,
			"board_phase": "NONE",
			"base_round_ordinal": state["next_app_round_ordinal"],
			"unfinished_base_board": false,
		}}
	var identity_map := identity as Dictionary
	for field: String in ["run_id", "branch_id", "causal_day_instance"]:
		if str(identity_map.get(field, "")) != str(state[field]):
			return _fail(&"schedule_warning_board_identity_mismatch",
				"the board identity must match the run, branch, generation and causal-day",
				{"field": field})
	if int(identity_map.get("desktop_timeline_generation", -1)) \
			!= int(state["desktop_timeline_generation"]):
		return _fail(&"schedule_warning_board_identity_mismatch",
			"the board identity must match the run, branch, generation and causal-day",
			{"field": "desktop_timeline_generation"})
	var ordinal := int(identity_map.get("app_round_ordinal", 0))
	var unfinished := ordinal >= 1 and ordinal <= 2 and phase in UNFINISHED_PHASES and not _INSPECTION_BOARD.is_settled_inspection(board)
	return {"ok": true, "value": {
		"board_identity": identity_map.duplicate(true),
		"board_phase": phase,
		"base_round_ordinal": ordinal,
		"unfinished_base_board": unfinished,
	}}


func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
