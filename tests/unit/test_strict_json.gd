# tests/unit/test_strict_json.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

var _strict: Script
var _writer: Script

func before_all() -> void:
	var strict_result: Dictionary = PROBE.load_script("res://scripts/validation/StrictJson.gd")
	assert_true(strict_result.get("ok", false), "StrictJson must load: %s" % strict_result)
	if strict_result.get("ok", false):
		_strict = strict_result["value"]
	var writer_result: Dictionary = PROBE.load_script("res://scripts/validation/CanonicalJsonWriter.gd")
	assert_true(writer_result.get("ok", false), "CanonicalJsonWriter must load: %s" % writer_result)
	if writer_result.get("ok", false):
		_writer = writer_result["value"]

func test_strict_parser_accepts_nested_object_and_detaches_values() -> void:
	var result: Dictionary = _strict.call(&"parse_object", "{\"a\":[1,true,null,{\"b\":-2.5e1}]}")
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("value"), {"a": [1, true, null, {"b": -25.0}]})

func test_strict_parser_rejects_duplicate_keys_before_materialization() -> void:
	var result: Dictionary = _strict.call(&"parse_object", "{\"same\":1,\"same\":2}")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"duplicate_key")

func test_strict_parser_rejects_non_object_root_and_trailing_tokens() -> void:
	assert_eq(_strict.call(&"parse_object", "[1]").get("code"), &"object_root_required")
	assert_eq(_strict.call(&"parse_object", "{} true").get("code"), &"trailing_tokens")

func test_strict_parser_rejects_invalid_strings_and_lone_surrogates() -> void:
	assert_eq(_strict.call(&"parse_object", "{\"x\":\"\\q\"}").get("code"), &"invalid_escape")
	assert_eq(_strict.call(&"parse_object", "{\"x\":\"\\uD800\"}").get("code"), &"invalid_surrogate")
	assert_eq(_strict.call(&"parse_object", "{\"x\":\"\\uDC00\"}").get("code"), &"invalid_surrogate")
	var paired: Dictionary = _strict.call(&"parse_object", "{\"x\":\"\\uD83D\\uDE3D\"}")
	assert_true(paired.get("ok", false), str(paired))
	assert_eq(paired["value"]["x"], "😽")

func test_strict_parser_rejects_bad_numbers_and_integer_overflow() -> void:
	assert_false(_strict.call(&"parse_object", "{\"x\":01}").get("ok", true))
	assert_eq(_strict.call(&"parse_object", "{\"x\":9223372036854775808}").get("code"), &"integer_overflow")
	assert_eq(_strict.call(&"parse_object", "{\"x\":-9223372036854775809}").get("code"), &"integer_overflow")
	assert_true(_strict.call(&"parse_object", "{\"x\":-9223372036854775808}").get("ok", false))

func test_strict_parser_reports_first_error_location() -> void:
	var result: Dictionary = _strict.call(&"parse_object", "{\n  \"x\": @\n}")
	assert_false(result.get("ok", true))
	assert_eq(result.get("line"), 2)
	assert_eq(result.get("column"), 8)

func test_canonical_writer_is_stable_across_dictionary_insertion_order() -> void:
	var first := {"z": 1, "a": 2, "nested": {"b": true, "a": false}}
	var second := {"nested": {"a": false, "b": true}, "a": 2, "z": 1}
	var one: Dictionary = _writer.call(&"stringify", first)
	var two: Dictionary = _writer.call(&"stringify", second)
	assert_true(one.get("ok", false), str(one))
	assert_eq(one, two)
	assert_eq(one.get("value"), "{\"a\":2,\"nested\":{\"a\":false,\"b\":true},\"z\":1}")

func test_canonical_writer_preserves_types_and_escapes_controls() -> void:
	var result: Dictionary = _writer.call(&"stringify", {"f": 1.0, "s": "a\n\u0001", "zero": -0.0})
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("value"), "{\"f\":1.0,\"s\":\"a\\n\\u0001\",\"zero\":0.0}")
	for difficult_float in [0.1, 1.2345678901234567, 1.0e-200, 1.0e200]:
		var round_trip: Dictionary = _writer.call(&"stringify", {"value": difficult_float})
		assert_true(round_trip.get("ok", false), "float must round-trip exactly: %s" % round_trip)

func test_canonical_writer_rejects_unsupported_values_and_invalid_keys() -> void:
	assert_eq(_writer.call(&"stringify", {"bad": Vector2.ZERO}).get("code"), &"unsupported_type")
	assert_eq(_writer.call(&"stringify", {1: "bad"}).get("code"), &"invalid_key_type")
