class_name JsonSchemaValidator
extends RefCounted

static func validate(value: Variant, schema: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	_validate_at(value, schema, "$", errors)
	if errors.is_empty(): return {"ok": true, "value": _detach(value)}
	return {"ok": false, "code": &"schema_validation_failed", "message": errors[0]["message"], "errors": errors.duplicate(true)}

static func _validate_at(value: Variant, schema: Dictionary, path: String, errors: Array[Dictionary]) -> void:
	var expected: String = schema.get("type", "")
	if not expected.is_empty() and not _matches_type(value, expected):
		_add(errors, path, "expected " + expected)
		return
	if schema.has("const"):
		var expected_const: Variant = schema["const"]
		if _same_type(value, expected_const) and value != expected_const:
			_add(errors, path, "value differs from const")
		elif not _same_type(value, expected_const):
			_add(errors, path, "value differs from const")
	if schema.has("enum") and value not in schema["enum"]:
		_add(errors, path, "value is not enumerated")
	if typeof(value) == TYPE_DICTIONARY:
		var object: Dictionary = value
		for required in schema.get("required", []):
			if not object.has(required): _add(errors, path, "missing required property: " + str(required))
		var properties: Dictionary = schema.get("properties", {})
		for key in object:
			if properties.has(key): _validate_at(object[key], properties[key], path + "." + str(key), errors)
			elif schema.get("additionalProperties", true) == false: _add(errors, path, "unknown property: " + str(key))
	if typeof(value) == TYPE_ARRAY:
		var array: Array = value
		if schema.get("uniqueItems", false):
			for index in range(array.size()):
				if array.slice(0, index).has(array[index]): _add(errors, path, "array items must be unique")
		if schema.has("items"):
			for index in range(array.size()): _validate_at(array[index], schema["items"], "%s[%d]" % [path, index], errors)
	if typeof(value) == TYPE_STRING and value.length() < int(schema.get("minLength", 0)): _add(errors, path, "string is shorter than minLength")

static func _matches_type(value: Variant, expected: String) -> bool:
	return (expected == "object" and typeof(value) == TYPE_DICTIONARY) or (expected == "array" and typeof(value) == TYPE_ARRAY) or (expected == "string" and typeof(value) == TYPE_STRING) or (expected == "integer" and typeof(value) == TYPE_INT) or (expected == "number" and typeof(value) in [TYPE_INT, TYPE_FLOAT]) or (expected == "boolean" and typeof(value) == TYPE_BOOL) or (expected == "null" and value == null)

static func _same_type(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left == null:
		return true
	if typeof(left) == TYPE_DICTIONARY:
		return (left as Dictionary).size() == (right as Dictionary).size()
	if typeof(left) == TYPE_ARRAY:
		return true
	return true

static func _add(errors: Array[Dictionary], path: String, message: String) -> void:
	errors.append({"path": path, "message": message})

static func _detach(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
