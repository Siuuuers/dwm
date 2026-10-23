extends "res://addons/gut/test.gd"
# Finite Schedule Done warning policy (Amendment Plan 03 Task 3 Steps 1-3, dwm-oyo.3;
# amendment section 10).
#
# The context is EXACTLY twelve keys; no board is represented only by board_identity=null
# plus board_phase="NONE"; an existing board requires its full identity (matching the
# context's run/branch/generation/causal-day) and one registered phase. The queue exists
# only on Days 1-6 while the date-entry-seen latch is false; the closed order is unread
# date-enabling message -> accepted-but-unscheduled date -> base Minesweeper -> Done
# proceeds; consumed receipts are keyed fingerprint|kind and once the finite queue is
# exhausted Done stays reachable. The warning-state fingerprint hashes the view projection
# {day, causal_day_instance, entries, date_entry_seen} plus the exact context, excluding
# pending_warning and consumed_warning_receipts, and is distinct from Task 2's optimistic
# fingerprint.
#
# RED VALIDITY (plan Global Constraints line 40): the compiling ScheduleWarningPolicy
# skeleton exists; every failure below is a typed wrong-behavior result.

const POLICY := preload("res://scripts/domain/schedule/ScheduleWarningPolicy.gd")
const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const CONTEXT_KEYS: Array = [
	"accepted_unscheduled_date_ids", "base_opportunity_remaining", "base_round_ordinal",
	"board_identity", "board_phase", "causal_day_instance", "desktop_timeline_generation",
	"eligible_unread_date_message_ids", "motivation", "run_id", "unfinished_base_board",
	"branch_id",
]

var _registry: Object = null
var _fingerprint := ""


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))


# ---- builders ----

func _entry(draft_entry_id: String, day: int, slot_index: int, action_id: String,
		action_kind: String, participants: Array, source_receipt_id: Variant) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": action_kind,
		"participants": participants.duplicate(),
		"source_receipt_id": source_receipt_id,
	}


func _ordinary(draft_entry_id: String, slot: int, action_id: String, day := 3) -> Dictionary:
	return _entry(draft_entry_id, day, slot, action_id, "ordinary", [], null)


func _view(day: int, entries: Array, overrides: Dictionary = {}) -> Dictionary:
	var view := {
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"entries": entries.duplicate(true),
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}
	for key: String in overrides:
		view[key] = overrides[key]
	return view


func _board_identity(ordinal: int) -> Dictionary:
	return {
		"run_id": "run-fixture", "branch_id": "branch-fixture",
		"desktop_timeline_generation": 0, "causal_day_instance": CAUSAL_DAY,
		"app_round_ordinal": ordinal,
	}


func _context(overrides: Dictionary = {}) -> Dictionary:
	var context := {
		"run_id": "run-fixture",
		"branch_id": "branch-fixture",
		"desktop_timeline_generation": 0,
		"causal_day_instance": CAUSAL_DAY,
		"eligible_unread_date_message_ids": [],
		"accepted_unscheduled_date_ids": [],
		"board_identity": null,
		"board_phase": "NONE",
		"base_round_ordinal": 1,
		"base_opportunity_remaining": true,
		"unfinished_base_board": false,
		"motivation": 1,
	}
	for key: String in overrides:
		context[key] = overrides[key]
	return context


func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _digest_of(view: Dictionary, context: Dictionary) -> String:
	var result: Dictionary = POLICY.warning_state_fingerprint(view, context)
	assert_true(result.get("ok", false), "warning_state_fingerprint: " + str(result))
	return str((result.get("value", {}) as Dictionary).get("fingerprint", ""))


func _next(view: Dictionary, context: Dictionary) -> Variant:
	var result: Dictionary = POLICY.next_warning(view, context)
	assert_true(result.get("ok", false), "next_warning: " + str(result))
	var value: Dictionary = result.get("value", {})
	assert_eq(_keys_of(value), ["warning"], "the success value is exactly {warning}")
	return value.get("warning", "MISSING")


func _next_kind(view: Dictionary, context: Dictionary) -> String:
	var warning: Variant = _next(view, context)
	if warning == null:
		return "none"
	if typeof(warning) != TYPE_DICTIONARY:
		return "MALFORMED"
	return str((warning as Dictionary).get("warning_kind", "MALFORMED"))


func _require_dict(value: Variant, context: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		return true
	assert_true(false, context + " must be a Dictionary: " + str(value))
	return false


func _consumed(view: Dictionary, context: Dictionary, kinds: Array) -> Dictionary:
	# A consumed-receipt stub index keyed fingerprint|kind for the CURRENT fingerprint.
	var digest := _digest_of(view, context)
	var index: Dictionary = {}
	for kind: String in kinds:
		index[digest + "|" + kind] = {"stub": true}
	var stamped := view.duplicate(true)
	stamped["consumed_warning_receipts"] = index
	return stamped


# ---- Step 1: exact context schema ----

func test_the_context_schema_is_exactly_twelve_keys() -> void:
	var accepted: Dictionary = POLICY.validate_context(_context())
	assert_true(accepted.get("ok", false), str(accepted))
	assert_eq(_keys_of(accepted.get("value", {})), ["context"],
		"the success value is exactly {context}")
	var sorted_keys: Array = CONTEXT_KEYS.duplicate()
	sorted_keys.sort()
	assert_eq(_keys_of((accepted.get("value", {}) as Dictionary).get("context", {})),
		sorted_keys, "the returned context carries exactly the twelve keys")
	var missing := _context()
	missing.erase("motivation")
	assert_eq(_code(POLICY.validate_context(missing)), "invalid_warning_context",
		"a missing member is refused")
	var widened := _context({"board_revision": 3})
	assert_eq(_code(POLICY.validate_context(widened)), "invalid_warning_context",
		"an unknown member is refused")
	var aliased := _context()
	aliased.erase("accepted_unscheduled_date_ids")
	aliased["accepted_date_action_ids"] = []
	assert_eq(_code(POLICY.validate_context(aliased)), "invalid_warning_context",
		"an aliased member is refused; the port already subtracted scheduled IDs")


func test_context_identity_and_type_strictness() -> void:
	assert_eq(_code(POLICY.validate_context(_context({"run_id": ""}))),
		"invalid_warning_context", "run_id is nonblank")
	assert_eq(_code(POLICY.validate_context(_context({"desktop_timeline_generation": -1}))),
		"invalid_warning_context", "the generation is a nonnegative int")
	assert_eq(_code(POLICY.validate_context(_context({"motivation": -1}))),
		"invalid_warning_context", "motivation is a nonnegative int")
	assert_eq(_code(POLICY.validate_context(_context({"motivation": "1"}))),
		"invalid_warning_context", "motivation is a strict int, never coerced")
	assert_eq(_code(POLICY.validate_context(
		_context({"eligible_unread_date_message_ids": ["b", "a"]}))),
		"invalid_warning_context", "the unread set is sorted")
	assert_eq(_code(POLICY.validate_context(
		_context({"accepted_unscheduled_date_ids": ["a", "a"]}))),
		"invalid_warning_context", "the accepted set is unique")
	assert_eq(_code(POLICY.validate_context(
		_context({"eligible_unread_date_message_ids": [1]}))),
		"invalid_warning_context", "IDs are Strings")


func test_no_board_is_null_identity_and_phase_none_only() -> void:
	assert_eq(_code(POLICY.validate_context(_context({"board_phase": "PREPARING"}))),
		"invalid_warning_context", "a null identity requires phase NONE")
	assert_eq(_code(POLICY.validate_context(
		_context({"board_identity": _board_identity(1)}))),
		"invalid_warning_context", "an existing board requires a registered non-NONE phase")
	var partial := _board_identity(1)
	partial.erase("app_round_ordinal")
	assert_eq(_code(POLICY.validate_context(_context(
		{"board_identity": partial, "board_phase": "ACTIVE_VISIBLE"}))),
		"invalid_warning_context", "an existing board requires its full identity")
	var foreign := _board_identity(1)
	foreign["run_id"] = "run-other"
	assert_eq(_code(POLICY.validate_context(_context(
		{"board_identity": foreign, "board_phase": "ACTIVE_VISIBLE"}))),
		"invalid_warning_context", "the board identity must match the context identity")
	assert_eq(_code(POLICY.validate_context(_context(
		{"board_identity": _board_identity(1), "board_phase": "OPEN"}))),
		"invalid_warning_context", "the phase set is closed")


func test_base_round_and_unfinished_board_coherence() -> void:
	assert_eq(_code(POLICY.validate_context(_context({"base_round_ordinal": 0}))),
		"invalid_warning_context", "ordinal 0 is not a round")
	assert_eq(_code(POLICY.validate_context(_context({"base_round_ordinal": 6}))),
		"invalid_warning_context", "ordinal 6 is not a round")
	assert_eq(_code(POLICY.validate_context(_context(
		{"base_round_ordinal": null, "base_opportunity_remaining": true}))),
		"invalid_warning_context", "a null ordinal is legal only after exhaustion")
	var exhausted: Dictionary = POLICY.validate_context(_context(
		{"base_round_ordinal": null, "base_opportunity_remaining": false}))
	assert_true(exhausted.get("ok", false), "exhausted rounds carry a null ordinal: "
		+ str(exhausted))
	assert_eq(_code(POLICY.validate_context(_context({
		"board_identity": _board_identity(3), "board_phase": "ACTIVE_SUSPENDED",
		"base_round_ordinal": 3, "unfinished_base_board": true,
	}))), "invalid_warning_context", "unfinished_base_board is a base-ordinal-1-2 fact")
	assert_eq(_code(POLICY.validate_context(_context({"unfinished_base_board": true}))),
		"invalid_warning_context", "no board can be unfinished")
	var suspended: Dictionary = POLICY.validate_context(_context({
		"board_identity": _board_identity(1), "board_phase": "ACTIVE_SUSPENDED",
		"base_round_ordinal": 1, "unfinished_base_board": true,
	}))
	assert_true(suspended.get("ok", false),
		"a suspended base-ordinal board is unfinished: " + str(suspended))
	assert_eq(_code(POLICY.validate_context(_context({
		"board_identity": _board_identity(1), "board_phase": "SETTLING",
		"base_round_ordinal": 1, "unfinished_base_board": true,
	}))), "invalid_warning_context", "a settling board is not unfinished")


# ---- Step 3: the warning-state fingerprint ----

func test_fingerprint_envelope_and_projection() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	var context := _context()
	var result: Dictionary = POLICY.warning_state_fingerprint(view, context)
	assert_true(result.get("ok", false), str(result))
	assert_eq(_keys_of(result.get("value", {})), ["fingerprint"],
		"the success value is exactly {fingerprint}")
	var digest := str((result.get("value", {}) as Dictionary).get("fingerprint", ""))
	assert_eq(digest.length(), 64, "a sha256 digest")
	assert_eq(digest, digest.to_lower(), "lowercase hex")
	var noisy := view.duplicate(true)
	noisy["pending_warning"] = {"stub": true}
	noisy["consumed_warning_receipts"] = {"k": {"stub": true}}
	noisy["condition_departure_receipts"] = {"c": {"stub": true}}
	assert_eq(_digest_of(noisy, context), digest,
		"pending_warning, consumed receipts and the condition ledger are excluded")
	assert_ne(_digest_of(_view(3, []), context), digest, "entries are projected")
	assert_ne(_digest_of(_view(3, [_ordinary("d1", 0, "rest")],
		{"date_entry_seen": true}), context), digest, "the latch is projected")
	assert_ne(_digest_of(view, _context({"motivation": 0})), digest,
		"the exact context is part of the preimage")


func test_fingerprint_is_distinct_from_the_optimistic_fingerprint() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	var optimistic: Dictionary = VIEW_STATE.fingerprint(view, _registry, _fingerprint)
	assert_true(optimistic.get("ok", false), str(optimistic))
	assert_ne(_digest_of(view, _context()),
		str((optimistic.get("value", {}) as Dictionary).get("fingerprint", "")),
		"the warning fingerprint is separate from Task 2's optimistic fingerprint")


func test_fingerprint_refuses_an_invalid_view_and_an_invalid_context() -> void:
	var widened := _view(3, [])
	widened["route_plan"] = []
	assert_eq(_code(POLICY.warning_state_fingerprint(widened, _context())),
		"invalid_schedule_view", "no digest over an invalid view")
	var context := _context()
	context.erase("motivation")
	assert_eq(_code(POLICY.warning_state_fingerprint(_view(3, []), context)),
		"invalid_warning_context", "no digest over an invalid context")


# ---- Step 2: the exhaustive warning table ----

func test_the_exact_order_unread_then_accepted_then_base_then_done() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	var context := _context({
		"eligible_unread_date_message_ids": ["msg-1"],
		"accepted_unscheduled_date_ids": ["solo:lavinia:day3"],
		"motivation": 0,
	})
	assert_eq(_next_kind(view, context), "unread_invitation", "unread comes first")
	var after_unread := _consumed(view, context, ["unread_invitation"])
	assert_eq(_next_kind(after_unread, context), "accepted_date", "accepted comes second")
	var after_accepted := _consumed(view, context, ["unread_invitation", "accepted_date"])
	assert_eq(_next_kind(after_accepted, context), "base_minesweeper", "base comes third")
	var exhausted := _consumed(view, context,
		["unread_invitation", "accepted_date", "base_minesweeper"])
	assert_eq(_next_kind(exhausted, context), "none",
		"the finite queue exhausts and Done stays reachable")


func test_a_presented_warning_names_its_own_fingerprint() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	var context := _context({"eligible_unread_date_message_ids": ["msg-1"]})
	var warning: Variant = _next(view, context)
	if not _require_dict(warning, "the presented warning"):
		return
	assert_eq(_keys_of(warning as Dictionary),
		["warning_kind", "warning_state_fingerprint"],
		"a presented warning is exactly {warning_kind, warning_state_fingerprint}")
	assert_eq(str((warning as Dictionary).get("warning_state_fingerprint", "")),
		_digest_of(view, context), "the warning names the fingerprint it was computed for")


func test_day_seven_and_the_latch_disable_the_queue() -> void:
	var eligible := _context({
		"eligible_unread_date_message_ids": ["msg-1"],
		"accepted_unscheduled_date_ids": ["solo:lavinia:day7"],
		"motivation": 0,
	})
	assert_eq(_next_kind(_view(7, []), eligible), "none", "Day 7 never uses this queue")
	assert_eq(_next_kind(_view(3, [_ordinary("d1", 0, "rest")],
		{"date_entry_seen": true}), eligible), "none",
		"while the latch is true no warning may appear")


func test_unread_warning_needs_an_eligible_unread_message() -> void:
	var view := _view(3, [])
	var only_unread := _context({
		"eligible_unread_date_message_ids": ["msg-1"],
		"base_opportunity_remaining": false,
	})
	assert_eq(_next_kind(view, only_unread), "unread_invitation",
		"one unread date-enabling message is eligible alone")
	assert_eq(_next_kind(view, _context({"base_opportunity_remaining": false})), "none",
		"no unread message, no accepted date, no base opportunity: Done proceeds")


func test_accepted_warning_requires_zero_motivation_and_a_non_date_entry() -> void:
	assert_eq(_next_kind(_view(3, [_ordinary("d1", 0, "rest")]),
		_context({"accepted_unscheduled_date_ids": ["solo:lavinia:day3"],
			"base_opportunity_remaining": false, "motivation": 1})), "none",
		"positive motivation never presents the accepted-date warning")
	var zero := _context({"accepted_unscheduled_date_ids": ["solo:lavinia:day3"],
		"base_opportunity_remaining": false, "motivation": 0})
	assert_eq(_next_kind(_view(3, []), zero), "none",
		"without a non-date entry the accepted-date warning is ineligible")
	assert_eq(_next_kind(_view(3, [_ordinary("d1", 0, "rest")]), zero), "accepted_date",
		"zero motivation plus a non-date entry plus an addable accepted date")


func test_base_warning_motivation_branches() -> void:
	assert_eq(_next_kind(_view(3, []), _context({"motivation": 1})), "base_minesweeper",
		"positive motivation with an unspent base opportunity")
	assert_eq(_next_kind(_view(3, [_ordinary("d1", 0, "rest")]),
		_context({"motivation": 0})), "base_minesweeper",
		"zero motivation with a non-date entry still signals the opportunity")
	assert_eq(_next_kind(_view(3, []), _context({"motivation": 0})), "none",
		"zero motivation with an empty bar presents nothing")


func test_base_warning_sources_and_supportz_exclusion() -> void:
	var unfinished := _context({
		"board_identity": _board_identity(2), "board_phase": "PREPARED_UNSTARTED",
		"base_round_ordinal": 2, "base_opportunity_remaining": false,
		"unfinished_base_board": true, "motivation": 1,
	})
	assert_eq(_next_kind(_view(3, []), unfinished), "base_minesweeper",
		"an unfinished base board is eligible without a remaining opportunity")
	var supportz := _context({
		"board_identity": _board_identity(4), "board_phase": "ACTIVE_VISIBLE",
		"base_round_ordinal": 4, "base_opportunity_remaining": false,
		"unfinished_base_board": false, "motivation": 1,
	})
	assert_eq(_next_kind(_view(3, []), supportz), "none",
		"Supportz ordinals three-to-five never qualify")
	assert_eq(_next_kind(_view(3, []), _context({
		"base_round_ordinal": null, "base_opportunity_remaining": false, "motivation": 1,
	})), "none", "an exhausted opportunity with no board presents nothing")


func test_a_changed_fingerprint_recomputes_the_queue() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	var context := _context({"eligible_unread_date_message_ids": ["msg-1"],
		"base_opportunity_remaining": false})
	var consumed := _consumed(view, context, ["unread_invitation"])
	assert_eq(_next_kind(consumed, context), "none",
		"the receipt blocks the unchanged fingerprint and nothing else is eligible")
	var changed := _context({"eligible_unread_date_message_ids": ["msg-1"],
		"base_opportunity_remaining": false, "motivation": 3})
	assert_eq(_next_kind(consumed, changed), "unread_invitation",
		"any relevant state change makes a new fingerprint and re-presents the warning")


func test_next_warning_refuses_invalid_inputs_and_is_detached() -> void:
	var context := _context()
	context.erase("run_id")
	assert_eq(_code(POLICY.next_warning(_view(3, []), context)),
		"invalid_warning_context", "an invalid context is typed, never guessed")
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	var eligible := _context({"eligible_unread_date_message_ids": ["msg-1"]})
	var first: Variant = _next(view, eligible)
	if not _require_dict(first, "the first presented warning"):
		return
	(first as Dictionary)["warning_kind"] = "tampered"
	var second: Variant = _next(view, eligible)
	if not _require_dict(second, "the recomputed warning"):
		return
	assert_eq(str((second as Dictionary).get("warning_kind", "")), "unread_invitation",
		"the policy is stateless and its results are detached")


# ---- review fixes: day window, live-board ordinal law ----

func test_day_six_still_uses_the_queue() -> void:
	var eligible := _context({"eligible_unread_date_message_ids": ["msg-1"]})
	assert_eq(_next_kind(_view(6, []), eligible), "unread_invitation",
		"Day 6 sits inside the queue's day window")


func test_a_live_board_never_carries_a_null_effective_ordinal() -> void:
	assert_eq(_code(POLICY.validate_context(_context({
		"board_identity": _board_identity(1), "board_phase": "ACTIVE_VISIBLE",
		"base_round_ordinal": null, "base_opportunity_remaining": false,
		"unfinished_base_board": false,
	}))), "invalid_warning_context", "a live board is never exhaustion")


func test_a_board_and_base_ordinal_mismatch_is_refused() -> void:
	assert_eq(_code(POLICY.validate_context(_context({
		"board_identity": _board_identity(2), "board_phase": "ACTIVE_VISIBLE",
		"base_round_ordinal": 1,
	}))), "invalid_warning_context",
		"with a board the effective ordinal is the board identity's own")
