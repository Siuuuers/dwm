extends "res://addons/gut/test.gd"
# Schedule rules unit tests (TESTING.md §test_schedule_rules).

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
	GameState.day = 3
	assert_eq(GameState.get_max_scheduled_dates_for_current_day(), 2, "Day 1..6 allows 2 dates")
	GameState.day = 7
	assert_eq(GameState.get_max_scheduled_dates_for_current_day(), 1, "Day 7 allows 1 date")


func test_validate_schedule_returns_dictionary() -> void:
	var res := GameState.validate_schedule()
	assert_true(res is Dictionary)
	assert_true(res.has("ok"))


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
