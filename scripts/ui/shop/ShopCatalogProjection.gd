class_name ShopCatalogProjection
extends RefCounted

## Presentation boundary for a trusted catalog owner. Texture dimensions do not
## attest provenance; that owner must resolve the lawful same-item art pair and
## supply authored localized copy. No direct DataCatalog/GameState consumption.
## Dictionaries/scalars detach; art resources are immutable owner-retained references.

const _ORDER := [
	"wine", "pineapple_bun", "quiet_tea",
	"soft_blanket", "weighted_plush", "spa_coupon", "supportz",
	"premium_care", "lucky_charm",
	"debug_key", "bookend_keepsake", "metronome_keepsake",
	"pocket_calculator_keepsake",
]

const _CATALOG := {
	"wine": [55, "money", true],
	"pineapple_bun": [10, "money", true],
	"quiet_tea": [15, "money", true],
	"soft_blanket": [25, "money", true],
	"weighted_plush": [35, "money", true],
	"spa_coupon": [45, "money", false],
	"premium_care": [1, "minesweeper_coin", true],
	"lucky_charm": [1, "minesweeper_coin", false],
	"debug_key": [3, "minesweeper_coin", false],
	"bookend_keepsake": [3, "minesweeper_coin", false],
	"metronome_keepsake": [3, "minesweeper_coin", false],
	"pocket_calculator_keepsake": [3, "minesweeper_coin", false],
}


static func project(items: Array, supportz_eligible: bool = false) -> Dictionary:
	if items.size() != _CATALOG.size():
		return _failure("invalid_item_count")

	var by_id: Dictionary = {}
	for candidate: Variant in items:
		if typeof(candidate) != TYPE_DICTIONARY:
			return _failure("invalid_item_type")
		var item: Dictionary = candidate
		var validation_code := _validate_item(item)
		if not validation_code.is_empty():
			return _failure(validation_code)
		var item_id: String = item["id"]
		if by_id.has(item_id):
			return _failure("duplicate_item_id")
		by_id[item_id] = item

	if by_id.size() != _CATALOG.size():
		return _failure("invalid_catalog")

	var value: Array = []
	for item_id: String in _ORDER:
		if item_id == "supportz":
			value.append({
				"id": "supportz",
				"blank": true,
				"actionable": supportz_eligible,
			})
			continue
		if not by_id.has(item_id):
			return _failure("missing_item_id")
		value.append(_public_item(by_id[item_id]))
	return {"ok": true, "code": "", "value": value}


static func _validate_item(item: Dictionary) -> String:
	const REQUIRED := [
		"id", "name", "unit_price", "currency", "available", "batchable",
		"legal_max", "card_art", "inspector_art",
	]
	for key: String in REQUIRED:
		if not item.has(key):
			return "missing_field"
	if typeof(item["id"]) != TYPE_STRING:
		return "invalid_id"
	var item_id: String = item["id"]
	if not _CATALOG.has(item_id):
		return "unknown_item_id"
	if typeof(item["name"]) != TYPE_STRING or (item["name"] as String).is_empty():
		return "invalid_name"
	if typeof(item["unit_price"]) != TYPE_INT:
		return "invalid_unit_price"
	if typeof(item["currency"]) != TYPE_STRING:
		return "invalid_currency"
	if typeof(item["available"]) != TYPE_BOOL:
		return "invalid_available"
	if typeof(item["batchable"]) != TYPE_BOOL:
		return "invalid_batchable"
	if typeof(item["legal_max"]) != TYPE_INT or int(item["legal_max"]) < 0:
		return "invalid_legal_max"
	if not item["available"] and item["legal_max"] != 0:
		return "invalid_legal_max"
	if not item["batchable"] and item["legal_max"] > 1:
		return "invalid_legal_max"
	if item.has("description") and typeof(item["description"]) != TYPE_STRING:
		return "invalid_description"

	var expected: Array = _CATALOG[item_id]
	if item["unit_price"] != expected[0]:
		return "invalid_unit_price"
	# UI totals must remain exact integer prices, even for malformed owner maxima.
	@warning_ignore("integer_division")
	var largest_quantity: int = 9223372036854775807 / int(item["unit_price"])
	if item["legal_max"] > largest_quantity:
		return "invalid_legal_max"
	if item["currency"] != expected[1]:
		return "invalid_currency"
	if item["batchable"] != expected[2]:
		return "invalid_batchable"
	if not _valid_texture(item["card_art"], Vector2i(28, 28)):
		return "invalid_card_art"
	if not _valid_texture(item["inspector_art"], Vector2i(56, 56)):
		return "invalid_inspector_art"
	return ""


static func _valid_texture(value: Variant, expected_size: Vector2i) -> bool:
	return value is Texture2D and (value as Texture2D).get_size() == Vector2(expected_size)


static func _public_item(item: Dictionary) -> Dictionary:
	var result := {
		"id": item["id"],
		"name": item["name"],
		"unit_price": item["unit_price"],
		"currency": item["currency"],
		"available": item["available"],
		"batchable": item["batchable"],
		"legal_max": item["legal_max"],
		"card_art": item["card_art"],
		"inspector_art": item["inspector_art"],
		"blank": false,
	}
	if item.has("description"):
		result["description"] = item["description"]
	return result


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code, "value": []}

