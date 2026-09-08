class_name ProvisionalCorrespondenceCatalog
extends RefCounted

## Minimal functional correspondence authorized for the playable foundation. This is provisional
## interface copy, not canonical story dialogue; it covers only the fixed message identities the
## current Contacts state machine can emit.

const _SOLO_DAYS := {
	"priscilla": [1, 2, 4, 6, 7],
	"lavinia": [2, 3, 5, 6, 7],
	"sylvia": [1, 3, 4, 5, 7],
}
const _GROUP_DAYS := [2, 6]
const _GROUP_FRIENDS := ["priscilla", "lavinia"]
const _COPY := {
	"hospital_explanation": {"en": "I was in hospital yesterday. That's why I couldn't make it.", "zh-CN": "\u6211\u6628\u5929\u4f4f\u9662\u4e86\uff0c\u6240\u4ee5\u6ca1\u80fd\u8d74\u7ea6\u3002", "zh-HK": "\u6211\u6628\u5929\u4f4f\u9662\u4e86\uff0c\u6240\u4ee5\u6c92\u80fd\u8d74\u7d04\u3002"},
	"hospital_priscilla": {"en": "Tell me next time. I can help you make arrangements.", "zh-CN": "\u4e0b\u6b21\u5148\u544a\u8bc9\u6211\u3002\u6211\u53ef\u4ee5\u5e2e\u4f60\u5b89\u6392\u3002", "zh-HK": "\u4e0b\u6b21\u5148\u544a\u8a34\u6211\u3002\u6211\u53ef\u4ee5\u5e6b\u4f60\u5b89\u6392\u3002"},
	"hospital_lavinia": {"en": "Get some rest. We can meet when you're feeling better.", "zh-CN": "\u4f60\u5148\u4f11\u606f\u3002\u7b49\u4f60\u597d\u4e9b\u4e86\uff0c\u6211\u4eec\u518d\u89c1\u3002", "zh-HK": "\u4f60\u5148\u4f11\u606f\u3002\u7b49\u4f60\u597d\u4e9b\u4e86\uff0c\u6211\u5011\u518d\u898b\u3002"},
	"hospital_care": {"en": "I wanted to check on you after yesterday. Please take it gently today. I'm here if you need me.", "zh-CN": "\u60f3\u95ee\u95ee\u4f60\u6628\u5929\u4e4b\u540e\u600e\u4e48\u6837\u4e86\u3002\u4eca\u5929\u6162\u6162\u6765\uff0c\u9700\u8981\u6211\u5c31\u544a\u8bc9\u6211\u3002", "zh-HK": "\u60f3\u554f\u554f\u4f60\u6628\u5929\u4e4b\u5f8c\u600e\u9ebc\u6a23\u4e86\u3002\u4eca\u5929\u6162\u6162\u4f86\uff0c\u9700\u8981\u6211\u5c31\u544a\u8a34\u6211\u3002"},
	"solo_offer": {
		"en": "Would you like to meet today?",
		"zh-CN": "今天想一起见面吗？",
		"zh-HK": "今日想一起見面嗎？",
	},
	"group_offer": {
		"en": "Would you like to meet up with us today?",
		"zh-CN": "今天想和我们一起见面吗？",
		"zh-HK": "今日想和我們一起見面嗎？",
	},
	"nevermind": {
		"en": "No worries. Maybe another day.",
		"zh-CN": "没关系。改天再约吧。",
		"zh-HK": "沒關係。改日再約吧。",
	},
	"missed_question": {
		"en": "I missed you today. Is everything okay?",
		"zh-CN": "今天没见到你。还好吗？",
		"zh-HK": "今日沒見到你。還好嗎？",
	},
	"busy": {
		"en": "It looks like today is busy. Maybe next time.",
		"zh-CN": "看来今天很忙。下次再约吧。",
		"zh-HK": "看來今日很忙。下次再約吧。",
	},
	"judge": {
		"en": "Please answer both of us next time.",
		"zh-CN": "下次请记得回复我们两个人。",
		"zh-HK": "下次請記得回覆我們兩個人。",
	},
}


static func build() -> Dictionary:
	var catalog: Dictionary = {}
	for friend: String in _SOLO_DAYS:
		for day_value: Variant in _SOLO_DAYS[friend]:
			var day := int(day_value)
			_put(catalog, "solo:%s:day%d" % [friend, day], "solo_offer")
			if day < 7:
				_put(catalog, "nevermind:%s:day%d" % [friend, day + 1], "nevermind")
				_put(catalog, "missed_question:%s:day%d" % [friend, day + 1],
					"missed_question")
	for day_value: Variant in _GROUP_DAYS:
		var day := int(day_value)
		for friend: String in _GROUP_FRIENDS:
			_put(catalog, "group_offer:priscilla_lavinia:day%d:%s" % [day, friend],
				"group_offer")
			_put(catalog, "busy:%s:day%d" % [friend, day + 1], "busy")
			_put(catalog, "nevermind:%s:day%d" % [friend, day + 1], "nevermind")
			_put(catalog, "judge:%s:day%d" % [friend, day + 1], "judge")
	for care_day: int in [2, 4, 5, 6]:
		_put(catalog, "care.sylvia.day%d" % care_day, "hospital_care")
	# Provisional reactions share the existing missed-question identity and durable
	# Hospital miss receipt; they do not create duplicate queued messages or choices.
	for friend: String in _GROUP_FRIENDS:
		for source_day: int in _SOLO_DAYS[friend]:
			if source_day == 7: continue
			var id := "missed_question:%s:day%d" % [friend, source_day + 1]
			catalog[id]["hospital_followup"] = {
				"explanation": {"outgoing": true, "texts": _COPY.hospital_explanation.duplicate(true)},
				"reaction": {"outgoing": false, "texts": _COPY["hospital_" + friend].duplicate(true)}}
	return catalog.duplicate(true)


static func _put(catalog: Dictionary, message_id: String, kind: String) -> void:
	catalog[message_id] = {
		"outgoing": false,
		"texts": (_COPY[kind] as Dictionary).duplicate(true),
	}