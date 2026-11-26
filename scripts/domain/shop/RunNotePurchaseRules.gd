extends RefCounted

const ITEM_IDS: Array[String] = [
	"crystal_stutters",
	"inked_silk_string",
	"letter_with_wax_seal",
]
const PURCHASE_CAP: int = 3


static func validate_counts(counts: Variant) -> Dictionary:
	if typeof(counts) != TYPE_DICTIONARY:
		return _refuse("invalid_counts")
	var supplied_counts: Dictionary = counts
	var detached_counts: Dictionary = {}
	for key: Variant in supplied_counts:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			return _refuse("invalid_counts")
		var normalized_key: String = String(key)
		if detached_counts.has(normalized_key):
			return _refuse("invalid_counts")
		var count: Variant = supplied_counts[key]
		if typeof(count) != TYPE_INT or count < 0:
			return _refuse("invalid_counts")
		if ITEM_IDS.has(normalized_key) and count > PURCHASE_CAP:
			return _refuse("invalid_counts")
		detached_counts[normalized_key] = count
	return _accept({"shop_purchase_counts": detached_counts})


static func _accept(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": "", "value": value}


static func _refuse(code: String) -> Dictionary:
	return {"ok": false, "code": code, "value": {}}
