extends "res://addons/gut/test.gd"

const CATALOGUE := preload("res://scripts/narrative/SoloReadingCatalogue.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const PRE := CATALOGUE.PRE_ENTRY
const POST := CATALOGUE.POST_ENTRY

func _selectors(entry_id: String) -> Dictionary:
	var phase := "pre_challenge" if entry_id == PRE else "post_challenge"
	var result := {"entry_id": entry_id, "entry_role": "solo_" + phase, "day": 1,
		"friend_id": "priscilla", "challenge_slot": "dating.solo.priscilla.day1", "phase": phase,
		"tier": "friend", "tone": "sweet", "attitude": "", "due_echoes": [], "attempt_residue_id": null}
	if entry_id == POST:
		result.merge({"board_result": "cleared", "perfect_reasons": [], "relationship_outcome": "loved"})
	return result

func _presentation(entry_id: String, tone: String = "sweet") -> Dictionary:
	var fields := _selectors(entry_id)
	fields.tone = tone
	fields.merge({"run_id": "fixture:run", "branch_id": "fixture:branch"})
	if entry_id == POST: fields.merge({"attempt_id": "fixture:attempt", "effect_receipt_id": "fixture:effect"})
	return FROZEN.build(entry_id, fields).value

func _line(entry_id: String) -> Dictionary:
	var identity := "fixture.selector.pre" if entry_id == PRE else "fixture.selector.post"
	return {"beat_id": identity, "line_id": identity, "text": "A noncanonical quiet moment.",
		"revision": "fixture-v1", "variant_id": "quiet", "selector_fields": ["tone"]}

func _document() -> Dictionary:
	var entries: Array = []
	for entry_id: String in [PRE, POST]:
		var selectors := _selectors(entry_id)
		var first := {"selector_values": selectors, "label": entry_id + ".sweet", "lines": [_line(entry_id)]}
		var second: Dictionary = first.duplicate(true)
		second.selector_values.tone = "dark"
		second.label = entry_id + ".dark"
		second.lines[0].text = "A different noncanonical quiet moment."
		entries.append({"entry_id": entry_id, "content_version": 1,
			"selector_fields": (CATALOGUE.PRE_SELECTORS if entry_id == PRE else CATALOGUE.POST_SELECTORS).duplicate(),
			"variants": [first, second]})
	return {"kind": "solo_reading_catalogue", "schema_version": 2, "entries": entries}

func test_exact_frame_selects_same_line_variant_and_detached_projection() -> void:
	var document := _document()
	var compiled := CATALOGUE.compile(document)
	assert_true(compiled.ok, str(compiled))
	if not compiled.ok: return
	for entry_id: String in [PRE, POST]:
		var sweet := CATALOGUE.select(compiled.value.entries[entry_id], _presentation(entry_id))
		var dark := CATALOGUE.select(compiled.value.entries[entry_id], _presentation(entry_id, "dark"))
		assert_true(sweet.ok)
		assert_true(dark.ok)
		assert_eq(sweet.value.beats[0].line_id, dark.value.beats[0].line_id)
		assert_eq(sweet.value.beats[0].beat_id, dark.value.beats[0].beat_id)
		assert_ne(sweet.value.beats[0].presentation_signature, dark.value.beats[0].presentation_signature)
		assert_ne(sweet.value.lines[0].text, dark.value.lines[0].text)
		sweet.value.lines[0].text = "Caller mutation"
		sweet.value.selectors.due_echoes.append({"caller": true})
		assert_eq(CATALOGUE.select(compiled.value.entries[entry_id], _presentation(entry_id)).value.lines[0].text,
			"A noncanonical quiet moment.")
	document.entries[0].variants[0].lines[0].text = "Original mutation"
	assert_eq(compiled.value.entries[PRE].variants[0].lines[0].text, "A noncanonical quiet moment.")

func test_causal_frame_changes_preserve_exact_caption_and_entry_selector_identity() -> void:
	var entry: Dictionary = CATALOGUE.compile(_document()).value.entries[POST]
	var first := _presentation(POST)
	var changed := first.duplicate(true)
	for field: String in ["run_id", "branch_id", "attempt_id", "effect_receipt_id"]:
		changed.fields[field] = "different:" + field
	assert_eq(CATALOGUE.select(entry, first).value, CATALOGUE.select(entry, changed).value)

func test_line_subset_does_not_turn_unrelated_entry_selector_into_caption_variant() -> void:
	var document := _document()
	var alternative: Dictionary = document.entries[0].variants[0].duplicate(true)
	alternative.selector_values.attitude = "amused"
	document.entries[0].variants.append(alternative)
	var compiled := CATALOGUE.compile(document)
	assert_true(compiled.ok, str(compiled))
	if not compiled.ok: return
	var ordinary := _presentation(PRE)
	var amused := ordinary.duplicate(true)
	amused.fields.attitude = "amused"
	var a := CATALOGUE.select(compiled.value.entries[PRE], ordinary)
	var b := CATALOGUE.select(compiled.value.entries[PRE], amused)
	assert_ne(a.value.selectors, b.value.selectors)
	assert_eq(a.value.beats, b.value.beats, "whole-entry selection is separate from each caption's declared selectors")

func test_missing_duplicate_unknown_and_causal_selector_contracts_refuse() -> void:
	for field: String in ["run_id", "branch_id", "attempt_id", "effect_receipt_id", "invented"]:
		var document := _document()
		document.entries[0].selector_fields.append(field)
		assert_false(CATALOGUE.compile(document).ok, field)
	var missing := _document()
	missing.entries[0].selector_fields.erase("tone")
	assert_false(CATALOGUE.compile(missing).ok)
	var repeated := _document()
	repeated.entries[0].selector_fields[-1] = "tone"
	assert_false(CATALOGUE.compile(repeated).ok)
	var line_causal := _document()
	line_causal.entries[0].variants[0].lines[0].selector_fields = ["run_id"]
	assert_false(CATALOGUE.compile(line_causal).ok)

func test_ambiguous_missing_and_malformed_selection_fail_closed() -> void:
	var duplicate := _document()
	duplicate.entries[0].variants.append(duplicate.entries[0].variants[0].duplicate(true))
	assert_eq(CATALOGUE.compile(duplicate).code, &"reading_selector_ambiguous")
	var entry: Dictionary = CATALOGUE.compile(_document()).value.entries[PRE]
	var absent := _presentation(PRE)
	absent.fields.attitude = "amused"
	assert_eq(CATALOGUE.select(entry, absent).code, &"reading_selector_unavailable")
	var malformed := _presentation(PRE)
	malformed.fields.erase("run_id")
	assert_false(CATALOGUE.select(entry, malformed).ok, "selector projection cannot replace full canonical admission")
	malformed = _presentation(PRE)
	malformed.fields.attempt_residue_id = "invented:residue"
	assert_false(CATALOGUE.select(entry, malformed).ok)
	assert_false(CATALOGUE.select(entry, _presentation(POST)).ok)

func test_compile_rejects_wrong_types_constants_outcomes_and_unregistered_echoes() -> void:
	for changed: Dictionary in [{"day": 1.0}, {"friend_id": "lavinia"}, {"tone": "unknown"},
			{"attempt_residue_id": "invented:residue"},
			{"due_echoes": [{"echo_id": "invented", "presentation_atom_id": "invented"}]}]:
		var document := _document()
		document.entries[0].variants[0].selector_values.merge(changed, true)
		assert_false(CATALOGUE.compile(document).ok, str(changed))
	var invalid_result := _document()
	invalid_result.entries[1].variants[0].selector_values.board_result = "perfect"
	assert_false(CATALOGUE.compile(invalid_result).ok, "perfect cannot have empty reasons")
	var unsupported_version := _document()
	unsupported_version.schema_version = 2.0
	assert_false(CATALOGUE.compile(unsupported_version).ok)

func test_identical_descriptor_cannot_alias_different_text() -> void:
	var document := _document()
	for variant: Dictionary in document.entries[0].variants:
		variant.lines[0].selector_fields = []
	assert_eq(CATALOGUE.compile(document).code, &"reading_variant_text_conflict")

func test_line_identity_and_native_label_cannot_alias_foreign_programmes() -> void:
	var identity := _document()
	identity.entries[0].variants[1].lines[0].beat_id = "different:beat"
	assert_eq(CATALOGUE.compile(identity).code, &"reading_identity_conflict")
	var duplicate := _document()
	duplicate.entries[0].variants[0].lines.append(duplicate.entries[0].variants[0].lines[0].duplicate(true))
	assert_false(CATALOGUE.compile(duplicate).ok)
	var label := _document()
	label.entries[0].variants[1].label = label.entries[0].variants[0].label
	assert_eq(CATALOGUE.compile(label).code, &"reading_label_conflict")

func test_unrelated_entry_and_unknown_document_fields_refuse() -> void:
	var foreign := _document()
	foreign.entries[0].entry_id = "dating.solo.lavinia.day1.pre_challenge"
	assert_false(CATALOGUE.compile(foreign).ok)
	var extra := _document()
	extra["production_enabled"] = true
	assert_false(CATALOGUE.compile(extra).ok)
