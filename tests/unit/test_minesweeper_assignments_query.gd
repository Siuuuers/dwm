extends GutTest

const QUERY := preload("res://scripts/application/minesweeper/MinesweeperAssignmentsQuery.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const UNAVAILABLE := {"ok": false, "code": &"minesweeper_assignments_unavailable"}

class StateFixture extends RefCounted:
	var minesweeper_task_rewards_claimed: Variant = {}
	var mutation_calls := 0

	func check_and_claim_minesweeper_task_rewards(_result: Dictionary) -> Array:
		mutation_calls += 1
		return []

	func to_save_dict() -> Dictionary:
		mutation_calls += 1
		return {}

	func apply_save_dict(_data: Dictionary) -> Dictionary:
		mutation_calls += 1
		return {}

class CatalogFixture extends RefCounted:
	var rows: Variant = []

	func get_minesweeper_tasks() -> Variant:
		return rows


func test_real_owner_receipts_project_in_registry_order_without_mutation() -> void:
	var state := GAME_STATE.new()
	state.reset_game()
	state.check_and_claim_minesweeper_task_rewards({"task_ids": [
		"complete_beginner", "complete_intermediate", "complete_expert", "foresight_finish",
	]})
	var before: Dictionary = state.to_save_dict().duplicate(true)
	watch_signals(state)
	var result: Dictionary = QUERY.from_sources(state, CATALOG.new())
	assert_eq(result, {"ok": true, "value": [true, true, true, false, true, false, false, false, true]})
	assert_eq(state.to_save_dict(), before, "Inspection does not claim, award, or mutate gameplay.")
	assert_signal_not_emitted(state, "minesweeper_reward_changed")
	state.free()


func test_empty_receipts_and_result_edits_do_not_create_claims() -> void:
	var state := GAME_STATE.new()
	state.reset_game()
	var before: Dictionary = state.to_save_dict().duplicate(true)
	var result: Dictionary = QUERY.from_sources(state, CATALOG.new())
	assert_eq(result.value, [false, false, false, false, false, false, false, false, false])
	result.value[0] = true
	assert_eq(state.to_save_dict(), before)
	assert_false(QUERY.from_sources(state, CATALOG.new()).value[0])
	state.free()


func test_membership_is_owner_truth_and_all_tiers_is_never_inferred() -> void:
	var state := StateFixture.new()
	state.minesweeper_task_rewards_claimed = {
		"complete_beginner": false, "complete_intermediate": true, "complete_expert": true,
	}
	var before: Dictionary = state.minesweeper_task_rewards_claimed.duplicate(true)
	assert_eq(QUERY.from_sources(state, CATALOG.new()), {
		"ok": true, "value": [true, true, true, false, false, false, false, false, false],
	})
	assert_eq(state.minesweeper_task_rewards_claimed, before)
	assert_eq(state.mutation_calls, 0, "The query never invokes a claim or save API.")


func test_missing_sources_and_malformed_maps_fail_without_partial_truth() -> void:
	var catalog := CATALOG.new()
	assert_eq(QUERY.from_sources(null, catalog), UNAVAILABLE)
	assert_eq(QUERY.from_sources(StateFixture.new(), null), UNAVAILABLE)
	assert_eq(QUERY.from_sources(RefCounted.new(), catalog), UNAVAILABLE)
	assert_eq(QUERY.from_sources(StateFixture.new(), RefCounted.new()), UNAVAILABLE)
	var state := StateFixture.new()
	for malformed: Variant in [null, [], "private receipt", 1]:
		state.minesweeper_task_rewards_claimed = malformed
		assert_eq(QUERY.from_sources(state, catalog), UNAVAILABLE)
	assert_eq(state.mutation_calls, 0)


func test_malformed_catalogs_fail_without_ids_or_partial_claims() -> void:
	var state := StateFixture.new()
	state.minesweeper_task_rewards_claimed = {"complete_beginner": true}
	var catalog := CatalogFixture.new()
	for malformed: Variant in [null, {}, [], "private catalog"]:
		catalog.rows = malformed
		assert_eq(QUERY.from_sources(state, catalog), UNAVAILABLE)
	var real_catalog := CATALOG.new()
	for corruption: String in ["missing", "extra", "reordered", "duplicate", "unknown", "null", "dictionary"]:
		var rows: Array = real_catalog.get_minesweeper_tasks()
		match corruption:
			"missing": rows.pop_back()
			"extra": rows.append(rows[0])
			"reordered": rows.reverse()
			"duplicate": rows[8] = rows[0]
			"unknown": rows[8].id = "private unknown assignment"
			"null": rows[8] = null
			"dictionary": rows[8] = {"id": "win_win_win"}
		catalog.rows = rows
		assert_eq(QUERY.from_sources(state, catalog), UNAVAILABLE, corruption)
	assert_eq(state.mutation_calls, 0)
