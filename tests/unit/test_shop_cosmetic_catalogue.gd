extends GutTest

const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const RULES := preload("res://scripts/domain/shop/SceneShopPurchaseRules.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const ART := preload("res://scripts/ui/shop/ShopItemArt.gd")
const COSMETICS := ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]

func test_current_catalogue_has_nine_items_with_supportz_last() -> void:
	var catalog := CATALOG.new()
	var ids: Array = []
	for item in catalog.get_shop_items(): ids.append(item.id)
	assert_eq(ids, COSMETICS + ["lucky_charm", "debug_key", "priscilla_gift", "lavinia_gift", "sylvia_gift", "supportz"])
	for id: String in COSMETICS:
		var item: Dictionary = catalog.get_shop_item(id)
		assert_eq(item.price, 45)
		assert_eq(item.currency, "money")
		assert_eq(item.max_purchases, 1)
		assert_eq(item.effect_ids, ["inventory:add:" + id])
	assert_eq(catalog.get_shop_item("lucky_charm").price, 1)
	for id: String in ["debug_key", "priscilla_gift", "lavinia_gift", "sylvia_gift"]:
		assert_eq(catalog.get_shop_item(id).price, 3)
	assert_true(catalog.get_shop_item("supportz").is_secret_buy_button)

func test_each_cosmetic_spends_once_and_leaves_stats_and_notes_unchanged() -> void:
	var catalog := CATALOG.new()
	var gameplay := {"money": 200, "coins": 4, "minesweeper_round_floor": 0,
		"stats": {"pressure": 3}, "inventory": {}, "shop_purchase_counts": {"crystal_stutters": 2}}
	for id: String in COSMETICS:
		var before := gameplay.duplicate(true)
		var item: Dictionary = catalog.get_shop_item(id)
		var result: Dictionary = RULES.prepare(gameplay, item, 1)
		assert_true(result.ok, str(result))
		if not result.ok: return
		gameplay = result.value.gameplay
		assert_eq(gameplay.money, before.money - 45)
		assert_eq(gameplay.inventory[id], 1)
		assert_eq(gameplay.stats, before.stats)
		assert_eq(gameplay.shop_purchase_counts, before.shop_purchase_counts)
		assert_eq(RULES.prepare(gameplay, item, 1).code, &"item_already_owned")
	assert_eq(gameplay.money, 65)
	assert_eq(gameplay.inventory.size(), 3)

func test_cosmetic_names_descriptions_and_art_are_available_in_all_ui_locales() -> void:
	assert_eq(COPY.item_name("en", "crystal_stutters"), "crystal stutters")
	for id: String in COSMETICS:
		for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
			assert_false(COPY.item_name(locale, id).is_empty())
			assert_false(COPY.item_description(locale, id).is_empty())
		for size: int in [28, 56]:
			var texture: Texture2D = ART.texture(id, size)
			assert_not_null(texture)
			if texture == null: return
			assert_eq(texture.get_size(), Vector2(size, size))
			assert_true(texture.get_image().get_used_rect().has_area())
