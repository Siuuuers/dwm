extends "res://addons/gut/test.gd"
## Semantic visual identity on ArtManifest (Seven-Day Flow Plan 01 Task 6, dwm-oyo.2).
##
## WHAT THIS SUITE BINDS. DEVIATION-11 Ruling C gives Task 6 CLOSURE LAWS ONLY, over an EMPTY typed
## registry in scripts/data/ArtManifest.gd. The strict record shape and its refusal laws are
## authored and proven in the REFUSAL direction against fabricated records. NO art path is
## invented in the shipped registry and NO neutral fallback record is created, because the
## repository owns exactly one non-addon image file and no verified neutral asset exists. The
## affirmative resolution path over a REAL asset therefore stays knowingly unexercised until one
## does, exactly as observer.evidence.commit denial is knowingly uncovered.
##
## THE REQUIRED HOME CONFLICT, AND HOW IT IS RESOLVED. The plan's record shape carries a required
## key; specification 12.2 and all 137 shipped entries make requiredness a property of the
## (entry, visual) EDGE via visual_ids.required. Ruling C settles it for the specification, so the
## record's key is given a narrower subordinate meaning: it is a CONSENT flag declaring whether
## this visual is ELIGIBLE to be required. It never causes a visual to be required. The edge is
## what asks, which is why resolve_visual takes requiredness as its third PARAMETER and reads the
## record's own required only to check consent. That keeps the plan's five-field shape byte for
## byte, keeps the specification authoritative, and gives the field a load-bearing job instead of
## leaving it inert.
##
## FABRICATED FIXTURES ONLY. Every record below is fabricated in-test. Nothing here reads the disk,
## resolves a res:// path, or requires an asset to exist - the fabricated resource paths are never
## resolved by any law under test, and the repository already refuses nonexistent art paths this
## way in tests/unit/test_dtl_master_structure.gd.
##
## ACCESS IDIOM. Every production call goes through Object.call(&"name", ...) on a Script value
## loaded by tests/support/DynamicScriptProbe.gd, and every constant through
## get_script_constant_map(). A preload of a script declaring class_name resolves to the CLASS and
## not to a Script object, and a statically resolved call to a method the production source does
## not declare yet is a PARSE error that reports as a load failure and proves nothing. The dynamic
## form lets this suite compile and report RED as an ordinary named assertion.
##
## TASK 6 JOINS, IT DOES NOT REPLACE. The six legacy statics are kept byte-identical:
## docs/superpowers/plans/2026-07-17-phase-2r-foundation-repair.md carries a standing prohibition
## naming this exact path; current handoff guidance also requires real dependency review
## before retirement. test_the_six_legacy_statics_are_untouched_and_still_return_empty fails if
## anyone deletes them.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const SCRIPT_PATH := "res://scripts/data/ArtManifest.gd"

const PRIMARY_ID := "visual.fabricated.primary"
const FALLBACK_ID := "visual.fabricated.fallback"
const UNDECLARED_ID := "visual.fabricated.undeclared"

## The five fields the plan's record shape fixes, in the order the production constant declares.
const EXPECTED_RECORD_FIELDS := [
	"fallback_visual_id", "required", "resource_path", "resource_type", "visual_id",
]
const EXPECTED_RESOURCE_TYPES := ["Texture2D"]

## The six legacy statics this task joins rather than replaces.
const LEGACY_STATIC_NAMES := [
	"get_expected_art_paths", "get_path", "get_expected_size",
	"get_daily_main_scene_paths", "get_missing_art_report", "set_overlay_info",
]

const CODE_RECORD_SHAPE := &"ART_MANIFEST_RECORD_SHAPE"
const CODE_VISUAL_ID_INVALID := &"ART_MANIFEST_VISUAL_ID_INVALID"
const CODE_RESOURCE_PATH_INVALID := &"ART_MANIFEST_RESOURCE_PATH_INVALID"
const CODE_RESOURCE_TYPE_UNKNOWN := &"ART_MANIFEST_RESOURCE_TYPE_UNKNOWN"
const CODE_REQUIRED_INVALID := &"ART_MANIFEST_REQUIRED_INVALID"
const CODE_FALLBACK_INVALID := &"ART_MANIFEST_FALLBACK_INVALID"
const CODE_DUPLICATE_VISUAL_ID := &"ART_MANIFEST_DUPLICATE_VISUAL_ID"
const CODE_FALLBACK_UNDECLARED := &"ART_MANIFEST_FALLBACK_UNDECLARED"
const CODE_FALLBACK_CHAIN := &"ART_MANIFEST_FALLBACK_CHAIN"
const CODE_REQUIRED_VISUAL_MISSING := &"ART_MANIFEST_REQUIRED_VISUAL_MISSING"
const CODE_VISUAL_UNREGISTERED := &"ART_MANIFEST_VISUAL_UNREGISTERED"
const CODE_REQUIRED_NOT_ELIGIBLE := &"ART_MANIFEST_REQUIRED_NOT_ELIGIBLE"
const CODE_REQUIRED_SUBSTITUTION_FORBIDDEN := &"ART_MANIFEST_REQUIRED_SUBSTITUTION_FORBIDDEN"

const ALL_ART_MANIFEST_CODES := [
	CODE_RECORD_SHAPE, CODE_VISUAL_ID_INVALID, CODE_RESOURCE_PATH_INVALID,
	CODE_RESOURCE_TYPE_UNKNOWN, CODE_REQUIRED_INVALID, CODE_FALLBACK_INVALID,
	CODE_DUPLICATE_VISUAL_ID, CODE_FALLBACK_UNDECLARED, CODE_FALLBACK_CHAIN,
	CODE_REQUIRED_VISUAL_MISSING, CODE_VISUAL_UNREGISTERED, CODE_REQUIRED_NOT_ELIGIBLE,
	CODE_REQUIRED_SUBSTITUTION_FORBIDDEN,
]

var _script: Script

func before_all() -> void:
	var loaded: Dictionary = PROBE.load_script(SCRIPT_PATH)
	if loaded.get("ok", false):
		_script = loaded["value"] as Script

# --------------------------------------------------------------------------------------------
# Fixtures and helpers. Everything fails soft so RED is an assertion, never a script error.
# --------------------------------------------------------------------------------------------

## Refuses to reach a dynamic call until the closure laws exist.
func _guard() -> bool:
	if _script == null:
		assert_true(false, "expected RED: missing " + SCRIPT_PATH)
		return false
	var names: Array = []
	for method: Dictionary in _script.get_script_method_list():
		names.append(str(method.get("name", "")))
	for declared: String in ["validate_visual_record", "validate_visual_registry", "resolve_visual"]:
		if not names.has(declared):
			assert_true(false, "expected RED: " + SCRIPT_PATH + " declares no " + declared)
			return false
	return true

func _constants() -> Dictionary:
	if _script == null:
		return {}
	return _script.get_script_constant_map()

## The reference record. Every refusal fixture is this record with exactly ONE field spoiled, so
## each test isolates one law. The resource path is fabricated and no law under test resolves it.
func _record(overrides: Dictionary = {}) -> Dictionary:
	var record: Dictionary = {
		"visual_id": PRIMARY_ID,
		"resource_path": "res://art/fabricated/primary.png",
		"resource_type": "Texture2D",
		"required": false,
		"fallback_visual_id": null,
	}
	for key: Variant in overrides:
		record[str(key)] = overrides[key]
	return record

## A terminal record, eligible as the declared fallback of another.
func _fallback_record(overrides: Dictionary = {}) -> Dictionary:
	var record: Dictionary = _record({
		"visual_id": FALLBACK_ID,
		"resource_path": "res://art/fabricated/fallback.png",
	})
	for key: Variant in overrides:
		record[str(key)] = overrides[key]
	return record

## The primary record, declaring the terminal record as its fallback, beside that terminal record.
func _registry_with_fallback() -> Array:
	return [_record({"fallback_visual_id": FALLBACK_ID}), _fallback_record()]

func _validate_record(record: Variant) -> Dictionary:
	return _script.call(&"validate_visual_record", record)

func _validate_registry(records: Array) -> Dictionary:
	return _script.call(&"validate_visual_registry", records)

func _resolve(records: Array, visual_id: String, required: bool) -> Dictionary:
	return _script.call(&"resolve_visual", records, visual_id, required)

# --------------------------------------------------------------------------------------------
# The shipped registry, and the two closed vocabularies.
# --------------------------------------------------------------------------------------------

func test_the_shipped_visual_registry_is_empty() -> void:
	if not _guard():
		return
	assert_eq(_constants().get("VISUAL_RECORDS"), [],
		"no art path is invented while no verified neutral asset exists")
	assert_eq(_script.call(&"visual_records"), [],
		"and the public accessor reports the same empty registry")

func test_the_record_field_set_is_exactly_the_five_declared_fields() -> void:
	if not _guard():
		return
	assert_eq(_constants().get("VISUAL_RECORD_FIELDS"), EXPECTED_RECORD_FIELDS,
		"the plan fixes these five fields and no others, sorted")

func test_the_resource_type_allowlist_is_exactly_texture_2d() -> void:
	if not _guard():
		return
	assert_eq(_constants().get("VISUAL_RESOURCE_TYPES"), EXPECTED_RESOURCE_TYPES,
		"a second type is added only when a verified asset of that type exists")

func test_a_well_formed_record_and_registry_are_accepted() -> void:
	if not _guard():
		return
	var validated: Dictionary = _validate_record(_record())
	assert_true(validated.get("ok", false),
		"the closure laws refuse defects, not everything: " + str(validated))
	var registry: Dictionary = _validate_registry(_registry_with_fallback())
	assert_true(registry.get("ok", false),
		"and a primary beside its declared terminal fallback is a legitimate registry: "
		+ str(registry))
	assert_eq(registry.get("value"), [PRIMARY_ID, FALLBACK_ID],
		"and it reports the ids it declared, in registration order")

# --------------------------------------------------------------------------------------------
# Record closure. The exact five-field set, then each field's own value law.
# --------------------------------------------------------------------------------------------

func test_a_record_that_is_not_an_object_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(PRIMARY_ID)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_RECORD_SHAPE, "a bare string is not a visual record")

func test_a_record_with_an_extra_field_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(_record({"resource_group": "backgrounds"}))
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_RECORD_SHAPE,
		"the field set is closed, so an unknown field is a closure defect")

func test_a_record_missing_required_is_refused_by_shape_naming_the_field() -> void:
	if not _guard():
		return
	var spoiled: Dictionary = _record()
	spoiled.erase("required")
	var result: Dictionary = _validate_record(spoiled)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_RECORD_SHAPE,
		"a missing field is a closure defect, not a value defect")
	assert_true(str(result.get("message", "")).contains("required"),
		"and the message names the field the code does not: " + str(result))

func test_an_empty_visual_id_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(_record({"visual_id": ""}))
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_VISUAL_ID_INVALID, "the empty string is not an identity")
	assert_eq(_validate_record(_record({"visual_id": 7})).get("code"), CODE_VISUAL_ID_INVALID,
		"and neither is an integer: both halves of the guard are law")

func test_a_nonstring_resource_path_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(_record({"resource_path": 7}))
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_RESOURCE_PATH_INVALID, "a resource path is a string")
	assert_eq(_validate_record(_record({"resource_path": ""})).get("code"),
		CODE_RESOURCE_PATH_INVALID, "and a nonempty one: both halves of the guard are law")

func test_an_unknown_resource_type_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(_record({"resource_type": "PackedScene"}))
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_RESOURCE_TYPE_UNKNOWN,
		"the type allowlist is closed, not merely a string check")

func test_a_nonbool_required_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(_record({"required": "true"}))
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_REQUIRED_INVALID,
		"a consent flag is a boolean, and a truthy string is not one")

func test_a_nonstring_nonnull_fallback_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_record(_record({"fallback_visual_id": 7}))
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_FALLBACK_INVALID,
		"a fallback is null or a nonempty visual id")
	assert_eq(_validate_record(_record({"fallback_visual_id": ""})).get("code"),
		CODE_FALLBACK_INVALID, "the empty string is neither null nor an id")

# --------------------------------------------------------------------------------------------
# Registry closure. Uniqueness, declared fallbacks, and terminal fallbacks.
# --------------------------------------------------------------------------------------------

func test_two_records_sharing_a_visual_id_are_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_registry([_record(), _record()])
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_DUPLICATE_VISUAL_ID,
		"one id resolving to two records is an ambiguity, not a preference")

func test_a_fallback_naming_no_record_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _validate_registry([_record({"fallback_visual_id": UNDECLARED_ID})])
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_FALLBACK_UNDECLARED,
		"an optional visual resolves only to a DECLARED fallback id")

func test_a_fallback_record_declaring_its_own_fallback_is_refused() -> void:
	if not _guard():
		return
	var chained: Array = [
		_record({"fallback_visual_id": FALLBACK_ID}),
		_fallback_record({"fallback_visual_id": UNDECLARED_ID}),
		_record({"visual_id": UNDECLARED_ID, "resource_path": "res://art/fabricated/third.png"}),
	]
	var result: Dictionary = _validate_registry(chained)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_FALLBACK_CHAIN,
		"fallbacks are terminal, so following one can never loop")

# --------------------------------------------------------------------------------------------
# Resolution. The edge asks; the record consents.
# --------------------------------------------------------------------------------------------

func test_a_required_visual_with_no_record_is_refused_before_playback() -> void:
	if not _guard():
		return
	var result: Dictionary = _resolve([_fallback_record()], PRIMARY_ID, true)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_REQUIRED_VISUAL_MISSING,
		"a required visual with no record is a content gap, refused before playback")

func test_an_optional_visual_with_no_record_is_refused_as_unregistered() -> void:
	if not _guard():
		return
	var result: Dictionary = _resolve([_fallback_record()], PRIMARY_ID, false)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_VISUAL_UNREGISTERED,
		"an unregistered optional id is an identity error, a different failure from a content gap")

func test_a_required_visual_whose_record_declares_required_false_is_refused() -> void:
	if not _guard():
		return
	var result: Dictionary = _resolve([_record()], PRIMARY_ID, true)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_REQUIRED_NOT_ELIGIBLE,
		"the edge may ask, but a record that declares no consent may not be required")
	var doubly_spoiled: Array = [
		_record({"fallback_visual_id": FALLBACK_ID}),
		_fallback_record(),
	]
	assert_eq(_resolve(doubly_spoiled, PRIMARY_ID, true).get("code"), CODE_REQUIRED_NOT_ELIGIBLE,
		"consent is judged BEFORE substitution, so a record that fails both reports ineligibility")

## The one affirmative law of the required path. Without it, collapsing the substitution guard
## to a bare `if required:` would refuse EVERY required visual and no other test would notice.
func test_a_required_visual_that_consents_and_declares_no_fallback_resolves() -> void:
	if not _guard():
		return
	var result: Dictionary = _resolve([_record({"required": true})], PRIMARY_ID, true)
	assert_true(result.get("ok", false),
		"a consenting required visual with no fallback resolves: " + str(result))
	var value: Dictionary = result.get("value", {})
	assert_eq(value.get("visual_id"), PRIMARY_ID, "and answers with the record asked for")
	assert_true(value.get("required", false), "carrying its declared consent")
	assert_null(value.get("fallback_visual_id"), "and no substitute")

func test_a_required_visual_may_not_declare_a_fallback() -> void:
	if not _guard():
		return
	var records: Array = [
		_record({"required": true, "fallback_visual_id": FALLBACK_ID}),
		_fallback_record(),
	]
	var result: Dictionary = _resolve(records, PRIMARY_ID, true)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_REQUIRED_SUBSTITUTION_FORBIDDEN,
		"papering a required visual over with a neutral image is what the law forbids")

func test_a_wrong_typed_record_is_refused_at_resolution_with_the_validators_own_code() -> void:
	if not _guard():
		return
	var result: Dictionary = _resolve([_record({"resource_type": "PackedScene"})], PRIMARY_ID, false)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), CODE_RESOURCE_TYPE_UNKNOWN,
		"resolution delegates and returns the owning validator's own named code, not a generic one")

func test_an_optional_visual_resolves_to_itself_and_reports_its_declared_fallback() -> void:
	if not _guard():
		return
	var result: Dictionary = _resolve(_registry_with_fallback(), PRIMARY_ID, false)
	assert_true(result.get("ok", false), "the one positive law: " + str(result))
	var value: Dictionary = result.get("value", {})
	assert_eq(value.get("visual_id"), PRIMARY_ID, "resolution answers with the record asked for")
	assert_eq(value.get("fallback_visual_id"), FALLBACK_ID,
		"and reports the declared fallback the caller may substitute")
	assert_eq(value.get("resource_type"), "Texture2D", "carrying the record's declared type")

## Every value that leaves this module is a deep copy. Without it a caller could reach through a
## resolved record and poison the registry it came from, which is the aliasing defect the repo
## already guards against at DialogicBridge._entry_record.
func test_resolution_hands_back_a_copy_and_never_an_alias_into_the_registry() -> void:
	if not _guard():
		return
	var records: Array = _registry_with_fallback()
	var first: Dictionary = _resolve(records, PRIMARY_ID, false)
	assert_true(first.get("ok", false), str(first))
	var original: String = str((first.get("value", {}) as Dictionary).get("resource_path"))
	((first["value"]) as Dictionary)["resource_path"] = "res://art/fabricated/poisoned.png"
	var second: Dictionary = _resolve(records, PRIMARY_ID, false)
	assert_eq((second.get("value", {}) as Dictionary).get("resource_path"), original,
		"mutating a resolved record must not reach back into the registry")
	var shipped: Array = _script.call(&"visual_records")
	shipped.append({"visual_id": "visual.fabricated.injected"})
	assert_eq(_script.call(&"visual_records"), [],
		"and the shipped registry accessor hands back a copy too")

# --------------------------------------------------------------------------------------------
# Source-text pins: the code vocabulary, and the six statics Task 6 joins rather than replaces.
# --------------------------------------------------------------------------------------------

## Both directions: every declared code is spelled exactly this way in the source, AND the source
## declares no code this suite does not pin. The second half is what fails when a fourteenth code
## is introduced without a test for it.
func test_the_art_manifest_code_vocabulary_is_exactly_the_thirteen_this_suite_pins() -> void:
	assert_true(FileAccess.file_exists(SCRIPT_PATH), "expected RED: missing " + SCRIPT_PATH)
	if not FileAccess.file_exists(SCRIPT_PATH):
		return
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	for code: StringName in ALL_ART_MANIFEST_CODES:
		assert_true(source.contains("&\"" + str(code) + "\""),
			"%s: the production source still declares this exact failure code" % str(code))
	var matcher := RegEx.new()
	matcher.compile("&\"(ART_MANIFEST_[A-Z_]+)\"")
	var found: Dictionary = {}
	for found_match: RegExMatch in matcher.search_all(source):
		found[found_match.get_string(1)] = true
	var declared: Array = found.keys()
	declared.sort()
	var pinned: Array = []
	for code: StringName in ALL_ART_MANIFEST_CODES:
		pinned.append(str(code))
	pinned.sort()
	assert_eq(declared, pinned,
		"the source declares no ART_MANIFEST code this suite does not pin behaviourally")

func test_legacy_path_apis_now_describe_optional_placements_without_inventing_paths() -> void:
	if not _guard():
		return
	_script.call(&"reload_placements")
	var paths: Dictionary = _script.call(&"get_expected_art_paths")
	assert_true(paths.has("ui.title"))
	assert_eq(_script.call(&"get_path", "ui", "title"), "res://art/ui/title/background.png")
	assert_eq(_script.call(&"get_path", "backgrounds", "example"), "")
	assert_eq(_script.call(&"get_expected_size", "res://art/ui/title/background.png"), Vector2i(960, 656))
	assert_eq(_script.call(&"get_expected_size", "res://art/fabricated/primary.png"), Vector2i.ZERO)
	assert_eq(_script.call(&"get_daily_main_scene_paths", 0), {})
	assert_false((_script.call(&"get_daily_main_scene_paths", 1) as Dictionary).is_empty())
