extends GutTest
## The cache must emit exactly the canonical whole document while encoding only changed operations.
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class CountingJournal extends "res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd":
	var encodes := 0
	func _serialize_operation(operation: Dictionary) -> Dictionary:
		encodes += 1
		return super._serialize_operation(operation)

func _document() -> Dictionary:
	return {"schema_version": JOURNAL.SCHEMA_VERSION, "operations": {
		"\u65e7\u8bb0\u5f55": {"receipt": {"amount": 1, "ratio": 1.0}, "text": "quote \" / newline\n"},
		"new": {"receipt": {"amount": 2}, "text": "retained"}}}

func test_reuses_unchanged_history_and_matches_canonical_utf8_order() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	var first: Dictionary = journal._serialize_document(document)
	assert_eq(first, WRITER.stringify(document))
	assert_eq(journal.encodes, 2)
	assert_eq(journal._serialize_document(document.duplicate(true)), first)
	assert_eq(journal.encodes, 2, "unchanged detached history is not encoded again")
	document.operations.new.receipt.amount = 3
	assert_eq(journal._serialize_document(document), WRITER.stringify(document))
	assert_eq(journal.encodes, 3, "a changed operation alone is encoded")

func test_single_operation_hint_matches_whole_canonical_for_change_new_entry_and_cache_miss() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	assert_true(journal._serialize_document(document).ok)
	document.operations.new.receipt.amount = 3
	var changed: Dictionary = journal._serialize_document(document, "new")
	assert_eq(changed, WRITER.stringify(document))
	assert_eq(journal.encodes, 3, "the hinted operation alone is encoded")
	document.operations["later"] = {"receipt": {"amount": 4}, "text": "new cache miss"}
	var appended: Dictionary = journal._serialize_document(document, "later")
	assert_eq(appended, WRITER.stringify(document))
	assert_eq(journal.encodes, 4, "a hinted cache miss encodes the new operation exactly once")


func test_generic_path_detects_unhinted_history_mutation_and_numeric_subtype() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	assert_true(journal._serialize_document(document).ok)
	document.operations["\u65e7\u8bb0\u5f55"].receipt.amount = 1.0
	var changed: Dictionary = journal._serialize_document(document)
	assert_eq(changed, WRITER.stringify(document), "generic callers scan every detached operation")
	assert_eq(journal.encodes, 3, "integer to integral-float provenance invalidates generic reuse")


func test_hinted_encoding_failure_keeps_prior_proof_and_exact_retry_succeeds() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	var original: Dictionary = journal._serialize_document(document)
	document.operations.new.receipt.amount = NAN
	assert_false(journal._serialize_document(document, "new").ok)
	document.operations.new.receipt.amount = 2
	assert_eq(journal._serialize_document(document, "new"), original)
	assert_eq(journal.encodes, 4, "failed hinted encoding never replaces the prior detached proof")


func test_nested_mutation_and_equal_numeric_values_cannot_reuse_stale_bytes() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	assert_true(journal._serialize_document(document).ok)
	document.operations.new.receipt.amount = 2.0
	var changed: Dictionary = journal._serialize_document(document)
	assert_eq(changed, WRITER.stringify(document), "integral floats keep the canonical decimal marker")
	assert_eq(journal.encodes, 3, "deep equality is type preserving")
	document.operations.new.receipt.amount = 2
	assert_eq(journal._serialize_document(document), WRITER.stringify(document))
	assert_eq(journal.encodes, 4, "cache snapshots do not alias caller mutations")

func test_removed_history_does_not_accumulate_cache_entries() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	assert_true(journal._serialize_document(document).ok)
	document.operations.erase("\u65e7\u8bb0\u5f55")
	assert_eq(journal._serialize_document(document), WRITER.stringify(document))
	assert_eq(journal._operation_text_cache.size(), 1)
	document.operations.clear()
	assert_eq(journal._serialize_document(document), WRITER.stringify(document))
	assert_true(journal._operation_text_cache.is_empty())

func test_failed_encoding_does_not_poison_previous_operation_proof() -> void:
	var journal := CountingJournal.new()
	var document := _document()
	var valid: Dictionary = journal._serialize_document(document)
	document.operations.new.receipt.amount = NAN
	assert_false(journal._serialize_document(document).ok)
	document.operations.new.receipt.amount = 2
	assert_eq(journal._serialize_document(document), valid)
	assert_eq(journal.encodes, 3, "failure retained only the previous valid detached proof")

func test_strict_cold_parse_is_reused_without_aliasing_or_relaxing_schema() -> void:
	var journal := CountingJournal.new()
	var text := '{"operations":{},"schema_version":999}'
	var parsed: Dictionary = journal._parse_document(text)
	assert_true(parsed.ok)
	assert_false(journal._validate_document(parsed.value).ok, "parse proof never authorizes a foreign schema")
	parsed.value.schema_version = JOURNAL.SCHEMA_VERSION
	assert_eq(journal._parse_document(text).value.schema_version, 999, "cached parse is detached")
	assert_true(journal._parse_known_document(text).value.is_empty(), "atomic syntax checks reuse exact previously parsed bytes")
	assert_false(journal._parse_document('{"duplicate":1,"duplicate":2}').ok)
	assert_false(journal._validated_text_documents.has('{"duplicate":1,"duplicate":2}'))

func test_parse_proof_lru_keeps_active_outgoing_current_and_backup_texts() -> void:
	var journal := CountingJournal.new()
	for text: String in ['{"a":1}', '{"b":2}', '{"c":3}']:
		assert_true(journal._parse_document(text).ok)
	journal._parse_known_document('{"a":1}')
	journal._parse_document('{"d":4}')
	assert_eq(journal._validated_text_documents.size(), 3)
	assert_true(journal._validated_text_documents.has('{"a":1}'), "storage read refreshed the active proof")
	assert_false(journal._validated_text_documents.has('{"b":2}'), "least recently used proof was evicted")
