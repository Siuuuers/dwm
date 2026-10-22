extends "res://addons/gut/test.gd"

const GAME := preload("res://autoload/GameState.gd")
const REWARD := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const FIXTURE := preload("res://tests/unit/test_scene_receipt_validation.gd")
const LAYOUT := {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [4], "mine_count": 1}

func _terminal(clear: bool) -> Dictionary:
	var board: Dictionary = REDUCER.first_reveal(LAYOUT, 0).value.board
	if not clear: return REDUCER.reveal(board, 4, "explode").value.board
	for cell: int in [1, 2, 3, 5, 6, 7, 8]:
		board = REDUCER.reveal(board, cell, "reveal-%d" % cell).value.board
	return board

func test_scene_rewards_are_detached_pressure_only_and_retain_daily_cap() -> void:
	var game := GAME.new()
	game.reset_game()
	game.stats = {"pressure": 3}
	game.minesweeper_money_earned_today = 107
	var before: Dictionary = game.to_save_dict().duplicate(true)
	var contacts: Dictionary = game.contacts.duplicate(true)
	var port := REWARD.new(game)
	var result: Dictionary = port.prepare_scene_complete("expert", _terminal(false))
	assert_true(result.ok, str(result))
	if result.ok:
		assert_eq(result.value.gameplay.money, before.money + 1)
		assert_eq(result.value.gameplay.minesweeper_money_earned_today, 108)
		assert_eq(result.value.gameplay.stats.pressure, before.stats.pressure + 2)
		assert_eq(result.value.gameplay.minesweeper_app_rounds_finished_today, 1)
		assert_false(result.value.gameplay.has("unfinished_minesweeper_result"))
		assert_eq(result.value.gameplay.size(), GAME.SCENE_GAMEPLAY_KEYS.size())
		assert_eq(result.value.gameplay.stats.keys(), ["pressure"])
		assert_false(result.value.gameplay.has("day"))
		assert_false(result.value.gameplay.has("schedule"))
	assert_eq(game.to_save_dict(), before)
	assert_eq(game.contacts, contacts)
	game.free()

func test_perfect_task_claims_share_existing_once_only_rules() -> void:
	var game := GAME.new()
	game.reset_game()
	game.stats = {"pressure": 3}
	var port := REWARD.new(game)
	var result: Dictionary = port.prepare_scene_complete("beginner", _terminal(true))
	assert_true(result.ok, str(result))
	if result.ok:
		assert_eq(result.value.outcome, "perfect")
		assert_eq(result.value.reward.money, 9)
		for id: String in ["complete_beginner", "perfect_beginner", "no_flag_finish", "foresight_finish"]:
			assert_true(result.value.gameplay.minesweeper_task_rewards_claimed.has(id))
		game._apply_gameplay_silent(result.value.gameplay)
		var again: Dictionary = port.prepare_scene_complete("beginner", _terminal(true))
		assert_true(again.ok)
		if again.ok:
			assert_eq(again.value.claimed, [])
			assert_eq(again.value.gameplay.coins, result.value.gameplay.coins)
	game.free()

func test_completion_receipt_authenticates_board_and_reward_and_requires_admission() -> void:
	var fixture := FIXTURE.new()
	fixture.before_each()
	var root: Dictionary = fixture.issuer.issue(&"transaction_id").value.issuer_receipt
	var identity: Dictionary = fixture.identity.duplicate(true)
	identity.erase("causal_day_instance_issuer_receipt")
	identity["app_round_ordinal"] = 1
	var completion := {"board_identity": identity, "board_sha256": "ab".repeat(32),
		"gameplay_sha256": "cd".repeat(32), "revision": 7, "difficulty": "expert", "outcome": "exploded"}
	var made: Dictionary = CONTRACT.make_scene_round_completion(fixture.identity, root,
		fixture.admission.transaction_id, completion, fixture.issuer)
	assert_true(made.ok, str(made))
	if made.ok:
		assert_true(CONTRACT.validate_scene_round_completion(made.value, fixture.issuer).ok)
		var bag := {made.value.transaction_id: made.value, fixture.admission.transaction_id: fixture.admission}
		assert_true(CONTRACT.validate_scene_receipts(bag, fixture.bundle, fixture.issuer).ok)
		assert_false(CONTRACT.validate_scene_receipts({made.value.transaction_id: made.value}, fixture.bundle, fixture.issuer).ok)
		for field: String in ["board_sha256", "gameplay_sha256", "outcome", "revision"]:
			var bad: Dictionary = made.value.duplicate(true)
			bad.scene_round_completion.completion[field] = 8 if field == "revision" else "changed"
			assert_false(CONTRACT.validate_scene_round_completion(bad, fixture.issuer).ok, field)
		var foreign := completion.duplicate(true)
		foreign.board_identity.causal_day_instance = "other-day"
		assert_false(CONTRACT.make_scene_round_completion(fixture.identity, root,
			fixture.admission.transaction_id, foreign, fixture.issuer).ok)
	fixture.free()
