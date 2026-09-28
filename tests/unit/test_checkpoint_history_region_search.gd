extends "res://addons/gut/test.gd"

## Region-search changes must preserve the original proof decisions and retained custody.
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const REFERENCE := preload("res://tests/support/HistoryRegionSearchReference.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class Manager extends RefCounted:
	var _journal := JOURNAL.new()

func _wired(reference: bool = false) -> Dictionary:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	assert_true(parsed.get("ok", false), "strict fixture parse")
	var validated := SNAPSHOT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), "fixture snapshot validation")
	var snapshot: Dictionary = validated.get("value", {}).get("candidate", {})
	var manager := Manager.new()
	assert_true(manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	for sequence: int in range(1, 5):
		var current := snapshot.duplicate(true)
		current["checkpoint_sequence"] = sequence
		current["checkpoint_id"] = "%s:%d" % [snapshot.run_id, sequence]
		var prepared: Dictionary = manager._journal.prepare_record(current, &"line")
		assert_true(prepared.get("ok", false), "retained fixture preparation")
		assert_true(manager._journal.commit_prepared(
			prepared.get("value", {}).get("candidate", {})).get("ok", false), "retained fixture commit")
	var port: RefCounted = REFERENCE.new(manager) if reference else PORT.new(manager)
	return {"manager": manager, "port": port, "bundles": manager._journal.get_bundles_for_disk()}

func _text(value: Variant) -> String:
	var emitted := WRITER.stringify(value)
	assert_true(emitted.get("ok", false), "canonical test text")
	return str(emitted.get("value", ""))

func _exercise(wired: Dictionary, bundles: Array, document_text: String) -> Dictionary:
	var source_before: Array = bundles.duplicate(true)
	var retained_before: Dictionary = wired.manager._journal.capture_state()["value"]["backup"]
	var profile := {"diagnostics_version": 2}
	wired.port._remember_written_history(bundles, document_text, profile)
	assert_true(WRITER._deep_same(bundles, source_before), "search never mutates supplied history")
	assert_true(WRITER._deep_same(wired.manager._journal.capture_state()["value"]["backup"], retained_before),
		"proof learning never changes retained bundles or the journal cursor")
	var proofs := {}
	for bundle: Dictionary in wired.bundles:
		var checkpoint_id := str(bundle.snapshot.checkpoint_id)
		proofs[checkpoint_id] = {
			"text": wired.manager._journal.get_retained_bundle_text(checkpoint_id),
			"document": wired.manager._journal.get_retained_bundle_document(checkpoint_id).duplicate(true),
		}
	# Timings are observations; compare every diagnostic decision, never elapsed values.
	for key: String in profile.keys():
		if key.ends_with("_us"):
			assert_gte(int(profile[key]), 0, key)
			profile.erase(key)
	return {"profile": profile, "proofs": proofs}

func _assert_search_equivalence(actual: Dictionary, reference: Dictionary, bundles: Array, document_text: String,
		learned_indexes: Array, expected_counts: Dictionary) -> void:
	var observed := _exercise(actual, bundles, document_text)
	var expected := _exercise(reference, bundles.duplicate(true), document_text)
	assert_true(WRITER._deep_same(observed, expected), "same proof bytes, detached values and decisions as Run66")
	for key: String in expected_counts:
		assert_eq(observed.profile.get(key), expected_counts[key], key)
	for index: int in actual.bundles.size():
		var checkpoint_id := str(actual.bundles[index].snapshot.checkpoint_id)
		var proof: Dictionary = observed.proofs[checkpoint_id]
		assert_eq(not str(proof.text).is_empty(), index in learned_indexes, "proof custody for " + checkpoint_id)
		if index in learned_indexes:
			assert_eq(str(proof.text), _text(actual.bundles[index]), "exact canonical proof bytes")
			assert_true(WRITER._deep_same(proof.document, actual.bundles[index]), "exact retained proof value")

func test_ordered_regions_with_unicode_prefix_preserve_every_proof() -> void:
	var actual := _wired()
	var reference := _wired(true)
	var document_text := _text({"prefix": "繁體中文／日本語🌌é", "recovery_journal": actual.bundles})
	_assert_search_equivalence(actual, reference, actual.bundles, document_text, [0, 1, 2], {
		"history_proof_misses": 3, "history_proof_learn_successes": 3, "history_proof_region_misses": 0})

func test_reordered_regions_still_learn_from_any_exact_occurrence() -> void:
	var actual := _wired()
	var reference := _wired(true)
	var reordered: Array = [actual.bundles[2], actual.bundles[0], actual.bundles[1]]
	_assert_search_equivalence(actual, reference, reordered, _text(actual.bundles), [0, 1, 2], {
		"history_proof_learn_attempts": 3, "history_proof_learn_successes": 3})

func test_duplicate_bundle_is_idempotent_after_successful_learning() -> void:
	var actual := _wired()
	var reference := _wired(true)
	var repeated: Array = [actual.bundles[0], actual.bundles[1], actual.bundles[0], actual.bundles[2]]
	_assert_search_equivalence(actual, reference, repeated, _text(actual.bundles), [0, 1, 2], {
		"history_proof_entries": 4, "history_proof_hits": 1, "history_proof_learn_successes": 3})

func test_missing_first_or_middle_region_does_not_hide_later_proofs() -> void:
	for missing_index: int in [0, 1]:
		var actual := _wired()
		var reference := _wired(true)
		var written: Array = actual.bundles.duplicate(true)
		written.remove_at(missing_index)
		var learned: Array = [0, 1, 2]
		learned.erase(missing_index)
		_assert_search_equivalence(actual, reference, actual.bundles, _text(written), learned, {
			"history_proof_misses": 3, "history_proof_region_misses": 1,
			"history_proof_learn_attempts": 2, "history_proof_learn_successes": 2})

func test_existing_proof_is_preserved_even_when_its_region_is_absent() -> void:
	var actual := _wired()
	var reference := _wired(true)
	for wired: Dictionary in [actual, reference]:
		var bundle: Dictionary = wired.bundles[1]
		assert_true(wired.manager._journal.remember_written_retained_bundle(
			str(bundle.snapshot.checkpoint_id), _text(bundle), bundle))
	_assert_search_equivalence(actual, reference, actual.bundles, _text([actual.bundles[0], actual.bundles[2]]), [0, 1, 2], {
		"history_proof_hits": 1, "history_proof_misses": 2, "history_proof_learn_successes": 2})

func test_repeated_mismatched_bundle_cannot_gain_a_proof_from_region_presence() -> void:
	var actual := _wired()
	var reference := _wired(true)
	var changed: Dictionary = actual.bundles[0].duplicate(true)
	changed["snapshot"]["content_version"] += 100
	var repeated: Array = [changed, actual.bundles[1], changed, actual.bundles[2]]
	_assert_search_equivalence(actual, reference, repeated, _text([changed, actual.bundles[1], actual.bundles[2]]), [1, 2], {
		"history_proof_misses": 4, "history_proof_learn_attempts": 4,
		"history_proof_learn_successes": 2, "history_proof_region_misses": 0})

func test_nested_exact_occurrence_keeps_original_region_semantics() -> void:
	var actual := _wired()
	var reference := _wired(true)
	var document_text := _text({"prefix": {"nested": actual.bundles[1]},
		"recovery_journal": [actual.bundles[0], actual.bundles[2]]})
	_assert_search_equivalence(actual, reference, actual.bundles, document_text, [0, 1, 2], {
		"history_proof_learn_attempts": 3, "history_proof_learn_successes": 3})
