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
