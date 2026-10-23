extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/ProfileManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const READER := preload("res://scripts/validation/StrictJson.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

var _entries_before: Dictionary

func before_each() -> void:
	_entries_before = SIGNATURE._entries.duplicate(true)

func after_each() -> void:
	SIGNATURE._entries = _entries_before

func _text(profile: Dictionary) -> String:
	var encoded := WRITER.stringify(profile)
	assert_true(encoded.ok, str(encoded))
	return str(encoded.value)

func test_repeated_profile_reads_are_detached_and_preserve_json_types() -> void:
	var manager: Node = autofree(MANAGER.new())
	var profile := SCHEMA.make_defaults()
	var text := _text(profile)
	var first: Dictionary = manager._profile_text_validator(text)
	assert_true(first.ok, str(first))
	if not first.ok: return
	first.value.preferences.audio.music_volume = 0.25
	first.value.visited_line_ids.append("caller-mutation")
	var second: Dictionary = manager._profile_text_validator(text)
	assert_true(second.ok, str(second))
	assert_eq(second.value, profile)
	assert_eq(typeof(second.value.preferences.audio.music_volume), TYPE_FLOAT)
	second.value.preferences.clear()
	assert_eq(manager._profile_text_validator(text).value, profile)

func test_changed_and_malformed_text_cannot_reuse_another_profile() -> void:
	var manager: Node = autofree(MANAGER.new())
	var profile := SCHEMA.make_defaults()
	var first := _text(profile)
	assert_true(manager._profile_text_validator(first).ok)
	profile.preferences.audio.music_volume = 0.25
	var changed := _text(profile)
	assert_eq(manager._profile_text_validator(changed).value, profile)
	for malformed: String in ["{", "[]", "{\"schema_version\":10,\"schema_version\":10}"]:
		var expected := READER.parse_object(malformed)
		assert_false(expected.ok)
		assert_eq(manager._profile_text_validator(malformed), expected)
		assert_eq(manager._profile_text_validator(malformed), expected)
	assert_eq(manager._profile_text_validator(changed).value, profile)
	assert_eq(manager._profile_text_validator(first).value, SCHEMA.make_defaults())

func test_oversized_valid_text_keeps_result_without_retaining_it() -> void:
	var manager: Node = autofree(MANAGER.new())
	var profile := SCHEMA.make_defaults()
	var small := _text(profile)
	assert_true(manager._profile_text_validator(small).ok)
	var oversized := small + " ".repeat(MANAGER._PROFILE_PARSE_MAX_BYTES)
	var result: Dictionary = manager._profile_text_validator(oversized)
	assert_true(result.ok, str(result))
	assert_eq(result.value, profile)
	assert_true(manager._profile_parsed_document.is_empty())
	assert_eq(manager._profile_parsed_text, "")
	assert_eq(manager._profile_text_validator(small).value, profile)

func test_same_text_revalidates_changed_presentation_registry() -> void:
	var manager: Node = autofree(MANAGER.new())
	var signature := {"schema_version": 1, "entry_id": "ending.alone.normal",
		"fields": {"ending_role": "core", "ending_form": "alone_normal"}}
	var admitted := SIGNATURE.validate(signature)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	var identity: String = admitted.value.signature_id
	var profile := SCHEMA.make_defaults()
	profile.reached_presentations[identity] = signature
	profile.reached_presentation_chronology.first_witnessed.append(identity)
	var text := _text(profile)
	assert_true(manager._profile_text_validator(text).ok)
	var row: Dictionary = SIGNATURE._entries[signature.entry_id].duplicate(true)
	SIGNATURE._entries[signature.entry_id].allowed_ending_forms = []
	var expected := SCHEMA.validate(READER.parse_object(text).value)
	assert_false(expected.ok)
	assert_eq(manager._profile_text_validator(text), expected,
		"syntax reuse must not retain prior schema admission")
	SIGNATURE._entries[signature.entry_id] = row
	assert_true(manager._profile_text_validator(text).ok)
