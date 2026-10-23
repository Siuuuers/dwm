extends "res://addons/gut/test.gd"
## Closed entry vocabulary on the timeline catalog (Seven-Day Flow Plan 01 Task 4, dwm-oyo.2).
##
## WHAT THIS SUITE BINDS. scripts/data/DialogicTimelineCatalog.gd answers TWO vocabularies, and
## this suite owns exactly one of them: the closed 137-entry vocabulary of
## data/manifests/dialogic_entries.json, reached through the five methods Task 4 adds - get_entry,
## has_entry_id, get_required_entry_ids, get_required_master_paths and build_validation_report.
## tests/unit/test_timeline_manifest.gd keeps owning the legacy 59-id timeline vocabulary and is
## left byte-untouched (DEVIATION-8 Ruling X). There is no third file to consult: what is not
## asserted here is asserted there.
##
## WHY TASK 4 ADDS AND NEVER RE-POINTS (DEVIATION-8 Ruling U). The two vocabularies share only 34
## ids. hospital.faint is a timeline id with NO entry counterpart, and
## scripts/application/run/GameStateDayResolutionPort.gd returns it only while
## has_timeline_id answers for timelines.json; re-pointing that method at the 137-entry manifest
## makes the port return the empty string and moves the frozen schedule gate. A union lookup is
## equally forbidden, because specification 12.2 orders an absent id to fail closed. The
## separateness is therefore a LAW here, not an accident, and
## test_the_entry_and_timeline_vocabularies_stay_separate is what fails first if anyone merges
## them.
##
## ACCESS IDIOM. The five new methods are reached through a Script value loaded at runtime by
## tests/support/DynamicScriptProbe.gd, then called by name. That is deliberate and it is the same
## choice tests/unit/test_dialogic_entry_manifest.gd made: a statically resolved call to a method
## the production source does not declare yet is a PARSE error, which reports as a load failure
## and proves nothing, whereas the dynamic form lets this suite compile and report RED as an
## ordinary named assertion. Note that a preload of a script declaring class_name resolves to the
## CLASS and not to a Script object, so callv is unavailable on it; the probe is what supplies a
## real Script value. _guard() reads the production source and refuses to reach any dynamic call
## until all five signatures are declared, so a missing method is never an engine error. The
## legacy timeline methods are called by static syntax, because they already exist and their
## continued existence is itself a Ruling U law.
##
## TWO INDEPENDENT DERIVATIONS, NEVER ONE. Every count and every id below is pinned as a literal
## AND re-derived at runtime by parsing data/manifests/dialogic_entries.json,
## data/manifests/timelines.json and data/manifests/dialogic_ids.json off disk. A manifest defect
## cannot vouch for itself by moving both sides at once.
##
## FIXTURE-DRIVEN LAWS (DEVIATION-8 controller ruling (a)). All 137 shipped records carry a
## non-empty English label and there are 137 distinct labels, so the missing-label and
## duplicated-label laws of specification 14.1 cannot be driven by the shipped manifest at all.
## They are driven instead through DialogicEntryManifest.resolve_entry, which takes its document
## as a parameter, against a deep copy of the shipped document with exactly one field mutated.
## That is what makes them mutation-killable rather than laws that name themselves and are never
## reached.
##
## SIBLING BRANCHES ASSERT THEIR OWN MESSAGE. ENTRY_MANIFEST_UNKNOWN_ENTRY and
## ENTRY_MANIFEST_RETIRED_ENTRY are emitted by the same unregistered-entry branch, so a test that
## asserted the code alone would still pass when one of them was deleted and the other refused the
## same id. Each therefore asserts its own message fragment AND the absence of its sibling's.
##
## KNOWN UNTESTED PATHS IN THE PRODUCTION SOURCE, recorded rather than hidden. The four
## failure-propagation guards in _ensure_entries, get_entry and get_required_entry_ids fire only
## when data/manifests/dialogic_entries.json is absent, unparseable or invalid, and the
## missing-master branch of build_validation_report fires only when a shipped master is deleted.
## Reaching any of the five needs filesystem manipulation, so they are KNOWINGLY UNCOVERED on the
## same ground the three load-time codes of test_dialogic_entry_manifest.gd are. The
## validate_document CALL those guards sit around is a different case and is NOT uncovered: it is
## invisible to behaviour but load-bearing for two unguarded indexes, so it is pinned as source
## text by test_the_cached_entry_document_is_validated_before_it_is_cached.

const CATALOG_SOURCE := "res://scripts/data/DialogicTimelineCatalog.gd"
const ENTRIES_MANIFEST_PATH := "res://data/manifests/dialogic_entries.json"
const TIMELINES_MANIFEST_PATH := "res://data/manifests/timelines.json"
const IDS_MANIFEST_PATH := "res://data/manifests/dialogic_ids.json"

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const CATALOG := preload("res://scripts/data/DialogicTimelineCatalog.gd")
const ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")

const EXPECTED_ENTRY_COUNT := 137
const EXPECTED_SCENE_COUNT := 62
const EXPECTED_TIMELINE_COUNT := 64
const EXPECTED_SHARED_ID_COUNT := 33

const DEFAULT_LOCALE := "en"
const FOREIGN_LOCALE := "zh_CN"
const SECOND_FOREIGN_LOCALE := "zh_HK"

## The exact compatibility surface Task 4 orders, transcribed from the plan's own code block.
const REQUIRED_SIGNATURES := [
	"static func get_entry(entry_id: String, locale: String = \"\") -> Dictionary:",
	"static func has_entry_id(entry_id: String) -> bool:",
	"static func get_required_entry_ids() -> Array[String]:",
	"static func get_required_master_paths(locale: String = \"en\") -> Array[String]:",
	"static func build_validation_report(locale: String = \"en\") -> Dictionary:",
]

## Ruling U in executable form: Task 4 ADDS, so every legacy timeline method is still declared.
const PRESERVED_TIMELINE_SIGNATURES := [
	"static func has_timeline_id(timeline_id: String) -> bool:",
	"static func get_record(timeline_id: String) -> Dictionary:",
	"static func get_path_for_id(timeline_id: String) -> Dictionary:",
	"static func get_required_timeline_ids() -> Array[String]:",
	"static func get_timeline_path(timeline_id: String, _locale: String = \"en\") -> String:",
	"static func get_required_timeline_paths(_locale: String = \"en\") -> Array[String]:",
	"static func build_missing_timeline_report(locale: String = \"en\") -> Dictionary:",
]

const DEPRECATION_MARKER := "## DEPRECATED (Plan 01 Task 4)"

## The call that licenses the unguarded ["value"] and ["entries"] indexes further down the
## catalog. Pinned as source text because deleting it changes nothing observable against the
## shipped manifest, so no behavioural test can reach it.
const VALIDATION_CALL := "DialogicEntryManifest.validate_document(loaded[\"value\"])"

const SAMPLE_ENTRY_ID := "contact.ordinary.lavinia.day1"
const SAMPLE_ENTRY_PATH := "res://dialogic/timelines/en/contacts/lavinia_day1.dtl"
const FIRST_SORTED_ENTRY_ID := "contact.hospital_care.sylvia.day2"
const LAST_SORTED_ENTRY_ID := "hospital.faint.day7"
const ARBITRARY_SUFFIX_ID := "contact.ordinary.lavinia.day1.extra"

const RETIRED_LABEL_IDS := ["ending.lavinia.true", "ending.priscilla.true", "ending.sylvia.true"]

## Measured, not assumed: each of these resolves in exactly one of the two vocabularies.
const TIMELINE_ONLY_IDS := ["hospital.faint", "contact.lavinia.day1", "ending.sylvia"]
const ENTRY_ONLY_IDS := ["hospital.faint.day7", "ending.alone.normal", FIRST_SORTED_ENTRY_ID]

const HOSPITAL_TIMELINE_ID := "hospital.faint"
const HOSPITAL_TIMELINE_PATH := "res://dialogic/timelines/en/core/hospital_faint.dtl"


const CODE_UNKNOWN_ENTRY := &"ENTRY_MANIFEST_UNKNOWN_ENTRY"
const CODE_RETIRED_ENTRY := &"ENTRY_MANIFEST_RETIRED_ENTRY"
const CODE_ENGLISH_LOCATOR_MISSING := &"ENTRY_MANIFEST_ENGLISH_LOCATOR_MISSING"
const CODE_ENGLISH_LOCATOR_AMBIGUOUS := &"ENTRY_MANIFEST_ENGLISH_LOCATOR_AMBIGUOUS"

const ALL_FAILURE_CODES := [
	CODE_UNKNOWN_ENTRY,
	CODE_RETIRED_ENTRY,
	CODE_ENGLISH_LOCATOR_MISSING,
	CODE_ENGLISH_LOCATOR_AMBIGUOUS,
]

const UNKNOWN_FRAGMENT := "is not a registered semantic entry"
const RETIRED_FRAGMENT := "was retired by the 61-to-8 migration"
const LOCATOR_MISSING_FRAGMENT := "nothing starts and the event stays pending"
const LOCATOR_AMBIGUOUS_FRAGMENT := "entries claim the same English path and label"


# --------------------------------------------------------------------------------------------
# Loading helpers. Everything fails soft so RED is an assertion, never a script error.
# --------------------------------------------------------------------------------------------

func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return {}
	return parsed["value"]


func _entries_document() -> Dictionary:
	return _parse(ENTRIES_MANIFEST_PATH)


func _catalog_source() -> String:
	if not FileAccess.file_exists(CATALOG_SOURCE):
		return ""
	return FileAccess.get_file_as_string(CATALOG_SOURCE)


## The entry ids the shipped document declares, derived here rather than taken from the catalog.
func _document_entry_ids() -> Array:
	var out: Array = []
	for record: Variant in _entries_document().get("entries", []):
		if record is Dictionary:
			out.append(str((record as Dictionary).get("entry_id", "")))
	return out


func _expected_scene_paths() -> Array:
	var out: Array = []
	for record: Dictionary in _parse(TIMELINES_MANIFEST_PATH).get("records", []):
		if record["id"] in ["opening.day1", "tutorial.desktop_day1"]: continue
		out.append("res://" + str(record["path"]))
	out.sort()
	return out


func _timeline_ids() -> Array:
	var out: Array = []
	for record: Variant in _parse(TIMELINES_MANIFEST_PATH).get("records", []):
		if record is Dictionary:
			out.append(str((record as Dictionary).get("id", "")))
	return out


func _catalog_script() -> Script:
	var loaded: Dictionary = PROBE.load_script(CATALOG_SOURCE)
	if not loaded.get("ok", false):
		return null
	return loaded["value"] as Script


## No dynamic call is reached until the production source declares all five methods, so a missing
## method reports as this named assertion rather than as an engine-level invalid call.
func _guard() -> bool:
	var source := _catalog_source()
	if source.is_empty():
		assert_false(source.is_empty(), "expected RED: missing " + CATALOG_SOURCE)
		return false
	if _catalog_script() == null:
		assert_true(_catalog_script() != null, "expected RED: unloadable " + CATALOG_SOURCE)
		return false
	for signature: String in REQUIRED_SIGNATURES:
		if not source.contains(signature):
			assert_true(false, "expected RED: the catalog does not declare " + signature)
			return false
	if _entries_document().is_empty():
		assert_false(_entries_document().is_empty(),
			"expected RED: missing or unparseable " + ENTRIES_MANIFEST_PATH)
		return false
	return true


func _call(method: StringName, args: Array) -> Variant:
	return _catalog_script().callv(method, args)


func _entry(entry_id: String, locale: String) -> Dictionary:
	var result: Variant = _call(&"get_entry", [entry_id, locale])
	return result if result is Dictionary else {}


## Asserts the refusal AND the branch's own message, because ENTRY_MANIFEST_UNKNOWN_ENTRY and
## ENTRY_MANIFEST_RETIRED_ENTRY leave the same branch and would otherwise cover for each other.
func _reject_naming(entry_id: String, code: StringName, fragment: String, sibling: String,
		why: String) -> void:
	var result := _entry(entry_id, DEFAULT_LOCALE)
	assert_false(result.get("ok", true), why)
	assert_eq(result.get("code"), code, why + " (named code)")
	var message := str(result.get("message", ""))
	assert_true(message.contains(fragment),
		"%s (this branch's own message, not a sibling's): %s" % [why, message])
	assert_false(message.contains(sibling),
		"%s (and never the sibling branch's message): %s" % [why, message])


# --------------------------------------------------------------------------------------------
# Mutation builders. Each returns a fresh deep copy; the shipped document is never touched.
# --------------------------------------------------------------------------------------------

## Specification 14.1: a missing English label starts nothing. The shipped manifest cannot carry
## this, so the law is reached through the document-taking resolver instead.
func _with_missing_label(document: Dictionary) -> Dictionary:
	var mutated: Dictionary = document.duplicate(true)
	var locators: Dictionary = ((mutated["entries"] as Array)[0] as Dictionary)["locators"]
	(locators[DEFAULT_LOCALE] as Dictionary)["label"] = ""
	return mutated


## Specification 14.1: a duplicated English label starts nothing. The second record claims the
## first record's whole locator, so the first entry's own locator is owned twice.
func _with_duplicated_label(document: Dictionary) -> Dictionary:
	var mutated: Dictionary = document.duplicate(true)
	var entries: Array = mutated["entries"]
	var first: Dictionary = (entries[0] as Dictionary)["locators"]
	var second: Dictionary = (entries[1] as Dictionary)["locators"]
	second[DEFAULT_LOCALE] = (first[DEFAULT_LOCALE] as Dictionary).duplicate(true)
	return mutated


# --------------------------------------------------------------------------------------------
# The compatibility surface Task 4 adds, and the legacy surface it does not touch.
# --------------------------------------------------------------------------------------------

func test_the_catalog_declares_the_five_entry_methods_the_plan_orders() -> void:
	var source := _catalog_source()
	assert_false(source.is_empty(), "expected RED: missing " + CATALOG_SOURCE)
	for signature: String in REQUIRED_SIGNATURES:
		assert_true(source.contains(signature),
			"the plan's compatibility surface is declared verbatim: " + signature)


func test_the_fifty_nine_id_timeline_surface_survives_task_four() -> void:
	var source := _catalog_source()
	assert_false(source.is_empty(), "expected RED: missing " + CATALOG_SOURCE)
	for signature: String in PRESERVED_TIMELINE_SIGNATURES:
		assert_true(source.contains(signature),
			"Task 4 adds and never removes the timeline surface: " + signature)
	assert_true(source.contains(DEPRECATION_MARKER),
		"get_timeline_path is marked deprecated in comment only, and the marker is that comment")


## get_required_master_paths and get_required_entry_ids both index the cached document with no ok
## check, and the only thing that makes that sound is that the document was validated before it
## was cached. Deleting the validation is invisible to every behavioural test, because the shipped
## document is valid, so the call is pinned here instead. Without this the two unguarded indexes
## would be one silent deletion away from crashing on the next malformed manifest.
func test_the_cached_entry_document_is_validated_before_it_is_cached() -> void:
	var source := _catalog_source()
	assert_false(source.is_empty(), "expected RED: missing " + CATALOG_SOURCE)
	assert_true(source.contains(VALIDATION_CALL),
		"the document is validated before it is cached, which is what lets the two enumerating "
			+ "methods index it without a guard")


func test_every_declared_failure_code_exists_in_the_production_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/narrative/DialogicEntryManifest.gd")
	assert_false(source.is_empty(), "expected RED: missing the entry manifest source")
	for code: StringName in ALL_FAILURE_CODES:
		assert_true(source.contains("&\"" + str(code) + "\""),
			"%s: the delegated source still declares this exact failure code" % str(code))


# --------------------------------------------------------------------------------------------
# Exact resolution through the closed 137-entry manifest.
# --------------------------------------------------------------------------------------------

func test_get_entry_resolves_the_exact_registered_english_locator() -> void:
	if not _guard():
		return
	var result := _entry(SAMPLE_ENTRY_ID, DEFAULT_LOCALE)
	assert_true(result.get("ok", false), "English resolves: " + str(result.get("message", "")))
	var value: Dictionary = result.get("value", {})
	assert_eq(str(value.get("entry_id", "")), SAMPLE_ENTRY_ID, "the entry answers for itself")
	assert_eq(str(value.get("locale", "")), DEFAULT_LOCALE, "and in the default locale")
	assert_eq(str(value.get("requested_locale", "")), DEFAULT_LOCALE, "which is what was asked")
	assert_eq(str(value.get("path", "")), SAMPLE_ENTRY_PATH, "the exact registered master")
	assert_eq(str(value.get("label", "")), SAMPLE_ENTRY_ID, "and the exact registered label")
	assert_false(value.get("used_fallback", true), "the default locale never falls back")


func test_an_empty_locale_argument_is_the_default_locale() -> void:
	if not _guard():
		return
	var omitted: Variant = _call(&"get_entry", [SAMPLE_ENTRY_ID])
	var explicit := _entry(SAMPLE_ENTRY_ID, DEFAULT_LOCALE)
	assert_true((omitted as Dictionary).get("ok", false), "the one-argument form resolves")
	var value: Dictionary = (omitted as Dictionary).get("value", {})
	assert_eq(str(value.get("locale", "")), DEFAULT_LOCALE, "an omitted locale is the default one")
	assert_eq(str(value.get("requested_locale", "")), DEFAULT_LOCALE,
		"and it is recorded as the default rather than as the empty string")
	assert_false(value.get("used_fallback", true), "so it is not a fallback")
	assert_eq(str(value.get("path", "")),
		str((explicit.get("value", {}) as Dictionary).get("path", "")),
		"the one-argument and the explicit-English forms name one master")


# --------------------------------------------------------------------------------------------
# Specification 12.2: the manifest is closed and an absent id fails closed.
# --------------------------------------------------------------------------------------------

func test_get_entry_refuses_an_arbitrary_suffix() -> void:
	if not _guard():
		return
	assert_false(ARBITRARY_SUFFIX_ID in _document_entry_ids(),
		"the fixture id is genuinely unregistered")
	_reject_naming(ARBITRARY_SUFFIX_ID, CODE_UNKNOWN_ENTRY, UNKNOWN_FRAGMENT, RETIRED_FRAGMENT,
		"an unknown suffix never resolves through permissive pattern parsing")


func test_get_entry_refuses_every_retired_true_ending_label() -> void:
	if not _guard():
		return
	for retired: String in RETIRED_LABEL_IDS:
		_reject_naming(retired, CODE_RETIRED_ENTRY, RETIRED_FRAGMENT, UNKNOWN_FRAGMENT,
			"%s: a save that still carries a retired label is refused by name" % retired)


func test_has_entry_id_answers_only_for_registered_entries() -> void:
	if not _guard():
		return
	for entry_id: String in ENTRY_ONLY_IDS:
		assert_true(_call(&"has_entry_id", [entry_id]),
			"%s: a registered entry is callable" % entry_id)
	assert_false(_call(&"has_entry_id", [ARBITRARY_SUFFIX_ID]),
		"an arbitrary suffix is not callable")
	for retired: String in RETIRED_LABEL_IDS:
		assert_false(_call(&"has_entry_id", [retired]),
			"%s: a retired label is not callable either" % retired)


# --------------------------------------------------------------------------------------------
# Specification 14.1: language may change, the physical master may not.
# --------------------------------------------------------------------------------------------

func test_a_foreign_locale_falls_back_to_english_and_never_manufactures_a_path() -> void:
	if not _guard():
		return
	for locale: String in [FOREIGN_LOCALE, SECOND_FOREIGN_LOCALE]:
		var result := _entry(SAMPLE_ENTRY_ID, locale)
		assert_true(result.get("ok", false),
			"%s: a missing locale falls back rather than failing" % locale)
		var value: Dictionary = result.get("value", {})
		assert_eq(str(value.get("locale", "")), DEFAULT_LOCALE,
			"%s: the fallback is the English record" % locale)
		assert_eq(str(value.get("requested_locale", "")), locale,
			"%s: and it still records what was asked for" % locale)
		assert_true(value.get("used_fallback", false),
			"%s: the fallback is declared, never silent" % locale)
		assert_eq(str(value.get("path", "")), SAMPLE_ENTRY_PATH,
			"%s: the exact same English master, never a manufactured one" % locale)
		assert_eq(str(value.get("label", "")), SAMPLE_ENTRY_ID,
			"%s: and the exact same semantic label" % locale)
		assert_false(str(value.get("path", "")).contains(locale),
			"%s: no locale directory is ever fabricated" % locale)


func test_the_master_path_set_is_identical_for_every_locale() -> void:
	if not _guard():
		return
	var english: Array = _call(&"get_required_master_paths", [DEFAULT_LOCALE])
	for locale: String in [FOREIGN_LOCALE, SECOND_FOREIGN_LOCALE]:
		var foreign: Array = _call(&"get_required_master_paths", [locale])
		assert_eq(foreign, english,
			"%s: a fallback changes language only, so the master set cannot move" % locale)
		assert_eq(foreign, _expected_scene_paths(),
			"%s: and it is still exactly the English scene files" % locale)


# --------------------------------------------------------------------------------------------
# Enumeration. The manifest exposes none, so the catalog owns these outright.
# --------------------------------------------------------------------------------------------

func test_get_required_entry_ids_lists_all_one_hundred_thirty_seven_sorted() -> void:
	if not _guard():
		return
	var ids: Array = _call(&"get_required_entry_ids", [])
	assert_eq(ids.size(), EXPECTED_ENTRY_COUNT, "every registered entry is enumerated")
	var derived := _document_entry_ids()
	assert_eq(ids.size(), derived.size(),
		"and the count is the shipped document's own, not a transcription")
	var sorted_derived := derived.duplicate()
	sorted_derived.sort()
	assert_eq(ids, sorted_derived, "the enumeration is sorted, so its order is not the file's")
	assert_eq(str(ids[0]), FIRST_SORTED_ENTRY_ID, "the first id is the sorted first")
	assert_eq(str(ids[ids.size() - 1]), LAST_SORTED_ENTRY_ID, "and the last is the sorted last")
	var seen := {}
	for entry_id: Variant in ids:
		assert_false(seen.has(str(entry_id)), "no id is enumerated twice: " + str(entry_id))
		seen[str(entry_id)] = true


func test_get_required_master_paths_lists_scene_paths_sorted() -> void:
	if not _guard():
		return
	var paths: Array = _call(&"get_required_master_paths", [DEFAULT_LOCALE])
	assert_eq(paths, _expected_scene_paths(),
		"the 137 entries are deduplicated to the scene files, in sorted order")
	assert_eq(paths.size(), EXPECTED_SCENE_COUNT, "scene files and no more")
	var derived := {}
	for record: Variant in _entries_document().get("entries", []):
		var locator: Dictionary = ((record as Dictionary)["locators"] as Dictionary)[DEFAULT_LOCALE]
		derived[str(locator.get("path", ""))] = true
	assert_eq(derived.size(), EXPECTED_SCENE_COUNT,
		"and the shipped document independently names exactly distinct scene paths")
	for path: Variant in paths:
		assert_true(derived.has(str(path)), "no master is invented: " + str(path))
		assert_true(FileAccess.file_exists(str(path)), "and every one is on disk: " + str(path))


# --------------------------------------------------------------------------------------------
# The validation report. validate_document proves document integrity; this proves disk presence.
# --------------------------------------------------------------------------------------------

func test_build_validation_report_finds_all_scene_files_present() -> void:
	if not _guard():
		return
	var report: Dictionary = _call(&"build_validation_report", [DEFAULT_LOCALE])
	assert_eq(str(report.get("locale", "")), DEFAULT_LOCALE, "the report names its locale")
	assert_eq(report.get("entry_count"), EXPECTED_ENTRY_COUNT, "and the entries it covers")
	assert_eq(report.get("required_count"), EXPECTED_SCENE_COUNT, "and the masters they need")
	assert_eq(report.get("existing_count"), EXPECTED_SCENE_COUNT, "all of which are on disk")
	assert_eq(report.get("missing_count"), 0, "so none is missing")
	assert_eq(report.get("missing"), [], "and the missing list is empty rather than absent")


func test_build_validation_report_echoes_the_requested_locale() -> void:
	if not _guard():
		return
	var report: Dictionary = _call(&"build_validation_report", [FOREIGN_LOCALE])
	assert_eq(str(report.get("locale", "")), FOREIGN_LOCALE,
		"the report echoes what was asked, so a caller can tell which locale it describes")
	assert_eq(report.get("required_count"), EXPECTED_SCENE_COUNT,
		"while the master set itself is locale-independent")
	assert_eq(report.get("missing_count"), 0, "and still complete")


# --------------------------------------------------------------------------------------------
# DEVIATION-8 Ruling U. The two vocabularies coexist; neither is re-pointed at the other.
# --------------------------------------------------------------------------------------------

func test_the_two_vocabularies_share_exactly_thirty_three_ids() -> void:
	if not _guard():
		return
	var entry_ids := _document_entry_ids()
	var timeline_ids := _timeline_ids()
	assert_eq(entry_ids.size(), EXPECTED_ENTRY_COUNT, "137 entry ids")
	assert_eq(timeline_ids.size(), EXPECTED_TIMELINE_COUNT, "64 timeline ids")
	var shared: Array = []
	for entry_id: Variant in entry_ids:
		if str(entry_id) in timeline_ids:
			shared.append(str(entry_id))
	assert_eq(shared.size(), EXPECTED_SHARED_ID_COUNT,
		"the vocabularies overlap in 33 ids, so neither can stand in for the other")


func test_the_entry_and_timeline_vocabularies_stay_separate() -> void:
	if not _guard():
		return
	assert_eq(CATALOG.get_required_timeline_ids().size(), EXPECTED_TIMELINE_COUNT,
		"the timeline vocabulary is current at 64")
	var entry_ids: Array = _call(&"get_required_entry_ids", [])
	assert_eq(entry_ids.size(), EXPECTED_ENTRY_COUNT, "the entry vocabulary is current at 137")
	for timeline_id: String in TIMELINE_ONLY_IDS:
		assert_true(CATALOG.has_timeline_id(timeline_id),
			"%s: still resolves as a timeline id" % timeline_id)
		assert_false(_call(&"has_entry_id", [timeline_id]),
			"%s: and is not a semantic entry, so the two must not be merged" % timeline_id)
	for entry_id: String in ENTRY_ONLY_IDS:
		assert_true(_call(&"has_entry_id", [entry_id]),
			"%s: resolves as a semantic entry" % entry_id)
		assert_false(CATALOG.has_timeline_id(entry_id),
			"%s: and is not a timeline id" % entry_id)


func test_has_timeline_id_still_answers_for_the_hospital_locator() -> void:
	if not _guard():
		return
	assert_true(CATALOG.has_timeline_id(HOSPITAL_TIMELINE_ID),
		"GameStateDayResolutionPort returns hospital.faint only while this answers true")
	assert_eq(CATALOG.get_timeline_path(HOSPITAL_TIMELINE_ID), HOSPITAL_TIMELINE_PATH,
		"and get_timeline_path still resolves through timelines.json, never through get_entry")
	var refused := _entry(HOSPITAL_TIMELINE_ID, DEFAULT_LOCALE)
	assert_false(refused.get("ok", true),
		"the entry vocabulary has no hospital.faint, which is exactly why nothing was re-pointed")
	assert_eq(refused.get("code"), CODE_UNKNOWN_ENTRY, "and it fails closed by name")


# --------------------------------------------------------------------------------------------
# Fixture-driven English locator laws (DEVIATION-8 controller ruling (a), specification 14.1).
# --------------------------------------------------------------------------------------------

func test_the_shipped_manifest_cannot_drive_the_two_label_laws() -> void:
	if not _guard():
		return
	var labels := {}
	for record: Variant in _entries_document().get("entries", []):
		var locator: Dictionary = ((record as Dictionary)["locators"] as Dictionary)[DEFAULT_LOCALE]
		var label := str(locator.get("label", ""))
		assert_false(label.is_empty(), "every shipped record carries an English label")
		assert_false(labels.has(label), "and no label is shipped twice: " + label)
		labels[label] = true
	assert_eq(labels.size(), EXPECTED_ENTRY_COUNT,
		"so the missing-label and duplicated-label laws need a fabricated document, not this one")


func test_a_missing_english_label_starts_nothing() -> void:
	if not _guard():
		return
	var document := _entries_document()
	var entry_id := str(((document["entries"] as Array)[0] as Dictionary)["entry_id"])
	var result: Dictionary = ENTRY_MANIFEST.resolve_entry(
		_with_missing_label(document), entry_id, DEFAULT_LOCALE)
	assert_false(result.get("ok", true), "a missing English label starts nothing")
	assert_eq(result.get("code"), CODE_ENGLISH_LOCATOR_MISSING, "under its own named code")
	assert_true(str(result.get("message", "")).contains(LOCATOR_MISSING_FRAGMENT),
		"and the pending event is preserved: " + str(result.get("message", "")))


func test_a_duplicated_english_locator_starts_nothing() -> void:
	if not _guard():
		return
	var document := _entries_document()
	var entry_id := str(((document["entries"] as Array)[0] as Dictionary)["entry_id"])
	var result: Dictionary = ENTRY_MANIFEST.resolve_entry(
		_with_duplicated_label(document), entry_id, DEFAULT_LOCALE)
	assert_false(result.get("ok", true), "a duplicated English locator starts nothing")
	assert_eq(result.get("code"), CODE_ENGLISH_LOCATOR_AMBIGUOUS, "under its own named code")
	assert_true(str(result.get("message", "")).contains(LOCATOR_AMBIGUOUS_FRAGMENT),
		"and it names the ambiguity rather than guessing an owner: "
			+ str(result.get("message", "")))
