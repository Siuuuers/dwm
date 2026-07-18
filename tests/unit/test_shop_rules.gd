extends "res://addons/gut/test.gd"
# Shop data/rules unit tests (prompt_docs/requirements/verification.md). The full ShopApp buy flow
# (quantity selector, spend/refund) is Phase 3 UI; Phase 1 verifies the data + effect rules.

var _dc: DataCatalog


func before_each() -> void:
	_dc = DataCatalog.new()


func test_eighteen_shop_items() -> void:
	var items := _dc.get_shop_items()
	assert_eq(items.size(), 18, "exactly 18 shop item templates")


func test_supportz_properties() -> void:
	var s := _dc.get_shop_item("supportz")
	assert_false(s.is_empty(), "supportz exists")
	assert_true(bool(s["is_secret_buy_button"]), "supportz is a secret buy button")
	assert_false(bool(s["is_visible_in_shop"]), "supportz not shown as a normal item")
	assert_eq(int(s["max_purchases"]), 3, "supportz max 3")
	assert_true("minesweeper:round_floor:-1" in s["effect_ids"], "supportz lowers the round floor")


func test_all_item_effects_are_known() -> void:
	for item in _dc.get_shop_items():
		assert_true(EffectResolver.are_effect_ids_known(item.effect_ids), "effects known for %s" % item.id)


func test_currencies_valid() -> void:
	for item in _dc.get_shop_items():
		assert_true(item.currency == "money" or item.currency == "minesweeper_coin", "valid currency for %s" % item.id)


func test_gift_items_flagged() -> void:
	var pineapple := _dc.get_shop_item("pineapple_bun")
	assert_true(bool(pineapple["is_gift"]), "pineapple_bun is a gift")
	var priscilla_gift := _dc.get_shop_item("priscilla_gift")
	assert_true(bool(priscilla_gift["is_special_gift"]), "priscilla_gift is a special gift")
