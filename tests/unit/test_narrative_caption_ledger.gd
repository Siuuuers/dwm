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

func test_entry_context_admission_is_causal_immutable_and_detached() -> void:
	var fixture := _fixture()
	fixture.entry_contexts[ENTRY].selectors["fixture_counter"] = 1
	var ledger := LEDGER.new()
	assert_true(ledger.initialize(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, true).ok)
	var empty := ledger.snapshot()
	assert_eq(empty.entry_contexts, {}, "registration cannot admit a future entry's facts")
	assert_eq(ledger.allocate_publication(TOKEN, ENTRY).code, &"caption_entry_context_missing")
	assert_eq(ledger.publish_caption(TOKEN, "first", fixture.registry.beats[0]).code,
		&"caption_entry_context_missing", "direct publication cannot bypass frame admission")
	assert_eq(ledger.admit_entry_context("foreign", ENTRY, fixture.entry_contexts[ENTRY]).code,
		&"caption_foreign_session")
	assert_eq(ledger.admit_entry_context(TOKEN, "unregistered", fixture.entry_contexts[ENTRY]).code,
		&"caption_entry_unregistered")
	assert_eq(ledger.admit_entry_context(TOKEN, ENTRY, {"object": RefCounted.new()}).code,
		&"caption_entry_context_invalid")
	assert_eq(ledger.snapshot(), empty, "failed admissions and publications reserve no state")
	var original: Dictionary = fixture.entry_contexts[ENTRY].duplicate(true)
	assert_true(ledger.admit_entry_context(TOKEN, ENTRY, fixture.entry_contexts[ENTRY]).ok)
	assert_true(ledger.admit_entry_context(TOKEN, ENTRY, original).ok, "identical retry is idempotent")
	assert_true(ledger.publish_line(TOKEN, "first", ENTRY, "fixture.caption.alpha").ok)
	var before := ledger.snapshot()
	var conflicting := original.duplicate(true)
	conflicting.selectors.fixture_counter = true
	assert_eq(ledger.admit_entry_context(TOKEN, ENTRY, conflicting).code,
		&"caption_entry_context_conflict", "nested bool and int are distinct frozen facts")
	fixture.entry_contexts[ENTRY].selectors.inputs.append("caller changed")
	assert_eq(ledger.admit_entry_context(TOKEN, ENTRY, fixture.entry_contexts[ENTRY]).code,
		&"caption_entry_context_conflict")
	var exposed := ledger.snapshot()
	exposed.entry_contexts[ENTRY].selectors.inputs.clear()
	exposed.entry_contexts.clear()
	assert_eq(ledger.snapshot(), before)
	var second := "fixture.non_canon.foreign_entry"
	assert_eq(ledger.publish_line(TOKEN, "second", second, "fixture.caption.gamma").code,
		&"caption_entry_context_missing")
	assert_eq(ledger.snapshot(), before)
	assert_true(ledger.admit_entry_context(TOKEN, second, fixture.entry_contexts[second]).ok)
	assert_eq(ledger.publish_line(TOKEN, "second", second, "fixture.caption.alpha").code,
		&"caption_line_foreign_entry", "a second admitted frame cannot claim the first entry's line")
	assert_true(ledger.publish_line(TOKEN, "second", second, "fixture.caption.gamma").ok)
	var together := ledger.snapshot()
	assert_eq(together.captions[0], before.captions[0])
	assert_eq(together.entry_contexts[ENTRY], original, "later facts cannot rewrite the earlier frame")
	assert_eq(together.entry_contexts[together.captions[1].beat.owning_entry_id],
		fixture.entry_contexts[second], "authored entry identity binds the occurrence to its exact frame")

func test_framed_reconstruction_validates_all_contexts_and_occurrences_before_installing() -> void:
	var fixture := _fixture()
	var source := LEDGER.new()
	assert_true(source.initialize(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, true).ok)
	var empty_framed := source.snapshot()
	var empty_restored := LEDGER.new()
	var before_empty := empty_restored.snapshot()
	var downgraded := empty_framed.duplicate(true)
	downgraded.erase("entry_contexts")
	assert_eq(empty_restored.restore_snapshot(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, downgraded, {}, true).code, &"caption_entry_context_mismatch")
	assert_eq(empty_restored.snapshot(), before_empty,
		"even zero admitted frames cannot downgrade the independently required mode")
	assert_true(empty_restored.restore_snapshot(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, empty_framed, {}, true).ok)
	assert_eq(empty_restored.snapshot(), empty_framed)
	assert_eq(empty_restored.publish_caption(TOKEN, "unadmitted", fixture.registry.beats[0]).code,
		&"caption_entry_context_missing", "restoring no frames preserves the publication gate")
	for entry_id: String in fixture.entry_contexts:
		assert_true(source.admit_entry_context(TOKEN, entry_id, fixture.entry_contexts[entry_id]).ok)
	assert_true(source.publish_caption(TOKEN, "first", fixture.registry.beats[0]).ok)
	assert_true(source.publish_caption(TOKEN, "second", fixture.registry.beats[2]).ok)
	var saved := source.snapshot()
	var restored := LEDGER.new()
	var empty := restored.snapshot()
	var second := "fixture.non_canon.foreign_entry"
	var damaged := saved.duplicate(true)
	damaged.entry_contexts[second] = damaged.entry_contexts[ENTRY].duplicate(true)
	assert_eq(restored.restore_snapshot(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, damaged, fixture.entry_contexts, true).code, &"caption_entry_context_mismatch")
	assert_eq(restored.snapshot(), empty, "changed later facts do not install the earlier frame")
	damaged = saved.duplicate(true)
	damaged.entry_contexts.erase(second)
	var incomplete: Dictionary = fixture.entry_contexts.duplicate(true)
	incomplete.erase(second)
	assert_eq(restored.restore_snapshot(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, damaged, incomplete, true).code, &"caption_entry_context_missing")
	assert_eq(restored.snapshot(), empty, "a valid first occurrence cannot install before a bad suffix")
	damaged = saved.duplicate(true)
	damaged.erase("entry_contexts")
	assert_eq(restored.restore_snapshot(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, damaged, fixture.entry_contexts, true).code, &"caption_entry_context_mismatch")
	assert_eq(restored.snapshot(), empty, "removing the frame map cannot downgrade a framed reconstruction")
	assert_true(restored.restore_snapshot(TOKEN, fixture.frozen_context, fixture.entry_manifest,
		fixture.registry, saved, fixture.entry_contexts, true).ok)
	var expected := saved.duplicate(true)
	saved.entry_contexts[ENTRY].selectors.inputs.clear()
	fixture.entry_contexts[second].selectors.inputs.clear()
	assert_eq(restored.snapshot(), expected, "saved and independently admitted inputs are detached")
	assert_eq(source.snapshot(), expected)

func test_original_unframed_snapshot_and_restore_contract_remains_available() -> void:
	var fixture := _fixture()
	var ledger := _ledger(fixture)
	assert_true(ledger.publish_line(TOKEN, "first", ENTRY, "fixture.caption.alpha").ok)
	var saved := ledger.snapshot()
	assert_false(saved.has("entry_contexts"))
	assert_eq(ledger.admit_entry_context(TOKEN, ENTRY, fixture.entry_contexts[ENTRY]).code,
		&"caption_entry_contexts_disabled", "an existing session cannot silently change its contract")
	var restored := LEDGER.new()
	assert_true(restored.restore_snapshot(TOKEN, fixture.frozen_context,
		fixture.entry_manifest, fixture.registry, saved).ok)
	assert_eq(restored.snapshot(), saved)
