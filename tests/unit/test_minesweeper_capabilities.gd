extends "res://addons/gut/test.gd"

# Task 2 capability/Supportz contract suite (Plan 02 Task 2, dwm-p2r.32.1).
# MinesweeperCapabilityRules is a brand-new file with no frozen-class precedent, so its
# interface matches the brief exactly and the verbatim composition example runs unmodified.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const RULES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")

const _DAY := "day-alpha"
const _OTHER_DAY := "day-beta"


func test_capability_rules_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
	assert_true(loaded.get("ok", false), "MinesweeperCapabilityRules.gd must load")


# ---- resolve_owned: composition ----

func test_resolve_owned_neither_item_is_baseline_only() -> void:
	var result: Dictionary = RULES.resolve_owned({})
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["capability_ids"], ["first_cell_safe"])


func test_resolve_owned_lucky_only() -> void:
	var result: Dictionary = RULES.resolve_owned({"lucky_charm": 1})
	assert_eq(result["value"]["capability_ids"], ["first_cell_safe", "first_cell_zero"])


func test_resolve_owned_debug_only() -> void:
	var result: Dictionary = RULES.resolve_owned({"debug_key": 1})
	assert_eq(result["value"]["capability_ids"], ["first_cell_safe", "forced_no_guess"])


func test_lucky_and_debug_compose_in_both_purchase_orders() -> void:
	var both_a: Dictionary = RULES.resolve_owned({"lucky_charm": 1, "debug_key": 1})
	var both_b: Dictionary = RULES.resolve_owned({"debug_key": 1, "lucky_charm": 1})
	assert_eq(both_a, both_b)
	assert_eq(both_a["value"]["capability_ids"], ["first_cell_safe", "first_cell_zero", "forced_no_guess"])


func test_resolve_owned_ignores_unowned_and_falsy_quantities() -> void:
	var result: Dictionary = RULES.resolve_owned({"lucky_charm": 0, "debug_key": false, "supportz": 3})
	assert_eq(result["value"]["capability_ids"], ["first_cell_safe"], "supportz carries no capability_ids in the registry")


func test_resolve_owned_capability_ids_are_registry_derived_not_hardcoded() -> void:
	var lucky_record: Dictionary = SHOP_REGISTRY.get_record("lucky_charm")
	var debug_record: Dictionary = SHOP_REGISTRY.get_record("debug_key")
	assert_true(lucky_record.get("ok", false))
	assert_true(debug_record.get("ok", false))
	var lucky_caps: Array = ((lucky_record["value"] as Dictionary)["record"] as Dictionary)["capability_ids"]
	var debug_caps: Array = ((debug_record["value"] as Dictionary)["record"] as Dictionary)["capability_ids"]
	var both: Dictionary = RULES.resolve_owned({"lucky_charm": 1, "debug_key": 1})
	var capability_ids: Array = both["value"]["capability_ids"]
	for cap_id: String in lucky_caps:
		assert_true(capability_ids.has(cap_id), "%s must come from the live registry" % cap_id)
	for cap_id: String in debug_caps:
		assert_true(capability_ids.has(cap_id), "%s must come from the live registry" % cap_id)


func test_resolve_owned_returns_a_detached_array() -> void:
	var first: Dictionary = RULES.resolve_owned({"lucky_charm": 1})
	(first["value"]["capability_ids"] as Array).append("tampered")
	var second: Dictionary = RULES.resolve_owned({"lucky_charm": 1})
	assert_false((second["value"]["capability_ids"] as Array).has("tampered"),
		"resolve_owned() must return a fresh array each call")


# ---- build_spec_inputs: raw/effective extras and forced_no_guess ----

func test_build_spec_inputs_raw_extra_formula() -> void:
	# raw_extra = floor(pressure / 3) + penalty_points_today
	var result: Dictionary = RULES.build_spec_inputs({"capability_ids": ["first_cell_safe"]}, 9, 2)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["raw_extra_mines"], 5)
	assert_eq(result["value"]["effective_extra_mines"], 5, "no lucky charm: effective equals raw")
	assert_false(result["value"]["forced_no_guess"])


func test_build_spec_inputs_odd_raw_extras_floor_divide_under_lucky() -> void:
	# pressure=15, penalty=0 -> raw_extra = floor(15/3) = 5 (odd) -> lucky halves floor(5/2) = 2
	var result: Dictionary = RULES.build_spec_inputs({"capability_ids": ["first_cell_safe", "first_cell_zero"]}, 15, 0)
	assert_eq(result["value"]["raw_extra_mines"], 5)
	assert_eq(result["value"]["effective_extra_mines"], 2)


func test_build_spec_inputs_even_raw_extras_halve_exactly_under_lucky() -> void:
	var result: Dictionary = RULES.build_spec_inputs({"capability_ids": ["first_cell_safe", "first_cell_zero"]}, 12, 0)
	assert_eq(result["value"]["raw_extra_mines"], 4)
	assert_eq(result["value"]["effective_extra_mines"], 2)


func test_build_spec_inputs_debug_sets_forced_no_guess_without_touching_extras() -> void:
	var result: Dictionary = RULES.build_spec_inputs({"capability_ids": ["first_cell_safe", "forced_no_guess"]}, 9, 1)
	assert_true(result["value"]["forced_no_guess"])
	assert_eq(result["value"]["raw_extra_mines"], 4)
	assert_eq(result["value"]["effective_extra_mines"], 4,
		"debug alone does not halve extras -- only first_cell_zero's floor-halving is a pure-rule projection")


func test_build_spec_inputs_both_capabilities_halve_and_force_no_guess() -> void:
	var result: Dictionary = RULES.build_spec_inputs(
		{"capability_ids": ["first_cell_safe", "first_cell_zero", "forced_no_guess"]}, 9, 1)
	assert_eq(result["value"]["raw_extra_mines"], 4)
	assert_eq(result["value"]["effective_extra_mines"], 2)
	assert_true(result["value"]["forced_no_guess"])


func test_build_spec_inputs_is_a_pure_prospective_projection() -> void:
	var owned: Dictionary = {"capability_ids": ["first_cell_safe", "first_cell_zero"]}
	var first: Dictionary = RULES.build_spec_inputs(owned, 15, 0)
	var second: Dictionary = RULES.build_spec_inputs(owned, 15, 0)
	assert_eq(first, second, "the same inputs always project the same spec inputs; no hidden state")


func test_build_spec_inputs_rejects_malformed_owned() -> void:
	assert_false(RULES.build_spec_inputs({}, 9, 0).get("ok", true), "missing capability_ids rejects")
	assert_false(RULES.build_spec_inputs({"capability_ids": ["first_cell_safe"], "extra": 1}, 9, 0).get("ok", true),
		"extra key rejects")
	assert_false(RULES.build_spec_inputs({"capability_ids": "not_an_array"}, 9, 0).get("ok", true),
		"non-array capability_ids rejects")


# ---- supportz_eligible: two-completion base-ordinal law ----

func _completion(ordinal: int, day: String = _DAY) -> Dictionary:
	return {"kind": "complete", "app_round_ordinal": ordinal, "causal_day_instance": day}


func _receipt(kind: String, ordinal: int, day: String = _DAY) -> Dictionary:
	return {"kind": kind, "app_round_ordinal": ordinal, "causal_day_instance": day}


func _state(receipts: Array, branch_purchase_count: int = 0, daily_purchase_done: bool = false) -> Dictionary:
	return {
		"causal_day_instance": _DAY,
		"completion_receipts": receipts,
		"branch_purchase_count": branch_purchase_count,
		"daily_purchase_done": daily_purchase_done,
	}


func test_supportz_requires_two_current_day_base_completions() -> void:
	var eligible: Dictionary = RULES.supportz_eligible(_state([_completion(1), _completion(2)]))
	assert_true(eligible.get("ok", false), JSON.stringify(eligible))
	assert_true(eligible["value"]["eligible"], "ordinal 1 and 2 complete today makes supportz eligible")


func test_supportz_rejects_when_ordinal_one_is_replaced() -> void:
	var replacements: Array[Dictionary] = [
		_receipt("forfeit", 1),
		_receipt("challenge", 1),
		_receipt("prepared", 1),
		_completion(1, _OTHER_DAY),
		_completion(3),
	]
	for replacement: Dictionary in replacements:
		var result: Dictionary = RULES.supportz_eligible(_state([replacement, _completion(2)]))
		assert_true(result.get("ok", false), JSON.stringify(result))
		assert_false(result["value"]["eligible"], "replacing ordinal 1 with %s must reject" % JSON.stringify(replacement))


func test_supportz_rejects_when_ordinal_two_is_replaced() -> void:
	var replacements: Array[Dictionary] = [
		_receipt("forfeit", 2),
		_receipt("challenge", 2),
		_receipt("prepared", 2),
		_completion(2, _OTHER_DAY),
		_completion(3),
	]
	for replacement: Dictionary in replacements:
		var result: Dictionary = RULES.supportz_eligible(_state([_completion(1), replacement]))
		assert_true(result.get("ok", false), JSON.stringify(result))
		assert_false(result["value"]["eligible"], "replacing ordinal 2 with %s must reject" % JSON.stringify(replacement))


func test_supportz_rejects_at_three_branch_purchases() -> void:
	var result: Dictionary = RULES.supportz_eligible(_state([_completion(1), _completion(2)], 3, false))
	assert_true(result.get("ok", false))
	assert_false(result["value"]["eligible"], "the branch cap of three purchases blocks a fourth")


func test_supportz_accepts_up_to_two_branch_purchases() -> void:
	for count: int in [0, 1, 2]:
		var result: Dictionary = RULES.supportz_eligible(_state([_completion(1), _completion(2)], count, false))
		assert_true(result["value"]["eligible"], "branch_purchase_count=%d must still be eligible" % count)


func test_supportz_rejects_a_second_purchase_the_same_day() -> void:
	var result: Dictionary = RULES.supportz_eligible(_state([_completion(1), _completion(2)], 0, true))
	assert_false(result["value"]["eligible"], "at most one supportz purchase per logical day")


func test_supportz_eligible_rejects_a_malformed_state() -> void:
	assert_false(RULES.supportz_eligible({}).get("ok", true), "missing members rejects")
	assert_false(RULES.supportz_eligible(_state([{"kind": "complete"}])).get("ok", true),
		"a malformed completion receipt rejects the whole call")


# ---- prepare_supportz_effect: signed round-floor 0..-3, prospective, registry-derived effect id ----

func test_prepare_supportz_effect_first_purchase_floors_to_negative_one() -> void:
	var result: Dictionary = RULES.prepare_supportz_effect(
		_state([_completion(1), _completion(2)], 0, false), _DAY, "txn-1")
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["previous_round_floor"], 0)
	assert_eq(result["value"]["new_round_floor"], -1)


func test_prepare_supportz_effect_floor_progression_zero_to_negative_three() -> void:
	var expected: Array = [[0, -1], [1, -2], [2, -3]]
	for pair: Array in expected:
		var branch_purchase_count: int = pair[0]
		var result: Dictionary = RULES.prepare_supportz_effect(
			_state([_completion(1), _completion(2)], branch_purchase_count, false), _DAY,
			"txn-%d" % branch_purchase_count)
		assert_eq(result["value"]["previous_round_floor"], -branch_purchase_count)
		assert_eq(result["value"]["new_round_floor"], pair[1])


func test_prepare_supportz_effect_uses_the_registry_declared_effect_id() -> void:
	var record: Dictionary = SHOP_REGISTRY.get_record("supportz")
	assert_true(record.get("ok", false))
	var effect_ids: Array = ((record["value"] as Dictionary)["record"] as Dictionary)["effect_ids"]
	var expected_effect_id: String = effect_ids[0]
	var result: Dictionary = RULES.prepare_supportz_effect(
		_state([_completion(1), _completion(2)], 0, false), _DAY, "txn-1")
	assert_eq(result["value"]["effect_id"], expected_effect_id)
	assert_eq(result["value"]["effect_id"], "minesweeper:round_floor:-1")


func test_prepare_supportz_effect_rejects_when_not_eligible() -> void:
	var result: Dictionary = RULES.prepare_supportz_effect(_state([_completion(1)], 0, false), _DAY, "txn-1")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"supportz_not_eligible")


func test_prepare_supportz_effect_rejects_blank_identifiers() -> void:
	var state: Dictionary = _state([_completion(1), _completion(2)], 0, false)
	assert_false(RULES.prepare_supportz_effect(state, "", "txn-1").get("ok", true), "blank causal_day_instance rejects")
	assert_false(RULES.prepare_supportz_effect(state, _DAY, "").get("ok", true), "blank transaction_id rejects")


func test_prepare_supportz_effect_is_prospective_only() -> void:
	var state: Dictionary = _state([_completion(1), _completion(2)], 0, false)
	var first: Dictionary = RULES.prepare_supportz_effect(state, _DAY, "txn-1")
	var second: Dictionary = RULES.prepare_supportz_effect(state, _DAY, "txn-1")
	assert_eq(first["value"]["new_round_floor"], second["value"]["new_round_floor"],
		"prepare_supportz_effect never mutates state -- the same branch_purchase_count always projects the same floor")
