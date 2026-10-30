extends GutTest

const CATALOG := preload("res://scripts/data/DataCatalog.gd")
const COPY := preload("res://scripts/ui/shop/ShopCopy.gd")
const ART := preload("res://scripts/ui/shop/ShopItemArt.gd")
const RETIRED := ["crystal_stutters", "inked_silk_string", "letter_with_wax_seal"]

func test_current_catalogue_keeps_six_items_and_excludes_retired_decorations() -> void:
	var catalog := CATALOG.new()
	var ids: Array = []
	for item in catalog.get_shop_items(): ids.append(item.id)
	assert_eq(ids, ["lucky_charm", "debug_key", "priscilla_gift", "lavinia_gift", "sylvia_gift", "supportz"])
	for id: String in RETIRED:
		assert_true(catalog.get_shop_item(id).is_empty())
		for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
			assert_true(COPY.item_description(locale, id).is_empty())
		for size: int in [28, 56]: assert_null(ART.texture(id, size))
	assert_eq(catalog.get_shop_item("lucky_charm").price, 1)
	for id: String in ["debug_key", "priscilla_gift", "lavinia_gift", "sylvia_gift"]:
		assert_eq(catalog.get_shop_item(id).price, 3)
	assert_true(catalog.get_shop_item("supportz").is_secret_buy_button)
