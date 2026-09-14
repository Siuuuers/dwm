extends "res://addons/gut/test.gd"
## Public read contracts used by the production HUD, board, and Shop ports.
## Bounds and overdraft behavior are authoritative in recovered CONTRACTS section 2
## and the retained GameState query implementations; setup does not exercise legacy mutations.

const GAME_STATE := preload("res://autoload/GameState.gd")


func _fresh_state() -> Node:
	var state: Node = autofree(GAME_STATE.new())
	state.reset_game()
	return state


func _watch_mutations(state: Node) -> Array[String]:
	var emissions: Array[String] = []
	state.stat_changed.connect(func(_id: String, _value: int, _min: int, _max: int) -> void:
		emissions.append("stat"))
	state.money_changed.connect(func(_value: int) -> void: emissions.append("money"))
	state.coins_changed.connect(func(_value: int) -> void: emissions.append("coins"))
	state.save_relevant_state_changed.connect(func() -> void: emissions.append("save"))
	return emissions


func _query_state(state: Node) -> Dictionary:
	return {"stats": state.stats.duplicate(true), "money": state.money, "coins": state.coins}


func test_get_stat_returns_canonical_internal_values_without_mutation() -> void:
	var state := _fresh_state()
	var emissions := _watch_mutations(state)
	var cases := [
		["pressure", 0], ["pressure", 12],
		["health", -2], ["health", 9],
		["motivation", 0], ["motivation", 7],
	]
	for row: Array in cases:
		var stat_id := str(row[0])
		var expected := int(row[1])
		state.stats[stat_id] = expected
		var before := _query_state(state)
		assert_eq(state.get_stat(stat_id), expected, str(row))
		assert_eq(_query_state(state), before, str(row))
	var before_unknown := _query_state(state)
	assert_eq(state.get_stat("absent-stat"), 0, "an absent stat has the documented neutral read")
	assert_eq(_query_state(state), before_unknown)
	assert_eq(emissions, [], "reads publish no mutation signal")


func test_get_stat_display_value_projects_audience_bounds_without_mutation() -> void:
	var state := _fresh_state()
	var emissions := _watch_mutations(state)
	var cases := [
		["pressure", 0, 0], ["pressure", 9, 9], ["pressure", 10, 9],
		["pressure", 11, 9], ["pressure", 12, 9],
		["health", -2, 0], ["health", -1, 0], ["health", 0, 0], ["health", 9, 9],
		["motivation", 0, 0], ["motivation", 7, 7],
	]
	for row: Array in cases:
		var stat_id := str(row[0])
		state.stats[stat_id] = int(row[1])
		var before := _query_state(state)
		assert_eq(state.get_stat_display_value(stat_id), int(row[2]), str(row))
		assert_eq(_query_state(state), before, str(row))
	var before_unknown := _query_state(state)
	assert_eq(state.get_stat_display_value("absent-stat"), 0)
	assert_eq(_query_state(state), before_unknown)
	assert_eq(emissions, [], "projection publishes no mutation signal")


func test_get_stat_display_max_returns_each_audience_scale_without_mutation() -> void:
	var state := _fresh_state()
	var emissions := _watch_mutations(state)
	var before := _query_state(state)
	for row: Array in [["pressure", 9], ["health", 9], ["motivation", 7], ["absent-stat", 0]]:
		assert_eq(state.get_stat_display_max(str(row[0])), int(row[1]), str(row))
	assert_eq(_query_state(state), before)
	assert_eq(emissions, [], "display metadata publishes no mutation signal")


func test_can_spend_money_respects_the_exact_overdraft_boundary_without_mutation() -> void:
	var state := _fresh_state()
	var emissions := _watch_mutations(state)
	var cases := [
		[-30, 1, false], [-1, 1, false],
		[0, -1, false], [0, 0, false], [0, 30, true], [0, 31, false],
		[20, 1, true], [20, 50, true], [20, 51, false],
	]
	for row: Array in cases:
		state.money = int(row[0])
		var before := _query_state(state)
		assert_eq(state.can_spend_money(int(row[1])), bool(row[2]), str(row))
		assert_eq(_query_state(state), before, str(row))
	assert_eq(emissions, [], "affordability checks spend nothing and publish nothing")


func test_can_spend_coins_requires_a_positive_owned_amount_without_mutation() -> void:
	var state := _fresh_state()
	var emissions := _watch_mutations(state)
	var cases := [
		[0, 1, false],
		[3, -1, false], [3, 0, false], [3, 1, true], [3, 3, true], [3, 4, false],
	]
	for row: Array in cases:
		state.coins = int(row[0])
		var before := _query_state(state)
		assert_eq(state.can_spend_coins(int(row[1])), bool(row[2]), str(row))
		assert_eq(_query_state(state), before, str(row))
	assert_eq(emissions, [], "affordability checks spend nothing and publish nothing")
