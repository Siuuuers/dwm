class_name CanonicalJsonWriter
extends RefCounted

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
static var _ordinary_ascii := RegEx.create_from_string("\\A[\\x20-\\x21\\x23-\\x5B\\x5D-\\x7E]*\\z")

# Native escaping is byte-identical on printable ASCII, including quotes and backslashes.
static var _printable_ascii := RegEx.create_from_string("\\A[\\x20-\\x7E]*\\z")

static func stringify(value: Variant) -> Dictionary:
	var emitted := _emit(value)
	if not emitted.get("ok", false):
		return emitted
	# Containers compose already checked scalar encodings. Avoid reparsing the entire
	# document for every internal receipt hash; cold/external reads still use StrictJson.
	# Defer lossy-scalar failure until emission ends to preserve structural-error precedence.
	if emitted.get("round_trip_failed", false):
		return {"ok": false, "code": &"self_check_failed", "message": "Canonical JSON did not round-trip exactly"}
	return _ok(emitted["value"])

static func _emit(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL:
			return _ok("null")
		TYPE_BOOL:
			return _ok("true" if value else "false")
		TYPE_INT:
			return _ok(str(value))
		TYPE_FLOAT:
			return _emit_float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return _emit_string(str(value))
		TYPE_ARRAY:
			return _emit_array(value)
		TYPE_DICTIONARY:
			return _emit_dictionary(value)
		_:
			return {"ok": false, "code": &"unsupported_type", "message": "Unsupported Variant type: %s" % type_string(typeof(value))}

static func _emit_float(value: float) -> Dictionary:
	if not is_finite(value):
		return {"ok": false, "code": &"non_finite_number", "message": "Canonical JSON requires finite floats"}
	if value == 0.0:
		return _ok("0.0")
	var number := String.num_scientific(value)
	number = number.to_lower()
	if "e" in number:
		var pieces := number.split("e", false, 1)
		var exponent: String = pieces[1]
		var sign := ""
		if exponent.begins_with("+"):
			exponent = exponent.substr(1)
		elif exponent.begins_with("-"):
			sign = "-"
			exponent = exponent.substr(1)
		exponent = exponent.trim_prefix("0")
		while exponent.begins_with("0"):
			exponent = exponent.substr(1)
		if exponent.is_empty():
			exponent = "0"
		number = pieces[0] + "e" + sign + exponent
	var exponent_position := number.find("e")
	var mantissa := number if exponent_position < 0 else number.substr(0, exponent_position)
	if "." not in mantissa:
		if exponent_position < 0:
			number += ".0"
		else:
			number = mantissa + ".0" + number.substr(exponent_position)
	var parsed := STRICT_JSON._parse_value_document(number)
	var exact: bool = parsed.get("ok", false) and typeof(parsed.get("value")) == TYPE_FLOAT and parsed["value"] == value
	return _ok(number, not exact)

static func _emit_string(value: String) -> Dictionary:
	# Exact whole-string match: all excluded characters retain the original emitter.
	if _ordinary_ascii.search(value) != null:
		return _ok('"' + value + '"')
	# String.json_escape also emits non-JSON \v for vertical tabs, so constrain this
	# native path to printable ASCII. Controls and Unicode retain the checked emitter.
	if _printable_ascii.search(value) != null:
		return _ok('"' + value.json_escape() + '"')
	var output := "\""
	var round_trip_failed := false
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint >= 0xD800 and codepoint <= 0xDFFF:
			return {"ok": false, "code": &"invalid_surrogate", "message": "String contains a lone surrogate code point"}
		# Godot replaces these malformed internal codepoints during String.chr.
		round_trip_failed = round_trip_failed or codepoint == 0 or codepoint > 0x10FFFF
		match codepoint:
			0x22: output += "\\\""
			0x5C: output += "\\\\"
			0x08: output += "\\b"
			0x0C: output += "\\f"
			0x0A: output += "\\n"
			0x0D: output += "\\r"
			0x09: output += "\\t"
			_:
				if codepoint < 0x20:
					output += "\\u%04x" % codepoint
				else:
					output += String.chr(codepoint)
	output += "\""
	return _ok(output, round_trip_failed)

static func _emit_array(value: Array) -> Dictionary:
	var parts: Array[String] = []
	var round_trip_failed := false
	for item in value:
		var emitted := _emit(item)
		if not emitted.get("ok", false):
			return emitted
		parts.append(emitted["value"])
		round_trip_failed = round_trip_failed or emitted.get("round_trip_failed", false)
	return _ok("[" + ",".join(parts) + "]", round_trip_failed)

static func _emit_dictionary(value: Dictionary) -> Dictionary:
	var normalized := {}
	for original_key in value.keys():
		if typeof(original_key) != TYPE_STRING and typeof(original_key) != TYPE_STRING_NAME:
			return {"ok": false, "code": &"invalid_key_type", "message": "Object keys must be String or StringName"}
		var key := str(original_key)
		if normalized.has(key):
			return {"ok": false, "code": &"key_collision", "message": "Object keys collide after normalization: %s" % key}
		normalized[key] = value[original_key]
	var keys: Array = normalized.keys()
	keys.sort_custom(_utf8_less)
	var parts: Array[String] = []
	var round_trip_failed := false
	for key: String in keys:
		var emitted_key := _emit_string(key)
		if not emitted_key.get("ok", false):
			return emitted_key
		var emitted_value := _emit(normalized[key])
		if not emitted_value.get("ok", false):
			return emitted_value
		parts.append(emitted_key["value"] + ":" + emitted_value["value"])
		round_trip_failed = round_trip_failed or emitted_key.get("round_trip_failed", false) or emitted_value.get("round_trip_failed", false)
	return _ok("{" + ",".join(parts) + "}", round_trip_failed)

static func _utf8_less(left: String, right: String) -> bool:
	var left_bytes := left.to_utf8_buffer()
	var right_bytes := right.to_utf8_buffer()
	var shared := mini(left_bytes.size(), right_bytes.size())
	for index in range(shared):
		if left_bytes[index] != right_bytes[index]:
			return left_bytes[index] < right_bytes[index]
	return left_bytes.size() < right_bytes.size()

static func _deep_same(left: Variant, right: Variant) -> bool:
	var left_type := typeof(left)
	if left_type == TYPE_STRING_NAME:
		left_type = TYPE_STRING
	if left_type != typeof(right):
		return false
	match left_type:
		TYPE_ARRAY:
			if left.size() != right.size():
				return false
			for index in range(left.size()):
				if not _deep_same(left[index], right[index]):
					return false
			return true
		TYPE_DICTIONARY:
			if left.size() != right.size():
				return false
			for key in left:
				var normalized_key := str(key)
				if not right.has(normalized_key) or not _deep_same(left[key], right[normalized_key]):
					return false
			return true
		TYPE_FLOAT:
			return (left == 0.0 and right == 0.0) or left == right
		_:
			return left == right

static func _ok(value: String, round_trip_failed := false) -> Dictionary:
	var result := {"ok": true, "value": value}
	if round_trip_failed:
		result["round_trip_failed"] = true
	return result
