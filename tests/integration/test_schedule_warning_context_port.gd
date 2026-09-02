extends "res://addons/gut/test.gd"
# Read-only Schedule-warning context port over the REAL retained owners (Amendment Plan 03
# Task 3 Steps 1+4, dwm-oyo.3, plan line 364).
#
# configure(game_state, board_state) accepts exactly the retained GameState facade plus the
# retained DesktopBoardState owner; it is idempotent for the identical pair, refuses an
# invalid first call with invalid_schedule_warning_game_state |
# invalid_schedule_warning_board_state, and rejects later replacement with
# schedule_warning_context_already_configured before any read. snapshot_for(view) before
# configure fails schedule_warning_context_unconfigured; success is exactly value={context}
# with the exact twelve keys, requires state.day == view.day plus byte-equal causal
# identity, subtracts view-scheduled action IDs into accepted_unscheduled_date_ids, and
# consumes Plan 02's unchanged raw DesktopBoardState.capture().
#
# RED VALIDITY (plan Global Constraints line 40): the compiling port skeleton exists; every
# behavioral failure below is a typed wrong-behavior result. The static-purity tests are
# constraint scans and may already hold at RED.

const PORT := preload("res://scripts/application/schedule/GameStateScheduleWarningContextPort.gd")
const PORT_PATH := "res://scripts/application/schedule/GameStateScheduleWarningContextPort.gd"
const GAME_STATE := preload("res://autoload/GameState.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")

const CONTEXT_KEYS: Array = [
	"accepted_unscheduled_date_ids", "base_opportunity_remaining", "base_round_ordinal",
	"board_identity", "board_phase", "branch_id", "causal_day_instance",
	"desktop_timeline_generation", "eligible_unread_date_message_ids", "motivation",
	"run_id", "unfinished_base_board",
]

var _registry: Object = null
var _issuer: RefCounted = null
var _root_counter := 0



## Step-4-sanctioned independent dependency replacement: a stub board owner returning one
## fixed raw capture, and a stub warning facade returning one fixed captured state.
class StubBoardState:
	extends RefCounted
	var _snapshot: Dictionary

	func _init(snapshot: Dictionary) -> void:
		_snapshot = snapshot

	func capture() -> Dictionary:
		return _snapshot.duplicate(true)


class StubWarningGameState:
	extends RefCounted
	var _state: Dictionary

	func _init(state: Dictionary) -> void:
		_state = state

	func capture_schedule_warning_state() -> Dictionary:
		return {"ok": true, "code": &"ok",
			"value": {"state": _state.duplicate(true)}, "receipt": {}}


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_issuer = _sandbox_issuer()


func _sandbox_issuer() -> RefCounted:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root := wrapper.path_join("warning-context-%d-%d" % [_root_counter, randi()])
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(JsonFileStorage.new(root), NAMESPACE_SOURCE.new())
		.get("ok", false), "root store configured")
	assert_true(store.load_or_create().get("ok", false), "root store initialized")
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(store).get("ok", false), "issuer configured")
	return issuer


func _fresh_game_state() -> Node:
	var game_state: Node = GAME_STATE.new()
	game_state.reset_game()
	autofree(game_state)
	return game_state


func _configured(game_state: Object, board_state: Object) -> Object:
	var port: Object = PORT.new()
	var configured: Dictionary = port.configure(game_state, board_state)
	assert_true(configured.get("ok", false), "configure: " + str(configured))
	return port


func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _refused(result: Dictionary, code: String, context: String) -> void:
	assert_false(result.get("ok", true), context + " must refuse: " + str(result))
	assert_eq(_code(result), code, context + " typed code")


func _warning_state(game_state: Node) -> Dictionary:
	var captured: Dictionary = game_state.capture_schedule_warning_state()
	assert_true(captured.get("ok", false),
		"capture_schedule_warning_state: " + str(captured))
	return ((captured.get("value", {}) as Dictionary).get("state", {}) as Dictionary)


func _view_for(state: Dictionary, entries: Array = []) -> Dictionary:
	return {
		"day": int(state.get("day", -1)),
		"causal_day_instance": str(state.get("causal_day_instance", "")),
		"entries": entries.duplicate(true),
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}


func _txn() -> Dictionary:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	var value: Dictionary = issued.get("value", {})
	return {"id": str(value.get("token", "")),
		"receipt": (value.get("issuer_receipt", {}) as Dictionary).duplicate(true)}


func _offer(game_state: Node, friend_id: String, day: int, message_id: String) -> void:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(game_state.contacts,
		friend_id, day, message_id, "tx:offer:%s:%d" % [friend_id, day])
	assert_true(offered.get("ok", false), str(offered))
	game_state.contacts = (offered.get("value", {}) as Dictionary).get("candidate", {})


func _accept(game_state: Node, friend_id: String, day: int) -> String:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	var txn := _txn()
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(game_state.contacts,
		friend_id, day, txn["id"], txn["receipt"], _issuer,
		((found.get("value", {}) as Dictionary).get("record", {}) as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	game_state.contacts = (opened.get("value", {}) as Dictionary).get("candidate", {})
	return str((opened.get("receipt", {}) as Dictionary).get("receipt_id", ""))


# ---- configure seam ----

func test_snapshot_for_before_configure_is_typed() -> void:
	var port: Object = PORT.new()
	_refused(port.snapshot_for(_view_for({"day": 1, "causal_day_instance": "x"})),
		"schedule_warning_context_unconfigured", "a read before configure")


func test_configure_refuses_invalid_owners_typed() -> void:
	var game_state := _fresh_game_state()
	var board: Object = BOARD_STATE.new()
	_refused((PORT.new() as Object).configure(null, board),
		"invalid_schedule_warning_game_state", "a null GameState")
	_refused((PORT.new() as Object).configure(RefCounted.new(), board),
		"invalid_schedule_warning_game_state", "an object without the facade capabilities")
	_refused((PORT.new() as Object).configure(game_state, null),
		"invalid_schedule_warning_board_state", "a null board owner")
	_refused((PORT.new() as Object).configure(game_state, RefCounted.new()),
		"invalid_schedule_warning_board_state", "an object without capture()")


func test_configure_is_idempotent_and_rejects_replacement_before_any_read() -> void:
	var game_state := _fresh_game_state()
	var board: Object = BOARD_STATE.new()
	var port: Object = PORT.new()
	var first: Dictionary = port.configure(game_state, board)
	assert_true(first.get("ok", false), str(first))
	assert_eq(_keys_of(first.get("value", {})), ["already_configured", "configured"],
		"the exact configure value")
	assert_eq((first.get("value", {}) as Dictionary).get("already_configured", true),
		false, "a fresh configuration")
	var replay: Dictionary = port.configure(game_state, board)
	assert_true(replay.get("ok", false), "the identical pair replays: " + str(replay))
	assert_eq((replay.get("value", {}) as Dictionary).get("already_configured", false),
		true, "the replay reports already_configured")
	_refused(port.configure(_fresh_game_state(), board),
		"schedule_warning_context_already_configured",
		"a replacement GameState before any read")
	_refused(port.configure(game_state, BOARD_STATE.new()),
		"schedule_warning_context_already_configured",
		"a replacement board owner before any read")


# ---- the context read ----

func test_snapshot_for_returns_the_exact_context_from_the_real_owners() -> void:
	var game_state := _fresh_game_state()
	var board: Object = BOARD_STATE.new()
	var port := _configured(game_state, board)
	var state := _warning_state(game_state)
	var result: Dictionary = port.snapshot_for(_view_for(state))
	assert_true(result.get("ok", false), str(result))
	assert_eq(_keys_of(result.get("value", {})), ["context"],
		"the success value is exactly {context}")
	var context: Dictionary = (result.get("value", {}) as Dictionary).get("context", {})
	assert_eq(_keys_of(context), CONTEXT_KEYS, "exactly the twelve context keys")
	assert_eq(str(context.get("run_id", "")), str(state.get("run_id", "x")),
		"run identity comes from the captured state")
	assert_eq(str(context.get("causal_day_instance", "")),
		str(state.get("causal_day_instance", "x")), "byte-equal causal identity")
	assert_eq(int(context.get("motivation", -1)), int(state.get("motivation", -2)),
		"motivation is the canonical owner's, never caller-supplied")
	assert_null(context.get("board_identity", "x"),
		"a NONE board is represented only by a null identity")
	assert_eq(str(context.get("board_phase", "")), "NONE", "and phase NONE")
	assert_eq(context.get("unfinished_base_board", true), false,
		"no board is never unfinished")
	assert_eq(context.get("eligible_unread_date_message_ids", ["x"]),
		state.get("eligible_unread_date_message_ids", ["y"]),
		"the unread set is the captured canonical fact")
	assert_eq(context.get("accepted_unscheduled_date_ids", ["x"]),
		state.get("accepted_date_action_ids", ["y"]),
		"with an empty view nothing is subtracted")
	if state.get("next_app_round_ordinal") == null:
		assert_null(context.get("base_round_ordinal", "x"),
			"a null next ordinal projects null")
	else:
		assert_eq(int(context.get("base_round_ordinal", -1)),
			int(state.get("next_app_round_ordinal", -2)),
			"with no board the effective ordinal is next_app_round_ordinal")


func test_real_contacts_drive_unread_accepted_and_the_subtraction_law() -> void:
	var game_state := _fresh_game_state()
	var port := _configured(game_state, BOARD_STATE.new())
	_offer(game_state, "sylvia", 1, "msg:s1")
	_offer(game_state, "priscilla", 1, "msg:p1")
	var unread := _warning_state(game_state)
	assert_true((unread.get("eligible_unread_date_message_ids", []) as Array)
		.has("msg:p1"), "an unread current-day offer is eligible")
	assert_eq(unread.get("eligible_unread_date_message_ids", []), ["msg:p1", "msg:s1"],
		"the unread set is sorted and unique")
	assert_eq(unread.get("accepted_date_action_ids", ["x"]), [],
		"nothing is accepted yet")
	var source_receipt_id := _accept(game_state, "priscilla", 1)
	assert_false(source_receipt_id.is_empty(), "the acceptance mints a source receipt")
	var accepted := _warning_state(game_state)
	assert_eq(accepted.get("accepted_date_action_ids", []), ["solo:priscilla:day1"],
		"a read acceptance becomes an accepted current-day date action")
	assert_false((accepted.get("eligible_unread_date_message_ids", []) as Array)
		.has("msg:p1"), "an opened offer is no longer unread")
	var empty_view := _view_for(accepted)
	var unscheduled: Dictionary = port.snapshot_for(empty_view)
	assert_true(unscheduled.get("ok", false), str(unscheduled))
	assert_eq((((unscheduled.get("value", {}) as Dictionary).get("context", {})
		as Dictionary).get("accepted_unscheduled_date_ids", []) as Array),
		["solo:priscilla:day1"], "an unscheduled acceptance stays in the context")
	var scheduled_view := _view_for(accepted, [{
		"draft_entry_id": "d-p1", "day": int(accepted.get("day", -1)), "slot_index": 0,
		"action_id": "solo:priscilla:day1", "action_kind": "solo",
		"participants": ["priscilla"], "source_receipt_id": source_receipt_id,
	}])
	scheduled_view["date_entry_seen"] = true
	var subtracted: Dictionary = port.snapshot_for(scheduled_view)
	assert_true(subtracted.get("ok", false), str(subtracted))
	assert_eq((((subtracted.get("value", {}) as Dictionary).get("context", {})
		as Dictionary).get("accepted_unscheduled_date_ids", ["x"]) as Array), [],
		"an action already represented by view.entries is subtracted")


func test_snapshot_for_requires_the_matching_day_and_causal_identity() -> void:
	var game_state := _fresh_game_state()
	var port := _configured(game_state, BOARD_STATE.new())
	var state := _warning_state(game_state)
	var wrong_day := _view_for(state)
	wrong_day["day"] = int(state.get("day", 1)) + 1
	_refused(port.snapshot_for(wrong_day), "schedule_warning_view_state_mismatch",
		"a view for another day")
	var wrong_causal := _view_for(state)
	wrong_causal["causal_day_instance"] = "causal-day-other"
	_refused(port.snapshot_for(wrong_causal), "schedule_warning_view_state_mismatch",
		"a view under another causal day instance")


func test_snapshot_for_refuses_a_malformed_view() -> void:
	var game_state := _fresh_game_state()
	var port := _configured(game_state, BOARD_STATE.new())
	var state := _warning_state(game_state)
	var widened := _view_for(state)
	widened["motivation"] = 99
	_refused(port.snapshot_for(widened), "invalid_schedule_view",
		"a caller-supplied context fact hidden in the view")


# ---- static purity (plan Step 4: reject globals, scene lookup, fallback construction) ----

func test_the_port_never_locates_owners_or_scenes_statically() -> void:
	var raw := FileAccess.get_file_as_string(PORT_PATH)
	assert_false(raw.is_empty(), "the port source exists")
	# The doc header legitimately NAMES the forbidden constructs while forbidding them, so
	# the law binds the EXECUTABLE text: comment text is cut line-by-line before scanning,
	# the same discipline the frozen gate's forbidden-token walk applies.
	var executable := ""
	for line: String in raw.split("\n"):
		executable += line.split("#")[0] + "\n"
	assert_lt(executable.find("get_node("), 0, "no scene lookup")
	assert_lt(executable.find("/root"), 0, "no /root location")
	assert_lt(executable.find("get_tree("), 0, "no tree traversal")
	assert_lt(executable.find("Engine.get_singleton("), 0, "no global singleton lookup")
	assert_lt(executable.find("get_main_loop("), 0, "no main-loop traversal")
	assert_lt(executable.find("load(\"res://autoload"), 0,
		"no fallback owner loading, eager or lazy")
	assert_lt(executable.find("preload(\"res://autoload"), 0,
		"no fallback owner construction")
	assert_eq(raw.count("class_name "), 1, "one context owner, never a second")
	assert_true(raw.find("func snapshot_for(view: Dictionary) -> Dictionary:") >= 0,
		"snapshot_for accepts only the view; context facts are never caller-supplied")


# ---- review fixes: the board refusal family, configure order, null ordinal ----

func _board_snapshot(identity: Variant, phase: String) -> Dictionary:
	return {
		"schema_version": 1, "phase": phase, "revision": 1, "identity": identity,
		"candidate": null, "board": null, "settlement": null,
		"command_receipts": {}, "terminal_receipts": {},
	}


func _identity_for(state: Dictionary, ordinal: int) -> Dictionary:
	return {
		"run_id": str(state.get("run_id", "")),
		"branch_id": str(state.get("branch_id", "")),
		"desktop_timeline_generation": int(state.get("desktop_timeline_generation", 0)),
		"causal_day_instance": str(state.get("causal_day_instance", "")),
		"app_round_ordinal": ordinal,
	}


func test_a_foreign_board_identity_is_refused() -> void:
	var game_state := _fresh_game_state()
	var state := _warning_state(game_state)
	var foreign := _identity_for(state, 1)
	foreign["run_id"] = "run-other"
	var foreign_port := _configured(game_state,
		StubBoardState.new(_board_snapshot(foreign, "ACTIVE_VISIBLE")))
	_refused(foreign_port.snapshot_for(_view_for(state)),
		"schedule_warning_board_identity_mismatch", "a foreign run id")
	var drifted := _identity_for(state, 1)
	drifted["desktop_timeline_generation"] = \
		int(state.get("desktop_timeline_generation", 0)) + 1
	var drifted_port := _configured(game_state,
		StubBoardState.new(_board_snapshot(drifted, "ACTIVE_VISIBLE")))
	_refused(drifted_port.snapshot_for(_view_for(state)),
		"schedule_warning_board_identity_mismatch", "a drifted timeline generation")


func test_a_none_phase_asymmetry_is_refused() -> void:
	var game_state := _fresh_game_state()
	var state := _warning_state(game_state)
	var headless_port := _configured(game_state,
		StubBoardState.new(_board_snapshot(null, "PREPARING")))
	_refused(headless_port.snapshot_for(_view_for(state)),
		"invalid_schedule_warning_board_state", "a phase without an identity")
	var phantom_port := _configured(game_state,
		StubBoardState.new(_board_snapshot(_identity_for(state, 1), "NONE")))
	_refused(phantom_port.snapshot_for(_view_for(state)),
		"invalid_schedule_warning_board_state", "an identity without a phase")


func test_a_live_board_projects_its_identity_ordinal_and_unfinished_state() -> void:
	var game_state := _fresh_game_state()
	var state := _warning_state(game_state)
	var identity := _identity_for(state, 2)
	var port := _configured(game_state,
		StubBoardState.new(_board_snapshot(identity, "ACTIVE_SUSPENDED")))
	var result: Dictionary = port.snapshot_for(_view_for(state))
	assert_true(result.get("ok", false), str(result))
	var context: Dictionary = (result.get("value", {}) as Dictionary).get("context", {})
	assert_eq(str(JSON.stringify(context.get("board_identity", {}))),
		str(JSON.stringify(identity)), "the raw board identity is projected")
	assert_eq(str(context.get("board_phase", "")), "ACTIVE_SUSPENDED", "the raw phase")
	assert_eq(int(context.get("base_round_ordinal", -1)), 2,
		"a live board's ordinal is effective")
	assert_eq(context.get("unfinished_base_board", false), true,
		"base ordinals 1-2 in a suspended phase are unfinished")
	var supportz := _configured(game_state, StubBoardState.new(
		_board_snapshot(_identity_for(state, 4), "ACTIVE_VISIBLE")))
	var far: Dictionary = supportz.snapshot_for(_view_for(state))
	assert_true(far.get("ok", false), str(far))
	assert_eq(((far.get("value", {}) as Dictionary).get("context", {})
		as Dictionary).get("unfinished_base_board", true), false,
		"Supportz ordinals are never unfinished base boards")


func test_an_invalid_replacement_is_refused_as_invalid_first() -> void:
	var game_state := _fresh_game_state()
	var port := _configured(game_state, BOARD_STATE.new())
	_refused(port.configure(null, BOARD_STATE.new()),
		"invalid_schedule_warning_game_state",
		"validity is checked before the replacement law")
	_refused(port.configure(game_state, null),
		"invalid_schedule_warning_board_state",
		"validity is checked before the replacement law")


func test_a_null_next_ordinal_projects_a_null_base_round_ordinal() -> void:
	var state := {
		"run_id": "run-stub", "branch_id": "branch-stub",
		"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-stub",
		"day": 3, "eligible_unread_date_message_ids": [],
		"accepted_date_action_ids": [], "next_app_round_ordinal": null,
		"base_opportunity_remaining": false, "motivation": 2,
	}
	var port := _configured(StubWarningGameState.new(state), BOARD_STATE.new())
	var result: Dictionary = port.snapshot_for(_view_for(state))
	assert_true(result.get("ok", false), str(result))
	var context: Dictionary = (result.get("value", {}) as Dictionary).get("context", {})
	assert_null(context.get("base_round_ordinal", "x"),
		"an exhausted opportunity projects a null effective ordinal")
	assert_eq(context.get("base_opportunity_remaining", true), false,
		"the exhausted opportunity flag is projected")
	assert_null(context.get("board_identity", "x"), "no board either way")
