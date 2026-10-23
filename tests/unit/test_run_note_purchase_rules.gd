extends "res://addons/gut/test.gd"

const RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")
const FIXTURE := preload("res://tests/support/RunNotePurchaseFixture.gd")

func test_each_product_unlocks_three_in_order_and_refuses_fourth() -> void:
	for item: String in FIXTURE.ITEMS:
		var counts: Dictionary = FIXTURE.counts()
		var money: int = 180
		var catalogue: Dictionary = FIXTURE.catalogue()
		for ordinal: int in range(1, 4):
			var result: Dictionary = RULES.prepare(item, 1, money, counts, catalogue)
			assert_true(result.ok, item)
			if not result.ok: continue
			assert_eq(result.value.candidate.money, 180 - 45 * ordinal)
			assert_eq(result.value.candidate.shop_purchase_counts[item], ordinal)
			assert_eq(result.value.note, catalogue[item][ordinal - 1])
			assert_eq(result.value.notes, catalogue[item].slice(0, ordinal))
			money = result.value.candidate.money
			counts = result.value.candidate.shop_purchase_counts
		var before: Dictionary = counts.duplicate(true)
		var capped: Dictionary = RULES.prepare(item, 1, money, counts, catalogue)
		assert_false(capped.ok)
		assert_eq(capped.code, "purchase_cap_reached")
		assert_eq(counts, before)
		assert_eq(money, 45)

func test_exact_money_boundary_for_every_product() -> void:
	for item: String in FIXTURE.ITEMS:
		var poor: Dictionary = RULES.prepare(item, 1, 44, {}, FIXTURE.catalogue())
		assert_false(poor.ok)
		assert_eq(poor.code, "insufficient_funds")
		var exact: Dictionary = RULES.prepare(item, 1, 45, {}, FIXTURE.catalogue())
		assert_true(exact.ok)
		if exact.ok: assert_eq(exact.value.candidate.money, 0)

func test_money_requires_nonnegative_integer_without_coercion() -> void:
	for money: Variant in [-1, -9223372036854775807, 45.0, 45.5, true, false, "45", null, [], {}, INF, NAN]:
		var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, money, {}, FIXTURE.catalogue())
		assert_false(result.ok, str(money))
		assert_eq(result.code, "invalid_money")

func test_maximum_integer_money_debits_exactly() -> void:
	var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 9223372036854775807, {}, FIXTURE.catalogue())
	assert_true(result.ok)
	if result.ok: assert_eq(result.value.candidate.money, 9223372036854775762)

func test_quantity_is_exactly_one_integer() -> void:
	for quantity: Variant in [0, -1, 2, 3, 9223372036854775807, 1.0, 1.5, true, false, "1", null, [], {}]:
		var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], quantity, 100, {}, FIXTURE.catalogue())
		assert_false(result.ok, str(quantity))
		assert_eq(result.code, "invalid_quantity")

func test_unknown_and_malformed_products_refuse() -> void:
	for item: Variant in ["unknown", "supportz", "Crystal_stutters", "", null, 1, true, [], {}]:
		var result: Dictionary = RULES.prepare(item, 1, 100, {}, FIXTURE.catalogue())
		assert_false(result.ok, str(item))
		assert_eq(result.code, "invalid_item_id")

func test_runtime_string_name_product_normalizes_to_primitive_id() -> void:
	var result: Dictionary = RULES.prepare(&"crystal_stutters", 1, 45, {}, FIXTURE.catalogue())
	assert_true(result.ok)
	if result.ok:
		assert_eq(result.value.item_id, "crystal_stutters")
		assert_eq(typeof(result.value.item_id), TYPE_STRING)

func test_missing_counts_mean_zero_without_filling_unrelated_keys() -> void:
	var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[1], 1, 45, {}, FIXTURE.catalogue())
	assert_true(result.ok)
	if result.ok: assert_eq(result.value.candidate.shop_purchase_counts, {"inked_silk_string": 1})

func test_runtime_string_name_count_keys_normalize_without_bypassing_caps() -> void:
	var counts := {&"crystal_stutters": 2, &"supportz": 8}
	var before: Dictionary = counts.duplicate(true)
	var result: Dictionary = RULES.prepare(&"crystal_stutters", 1, 45, counts, FIXTURE.catalogue())
	assert_true(result.ok)
	assert_eq(counts, before)
	if result.ok:
		assert_eq(result.value.candidate.shop_purchase_counts, {"crystal_stutters": 3, "supportz": 8})
		for key: Variant in result.value.candidate.shop_purchase_counts:
			assert_eq(typeof(key), TYPE_STRING)
	assert_eq(RULES.prepare("crystal_stutters", 1, 45, {&"crystal_stutters": 3}, FIXTURE.catalogue()).code, "purchase_cap_reached")
	assert_eq(RULES.prepare("crystal_stutters", 1, 45, {&"crystal_stutters": 4}, FIXTURE.catalogue()).code, "invalid_counts")

func test_all_note_counts_are_validated_before_any_debit() -> void:
	for item: String in FIXTURE.ITEMS:
		for value: Variant in [-1, 4, 9223372036854775807, 0.0, 1.5, true, "1", null, [], {}]:
			var counts: Dictionary = FIXTURE.counts()
			counts[item] = value
			var before: Dictionary = counts.duplicate(true)
			var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 100, counts, FIXTURE.catalogue())
			assert_false(result.ok, item + " " + str(value))
			assert_eq(result.code, "invalid_counts")
			assert_eq(counts, before)

func test_counts_container_and_unrelated_counts_are_strict_primitives() -> void:
	for counts: Variant in [null, [], 1, "counts", {1: 0}, {"supportz": -1}, {"supportz": 1.0}, {"other": []}, {"other": true}]:
		var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 100, counts, FIXTURE.catalogue())
		assert_false(result.ok)
		assert_eq(result.code, "invalid_counts")

func test_products_and_unrelated_state_remain_independent() -> void:
	var state := {"money": 180, "minesweeper_coin": 7, "pressure": 42,
		"shop_purchase_counts": FIXTURE.counts(), "other": {"history": ["TEST.retained"]}}
	state.shop_purchase_counts.inked_silk_string = 3
	state.shop_purchase_counts.letter_with_wax_seal = 1
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = RULES.prepare("crystal_stutters", 1, state.money, state.shop_purchase_counts, FIXTURE.catalogue())
	assert_true(result.ok)
	assert_eq(state, before)
	if result.ok:
		assert_eq(result.value.candidate.shop_purchase_counts,
			{"crystal_stutters": 1, "inked_silk_string": 3, "letter_with_wax_seal": 1, "supportz": 8, "lucky_charm": 1})
		assert_eq(result.value.candidate.keys().size(), 2)

func test_identical_calls_are_equal_proposals_and_never_live_grants() -> void:
	var counts: Dictionary = FIXTURE.counts()
	var catalogue: Dictionary = FIXTURE.catalogue()
	var first: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 90, counts, catalogue)
	var second: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 90, counts, catalogue)
	assert_true(first.ok)
	assert_eq(first, second)
	assert_eq(counts, FIXTURE.counts())
	assert_eq(catalogue, FIXTURE.catalogue())
	if first.ok:
		first.value.candidate.shop_purchase_counts.crystal_stutters = 3
		first.value.note.text = "TEST.changed"
		first.value.notes[0].text = "TEST.changed again"
		assert_eq(second.value.candidate.shop_purchase_counts.crystal_stutters, 1)
		assert_eq(second.value.note, catalogue.crystal_stutters[0])
		assert_eq(counts, FIXTURE.counts())
		assert_eq(catalogue, FIXTURE.catalogue())

func test_input_mutation_after_success_does_not_change_proposal() -> void:
	var counts: Dictionary = FIXTURE.counts()
	var catalogue: Dictionary = FIXTURE.catalogue()
	var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 90, counts, catalogue)
	assert_true(result.ok)
	if not result.ok: return
	var before: Dictionary = result.duplicate(true)
	counts.crystal_stutters = 3
	catalogue.crystal_stutters[0].text = "TEST.changed"
	catalogue.crystal_stutters.clear()
	assert_eq(result, before)

func test_missing_catalogue_and_missing_text_refuse_without_partial_candidate() -> void:
	var missing: Dictionary = FIXTURE.catalogue()
	missing.crystal_stutters[1].erase("text")
	for catalogue: Variant in [null, {}, missing]:
		var counts: Dictionary = FIXTURE.counts()
		var before: Dictionary = counts.duplicate(true)
		var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 90, counts, catalogue)
		assert_false(result.ok)
		assert_false(result.code.is_empty())
		assert_eq(result.value, {})
		assert_eq(counts, before)

func test_duplicate_note_ids_refuse_even_outside_selected_product() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	catalogue.letter_with_wax_seal[2].id = catalogue.inked_silk_string[0].id
	var result: Dictionary = RULES.prepare(FIXTURE.ITEMS[0], 1, 90, {}, catalogue)
	assert_false(result.ok)
	assert_eq(result.code, "invalid_catalogue")

func test_all_refusals_have_no_candidate_and_do_not_mutate_inputs() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	var counts: Dictionary = FIXTURE.counts()
	counts.crystal_stutters = 3
	var before: Dictionary = counts.duplicate(true)
	for args: Array in [["unknown", 1, 90], [FIXTURE.ITEMS[0], 2, 90], [FIXTURE.ITEMS[1], 1, 44], [FIXTURE.ITEMS[0], 1, 90]]:
		var result: Dictionary = RULES.prepare(args[0], args[1], args[2], counts, catalogue)
		assert_false(result.ok)
		assert_eq(result.value, {})
		assert_eq(counts, before)
		assert_eq(catalogue, FIXTURE.catalogue())


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
