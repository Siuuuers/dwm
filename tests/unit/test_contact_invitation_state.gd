extends "res://addons/gut/test.gd"

# Stateless ContactInvitationState (dwm-p2r.6, plan-04 Task 1). Supersedes the
# stateful RefCounted suite; see docs/superpowers/plans/2026-07-22-phase-2r-06-contacts-stateless-reconciliation.md

const CONTACT_STATE_PATH := "res://scripts/domain/contact/ContactInvitationState.gd"
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const DATA_CATALOG := preload("res://scripts/data/DataCatalog.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

var _identity_issuer: RefCounted
var _registry: RefCounted
var _commands: Dictionary


func before_each() -> void:
	var root: RefCounted = FAKE_ROOT.new("11".repeat(32), 1)
	_identity_issuer = ISSUER.new()
	assert_true(_identity_issuer.configure(root).get("ok", false))
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = loaded.get("value", {}).get("registry")
	_commands = {}


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _identity_issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str(issued.get("value", {}).get("token", "")),
			"receipt": issued.get("value", {}).get("issuer_receipt", {}).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


func _record(action_id: String) -> Dictionary:
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	return found.get("value", {}).get("record", {})


func _open(script: Script, state: Dictionary, friend_id: String, day: int,
		label: String) -> Dictionary:
	var command := _command(label)
	var action_id := "group:priscilla_lavinia:day%d" % day \
		if str(state.get("group_action", {}).get("state", "")) in script.GROUP_OPEN_STATES \
		else "solo:%s:day%d" % [friend_id, day]
	return script.prepare_open_contact(state, friend_id, day, command["id"],
		command["receipt"], _identity_issuer, _record(action_id))


func _reply(script: Script, state: Dictionary, friend_id: String, day: int,
		label: String) -> Dictionary:
	var command := _command(label)
	var action_id := "group:priscilla_lavinia:day%d" % day \
		if str(state.get("group_action", {}).get("state", "")) in script.GROUP_OPEN_STATES \
		else "solo:%s:day%d" % [friend_id, day]
	return script.prepare_reply(state, friend_id, day, command["id"],
		command["receipt"], _identity_issuer, _record(action_id))

func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

func test_defaults_are_empty_and_valid() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	assert_not_null(state_script, "ContactInvitationState must exist")
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	assert_eq(state["messages"]["priscilla"], [])
	assert_eq(state["messages"]["lavinia"], [])
	assert_eq(state["messages"]["sylvia"], [])
	assert_eq(state["solo_actions"], {})
	assert_eq(state["transaction_receipts"], {})
	assert_eq(state["next_sequence"], 1)
	assert_null(state["group_action"]["action_id"])
	assert_null(state["group_action"]["day"])
	assert_true(state_script.validate_state(state).get("ok", false))

func test_solo_offer_returns_linked_candidate_batch_and_parent_receipt() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	assert_not_null(state_script, "ContactInvitationState must exist")
	if state_script == null:
		return
	var result: Dictionary = state_script.prepare_offer_solo(
		state_script.make_defaults(),
		"priscilla",
		1,
		"msg.solo.priscilla.day1",
		"tx.solo.p.d1"
	)
	assert_eq(_sorted_keys(result), ["code", "ok", "receipt", "value"])
	assert_true(result["ok"])
	assert_eq(_sorted_keys(result["value"]), ["candidate", "message_batch"])
	assert_eq(result["value"]["message_batch"].size(), 1)
	assert_eq(result["receipt"]["transaction_id"], "tx.solo.p.d1")
	assert_eq(result["receipt"]["action_id"], "solo:priscilla:day1")
	assert_eq(result["receipt"]["child_transaction_ids"], ["tx.solo.p.d1:message:0"])
	var candidate: Dictionary = result["value"]["candidate"]
	assert_eq(candidate["solo_actions"]["solo:priscilla:day1"]["offer_message_id"], "msg.solo.priscilla.day1")
	assert_eq(candidate["messages"]["priscilla"][0]["transaction_id"], "tx.solo.p.d1:message:0")
	assert_eq(candidate["transaction_receipts"]["tx.solo.p.d1"], result["receipt"])

func test_opening_solo_offer_marks_read_and_accepts_without_a_reply() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	assert_not_null(state_script, "ContactInvitationState must exist")
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	var offered: Dictionary = state_script.prepare_offer_solo(
		state, "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1"
	)
	assert_true(offered.get("ok", false))
	state = offered["value"]["candidate"]
	assert_eq(state_script.get_unread_count(state, "priscilla", 1), 1)
	var opened: Dictionary = _open(state_script, state, "priscilla", 1, "tx.open.p.d1")
	assert_true(opened.get("ok", false))
	state = opened["value"]["candidate"]
	assert_eq(state_script.get_unread_count(state, "priscilla", 1), 0)
	assert_false(state_script.is_reply_required(state, "priscilla"))
	assert_true(state_script.is_date_addable(state, "solo:priscilla:day1"))

func test_replying_solo_offer_is_rejected_as_not_required() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	state = state_script.prepare_offer_solo(state, "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	state = _open(state_script, state, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	var replied: Dictionary = _reply(state_script, state, "priscilla", 1, "tx.reply.p.d1")
	assert_false(replied.get("ok", true), "solo reply must not exist")
	assert_eq(replied.get("code"), &"solo_reply_not_required")
	assert_false(state_script.is_reply_required(state, "priscilla"))
	assert_true(state_script.is_date_addable(state, "solo:priscilla:day1"))

func test_reply_rejects_when_no_available_offer() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	if state_script == null:
		return
	var replied: Dictionary = _reply(state_script, state_script.make_defaults(), "priscilla", 1, "tx.reply.p.d1")
	assert_false(replied.get("ok", true), "reply with no offer must fail")

func test_prepare_does_not_mutate_input_state() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	state_script.prepare_offer_solo(state, "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")
	assert_eq((state["messages"]["priscilla"] as Array).size(), 0, "input state must be untouched (rollback by construction)")
	assert_eq(int(state["next_sequence"]), 1)

func test_duplicate_offer_transaction_is_idempotent() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	if state_script == null:
		return
	var first: Dictionary = state_script.prepare_offer_solo(state_script.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")
	var replay: Dictionary = state_script.prepare_offer_solo(first["value"]["candidate"], "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")
	assert_true(replay.get("ok", false))
	assert_eq((replay["value"]["candidate"]["messages"]["priscilla"] as Array).size(), 1, "replay appends nothing")
	assert_eq(replay["receipt"], first["receipt"], "replay returns the stored receipt")

func _script() -> Script:
	return load(CONTACT_STATE_PATH)

func test_resolve_unanswered_solo_queues_nevermind() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	assert_true(res.get("ok", false))
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_UNANSWERED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 1)
	assert_eq(res["value"]["message_batch"][0]["type"], "nevermind")
	assert_eq(int(res["value"]["message_batch"][0]["target_day"]), 2)
	assert_eq(res["receipt"]["kind"], "resolve_day_end")

func test_resolve_accepted_but_uncommitted_is_a_missed_question() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	st = _open(s, st, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_MISSED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 1)
	assert_eq(res["value"]["message_batch"][0]["type"], "missed_question")

func test_resolve_attended_solo_no_message() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	st = _open(s, st, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": ["solo:priscilla:day1"]}, "tx.resolve.d1")
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_ATTENDED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 0)

func test_resolve_accepted_but_absent_queues_missed_question() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	st = _open(s, st, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_MISSED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 1)
	assert_eq(res["value"]["message_batch"][0]["type"], "missed_question")
	assert_eq(int(res["value"]["message_batch"][0]["target_day"]), 2)

func test_resolve_day7_marks_run_end_no_message() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 7, "msg.solo.priscilla.day7", "tx.solo.p.d7")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 7, {"solo_attended_action_ids": []}, "tx.resolve.d7")
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day7"]["state"], "RESOLVED_RUN_END")
	assert_eq((res["value"]["message_batch"] as Array).size(), 0)

func test_resolve_is_idempotent() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	var first: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	var replay: Dictionary = s.prepare_resolve_day_end(first["value"]["candidate"], 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	assert_true(replay.get("ok", false))
	assert_eq(replay["receipt"], first["receipt"], "replayed resolve returns the stored receipt")
	assert_eq((replay["value"]["candidate"]["messages"]["priscilla"] as Array).size(), 2, "replay appends no duplicate beyond offer+nevermind")

func test_either_group_participant_can_reply_first() -> void:
	var s: Script = _script()
	if s == null:
		return
	var state: Dictionary = s.make_defaults()
	state = s.prepare_offer_solo(state, "priscilla", 2, "offer-p", "solo-p")["value"]["candidate"]
	state = s.prepare_offer_solo(state, "lavinia", 2, "offer-l", "solo-l")["value"]["candidate"]

	var activated: Dictionary = s.prepare_activate_group_after_round(state, 2, 2, 3, "group-day2")
	assert_true(activated.get("ok", false), "activation predicate must pass")
	state = activated["value"]["candidate"]
	assert_eq(state["group_action"]["action_id"], "group:priscilla_lavinia:day2")
	assert_eq(int(state["group_action"]["day"]), 2)
	assert_null(state["group_action"]["inviter_id"])
	assert_eq((s.get_contact_view(state, "priscilla", 2)["messages"] as Array).size(), 0, "no group text before first open; solo hidden")

	var opened: Dictionary = _open(s, state, "priscilla", 2, "open-group-priscilla")
	assert_true(opened.get("ok", false))
	state = opened["value"]["candidate"]
	assert_eq(state["group_action"]["inviter_id"], "priscilla")
	assert_eq(s.get_unread_count(state, "priscilla", 2), 0)
	assert_eq(s.get_unread_count(state, "lavinia", 2), 1)

	var replied: Dictionary = _reply(s, state, "lavinia", 2, "reply-lavinia")
	assert_true(replied.get("ok", false), "the non-inviter may reply first")
	state = replied["value"]["candidate"]
	assert_true(s.is_date_addable(state, "group:priscilla_lavinia:day2"))

func test_group_activation_rejected_when_a_solo_missing() -> void:
	var s: Script = _script()
	if s == null:
		return
	var state: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 2, "offer-p", "solo-p")["value"]["candidate"]
	# Only priscilla offered; lavinia has no AVAILABLE solo -> predicate fails, nothing changes.
	var activated: Dictionary = s.prepare_activate_group_after_round(state, 2, 2, 3, "group-day2")
	assert_false(activated.get("ok", true), "activation must fail without both solos")

func test_group_second_open_and_second_reply() -> void:
	var s: Script = _script()
	if s == null:
		return
	var state: Dictionary = s.make_defaults()
	state = s.prepare_offer_solo(state, "priscilla", 2, "offer-p", "solo-p")["value"]["candidate"]
	state = s.prepare_offer_solo(state, "lavinia", 2, "offer-l", "solo-l")["value"]["candidate"]
	state = s.prepare_activate_group_after_round(state, 2, 2, 3, "group-day2")["value"]["candidate"]
	state = _open(s, state, "priscilla", 2, "open-p")["value"]["candidate"]
	var second_open: Dictionary = _open(s, state, "lavinia", 2, "open-l")
	assert_true(second_open.get("ok", false))
	state = second_open["value"]["candidate"]
	assert_eq(s.get_unread_count(state, "lavinia", 2), 0, "second open advances lavinia's watermark")
	assert_eq(second_open["receipt"]["kind"], "open_group_second")
	assert_eq((second_open["receipt"]["child_transaction_ids"] as Array).size(), 0, "second open appends no records")
	state = _reply(s, state, "priscilla", 2, "reply-p")["value"]["candidate"]
	var second_reply: Dictionary = _reply(s, state, "lavinia", 2, "reply-l")
	assert_false(second_reply.get("ok", true), "only the first group reply is accepted")
	assert_eq((state["group_action"]["replied_ids"] as Array), ["priscilla"])
	assert_eq(state["group_action"]["state"], "ACCEPTED")

func _activated_group_day2(s: Script) -> Dictionary:
	var st: Dictionary = s.make_defaults()
	st = s.prepare_offer_solo(st, "priscilla", 2, "offer-p", "solo-p")["value"]["candidate"]
	st = s.prepare_offer_solo(st, "lavinia", 2, "offer-l", "solo-l")["value"]["candidate"]
	return s.prepare_activate_group_after_round(st, 2, 2, 3, "group-day2")["value"]["candidate"]

func _att(outcome: String, scheduled: Variant, route: Variant) -> Dictionary:
	return {"solo_attended_action_ids": [], "scheduled_group_action_id": scheduled, "group_route_receipt_id": route, "group_outcome": outcome}

func test_group_untouched_resolves_unanswered_with_busy() -> void:
	var s: Script = _script()
	if s == null:
		return
	var res: Dictionary = s.prepare_resolve_day_end(_activated_group_day2(s), 2, _att("not_scheduled", null, null), "tx.resolve.d2")
	assert_true(res.get("ok", false))
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_UNANSWERED")
	var batch: Array = res["value"]["message_batch"]
	assert_eq(batch.size(), 2)
	assert_eq(batch[0]["type"], "busy")
	assert_eq(batch[1]["type"], "busy")
	assert_eq(int(batch[0]["target_day"]), 3)

func test_group_opened_unanswered_resolves_nevermind() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = _open(s, st, "priscilla", 2, "open-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("not_scheduled", null, null), "tx.resolve.d2")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_UNANSWERED")
	var batch: Array = res["value"]["message_batch"]
	assert_eq(batch.size(), 2)
	assert_eq(batch[0]["type"], "nevermind")
	assert_eq(batch[1]["type"], "nevermind")

func test_group_one_reply_attended_judges_unreplied() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = _open(s, st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = _reply(s, st, "priscilla", 2, "reply-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("attended", "group:priscilla_lavinia:day2", "route.group.day2:completed"), "tx.resolve.d2")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_ATTENDED")
	assert_eq(res["receipt"]["group_date_variation"], "judgmental")
	var batch: Array = res["value"]["message_batch"]
	assert_eq(batch.size(), 1)
	assert_eq(batch[0]["type"], "judge")
	assert_eq(batch[0]["message_id"], "judge:lavinia:day3")

func test_group_accepted_not_attended_misses_and_defers_twofriends() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = _open(s, st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = _reply(s, st, "priscilla", 2, "reply-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("not_attended", "group:priscilla_lavinia:day2", "route.group.day2:cancelled"), "tx.resolve.d2")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_MISSED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 2)
	assert_eq(res["value"]["message_batch"][0]["type"], "missed_question")
	assert_eq(res["receipt"]["date_outcome_ids"], ["date.group.priscilla_lavinia.missed.day2"])
	assert_eq(res["receipt"]["deferred_twofriends"], {"route_id": "dating", "action_id": "group:priscilla_lavinia:day2", "after_hospital": false})

func test_group_ordinary_miss_reasons_keep_their_two_questions() -> void:
	var s: Script = _script()
	for outcome: String in ["not_scheduled", "not_attended"]:
		var state: Dictionary = _activated_group_day2(s)
		state = _open(s, state, "priscilla", 2, "ordinary-%s-open" % outcome)["value"]["candidate"]
		state = _reply(s, state, "priscilla", 2, "ordinary-%s-reply" % outcome)["value"]["candidate"]
		var resolved: Dictionary = s.prepare_resolve_day_end(
			state, 2, _att(outcome, "group:priscilla_lavinia:day2",
			"route.group.day2:%s" % outcome), "resolve.group.%s.day2" % outcome)
		assert_true(resolved.get("ok", false), str(resolved))
		assert_eq((resolved["value"]["message_batch"] as Array).size(), 2,
			"%s remains an ordinary group miss" % outcome)
		for message: Dictionary in resolved["value"]["message_batch"]:
			assert_eq(message["type"], "missed_question")
		assert_eq(resolved["receipt"]["deferred_twofriends"]["after_hospital"], false)

func test_group_hospital_supersession_defers_without_generic_missed_question() -> void:
	var s: Script = _script()
	var state: Dictionary = _activated_group_day2(s)
	state = _open(s, state, "priscilla", 2, "hospital-group-open")["value"]["candidate"]
	state = _reply(s, state, "priscilla", 2, "hospital-group-reply")["value"]["candidate"]
	var resolved: Dictionary = s.prepare_resolve_day_end(
		state, 2, _att("prevented_by_fainting", "group:priscilla_lavinia:day2",
		"route.group.day2:hospital"), "resolve.group.hospital.day2")
	assert_true(resolved.get("ok", false), str(resolved))
	assert_eq(resolved["value"]["candidate"]["group_action"]["state"], "RESOLVED_MISSED")
	assert_eq(resolved["receipt"]["deferred_twofriends"], {
		"route_id": "dating",
		"action_id": "group:priscilla_lavinia:day2",
		"after_hospital": true,
	})
	var message_types: Array = []
	for message: Dictionary in resolved["value"]["message_batch"]:
		message_types.append(message["type"])
	assert_false("missed_question" in message_types,
		"RED fix2: Hospital owns its distinct miss; Contacts cannot enqueue a generic duplicate")
	assert_eq(resolved["value"]["message_batch"], [],
		"Hospital supersession appends no ordinary group-miss messages")

func test_group_day7_forces_run_end() -> void:
	var s: Script = _script()
	if s == null:
		return
	var res: Dictionary = s.prepare_resolve_day_end(_activated_group_day2(s), 7, _att("not_scheduled", null, null), "tx.resolve.d7")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_RUN_END")
	assert_eq((res["value"]["message_batch"] as Array).size(), 0)

func test_pl_window_group_attended_counts_once() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = _open(s, st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = _reply(s, st, "priscilla", 2, "reply-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("attended", "group:priscilla_lavinia:day2", "route.group.day2:completed"), "tx.resolve.d2")
	assert_eq(res["receipt"]["pl_window"]["outcome"], "group")
	assert_eq(res["receipt"]["counter_deltas"], {"pl_window_counts.priscilla_lavinia": 1})

func test_pl_window_accepted_missed_counts_once() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = _open(s, st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = _reply(s, st, "priscilla", 2, "reply-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("not_attended", "group:priscilla_lavinia:day2", "route.group.day2:cancelled"), "tx.resolve.d2")
	assert_eq(res["receipt"]["pl_window"]["outcome"], "missed")
	assert_eq(res["receipt"]["counter_deltas"], {"pl_window_counts.priscilla_lavinia": 1})

func test_pl_window_both_unread_is_private_visible_counts() -> void:
	var s: Script = _script()
	if s == null:
		return
	var res: Dictionary = s.prepare_resolve_day_end(_activated_group_day2(s), 2, _att("not_scheduled", null, null), "tx.resolve.d2")
	assert_eq(res["receipt"]["pl_window"]["outcome"], "private_visible")
	assert_true(res["receipt"]["pl_window"]["visible"])
	assert_eq(res["receipt"]["counter_deltas"], {"pl_window_counts.priscilla_lavinia": 1})

func test_pl_window_never_activated_is_private_offscreen_counts() -> void:
	var s: Script = _script()
	if s == null:
		return
	# Solos offered on the window day but the group never activates and neither is dated.
	var st: Dictionary = s.make_defaults()
	st = s.prepare_offer_solo(st, "priscilla", 2, "offer-p", "solo-p")["value"]["candidate"]
	st = s.prepare_offer_solo(st, "lavinia", 2, "offer-l", "solo-l")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("not_scheduled", null, null), "tx.resolve.d2")
	assert_eq(res["receipt"]["pl_window"]["outcome"], "private_offscreen")
	assert_false(res["receipt"]["pl_window"]["visible"])
	assert_eq(res["receipt"]["counter_deltas"], {"pl_window_counts.priscilla_lavinia": 1})

func test_pl_window_solo_dated_one_is_prevented_no_count() -> void:
	var s: Script = _script()
	if s == null:
		return
	# Priscilla's solo is replied+attended, so the group cannot activate: window prevented.
	var st: Dictionary = s.make_defaults()
	st = s.prepare_offer_solo(st, "priscilla", 2, "offer-p", "solo-p")["value"]["candidate"]
	st = s.prepare_offer_solo(st, "lavinia", 2, "offer-l", "solo-l")["value"]["candidate"]
	st = _open(s, st, "priscilla", 2, "open-p")["value"]["candidate"]
	var att: Dictionary = _att("not_scheduled", null, null)
	att["solo_attended_action_ids"] = ["solo:priscilla:day2"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, att, "tx.resolve.d2")
	assert_eq(res["receipt"]["pl_window"]["outcome"], "prevented")
	assert_eq(res["receipt"]["counter_deltas"], {})

func test_solo_day_has_no_pl_window() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "sylvia", 1, "offer-syl", "solo-syl")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	assert_null(res["receipt"]["pl_window"])
	assert_eq(res["receipt"]["counter_deltas"], {})


func test_validate_state_rejects_recursive_task3_union_tampers() -> void:
	var s: Script = _script()
	var state := _complete_task3_union_state(s)
	assert_true(s.validate_state(state).get("ok", false), "the genuine complete Task-3 union is valid")
	var cases: Array[Dictionary] = []

	var messages_reversed: Array = state["messages"]["priscilla"].duplicate(true)
	messages_reversed.reverse()
	for entry: Dictionary in [
		{"name": "messages extra friend", "path": ["messages", "intruder"], "value": []},
		{"name": "messages missing friend", "path": ["messages", "sylvia"], "erase": true},
		{"name": "message extra member", "path": ["messages", "sylvia", 0, "unexpected"], "value": true},
		{"name": "message missing member", "path": ["messages", "sylvia", 0, "variant"], "erase": true},
		{"name": "message sequence integral float", "path": ["messages", "sylvia", 0, "sequence"], "value": 1.0},
		{"name": "message type enum", "path": ["messages", "sylvia", 0, "type"], "value": "invented"},
		{"name": "message target day integral float", "path": ["messages", "sylvia", 0, "target_day"], "value": 1.0},
		{"name": "message parameters primitive", "path": ["messages", "sylvia", 0, "parameters"], "value": []},
		{"name": "message visibility enum", "path": ["messages", "sylvia", 0, "visibility"], "value": "invented"},
		{"name": "message transaction wrong type", "path": ["messages", "sylvia", 0, "transaction_id"], "value": 1},
		{"name": "message sequence order", "path": ["messages", "priscilla"], "value": messages_reversed},
		{"name": "watermarks extra friend", "path": ["read_watermarks", "intruder"], "value": 0},
		{"name": "watermarks missing friend", "path": ["read_watermarks", "lavinia"], "erase": true},
		{"name": "watermark integral float", "path": ["read_watermarks", "priscilla"], "value": 1.0},
		{"name": "watermark negative", "path": ["read_watermarks", "priscilla"], "value": -1},
		{"name": "solo action extra member", "path": ["solo_actions", "solo:sylvia:day1", "unexpected"], "value": true},
		{"name": "solo action missing member", "path": ["solo_actions", "solo:sylvia:day1", "offer_message_id"], "erase": true},
		{"name": "solo action id StringName", "path": ["solo_actions", "solo:sylvia:day1", "action_id"], "value": &"solo:sylvia:day1"},
		{"name": "solo friend enum", "path": ["solo_actions", "solo:sylvia:day1", "friend_id"], "value": "intruder"},
		{"name": "solo day integral float", "path": ["solo_actions", "solo:sylvia:day1", "day"], "value": 1.0},
		{"name": "solo state enum", "path": ["solo_actions", "solo:sylvia:day1", "state"], "value": "invented"},
		{"name": "solo offer id type", "path": ["solo_actions", "solo:sylvia:day1", "offer_message_id"], "value": null},
		{"name": "solo reply id type", "path": ["solo_actions", "solo:sylvia:day1", "reply_transaction_id"], "value": 1},
		{"name": "solo transaction blank", "path": ["solo_actions", "solo:sylvia:day1", "transaction_id"], "value": ""},
		{"name": "group extra member", "path": ["group_action", "unexpected"], "value": true},
		{"name": "group missing member", "path": ["group_action", "history_generated"], "erase": true},
		{"name": "group state enum", "path": ["group_action", "state"], "value": "invented"},
		{"name": "group action id StringName", "path": ["group_action", "action_id"], "value": &"group:priscilla_lavinia:day2"},
		{"name": "group day integral float", "path": ["group_action", "day"], "value": 2.0},
		{"name": "group participants order", "path": ["group_action", "participant_ids"], "value": ["lavinia", "priscilla"]},
		{"name": "group inviter enum", "path": ["group_action", "inviter_id"], "value": "sylvia"},
		{"name": "group opened order", "path": ["group_action", "opened_ids"], "value": ["lavinia", "priscilla"]},
		{"name": "group replied enum", "path": ["group_action", "replied_ids"], "value": ["sylvia"]},
		{"name": "group history bool type", "path": ["group_action", "history_generated"], "value": 1},
		{"name": "group transaction type", "path": ["group_action", "transaction_id"], "value": null},
	]:
		cases.append({"name": entry["name"], "state": _mutated_state(
			state, entry["path"], entry.get("value"), entry.get("erase", false))})

	var operation_ids: Dictionary = _operation_ids_by_kind(state)
	for transaction_id: Variant in state["transaction_receipts"]:
		var receipt: Dictionary = state["transaction_receipts"][transaction_id]
		cases.append({"name": "%s extra member" % receipt["kind"], "state": _mutated_state(
			state, ["transaction_receipts", transaction_id, "unexpected"], true)})
		cases.append({"name": "%s missing transaction id" % receipt["kind"], "state": _mutated_state(
			state, ["transaction_receipts", transaction_id, "transaction_id"], null, true)})
		cases.append({"name": "%s kind StringName" % receipt["kind"], "state": _mutated_state(
			state, ["transaction_receipts", transaction_id, "kind"], StringName(receipt["kind"]))})

	for entry: Dictionary in [
		{"name": "offer child id array item type", "kind": "offer_solo", "path": ["child_transaction_ids", 0], "value": 1},
		{"name": "activation supersession order", "kind": "activate_group", "path": ["superseded_action_ids"], "value": ["solo:lavinia:day2", "solo:priscilla:day2"]},
		{"name": "solo-open watermark float", "kind": "open_solo_acceptance", "path": ["prior_watermark"], "value": 0.0},
		{"name": "group-first message sequence float", "kind": "open_group_first", "path": ["message_sequences", 0], "value": 1.0},
		{"name": "group-second command receipt widened", "kind": "open_group_second", "path": ["command_issuer_receipt", "unexpected"], "value": true},
		{"name": "group-reply transition enum", "kind": "reply_group", "path": ["from_state"], "value": "AVAILABLE"},
		{"name": "resolve transition widened", "kind": "resolve_day_end", "path": ["state_transitions", 0, "unexpected"], "value": true},
		{"name": "resolve child id item type", "kind": "resolve_day_end", "path": ["child_transaction_ids", 0], "value": 1},
		{"name": "resolve group variation enum", "kind": "resolve_day_end", "path": ["group_date_variation"], "value": "invented"},
		{"name": "resolve deferred primitive", "kind": "resolve_day_end", "path": ["deferred_twofriends", "after_hospital"], "value": 0},
		{"name": "resolve PL window widened", "kind": "resolve_day_end", "path": ["pl_window", "unexpected"], "value": true},
		{"name": "resolve counter integral float", "kind": "resolve_day_end", "path": ["counter_deltas", "pl_window_counts.priscilla_lavinia"], "value": 1.0},
	]:
		var operation_id: String = operation_ids[entry["kind"]]
		var path: Array = ["transaction_receipts", operation_id]
		path.append_array(entry["path"])
		cases.append({"name": entry["name"], "state": _mutated_state(state, path, entry["value"])})

	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		assert_false(s.validate_state(entry["state"]).get("ok", true),
			"RED recursive Contacts primitive: %s" % entry["name"])
		assert_eq(entry["state"], before, "state validation is pure: %s" % entry["name"])


func test_validate_state_accepts_every_genuine_task3_transition_variant() -> void:
	var s: Script = _script()
	var states: Array[Dictionary] = [s.make_defaults()]
	var solo: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "offer-priscilla", "offer.priscilla.day1")["value"]["candidate"]
	states.append(solo.duplicate(true))
	solo = _open(s, solo, "priscilla", 1, "positive-solo-open")["value"]["candidate"]
	states.append(solo.duplicate(true))
	solo = s.prepare_resolve_day_end(
		solo, 1, {"solo_attended_action_ids": []}, "resolve.solo.day1")["value"]["candidate"]
	states.append(solo.duplicate(true))

	var group: Dictionary = s.make_defaults()
	group = s.prepare_offer_solo(group, "priscilla", 2, "offer-p", "offer.p.day2")["value"]["candidate"]
	group = s.prepare_offer_solo(group, "lavinia", 2, "offer-l", "offer.l.day2")["value"]["candidate"]
	group = s.prepare_activate_group_after_round(group, 2, 2, 3, "activate.group.day2")["value"]["candidate"]
	states.append(group.duplicate(true))
	group = _open(s, group, "priscilla", 2, "positive-group-first")["value"]["candidate"]
	states.append(group.duplicate(true))
	group = _open(s, group, "lavinia", 2, "positive-group-second")["value"]["candidate"]
	states.append(group.duplicate(true))
	group = _reply(s, group, "lavinia", 2, "positive-group-reply")["value"]["candidate"]
	states.append(group.duplicate(true))
	group = s.prepare_resolve_day_end(
		group, 2, _att("not_scheduled", null, null), "resolve.positive.group.day2")["value"]["candidate"]
	states.append(group.duplicate(true))

	var day7: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "offer-sylvia-day7", "offer.sylvia.day7")["value"]["candidate"]
	day7 = _open(s, day7, "sylvia", 7, "positive-day7-open")["value"]["candidate"]
	states.append(day7.duplicate(true))
	day7 = s.prepare_resolve_day_end(
		day7, 7, {"solo_attended_action_ids": []}, "resolve.sylvia.day7")["value"]["candidate"]
	states.append(day7.duplicate(true))

	for index: int in range(states.size()):
		assert_true(s.validate_state(states[index]).get("ok", false),
			"genuine Task-3 transition state %d must validate" % index)


func test_validate_state_enforces_offer_visibility_and_watermark_by_solo_lineage() -> void:
	var s: Script = _script()
	var available: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "visibility-available", "offer.visibility.available")["value"]["candidate"]
	var advanced: Dictionary = available.duplicate(true)
	advanced["read_watermarks"]["priscilla"] = advanced["messages"]["priscilla"][0]["sequence"]
	var accepted: Dictionary = _open(s, available, "priscilla", 1,
		"open.visibility.accepted")["value"]["candidate"]
	var accepted_hidden: Dictionary = accepted.duplicate(true)
	accepted_hidden["messages"]["priscilla"][0]["visibility"] = "superseded_hidden"
	var superseded: Dictionary = _activated_group_day2(s)
	var superseded_visible: Dictionary = superseded.duplicate(true)
	superseded_visible["messages"]["priscilla"][0]["visibility"] = "visible"
	for entry: Dictionary in [
		{"name": "AVAILABLE offer watermark already covers the offer", "state": advanced},
		{"name": "accepted offer is hidden as if superseded", "state": accepted_hidden},
		{"name": "superseded offer remains visible", "state": superseded_visible},
	]:
		var before: Dictionary = entry["state"].duplicate(true)
		assert_false(s.validate_state(entry["state"]).get("ok", true),
			"RED fix3: %s" % entry["name"])
		assert_eq(entry["state"], before, "visibility/watermark validation remains pure")
	var accepted_resolved: Dictionary = s.prepare_resolve_day_end(accepted, 1,
		{"solo_attended_action_ids": []}, "resolve.visibility.accepted")["value"]["candidate"]
	var day7: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "visibility-day7", "offer.visibility.day7")["value"]["candidate"]
	day7 = _open(s, day7, "sylvia", 7, "open.visibility.day7")["value"]["candidate"]
	day7 = s.prepare_resolve_day_end(day7, 7,
		{"solo_attended_action_ids": []}, "resolve.visibility.day7")["value"]["candidate"]
	for legal: Dictionary in [accepted, accepted_resolved, day7, superseded]:
		assert_true(s.validate_state(legal).get("ok", false),
			"legal accepted/resolved/Day7/superseded lineage remains valid")


func test_validate_state_requires_one_exact_canonical_resolution_envelope() -> void:
	var s: Script = _script()
	var states: Dictionary = _fix3_resolution_states(s)
	for name: String in states:
		assert_true(s.validate_state(states[name]["state"]).get("ok", false),
			"genuine resolution envelope remains legal: %s" % name)
	var cases: Array[Dictionary] = []
	var missing_solo_transition: Dictionary = states["solo_unanswered"]["state"].duplicate(true)
	missing_solo_transition["transaction_receipts"][states["solo_unanswered"]["tx"]]["state_transitions"].clear()
	cases.append({"name": "missing required solo transition", "state": missing_solo_transition})
	var missing_group_transition: Dictionary = states["group_hospital"]["state"].duplicate(true)
	missing_group_transition["transaction_receipts"][states["group_hospital"]["tx"]]["state_transitions"].clear()
	cases.append({"name": "missing required Hospital group transition", "state": missing_group_transition})
	for variant: String in ["day7_unaccepted", "day7_accepted"]:
		var missing_day7: Dictionary = states[variant]["state"].duplicate(true)
		missing_day7["transaction_receipts"][states[variant]["tx"]]["state_transitions"].clear()
		cases.append({"name": "missing %s transition" % variant, "state": missing_day7})
	var added_transition: Dictionary = states["solo_attended"]["state"].duplicate(true)
	added_transition["transaction_receipts"][states["solo_attended"]["tx"]]["state_transitions"].append({
		"action_id": "solo:sylvia:day1", "from_state": "AVAILABLE",
		"to_state": "RESOLVED_UNANSWERED",
	})
	cases.append({"name": "added valid-typed transition", "state": added_transition})
	var swapped_transitions: Dictionary = states["two_solo_unanswered"]["state"].duplicate(true)
	var transitions: Array = swapped_transitions["transaction_receipts"][states["two_solo_unanswered"]["tx"]]["state_transitions"]
	var first_transition: Variant = transitions[0]
	transitions[0] = transitions[1]
	transitions[1] = first_transition
	cases.append({"name": "reversed canonical transition order", "state": swapped_transitions})
	for mutation: Dictionary in [
		{"name": "resolution message type", "key": "type", "value": "nevermind"},
		{"name": "resolution message visibility", "key": "visibility", "value": "superseded_hidden"},
		{"name": "resolution message target", "key": "target_day", "value": 1},
	]:
		cases.append({"name": mutation["name"], "state": _mutate_resolution_message(
			states["solo_missed"]["state"], states["solo_missed"]["tx"],
			mutation["key"], mutation["value"])})
	cases.append({"name": "opened-group resolution message substitution",
		"state": _mutate_resolution_message(states["group_opened_unanswered"]["state"],
			states["group_opened_unanswered"]["tx"], "type", "busy")})
	var wrong_ownership: Dictionary = _mutate_resolution_message(
		states["solo_missed"]["state"], states["solo_missed"]["tx"],
		"transaction_id", "another-resolution:message:0")
	cases.append({"name": "resolution message ownership", "state": wrong_ownership})
	var ordinary_as_hospital: Dictionary = states["group_missed"]["state"].duplicate(true)
	ordinary_as_hospital["transaction_receipts"][states["group_missed"]["tx"]]["deferred_twofriends"]["after_hospital"] = true
	cases.append({"name": "ordinary group miss claims Hospital", "state": ordinary_as_hospital})
	var hospital_as_ordinary: Dictionary = states["group_hospital"]["state"].duplicate(true)
	hospital_as_ordinary["transaction_receipts"][states["group_hospital"]["tx"]]["deferred_twofriends"]["after_hospital"] = false
	cases.append({"name": "Hospital group miss claims ordinary", "state": hospital_as_ordinary})
	var unowned_ordinary_messages: Dictionary = states["group_missed"]["state"].duplicate(true)
	for key: String in ["child_transaction_ids", "message_ids", "message_sequences"]:
		unowned_ordinary_messages["transaction_receipts"][states["group_missed"]["tx"]][key] = []
	cases.append({"name": "ordinary messages removed from receipt only", "state": unowned_ordinary_messages})
	var wrong_variation: Dictionary = states["group_attended"]["state"].duplicate(true)
	wrong_variation["transaction_receipts"][states["group_attended"]["tx"]]["group_date_variation"] = "normal"
	cases.append({"name": "group attended variation", "state": wrong_variation})
	var missing_outcome: Dictionary = states["group_missed"]["state"].duplicate(true)
	missing_outcome["transaction_receipts"][states["group_missed"]["tx"]]["date_outcome_ids"] = []
	cases.append({"name": "group miss date outcome", "state": missing_outcome})
	var wrong_window: Dictionary = states["group_missed"]["state"].duplicate(true)
	wrong_window["transaction_receipts"][states["group_missed"]["tx"]]["pl_window"]["outcome"] = "group"
	cases.append({"name": "PL-window projection", "state": wrong_window})
	var wrong_counter: Dictionary = states["group_missed"]["state"].duplicate(true)
	wrong_counter["transaction_receipts"][states["group_missed"]["tx"]]["counter_deltas"]["pl_window_counts.priscilla_lavinia"] = 2
	cases.append({"name": "PL-window counter", "state": wrong_counter})
	cases.append({"name": "extra unowned resolution message", "state": _append_extra_resolution_message(
		states["group_missed"]["state"], states["group_missed"]["tx"], 3)})
	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		assert_false(s.validate_state(entry["state"]).get("ok", true),
			"RED fix3 resolution envelope: %s" % entry["name"])
		assert_eq(entry["state"], before, "resolution envelope validation remains pure")


func _fix3_resolution_states(s: Script) -> Dictionary:
	var found: Dictionary = {}
	var solo_unanswered: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "fix3-unanswered", "offer.fix3.unanswered")["value"]["candidate"]
	found["solo_unanswered"] = _resolution_entry(s.prepare_resolve_day_end(
		solo_unanswered, 1, {"solo_attended_action_ids": []}, "resolve.fix3.solo.unanswered"))
	var solo_missed: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "fix3-missed", "offer.fix3.missed")["value"]["candidate"]
	solo_missed = _open(s, solo_missed, "priscilla", 1, "open.fix3.missed")["value"]["candidate"]
	found["solo_missed"] = _resolution_entry(s.prepare_resolve_day_end(
		solo_missed, 1, {"solo_attended_action_ids": []}, "resolve.fix3.solo.missed"))
	var solo_attended: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "fix3-attended", "offer.fix3.attended")["value"]["candidate"]
	solo_attended = _open(s, solo_attended, "priscilla", 1, "open.fix3.attended")["value"]["candidate"]
	found["solo_attended"] = _resolution_entry(s.prepare_resolve_day_end(solo_attended, 1,
		{"solo_attended_action_ids": ["solo:priscilla:day1"]}, "resolve.fix3.solo.attended"))
	var two_solo: Dictionary = s.make_defaults()
	two_solo = s.prepare_offer_solo(two_solo, "priscilla", 1,
		"fix3-two-priscilla", "offer.fix3.two.priscilla")["value"]["candidate"]
	two_solo = s.prepare_offer_solo(two_solo, "sylvia", 1,
		"fix3-two-sylvia", "offer.fix3.two.sylvia")["value"]["candidate"]
	found["two_solo_unanswered"] = _resolution_entry(s.prepare_resolve_day_end(
		two_solo, 1, {"solo_attended_action_ids": []}, "resolve.fix3.two.unanswered"))
	var group_unopened: Dictionary = _activated_group_day2(s)
	found["group_unopened"] = _resolution_entry(s.prepare_resolve_day_end(group_unopened, 2,
		_att("not_scheduled", null, null), "resolve.fix3.group.unopened"))
	var group_opened: Dictionary = _activated_group_day2(s)
	group_opened = _open(s, group_opened, "priscilla", 2,
		"open.fix3.group.unanswered")["value"]["candidate"]
	found["group_opened_unanswered"] = _resolution_entry(s.prepare_resolve_day_end(group_opened, 2,
		_att("not_scheduled", null, null), "resolve.fix3.group.opened"))
	for outcome: String in ["not_attended", "prevented_by_fainting", "attended"]:
		var group: Dictionary = _activated_group_day2(s)
		group = _open(s, group, "priscilla", 2, "open.fix3.group.%s" % outcome)["value"]["candidate"]
		group = _reply(s, group, "priscilla", 2, "reply.fix3.group.%s" % outcome)["value"]["candidate"]
		var key := "group_hospital" if outcome == "prevented_by_fainting" \
			else ("group_attended" if outcome == "attended" else "group_missed")
		found[key] = _resolution_entry(s.prepare_resolve_day_end(group, 2,
			_att(outcome, "group:priscilla_lavinia:day2", "route.fix3.group.%s" % outcome),
			"resolve.fix3.%s" % key))
	var day7_unaccepted: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "fix3-day7-unaccepted", "offer.fix3.day7.unaccepted")["value"]["candidate"]
	found["day7_unaccepted"] = _resolution_entry(s.prepare_resolve_day_end(day7_unaccepted, 7,
		{"solo_attended_action_ids": []}, "resolve.fix3.day7.unaccepted"))
	var day7_accepted: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "fix3-day7-accepted", "offer.fix3.day7.accepted")["value"]["candidate"]
	day7_accepted = _open(s, day7_accepted, "sylvia", 7,
		"open.fix3.day7.accepted")["value"]["candidate"]
	found["day7_accepted"] = _resolution_entry(s.prepare_resolve_day_end(day7_accepted, 7,
		{"solo_attended_action_ids": []}, "resolve.fix3.day7.accepted"))
	return found


func _resolution_entry(result: Dictionary) -> Dictionary:
	assert_true(result.get("ok", false), str(result))
	return {"state": result["value"]["candidate"], "tx": result["receipt"]["transaction_id"]}


func _mutate_resolution_message(state: Dictionary, transaction_id: String,
		key: String, value: Variant) -> Dictionary:
	var changed: Dictionary = state.duplicate(true)
	for friend_id: String in ["priscilla", "lavinia", "sylvia"]:
		for message: Dictionary in changed["messages"][friend_id]:
			if str(message["transaction_id"]).begins_with("%s:message:" % transaction_id):
				message[key] = value
				return changed
	return changed


func _append_extra_resolution_message(state: Dictionary, transaction_id: String,
		target_day: int) -> Dictionary:
	var changed: Dictionary = state.duplicate(true)
	var sequence: int = changed["next_sequence"]
	var receipt: Dictionary = changed["transaction_receipts"][transaction_id]
	var ordinal: int = receipt["child_transaction_ids"].size()
	changed["messages"]["sylvia"].append({
		"message_id": "busy:sylvia:day%d" % target_day,
		"sequence": sequence,
		"type": "busy",
		"variant": "default",
		"target_day": target_day,
		"parameters": {},
		"visibility": "visible",
		"transaction_id": "%s:message:%d" % [transaction_id, ordinal],
	})
	changed["next_sequence"] = sequence + 1
	return changed


func test_validate_state_rejects_valid_typed_resolve_history_tampers() -> void:
	var s: Script = _script()
	var state: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "resolve-offer", "resolve.offer.day1")["value"]["candidate"]
	state = _open(s, state, "priscilla", 1, "resolve-open-day1")["value"]["candidate"]
	state = s.prepare_resolve_day_end(
		state, 1, {"solo_attended_action_ids": []}, "resolve.history.day1")["value"]["candidate"]
	var transaction_id := "resolve.history.day1"
	var cases: Array[Dictionary] = []
	for entry: Dictionary in [
		{"name": "transition action", "path": ["transaction_receipts", transaction_id, "state_transitions", 0, "action_id"], "value": "solo:sylvia:day1"},
		{"name": "transition from enum", "path": ["transaction_receipts", transaction_id, "state_transitions", 0, "from_state"], "value": "SUPERSEDED"},
		{"name": "transition to enum", "path": ["transaction_receipts", transaction_id, "state_transitions", 0, "to_state"], "value": "RESOLVED_ATTENDED"},
		{"name": "resolve message id tuple", "path": ["transaction_receipts", transaction_id, "message_ids", 0], "value": "another-missed-message"},
		{"name": "resolve child transaction tuple", "path": ["transaction_receipts", transaction_id, "child_transaction_ids", 0], "value": "another:message:0"},
		{"name": "resolve message sequence tuple", "path": ["transaction_receipts", transaction_id, "message_sequences", 0], "value": 999},
	]:
		cases.append({"name": entry["name"], "state": _mutated_state(
			state, entry["path"], entry["value"])})
	for entry: Dictionary in cases:
		var before: Dictionary = entry["state"].duplicate(true)
		assert_false(s.validate_state(entry["state"]).get("ok", true),
			"RED fix2 resolve lineage: %s" % entry["name"])
		assert_eq(entry["state"], before, "resolve validation remains pure")


func test_validate_state_rejects_day7_prestates_that_disagree_with_retained_history() -> void:
	var s: Script = _script()
	var variants: Array[Dictionary] = []
	var solo_unaccepted: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "runend-unaccepted", "offer.runend.unaccepted")["value"]["candidate"]
	solo_unaccepted = s.prepare_resolve_day_end(solo_unaccepted, 7,
		{"solo_attended_action_ids": []}, "resolve.runend.unaccepted")["value"]["candidate"]
	variants.append({"name": "solo without acceptance", "state": solo_unaccepted,
		"transaction_id": "resolve.runend.unaccepted", "from_state": "ACCEPTED"})
	var solo_accepted: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "runend-accepted", "offer.runend.accepted")["value"]["candidate"]
	solo_accepted = _open(s, solo_accepted, "sylvia", 7,
		"open.runend.accepted")["value"]["candidate"]
	solo_accepted = s.prepare_resolve_day_end(solo_accepted, 7,
		{"solo_attended_action_ids": []}, "resolve.runend.accepted")["value"]["candidate"]
	variants.append({"name": "solo with acceptance", "state": solo_accepted,
		"transaction_id": "resolve.runend.accepted", "from_state": "AVAILABLE"})
	var group_unopened: Dictionary = _activated_group_day2(s)
	group_unopened = s.prepare_resolve_day_end(group_unopened, 7,
		_att("not_scheduled", null, null), "resolve.group.runend.unopened")["value"]["candidate"]
	variants.append({"name": "group unopened", "state": group_unopened,
		"transaction_id": "resolve.group.runend.unopened", "from_state": "ACCEPTED"})
	var group_opened: Dictionary = _activated_group_day2(s)
	group_opened = _open(s, group_opened, "priscilla", 2,
		"open.group.runend.unanswered")["value"]["candidate"]
	group_opened = s.prepare_resolve_day_end(group_opened, 7,
		_att("not_scheduled", null, null), "resolve.group.runend.opened")["value"]["candidate"]
	variants.append({"name": "group opened", "state": group_opened,
		"transaction_id": "resolve.group.runend.opened", "from_state": "AVAILABLE_UNOPENED"})
	var group_accepted: Dictionary = _activated_group_day2(s)
	group_accepted = _open(s, group_accepted, "priscilla", 2,
		"open.group.runend.replied")["value"]["candidate"]
	group_accepted = _reply(s, group_accepted, "priscilla", 2,
		"reply.group.runend.replied")["value"]["candidate"]
	group_accepted = s.prepare_resolve_day_end(group_accepted, 7,
		_att("not_scheduled", null, null), "resolve.group.runend.replied")["value"]["candidate"]
	variants.append({"name": "group accepted", "state": group_accepted,
		"transaction_id": "resolve.group.runend.replied", "from_state": "REPLY_REQUIRED"})
	for entry: Dictionary in variants:
		var changed := _mutated_state(entry["state"], ["transaction_receipts",
			entry["transaction_id"], "state_transitions", 0, "from_state"], entry["from_state"])
		var before: Dictionary = changed.duplicate(true)
		assert_false(s.validate_state(changed).get("ok", true),
			"RED fix2 Day7 prestate lineage: %s" % entry["name"])
		assert_eq(changed, before, "Day7 prestate validation remains pure")


func test_validate_state_preserves_every_legal_resolution_history_variant() -> void:
	var s: Script = _script()
	var variants: Array[Dictionary] = []
	var solo_unanswered: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "solo-unanswered", "offer.solo.unanswered")["value"]["candidate"]
	variants.append(s.prepare_resolve_day_end(solo_unanswered, 1,
		{"solo_attended_action_ids": []}, "resolve.solo.unanswered")["value"]["candidate"])
	var solo_attended: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "priscilla", 1, "solo-attended", "offer.solo.attended")["value"]["candidate"]
	solo_attended = _open(s, solo_attended, "priscilla", 1, "open.solo.attended")["value"]["candidate"]
	variants.append(s.prepare_resolve_day_end(solo_attended, 1,
		{"solo_attended_action_ids": ["solo:priscilla:day1"]}, "resolve.solo.attended")["value"]["candidate"])
	var solo_run_end: Dictionary = s.prepare_offer_solo(
		s.make_defaults(), "sylvia", 7, "solo-run-end", "offer.solo.runend")["value"]["candidate"]
	variants.append(s.prepare_resolve_day_end(solo_run_end, 7,
		{"solo_attended_action_ids": []}, "resolve.solo.runend.unaccepted")["value"]["candidate"])

	var group_unopened := _activated_group_day2(s)
	variants.append(s.prepare_resolve_day_end(group_unopened, 2,
		_att("not_scheduled", null, null), "resolve.group.unopened")["value"]["candidate"])
	var group_opened := _activated_group_day2(s)
	group_opened = _open(s, group_opened, "priscilla", 2, "open.group.unanswered")["value"]["candidate"]
	variants.append(s.prepare_resolve_day_end(group_opened, 2,
		_att("not_scheduled", null, null), "resolve.group.opened")["value"]["candidate"])
	var group_attended := _activated_group_day2(s)
	group_attended = _open(s, group_attended, "priscilla", 2, "open.group.attended")["value"]["candidate"]
	group_attended = _reply(s, group_attended, "priscilla", 2, "reply.group.attended")["value"]["candidate"]
	variants.append(s.prepare_resolve_day_end(group_attended, 2,
		_att("attended", "group:priscilla_lavinia:day2", "route.group.attended"),
		"resolve.group.attended")["value"]["candidate"])
	var group_run_end_unaccepted := _activated_group_day2(s)
	variants.append(s.prepare_resolve_day_end(group_run_end_unaccepted, 7,
		_att("not_scheduled", null, null), "resolve.group.runend.unaccepted")["value"]["candidate"])
	var group_run_end_accepted := _activated_group_day2(s)
	group_run_end_accepted = _open(s, group_run_end_accepted, "priscilla", 2,
		"open.group.runend.accepted")["value"]["candidate"]
	group_run_end_accepted = _reply(s, group_run_end_accepted, "priscilla", 2,
		"reply.group.runend.accepted")["value"]["candidate"]
	variants.append(s.prepare_resolve_day_end(group_run_end_accepted, 7,
		_att("not_scheduled", null, null), "resolve.group.runend.accepted")["value"]["candidate"])

	for index: int in range(variants.size()):
		assert_true(s.validate_state(variants[index]).get("ok", false),
			"legal resolution history variant %d remains valid" % index)


func _complete_task3_union_state(s: Script) -> Dictionary:
	var state: Dictionary = s.make_defaults()
	state = s.prepare_offer_solo(state, "sylvia", 1, "offer-sylvia", "offer.sylvia.day1")["value"]["candidate"]
	state = _open(s, state, "sylvia", 1, "open-sylvia-day1")["value"]["candidate"]
	state = s.prepare_offer_solo(state, "priscilla", 2, "offer-priscilla", "offer.priscilla.day2")["value"]["candidate"]
	state = s.prepare_offer_solo(state, "lavinia", 2, "offer-lavinia", "offer.lavinia.day2")["value"]["candidate"]
	state = s.prepare_activate_group_after_round(state, 2, 2, 3, "activate.group.day2")["value"]["candidate"]
	state = _open(s, state, "priscilla", 2, "open-group-priscilla")["value"]["candidate"]
	state = _open(s, state, "lavinia", 2, "open-group-lavinia")["value"]["candidate"]
	state = _reply(s, state, "priscilla", 2, "reply-group-priscilla")["value"]["candidate"]
	var resolved: Dictionary = s.prepare_resolve_day_end(
		state, 2, _att("not_scheduled", null, null), "resolve.group.day2")
	assert_true(resolved.get("ok", false), str(resolved))
	return resolved["value"]["candidate"]


func _operation_ids_by_kind(state: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for transaction_id: Variant in state["transaction_receipts"]:
		var kind := str(state["transaction_receipts"][transaction_id].get("kind", ""))
		if not found.has(kind):
			found[kind] = str(transaction_id)
	return found


func _mutated_state(state: Dictionary, path: Array, value: Variant, erase: bool = false) -> Dictionary:
	var changed: Dictionary = state.duplicate(true)
	var cursor: Variant = changed
	for index: int in range(path.size() - 1):
		if typeof(cursor) == TYPE_DICTIONARY:
			cursor = (cursor as Dictionary)[path[index]]
		else:
			cursor = (cursor as Array)[int(path[index])]
	var final_key: Variant = path[-1]
	if typeof(cursor) == TYPE_DICTIONARY:
		if erase:
			(cursor as Dictionary).erase(final_key)
		else:
			(cursor as Dictionary)[final_key] = value
	else:
		(cursor as Array)[int(final_key)] = value
	return changed


# ---- Task 7 Step 7.3: the Sylvia hospital witness handoff index (dwm-p2r.14) ----
#
# Task 3 RESERVED contacts.sylvia_hospital_witness_receipts and rejected any non-empty value.
# Task 7 opens it: the Hospital transaction commits the byte-identical witness here, and the index
# outlives the resolution plan so dwm-oyo.4 can consume it later. It is an append-only HANDOFF
# index, not a second gameplay ledger -- nothing here applies a relationship change.

const WITNESS_INDEX := "sylvia_hospital_witness_receipts"


func _witness_record(entry_id: String = "e-syl", day: int = 3) -> Dictionary:
	return {
		"kind": "sylvia_hospital_witness",
		"resolution_kind": "schedule_done",
		"schedule_entry_id": entry_id,
		"action_id": "solo:sylvia:day%d" % day,
		"source_receipt_id": "source." + entry_id,
		"hospital_miss_ordinal": 0,
		"care_followup_day": day + 1,
		"care_followup_entry_id": "care.sylvia.day%d" % (day + 1),
		"affection_delta": 2,
		"dark_delta": 1,
		"attitude": "fixated",
		"tier_transition": "advance_one_or_stay_love",
	}


func test_a_valid_sylvia_witness_record_is_accepted_by_the_opened_index() -> void:
	var state: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	state[WITNESS_INDEX]["witness.1"] = _witness_record()
	var result: Dictionary = load(CONTACT_STATE_PATH).validate_state(state)
	assert_true(result.get("ok", false),
		"Task 7 opens the reserved index for real witness records: " + JSON.stringify(result))


func test_the_witness_index_rejects_malformed_records() -> void:
	# A blank id, a wrong kind, a missing member, an extra member, and a wrong-typed delta all
	# fail closed. The index is a durable handoff, so a malformed record must never persist.
	var blank_id: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	blank_id[WITNESS_INDEX][""] = _witness_record()
	assert_false(load(CONTACT_STATE_PATH).validate_state(blank_id).get("ok", true), "blank receipt id rejects")

	var wrong_kind: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	var record: Dictionary = _witness_record()
	record["kind"] = "something_else"
	wrong_kind[WITNESS_INDEX]["witness.1"] = record
	assert_false(load(CONTACT_STATE_PATH).validate_state(wrong_kind).get("ok", true), "wrong kind rejects")

	var missing: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	var short_record: Dictionary = _witness_record()
	short_record.erase("care_followup_entry_id")
	missing[WITNESS_INDEX]["witness.1"] = short_record
	assert_false(load(CONTACT_STATE_PATH).validate_state(missing).get("ok", true), "a missing member rejects")

	var extra: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	var wide_record: Dictionary = _witness_record()
	wide_record["applied"] = true
	extra[WITNESS_INDEX]["witness.1"] = wide_record
	assert_false(load(CONTACT_STATE_PATH).validate_state(extra).get("ok", true),
		"an extra member rejects; the record is exact-key")

	var bad_delta: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	var delta_record: Dictionary = _witness_record()
	delta_record["affection_delta"] = "2"
	bad_delta[WITNESS_INDEX]["witness.1"] = delta_record
	assert_false(load(CONTACT_STATE_PATH).validate_state(bad_delta).get("ok", true),
		"a coerced delta rejects; deltas are strict ints")


func test_the_witness_index_only_accepts_the_schedule_done_resolution_kind() -> void:
	# Plan 01 writes ONLY the Schedule-Done witness. Plan 03's condition-Hospital flow owns its own
	# ancestry and must not reach this index through a Plan-01 shaped record.
	var state: Dictionary = load(CONTACT_STATE_PATH).make_defaults()
	var record: Dictionary = _witness_record()
	record["resolution_kind"] = "condition_hospital"
	state[WITNESS_INDEX]["witness.1"] = record
	assert_false(load(CONTACT_STATE_PATH).validate_state(state).get("ok", true),
		"Plan 01 never persists a condition-Hospital witness here")


## dwm-pm4. One canonical roster, owned here; DataCatalog and the GameState autoload are
## aliases. This pin is what turns silent drift between the three surfaces into a red test --
## the gap the bead was filed about.
func test_the_friend_roster_has_one_owner_and_two_aliases() -> void:
	assert_eq(DATA_CATALOG.FRIEND_IDS, CONTACT_STATE.FRIEND_IDS,
		"DataCatalog serves exactly the domain-owned roster")
	assert_eq(GameState.FRIEND_IDS, CONTACT_STATE.FRIEND_IDS,
		"and so does the GameState autoload")
