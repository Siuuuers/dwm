extends "res://addons/gut/test.gd"
# Shop data/rules unit tests (prompt_docs/requirements/verification.md). The full ShopApp buy flow
# (quantity selector, spend/refund) is Phase 3 UI; Phase 1 verifies the data + effect rules.

const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")

# max_purchases is DERIVED from the registry record's cap.per_branch; the structured cap also
# carries per_causal_day, which DataCatalog does not and should not expose (DECISION 4).
const SHOP_PARITY := [
	{
		"item_id": "lucky_charm",
		"currency": "minesweeper_coin",
		"price": 1,
		"effect_ids": ["inventory:add:lucky_charm"],
		"max_purchases": 1,
	},
	{
		"item_id": "debug_key",
		"currency": "minesweeper_coin",
		"price": 3,
		"effect_ids": ["inventory:add:debug_key"],
		"max_purchases": 1,
	},
	{
		"item_id": "supportz",
		"currency": "money",
		"price": 45,
		"effect_ids": ["minesweeper:round_floor:-1"],
		"max_purchases": 3,
	},
]

var _dc: DataCatalog


func before_each() -> void:
	_dc = DataCatalog.new()


func test_nine_shop_items() -> void:
	var items := _dc.get_shop_items()
	assert_eq(items.size(), 9, "eight public items and secret Supportz")


func test_supportz_properties() -> void:
	var s := _dc.get_shop_item("supportz")
	assert_false(s.is_empty(), "supportz exists")
	assert_true(bool(s["is_secret_buy_button"]), "supportz is a secret buy button")
	assert_false(bool(s["is_visible_in_shop"]), "supportz not shown as a normal item")
	assert_eq(int(s["max_purchases"]), 3, "supportz max 3")
	assert_true("minesweeper:round_floor:-1" in s["effect_ids"], "supportz lowers the round floor")


func test_all_item_effects_are_known() -> void:
	for item in _dc.get_shop_items():
		assert_true(get_node("/root/EffectResolver").are_effect_ids_known(item.effect_ids), "effects known for %s" % item.id)


func test_currencies_valid() -> void:
	for item in _dc.get_shop_items():
		assert_true(item.currency == "money" or item.currency == "minesweeper_coin", "valid currency for %s" % item.id)


func test_gift_items_flagged() -> void:
	var priscilla_gift := _dc.get_shop_item("priscilla_gift")
	assert_true(bool(priscilla_gift["is_special_gift"]), "priscilla_gift is a special gift")


func test_shop_projection_matches_the_frozen_literals() -> void:
	for expected: Dictionary in SHOP_PARITY:
		var item_id: String = str(expected["item_id"])
		var item: Dictionary = _dc.get_shop_item(item_id)
		assert_false(item.is_empty(), "%s must resolve" % item_id)
		assert_eq(str(item.get("currency", "")), str(expected["currency"]), "%s currency" % item_id)
		assert_eq(int(item.get("price", -1)), int(expected["price"]), "%s price" % item_id)
		assert_eq(item.get("effect_ids", []), expected["effect_ids"], "%s effect_ids" % item_id)
		assert_eq(int(item.get("max_purchases", -1)), int(expected["max_purchases"]),
			"%s max_purchases" % item_id)


# Task 7 (dwm-p2r.32.7): MinesweeperShopPurchaseParticipant interprets exactly this closed 3-item
# union itself (no generic effect-string execution path, per the frozen contract's own words) --
# lucky_charm/debug_key grant their capability via inventory ownership, supportz spends money and
# decrements the round floor. A regression guard: if the registry's item-id set ever changes, this
# fails loudly rather than the participant silently rejecting every purchase as unregistered.
func test_registry_ids_are_the_closed_three_item_set_the_shop_purchase_participant_depends_on() -> void:
	assert_eq(SHOP_REGISTRY.get_ids(), ["lucky_charm", "debug_key", "supportz"])


# The only genuinely RED Shop assertion: get_record() answers not_implemented today, so this can go
# green only once the registry works AND DataCatalog delegates to it (DECISION 11.9).
func test_shop_projection_equals_the_registry_records() -> void:
	var initialized: Dictionary = SHOP_REGISTRY.initialize()
	assert_true(initialized.get("ok", false),
		"the Shop registry must load: %s" % str(initialized.get("code", &"")))
	for expected: Dictionary in SHOP_PARITY:
		var item_id: String = str(expected["item_id"])
		var fetched: Dictionary = SHOP_REGISTRY.get_record(item_id)
		assert_true(fetched.get("ok", false),
			"get_record(%s) must succeed: %s" % [item_id, str(fetched.get("code", &""))])
		if not fetched.get("ok", false):
			continue
		var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
		var cap: Dictionary = record.get("cap", {}) as Dictionary
		var item: Dictionary = _dc.get_shop_item(item_id)
		assert_eq(str(item.get("currency", "")), str(record.get("currency", "")),
			"%s currency is projected, not stored" % item_id)
		assert_eq(int(item.get("price", -1)), int(record.get("price", -2)),
			"%s price is projected, not stored" % item_id)
		assert_eq(item.get("effect_ids", []), record.get("effect_ids", []),
			"%s effect_ids are projected, not stored" % item_id)
		assert_eq(int(item.get("max_purchases", -1)), int(cap.get("per_branch", -2)),
			"%s max_purchases is derived from cap.per_branch" % item_id)


func test_replaced_items_are_absent_and_cosmetics_use_inventory() -> void:
	for item_id: String in ["coffee", "pep_note", "bandage_pack", "healthy_meal", "protein_box",
			"wine", "pineapple_bun", "quiet_tea", "soft_blanket", "weighted_plush", "spa_coupon", "premium_care"]:
		assert_true(_dc.get_shop_item(item_id).is_empty(), item_id)
	for item_id: String in ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]:
		var item: Dictionary = _dc.get_shop_item(item_id)
		assert_eq(item.effect_ids, ["inventory:add:" + item_id])
		assert_eq(item.price, 45)
		assert_eq(item.currency, "money")
		assert_eq(item.max_purchases, 1)
