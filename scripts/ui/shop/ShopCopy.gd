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
	"ja": "ja",
	"ko": "ko",
}

const _TEXT := {
	"en": {
		"previous": "Previous", "next": "Next", "available": "Available",
		"sold_out": "Sold out", "minimum": "MIN", "maximum": "MAX",
		"minus": "Minus", "plus": "Plus", "quantity": "Quantity", "buy": "Buy",
		"unavailable": "Unavailable", "information": "Item information",
		"blank_card": "Blank shop card", "no": "No", "yes": "Yes",
		"confirmation": "Purchase confirmation",
		"retry_purchase": "Unable to finish saving. Try again.",
	},
	"zh_CN": {
		"previous": "上一页", "next": "下一页", "available": "有货",
		"sold_out": "售罄", "minimum": "最小", "maximum": "最大",
		"minus": "减少", "plus": "增加", "quantity": "数量", "buy": "购买",
		"unavailable": "不可购买", "information": "商品信息",
		"blank_card": "空白商店卡片", "no": "否", "yes": "是",
		"confirmation": "确认购买",
		"retry_purchase": "无法完成保存。请重试。",
	},
	"zh_HK": {
		"previous": "上一頁", "next": "下一頁", "available": "有貨",
		"sold_out": "售罄", "minimum": "最小", "maximum": "最大",
		"minus": "減少", "plus": "增加", "quantity": "數量", "buy": "購買",
		"unavailable": "不可購買", "information": "商品資訊",
		"blank_card": "空白商店卡片", "no": "否", "yes": "是",
		"confirmation": "確認購買",
		"retry_purchase": "無法完成儲存。請重試。",
	},
	"ja": {"previous": "前へ", "next": "次へ", "available": "在庫あり", "sold_out": "売り切れ", "minimum": "最小", "maximum": "最大", "minus": "減らす", "plus": "増やす", "quantity": "数量", "buy": "購入", "unavailable": "購入不可", "information": "商品情報", "blank_card": "空の商品カード", "no": "いいえ", "yes": "はい", "confirmation": "購入の確認", "retry_purchase": "保存を完了できません。もう一度お試しください。"},
	"ko": {"previous": "이전", "next": "다음", "available": "재고 있음", "sold_out": "품절", "minimum": "최소", "maximum": "최대", "minus": "줄이기", "plus": "늘리기", "quantity": "수량", "buy": "구매", "unavailable": "구매 불가", "information": "상품 정보", "blank_card": "빈 상품 카드", "no": "아니요", "yes": "예", "confirmation": "구매 확인", "retry_purchase": "저장을 완료할 수 없어요. 다시 시도해 주세요."},
}

const _ITEM_NAMES := {
	"en": {
		"crystal_stutters": "crystal stutters",
		"inked_silk_string": "inked silk string",
		"letter_with_wax_seal": "letter with wax seal",
		"lucky_charm": "Lucky Charm",
		"debug_key": "Debug Key",
		"bookend_keepsake": "Bookend",
		"metronome_keepsake": "Metronome",
		"pocket_calculator_keepsake": "Pocket Calculator"
	},
	"zh_CN": {
		"crystal_stutters": "水晶碎光",
		"inked_silk_string": "墨染丝线",
		"letter_with_wax_seal": "火漆封缄信",
		"lucky_charm": "幸运符",
		"debug_key": "调试键",
		"bookend_keepsake": "书挡",
		"metronome_keepsake": "节拍器",
		"pocket_calculator_keepsake": "袖珍计算器"
	},
	"zh_HK": {
		"crystal_stutters": "水晶碎光",
		"inked_silk_string": "墨染絲線",
		"letter_with_wax_seal": "火漆封緘信",
		"lucky_charm": "幸運符",
		"debug_key": "除錯鍵",
		"bookend_keepsake": "書擋",
		"metronome_keepsake": "節拍器",
		"pocket_calculator_keepsake": "袖珍計算器"
	},
	"ja": {
		"crystal_stutters": "水晶のさざめき",
		"inked_silk_string": "墨染めの絹糸",
		"letter_with_wax_seal": "封蝋付きの手紙",
		"lucky_charm": "幸運のお守り",
		"debug_key": "デバッグキー",
		"bookend_keepsake": "ブックエンド",
		"metronome_keepsake": "メトロノーム",
		"pocket_calculator_keepsake": "ポケット電卓"
	},
	"ko": {
		"crystal_stutters": "수정의 속삭임",
		"inked_silk_string": "먹빛 비단실",
		"letter_with_wax_seal": "밀랍 봉인 편지",
		"lucky_charm": "행운의 부적",
		"debug_key": "디버그 키",
		"bookend_keepsake": "북엔드",
		"metronome_keepsake": "메트로놈",
		"pocket_calculator_keepsake": "휴대용 계산기"
	}
}


const _ITEM_DESCRIPTIONS := {
	"en": {
		"crystal_stutters": "A keepsake stored in your inventory. No decorative effect.",
		"inked_silk_string": "A keepsake stored in your inventory. No decorative effect.",
		"letter_with_wax_seal": "A keepsake stored in your inventory. No decorative effect.",
	},
	"zh_CN": {
		"crystal_stutters": "存放于物品栏的纪念品，不会产生装饰效果。",
		"inked_silk_string": "存放于物品栏的纪念品，不会产生装饰效果。",
		"letter_with_wax_seal": "存放于物品栏的纪念品，不会产生装饰效果。",
	},
	"zh_HK": {
		"crystal_stutters": "存放於物品欄的紀念品，不會產生裝飾效果。",
		"inked_silk_string": "存放於物品欄的紀念品，不會產生裝飾效果。",
		"letter_with_wax_seal": "存放於物品欄的紀念品，不會產生裝飾效果。",
	},
	"ja": {
		"crystal_stutters": "インベントリに保管する記念品です。装飾効果はありません。",
		"inked_silk_string": "インベントリに保管する記念品です。装飾効果はありません。",
		"letter_with_wax_seal": "インベントリに保管する記念品です。装飾効果はありません。",
	},
	"ko": {
		"crystal_stutters": "인벤토리에 보관하는 기념품입니다. 장식 효과는 없습니다.",
		"inked_silk_string": "인벤토리에 보관하는 기념품입니다. 장식 효과는 없습니다.",
		"letter_with_wax_seal": "인벤토리에 보관하는 기념품입니다. 장식 효과는 없습니다.",
	},
}


static func item_description(locale: String, item_id: String) -> String:
	return _ITEM_DESCRIPTIONS.get(_locale_id(locale), {}).get(item_id, "")


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
	if locale_id == "ja":
		return "%d コイン" % amount
	if locale_id == "ko":
		return "%d 코인" % amount
	if locale_id == "zh_CN":
		return "%d 枚硬币" % amount
	return "%d 枚硬幣" % amount


static func _locale_id(locale: String) -> String:
	return _LOCALE_ALIASES.get(locale, "")

