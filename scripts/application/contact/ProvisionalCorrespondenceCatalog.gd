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
	return catalog.duplicate(true)


static func _put(catalog: Dictionary, message_id: String, kind: String) -> void:
	catalog[message_id] = {
		"outgoing": false,
		"texts": (_COPY[kind] as Dictionary).duplicate(true),
	}