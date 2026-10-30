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

func test_capability_art_matches_september_21_illustrations() -> void:
	# Frozen RGBA signatures from the original 8630b25b drawings.
	var signatures := {
		"lucky_charm": "8f70af7c1339c4a0e06d6b6eb03708930fd7c1b6f04ff90ebee0ee24f669fb35",
		"debug_key": "975b8621abb80c24add0c9aad16d0b2ce8e8c6885f3689853eeb9c4ce4c33700",
	}
	for id: String in signatures:
		var actual: Image = ART.texture(id, 28).get_image()
		assert_eq(actual.get_data().hex_encode().sha256_text(), signatures[id], id)
