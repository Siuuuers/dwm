extends "res://addons/gut/test.gd"
# Pure ContactInvitationState module (dwm-p2r.6): append-only per-friend history
# with monotonic watermarks, solo-offer state machine, group activation/resolution,
# and the run-end Priscilla-Lavinia four-way window.

const STATE_PATH := "res://scripts/domain/contact/ContactInvitationState.gd"

func _exists() -> bool:
	return ResourceLoader.exists(STATE_PATH, "Script")

func _new() -> RefCounted:
	return load(STATE_PATH).new()

func test_module_exists() -> void:
	assert_true(_exists(), "ContactInvitationState must exist")

# ---- req.contact.history_watermark ----

func test_append_only_log_with_monotonic_watermark() -> void:
	if not _exists(): return
	var s := _new()
	assert_eq(s.get_watermark("priscilla"), 0, "empty history has watermark 0")
	var first: Dictionary = s.generate_message("priscilla", &"daily_message", 1)
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_true(first["value"]["appended"], "first generation appends")
	assert_eq(int(first["value"]["entry"]["seq"]), 1, "sequences start at 1")
	assert_eq(s.get_watermark("priscilla"), 1)
	var second: Dictionary = s.generate_message("priscilla", &"solo_offer", 1)
	assert_eq(int(second["value"]["entry"]["seq"]), 2, "sequences are monotonic per friend")
	# A second friend keeps its own independent sequence.
	assert_eq(int(s.generate_message("lavinia", &"daily_message", 1)["value"]["entry"]["seq"]), 1)

func test_generation_is_idempotent_per_day_kind() -> void:
	if not _exists(): return
	var s := _new()
	s.generate_message("priscilla", &"solo_offer", 1)
	var repeat: Dictionary = s.generate_message("priscilla", &"solo_offer", 1)
	assert_true(repeat.get("ok", false))
	assert_false(repeat["value"]["appended"], "re-generating the same (day, kind) is a no-op")
	assert_eq(s.get_watermark("priscilla"), 1, "no duplicate entry, watermark unchanged")
	assert_eq((s.get_history("priscilla") as Array).size(), 1)

func test_unknown_friend_rejects() -> void:
	if not _exists(): return
	var s := _new()
	assert_false(s.generate_message("angela", &"solo_offer", 1).get("ok", true), "only friends have contact history")
	assert_false(s.generate_message("priscilla", &"bogus_kind", 1).get("ok", true), "unknown message kind rejects")

# ---- req.invitation.solo (state machine) ----

func test_solo_offer_state_transitions() -> void:
	if not _exists(): return
	var s := _new()
	s.generate_message("sylvia", &"solo_offer", 3)
	assert_eq(s.get_solo_state("sylvia", 3), &"unread", "a fresh offer is unread")
	assert_true(s.has_unread_solo("sylvia", 3))
	assert_true(s.open_solo_offer("sylvia", 3)["ok"])
	assert_eq(s.get_solo_state("sylvia", 3), &"reply_required", "opening moves unread -> reply_required")
	assert_false(s.has_unread_solo("sylvia", 3))
	assert_true(s.reply_solo_offer("sylvia", 3)["ok"])
	assert_eq(s.get_solo_state("sylvia", 3), &"replied", "replying moves reply_required -> replied")

func test_group_generation_supersedes_solo_offers() -> void:
	if not _exists(): return
	var s := _new()
	s.generate_message("priscilla", &"solo_offer", 2)
	s.generate_message("lavinia", &"solo_offer", 2)
	assert_true(s.supersede_solo("priscilla", 2)["ok"])
	assert_true(s.supersede_solo("lavinia", 2)["ok"])
	assert_eq(s.get_solo_state("priscilla", 2), &"superseded")
	assert_eq(s.get_solo_state("lavinia", 2), &"superseded")

func test_day_end_nevermind_for_any_unreplied_solo() -> void:
	if not _exists(): return
	var s := _new()
	# priscilla: unread (never opened). lavinia: opened, unanswered. sylvia: replied.
	s.generate_message("priscilla", &"solo_offer", 4)
	s.generate_message("lavinia", &"solo_offer", 4)
	s.open_solo_offer("lavinia", 4)
	s.generate_message("sylvia", &"solo_offer", 4)
	s.open_solo_offer("sylvia", 4)
	s.reply_solo_offer("sylvia", 4)
	var resolved: Dictionary = s.resolve_solo_offers_at_day_end(4)
	assert_true(resolved.get("ok", false), JSON.stringify(resolved))
	var nevermind: Array = resolved["value"]["nevermind_friend_ids"]
	nevermind.sort()
	assert_eq(nevermind, ["lavinia", "priscilla"],
		"nevermind fires for BOTH unread and opened-unanswered offers")
	assert_false("sylvia" in nevermind, "a replied offer is never a nevermind")

func test_day_end_superseded_is_silent() -> void:
	if not _exists(): return
	var s := _new()
	s.generate_message("priscilla", &"solo_offer", 2)
	s.supersede_solo("priscilla", 2)
	var resolved: Dictionary = s.resolve_solo_offers_at_day_end(2)
	assert_false("priscilla" in (resolved["value"]["nevermind_friend_ids"] as Array),
		"a superseded offer emits no nevermind")

# ---- save round-trip ----

func test_to_dict_from_dict_round_trip() -> void:
	if not _exists(): return
	var s := _new()
	s.generate_message("priscilla", &"solo_offer", 2)
	s.open_solo_offer("priscilla", 2)
	var data: Dictionary = s.to_dict()
	var restored: Dictionary = load(STATE_PATH).from_dict(data.duplicate(true))
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	var s2: RefCounted = restored["value"]["state"]
	assert_eq(s2.to_dict(), data, "restore is lossless")
	assert_eq(s2.get_solo_state("priscilla", 2), &"reply_required", "restored state preserves offer state")

# ---- req.invitation.group_activation ----

func _both_unread(s: RefCounted, day: int) -> void:
	s.generate_message("priscilla", &"solo_offer", day)
	s.generate_message("lavinia", &"solo_offer", day)

func test_group_activation_requires_third_round_and_both_unread() -> void:
	if not _exists(): return
	var s := _new()
	_both_unread(s, 2)
	assert_false(s.can_activate_group(2, 2), "before the third round the group offer is unavailable")
	assert_true(s.can_activate_group(2, 3), "after the third round with both unread it activates")
	assert_false(s.can_activate_group(1, 3), "only counted windows (Day 2/6) are group-eligible")
	var s6 := _new()
	_both_unread(s6, 6)
	assert_true(s6.can_activate_group(6, 3), "Day 6 is the other counted window")

func test_group_activation_needs_both_participants_unread() -> void:
	if not _exists(): return
	var s := _new()
	s.generate_message("priscilla", &"solo_offer", 2)
	s.generate_message("lavinia", &"solo_offer", 2)
	s.open_solo_offer("lavinia", 2)  # lavinia no longer unread
	assert_false(s.can_activate_group(2, 3), "a read solo for either participant blocks group activation")

func test_activate_group_supersedes_both_solo_offers() -> void:
	if not _exists(): return
	var s := _new()
	_both_unread(s, 2)
	var activated: Dictionary = s.activate_group(2)
	assert_true(activated.get("ok", false), JSON.stringify(activated))
	assert_true(s.is_group_active(2))
	assert_eq(s.get_solo_state("priscilla", 2), &"superseded", "activation supersedes the pair's solo offers")
	assert_eq(s.get_solo_state("lavinia", 2), &"superseded")
	assert_eq(s.get_group_state("priscilla", 2), &"unread", "each participant gets an unread group offer")
	assert_eq(s.get_group_state("lavinia", 2), &"unread")
	# Idempotent.
	assert_false(s.activate_group(2)["value"]["appended"], "re-activating the same day is a no-op")

# ---- req.invitation.group_resolution ----

func test_first_opened_becomes_inviter() -> void:
	if not _exists(): return
	var s := _new()
	_both_unread(s, 6)
	s.activate_group(6)
	assert_eq(s.get_group_inviter(6), "", "no inviter until a group message is opened")
	assert_true(s.open_group_offer("lavinia", 6)["ok"])
	assert_eq(s.get_group_inviter(6), "lavinia", "the first participant opened becomes the inviter")
	# Opening the other does not change the inviter.
	s.open_group_offer("priscilla", 6)
	assert_eq(s.get_group_inviter(6), "lavinia", "inviter is assigned once, for variation/image only")

func test_reply_order_gate_and_schedulable() -> void:
	if not _exists(): return
	var s := _new()
	_both_unread(s, 2)
	s.activate_group(2)
	s.open_group_offer("priscilla", 2)  # priscilla is inviter
	assert_false(s.is_group_schedulable(2), "not schedulable until a valid reply")
	# The non-inviter cannot reply before the inviter (FLOWS 5.1 gate).
	assert_eq(s.reply_group_offer("lavinia", 2).get("code"), &"need_reply_inviter_first")
	assert_true(s.reply_group_offer("priscilla", 2)["ok"], "the inviter may reply")
	assert_true(s.is_group_schedulable(2), "replying makes the group date schedulable")

func test_group_state_round_trips() -> void:
	if not _exists(): return
	var s := _new()
	_both_unread(s, 2)
	s.activate_group(2)
	s.open_group_offer("priscilla", 2)
	s.reply_group_offer("priscilla", 2)
	var data: Dictionary = s.to_dict()
	var s2: RefCounted = load(STATE_PATH).from_dict(data.duplicate(true))["value"]["state"]
	assert_eq(s2.to_dict(), data, "group + inviter + schedulable state restores losslessly")
	assert_eq(s2.get_group_inviter(2), "priscilla")
	assert_true(s2.is_group_schedulable(2))

# ---- req.invitation.run_end (Priscilla-Lavinia four-way window, story/05 §7) ----

func _activated_group(day: int) -> RefCounted:
	var s := _new()
	_both_unread(s, day)
	s.activate_group(day)
	return s

func test_pl_prevented_when_angela_solo_dated_one() -> void:
	if not _exists(): return
	var s := _activated_group(2)
	var r: Dictionary = s.resolve_pl_window(2, ["priscilla"], false)
	assert_true(r.get("ok", false), JSON.stringify(r))
	assert_eq(r["value"]["outcome"], &"prevented")
	assert_false(r["value"]["counts"], "solo-dating one participant never counts")
	assert_eq(s.get_pair_counter(), 0)

func test_pl_group_when_attended() -> void:
	if not _exists(): return
	var s := _activated_group(2)
	s.open_group_offer("priscilla", 2)
	s.reply_group_offer("priscilla", 2)
	var r: Dictionary = s.resolve_pl_window(2, [], true)
	assert_eq(r["value"]["outcome"], &"group")
	assert_true(r["value"]["counts"] and r["value"]["visible"])
	assert_eq(s.get_pair_counter(), 1)

func test_pl_missed_when_accepted_but_unattended() -> void:
	if not _exists(): return
	var s := _activated_group(2)
	s.open_group_offer("lavinia", 2)
	s.reply_group_offer("lavinia", 2)  # accepted -> schedulable
	var r: Dictionary = s.resolve_pl_window(2, [], false)
	assert_eq(r["value"]["outcome"], &"missed")
	assert_true(r["value"]["counts"] and r["value"]["visible"])

func test_pl_private_visible_when_generated_but_not_accepted() -> void:
	if not _exists(): return
	var s := _activated_group(2)  # both group offers unread, never accepted
	var r: Dictionary = s.resolve_pl_window(2, [], false)
	assert_eq(r["value"]["outcome"], &"private_visible")
	assert_true(r["value"]["counts"] and r["value"]["visible"])

func test_pl_private_offscreen_when_group_never_generated() -> void:
	if not _exists(): return
	var s := _new()  # no group activation at all
	var r: Dictionary = s.resolve_pl_window(2, [], false)
	assert_eq(r["value"]["outcome"], &"private_offscreen")
	assert_true(r["value"]["counts"], "offscreen private still counts")
	assert_false(r["value"]["visible"], "offscreen private shows no scene")

func test_pl_counter_reaches_two_and_gates_epilogue() -> void:
	if not _exists(): return
	var s := _new()
	assert_false(s.should_route_pl_epilogue())
	assert_true(s.resolve_pl_window(2, [], false)["value"]["counts"], "Day 2 private-offscreen counts")
	assert_false(s.should_route_pl_epilogue(), "one window is not enough")
	s.resolve_pl_window(6, [], false)
	assert_eq(s.get_pair_counter(), 2)
	assert_true(s.should_route_pl_epilogue(), "count == 2 (both windows) gates the epilogue")

func test_pl_resolution_is_idempotent_per_day() -> void:
	if not _exists(): return
	var s := _new()
	s.resolve_pl_window(2, [], false)
	var repeat: Dictionary = s.resolve_pl_window(2, [], false)
	assert_true(repeat.get("ok", false))
	assert_true(repeat["value"]["already_resolved"], "re-resolving a window is a no-op")
	assert_eq(s.get_pair_counter(), 1, "no double count")

func test_run_end_state_round_trips() -> void:
	if not _exists(): return
	var s := _new()
	s.resolve_pl_window(2, [], false)
	var data: Dictionary = s.to_dict()
	var s2: RefCounted = load(STATE_PATH).from_dict(data.duplicate(true))["value"]["state"]
	assert_eq(s2.to_dict(), data, "pair counter + resolved windows restore losslessly")
	assert_eq(s2.get_pair_counter(), 1)
