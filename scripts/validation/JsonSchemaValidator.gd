class_name JsonSchemaValidator
extends RefCounted
## Project schema subset: local references, oneOf, primitive/object/array constraints.
## Recursive or external references are refused; this is not a complete JSON Schema implementation.

static func validate(value: Variant, schema: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	_validate_at(value, schema, "$", errors, schema, {})
	if errors.is_empty(): return {"ok": true, "value": _detach(value)}
	return {"ok": false, "code": &"schema_validation_failed", "message": errors[0]["message"], "errors": errors.duplicate(true)}

static func _validate_at(
		value: Variant,
		schema: Dictionary,
		path: String,
		errors: Array[Dictionary],
		root_schema: Dictionary,
		active_refs: Dictionary
) -> void:
	if typeof(value) == TYPE_FLOAT and not is_finite(float(value)):
		_add(errors, path, "number must be finite")
		return
	if schema.has("$ref"):
		var reference: Variant = schema["$ref"]
		if typeof(reference) != TYPE_STRING:
			_add(errors, path, "$ref must be a string")
			return
		var reference_text: String = reference
		if active_refs.has(reference_text):
			_add(errors, path, "cyclic $ref")
			return
		var resolved: Dictionary = _resolve_local_ref(reference_text, root_schema)
		if not resolved.get("ok", false):
			_add(errors, path, str(resolved.get("message", "invalid $ref")))
			return
		active_refs[reference_text] = true
		_validate_at(value, resolved["value"], path, errors, root_schema, active_refs)
		active_refs.erase(reference_text)

	if schema.has("oneOf"):
		var alternatives: Variant = schema["oneOf"]
		if typeof(alternatives) != TYPE_ARRAY or alternatives.is_empty():
			_add(errors, path, "oneOf must be a nonempty array")
			return
		var match_count: int = 0
		for alternative: Variant in alternatives:
			if typeof(alternative) != TYPE_DICTIONARY:
				_add(errors, path, "oneOf branches must be objects")
				return
			var branch_errors: Array[Dictionary] = []
			_validate_at(
				value, alternative, path, branch_errors, root_schema, active_refs.duplicate()
			)
			if branch_errors.is_empty():
				match_count += 1
		if match_count != 1:
			_add(errors, path, "oneOf must match exactly one branch")

	if schema.has("const") and not _json_equal(value, schema["const"]):
		_add(errors, path, "value differs from const")
	if schema.has("enum"):
		var options: Variant = schema["enum"]
		if typeof(options) != TYPE_ARRAY:
			_add(errors, path, "enum must be an array")
		elif not _array_contains_json(options, value):
			_add(errors, path, "value is not enumerated")

	var expected: String = ""
	if schema.has("type"):
		if typeof(schema["type"]) != TYPE_STRING:
			_add(errors, path, "type must be a string")
			return
		expected = schema["type"]
		if expected not in ["object", "array", "string", "integer", "number", "boolean", "null"]:
			_add(errors, path, "unsupported type")
			return
		if not _matches_type(value, expected):
			_add(errors, path, "expected " + expected)
			return

	if typeof(value) == TYPE_DICTIONARY:
		var object: Dictionary = value
		for required in schema.get("required", []):
			if not object.has(required): _add(errors, path, "missing required property: " + str(required))
		var properties: Dictionary = schema.get("properties", {})
		var additional: Variant = schema.get("additionalProperties", true)
		if typeof(additional) != TYPE_BOOL and typeof(additional) != TYPE_DICTIONARY:
			_add(errors, path, "additionalProperties must be boolean or a schema object")
			return
		for key in object:
			if properties.has(key): _validate_at(object[key], properties[key], path + "." + str(key), errors, root_schema, active_refs)
			elif additional is Dictionary:
				_validate_at(object[key], additional, path + "." + str(key), errors, root_schema, active_refs)
			elif additional == false: _add(errors, path, "unknown property: " + str(key))
	if typeof(value) == TYPE_ARRAY:
		var array: Array = value
		if schema.get("uniqueItems", false):
			for index in range(array.size()):
				if _array_contains_json(array.slice(0, index), array[index]): _add(errors, path, "array items must be unique")
		if array.size() < int(schema.get("minItems", 0)): _add(errors, path, "array is shorter than minItems")
		if schema.has("items"):
			for index in range(array.size()): _validate_at(array[index], schema["items"], "%s[%d]" % [path, index], errors, root_schema, active_refs)
	if typeof(value) == TYPE_STRING and value.length() < int(schema.get("minLength", 0)): _add(errors, path, "string is shorter than minLength")
	_validate_number(value, schema, path, errors)

static func _validate_number(
		value: Variant, schema: Dictionary, path: String, errors: Array[Dictionary]
) -> void:
	if schema.has("minimum"):
		if not _finite_number(schema["minimum"]):
			_add(errors, path, "minimum must be a finite number")
		elif _finite_number(value) and float(value) < float(schema["minimum"]):
			_add(errors, path, "number is below minimum")
	if schema.has("maximum"):
		if not _finite_number(schema["maximum"]):
			_add(errors, path, "maximum must be a finite number")
		elif _finite_number(value) and float(value) > float(schema["maximum"]):
			_add(errors, path, "number is above maximum")


static func _resolve_local_ref(reference: String, root_schema: Dictionary) -> Dictionary:
	if reference == "#":
		return {"ok": true, "value": root_schema}
	if not reference.begins_with("#/"):
		return {"ok": false, "message": "only local $ref is supported"}
	var cursor: Variant = root_schema
	for encoded_token: String in reference.substr(2).split("/"):
		var decoded: Dictionary = _decode_pointer_token(encoded_token)
		if not decoded["ok"]:
			return {"ok": false, "message": "malformed local $ref"}
		var token: String = decoded["value"]
		if typeof(cursor) == TYPE_DICTIONARY:
			if not cursor.has(token):
				return {"ok": false, "message": "unresolved local $ref"}
			cursor = cursor[token]
		elif typeof(cursor) == TYPE_ARRAY and token.is_valid_int():
			var index: int = int(token)
			if str(index) != token or index < 0 or index >= cursor.size():
				return {"ok": false, "message": "unresolved local $ref"}
			cursor = cursor[index]
		else:
			return {"ok": false, "message": "unresolved local $ref"}
	if typeof(cursor) != TYPE_DICTIONARY:
		return {"ok": false, "message": "local $ref target must be an object"}
	return {"ok": true, "value": cursor}


static func _decode_pointer_token(token: String) -> Dictionary:
	var result: String = ""
	var index: int = 0
	while index < token.length():
		var character: String = token[index]
		if character != "~":
			result += character
			index += 1
			continue
		if index + 1 >= token.length():
			return {"ok": false}
		var escape: String = token[index + 1]
		if escape == "0":
			result += "~"
		elif escape == "1":
			result += "/"
		else:
			return {"ok": false}
		index += 2
	return {"ok": true, "value": result}


static func _matches_type(value: Variant, expected: String) -> bool:
	match expected:
		"object":
			return typeof(value) == TYPE_DICTIONARY
		"array":
			return typeof(value) == TYPE_ARRAY
		"string":
			return typeof(value) == TYPE_STRING
		"integer":
			return typeof(value) == TYPE_INT or (
				typeof(value) == TYPE_FLOAT and is_finite(float(value))
				and floor(float(value)) == float(value)
			)
		"number":
			return _finite_number(value)
		"boolean":
			return typeof(value) == TYPE_BOOL
		"null":
			return value == null
		_:
			return false


static func _finite_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (
		typeof(value) == TYPE_FLOAT and is_finite(float(value))
	)


static func _array_contains_json(values: Array, target: Variant) -> bool:
	for value: Variant in values:
		if _json_equal(value, target):
			return true
	return false


static func _json_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) == TYPE_INT and typeof(right) == TYPE_INT: return left == right
	if _finite_number(left) and _finite_number(right):
		return float(left) == float(right)
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index: int in range(left.size()):
			if not _json_equal(left[index], right[index]):
				return false
		return true
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _json_equal(left[key], right[key]):
				return false
		return true
	return left == right


static func _add(errors: Array[Dictionary], path: String, message: String) -> void:
	errors.append({"path": path, "message": message})

static func _detach(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
