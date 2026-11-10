class_name ScheduleWarningPolicy
extends RefCounted


const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const UNREAD_INVITATION := "unread_invitation"
const ACCEPTED_DATE := "accepted_date"
const BASE_MINESWEEPER := "base_minesweeper"

const CONTEXT_KEYS: Array = [
	"accepted_unscheduled_date_ids", "base_opportunity_remaining", "base_round_ordinal",
	"board_identity", "board_phase", "branch_id", "causal_day_instance",
	"desktop_timeline_generation", "eligible_unread_date_message_ids", "motivation",
	"run_id", "unfinished_base_board",
]
const BOARD_IDENTITY_KEYS: Array = [
	"app_round_ordinal", "branch_id", "causal_day_instance",
	"desktop_timeline_generation", "run_id",
]
const BOARD_PHASES: Array = [
	"NONE", "PAID_UNSTARTED", "PREPARING", "PREPARED_UNSTARTED", "ACTIVE_VISIBLE", "ACTIVE_SUSPENDED",
	"SETTLING",
]
const UNFINISHED_PHASES: Array = [
	"PAID_UNSTARTED", "PREPARING", "PREPARED_UNSTARTED", "ACTIVE_VISIBLE", "ACTIVE_SUSPENDED",
]
const VIEW_KEYS: Array = [
	"causal_day_instance", "condition_departure_receipts", "consumed_warning_receipts",
	"date_entry_seen", "day", "entries", "pending_warning",
]



static func validate_context(context: Dictionary) -> Dictionary:
	var fault := _context_error(context)
	if not fault.is_empty():
		return fault
	return _ok({"context": context.duplicate(true)})


static func warning_state_fingerprint(view: Dictionary, context: Dictionary) -> Dictionary:
	var view_fault := _view_shape_error(view)
	if not view_fault.is_empty():
		return view_fault
	var context_fault := _context_error(context)
	if not context_fault.is_empty():
		return context_fault
	var preimage := {
		"view_projection": _view_projection(view),
		"context": context.duplicate(true),
	}
	var canonical: Dictionary = _CANONICAL_JSON.stringify(preimage)
	if not canonical.get("ok", false):
		return _fail(&"noncanonical_warning_preimage",
			"the warning preimage is not canonicalizable",
			{"cause": canonical.get("code", &"")})
	return _ok({"fingerprint": _digest(str(canonical["value"]))})


static func next_warning(view: Dictionary, context: Dictionary) -> Dictionary:
	var fingerprinted := warning_state_fingerprint(view, context)
	if not fingerprinted.get("ok", false):
		return fingerprinted
	var digest := str((fingerprinted["value"] as Dictionary)["fingerprint"])
	if int(view["day"]) < 1 or int(view["day"]) > 6 or bool(view["date_entry_seen"]):
		return _ok({"warning": null})
	var has_non_date := false
	for raw: Variant in view["entries"] as Array:
		if typeof(raw) == TYPE_DICTIONARY \
				and str((raw as Dictionary).get("action_kind", "")) == "ordinary":
			has_non_date = true
	var motivation := int(context["motivation"])
	var eligibility: Dictionary = {}
	eligibility[UNREAD_INVITATION] = \
			not (context["eligible_unread_date_message_ids"] as Array).is_empty()
	eligibility[ACCEPTED_DATE] = motivation == 0 and has_non_date \
			and not (context["accepted_unscheduled_date_ids"] as Array).is_empty()
	eligibility[BASE_MINESWEEPER] = (bool(context["unfinished_base_board"]) \
			or bool(context["base_opportunity_remaining"])) \
			and (motivation > 0 or (motivation == 0 and has_non_date))
	var consumed: Dictionary = view["consumed_warning_receipts"]
	for kind: String in [UNREAD_INVITATION, ACCEPTED_DATE, BASE_MINESWEEPER]:
		if not bool(eligibility[kind]):
			continue
		if consumed.has(digest + "|" + kind):
			continue
		return _ok({"warning": {
			"warning_kind": kind,
			"warning_state_fingerprint": digest,
		}})
	return _ok({"warning": null})



static func _context_error(context: Dictionary) -> Dictionary:
	var keys: Array = context.keys()
	keys.sort()
	if keys != CONTEXT_KEYS:
		return _context_fault("the context carries exactly " + str(CONTEXT_KEYS), "keys")
	for field: String in ["run_id", "branch_id", "causal_day_instance"]:
		if typeof(context[field]) != TYPE_STRING or str(context[field]).strip_edges().is_empty():
			return _context_fault(field + " is a nonblank String", field)
	if typeof(context["desktop_timeline_generation"]) != TYPE_INT \
			or int(context["desktop_timeline_generation"]) < 0:
		return _context_fault("the generation is a nonnegative strict int",
			"desktop_timeline_generation")
	if typeof(context["motivation"]) != TYPE_INT or int(context["motivation"]) < 0:
		return _context_fault("motivation is a nonnegative strict int", "motivation")
	for field: String in ["eligible_unread_date_message_ids", "accepted_unscheduled_date_ids"]:
		var fault := _sorted_unique_error(context[field], field)
		if not fault.is_empty():
			return fault
	for field: String in ["base_opportunity_remaining", "unfinished_base_board"]:
		if typeof(context[field]) != TYPE_BOOL:
			return _context_fault(field + " is a strict bool", field)
	var phase: Variant = context["board_phase"]
	if typeof(phase) != TYPE_STRING or str(phase) not in BOARD_PHASES:
		return _context_fault("board_phase is one of the closed set", "board_phase")
	var identity: Variant = context["board_identity"]
	if identity == null:
		if str(phase) != "NONE":
			return _context_fault("a null identity requires phase NONE", "board_identity")
	else:
		if str(phase) == "NONE":
			return _context_fault("an existing board requires a non-NONE phase",
				"board_phase")
		var identity_fault := _board_identity_error(context, identity)
		if not identity_fault.is_empty():
			return identity_fault
	var ordinal: Variant = context["base_round_ordinal"]
	if ordinal == null:
		if bool(context["base_opportunity_remaining"]):
			return _context_fault("a null ordinal is legal only after exhaustion",
				"base_round_ordinal")
		if identity != null:
			return _context_fault(
				"a live board carries its effective ordinal, never null",
				"base_round_ordinal")
	elif typeof(ordinal) != TYPE_INT or int(ordinal) < 1 or int(ordinal) > 5:
		return _context_fault("base_round_ordinal is 1..5 or null", "base_round_ordinal")
	elif identity != null \
			and int(ordinal) != int((identity as Dictionary)["app_round_ordinal"]):
		return _context_fault(
			"with a board the effective ordinal is the board identity's own",
			"base_round_ordinal")
	if bool(context["unfinished_base_board"]):
		if identity == null:
			return _context_fault("no board can be unfinished", "unfinished_base_board")
		if int((identity as Dictionary)["app_round_ordinal"]) > 2:
			return _context_fault("unfinished_base_board is a base-ordinal-1-2 fact",
				"unfinished_base_board")
		if str(phase) not in UNFINISHED_PHASES:
			return _context_fault(
				"an unfinished board sits in an unfinished-capable phase",
				"unfinished_base_board")
	return {}


static func _board_identity_error(context: Dictionary, identity: Variant) -> Dictionary:
	if typeof(identity) != TYPE_DICTIONARY:
		return _context_fault("board_identity is null or the full identity Dictionary",
			"board_identity")
	var identity_map := identity as Dictionary
	var keys: Array = identity_map.keys()
	keys.sort()
	if keys != BOARD_IDENTITY_KEYS:
		return _context_fault("an existing board requires its full identity",
			"board_identity")
	var ordinal: Variant = identity_map["app_round_ordinal"]
	if typeof(ordinal) != TYPE_INT or int(ordinal) < 1 or int(ordinal) > 5:
		return _context_fault("app_round_ordinal is an integer in 1..5", "board_identity")
	for field: String in ["run_id", "branch_id", "causal_day_instance"]:
		if str(identity_map[field]) != str(context[field]):
			return _context_fault("the board identity must match the context identity",
				field)
	if int(identity_map["desktop_timeline_generation"]) \
			!= int(context["desktop_timeline_generation"]):
		return _context_fault("the board identity must match the context identity",
			"desktop_timeline_generation")
	return {}


static func _sorted_unique_error(value: Variant, field: String) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _context_fault(field + " is an Array", field)
	var previous := ""
	for index: int in range((value as Array).size()):
		var element: Variant = (value as Array)[index]
		if typeof(element) != TYPE_STRING or str(element).is_empty():
			return _context_fault(field + " carries nonempty String IDs", field)
		if index > 0 and str(element) <= previous:
			return _context_fault(field + " is sorted and unique", field)
		previous = str(element)
	return {}



static func _view_shape_error(view: Dictionary) -> Dictionary:
	var keys: Array = view.keys()
	keys.sort()
	if keys != VIEW_KEYS:
		return _fail(&"invalid_schedule_view",
			"the view carries exactly " + str(VIEW_KEYS), {"field": "keys"})
	if typeof(view["day"]) != TYPE_INT:
		return _fail(&"invalid_schedule_view", "day is a strict int", {"field": "day"})
	if typeof(view["causal_day_instance"]) != TYPE_STRING \
			or str(view["causal_day_instance"]).is_empty():
		return _fail(&"invalid_schedule_view",
			"causal_day_instance is a nonempty String", {"field": "causal_day_instance"})
	if typeof(view["entries"]) != TYPE_ARRAY:
		return _fail(&"invalid_schedule_view", "entries is an Array", {"field": "entries"})
	if typeof(view["date_entry_seen"]) != TYPE_BOOL:
		return _fail(&"invalid_schedule_view", "date_entry_seen is a strict bool",
			{"field": "date_entry_seen"})
	if typeof(view["consumed_warning_receipts"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_view",
			"consumed_warning_receipts is a Dictionary",
			{"field": "consumed_warning_receipts"})
	return {}


static func _view_projection(view: Dictionary) -> Dictionary:
	return {
		"day": int(view["day"]),
		"causal_day_instance": str(view["causal_day_instance"]),
		"entries": (view["entries"] as Array).duplicate(true),
		"date_entry_seen": bool(view["date_entry_seen"]),
	}



static func _digest(canonical: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


static func _context_fault(message: String, field: String) -> Dictionary:
	return _fail(&"invalid_warning_context", message, {"field": field})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
