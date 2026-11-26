extends "res://addons/gut/test.gd"

const RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")

func test_counts_only_validation_detaches_normalizes_keys_and_preserves_unrelated_counts() -> void:
	var source: Dictionary = {&"crystal_stutters": 3, "other_item": 19}
	var result: Dictionary = RULES.validate_counts(source)
	assert_true(result.ok)
	if not result.ok: return
	assert_eq(result.value.shop_purchase_counts, {"crystal_stutters": 3, "other_item": 19})
	for key: Variant in result.value.shop_purchase_counts:
		assert_eq(typeof(key), TYPE_STRING)
	result.value.shop_purchase_counts["crystal_stutters"] = 0
	assert_eq(source[&"crystal_stutters"], 3)
	assert_eq(RULES.validate_counts({}).value.shop_purchase_counts, {})


func test_counts_only_validation_refuses_invalid_maps_and_values_without_catalogue() -> void:
	for invalid: Variant in [null, [], false, 0, {"crystal_stutters": 4},
			{"crystal_stutters": -1}, {"crystal_stutters": true},
			{"crystal_stutters": 1.0}, {"other_item": -1},
			{"other_item": 1.5}, {"other_item": {}}, {1: 0}]:
		var result: Dictionary = RULES.validate_counts(invalid)
		assert_false(result.ok, str(invalid))
		assert_eq(result.code, "invalid_counts")
		assert_eq(result.value, {})
