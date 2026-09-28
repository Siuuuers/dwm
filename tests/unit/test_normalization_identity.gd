extends "res://addons/gut/test.gd"

const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")

func _normalizers() -> Array[Callable]:
	return [DOCUMENT._normalize_engine_text, PORT._normalize_json_string_types]

func test_clean_typed_and_nested_containers_preserve_identity() -> void:
	var words: Array[String] = ["one", "two"]
	var counts: Dictionary[String, int] = {"second": 2, "first": 1}
	var empty_names: Array[StringName] = []
	var empty_members: Dictionary[StringName, StringName] = {}
	var nested := {"items": [words, counts, empty_names, empty_members],
		"other": {"flag": true, "nothing": null}}
	var before := var_to_bytes(nested)
	for normalize: Callable in _normalizers():
		for clean: Variant in [words, counts, empty_names, empty_members, nested]:
			assert_true(is_same(normalize.call(clean), clean),
				str(normalize.get_method()) + " preserves clean container identity")
		assert_true(var_to_bytes(nested) == before, "clean input remains unchanged")

func test_array_conversion_at_each_position_rebuilds_only_changed_path() -> void:
	for normalize: Callable in _normalizers():
		for position: int in range(3):
			var source: Array = [{"slot": 0}, {"slot": 1}, {"slot": 2}]
			source[position] = {"changed": &"caption"}
			var before := var_to_bytes(source)
			var result: Array = normalize.call(source)
			assert_false(is_same(result, source))
			assert_eq(result.size(), 3, "first, middle and last conversions retain all entries")
			for index: int in range(3):
				if index == position:
					assert_false(is_same(result[index], source[index]))
					assert_eq(typeof(result[index]["changed"]), TYPE_STRING)
					assert_eq(result[index]["changed"], "caption")
				else:
					assert_true(is_same(result[index], source[index]), "clean sibling retains identity")
			assert_true(var_to_bytes(source) == before, "conversion never edits the source")

func test_dictionary_key_or_member_conversion_keeps_order_and_clean_siblings() -> void:
	var keys: Array[String] = ["first", "middle", "last"]
	for normalize: Callable in _normalizers():
		for change_key: bool in [false, true]:
			for position: int in range(3):
				var source := {}
				for index: int in range(3):
					var key: Variant = StringName(keys[index]) if change_key and index == position else keys[index]
					source[key] = {"changed": &"caption"} if not change_key and index == position else {"slot": index}
				var before := var_to_bytes(source)
				var original_keys := source.keys()
				var result: Dictionary = normalize.call(source)
				assert_false(is_same(result, source))
				assert_true(result.keys() == keys, "conversion preserves insertion order")
				for index: int in range(3):
					assert_eq(typeof(result.keys()[index]), TYPE_STRING)
					if not change_key and index == position:
						assert_false(is_same(result[keys[index]], source[original_keys[index]]))
						assert_eq(typeof(result[keys[index]]["changed"]), TYPE_STRING)
						assert_eq(result[keys[index]]["changed"], "caption")
					else:
						assert_true(is_same(result[keys[index]], source[original_keys[index]]),
							"key conversion and clean siblings retain member identity")
				assert_true(var_to_bytes(source) == before, "source keys and members remain unchanged")

func test_changed_typed_nodes_become_untyped_without_mutating_sources() -> void:
	for normalize: Callable in _normalizers():
		var names: Array[StringName] = [&"one", &"two"]
		var by_name: Dictionary[StringName, int] = {&"first": 1, &"second": 2}
		var with_names: Dictionary[String, StringName] = {"first": &"one", "second": &"two"}
		var both_names: Dictionary[StringName, StringName] = {&"first": &"one"}
		var clean: Dictionary[String, int] = {"unchanged": 7}
		var source: Array[Dictionary] = [{"names": names, "keys": by_name,
			"values": with_names, "both": both_names}, clean]
		var before := var_to_bytes(source)
		var result: Array = normalize.call(source)
		assert_false(result.is_typed(), "a changed typed ancestor becomes untyped")
		assert_false((result[0]["names"] as Array).is_typed())
		assert_true(result[0]["names"] == ["one", "two"])
		for name: Variant in result[0]["names"]:
			assert_eq(typeof(name), TYPE_STRING)
		for name: String in ["keys", "values", "both"]:
			var converted: Dictionary = result[0][name]
			assert_false(converted.is_typed(), "changed typed dictionary: " + name)
			for key: Variant in converted:
				assert_eq(typeof(key), TYPE_STRING)
				assert_eq(typeof(converted[key]), TYPE_INT if name == "keys" else TYPE_STRING)
		assert_true(result[0]["keys"] == {"first": 1, "second": 2})
		assert_true(result[0]["values"] == {"first": "one", "second": "two"})
		assert_true(result[0]["both"] == {"first": "one"})
		assert_true(is_same(result[1], clean), "unchanged typed sibling stays shared and typed")
		assert_true(var_to_bytes(source) == before, "typed source containers remain unchanged")
		assert_eq(typeof(normalize.call(&"root")), TYPE_STRING, "root StringName converts too")

func test_numeric_values_keep_exact_types_and_signed_zero() -> void:
	var negative_zero_bytes := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 128])
	var negative_zero := negative_zero_bytes.decode_double(0)
	assert_true(PackedFloat64Array([negative_zero]).to_byte_array() == negative_zero_bytes,
		"negative-zero fixture has the exact IEEE 754 sign bit before normalization")
	for normalize: Callable in _normalizers():
		var source: Array = [9223372036854775807, -9223372036854775807 - 1,
			1, 1.0, 0.1, negative_zero, 0.0, &"last"]
		var before := var_to_bytes(source)
		var result: Array = normalize.call(source)
		assert_eq(result.size(), source.size())
		for index: int in range(7):
			assert_eq(typeof(result[index]), typeof(source[index]), "numeric type is unchanged")
			assert_true(var_to_bytes(result[index]) == var_to_bytes(source[index]),
				"numeric bits are unchanged")
		assert_false(PackedFloat64Array([result[5]]).to_byte_array() ==
			PackedFloat64Array([result[6]]).to_byte_array(), "negative zero retains its sign")
		assert_true(PackedFloat64Array([result[5]]).to_byte_array() == negative_zero_bytes,
			"normalized negative zero keeps its exact original bits")
		assert_eq(typeof(result[7]), TYPE_STRING)
		assert_true(var_to_bytes(source) == before)

func test_unsupported_leaves_remain_for_existing_validation() -> void:
	var object := RefCounted.new()
	var packed_values: Array = [PackedByteArray([0, 255]), PackedInt64Array([9223372036854775807]),
		PackedFloat64Array([-0.0, INF, NAN]), PackedStringArray(["caption"])]
	for normalize: Callable in _normalizers():
		var source := {"convert": &"caption", "packed": packed_values,
			"object": object, "nan": NAN, "positive": INF, "negative": -INF}
		var converted: Dictionary = normalize.call(source)
		for packed: Variant in packed_values:
			var result: Variant = normalize.call(packed)
			assert_eq(typeof(result), typeof(packed), "packed values are not converted to JSON arrays")
			assert_true(var_to_bytes(result) == var_to_bytes(packed))
		assert_true(var_to_bytes(converted["packed"]) == var_to_bytes(packed_values))
		assert_true(is_same(normalize.call(object), object), "objects remain objects for validator refusal")
		assert_true(is_nan(normalize.call(NAN)), "NaN is not silently replaced")
		assert_eq(normalize.call(INF), INF)
		assert_eq(normalize.call(-INF), -INF)
		assert_true(is_same(converted["object"], object))
		assert_true(is_nan(converted["nan"]))
		assert_eq(converted["positive"], INF)
		assert_eq(converted["negative"], -INF)
