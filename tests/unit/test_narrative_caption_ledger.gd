extends "res://addons/gut/test.gd"

const LEDGER := preload("res://scripts/narrative/NarrativeCaptionLedger.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FIXTURE := "res://tests/fixtures/dialogic/non_canon_caption_registry.json"
const ENTRY := "fixture.non_canon.caption_ledger"
const TOKEN := "fixture:caption-session"
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

func _fixture() -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(FIXTURE))
	assert_true(parsed.ok, str(parsed))
	return parsed.value

func _ledger(fixture: Dictionary = {}) -> NarrativeCaptionLedger:
	if fixture.is_empty(): fixture = _fixture()
	var ledger := LEDGER.new()
	var initialized := ledger.initialize(TOKEN, fixture.frozen_context,
		fixture.entry_manifest, fixture.registry)
	assert_true(initialized.ok, str(initialized))
	return ledger

func test_actual_publication_order_is_independent_of_registry_order() -> void:
	var fixture := _fixture()
	var ledger := _ledger(fixture)
	assert_eq(ledger.snapshot().captions.size(), 0, "registration does not publish unseen captions")
	assert_true(ledger.publish_line(TOKEN, "publication:beta", ENTRY, "fixture.caption.beta").ok)
	assert_true(ledger.publish_line(TOKEN, "publication:alpha", ENTRY, "fixture.caption.alpha").ok)
	var captions: Array = ledger.snapshot().captions
	assert_eq(captions[0].beat, fixture.registry.beats[1])
	assert_eq(captions[1].beat, fixture.registry.beats[0])
	assert_eq(captions[0].publication_id, "publication:beta")

func test_same_publication_is_idempotent_but_a_new_occurrence_is_retained() -> void:
	var ledger := _ledger()
	var first := ledger.publish_line(TOKEN, "publication:one", ENTRY, "fixture.caption.alpha")
	var again := ledger.publish_line(TOKEN, "publication:one", ENTRY, "fixture.caption.alpha")
	assert_eq(first.value, {"duplicate": false, "ordinal": 0})
	assert_eq(again.value, {"duplicate": true, "ordinal": 0})
	assert_eq(ledger.snapshot().captions.size(), 1)
	assert_true(ledger.publish_line(TOKEN, "publication:two", ENTRY, "fixture.caption.alpha").ok)
	assert_eq(ledger.snapshot().captions.size(), 2)

func test_conflicting_publication_refuses_without_changing_the_sequence() -> void:
	var fixture := _fixture()
	fixture.registry.beats[0].presentation_signature["nested_identity"] = {"value": 1}
	var ledger := _ledger(fixture)
	assert_true(ledger.publish_caption(TOKEN, "publication:one", fixture.registry.beats[0]).ok)
	var before := ledger.snapshot()
	assert_eq(ledger.publish_caption(TOKEN, "publication:one", fixture.registry.beats[1]).code,
		&"caption_publication_conflict")
	var changed: Dictionary = fixture.registry.beats[0].duplicate(true)
	changed.presentation_signature.text_revision = "changed-v2"
	assert_eq(ledger.publish_caption(TOKEN, "publication:one", changed).code, &"caption_publication_conflict")
	assert_eq(ledger.publish_caption(TOKEN, "publication:new", changed).code, &"caption_registration_mismatch")
	changed = fixture.registry.beats[0].duplicate(true)
	changed.presentation_signature.nested_identity.value = true
	assert_eq(ledger.publish_caption(TOKEN, "publication:one", changed).code,
		&"caption_publication_conflict", "nested bool and int cannot alias one identity")
	assert_eq(ledger.snapshot(), before)

func test_foreign_token_unknown_line_and_foreign_owner_apply_zero_mutation() -> void:
	var fixture := _fixture()
	fixture.registry.beats[1].owning_entry_id = "fixture.non_canon.foreign_entry"
	var ledger := _ledger(fixture)
	var before := ledger.snapshot()
	assert_eq(ledger.publish_line("foreign:session", "publication:one", ENTRY, "fixture.caption.alpha").code,
		&"caption_foreign_session")
	assert_eq(ledger.publish_line(TOKEN, "publication:one", ENTRY, "fixture.caption.inferred").code,
		&"caption_line_unregistered")
	assert_eq(ledger.publish_line(TOKEN, "publication:one", ENTRY, "fixture.caption.beta").code,
		&"caption_line_foreign_entry")
	assert_eq(ledger.snapshot(), before)

func test_inputs_and_returned_snapshots_are_recursively_detached() -> void:
	var fixture := _fixture()
	var ledger := _ledger(fixture)
	var initialized := ledger.snapshot()
	fixture.frozen_context.selectors.inputs.append("caller mutation")
	fixture.registry.beats[0].presentation_signature.selectors.append("caller mutation")
	fixture.registry.beats[0].line_id = "changed-by-caller"
	assert_eq(ledger.snapshot(), initialized)
	assert_true(ledger.publish_line(TOKEN, "publication:one", ENTRY, "fixture.caption.alpha").ok)
	var expected := ledger.snapshot()
	var exposed := ledger.snapshot()
	exposed.frozen_context.selectors.inputs.clear()
	exposed.captions[0].beat.presentation_signature.selectors.append("snapshot mutation")
	exposed.captions[0].beat.line_id = "changed-in-snapshot"
	exposed.captions.clear()
	assert_eq(ledger.snapshot(), expected)

func test_initialized_session_cannot_be_rebound_or_recaptured() -> void:
	var fixture := _fixture()
	var ledger := _ledger(fixture)
	var before := ledger.snapshot()
	assert_eq(ledger.initialize("another:session", {"changed": true}, fixture.entry_manifest,
		fixture.registry).code, &"caption_session_already_initialized")
	assert_eq(ledger.snapshot(), before)

func test_registry_requires_explicit_unique_identity_and_declared_entry_membership() -> void:
	for field: String in ["beat_id", "line_id"]:
		var fixture := _fixture()
		fixture.registry.beats[1][field] = fixture.registry.beats[0][field]
		assert_eq(MANIFEST.validate_caption_registry(fixture.entry_manifest, fixture.registry).code,
			&"caption_registration_duplicate", field)
	var fixture := _fixture()
	fixture.registry.beats[0].owning_entry_id = "unregistered:entry"
	assert_eq(MANIFEST.validate_caption_registry(fixture.entry_manifest, fixture.registry).code,
		&"caption_entry_unregistered")
	fixture = _fixture()
	fixture.registry.beats[0]["event_index"] = 1
	assert_eq(MANIFEST.validate_caption_registry(fixture.entry_manifest, fixture.registry).code,
		&"caption_registration_invalid", "DTL positions cannot be an alternate identity source")

func test_nonprimitive_context_and_signature_are_refused_before_any_session_install() -> void:
	var fixture := _fixture()
	var object := RefCounted.new()
	var ledger := LEDGER.new()
	var context := {"nested": [object]}
	assert_eq(ledger.initialize(TOKEN, context, fixture.entry_manifest, fixture.registry).code,
		&"caption_session_invalid")
	assert_eq(ledger.snapshot().session_token, "")
	fixture.registry.beats[0].presentation_signature["resource"] = object
	assert_eq(ledger.initialize(TOKEN, fixture.frozen_context, fixture.entry_manifest, fixture.registry).code,
		&"caption_registration_invalid")
	assert_eq(ledger.snapshot().session_token, "")

func test_uninitialized_ledger_and_empty_publication_identity_are_refused() -> void:
	var ledger := LEDGER.new()
	assert_eq(ledger.publish_line(TOKEN, "publication:one", ENTRY, "fixture.caption.alpha").code,
		&"caption_session_uninitialized")
	ledger = _ledger()
	assert_eq(ledger.publish_line(TOKEN, "", ENTRY, "fixture.caption.alpha").code,
		&"caption_publication_invalid")
	assert_eq(ledger.snapshot().captions.size(), 0)
