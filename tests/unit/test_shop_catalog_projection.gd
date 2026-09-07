extends "res://addons/gut/test.gd"

const CATALOG_PROJECTION := preload("res://scripts/ui/shop/ShopCatalogProjection.gd")

const ORDER := [
	"coffee", "wine", "pineapple_bun", "bandage_pack", "quiet_tea",
	"soft_blanket", "weighted_plush", "spa_coupon", "supportz",
	"healthy_meal", "protein_box", "pep_note", "premium_care", "lucky_charm",
	"debug_key", "bookend_keepsake", "metronome_keepsake",
	"pocket_calculator_keepsake",
]
const SPECS := {
	"coffee": [20, "money", true], "wine": [55, "money", true],
	"pineapple_bun": [10, "money", true], "bandage_pack": [15, "money", true],
	"quiet_tea": [15, "money", true], "soft_blanket": [25, "money", true],
	"weighted_plush": [35, "money", true], "spa_coupon": [45, "money", false],
	"healthy_meal": [25, "money", true], "protein_box": [35, "money", true],
	"pep_note": [10, "money", true], "premium_care": [1, "minesweeper_coin", true],
	"lucky_charm": [1, "minesweeper_coin", false],
	"debug_key": [3, "minesweeper_coin", false],
	"bookend_keepsake": [3, "minesweeper_coin", false],
	"metronome_keepsake": [3, "minesweeper_coin", false],
	"pocket_calculator_keepsake": [3, "minesweeper_coin", false],
}


func test_shuffled_owner_rows_are_reordered_and_private_keys_are_removed() -> void:
	var rows := _valid_rows()
	rows.reverse()
	rows[0]["effect_ids"] = ["secret"]
	rows[0]["purchase_count"] = 99
	var result: Dictionary = CATALOG_PROJECTION.project(rows)

	assert_true(result["ok"])
	assert_eq(_ids(result["value"]), ORDER)
	var projected: Dictionary = result["value"][17]
	assert_eq(projected.keys().size(), 10)
	assert_false(projected.has("effect_ids"))
	assert_false(projected.has("purchase_count"))
	var allowed := ["id", "name", "unit_price", "currency", "available", "batchable", "legal_max", "card_art", "inspector_art", "blank"]
	allowed.sort()
	for record: Dictionary in result.value:
		if record.blank: continue
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, allowed)


func test_rejects_missing_duplicate_unknown_and_old_keepsake_ids() -> void:
	var missing := _valid_rows()
	missing.pop_back()
	assert_false(CATALOG_PROJECTION.project(missing)["ok"])

	var duplicate := _valid_rows()
	duplicate[16] = duplicate[0].duplicate()
	assert_eq(CATALOG_PROJECTION.project(duplicate)["code"], "duplicate_item_id")

	var unknown := _valid_rows()
	unknown[16]["id"] = "unknown_item"
	assert_eq(CATALOG_PROJECTION.project(unknown)["code"], "unknown_item_id")

	var old_keepsake := _valid_rows()
	old_keepsake[14]["id"] = "priscilla_gift"
	assert_eq(CATALOG_PROJECTION.project(old_keepsake)["code"], "unknown_item_id")


func test_rejects_bad_price_art_and_field_types() -> void:
	var bad_price := _valid_rows()
	bad_price[0]["unit_price"] = 19
	assert_eq(CATALOG_PROJECTION.project(bad_price)["code"], "invalid_unit_price")

	var bad_art := _valid_rows()
	bad_art[0]["card_art"] = _texture(27, 28)
	assert_eq(CATALOG_PROJECTION.project(bad_art)["code"], "invalid_card_art")

	var bad_type := _valid_rows()
	bad_type[0]["legal_max"] = 2.0
	assert_eq(CATALOG_PROJECTION.project(bad_type)["code"], "invalid_legal_max")

	var non_record := _valid_rows()
	non_record[0] = "coffee"
	assert_eq(CATALOG_PROJECTION.project(non_record)["code"], "invalid_item_type")


func test_sold_out_item_stays_in_its_fixed_slot() -> void:
	var rows := _valid_rows()
	rows[0]["available"] = false
	rows[0]["legal_max"] = 0
	var value: Array = CATALOG_PROJECTION.project(rows)["value"]
	assert_eq(value[0]["id"], "coffee")
	assert_false(value[0]["available"])
	assert_eq(value[0]["legal_max"], 0)

func test_rejects_contradictory_maximum_but_accepts_unaffordable_available() -> void:
	var rows := _valid_rows()
	rows[0].available = false
	assert_eq(CATALOG_PROJECTION.project(rows).code, "invalid_legal_max")

func test_maximum_cannot_overflow_exact_currency_total() -> void:
	var rows := _valid_rows()
	rows[0].legal_max = 9223372036854775807
	assert_eq(CATALOG_PROJECTION.project(rows).code, "invalid_legal_max")
	rows[0].available = true
	rows[0].legal_max = 0
	assert_true(CATALOG_PROJECTION.project(rows).ok)
	rows[7].legal_max = 2
	assert_eq(CATALOG_PROJECTION.project(rows).code, "invalid_legal_max")


func test_supportz_blank_has_only_public_blank_fields_in_both_states() -> void:
	for eligible: bool in [false, true]:
		var blank: Dictionary = CATALOG_PROJECTION.project(_valid_rows(), eligible)["value"][8]
		assert_eq(blank, {"id": "supportz", "blank": true, "actionable": eligible})


func test_projected_records_are_detached_from_owner_record_mutation() -> void:
	var rows := _valid_rows()
	rows[0]["description"] = "A sealed vending cup."
	var result: Dictionary = CATALOG_PROJECTION.project(rows)
	rows[0]["name"] = "Changed"
	rows[0]["description"] = "Changed"
	rows[0]["private"] = true
	assert_eq(result["value"][0]["name"], "Coffee")
	assert_eq(result["value"][0]["description"], "A sealed vending cup.")
	assert_false(result["value"][0].has("private"))


func _valid_rows() -> Array:
	var rows: Array = []
	for item_id: String in ORDER:
		if item_id == "supportz":
			continue
		var spec: Array = SPECS[item_id]
		rows.append({
			"id": item_id,
			"name": {"bookend_keepsake": "Bookend", "metronome_keepsake": "Metronome", "pocket_calculator_keepsake": "Pocket Calculator"}.get(item_id, item_id.capitalize()),
			"unit_price": spec[0],
			"currency": spec[1],
			"available": true,
			"batchable": spec[2],
			"legal_max": 4 if spec[2] else 1,
			"card_art": _texture(28, 28),
			"inspector_art": _texture(56, 56),
		})
	return rows


func _texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


func _ids(value: Array) -> Array:
	var result: Array = []
	for item: Dictionary in value:
		result.append(item["id"])
	return result
