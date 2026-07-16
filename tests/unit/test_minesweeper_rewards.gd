extends "res://addons/gut/test.gd"
# Minesweeper reward unit tests (TESTING.md §test_minesweeper_rewards).

func before_each() -> void:
	GameState.reset_game()


func test_app_finish_rewards_money() -> void:
	GameState.start_minesweeper_app_round("beginner")
	GameState.finish_minesweeper_app_round({"context": "app", "difficulty": "beginner", "outcome": "cleared"})
	assert_eq(GameState.money, 6, "beginner cleared = +6")


func test_exploded_still_rewards() -> void:
	GameState.start_minesweeper_app_round("beginner")
	GameState.finish_minesweeper_app_round({"context": "app", "difficulty": "beginner", "outcome": "exploded"})
	assert_eq(GameState.money, 1, "beginner exploded = +1")


func test_dating_context_no_app_money() -> void:
	var before := GameState.money
	GameState.finish_minesweeper_app_round({"context": "dating", "difficulty": "expert", "outcome": "perfect"})
	assert_eq(GameState.money, before, "dating-context finish rewards no app money")


func test_daily_cap_enforced() -> void:
	GameState.minesweeper_money_earned_today = 108
	var r := GameState.calculate_minesweeper_money_reward({"difficulty": "expert", "outcome": "perfect"})
	assert_eq(int(r["money"]), 0, "at cap, no further money")
	assert_eq(int(r["remaining_cap"]), 0)


func test_cap_grows_with_supportz() -> void:
	GameState.change_minesweeper_round_floor(-1) # total playable 3
	GameState.minesweeper_money_earned_today = 108
	var r := GameState.calculate_minesweeper_money_reward({"difficulty": "expert", "outcome": "perfect"})
	assert_true(int(r["money"]) > 0, "extra playable round raises the daily cap above 108")


func test_task_reward_once_only() -> void:
	GameState.check_and_claim_minesweeper_task_rewards({"task_ids": ["complete_beginner"]})
	assert_eq(GameState.coins, 1)
	GameState.check_and_claim_minesweeper_task_rewards({"task_ids": ["complete_beginner"]})
	assert_eq(GameState.coins, 1, "same task never awards a second coin")


func test_win_win_win_claimable_once() -> void:
	GameState.check_and_claim_minesweeper_task_rewards({"task_ids": ["complete_beginner"]})
	GameState.check_and_claim_minesweeper_task_rewards({"task_ids": ["complete_intermediate"]})
	GameState.check_and_claim_minesweeper_task_rewards({"task_ids": ["complete_expert"]})
	assert_true(GameState.minesweeper_task_rewards_claimed.has("win_win_win"), "win_win_win auto-claims when all three completes achieved")
	assert_eq(GameState.coins, 4, "3 completes + win_win_win = 4 coins")
	assert_true(GameState.coins <= 9, "total coins never exceed the cap of 9")
