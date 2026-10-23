extends "res://addons/gut/test.gd"

const PROJECTION := preload("res://scripts/ui/notes/NotesCatalogProjection.gd")
const RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")
const FIXTURE := preload("res://tests/support/RunNotePurchaseFixture.gd")

func test_all_64_count_combinations_select_exact_ordered_prefixes() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	for a: int in range(4):
		for b: int in range(4):
			for c: int in range(4):
				var counts := {"crystal_stutters": a, "inked_silk_string": b, "letter_with_wax_seal": c}
				var result: Dictionary = PROJECTION.project(counts, catalogue)
				assert_true(result.ok)
				if not result.ok: continue
				assert_eq(result.value.groups.size(), 3)
				var seen: Dictionary = {}
				for index: int in range(3):
					var item: String = FIXTURE.ITEMS[index]
					var group: Dictionary = result.value.groups[index]
					assert_eq(group.item_id, item)
					assert_eq(group.count, counts[item])
					assert_eq(group.notes, catalogue[item].slice(0, counts[item]))
					for note: Dictionary in group.notes:
						assert_false(seen.has(note.id))
						seen[note.id] = true
				assert_eq(seen.size(), a + b + c)

func test_absent_counts_project_no_unlocks() -> void:
	var result: Dictionary = PROJECTION.project({}, FIXTURE.catalogue())
	assert_true(result.ok)
	if not result.ok: return
	for group: Dictionary in result.value.groups:
		assert_eq(group.count, 0)
		assert_eq(group.notes, [])

func test_catalogue_insertion_order_does_not_change_product_order() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	var reversed := {"letter_with_wax_seal": catalogue.letter_with_wax_seal,
		"inked_silk_string": catalogue.inked_silk_string, "crystal_stutters": catalogue.crystal_stutters}
	assert_eq(PROJECTION.project(FIXTURE.counts(), reversed), PROJECTION.project(FIXTURE.counts(), catalogue))

func test_purchase_candidate_projects_the_same_new_prefix() -> void:
	for item: String in FIXTURE.ITEMS:
		for count: int in range(3):
			var counts: Dictionary = {item: count}
			var catalogue: Dictionary = FIXTURE.catalogue()
			var proposal: Dictionary = RULES.prepare(item, 1, 45, counts, catalogue)
			assert_true(proposal.ok)
			if not proposal.ok: continue
			var projected: Dictionary = PROJECTION.project(proposal.value.candidate.shop_purchase_counts, catalogue)
			assert_true(projected.ok)
			if not projected.ok: continue
			var group: Dictionary = projected.value.groups[FIXTURE.ITEMS.find(item)]
			assert_eq(group.notes, proposal.value.notes)
			assert_eq(group.notes.back(), proposal.value.note)

func test_invalid_counts_refuse_instead_of_clamping_or_coercing() -> void:
	for item: String in FIXTURE.ITEMS:
		for count: Variant in [-1, 4, 1.0, true, "1", null]:
			var result: Dictionary = PROJECTION.project({item: count}, FIXTURE.catalogue())
			assert_false(result.ok)
			assert_eq(result.code, "invalid_counts")
			assert_eq(result.value, {})

func test_invalid_catalogue_container_or_unregistered_product_refuses() -> void:
	for catalogue: Variant in [null, [], "catalogue", 3, true]:
		var result: Dictionary = PROJECTION.project({}, catalogue)
		assert_false(result.ok)
		assert_eq(result.code, "invalid_catalogue")
	var extra: Dictionary = FIXTURE.catalogue()
	extra.unknown_product = []
	assert_false(PROJECTION.project({}, extra).ok)

func test_missing_product_and_incomplete_note_set_are_explicit() -> void:
	for item: String in FIXTURE.ITEMS:
		var missing: Dictionary = FIXTURE.catalogue()
		missing.erase(item)
		var result: Dictionary = PROJECTION.project({}, missing)
		assert_false(result.ok)
		assert_eq(result.code, "missing_note_content")
		for size: int in range(3):
			var incomplete: Dictionary = FIXTURE.catalogue()
			incomplete[item] = incomplete[item].slice(0, size)
			result = PROJECTION.project({}, incomplete)
			assert_false(result.ok)
			assert_eq(result.code, "missing_note_content")

func test_more_than_three_notes_is_not_silently_truncated() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	catalogue.crystal_stutters.append({"id": "TEST.extra", "text": "TEST extra."})
	var result: Dictionary = PROJECTION.project({}, catalogue)
	assert_false(result.ok)
	assert_eq(result.code, "invalid_catalogue")

func test_missing_or_blank_text_never_becomes_fallback_content() -> void:
	for field: String in ["id", "text"]:
		var missing: Dictionary = FIXTURE.catalogue()
		missing.crystal_stutters[2].erase(field)
		assert_eq(PROJECTION.project({}, missing).code, "missing_note_content")
		for blank: String in ["", " ", "\t\n"]:
			var catalogue: Dictionary = FIXTURE.catalogue()
			catalogue.crystal_stutters[2][field] = blank
			var result: Dictionary = PROJECTION.project({}, catalogue)
			assert_false(result.ok)
			assert_eq(result.code, "missing_note_content")
			assert_eq(result.value, {})

func test_note_field_and_row_types_are_not_coerced() -> void:
	for field: String in ["id", "text"]:
		for value: Variant in [null, true, 1, 1.0, [], {}]:
			var catalogue: Dictionary = FIXTURE.catalogue()
			catalogue.crystal_stutters[0][field] = value
			assert_false(PROJECTION.project({}, catalogue).ok)
	for value: Variant in [null, [], "note", 1]:
		var catalogue: Dictionary = FIXTURE.catalogue()
		catalogue.crystal_stutters[0] = value
		assert_false(PROJECTION.project({}, catalogue).ok)

func test_duplicate_ids_within_or_across_products_refuse() -> void:
	for item: String in FIXTURE.ITEMS:
		var catalogue: Dictionary = FIXTURE.catalogue()
		catalogue[item][2].id = catalogue.crystal_stutters[0].id
		var result: Dictionary = PROJECTION.project({}, catalogue)
		assert_false(result.ok)
		assert_eq(result.code, "invalid_catalogue")

func test_closed_note_rows_reject_unexpected_metadata() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	catalogue.crystal_stutters[0].live_owner = RefCounted.new()
	var result: Dictionary = PROJECTION.project({}, catalogue)
	assert_false(result.ok)
	assert_eq(result.code, "invalid_catalogue")

func test_projection_outputs_and_inputs_are_detached_both_directions() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	var counts: Dictionary = FIXTURE.counts()
	counts.crystal_stutters = 2
	var before_counts: Dictionary = counts.duplicate(true)
	var before_catalogue: Dictionary = catalogue.duplicate(true)
	var first: Dictionary = PROJECTION.project(counts, catalogue)
	var second: Dictionary = PROJECTION.project(counts, catalogue)
	assert_true(first.ok)
	assert_eq(first, second)
	assert_eq(counts, before_counts)
	assert_eq(catalogue, before_catalogue)
	if not first.ok: return
	first.value.groups[0].notes[0].text = "TEST.output mutation"
	first.value.groups[0].notes.clear()
	assert_eq(catalogue, before_catalogue)
	assert_eq(second.value.groups[0].notes, before_catalogue.crystal_stutters.slice(0, 2))
	var before_second: Dictionary = second.duplicate(true)
	catalogue.crystal_stutters[0].text = "TEST.input mutation"
	counts.crystal_stutters = 0
	assert_eq(second, before_second)

func test_authored_text_is_preserved_exactly_not_trimmed_or_rewritten() -> void:
	var catalogue: Dictionary = FIXTURE.catalogue()
	catalogue.crystal_stutters[0].text = "  TEST ONLY\n第二行 — αβ  "
	var result: Dictionary = PROJECTION.project({"crystal_stutters": 1}, catalogue)
	assert_true(result.ok)
	if result.ok: assert_eq(result.value.groups[0].notes[0].text, "  TEST ONLY\n第二行 — αβ  ")

func test_unrelated_counts_are_retained_by_rules_but_never_become_note_groups() -> void:
	var counts: Dictionary = FIXTURE.counts()
	counts.unrelated_future_item = 99
	var result: Dictionary = PROJECTION.project(counts, FIXTURE.catalogue())
	assert_true(result.ok)
	if result.ok:
		assert_eq(result.value.groups.size(), 3)
		for group: Dictionary in result.value.groups:
			assert_true(FIXTURE.ITEMS.has(group.item_id))
	assert_eq(counts.unrelated_future_item, 99)
