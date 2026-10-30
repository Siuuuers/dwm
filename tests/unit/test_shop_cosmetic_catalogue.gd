extends GutTest

const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const ART := preload("res://scripts/ui/shop/ShopItemArt.gd")
const KEEPSAKES := ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]

func test_nine_items_keep_inventory_only_effects_and_requested_order() -> void:
	var catalog := CATALOG.new()
	var ids: Array = []
	for item in catalog.get_shop_items(): ids.append(item.id)
	assert_eq(ids, ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal",
		"lavinia_gift", "sylvia_gift", "priscilla_gift", "lucky_charm", "debug_key", "supportz"])
	for id: String in KEEPSAKES:
		var item: Dictionary = catalog.get_shop_item(id)
		assert_eq(item.price, 45)
		assert_eq(item.currency, "money")
		assert_eq(item.max_purchases, 1)
		assert_eq(item.effect_ids, ["inventory:add:" + id])
		for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
			assert_false(COPY.item_name(locale, id).is_empty())
			assert_false(COPY.item_description(locale, id).is_empty())
		for size: int in [28, 56]: assert_not_null(ART.texture(id, size))

func test_capability_art_matches_pre_pr_one_fallback_tiles() -> void:
	for pair: Array in [["lucky_charm", "weighted_plush"], ["debug_key", "bandage_pack"]]:
		var hue := float(abs(str(pair[1]).hash()) % 360) / 360.0
		for size: int in [28, 56]:
			var actual: Image = ART.texture(pair[0], size).get_image()
			var expected := Image.create(size, size, false, Image.FORMAT_RGBA8)
			expected.fill(Color.from_hsv(hue, 0.28, 0.78, 1.0))
			var edge := Color.from_hsv(hue, 0.5, 0.34, 1.0)
			for coordinate: int in size:
				expected.set_pixel(coordinate, 0, edge)
				expected.set_pixel(coordinate, size - 1, edge)
				expected.set_pixel(0, coordinate, edge)
				expected.set_pixel(size - 1, coordinate, edge)
			assert_eq(actual.get_data(), expected.get_data())
