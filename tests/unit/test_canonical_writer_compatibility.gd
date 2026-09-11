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
