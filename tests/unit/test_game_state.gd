extends "res://addons/gut/test.gd"
# GameState unit tests (prompt_docs/requirements/verification.md).

func before_each() -> void:
	GameState.reset_game()


func test_reset_game_initial_values() -> void:
	assert_eq(GameState.day, 1)
	assert_eq(GameState.money, 0)
	assert_eq(GameState.coins, 0)
	assert_eq(GameState.penalty_points_today, 0)
	assert_eq(GameState.get_stat("pressure"), 3)
	assert_eq(GameState.get_stat("health"), 6)
	assert_eq(GameState.get_stat("motivation"), 7)


func test_change_stat_clamps() -> void:
	GameState.change_stat("pressure", 100)
	assert_eq(GameState.get_stat("pressure"), 12, "pressure clamps to 12")
	GameState.change_stat("pressure", -100)
	assert_eq(GameState.get_stat("pressure"), 0, "pressure clamps to 0")
	GameState.change_stat("health", -100)
	assert_eq(GameState.get_stat("health"), -2, "health clamps to -2")
	GameState.change_stat("motivation", 100)
	assert_eq(GameState.get_stat("motivation"), 7, "motivation clamps to 7")


func test_display_conversions() -> void:
	GameState.change_stat("pressure", 100)
	assert_eq(GameState.get_stat_display_value("pressure"), 9, "pressure display clamps 0..9")
	GameState.set_stat("health", -2)
	assert_eq(GameState.get_stat_display_value("health"), 0, "negative health displays 0")


func test_money_overdraft_rules() -> void:
	assert_true(GameState.change_money(-100), "spend from 0 clamps to -30")
	assert_eq(GameState.money, -30, "money floor -30")
	assert_false(GameState.can_spend_money(1), "cannot spend while negative")
	GameState.change_money(50)
	assert_eq(GameState.money, 20)


func test_coin_spending_blocks_when_insufficient() -> void:
	assert_false(GameState.can_spend_coins(1), "no coins to spend")
	GameState.change_coins(3)
	assert_true(GameState.try_spend_coins(2))
	assert_eq(GameState.coins, 1)
	assert_false(GameState.try_spend_coins(5), "cannot overspend coins")


func test_opening_and_tutorial_flags() -> void:
	assert_false(GameState.opening_seen)
	GameState.mark_opening_seen()
	assert_true(GameState.opening_seen)
	assert_false(GameState.tutorial_seen)
	GameState.mark_tutorial_seen()
	assert_true(GameState.tutorial_seen)


func test_advance_day_resets_and_ends() -> void:
	GameState.change_stat("motivation", -3)
	GameState.day = 3
	assert_true(GameState.advance_day_or_end(), "advance mid-week returns true")
	assert_eq(GameState.day, 4)
	assert_eq(GameState.get_stat("motivation"), 7, "motivation resets on new day")
	assert_eq(GameState.minesweeper_rounds_left, 2, "rounds reset on new day")
	GameState.day = 7
	assert_false(GameState.advance_day_or_end(), "advance after day 7 returns false")
	assert_eq(GameState.day, 8, "day becomes 8 ending marker")


# ---- Minesweeper round-floor ----
func test_round_floor_defaults() -> void:
	assert_eq(GameState.minesweeper_round_floor, 0)
	assert_eq(GameState.minesweeper_rounds_left, 2)
	assert_eq(GameState.get_minesweeper_display_rounds_left(), 2)
	assert_eq(GameState.get_minesweeper_display_rounds_max(), 2)
	assert_eq(GameState.get_minesweeper_total_playable_rounds(), 2)


func test_two_app_rounds_without_supportz() -> void:
	assert_true(GameState.can_start_minesweeper_app_round())
	GameState.start_minesweeper_app_round("beginner")
	assert_eq(GameState.get_minesweeper_display_rounds_left(), 1)
	GameState.finish_minesweeper_app_round({"context": "app", "difficulty": "beginner", "outcome": "cleared"})
	GameState.start_minesweeper_app_round("beginner")
	assert_eq(GameState.get_minesweeper_display_rounds_left(), 0)
	GameState.finish_minesweeper_app_round({"context": "app", "difficulty": "beginner", "outcome": "cleared"})
	assert_false(GameState.can_start_minesweeper_app_round(), "cannot start a third without Supportz")


func test_one_supportz_gives_three_rounds() -> void:
	GameState.change_minesweeper_round_floor(-1)
	assert_eq(GameState.minesweeper_round_floor, -1)
	assert_eq(GameState.get_minesweeper_total_playable_rounds(), 3)
	assert_eq(GameState.get_minesweeper_display_rounds_max(), 2, "denominator unchanged")


func test_three_supportz_caps_floor() -> void:
	for i in range(5):
		GameState.change_minesweeper_round_floor(-1)
	assert_eq(GameState.minesweeper_round_floor, -3, "floor never below -3")
	assert_eq(GameState.get_minesweeper_total_playable_rounds(), 5)


# ---- Conditions ----
func test_danger_penalty_and_reset() -> void:
	GameState.set_stat("pressure", 12)
	GameState.set_stat("health", -2)
	GameState.resolve_pressure_health_condition_end_of_day()
	assert_true(GameState.penalty_points_today <= 6, "daily penalty caps at 6")
	assert_true(GameState.get_stat("pressure") <= 9, "pressure reset to <=9 after penalty")
	assert_true(GameState.get_stat("health") >= 1, "health reset to >=1 after penalty")


func test_hospital_recovery() -> void:
	GameState.set_stat("health", -2)
	GameState.set_stat("pressure", 12)
	GameState.pending_hospital = true
	GameState.apply_hospital_recovery_and_advance_day()
	assert_eq(GameState.get_stat("health"), 6)
	assert_eq(GameState.get_stat("pressure"), 3)
	assert_false(GameState.pending_hospital)


# ---- Save whitelist ----
func test_save_dict_is_json_safe() -> void:
	var d := GameState.to_save_dict()
	assert_true(d is Dictionary)
	var json := JSON.stringify(d)
	assert_true(json.length() > 0, "save dict stringifies as JSON")
	var reparsed := JSON.new()
	assert_eq(reparsed.parse(json), OK, "save dict round-trips through JSON")


func test_apply_save_dict_preserves_state() -> void:
	GameState.change_money(45)
	GameState.change_minesweeper_round_floor(-2)
	var d := GameState.to_save_dict()
	GameState.reset_game()
	GameState.apply_save_dict(d)
	assert_eq(GameState.money, 45)
	assert_eq(GameState.minesweeper_round_floor, -2)


# ---- minesweeper_rng_seed persistence (CONTRACTS §2 / §6) ----
func test_save_whitelist_includes_rng_seed() -> void:
	GameState.reset_game()
	var d := GameState.to_save_dict()
	assert_true(d.has("minesweeper_rng_seed"), "rng_seed is in the save whitelist")


func test_rng_seed_round_trips_through_save() -> void:
	GameState.reset_game()
	GameState.minesweeper_rng_seed = 123456789
	var d := GameState.to_save_dict()
	GameState.reset_game()
	GameState.apply_save_dict(d)
	assert_eq(GameState.minesweeper_rng_seed, 123456789, "seed persists across save/load")


# ---- check_immediate_faint ----
func test_check_immediate_faint_requires_sequela_and_danger() -> void:
	GameState.set_stat("pressure", 12)
	GameState.set_stat("health", -2)
	GameState.condition_effects_today = []
	assert_false(GameState.check_immediate_faint(), "danger without sequela does not faint")
	assert_false(GameState.pending_hospital)
	GameState.condition_effects_today = ["sequela"]
	assert_true(GameState.check_immediate_faint(), "sequela + pressure>=10 faints")
	assert_true(GameState.pending_hospital)


func test_check_immediate_faint_sequela_and_low_health() -> void:
	GameState.set_stat("health", 0)
	GameState.condition_effects_today = ["sequela"]
	assert_true(GameState.check_immediate_faint(), "sequela + health<=0 faints")


func test_check_immediate_faint_sequela_no_danger() -> void:
	GameState.set_stat("pressure", 3)
	GameState.set_stat("health", 6)
	GameState.condition_effects_today = ["sequela"]
	assert_false(GameState.check_immediate_faint(), "sequela without danger does not faint")


# ---- should_route_sylvia_special_ending ----
func test_should_route_sylvia_special_ending_thresholds() -> void:
	GameState.hospital_skipped_sylvia_solo_count = 0
	assert_false(GameState.should_route_sylvia_special_ending())
	GameState.hospital_skipped_sylvia_solo_count = 1
	assert_false(GameState.should_route_sylvia_special_ending(), "1 skip is not enough")
	GameState.hospital_skipped_sylvia_solo_count = 2
	assert_true(GameState.should_route_sylvia_special_ending(), ">=2 skips enables Special Sylvia")


func test_hospital_recovery_counts_sylvia_solo() -> void:
	GameState.set_stat("health", -2)
	GameState.set_stat("pressure", 12)
	# Real hospital route: the Sylvia solo lives in schedule_entries (dates are skipped, never queued
	# into pending_date_entries). The counter MUST read the schedule before it is cleared.
	GameState.schedule_entries = [{"type": "solo", "friend_id": "sylvia"}]
	GameState.pending_hospital = true
	GameState.apply_hospital_recovery_and_advance_day()
	assert_eq(GameState.hospital_skipped_sylvia_solo_count, 1, "one skipped Sylvia solo counted")


# ---- Day-7 ending resolution (precedence + epilogue) ----
func test_resolve_day7_sylvia_special_highest_precedence() -> void:
	GameState.day = 7
	GameState.hospital_skipped_sylvia_solo_count = 2
	GameState.missed_group_date_counts = {"priscilla_lavinia": 2}  # priscilla_lavinia also true
	GameState.schedule_entries = [{"day": 7, "type": "solo", "date_kind": "date", "friend_id": "priscilla"}]
	var r := GameState.resolve_day7_ending()
	assert_eq(r["ending_id"], "ending.sylvia.special", "Special Sylvia wins over priscilla_lavinia")
	assert_eq(r["epilogue_ending_id"], "ending.priscilla_lavinia", "priscilla_lavinia plays as epilogue")
	assert_eq(GameState.route_context["ending_id"], "ending.sylvia.special")
	assert_eq(GameState.route_context["epilogue_ending_id"], "ending.priscilla_lavinia")
	assert_eq(GameState.day, 8, "day becomes 8 ending sentinel")


func test_resolve_day7_priscilla_lavinia_primary_no_epilogue() -> void:
	GameState.day = 7
	GameState.missed_group_date_counts = {"priscilla_lavinia": 2}
	var r := GameState.resolve_day7_ending()
	assert_eq(r["ending_id"], "ending.priscilla_lavinia")
	assert_eq(r["epilogue_ending_id"], "", "no epilogue when priscilla_lavinia is the primary")


func test_resolve_day7_candidate_true_path() -> void:
	GameState.day = 7
	GameState.contact_message_unlocks = {"day:7:friend:priscilla": true}
	GameState.schedule_entries = [{"day": 7, "type": "solo", "date_kind": "date", "friend_id": "priscilla"}]
	GameState.dating_route_state = {"priscilla": {"true_path_count": 4, "dark_points": 0}}
	GameState.affection = {"priscilla": 10}
	var r := GameState.resolve_day7_ending()
	assert_eq(r["ending_id"], "ending.priscilla.true", "true path with love affection")
	assert_eq(r["epilogue_ending_id"], "", "no epilogue without priscilla_lavinia unlock")


func test_resolve_day7_not_day7_returns_epilogue_key() -> void:
	GameState.day = 3
	var r := GameState.resolve_day7_ending()
	assert_false(r["ok"])
	assert_eq(r["epilogue_ending_id"], "", "non-day7 returns epilogue key for schema stability")
