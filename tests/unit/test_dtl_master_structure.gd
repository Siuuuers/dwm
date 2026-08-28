extends "res://addons/gut/test.gd"
## The eight plot-neutral master timelines and the validator that proves them
## (Seven-Day Flow Plan 01 Task 3, sub-commit 3A, dwm-oyo.2).
##
## WHY THIS SUITE IS AN ADD AND NOT A REPLACE (DEVIATION-7 Ruling Q). The plan orders "Replace:
## tests/smoke_dialogic_timelines.gd". That file is an `extends SceneTree` CLI, not a GUT suite, so
## the plan's own `-gtest=` invocation cannot run it; and it carries live coverage the replacement
## would silently drop - the fixture contract (3/1/1/1/1 counts, completion, restore) and an
## unconditional-pass audit over all of res://tests. Under Ruling O the legacy timeline manifest
## stays at 61 records, so that smoke stays green and keeps its coverage. The structural
## assertions the plan asks for land here instead, and the smoke is left byte-untouched.
##
## TWO INDEPENDENT DERIVATIONS, NEVER ONE. Every count below is re-derived from
## data/manifests/dialogic_entries.json at runtime AND pinned as a literal. A manifest defect
## cannot vouch for itself by moving both sides at once: the literals are what a reviewer reads,
## the re-derivation is what catches a manifest that quietly changed underneath them. This is the
## same discipline sub-commit 2A adopted after survivor S08, where a count pinned only by a code
## cross-check turned out to be silently deletable.
##
## MESSAGE FRAGMENTS ARE ASSERTED, NOT JUST CODES. The sub-commit 2B campaign proved that sibling
## branches of one law share a single failure code, so a test asserting only the code still passes
## when the branch it targets is deleted and the sibling refuses the same document. Every
## validator law below therefore asserts a distinguishing fragment of the message as well as the
## code. C18 and C41 in 2B died to NOTHING BUT their message-asserting test.
##
## THE RULING O LAW IS COVERED HERE BECAUSE NOTHING ELSE COVERS IT. Measured at 1c4682a3:
## tools/dialogic/TimelineManifestBuilder.gd is referenced by exactly one file in the repository,
## tools/dialogic/validate_manifests.gd, and by ZERO tests. So the Ruling O change - scoping the
## walk to subdirectories so the eight masters never enter timelines.json - would land with no
## test reaching it and would be deletable in silence, restoring the landmine it exists to remove.
## test_the_legacy_builder_never_sees_a_master and its siblings are that coverage.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")
const BUILDER := preload("res://tools/dialogic/TimelineManifestBuilder.gd")

const VALIDATOR_SOURCE_PATH := "res://tools/dialogic/DtlStructureValidator.gd"
const GENERATOR_SOURCE_PATH := "res://tools/dialogic/generate_master_skeletons.gd"
const CLI_SOURCE_PATH := "res://tools/dialogic/validate_dialogic_contract.gd"

const MASTER_DIR := "res://dialogic/timelines/en/"
const LEGACY_ROOT := "res://dialogic/timelines/en"

const EXPECTED_MASTER_COUNT := 8
const EXPECTED_ENTRY_COUNT := 139
const EXPECTED_LEGACY_FILE_COUNT := 61

## The Phase 01 Verification Gate figure, in the manifest's own master order.
const EXPECTED_MASTER_LABEL_COUNTS := {
	"res://dialogic/timelines/en/day_1.dtl": 10,
	"res://dialogic/timelines/en/day_2.dtl": 24,
	"res://dialogic/timelines/en/day_3.dtl": 20,
	"res://dialogic/timelines/en/day_4.dtl": 13,
	"res://dialogic/timelines/en/day_5.dtl": 13,
	"res://dialogic/timelines/en/day_6.dtl": 24,
	"res://dialogic/timelines/en/day_7.dtl": 17,
	"res://dialogic/timelines/en/endings.dtl": 18,
}

## Every failure code DtlStructureValidator can report. Read as text off the validator source
## below, so a rename cannot pass unnoticed even where a branch is hard to reach from a fixture.
const DECLARED_FAILURE_CODES := [
	"DTL_FILE_MISSING", "DTL_EMPTY", "DTL_CARRIAGE_RETURN", "DTL_HEADER_MISSING",
	"DTL_LEADING_RETURN_MISSING", "DTL_DUPLICATE_LABEL", "DTL_LABEL_FALLTHROUGH",
	"DTL_TRAILING_FALLTHROUGH", "DTL_UNREGISTERED_LABEL", "DTL_MISSING_LABEL",
	"DTL_LABEL_ORDER_MISMATCH", "DTL_PURPOSE_MISMATCH", "DTL_SIGNAL_COMMENT_MISMATCH",
	"DTL_UNREGISTERED_SIGNAL", "DTL_ANNOTATION_MISSING", "DTL_DIRECT_DOMAIN_CALL",
	"DTL_DYNAMIC_RESOURCE_PATH", "DTL_DIALOGUE_LINE", "DTL_UNEXPECTED_EVENT",
]

var _document: Dictionary = {}
var _partition: Dictionary = {}


func before_all() -> void:
	var loaded: Dictionary = MANIFEST.load_default()
	if loaded.get("ok", false):
		_document = loaded["value"]
		_partition = VALIDATOR.partition_by_master(_document)


# ---------------------------------------------------------------------------
# The manifest partition: what each master is required to hold.
# ---------------------------------------------------------------------------


func test_the_manifest_partitions_into_exactly_eight_masters() -> void:
	assert_eq(_partition.size(), EXPECTED_MASTER_COUNT,
		"the 139 registered entries partition onto exactly 8 owning masters")


func test_the_partition_holds_every_registered_entry_exactly_once() -> void:
	var total := 0
	for path: Variant in _partition:
		total += (_partition[path] as Array).size()
	assert_eq(total, EXPECTED_ENTRY_COUNT,
		"the partition holds all %d registered entries" % EXPECTED_ENTRY_COUNT)
	assert_eq(int(_document.get("entry_count", -1)), EXPECTED_ENTRY_COUNT,
		"the manifest agrees with its own declared entry_count")


func test_every_locator_label_occurs_exactly_once_across_all_masters() -> void:
	var seen: Dictionary = {}
	var duplicates: Array = []
	for path: Variant in _partition:
		for record: Variant in (_partition[path] as Array):
			var label := str((record as Dictionary)["label"])
			if seen.has(label):
				duplicates.append(label)
			seen[label] = true
	assert_eq(duplicates.size(), 0, "no label is registered twice: %s" % str(duplicates))
	assert_eq(seen.size(), EXPECTED_ENTRY_COUNT,
		"exactly %d distinct labels are registered" % EXPECTED_ENTRY_COUNT)


func test_the_per_master_label_counts_are_the_verification_gate_figure() -> void:
	for path: Variant in EXPECTED_MASTER_LABEL_COUNTS:
		var master_path := str(path)
		assert_true(_partition.has(master_path), "%s is a registered master" % master_path)
		if not _partition.has(master_path):
			continue
		assert_eq((_partition[master_path] as Array).size(),
			int(EXPECTED_MASTER_LABEL_COUNTS[master_path]),
			"%s owns its Verification Gate label count" % master_path)


func test_the_seven_day_masters_and_the_endings_master_are_the_whole_registry() -> void:
	var registered: Array = []
	for path: Variant in _partition:
		registered.append(str(path))
	registered.sort()
	var expected: Array = []
	for path: Variant in EXPECTED_MASTER_LABEL_COUNTS:
		expected.append(str(path))
	expected.sort()
	assert_eq(registered, expected, "the registry names exactly the eight plan-mandated masters")


func test_every_registered_master_path_is_a_res_path_in_the_masters_directory() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		assert_true(master_path.begins_with(MASTER_DIR),
			"%s lives directly under %s" % [master_path, MASTER_DIR])
		var tail := master_path.substr(MASTER_DIR.length())
		assert_false(tail.contains("/"),
			"%s is at the masters root, not in a legacy subdirectory" % master_path)


# ---------------------------------------------------------------------------
# The shipped masters on disk.
# ---------------------------------------------------------------------------


func test_exactly_eight_master_files_exist_on_disk() -> void:
	var present: Array = []
	for path: Variant in EXPECTED_MASTER_LABEL_COUNTS:
		if FileAccess.file_exists(str(path)):
			present.append(str(path))
	assert_eq(present.size(), EXPECTED_MASTER_COUNT,
		"all %d masters exist; present: %s" % [EXPECTED_MASTER_COUNT, str(present.size())])


func test_every_shipped_master_validates_clean() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		var result: Dictionary = VALIDATOR.validate_file(master_path, _partition[path])
		var failures: Array = result.get("failures", [])
		var first := ""
		if not failures.is_empty():
			first = str((failures[0] as Dictionary)["message"])
		assert_true(result.get("ok", false), "%s validates clean; first failure: %s" %
			[master_path, first])


func test_the_first_executable_event_in_each_master_is_return() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be inspected" % master_path)
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(master_path).split("\n")
		assert_true(lines.size() >= 2, "%s holds a header and a leading terminator" % master_path)
		if lines.size() < 2:
			continue
		assert_eq(lines[0], VALIDATOR.HEADER_COMMENT, "%s opens with the master header" % master_path)
		assert_eq(lines[1], VALIDATOR.TERMINATOR,
			"%s makes %s its first executable event" % [master_path, VALIDATOR.TERMINATOR])


func test_each_public_label_closes_with_its_own_return() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be inspected" % master_path)
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(master_path).split("\n")
		var open_label := ""
		var closed := true
		var leaks: Array = []
		for raw: String in lines:
			if raw.begins_with(VALIDATOR.LABEL_PREFIX):
				if open_label != "" and not closed:
					leaks.append(open_label)
				open_label = raw.substr(VALIDATOR.LABEL_PREFIX.length())
				closed = false
			elif raw == VALIDATOR.TERMINATOR and open_label != "":
				closed = true
		if open_label != "" and not closed:
			leaks.append(open_label)
		assert_eq(leaks.size(), 0, "%s: no label falls into its neighbour: %s" %
			[master_path, str(leaks)])


func test_the_label_count_on_disk_matches_the_registered_count() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be counted" % master_path)
			continue
		var labels := 0
		for raw: String in FileAccess.get_file_as_string(master_path).split("\n"):
			if raw.begins_with(VALIDATOR.LABEL_PREFIX):
				labels += 1
		assert_eq(labels, (_partition[path] as Array).size(),
			"%s holds one label per registered entry" % master_path)


func test_the_masters_hold_no_dialogue_no_resource_path_and_no_domain_call() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be inspected" % master_path)
			continue
		var offenders: Array = []
		var index := 0
		for raw: String in FileAccess.get_file_as_string(master_path).split("\n"):
			index += 1
			if raw.is_empty() or raw == VALIDATOR.TERMINATOR:
				continue
			if raw.begins_with(VALIDATOR.LABEL_PREFIX):
				continue
			if raw == VALIDATOR.HEADER_COMMENT or raw == VALIDATOR.CAUSAL_LINE:
				continue
			if raw == VALIDATOR.VARIATION_LINE:
				continue
			if raw.begins_with(VALIDATOR.PURPOSE_PREFIX) or raw.begins_with(VALIDATOR.SIGNALS_PREFIX):
				continue
			offenders.append("%d:%s" % [index, raw])
		assert_eq(offenders.size(), 0,
			"%s holds only structural lines; found: %s" % [master_path, str(offenders)])


func test_the_masters_are_lf_only_with_a_single_trailing_newline() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be inspected" % master_path)
			continue
		var text := FileAccess.get_file_as_string(master_path)
		assert_false(text.contains("\r"), "%s carries no CR" % master_path)
		assert_true(text.ends_with("\n"), "%s ends with a newline" % master_path)
		assert_false(text.ends_with("\n\n"), "%s ends with exactly one newline" % master_path)


func test_every_purpose_annotation_is_the_registered_role() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be inspected" % master_path)
			continue
		var roles: Dictionary = {}
		for record: Variant in (_partition[path] as Array):
			roles[str((record as Dictionary)["label"])] = str((record as Dictionary)["role"])
		var current := ""
		var mismatches: Array = []
		for raw: String in FileAccess.get_file_as_string(master_path).split("\n"):
			if raw.begins_with(VALIDATOR.LABEL_PREFIX):
				current = raw.substr(VALIDATOR.LABEL_PREFIX.length())
			elif raw.begins_with(VALIDATOR.PURPOSE_PREFIX) and current != "":
				var declared := raw.substr(VALIDATOR.PURPOSE_PREFIX.length())
				if declared != str(roles.get(current, "")):
					mismatches.append("%s:%s" % [current, declared])
		assert_eq(mismatches.size(), 0,
			"%s annotates each label with its registered role; mismatches: %s" %
			[master_path, str(mismatches)])


func test_every_signal_annotation_is_the_registered_array_in_stored_order() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be inspected" % master_path)
			continue
		var expected: Dictionary = {}
		for record: Variant in (_partition[path] as Array):
			var parts: PackedStringArray = []
			for signal_id: Variant in ((record as Dictionary)["allowed_signals"] as Array):
				parts.append(str(signal_id))
			expected[str((record as Dictionary)["label"])] = ", ".join(parts)
		var current := ""
		var mismatches: Array = []
		for raw: String in FileAccess.get_file_as_string(master_path).split("\n"):
			if raw.begins_with(VALIDATOR.LABEL_PREFIX):
				current = raw.substr(VALIDATOR.LABEL_PREFIX.length())
			elif raw.begins_with(VALIDATOR.SIGNALS_PREFIX) and current != "":
				var declared := raw.substr(VALIDATOR.SIGNALS_PREFIX.length())
				if declared != str(expected.get(current, "")):
					mismatches.append("%s:%s" % [current, declared])
		assert_eq(mismatches.size(), 0,
			"%s emits the stored signal order verbatim; mismatches: %s" %
			[master_path, str(mismatches)])


func test_no_master_declares_a_signal_the_manifest_did_not_register() -> void:
	var registered: Dictionary = {}
	for path: Variant in _partition:
		for record: Variant in (_partition[path] as Array):
			for signal_id: Variant in ((record as Dictionary)["allowed_signals"] as Array):
				registered[str(signal_id)] = true
	assert_true(registered.size() > 0, "the manifest registers at least one signal")
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			continue
		for raw: String in FileAccess.get_file_as_string(master_path).split("\n"):
			if not raw.begins_with(VALIDATOR.SIGNALS_PREFIX):
				continue
			for piece: String in raw.substr(VALIDATOR.SIGNALS_PREFIX.length()).split(","):
				var signal_id := piece.strip_edges()
				assert_true(registered.has(signal_id),
					"%s: %s is a registered signal id" % [master_path, signal_id])


# ---------------------------------------------------------------------------
# Whole-file identity. The two tests below are the only ones that pin the format as a WHOLE
# rather than one annotation at a time, and they are why a generator defect cannot ship.
# ---------------------------------------------------------------------------


## Rebuilds every master here, independently of the generator, and demands byte equality.
##
## This is a THIRD derivation of the same bytes. The generator builds them inside Godot from
## DialogicEntryManifest; this suite builds them again from the same manifest without touching the
## generator. Every piecewise assertion above could pass while the file as a whole drifted - a
## stray blank line, a lost trailing newline, a reordered block - and none of them would catch it.
## Whole-file equality catches all of it at once.
func test_each_master_is_byte_identical_to_a_fresh_derivation_from_the_manifest() -> void:
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be compared" % master_path)
			continue
		var lines: PackedStringArray = [VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR]
		for candidate: Variant in (_partition[path] as Array):
			var record: Dictionary = candidate
			var parts: PackedStringArray = []
			for signal_id: Variant in (record["allowed_signals"] as Array):
				parts.append(str(signal_id))
			lines.append("")
			lines.append(VALIDATOR.LABEL_PREFIX + str(record["label"]))
			lines.append(VALIDATOR.PURPOSE_PREFIX + str(record["role"]))
			lines.append(VALIDATOR.CAUSAL_LINE)
			lines.append(VALIDATOR.VARIATION_LINE)
			lines.append(VALIDATOR.SIGNALS_PREFIX + ", ".join(parts))
			lines.append(VALIDATOR.TERMINATOR)
		var expected := "\n".join(lines) + "\n"
		assert_eq(FileAccess.get_file_as_string(master_path), expected,
			"%s is byte-identical to a fresh derivation from the manifest" % master_path)


## Proves regeneration is a byte-identical no-op, which is the property that makes the masters
## safe to overwrite rather than hand-edit.
##
## The generator extends SceneTree, so it is PRELOADED and its static builder is called directly.
## It is never instantiated: instantiating would construct a SceneTree and execute the tool, which
## would rewrite all eight masters from inside a test run.
func test_the_generator_rebuilds_every_shipped_master_byte_for_byte() -> void:
	var generator: GDScript = load(GENERATOR_SOURCE_PATH)
	assert_not_null(generator, "%s loads as a script" % GENERATOR_SOURCE_PATH)
	if generator == null:
		return
	for path: Variant in _partition:
		var master_path := str(path)
		if not FileAccess.file_exists(master_path):
			assert_true(false, "%s must exist to be compared" % master_path)
			continue
		var rebuilt: String = generator.call(&"_build", _partition[path])
		assert_eq(rebuilt, FileAccess.get_file_as_string(master_path),
			"regenerating %s is a byte-identical no-op" % master_path)


# ---------------------------------------------------------------------------
# Ruling O: the legacy builder must never see a master.
# ---------------------------------------------------------------------------


func test_the_legacy_builder_never_sees_a_master() -> void:
	var listed: Array = BUILDER._list_dtl_files(LEGACY_ROOT)
	var masters: Array = []
	for candidate: Variant in listed:
		if EXPECTED_MASTER_LABEL_COUNTS.has(str(candidate)):
			masters.append(str(candidate))
	assert_eq(masters.size(), 0,
		"the legacy timeline builder collects zero masters; found %s" % str(masters))


func test_the_legacy_builder_still_collects_every_legacy_timeline() -> void:
	var listed: Array = BUILDER._list_dtl_files(LEGACY_ROOT)
	assert_eq(listed.size(), EXPECTED_LEGACY_FILE_COUNT,
		"the legacy timeline builder still collects all %d legacy .dtl files" %
		EXPECTED_LEGACY_FILE_COUNT)


func test_every_path_the_legacy_builder_collects_lives_in_a_subdirectory() -> void:
	var listed: Array = BUILDER._list_dtl_files(LEGACY_ROOT)
	assert_false(listed.is_empty(), "expected RED: the builder collected nothing")
	for candidate: Variant in listed:
		var path := str(candidate)
		assert_true(path.begins_with(MASTER_DIR), "%s is under the locale root" % path)
		var tail := path.substr(MASTER_DIR.length())
		assert_true(tail.contains("/"),
			"%s is in a subdirectory, not at the locale root" % path)


# ---------------------------------------------------------------------------
# The validator's own laws, on in-memory fixtures. One test per reachable code.
# ---------------------------------------------------------------------------


func _one_entry() -> Array:
	return [{
		"label": "opening.day1",
		"role": "opening",
		"allowed_signals": ["history.line.witness"],
	}]


func _good_text() -> String:
	return "%s\n%s\n\n%sopening.day1\n%sopening\n%s\n%s\n%shistory.line.witness\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR, VALIDATOR.LABEL_PREFIX,
		VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE, VALIDATOR.VARIATION_LINE,
		VALIDATOR.SIGNALS_PREFIX, VALIDATOR.TERMINATOR,
	]


func _codes(result: Dictionary) -> Array:
	var out: Array = []
	for failure: Variant in (result.get("failures", []) as Array):
		out.append(str((failure as Dictionary)["code"]))
	return out


func _messages(result: Dictionary) -> String:
	var out: Array = []
	for failure: Variant in (result.get("failures", []) as Array):
		out.append(str((failure as Dictionary)["message"]))
	return " | ".join(PackedStringArray(out))


## How MANY times a code was reported. Asserting presence is not enough where two independent
## branches share one code: sub-commit 3A campaign sites V22 and V23 each deleted one of the two
## DTL_ANNOTATION_MISSING branches and survived, because the surviving sibling still reported the
## code the test asked for.
func _count(result: Dictionary, code: String) -> int:
	var total := 0
	for entry: Variant in _codes(result):
		if str(entry) == code:
			total += 1
	return total


func test_the_reference_fixture_validates_clean() -> void:
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", _good_text(), _one_entry())
	assert_true(result.get("ok", false),
		"the reference fixture is clean; failures: %s" % _messages(result))


func test_the_validator_rejects_an_empty_master() -> void:
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", "", _one_entry())
	assert_has(_codes(result), "DTL_EMPTY", "an empty master is refused")
	assert_string_contains(_messages(result), "master is empty", "the message names emptiness")
	## Campaign site V32 made `ok` unconditionally true and survived every other test in this
	## suite, because they all read `failures` and none read `ok`. Both the generator's pre-write
	## check and the CLI branch on `ok`, so an always-true `ok` would let the generator write a
	## master its own validator rejects.
	assert_false(result.get("ok", true), "a refused master reports ok false, not merely failures")


func test_the_validator_rejects_a_carriage_return() -> void:
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl",
		_good_text().replace("\n", "\r\n"), _one_entry())
	assert_has(_codes(result), "DTL_CARRIAGE_RETURN", "a CRLF master is refused")
	assert_string_contains(_messages(result), "LF-only", "the message names the LF-only law")


func test_the_validator_rejects_a_missing_header() -> void:
	var text := _good_text().replace(VALIDATOR.HEADER_COMMENT, "# something else")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_HEADER_MISSING", "a foreign header is refused")
	assert_string_contains(_messages(result), "line 1 must be exactly",
		"the message names the header law")


func test_the_validator_rejects_a_missing_leading_return() -> void:
	var text := "%s\n\n%sopening.day1\n%sopening\n%s\n%s\n%shistory.line.witness\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.LABEL_PREFIX, VALIDATOR.PURPOSE_PREFIX,
		VALIDATOR.CAUSAL_LINE, VALIDATOR.VARIATION_LINE, VALIDATOR.SIGNALS_PREFIX,
		VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_LEADING_RETURN_MISSING",
		"a master whose first executable event is not return is refused")
	assert_string_contains(_messages(result), "first executable event",
		"the message names the leading-terminator law")


func test_the_validator_rejects_a_duplicate_label() -> void:
	var text := _good_text() + "\n%sopening.day1\n%sopening\n%s\n%s\n%shistory.line.witness\n%s\n" % [
		VALIDATOR.LABEL_PREFIX, VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE,
		VALIDATOR.VARIATION_LINE, VALIDATOR.SIGNALS_PREFIX, VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_DUPLICATE_LABEL", "a twice-declared label is refused")
	assert_string_contains(_messages(result), "is declared twice",
		"the message names the duplicate")


func test_the_validator_rejects_a_label_that_falls_into_its_neighbour() -> void:
	var expected: Array = _one_entry()
	expected.append({
		"label": "tutorial.desktop_day1",
		"role": "tutorial",
		"allowed_signals": ["history.line.witness"],
	})
	var text := "%s\n%s\n\n%sopening.day1\n%sopening\n%s\n%s\n%shistory.line.witness\n\n%stutorial.desktop_day1\n%stutorial\n%s\n%s\n%shistory.line.witness\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR, VALIDATOR.LABEL_PREFIX,
		VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE, VALIDATOR.VARIATION_LINE,
		VALIDATOR.SIGNALS_PREFIX, VALIDATOR.LABEL_PREFIX, VALIDATOR.PURPOSE_PREFIX,
		VALIDATOR.CAUSAL_LINE, VALIDATOR.VARIATION_LINE, VALIDATOR.SIGNALS_PREFIX,
		VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, expected)
	assert_has(_codes(result), "DTL_LABEL_FALLTHROUGH", "an unterminated label is refused")
	assert_string_contains(_messages(result), "falls through into",
		"the message names both the leaking label and the one it leaks into")


func test_the_validator_rejects_a_final_label_that_never_returns() -> void:
	var text := _good_text().substr(0, _good_text().length() - (VALIDATOR.TERMINATOR.length() + 1))
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_TRAILING_FALLTHROUGH",
		"a final label with no terminator is refused")
	assert_string_contains(_messages(result), "never reaches",
		"the message names the unterminated final label")


func test_the_validator_rejects_an_unregistered_label() -> void:
	var text := _good_text().replace("opening.day1", "invented.entry")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_UNREGISTERED_LABEL", "an invented label is refused")
	assert_string_contains(_messages(result), "is not registered for this master",
		"the message names the unregistered label")


func test_the_validator_rejects_a_registered_label_with_no_block() -> void:
	var expected: Array = _one_entry()
	expected.append({
		"label": "tutorial.desktop_day1",
		"role": "tutorial",
		"allowed_signals": ["history.line.witness"],
	})
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", _good_text(), expected)
	assert_has(_codes(result), "DTL_MISSING_LABEL",
		"a registered entry with no label in the master is refused")
	assert_string_contains(_messages(result), "has no label in this master",
		"the message names the entry that resolves to nothing")
	## Campaign site V21 dropped the equal-sizes guard on the order check and survived. With the
	## guard gone a master that is merely INCOMPLETE also reports a spurious order failure, which
	## buries the one diagnosis a caller can act on.
	assert_false(_codes(result).has("DTL_LABEL_ORDER_MISMATCH"),
		"an incomplete master is diagnosed as missing an entry, not as mis-ordered")


func test_the_validator_rejects_a_purpose_that_is_not_the_registered_role() -> void:
	var text := _good_text().replace(VALIDATOR.PURPOSE_PREFIX + "opening",
		VALIDATOR.PURPOSE_PREFIX + "tutorial")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_PURPOSE_MISMATCH", "a wrong role annotation is refused")
	assert_string_contains(_messages(result), "but is registered as",
		"the message names the declared role and the registered one")


func test_the_validator_rejects_a_signal_comment_in_the_wrong_order() -> void:
	var expected: Array = [{
		"label": "contact.ordinary.lavinia.day1",
		"role": "ordinary_message",
		"allowed_signals": ["history.line.witness", "message.echo.satisfy", "message.reply.commit"],
	}]
	var text := "%s\n%s\n\n%scontact.ordinary.lavinia.day1\n%sordinary_message\n%s\n%s\n%smessage.reply.commit, history.line.witness, message.echo.satisfy\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR, VALIDATOR.LABEL_PREFIX,
		VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE, VALIDATOR.VARIATION_LINE,
		VALIDATOR.SIGNALS_PREFIX, VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, expected)
	assert_has(_codes(result), "DTL_SIGNAL_COMMENT_MISMATCH",
		"a reordered signal comment is refused even though every member is registered")
	assert_false(_codes(result).has("DTL_UNREGISTERED_SIGNAL"),
		"reordering is not an unregistered-signal failure; the members are all registered")
	assert_string_contains(_messages(result), "in stored order",
		"the message names the stored-order law")


func test_the_validator_rejects_an_unregistered_signal() -> void:
	var text := _good_text().replace(VALIDATOR.SIGNALS_PREFIX + "history.line.witness",
		VALIDATOR.SIGNALS_PREFIX + "history.line.invented")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_UNREGISTERED_SIGNAL", "an invented signal is refused")
	assert_string_contains(_messages(result), "declares unregistered signal",
		"the message names the unregistered signal")


func test_the_validator_rejects_a_block_with_no_annotations() -> void:
	var text := "%s\n%s\n\n%sopening.day1\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR, VALIDATOR.LABEL_PREFIX,
		VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_ANNOTATION_MISSING", "an unannotated block is refused")
	## Campaign sites V22 and V23 each deleted ONE of the two branches that report this code and
	## both survived: the block below carries neither annotation, so whichever branch remained
	## still satisfied a bare assert_has and a bare "carries no". Counting them and naming each
	## annotation is what makes the two branches independently killable.
	assert_eq(_count(result, "DTL_ANNOTATION_MISSING"), 2,
		"BOTH the missing purpose and the missing signal annotation are reported")
	assert_string_contains(_messages(result),
		"carries no %s annotation" % VALIDATOR.PURPOSE_PREFIX.strip_edges(),
		"the missing purpose annotation is named")
	assert_string_contains(_messages(result),
		"carries no %s annotation" % VALIDATOR.SIGNALS_PREFIX.strip_edges(),
		"the missing signal annotation is named")


func test_the_validator_rejects_a_direct_domain_call() -> void:
	var text := _good_text().replace(VALIDATOR.CAUSAL_LINE, "GameState.advance_day()")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_DIRECT_DOMAIN_CALL", "a domain call is refused")
	assert_string_contains(_messages(result), "calls into a domain object directly",
		"the message names the direct call")


func test_the_validator_rejects_a_resource_path() -> void:
	var text := _good_text().replace(VALIDATOR.CAUSAL_LINE, "res://art/portraits/lavinia.png")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_DYNAMIC_RESOURCE_PATH", "an arbitrary visual path is refused")
	assert_string_contains(_messages(result), "names a resource path",
		"the message names the resource path")


func test_the_validator_rejects_a_dialogue_line() -> void:
	var text := _good_text().replace(VALIDATOR.CAUSAL_LINE, "Lavinia: are you awake")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_DIALOGUE_LINE", "a dialogue line is refused")
	assert_string_contains(_messages(result), "structural mode holds no dialogue",
		"the message names structural mode")


func test_the_validator_rejects_an_unregistered_annotation() -> void:
	var text := _good_text().replace(VALIDATOR.CAUSAL_LINE, "# MOOD: wistful")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_UNEXPECTED_EVENT", "a foreign annotation is refused")
	assert_string_contains(_messages(result), "unregistered annotation",
		"the message names the foreign annotation")


func test_the_validator_rejects_a_terminator_outside_any_block() -> void:
	var text := "%s\n%s\n\n%s\n\n%sopening.day1\n%sopening\n%s\n%s\n%shistory.line.witness\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR, VALIDATOR.TERMINATOR,
		VALIDATOR.LABEL_PREFIX, VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE,
		VALIDATOR.VARIATION_LINE, VALIDATOR.SIGNALS_PREFIX, VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_UNEXPECTED_EVENT", "a stray terminator is refused")
	assert_string_contains(_messages(result), "outside any label block",
		"the message names the stray terminator")


func test_the_validator_reports_a_missing_file_rather_than_passing_it() -> void:
	var result: Dictionary = VALIDATOR.validate_file(
		"res://dialogic/timelines/en/does_not_exist.dtl", _one_entry())
	assert_has(_codes(result), "DTL_FILE_MISSING", "an absent master is a failure, not a pass")
	assert_string_contains(_messages(result), "does not exist", "the message names the absence")


func test_the_validator_collects_every_failure_rather_than_stopping_at_the_first() -> void:
	var text := _good_text().replace(VALIDATOR.HEADER_COMMENT, "# wrong").replace(
		VALIDATOR.PURPOSE_PREFIX + "opening", VALIDATOR.PURPOSE_PREFIX + "tutorial")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_true(_codes(result).size() >= 2,
		"independent defects are reported together, not one run at a time: %s" % str(_codes(result)))
	assert_has(_codes(result), "DTL_HEADER_MISSING", "the header defect is reported")
	assert_has(_codes(result), "DTL_PURPOSE_MISMATCH", "the role defect is reported too")


# ---------------------------------------------------------------------------
# Published spelling. A rename is caught even where a branch is hard to reach.
# ---------------------------------------------------------------------------


func test_the_validator_declares_every_failure_code_this_suite_names() -> void:
	assert_true(FileAccess.file_exists(VALIDATOR_SOURCE_PATH),
		"%s exists" % VALIDATOR_SOURCE_PATH)
	var source := FileAccess.get_file_as_string(VALIDATOR_SOURCE_PATH)
	for code: Variant in DECLARED_FAILURE_CODES:
		assert_string_contains(source, "&\"%s\"" % str(code),
			"%s is declared in the validator" % str(code))


func test_the_generator_and_the_cli_are_the_ruling_n_files() -> void:
	assert_true(FileAccess.file_exists(GENERATOR_SOURCE_PATH),
		"%s exists" % GENERATOR_SOURCE_PATH)
	assert_true(FileAccess.file_exists(CLI_SOURCE_PATH),
		"%s exists; Ruling N moved the CLI off validate_manifests.gd" % CLI_SOURCE_PATH)
	assert_true(FileAccess.file_exists("res://tools/dialogic/validate_manifests.gd"),
		"the legacy Plan-05 generator is left in place, byte-untouched")



# ---------------------------------------------------------------------------
# Laws the sub-commit 3A mutation campaign proved were declared but unexercised.
# Each test below names the campaign site that survived without it.
# ---------------------------------------------------------------------------


## DTL_LABEL_ORDER_MISMATCH was declared, spelled-checked, and never exercised: campaign sites
## V20 (delete the branch) and V21 (drop its guard) both survived. The order law is what Ruling
## O+P leans on - the manifest's record order IS the generated label order - so an unreachable
## branch here is precisely this repository's recurring defect, a test that names a law but never
## reaches it.
func test_the_validator_rejects_a_label_order_that_is_not_the_manifest_order() -> void:
	var expected: Array = _one_entry()
	expected.append({
		"label": "tutorial.desktop_day1",
		"role": "tutorial",
		"allowed_signals": ["history.line.witness"],
	})
	var text := "%s\n%s\n\n%stutorial.desktop_day1\n%stutorial\n%s\n%s\n%shistory.line.witness\n%s\n\n%sopening.day1\n%sopening\n%s\n%s\n%shistory.line.witness\n%s\n" % [
		VALIDATOR.HEADER_COMMENT, VALIDATOR.TERMINATOR,
		VALIDATOR.LABEL_PREFIX, VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE,
		VALIDATOR.VARIATION_LINE, VALIDATOR.SIGNALS_PREFIX, VALIDATOR.TERMINATOR,
		VALIDATOR.LABEL_PREFIX, VALIDATOR.PURPOSE_PREFIX, VALIDATOR.CAUSAL_LINE,
		VALIDATOR.VARIATION_LINE, VALIDATOR.SIGNALS_PREFIX, VALIDATOR.TERMINATOR,
	]
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, expected)
	assert_has(_codes(result), "DTL_LABEL_ORDER_MISMATCH",
		"a master whose blocks run in the wrong order is refused")
	assert_string_contains(_messages(result), "does not match the registered manifest order",
		"the message names the order law")
	assert_false(_codes(result).has("DTL_UNREGISTERED_LABEL"),
		"both labels are registered; reordering is not an unregistered-label failure")
	assert_false(_codes(result).has("DTL_MISSING_LABEL"),
		"both labels are present; reordering is not a missing-label failure")


## The hazard classifier is ORDERED on purpose: a dynamic path INSIDE a call is reported as a
## path, because that is the actionable half of the diagnosis. Campaign site V28 swapped the two
## branches and survived, because every fixture until now used a bare path with no parentheses -
## so the documented ordering was never actually tested.
func test_a_resource_path_inside_a_call_is_reported_as_a_path_not_as_a_call() -> void:
	var text := _good_text().replace(VALIDATOR.CAUSAL_LINE,
		'load("res://art/portraits/lavinia.png")')
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_DYNAMIC_RESOURCE_PATH",
		"a path wrapped in a call is still a path failure")
	assert_false(_codes(result).has("DTL_DIRECT_DOMAIN_CALL"),
		"the path branch is checked first; the call diagnosis would bury the actionable half")
	assert_string_contains(_messages(result), "names a resource path",
		"the message names the resource path")


## Campaign site V29 narrowed the path condition to res:// alone and survived, because no fixture
## used a user:// path.
func test_a_user_path_is_refused_as_a_dynamic_resource_path() -> void:
	var text := _good_text().replace(VALIDATOR.CAUSAL_LINE, "user://saves/profile_4.json")
	var result: Dictionary = VALIDATOR.validate_text("fixture.dtl", text, _one_entry())
	assert_has(_codes(result), "DTL_DYNAMIC_RESOURCE_PATH",
		"a user:// path is a dynamic resource path too")


## The generator emits a registered signal array in its STORED order and must not sort it
## (DEVIATION-7 controller ruling (b)). Every record in the shipped manifest happens to store its
## signals alphabetically, so the shipped masters CANNOT distinguish a sorting generator from a
## faithful one - campaign site G08 inserted a sort and survived every other test here. This calls
## the builder directly with an array the shipped manifest could never supply.
func test_the_generator_emits_a_signal_array_in_stored_order_not_sorted() -> void:
	var generator: GDScript = load(GENERATOR_SOURCE_PATH)
	assert_not_null(generator, "%s loads as a script" % GENERATOR_SOURCE_PATH)
	if generator == null:
		return
	var records: Array = [{
		"label": "opening.day1",
		"role": "opening",
		"allowed_signals": ["message.reply.commit", "history.line.witness"],
	}]
	var built: String = generator.call(&"_build", records)
	assert_string_contains(built,
		VALIDATOR.SIGNALS_PREFIX + "message.reply.commit, history.line.witness",
		"the generator emits the registered array as stored, never sorted")


## THREE FILES DECLARE THE SAME TWO EXPECTATIONS AND NOTHING MADE THEM AGREE. The generator and
## the CLI each pin their own EXPECTED_MASTER_COUNT and EXPECTED_ENTRY_COUNT inside an
## `extends SceneTree` _run() that no GUT suite can reach without executing the tool. Campaign
## sites G09, G10, C02 and C03 changed those literals and all four survived, and C01 moved the
## CLI's master directory up one level and survived too. They are read as text for the same
## reason the failure codes are: a constant no test can reach is a constant that drifts in
## silence, and three files disagreeing about how many masters exist is exactly the defect the
## Verification Gate figure exists to prevent.
func test_the_generator_and_the_cli_pin_the_counts_this_suite_pins() -> void:
	for path: Variant in [GENERATOR_SOURCE_PATH, CLI_SOURCE_PATH]:
		var source := FileAccess.get_file_as_string(str(path))
		assert_string_contains(source, "const EXPECTED_MASTER_COUNT := %d" % EXPECTED_MASTER_COUNT,
			"%s pins the same master count as this suite" % str(path))
		assert_string_contains(source, "const EXPECTED_ENTRY_COUNT := %d" % EXPECTED_ENTRY_COUNT,
			"%s pins the same entry count as this suite" % str(path))
	assert_string_contains(FileAccess.get_file_as_string(CLI_SOURCE_PATH),
		'const MASTER_DIR := "%s"' % MASTER_DIR,
		"the CLI resolves masters under the same directory this suite pins")
