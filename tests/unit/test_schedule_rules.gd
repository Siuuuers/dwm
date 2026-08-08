extends "res://addons/gut/test.gd"
# Schedule rules unit tests (prompt_docs/requirements/verification.md).

func before_each() -> void:
	GameState.reset_game()


func test_add_action_costs_motivation() -> void:
	assert_eq(GameState.get_stat("motivation"), 7)
	assert_true(GameState.add_schedule_action("training"))
	assert_eq(GameState.get_stat("motivation"), 6, "adding costs 1 motivation")
	assert_eq(GameState.schedule_entries.size(), 1)


func test_remove_refunds_motivation() -> void:
	GameState.add_schedule_action("working")
	assert_eq(GameState.get_stat("motivation"), 6)
	assert_true(GameState.remove_schedule_entry(0))
	assert_eq(GameState.get_stat("motivation"), 7, "removing refunds 1 motivation")
	assert_eq(GameState.schedule_entries.size(), 0)


func test_cannot_add_at_zero_motivation() -> void:
	GameState.change_stat("motivation", -7)
	assert_eq(GameState.get_stat("motivation"), 0)
	assert_false(GameState.add_schedule_action("rest"), "cannot add with 0 motivation")
	assert_eq(GameState.schedule_entries.size(), 0)


func test_clear_with_and_without_refund() -> void:
	GameState.add_schedule_action("training")
	GameState.add_schedule_action("rest")
	assert_eq(GameState.get_stat("motivation"), 5)
	GameState.clear_schedule_with_refund()
	assert_eq(GameState.schedule_entries.size(), 0)
	assert_eq(GameState.get_stat("motivation"), 7, "refund restores motivation")
	GameState.add_schedule_action("training")
	var mot := GameState.get_stat("motivation")
	GameState.clear_schedule_without_refund()
	assert_eq(GameState.schedule_entries.size(), 0)
	assert_eq(GameState.get_stat("motivation"), mot, "no refund keeps motivation")


func test_max_scheduled_dates_by_day() -> void:
	# `day` is lifecycle-owned and read-only (dwm-p2r.4); position the run via the lifecycle.
	GameState._lifecycle_set_playing_day(3)
	assert_eq(GameState.get_max_scheduled_dates_for_current_day(), 2, "Day 1..6 allows 2 dates")
	GameState._lifecycle_set_playing_day(7)
	assert_eq(GameState.get_max_scheduled_dates_for_current_day(), 1, "Day 7 allows 1 date")


func test_validate_schedule_returns_dictionary() -> void:
	var res := GameState.validate_schedule()
	assert_true(res is Dictionary)
	assert_true(res.has("ok"))


# ---- Characterization net for the ScheduleRules migration (dwm-p2r.7 Task 4) ----
# These pin the CURRENT GameState validation reason codes so the future delegation onto the pure
# ScheduleRules module is provably behaviour-preserving (or its diff is visible). Not new logic.

func test_validate_schedule_reason_codes() -> void:
	assert_eq(GameState.validate_schedule(), {"ok": true, "reason": "valid"}, "empty schedule is valid")
	GameState.add_schedule_action("training")
	assert_eq(GameState.validate_schedule(), {"ok": true, "reason": "valid"}, "a registered action is valid")
	GameState.schedule_entries.append({"type": "mystery_action"})
	assert_eq(GameState.validate_schedule(), {"ok": false, "reason": "unknown_action"},
		"an unregistered action type is rejected")

func test_can_add_schedule_action_reason_codes() -> void:
	assert_eq(GameState.can_add_schedule_action("training"), {"ok": true}, "a registered action is addable")
	assert_eq(GameState.can_add_schedule_action("mystery_action").get("reason"), "unknown_action")
	assert_eq(GameState.can_add_schedule_action("dating", "").get("reason"), "no_friend",
		"dating requires a friend id")
	assert_eq(GameState.can_add_schedule_action("dating", "priscilla").get("reason"), "date_not_unlocked",
		"dating requires an unlocked date")
	GameState.change_stat("motivation", -7)
	assert_eq(GameState.can_add_schedule_action("training").get("reason"), "no_motivation",
		"zero motivation blocks scheduling")


# ---- Schedule Done warning ----
func test_warn_playable_round_and_motivation_empty_schedule() -> void:
	# Fresh day: no unfinished, playable rounds remain, motivation > 0, empty schedule.
	var w := GameState.should_warn_minesweeper_before_schedule_done()
	assert_true(w is Dictionary)
	assert_true(bool(w["should_warn"]), "playable round + motivation on empty schedule warns")


func test_warn_unfinished_round_and_motivation() -> void:
	GameState.start_minesweeper_app_round("beginner")
	assert_false(GameState.unfinished_minesweeper_result.is_empty())
	var w := GameState.should_warn_minesweeper_before_schedule_done()
	assert_true(bool(w["should_warn"]), "unfinished round + motivation warns")


func test_no_warn_zero_motivation_empty_schedule() -> void:
	GameState.change_stat("motivation", -7)
	assert_eq(GameState.get_stat("motivation"), 0)
	var w := GameState.should_warn_minesweeper_before_schedule_done()
	assert_false(bool(w["should_warn"]), "motivation 0 + no non-date entry does not warn")


# ---- Date-path characterization (dwm-p2r.7 Task 4): pins CURRENT behaviour before delegation ----
func test_char_add_time_duplicate_and_distinct_friend() -> void:
	GameState.schedule_entries = [GameState.build_date_entry_from_unlock("priscilla")]
	assert_false(GameState._can_add_date_entry(GameState.build_date_entry_from_unlock("priscilla")),
		"a second date for the same friend is not addable")
	assert_true(GameState._can_add_date_entry(GameState.build_date_entry_from_unlock("lavinia")),
		"a date for a distinct friend is addable")

func test_char_three_dates_exceed_the_day_allowance() -> void:
	GameState.schedule_entries = [
		GameState.build_date_entry_from_unlock("priscilla"),
		GameState.build_date_entry_from_unlock("lavinia"),
		GameState.build_date_entry_from_unlock("sylvia"),
	]
	assert_eq(GameState.validate_schedule(), {"ok": false, "reason": "too_many_dates"},
		"three dates exceed the day-1 allowance")

func test_char_full_two_date_week_currently_self_reports_invalid() -> void:
	# LATENT BUG documented: the add-time guard, reused at validate-time, double-counts, so a full,
	# legal 2-date week self-reports invalid_date. Task 3's delegation corrects this to valid.
	GameState.schedule_entries = [
		GameState.build_date_entry_from_unlock("priscilla"),
		GameState.build_date_entry_from_unlock("lavinia"),
	]
	assert_eq(GameState.validate_schedule(), {"ok": false, "reason": "invalid_date"},
		"pre-delegation: a full valid 2-date week self-reports invalid_date")
