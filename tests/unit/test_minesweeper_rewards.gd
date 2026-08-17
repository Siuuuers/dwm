extends "res://addons/gut/test.gd"
# Minesweeper reward unit tests (prompt_docs/requirements/desktop_minesweeper_handoff.md).
#
# These tests remain the AUTHORITY for current money/pressure/task behaviour. The Task 2 round
# contract routes every fixture through these same production rules rather than restating them,
# so the fixture set below is checked for coverage and derivation only -- never for duplicated
# authoritative reward values (dwm-p2r.9 Plan 06 Task 2).

const STATE_PORT := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")
const CONTRACT := preload("res://scripts/domain/minesweeper/MinesweeperRoundContract.gd")
const FIXTURE_PATH := "res://tests/fixtures/minesweeper/results.json"

func before_each() -> void:
	GameState.reset_game()


func _fixtures() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "fixture set must be a JSON object")
	return (parsed as Dictionary).get("fixtures", []) as Array


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


# ---- Task 2 fixture traversal (dwm-p2r.9 Plan 06) ----

func test_fixture_set_is_exactly_five_outcomes_for_each_of_three_difficulties() -> void:
	var fixtures := _fixtures()
	assert_eq(fixtures.size(), 15, "exactly fifteen test-only fixtures")
	var seen := {}
	for fixture: Variant in fixtures:
		var record := fixture as Dictionary
		var difficulty := str(record["difficulty"])
		var outcome := str((record["result"] as Dictionary)["outcome"])
		assert_true(StringName(difficulty) in CONTRACT.DIFFICULTIES, difficulty)
		assert_true(StringName(outcome) in CONTRACT.OUTCOMES, outcome)
		assert_eq((record["result"] as Dictionary).size(), 1,
			"a completed result is exactly one outcome key")
		var key := "%s/%s" % [difficulty, outcome]
		assert_false(seen.has(key), "duplicate fixture " + key)
		seen[key] = true
	assert_eq(seen.size(), 15)


func test_fixtures_carry_no_seed_grid_mine_timer_or_board_state() -> void:
	var raw := FileAccess.get_file_as_string(FIXTURE_PATH)
	for forbidden: String in ["seed", "grid", "mine", "timer", "board", "cells"]:
		assert_false(raw.contains("\"%s\"" % forbidden),
			"fixtures must not encode %s state" % forbidden)
	for fixture: Variant in _fixtures():
		var keys: Array = (fixture as Dictionary).keys()
		keys.sort()
		assert_eq(keys, ["difficulty", "fixture_id", "result"])


func test_every_fixture_derives_its_reward_through_production_rules() -> void:
	for fixture: Variant in _fixtures():
		var record := fixture as Dictionary
		var difficulty := str(record["difficulty"])
		var outcome := str((record["result"] as Dictionary)["outcome"])
		var reward: Dictionary = GameState.calculate_minesweeper_money_reward(
			{"difficulty": difficulty, "outcome": outcome})
		assert_true(reward.has("money") and reward.has("pressure"),
			"production rules answer for " + str(record["fixture_id"]))
		assert_true(int(reward["money"]) >= 0, str(record["fixture_id"]))


func test_no_flag_and_foresight_keep_perfect_equivalent_rewards() -> void:
	for difficulty: StringName in CONTRACT.DIFFICULTIES:
		var perfect: Dictionary = GameState.calculate_minesweeper_money_reward(
			{"difficulty": String(difficulty), "outcome": "perfect"})
		for equivalent: String in ["no_flag", "foresight"]:
			var actual: Dictionary = GameState.calculate_minesweeper_money_reward(
				{"difficulty": String(difficulty), "outcome": equivalent})
			assert_eq(int(actual["money"]), int(perfect["money"]),
				"%s %s money matches perfect" % [difficulty, equivalent])
			assert_eq(int(actual["pressure"]), int(perfect["pressure"]),
				"%s %s pressure matches perfect" % [difficulty, equivalent])


func test_no_flag_and_foresight_record_their_own_distinct_task_ids() -> void:
	var port: RefCounted = STATE_PORT.new(GameState)
	for difficulty: StringName in CONTRACT.DIFFICULTIES:
		var text := String(difficulty)
		var perfect: Array = port.call(&"_task_ids_for", "perfect", text)
		var no_flag: Array = port.call(&"_task_ids_for", "no_flag", text)
		var foresight: Array = port.call(&"_task_ids_for", "foresight", text)
		assert_true(no_flag.has("no_flag_finish"), text)
		assert_true(foresight.has("foresight_finish"), text)
		assert_false(no_flag.has("perfect_%s" % text),
			"no_flag records its own task, never the perfect task")
		assert_false(foresight.has("perfect_%s" % text),
			"foresight records its own task, never the perfect task")
		assert_true(perfect.has("perfect_%s" % text), text)
		assert_ne(no_flag, foresight, "the two share a reward, not an identity")
		for ids: Array in [perfect, no_flag, foresight]:
			assert_true(ids.has("complete_%s" % text), "every finish completes the difficulty")
		assert_eq(port.call(&"_task_ids_for", "exploded", text), [],
			"an exploded round claims no task")
