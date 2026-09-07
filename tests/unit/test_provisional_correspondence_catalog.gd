extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const CATALOG_PATH := "res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd"
const FRIEND_DAYS := {
	"priscilla": [1,2,4,6,7],
	"lavinia": [2,3,5,6,7],
	"sylvia": [1,3,4,5,7],
}

var _script: Script


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(CATALOG_PATH)
	_script = loaded.get("value") if loaded.get("ok",false) else null


func _require_catalog() -> bool:
	assert_not_null(_script,"The provisional correspondence catalog must exist")
	return _script != null


func test_catalog_covers_every_reachable_fixed_message_identity() -> void:
	if not _require_catalog(): return
	var catalog: Dictionary = _script.build()
	var actual: Array = catalog.keys()
	actual.sort()
	var expected := _expected_ids()
	assert_eq(actual,expected)
	assert_eq(actual.size(),51)


func test_every_entry_is_localized_plain_incoming_copy_without_identity_leakage() -> void:
	if not _require_catalog(): return
	var catalog: Dictionary = _script.build()
	for message_id: String in catalog:
		var row: Dictionary = catalog[message_id]
		var keys: Array = row.keys()
		keys.sort()
		assert_eq(keys,["outgoing","texts"],message_id)
		assert_false(row.outgoing,message_id)
		var locales: Array = row.texts.keys()
		locales.sort()
		assert_eq(locales,["en","zh-CN","zh-HK"],message_id)
		for locale: String in locales:
			var body: String = row.texts[locale]
			assert_false(body.strip_edges().is_empty(),message_id+":"+locale)
			assert_false(body.contains(message_id),"internal message identity leaked into copy")
			assert_false(body.contains("priscilla_lavinia"),"internal pair identity leaked into copy")


func test_build_returns_detached_catalog_bytes() -> void:
	if not _require_catalog(): return
	var first: Dictionary = _script.build()
	var second: Dictionary = _script.build()
	var id: String = first.keys()[0]
	first[id].texts.en = "caller mutation"
	assert_ne(second[id].texts.en,"caller mutation")


func _expected_ids() -> Array:
	var unique: Dictionary = {}
	for friend: String in FRIEND_DAYS:
		for day: int in FRIEND_DAYS[friend]:
			unique["solo:%s:day%d" % [friend,day]] = true
			if day < 7:
				unique["nevermind:%s:day%d" % [friend,day+1]] = true
				unique["missed_question:%s:day%d" % [friend,day+1]] = true
	for day: int in [2,6]:
		for friend: String in ["priscilla","lavinia"]:
			unique["group_offer:priscilla_lavinia:day%d:%s" % [day,friend]] = true
			unique["busy:%s:day%d" % [friend,day+1]] = true
			unique["nevermind:%s:day%d" % [friend,day+1]] = true
			unique["judge:%s:day%d" % [friend,day+1]] = true
	var ids: Array = unique.keys()
	ids.sort()
	return ids