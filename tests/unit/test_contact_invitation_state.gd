extends "res://addons/gut/test.gd"

# Stateless ContactInvitationState (dwm-p2r.6, plan-04 Task 1). Supersedes the
# stateful RefCounted suite; see docs/superpowers/plans/2026-07-22-phase-2r-06-contacts-stateless-reconciliation.md

const CONTACT_STATE_PATH := "res://scripts/domain/contact/ContactInvitationState.gd"

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

func test_opening_solo_offer_marks_read_without_answering() -> void:
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
	var opened: Dictionary = state_script.prepare_open_contact(
		state, "priscilla", 1, "tx.open.p.d1"
	)
	assert_true(opened.get("ok", false))
	state = opened["value"]["candidate"]
	assert_eq(state_script.get_unread_count(state, "priscilla", 1), 0)
	assert_true(state_script.is_reply_required(state, "priscilla"))
	assert_false(state_script.is_date_addable(state, "solo:priscilla:day1"))

func test_replying_solo_offer_accepts_and_makes_date_addable() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	if state_script == null:
		return
	var state: Dictionary = state_script.make_defaults()
	state = state_script.prepare_offer_solo(state, "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	state = state_script.prepare_open_contact(state, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	var replied: Dictionary = state_script.prepare_reply(state, "priscilla", 1, "tx.reply.p.d1")
	assert_true(replied.get("ok", false), "reply must succeed on an AVAILABLE offer")
	state = replied["value"]["candidate"]
	assert_false(state_script.is_reply_required(state, "priscilla"))
	assert_true(state_script.is_date_addable(state, "solo:priscilla:day1"))
	assert_eq(replied["receipt"]["from_state"], "AVAILABLE")
	assert_eq(replied["receipt"]["to_state"], "ACCEPTED")
	assert_eq(replied["receipt"]["action_id"], "solo:priscilla:day1")

func test_reply_rejects_when_no_available_offer() -> void:
	var state_script: Script = load(CONTACT_STATE_PATH)
	if state_script == null:
		return
	var replied: Dictionary = state_script.prepare_reply(state_script.make_defaults(), "priscilla", 1, "tx.reply.p.d1")
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

func test_resolve_opened_unanswered_still_nevermind() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	st = s.prepare_open_contact(st, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": []}, "tx.resolve.d1")
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_UNANSWERED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 1)
	assert_eq(res["value"]["message_batch"][0]["type"], "nevermind")

func test_resolve_attended_solo_no_message() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	st = s.prepare_open_contact(st, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 1, "tx.reply.p.d1")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 1, {"solo_attended_action_ids": ["solo:priscilla:day1"]}, "tx.resolve.d1")
	assert_eq(res["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"], "RESOLVED_ATTENDED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 0)

func test_resolve_accepted_but_absent_queues_missed_question() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = s.prepare_offer_solo(s.make_defaults(), "priscilla", 1, "msg.solo.priscilla.day1", "tx.solo.p.d1")["value"]["candidate"]
	st = s.prepare_open_contact(st, "priscilla", 1, "tx.open.p.d1")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 1, "tx.reply.p.d1")["value"]["candidate"]
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

	var opened: Dictionary = s.prepare_open_contact(state, "priscilla", 2, "open-group-priscilla")
	assert_true(opened.get("ok", false))
	state = opened["value"]["candidate"]
	assert_eq(state["group_action"]["inviter_id"], "priscilla")
	assert_eq(s.get_unread_count(state, "priscilla", 2), 0)
	assert_eq(s.get_unread_count(state, "lavinia", 2), 1)

	var replied: Dictionary = s.prepare_reply(state, "lavinia", 2, "reply-lavinia")
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
	state = s.prepare_open_contact(state, "priscilla", 2, "open-p")["value"]["candidate"]
	var second_open: Dictionary = s.prepare_open_contact(state, "lavinia", 2, "open-l")
	assert_true(second_open.get("ok", false))
	state = second_open["value"]["candidate"]
	assert_eq(s.get_unread_count(state, "lavinia", 2), 0, "second open advances lavinia's watermark")
	assert_eq(second_open["receipt"]["kind"], "open_group_second")
	assert_eq((second_open["receipt"]["child_transaction_ids"] as Array).size(), 0, "second open appends no records")
	state = s.prepare_reply(state, "priscilla", 2, "reply-p")["value"]["candidate"]
	var second_reply: Dictionary = s.prepare_reply(state, "lavinia", 2, "reply-l")
	assert_true(second_reply.get("ok", false), "second reply is allowed")
	state = second_reply["value"]["candidate"]
	assert_eq((state["group_action"]["replied_ids"] as Array), ["priscilla", "lavinia"])
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
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
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
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 2, "reply-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("attended", "group:priscilla_lavinia:day2", "route.group.day2:completed"), "tx.resolve.d2")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_ATTENDED")
	assert_eq(res["receipt"]["group_date_variation"], "judgmental")
	var batch: Array = res["value"]["message_batch"]
	assert_eq(batch.size(), 1)
	assert_eq(batch[0]["type"], "judge")
	assert_eq(batch[0]["message_id"], "judge:lavinia:day3")

func test_group_both_replied_attended_is_normal_silent() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 2, "reply-p")["value"]["candidate"]
	st = s.prepare_reply(st, "lavinia", 2, "reply-l")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("attended", "group:priscilla_lavinia:day2", "route.group.day2:completed"), "tx.resolve.d2")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_ATTENDED")
	assert_eq(res["receipt"]["group_date_variation"], "normal")
	assert_eq((res["value"]["message_batch"] as Array).size(), 0)

func test_group_accepted_not_attended_misses_and_defers_twofriends() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 2, "reply-p")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("not_attended", "group:priscilla_lavinia:day2", "route.group.day2:cancelled"), "tx.resolve.d2")
	assert_eq(res["value"]["candidate"]["group_action"]["state"], "RESOLVED_MISSED")
	assert_eq((res["value"]["message_batch"] as Array).size(), 2)
	assert_eq(res["value"]["message_batch"][0]["type"], "missed_question")
	assert_eq(res["receipt"]["date_outcome_ids"], ["date.group.priscilla_lavinia.missed.day2"])
	assert_eq(res["receipt"]["deferred_twofriends"], {"route_id": "twofriends", "action_id": "group:priscilla_lavinia:day2", "after_hospital": false})

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
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 2, "reply-p")["value"]["candidate"]
	st = s.prepare_reply(st, "lavinia", 2, "reply-l")["value"]["candidate"]
	var res: Dictionary = s.prepare_resolve_day_end(st, 2, _att("attended", "group:priscilla_lavinia:day2", "route.group.day2:completed"), "tx.resolve.d2")
	assert_eq(res["receipt"]["pl_window"]["outcome"], "group")
	assert_eq(res["receipt"]["counter_deltas"], {"pl_window_counts.priscilla_lavinia": 1})

func test_pl_window_accepted_missed_counts_once() -> void:
	var s: Script = _script()
	if s == null:
		return
	var st: Dictionary = _activated_group_day2(s)
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 2, "reply-p")["value"]["candidate"]
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
	st = s.prepare_open_contact(st, "priscilla", 2, "open-p")["value"]["candidate"]
	st = s.prepare_reply(st, "priscilla", 2, "reply-p")["value"]["candidate"]
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
