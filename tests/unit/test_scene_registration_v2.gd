extends "res://addons/gut/test.gd"
## Full DTL registration plus pure event admission; no installed-cache mutation.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const FIXTURE := preload("res://tests/support/SceneContactFixture.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")

func _bundle(version: int = 2) -> Dictionary:
	var parsed := PARSER.parse_object(FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_reading_registration.json"))
	assert_true(parsed.ok)
	var bundle: Dictionary = parsed.value.duplicate(true)
	if version == 2:
		bundle.schema_version = 2
		bundle.contact_definitions = FIXTURE.definitions()
		bundle.contacts[0].source_fact_ids = ["TEST.fact.read"]
	return bundle

func _assert_admitted(bundle: Dictionary, expected: bool) -> void:
	assert_eq(MANIFEST.validate_scene_registration(bundle).get("ok", false), expected, "full registration")
	assert_eq(CONTRACT.validate_bundle_structure(bundle).get("ok", false), expected, "event contract")

func test_exact_v1_and_v2_admitted_without_changing_inputs() -> void:
	for version: int in [1, 2]:
		var bundle := _bundle(version)
		var before := bundle.duplicate(true)
		_assert_admitted(bundle, true)
		assert_eq(bundle, before)

func test_definitions_cannot_be_smuggled_into_v1_or_omitted_from_v2() -> void:
	var bundle := _bundle()
	bundle.schema_version = 1
	_assert_admitted(bundle, false)
	bundle.schema_version = 2
	bundle.erase("contact_definitions")
	_assert_admitted(bundle, false)

func test_unknown_version_and_extra_member_refused() -> void:
	var bundle := _bundle()
	bundle.schema_version = 3
	_assert_admitted(bundle, false)
	bundle.schema_version = 2
	bundle.authorized = true
	_assert_admitted(bundle, false)

func test_unregistered_fact_and_duplicate_definition_fact_refused() -> void:
	var bundle := _bundle()
	bundle.contacts[0].source_fact_ids = ["TEST.fact.unknown"]
	_assert_admitted(bundle, false)
	bundle = _bundle()
	bundle.contact_definitions.replies[0].source_fact_ids = ["TEST.fact.read"]
	_assert_admitted(bundle, false)

func test_malformed_contacts_fail_without_indexing_untrusted_rows() -> void:
	for bad: Variant in [null, {}, [null], [{"source_fact_ids": null}], [{"source_fact_ids": [7]}]]:
		var bundle := _bundle()
		bundle.contacts = bad
		_assert_admitted(bundle, false)

func test_definition_text_changes_whole_bundle_fingerprint() -> void:
	var bundle := _bundle()
	var first := CONTRACT.bundle_fingerprint(bundle)
	assert_true(first.ok)
	bundle.contact_definitions.messages[0].texts.en = "TEST changed incoming."
	_assert_admitted(bundle, true)
	var second := CONTRACT.bundle_fingerprint(bundle)
	assert_true(second.ok)
	assert_ne(first.value, second.value)

func test_definition_validation_does_not_replace_nested_dtl_admission() -> void:
	var bundle := _bundle()
	bundle.entry_manifest = {}
	_assert_admitted(bundle, false)
