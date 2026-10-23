extends "res://addons/gut/test.gd"

const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const ITEM_IDS := [
	"wine", "pineapple_bun", "quiet_tea",
	"soft_blanket", "weighted_plush", "spa_coupon",
	"premium_care", "lucky_charm", "debug_key", "bookend_keepsake",
	"metronome_keepsake", "pocket_calculator_keepsake",
]


func test_english_labels_and_generic_item_names_are_exact() -> void:
	var labels := {
		"previous": "Previous", "next": "Next", "available": "Available",
		"sold_out": "Sold out", "minimum": "MIN", "maximum": "MAX",
		"minus": "Minus", "plus": "Plus", "quantity": "Quantity", "buy": "Buy",
		"unavailable": "Unavailable", "information": "Item information",
		"blank_card": "Blank shop card", "no": "No", "yes": "Yes",
	}
	for key: String in labels:
		assert_eq(COPY.text("en", key), labels[key], key)
	assert_eq(COPY.item_name("en", "bookend_keepsake"), "Bookend")
	assert_eq(COPY.item_name("en", "metronome_keepsake"), "Metronome")
	assert_eq(COPY.item_name("en", "pocket_calculator_keepsake"), "Pocket Calculator")


func test_all_twelve_ordinary_names_exist_in_every_locale_and_aliases_work() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		for item_id: String in ITEM_IDS:
			assert_false(COPY.item_name(locale, item_id).is_empty(), "%s %s" % [locale, item_id])
	assert_eq(COPY.item_name("zh-CN", "wine"), COPY.item_name("zh_CN", "wine"))
	assert_eq(COPY.item_name("zh-HK", "wine"), COPY.item_name("zh_HK", "wine"))
	assert_eq(COPY.text("zh-CN", "previous"), COPY.text("zh_CN", "previous"))


func test_blank_capacity_and_unknown_inputs_never_gain_fallback_copy() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK", "zh-CN", "zh-HK"]:
		assert_eq(COPY.item_name(locale, "supportz"), "")
	assert_eq(COPY.item_name("en", "unknown"), "")
	assert_eq(COPY.item_name("fr", "wine"), "")
	assert_eq(COPY.text("en", "unknown"), "")
	assert_eq(COPY.text("fr", "previous"), "")


func test_money_and_coin_prices_are_locale_exact() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK", "zh-CN", "zh-HK"]:
		assert_eq(COPY.price(locale, 55, "money"), "$55")
	assert_eq(COPY.price("en", 1, "minesweeper_coin"), "1 coin")
	assert_eq(COPY.price("en", 3, "minesweeper_coin"), "3 coins")
	assert_eq(COPY.price("zh_CN", 3, "minesweeper_coin"), "3 枚硬币")
	assert_eq(COPY.price("zh_HK", 3, "minesweeper_coin"), "3 枚硬幣")
	assert_eq(COPY.price("zh-CN", 1, "minesweeper_coin"), "1 枚硬币")
	assert_eq(COPY.price("en", 3, "unknown"), "")
	assert_eq(COPY.price("fr", 3, "money"), "")


func test_retired_items_have_no_copy_in_any_locale() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		for item_id: String in ["coffee", "pep_note", "bandage_pack", "healthy_meal", "protein_box"]:
			assert_eq(COPY.item_name(locale, item_id), "")
