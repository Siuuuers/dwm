extends GutTest
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const CORPUS := preload("res://tests/support/CanonicalWriterCompatibilityCorpus.gd")
# Captured from the previous full-document strict-parse implementation, not the optimized writer.
const ORIGINAL_SIGNATURE := "aa397baf53746ea17fbe3fb31998b05a72e54fb65b91c70d16c5c1635f4f3ae7"

func test_preserves_canonical_bytes_and_refusals_for_boundary_and_random_values() -> void:
    var signature := ""
    var count := 0
    for value in CORPUS.values():
        var result := WRITER.stringify(value)
        if result.get("ok", false):
            var parsed := STRICT._parse_value_document(result.value)
            assert_true(parsed.get("ok", false) and WRITER._deep_same(value, parsed.get("value")), "exact external round-trip at case %s" % count)
        signature += ("ok:" + str(result.value) if result.get("ok", false) else "error:" + str(result.get("code"))) + "\n"
        count += 1
    assert_eq(count, 1177)
    assert_eq(signature.sha256_text(), ORIGINAL_SIGNATURE, "same bytes, float refusals, and structural-error precedence as the old writer")

func test_printable_ascii_keys_keep_byte_order_after_string_name_normalization() -> void:
    # Case-sensitive lexical order, not natural-number or locale order.
    var keys := ["", " ", "\"", "-", "10", "2", "A", "Z", "\\", "_", "a", "a ", "a0", "aa", "~"]
    var value := {}
    for index: int in range(keys.size() - 1, -1, -1):
        value[StringName(keys[index]) if index % 2 else keys[index]] = index
    assert_eq(WRITER.stringify(value), {"ok": true, "value": '{"":0," ":1,"\\\"":2,"-":3,"10":4,"2":5,"A":6,"Z":7,"\\\\":8,"_":9,"a":10,"a ":11,"a0":12,"aa":13,"~":14}'})

func test_control_and_unicode_keys_keep_utf8_order() -> void:
    # Boundaries between UTF-8 widths, combining versus precomposed characters,
    # and supplementary codepoints must retain the existing byte comparator.
    var keys := ["\u0001", "\n", "Z", "e\u0301", "\u007f", "\u0080", "é", "\u07ff", "\u0800", "\ud7ff", "\ue000", "\uffff", String.chr(0x10000), String.chr(0x10ffff)]
    var value := {}
    for index: int in range(keys.size() - 1, -1, -1):
        value[keys[index]] = index
    var emitted := WRITER.stringify(value)
    assert_true(emitted.get("ok", false))
    var parsed := STRICT.parse_object(emitted.get("value", ""))
    assert_true(parsed.get("ok", false))
    assert_eq(parsed.get("value", {}).keys(), keys, "JSON member order is preserved by the strict parser")

func test_sorted_key_order_preserves_first_structural_refusal() -> void:
    assert_eq(WRITER.stringify({"a": NAN, "Z": Vector2.ZERO}).get("code"), &"unsupported_type")
    assert_eq(WRITER.stringify({"\u0080": Vector2.ZERO, "\u007f": NAN}).get("code"), &"non_finite_number")

func test_native_integer_document_preserves_values_beyond_double_precision() -> void:
    var integers: Array[int] = [
        -9223372036854775807 - 1, -9007199254740993, -9007199254740992,
        0, 9007199254740992, 9007199254740993, 9223372036854775807,
    ]
    var value := {"integers": integers, "other": [null, false, true]}
    var expected := '{"integers":[-9223372036854775808,-9007199254740993,-9007199254740992,0,9007199254740992,9007199254740993,9223372036854775807],"other":[null,false,true]}'
    assert_true(WRITER._can_use_native_encoder(value))
    assert_eq(WRITER.stringify(value), {"ok": true, "value": expected})
    var parsed := STRICT.parse_object(expected)
    assert_true(parsed.get("ok", false))
    if not parsed.get("ok", false): return
    for index: int in integers.size():
        assert_eq(typeof(parsed.value.integers[index]), TYPE_INT)
        assert_eq(parsed.value.integers[index], integers[index])

func test_native_document_escapes_every_printable_ascii_character_in_keys_and_values() -> void:
    var ascii := ""
    var escaped := ""
    for codepoint: int in range(0x20, 0x7f):
        var character := String.chr(codepoint)
        ascii += character
        if codepoint == 0x22:
            escaped += '\\"'
        elif codepoint == 0x5c:
            escaped += '\\\\'
        else:
            escaped += character
    var value := {ascii: StringName(ascii), "": ""}
    var expected := '{"":"","' + escaped + '":"' + escaped + '"}'
    assert_true(WRITER._can_use_native_encoder(value))
    assert_eq(WRITER.stringify(value), {"ok": true, "value": expected})
    assert_eq(WRITER.stringify(value), WRITER._emit(value))

func test_native_document_preserves_nested_string_names_typed_arrays_and_shared_children() -> void:
    var names: Array[StringName] = [&"alpha", &"quote\"slash\\"]
    var integers: Array[int] = [2, 10, 9007199254740993]
    var child := {&"z": names, "A": [null, false, true]}
    var value := {"z": child, &"array": [child, child], &"ints": integers}
    var child_text := '{"A":[null,false,true],"z":["alpha","quote\\"slash\\\\"]}'
    var expected := '{"array":[' + child_text + ',' + child_text \
        + '],"ints":[2,10,9007199254740993],"z":' + child_text + '}'
    assert_true(WRITER._can_use_native_encoder(value))
    assert_eq(WRITER.stringify(value), {"ok": true, "value": expected},
        "A repeated child is not a cycle; each occurrence must retain the same JSON content.")
    assert_eq(WRITER.stringify(value), WRITER._emit(value))
    assert_true(names.is_typed(), "Encoding does not normalize or mutate caller-owned containers.")
    assert_eq(typeof(names[0]), TYPE_STRING_NAME)
    assert_eq(typeof(integers[2]), TYPE_INT)

func test_native_depth_limit_changes_only_encoder_selection_not_accepted_bytes() -> void:
    for depth: int in [64, 65]:
        var value: Variant = "end"
        for _level: int in depth:
            value = [value]
        var expected := "[".repeat(depth) + '"end"' + "]".repeat(depth)
        assert_eq(WRITER._can_use_native_encoder(value), depth == 64,
            "Depth 65 must use the established emitter, not be rejected or truncated.")
        assert_eq(WRITER.stringify(value), {"ok": true, "value": expected})
        assert_eq(WRITER.stringify(value), WRITER._emit(value))

func test_native_preflight_exclusions_retain_original_values_and_refusals() -> void:
    var valid_fallbacks: Array = [
        1.0, -0.0, 0.1,
        {"nested": [1.0, &"plain"]},
        "line\n", String.chr(0x0b), String.chr(0x7f), String.chr(0x4e2d),
        {StringName("line\t"): "value"}, {String.chr(0x4e2d): "value"},
    ]
    for value: Variant in valid_fallbacks:
        assert_false(WRITER._can_use_native_encoder(value), str(value))
        var emitted := WRITER._emit(value)
        assert_true(emitted.get("ok", false), str(emitted))
        assert_eq(WRITER.stringify(value), emitted,
            "Native exclusion must preserve the original successful emission.")
    var invalid_fallbacks: Array = [
        {"value": PackedByteArray([1, 2])},
        {"value": PackedInt64Array([1, 9007199254740993])},
        {1: "non-string key"}, {"value": NodePath("plain")},
        {"a": NAN, "Z": Vector2.ZERO},
        {String.chr(0x80): Vector2.ZERO, String.chr(0x7f): NAN},
    ]
    for value: Variant in invalid_fallbacks:
        assert_false(WRITER._can_use_native_encoder(value))
        var emitted := WRITER._emit(value)
        assert_false(emitted.get("ok", true), str(emitted))
        assert_eq(WRITER.stringify(value), emitted,
            "Preflight refusal must leave the original structural error and its precedence intact.")
