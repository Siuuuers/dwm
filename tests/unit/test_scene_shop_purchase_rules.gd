extends "res://addons/gut/test.gd"

const RULES := preload("res://scripts/domain/shop/SceneShopPurchaseRules.gd")
const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const CAPABILITY := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")

func _gameplay() -> Dictionary:
	return {"money": 100, "coins": 10, "stats": {"pressure": 3}, "inventory": {},
		"minesweeper_round_floor": 0, "shop_purchase_counts": {}, "untouched": ["retained"]}

func _item(id: String) -> Dictionary:
	# Historical authored records retain generic rule coverage without returning them to sale.
	var historical := {
		"wine": {"id": "wine", "currency": "money", "price": 55, "max_purchases": 3, "effect_ids": ["pressure:-4"]},
		"quiet_tea": {"id": "quiet_tea", "currency": "money", "price": 15, "max_purchases": 3, "effect_ids": ["inventory:add:quiet_tea"]},
		"pineapple_bun": {"id": "pineapple_bun", "currency": "money", "price": 10, "max_purchases": 7, "effect_ids": ["inventory:add:pineapple_bun"]},
	}
	if historical.has(id): return historical[id].duplicate(true)
	var catalogue: Variant = CATALOG.new()
	return catalogue.get_shop_item(id)

func _supportz(count: int = 0) -> Dictionary:
	var prepared: Dictionary = CAPABILITY.prepare_supportz_effect({"causal_day_instance": "day",
		"completion_receipts": [{"kind": "complete", "app_round_ordinal": 1, "causal_day_instance": "day"},
			{"kind": "complete", "app_round_ordinal": 2, "causal_day_instance": "day"}],
		"branch_purchase_count": count, "daily_purchase_done": false}, "day", "purchase")
	assert_true(prepared.ok)
	return prepared.get("value", {})

func test_pressure_purchase_is_detached_and_debits_the_catalogue_price() -> void:
	var before: Dictionary = _gameplay()
	var original: Dictionary = before.duplicate(true)
	var item: Dictionary = _item("wine")
	var original_item: Dictionary = item.duplicate(true)
	var result: Dictionary = RULES.prepare(before, item, 2)
	assert_true(result.ok)
	if not result.ok: return
	assert_eq(result.value.gameplay.money, before.money - 2 * item.price)
	assert_eq(result.value.gameplay.stats.pressure, 0)
	assert_eq(result.value.purchase, {"item_id": "wine", "quantity": 2, "currency": item.currency,
		"unit_price": item.price, "effect_ids": item.effect_ids})
	result.value.gameplay.untouched.append("changed")
	result.value.purchase.effect_ids.append("changed")
	assert_eq(before, original)
	assert_eq(item, original_item)

func test_money_credit_boundary_and_negative_start_match_owner() -> void:
	var state: Dictionary = _gameplay()
	state.money = 0
	var item: Dictionary = _item("quiet_tea")
	var allowed: Dictionary = RULES.prepare(state, item, 2)
	assert_true(allowed.ok)
	if allowed.ok: assert_eq(allowed.value.gameplay.money, -30)
	assert_false(RULES.prepare(state, item, 3).ok)
	state.money = -1
	assert_false(RULES.prepare(state, item, 1).ok)

func test_coin_purchase_and_owned_capability() -> void:
	var state: Dictionary = _gameplay()
	var item: Dictionary = _item("debug_key")
	state.coins = item.price - 1
	assert_false(RULES.prepare(state, item, 1).ok)
	state.coins = item.price
	var accepted: Dictionary = RULES.prepare(state, item, 1)
	assert_true(accepted.ok)
	if not accepted.ok: return
	assert_eq(accepted.value.gameplay.coins, 0)
	assert_eq(accepted.value.gameplay.inventory.debug_key, 1)
	accepted.value.gameplay.coins = 10
	assert_false(RULES.prepare(accepted.value.gameplay, item, 1).ok)

func test_repeatable_batch_cap_is_not_a_lifetime_counter() -> void:
	var state: Dictionary = _gameplay()
	state.money = 1000
	state.shop_purchase_counts.wine = 100
	var item: Dictionary = _item("wine")
	var result: Dictionary = RULES.prepare(state, item, item.max_purchases)
	assert_true(result.ok)
	if result.ok: assert_eq(result.value.gameplay.shop_purchase_counts, state.shop_purchase_counts)
	assert_false(RULES.prepare(state, item, item.max_purchases + 1).ok)

func test_invalid_quantities_and_overflow_refuse_without_mutation() -> void:
	var state: Dictionary = _gameplay()
	var original: Dictionary = state.duplicate(true)
	for quantity: Variant in [0, -1, 1.0, true, "1", null, RULES.MAX_INTEGER]:
		assert_false(RULES.prepare(state, _item("wine"), quantity).ok, str(quantity))
	var expensive: Dictionary = _item("quiet_tea")
	expensive.price = RULES.MAX_INTEGER
	assert_false(RULES.prepare(state, expensive, 2).ok)
	assert_eq(state, original)

func test_retired_or_malformed_effect_does_not_publish_partial_debit() -> void:
	var state: Dictionary = _gameplay()
	var original: Dictionary = state.duplicate(true)
	for effects: Array in [["pressure:-2", "health:+1"], ["inventory:add:someone_else"],
			["pressure:-2", "pressure:-2"], [3], []]:
		var item: Dictionary = _item("wine")
		item.effect_ids = effects
		assert_false(RULES.prepare(state, item, 1).ok)
		assert_eq(state, original)

func test_missing_or_malformed_gameplay_is_not_defaulted() -> void:
	for key: String in ["money", "coins", "stats", "inventory", "minesweeper_round_floor"]:
		var state: Dictionary = _gameplay()
		state.erase(key)
		assert_false(RULES.prepare(state, _item("wine"), 1).ok, key)
	var state: Dictionary = _gameplay()
	state.inventory.wine = -1
	assert_false(RULES.prepare(state, _item("wine"), 1).ok)

func test_inventory_overflow_is_refused() -> void:
	var state: Dictionary = _gameplay()
	state.inventory.pineapple_bun = RULES.MAX_INTEGER
	assert_false(RULES.prepare(state, _item("pineapple_bun"), 1).ok)

func test_supportz_uses_existing_prepared_effect_and_preserves_other_state() -> void:
	var state: Dictionary = _gameplay()
	var original: Dictionary = state.duplicate(true)
	var effect: Dictionary = _supportz()
	var result: Dictionary = RULES.prepare(state, _item("supportz"), 1, effect)
	assert_true(result.ok)
	if not result.ok: return
	assert_eq(result.value.gameplay.minesweeper_round_floor, -1)
	assert_eq(result.value.gameplay.money, state.money - _item("supportz").price)
	assert_eq(result.value.gameplay.inventory, state.inventory)
	assert_eq(result.value.gameplay.shop_purchase_counts, state.shop_purchase_counts)
	assert_eq(state, original)
	assert_false(RULES.prepare(state, _item("supportz"), 1).ok)
	assert_false(RULES.prepare(state, _item("supportz"), 2, effect).ok)
	assert_false(RULES.prepare(state, _item("wine"), 1, effect).ok)

func test_supportz_requires_matching_previous_floor_and_bounded_successor() -> void:
	var state: Dictionary = _gameplay()
	var effect: Dictionary = _supportz(1)
	assert_false(RULES.prepare(state, _item("supportz"), 1, effect).ok)
	state.minesweeper_round_floor = -1
	assert_true(RULES.prepare(state, _item("supportz"), 1, effect).ok)
	effect.new_round_floor = -4
	assert_false(RULES.prepare(state, _item("supportz"), 1, effect).ok)

func test_current_catalogue_items_prepare_without_retired_effects() -> void:
	var catalogue: Variant = CATALOG.new()
	for raw: Variant in catalogue.get_shop_items():
		var item: Dictionary = catalogue.get_shop_item(raw.id)
		var state: Dictionary = _gameplay()
		state.money = 1000
		var result: Dictionary = RULES.prepare(state, item, 1, _supportz() if item.id == "supportz" else {})
		assert_true(result.ok, item.id + ": " + str(result.get("code")))

func test_maximal_money_balance_does_not_overflow_credit_check() -> void:
	var state: Dictionary = _gameplay()
	state.money = RULES.MAX_INTEGER
	var item: Dictionary = _item("wine")
	var result: Dictionary = RULES.prepare(state, item, 1)
	assert_true(result.ok)
	if result.ok: assert_eq(result.value.gameplay.money, RULES.MAX_INTEGER - item.price)

func test_invalid_currency_and_price_are_refused() -> void:
	var item: Dictionary = _item("wine")
	item.currency = "unknown"
	assert_false(RULES.prepare(_gameplay(), item, 1).ok)
	item = _item("wine")
	for price: Variant in [0, -1, 1.0, true]:
		item.price = price
		assert_false(RULES.prepare(_gameplay(), item, 1).ok)

func test_cosmetic_ownership_is_once_per_run_and_does_not_unlock_notes() -> void:
	for item_id: String in ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]:
		var state: Dictionary = _gameplay()
		state.shop_purchase_counts[item_id] = 3
		var item: Dictionary = _item(item_id)
		var result: Dictionary = RULES.prepare(state, item, 1)
		assert_true(result.ok, item_id)
		if not result.ok: continue
		assert_eq(result.value.gameplay.money, 55)
		assert_eq(result.value.gameplay.inventory, {item_id: 1})
		assert_eq(result.value.gameplay.stats, state.stats)
		assert_eq(result.value.gameplay.shop_purchase_counts, state.shop_purchase_counts)
		assert_false(RULES.prepare(result.value.gameplay, item, 1).ok, "second purchase refused")
		assert_false(RULES.prepare(state, item, 2).ok, "one item per purchase")
		assert_true(RULES.prepare(_gameplay(), item, 1).ok, "fresh run owns none")
