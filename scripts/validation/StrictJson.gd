class_name StrictJson
extends RefCounted

static func parse_object(text: String) -> Dictionary:
	var result: Dictionary = _Parser.new(text).parse_document()
	if not result.get("ok", false):
		return result
	if typeof(result["value"]) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"code": &"object_root_required",
			"message": "JSON document root must be an object",
			"line": 1,
			"column": 1,
		}
	return {"ok": true, "value": (result["value"] as Dictionary).duplicate(true)}

static func _parse_value_document(text: String) -> Dictionary:
	return _Parser.new(text).parse_document()

class _Parser:
	extends RefCounted

	var _text: String
	var _index := 0
	var _line := 1
	var _column := 1

	func _init(text: String) -> void:
		_text = text

	func parse_document() -> Dictionary:
		_skip_whitespace()
		var value_result := _parse_value()
		if not value_result.get("ok", false):
			return value_result
		_skip_whitespace()
		if not _is_eof():
			return _error(&"trailing_tokens", "Unexpected data after JSON value")
		return {"ok": true, "value": value_result["value"]}

	func _parse_value() -> Dictionary:
		if _is_eof():
			return _error(&"unexpected_eof", "Expected a JSON value")
		var codepoint := _peek()
		match codepoint:
			0x7B:
				return _parse_object_value()
			0x5B:
				return _parse_array()
			0x22:
				return _parse_string()
			0x74:
				return _parse_literal("true", true)
			0x66:
				return _parse_literal("false", false)
			0x6E:
				return _parse_literal("null", null)
			0x2D:
				return _parse_number()
			_:
				if codepoint >= 0x30 and codepoint <= 0x39:
					return _parse_number()
				return _error(&"unexpected_token", "Expected a JSON value")

	func _parse_object_value() -> Dictionary:
		_advance()
		_skip_whitespace()
		var output := {}
		var seen := {}
		if _consume_if(0x7D):
			return {"ok": true, "value": output}
		while true:
			if _peek() != 0x22:
				return _error(&"object_key_required", "Expected an object member name")
			var key_result := _parse_string()
			if not key_result.get("ok", false):
				return key_result
			var key: String = key_result["value"]
			if seen.has(key):
				return _error(&"duplicate_key", "Duplicate object member: %s" % key)
			seen[key] = true
			_skip_whitespace()
			if not _consume_if(0x3A):
				return _error(&"colon_required", "Expected ':' after object member name")
			_skip_whitespace()
			var value_result := _parse_value()
			if not value_result.get("ok", false):
				return value_result
			output[key] = value_result["value"]
			_skip_whitespace()
			if _consume_if(0x7D):
				return {"ok": true, "value": output}
			if not _consume_if(0x2C):
				return _error(&"comma_or_end_required", "Expected ',' or '}'")
			_skip_whitespace()
		return _error(&"internal_error", "Object parser terminated unexpectedly")

	func _parse_array() -> Dictionary:
		_advance()
		_skip_whitespace()
		var output := []
		if _consume_if(0x5D):
			return {"ok": true, "value": output}
		while true:
			var value_result := _parse_value()
			if not value_result.get("ok", false):
				return value_result
			output.append(value_result["value"])
			_skip_whitespace()
			if _consume_if(0x5D):
				return {"ok": true, "value": output}
			if not _consume_if(0x2C):
				return _error(&"comma_or_end_required", "Expected ',' or ']'")
			_skip_whitespace()
		return _error(&"internal_error", "Array parser terminated unexpectedly")

	func _parse_string() -> Dictionary:
		_advance()
		var output := ""
		while not _is_eof():
			var codepoint := _peek()
			if codepoint == 0x22:
				_advance()
				return {"ok": true, "value": output}
			if codepoint < 0x20:
				return _error(&"invalid_string_character", "Unescaped control character in string")
			if codepoint >= 0xD800 and codepoint <= 0xDFFF:
				return _error(&"invalid_surrogate", "Lone surrogate code point in string")
			if codepoint != 0x5C:
				output += String.chr(codepoint)
				_advance()
				continue
			_advance()
			if _is_eof():
				return _error(&"unexpected_eof", "Incomplete string escape")
			var escaped := _peek()
			_advance()
			match escaped:
				0x22: output += "\""
				0x5C: output += "\\"
				0x2F: output += "/"
				0x62: output += "\b"
				0x66: output += "\f"
				0x6E: output += "\n"
				0x72: output += "\r"
				0x74: output += "\t"
				0x75:
					var unicode_result := _parse_unicode_escape()
					if not unicode_result.get("ok", false):
						return unicode_result
					output += String.chr(unicode_result["value"])
				_:
					return _error(&"invalid_escape", "Invalid JSON string escape")
		return _error(&"unexpected_eof", "Unterminated JSON string")

	func _parse_unicode_escape() -> Dictionary:
		var first_result := _read_hex_quad()
		if not first_result.get("ok", false):
			return first_result
		var first: int = first_result["value"]
		if first >= 0xDC00 and first <= 0xDFFF:
			return _error(&"invalid_surrogate", "Lone low surrogate escape")
		if first < 0xD800 or first > 0xDBFF:
			return {"ok": true, "value": first}
		if _is_eof() or _peek() != 0x5C:
			return _error(&"invalid_surrogate", "High surrogate must be followed by a low surrogate escape")
		_advance()
		if _is_eof() or _peek() != 0x75:
			return _error(&"invalid_surrogate", "High surrogate must be followed by a low surrogate escape")
		_advance()
		var second_result := _read_hex_quad()
		if not second_result.get("ok", false):
			return second_result
		var second: int = second_result["value"]
		if second < 0xDC00 or second > 0xDFFF:
			return _error(&"invalid_surrogate", "High surrogate must be followed by a low surrogate escape")
		return {"ok": true, "value": 0x10000 + ((first - 0xD800) << 10) + second - 0xDC00}

	func _read_hex_quad() -> Dictionary:
		var value := 0
		for _digit_index in range(4):
			if _is_eof():
				return _error(&"invalid_unicode_escape", "Unicode escape requires four hexadecimal digits")
			var digit := _hex_value(_peek())
			if digit < 0:
				return _error(&"invalid_unicode_escape", "Unicode escape requires four hexadecimal digits")
			value = (value << 4) | digit
			_advance()
		return {"ok": true, "value": value}

	func _parse_number() -> Dictionary:
		var start := _index
		_consume_if(0x2D)
		if _is_eof():
			return _error(&"invalid_number", "Expected digits after '-'")
		if _consume_if(0x30):
			if not _is_eof() and _is_digit(_peek()):
				return _error(&"invalid_number", "Leading zero is not allowed")
		elif _peek() >= 0x31 and _peek() <= 0x39:
			while not _is_eof() and _is_digit(_peek()):
				_advance()
		else:
			return _error(&"invalid_number", "Expected a decimal digit")
		var is_float := false
		if _consume_if(0x2E):
			is_float = true
			if _is_eof() or not _is_digit(_peek()):
				return _error(&"invalid_number", "Fraction requires a digit")
			while not _is_eof() and _is_digit(_peek()):
				_advance()
		if not _is_eof() and (_peek() == 0x65 or _peek() == 0x45):
			is_float = true
			_advance()
			if not _is_eof() and (_peek() == 0x2B or _peek() == 0x2D):
				_advance()
			if _is_eof() or not _is_digit(_peek()):
				return _error(&"invalid_number", "Exponent requires a digit")
			while not _is_eof() and _is_digit(_peek()):
				_advance()
		var token := _text.substr(start, _index - start)
		if is_float:
			var float_value := token.to_float()
			if not is_finite(float_value):
				return _error(&"non_finite_number", "JSON number is not finite")
			return {"ok": true, "value": float_value}
		var digits := token.trim_prefix("-")
		var maximum := "9223372036854775808" if token.begins_with("-") else "9223372036854775807"
		if digits.length() > maximum.length() or (digits.length() == maximum.length() and digits > maximum):
			return _error(&"integer_overflow", "JSON integer is outside signed 64-bit range")
		return {"ok": true, "value": token.to_int()}

	func _parse_literal(literal: String, value: Variant) -> Dictionary:
		for expected_index in range(literal.length()):
			if _is_eof() or _peek() != literal.unicode_at(expected_index):
				return _error(&"invalid_literal", "Invalid JSON literal")
			_advance()
		return {"ok": true, "value": value}

	func _skip_whitespace() -> void:
		while not _is_eof() and _peek() in [0x20, 0x09, 0x0A, 0x0D]:
			_advance()

	func _consume_if(codepoint: int) -> bool:
		if _is_eof() or _peek() != codepoint:
			return false
		_advance()
		return true

	func _advance() -> void:
		var codepoint := _peek()
		_index += 1
		if codepoint == 0x0A:
			_line += 1
			_column = 1
		else:
			_column += 1

	func _peek() -> int:
		return -1 if _is_eof() else _text.unicode_at(_index)

	func _is_eof() -> bool:
		return _index >= _text.length()

	func _error(code: StringName, message: String) -> Dictionary:
		return {"ok": false, "code": code, "message": message, "line": _line, "column": _column}

	static func _is_digit(codepoint: int) -> bool:
		return codepoint >= 0x30 and codepoint <= 0x39

	static func _hex_value(codepoint: int) -> int:
		if codepoint >= 0x30 and codepoint <= 0x39:
			return codepoint - 0x30
		if codepoint >= 0x41 and codepoint <= 0x46:
			return codepoint - 0x41 + 10
		if codepoint >= 0x61 and codepoint <= 0x66:
			return codepoint - 0x61 + 10
		return -1
