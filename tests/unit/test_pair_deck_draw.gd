extends GutTest
const DRAW := preload("res://scripts/domain/relationship/PairDeckDraw.gd")

func test_unseen_pool_is_uniform_and_resets_only_when_every_form_was_witnessed() -> void:
	for witnessed: Array in [[], ["ambiguous_dark"], ["ambiguous_dark", "love_dark"],
			["ambiguous_dark", "love_dark", "love_sweet"], DRAW.FORMS.duplicate()]:
		var counts := {}
		for nonce: int in range(12):
			var draw: Dictionary = DRAW.build_draw(witnessed, nonce)
			assert_true(draw.ok)
			assert_true(DRAW.validate(draw.value).ok)
			counts[draw.value.form] = int(counts.get(draw.value.form, 0)) + 1
		var pool_size: int = 4 if witnessed.size() == 4 else 4 - witnessed.size()
		assert_eq(counts.size(), pool_size)
		for count: int in counts.values(): assert_eq(count, int(12 / pool_size))
		if witnessed.size() < 4:
			for form: String in witnessed: assert_false(counts.has(form))

func test_three_form_pool_rejects_the_incomplete_random_bucket() -> void:
	assert_eq(DRAW.build_draw(["ambiguous_dark"], 4294967295).code, &"pair_draw_nonce_rejected")
	assert_true(DRAW.build_draw(["ambiguous_dark"], 4294967294).ok)
	assert_true(DRAW.build_draw([], 4294967295).ok)
	assert_false(DRAW.build_draw([], -1).ok)
	assert_false(DRAW.build_draw([], 4294967296).ok)

func test_receipt_pins_pool_nonce_fingerprint_and_form_and_returns_detached_bytes() -> void:
	var receipt: Dictionary = DRAW.build_draw(["love_dark", "ambiguous_dark"], 7).value
	assert_eq(receipt.witnessed_forms, ["ambiguous_dark", "love_dark"])
	for field: String in ["form", "rng_nonce", "witness_fingerprint", "ruleset_id", "witnessed_forms"]:
		var changed := receipt.duplicate(true)
		match field:
			"form": changed.form = "love_dark"
			"rng_nonce": changed.rng_nonce = 8
			"witnessed_forms": changed.witnessed_forms.reverse()
			_: changed[field] = "changed"
		assert_false(DRAW.validate(changed).ok, field)
	var validated: Dictionary = DRAW.validate(receipt)
	validated.value.witnessed_forms.clear()
	assert_eq(receipt.witnessed_forms.size(), 2)

func test_legacy_import_preserves_established_form_without_inventing_draw_inputs() -> void:
	for form: String in DRAW.FORMS:
		var imported: Dictionary = DRAW.build_legacy(form)
		assert_true(imported.ok)
		assert_eq(imported.value.form, form)
		assert_null(imported.value.rng_nonce)
		assert_eq(imported.value.witnessed_forms, [])
		assert_true(DRAW.validate(imported.value).ok)
		imported.value.rng_nonce = 0
		assert_false(DRAW.validate(imported.value).ok)
