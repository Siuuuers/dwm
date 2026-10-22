extends "res://addons/gut/test.gd"

const INVENTORY := preload("res://tools/evidence/Phase2RCloseoutInventory.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")


func test_canonical_failures_cannot_reopen_an_equality_gate() -> void:
	assert_eq(INVENTORY._canonical({"b": 2, "a": 1}), '{"a":1,"b":2}')
	var unsupported := RefCounted.new()
	var first: String = INVENTORY._canonical(unsupported)
	var second: String = INVENTORY._canonical(unsupported)
	var third: String = INVENTORY._canonical(Vector2.ZERO)
	assert_ne(first, second, "Repeated unsupported values must never compare equal")
	assert_ne(second, third, "Different unsupported values must never compare equal")
	assert_ne(first, third)
	for sentinel: String in [first, second, third]:
		assert_eq(sentinel.unicode_at(0), 0xFFFD, "Preserve the historical non-JSON sentinel prefix")
		assert_false(STRICT.parse_object(sentinel).get("ok", false), "Failure sentinels cannot be valid documents")
