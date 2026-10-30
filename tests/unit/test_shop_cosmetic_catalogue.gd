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
	# Original 8630b25b RGBA signatures, including Godot's transparent-white surround.
	var signatures := {
		"lucky_charm": "cd8b20a974cf74a9550aa7b168a5d03fc2461206942716cc75f5573c64331c7e",
		"debug_key": "ba911428ff291657d9118437e9152747b818199ae43f8afb2f462445f9b379ba",
	}
	for id: String in signatures:
		var actual: Image = ART.texture(id, 28).get_image()
		assert_eq(actual.get_data().hex_encode().sha256_text(), signatures[id], id)
