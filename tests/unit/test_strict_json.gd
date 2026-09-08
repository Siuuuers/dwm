# tests/unit/test_strict_json.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

var _strict: Script
var _writer: Script
var _schema_validator: Script

func before_all() -> void:
	var strict_result: Dictionary = PROBE.load_script("res://scripts/validation/StrictJson.gd")
	assert_true(strict_result.get("ok", false), "StrictJson must load: %s" % strict_result)
	if strict_result.get("ok", false):
		_strict = strict_result["value"]
	var writer_result: Dictionary = PROBE.load_script("res://scripts/validation/CanonicalJsonWriter.gd")
	assert_true(writer_result.get("ok", false), "CanonicalJsonWriter must load: %s" % writer_result)
	if writer_result.get("ok", false):
		_writer = writer_result["value"]
	var schema_result: Dictionary = PROBE.load_script("res://scripts/validation/JsonSchemaValidator.gd")
	assert_true(schema_result.get("ok", false), str(schema_result))
	if schema_result.get("ok", false): _schema_validator = schema_result["value"]

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

func test_schema_files_are_strict_json_and_validate_closed_objects() -> void:
	var schema_text := FileAccess.get_file_as_string("res://schemas/localization/ui-locale.schema.json")
	var parsed: Dictionary = _strict.call(&"parse_object", schema_text)
	assert_true(parsed.get("ok", false), str(parsed))
	var valid := {"schema_version": 1, "locale": "en", "messages": []}
	assert_true(_schema_validator.call(&"validate", valid, parsed["value"]).get("ok", false))
	valid["unknown"] = true
	assert_false(_schema_validator.call(&"validate", valid, parsed["value"]).get("ok", true))


func test_ascii_span_accepts_every_safe_printable_character_in_keys_and_values() -> void:
	var safe := ""
	for codepoint in range(0x20, 0x7F):
		if codepoint != 0x22 and codepoint != 0x5C:
			safe += String.chr(codepoint)
	var result: Dictionary = _strict.call(&"parse_object", "{\"" + safe + "\":\"" + safe.repeat(8) + "\"}")
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("value"), {safe: safe.repeat(8)})

func test_ascii_spans_resume_after_unicode_and_every_escape() -> void:
	var unicode := String.chr(0x4E2D) + String.chr(0x1F63D)
	var encoded := "prefix" + unicode + "suffix\\\"\\\\\\/\\b\\f\\n\\r\\t\\u4E2D\\uD83D\\uDE3Dend"
	var expected := "prefix" + unicode + "suffix\"\\/\b\f\n\r\t" + unicode + "end"
	var result: Dictionary = _strict.call(&"parse_object", "{\"x\":\"" + encoded + "\"}")
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("value"), {"x": expected})

func test_ascii_span_errors_preserve_exact_line_and_column() -> void:
	var cases := [
		{"text": "{\n  \"x\":\"abc" + String.chr(1) + "\"}", "code": &"invalid_string_character", "line": 2, "column": 11},
		{"text": "{\n  \"x\":\"abc\\q\"}", "code": &"invalid_escape", "line": 2, "column": 13},
		{"text": "{\n\"same\":1,\n\"same\":2}", "code": &"duplicate_key", "line": 3, "column": 7},
		{"text": "{\"x\":\"abc", "code": &"unexpected_eof", "line": 1, "column": 10},
		{"text": "{\"x\":\"abc\\uD800\"}", "code": &"invalid_surrogate", "line": 1, "column": 16},
		{"text": "{\"x\":\"abc\ndef\"}", "code": &"invalid_string_character", "line": 1, "column": 10},
	]
	for item: Dictionary in cases:
		var result: Dictionary = _strict.call(&"parse_object", item["text"])
		assert_false(result.get("ok", true), str(item))
		assert_eq(result.get("code"), item["code"], str(item))
		assert_eq(result.get("line"), item["line"], str(item))
		assert_eq(result.get("column"), item["column"], str(item))

func test_ascii_span_keeps_integer_and_float_types_and_boundaries() -> void:
	var result: Dictionary = _strict.call(&"parse_object", "{\"label\":\"ordinary_ascii\",\"min\":-9223372036854775808,\"max\":9223372036854775807,\"float\":1.0,\"exponent\":-2.5e1}")
	assert_true(result.get("ok", false), str(result))
	var value: Dictionary = result.get("value", {})
	assert_eq(typeof(value.get("min")), TYPE_INT)
	assert_eq(typeof(value.get("max")), TYPE_INT)
	assert_eq(typeof(value.get("float")), TYPE_FLOAT)
	assert_eq(typeof(value.get("exponent")), TYPE_FLOAT)
	assert_eq(value.get("min"), -9223372036854775807 - 1)
	assert_eq(value.get("max"), 9223372036854775807)
	assert_eq(value.get("float"), 1.0)
	assert_eq(value.get("exponent"), -25.0)


func test_ascii_key_rejects_equivalent_escaped_duplicate_spelling() -> void:
	var result: Dictionary = _strict.call(&"parse_object", "{\"same\":1,\"\\u0073ame\":2}")
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"duplicate_key")
	assert_eq(result.get("line"), 1)
	assert_eq(result.get("column"), 22)

func test_canonical_string_fast_return_preserves_entire_safe_ascii_and_empty() -> void:
	var safe := ""
	for codepoint in range(0x20, 0x7F):
		if codepoint != 0x22 and codepoint != 0x5C:
			safe += String.chr(codepoint)
	for value: String in ["", safe, safe.repeat(8)]:
		var emitted: Dictionary = _writer.call(&"_emit_string", value)
		assert_eq(emitted, {"ok": true, "value": '"' + value + '"'})
		var document: Dictionary = _writer.call(&"stringify", {value: value})
		assert_true(document.get("ok", false), str(document))
		assert_eq(document.get("value"), '{"' + value + '":"' + value + '"}')

func test_canonical_string_fast_return_exclusions_keep_exact_original_escaping() -> void:
	var unicode := String.chr(0x4E2D) + String.chr(0x1F63D)
	var cases := [
		{"input": "safe\"suffix", "expected": "\"safe\\\"suffix\""},
		{"input": "safe\\suffix", "expected": "\"safe\\\\suffix\""},
		{"input": "safe\n", "expected": "\"safe\\n\""},
		{"input": "safe\r\t\b\f", "expected": "\"safe\\r\\t\\b\\f\""},
		{"input": "safe" + String.chr(1), "expected": "\"safe\\u0001\""},
		{"input": "safe" + String.chr(0x7F), "expected": '"safe' + String.chr(0x7F) + '"'},
		{"input": "safe" + unicode + "suffix", "expected": '"safe' + unicode + 'suffix"'},
	]
	for item: Dictionary in cases:
		var emitted: Dictionary = _writer.call(&"_emit_string", item["input"])
		assert_eq(emitted, {"ok": true, "value": item["expected"]}, str(item))
		var document: Dictionary = _writer.call(&"stringify", {"x": item["input"]})
		assert_true(document.get("ok", false), str(document))
		assert_eq(document.get("value"), '{"x":' + item["expected"] + '}', str(item))
