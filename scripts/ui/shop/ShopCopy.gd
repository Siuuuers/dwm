class_name ShopCopy
extends RefCounted
## UI-authored generic working translations. ShopApp still consumes owner-supplied
## record names; this helper never replaces missing live catalog copy or art.

const _LOCALE_ALIASES := {
	"en": "en",
	"zh_CN": "zh_CN",
	"zh-CN": "zh_CN",
	"zh_HK": "zh_HK",
	"zh-HK": "zh_HK",
}

const _TEXT := {
	"en": {
		"previous": "Previous", "next": "Next", "available": "Available",
		"sold_out": "Sold out", "minimum": "MIN", "maximum": "MAX",
		"minus": "Minus", "plus": "Plus", "quantity": "Quantity", "buy": "Buy",
		"unavailable": "Unavailable", "information": "Item information",
		"blank_card": "Blank shop card", "no": "No", "yes": "Yes",
	},
	"zh_CN": {
		"previous": "上一页", "next": "下一页", "available": "有货",
		"sold_out": "售罄", "minimum": "最小", "maximum": "最大",
		"minus": "减少", "plus": "增加", "quantity": "数量", "buy": "购买",
		"unavailable": "不可购买", "information": "商品信息",
		"blank_card": "空白商店卡片", "no": "否", "yes": "是",
	},
	"zh_HK": {
		"previous": "上一頁", "next": "下一頁", "available": "有貨",
		"sold_out": "售罄", "minimum": "最小", "maximum": "最大",
		"minus": "減少", "plus": "增加", "quantity": "數量", "buy": "購買",
		"unavailable": "不可購買", "information": "商品資訊",
		"blank_card": "空白商店卡片", "no": "否", "yes": "是",
	},
}

const _ITEM_NAMES := {
	"en": {
		"coffee": "Coffee", "wine": "Wine", "pineapple_bun": "Pineapple Bun",
		"bandage_pack": "Bandage Pack", "quiet_tea": "Quiet Tea",
		"soft_blanket": "Soft Blanket", "weighted_plush": "Weighted Plush",
		"spa_coupon": "Spa Coupon", "healthy_meal": "Healthy Meal",
		"protein_box": "Protein Box", "pep_note": "Pep Note",
		"premium_care": "Premium Care", "lucky_charm": "Lucky Charm",
		"debug_key": "Debug Key", "bookend_keepsake": "Bookend",
		"metronome_keepsake": "Metronome",
		"pocket_calculator_keepsake": "Pocket Calculator",
	},
	"zh_CN": {
		"coffee": "咖啡", "wine": "葡萄酒", "pineapple_bun": "菠萝包",
		"bandage_pack": "绷带包", "quiet_tea": "清茶", "soft_blanket": "柔软毛毯",
		"weighted_plush": "加重毛绒玩具", "spa_coupon": "水疗券",
		"healthy_meal": "健康餐", "protein_box": "蛋白质餐盒", "pep_note": "短笺",
		"premium_care": "高级护理用品", "lucky_charm": "幸运符",
		"debug_key": "调试键", "bookend_keepsake": "书挡",
		"metronome_keepsake": "节拍器",
		"pocket_calculator_keepsake": "袖珍计算器",
	},
	"zh_HK": {
		"coffee": "咖啡", "wine": "葡萄酒", "pineapple_bun": "菠蘿包",
		"bandage_pack": "繃帶包", "quiet_tea": "清茶", "soft_blanket": "柔軟毛毯",
		"weighted_plush": "加重毛絨玩具", "spa_coupon": "水療券",
		"healthy_meal": "健康餐", "protein_box": "蛋白質餐盒", "pep_note": "短箋",
		"premium_care": "高級護理用品", "lucky_charm": "幸運符",
		"debug_key": "除錯鍵", "bookend_keepsake": "書擋",
		"metronome_keepsake": "節拍器",
		"pocket_calculator_keepsake": "袖珍計算器",
	},
}


static func text(locale: String, key: String) -> String:
	var locale_id: String = _locale_id(locale)
	if locale_id.is_empty() or not _TEXT[locale_id].has(key):
		return ""
	return _TEXT[locale_id][key]


static func item_name(locale: String, item_id: String) -> String:
	var locale_id: String = _locale_id(locale)
	if locale_id.is_empty() or not _ITEM_NAMES[locale_id].has(item_id):
		return ""
	return _ITEM_NAMES[locale_id][item_id]


static func price(locale: String, amount: int, currency: String) -> String:
	var locale_id: String = _locale_id(locale)
	if locale_id.is_empty():
		return ""
	if currency == "money":
		return "$%d" % amount
	if currency != "minesweeper_coin":
		return ""
	if locale_id == "en":
		return "%d coin%s" % [amount, "" if amount == 1 else "s"]
	if locale_id == "zh_CN":
		return "%d 枚硬币" % amount
	return "%d 枚硬幣" % amount


static func _locale_id(locale: String) -> String:
	return _LOCALE_ALIASES.get(locale, "")
