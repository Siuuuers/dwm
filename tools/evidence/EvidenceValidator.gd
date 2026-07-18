class_name EvidenceValidator
extends RefCounted

const SOURCE_PATHS: Array[String] = [
	"Prompt.md", "prompt_docs/INDEX.md", "prompt_docs/CONTRACTS.md",
	"prompt_docs/CONTENT.md", "prompt_docs/DIALOGIC.md", "prompt_docs/FLOWS.md",
	"prompt_docs/PHASES.md", "prompt_docs/REPORT.md", "prompt_docs/TESTING.md",
	"prompt_docs/GLOSSARY.md", "ResultReport.md", "Beads.md",
]
const SHA256_PATTERN := "^[0-9a-f]{64}$"

class StrictReader:
	var source := ""
	var cursor := 0
	var errors: Array[String] = []

	func _init(text: String) -> void:
		source = text

	func parse() -> Dictionary:
		_skip_space()
		var value: Variant = _read_value("$")
		_skip_space()
		if errors.is_empty() and cursor != source.length():
			_fail("JSON_TRAILING_DATA", "$")
		return {"ok": errors.is_empty(), "value": value, "errors": errors}

	func _read_value(path: String) -> Variant:
		_skip_space()
		if cursor >= source.length():
			_fail("JSON_UNEXPECTED_EOF", path)
			return null
		match source[cursor]:
			"{": return _read_object(path)
			"[": return _read_array(path)
			"\"": return _read_string(path)
			"t": return _read_literal("true", true, path)
			"f": return _read_literal("false", false, path)
			"n": return _read_literal("null", null, path)
			_: return _read_number(path)

	func _read_object(path: String) -> Dictionary:
		cursor += 1
		var output := {}
		var seen := {}
		_skip_space()
		if _consume("}"): return output
		while errors.is_empty():
			_skip_space()
			if cursor >= source.length() or source[cursor] != "\"":
				_fail("JSON_OBJECT_KEY_EXPECTED", path)
				return output
			var key: Variant = _read_string(path)
			if seen.has(key):
				_fail("JSON_DUPLICATE_MEMBER", path + "." + str(key))
				return output
			seen[key] = true
			_skip_space()
			if not _consume(":"):
				_fail("JSON_COLON_EXPECTED", path + "." + str(key))
				return output
			output[key] = _read_value(path + "." + str(key))
			_skip_space()
			if _consume("}"): return output
			if not _consume(","):
				_fail("JSON_COMMA_EXPECTED", path)
				return output
		return output

	func _read_array(path: String) -> Array:
		cursor += 1
		var output: Array = []
		_skip_space()
		if _consume("]"): return output
		while errors.is_empty():
			output.append(_read_value("%s[%d]" % [path, output.size()]))
			_skip_space()
			if _consume("]"): return output
			if not _consume(","):
				_fail("JSON_COMMA_EXPECTED", path)
				return output
		return output

	func _read_string(path: String) -> Variant:
		var start := cursor
		cursor += 1
		while cursor < source.length():
			var character := source[cursor]
			if character == "\"":
				cursor += 1
				var token := source.substr(start, cursor - start)
				var parsed: Variant = JSON.parse_string(token)
				if typeof(parsed) != TYPE_STRING:
					_fail("JSON_STRING_INVALID", path)
				return parsed
			if character == "\\":
				cursor += 1
				if cursor >= source.length() or not source[cursor] in ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]:
					_fail("JSON_ESCAPE_INVALID", path)
					return null
				if source[cursor] == "u":
					if cursor + 4 >= source.length() or not source.substr(cursor + 1, 4).is_valid_hex_number(false):
						_fail("JSON_UNICODE_ESCAPE_INVALID", path)
						return null
					cursor += 4
			elif character.unicode_at(0) < 0x20:
				_fail("JSON_CONTROL_CHARACTER", path)
				return null
			cursor += 1
		_fail("JSON_UNTERMINATED_STRING", path)
		return null

	func _read_number(path: String) -> Variant:
		var start := cursor
		while cursor < source.length() and source[cursor] in ["-", "+", ".", "e", "E", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			cursor += 1
		if cursor == start:
			_fail("JSON_VALUE_INVALID", path)
			return null
		var token := source.substr(start, cursor - start)
		var number_pattern := RegEx.create_from_string("^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$")
		if number_pattern.search(token) == null:
			_fail("JSON_NUMBER_INVALID", path)
			return null
		# Godot's JSON parser materializes every JSON number as a float. Preserve
		# integer tokens as ints so JSON Schema's integer/number distinction remains
		# meaningful without accepting fractional values as integer fields.
		if "." not in token and "e" not in token.to_lower():
			return token.to_int()
		return JSON.parse_string(token)

	func _read_literal(token: String, value: Variant, path: String) -> Variant:
		if source.substr(cursor, token.length()) != token:
			_fail("JSON_LITERAL_INVALID", path)
			return null
		cursor += token.length()
		return value

	func _skip_space() -> void:
		while cursor < source.length() and source[cursor] in [" ", "\t", "\r", "\n"]:
			cursor += 1

	func _consume(token: String) -> bool:
		if cursor < source.length() and source[cursor] == token:
			cursor += 1
			return true
		return false

	func _fail(code: String, path: String) -> void:
		if errors.is_empty(): errors.append("%s at %s byte=%d" % [code, path, cursor])

static func validate_file(path: String, schema_path: String) -> Dictionary:
	var errors: Array[String] = []
	var evidence_result := _parse_utf8_file(path)
	var schema_result := _parse_utf8_file(schema_path)
	errors.append_array(evidence_result.errors)
	errors.append_array(schema_result.errors)
	if not errors.is_empty(): return {"ok": false, "errors": errors, "evidence": {}}
	if typeof(evidence_result.value) != TYPE_DICTIONARY or typeof(schema_result.value) != TYPE_DICTIONARY:
		errors.append("EVIDENCE_OR_SCHEMA_NOT_OBJECT")
		return {"ok": false, "errors": errors, "evidence": {}}
	_validate_schema(evidence_result.value, schema_result.value, "$", errors)
	if errors.is_empty(): _validate_cross_fields(evidence_result.value, errors)
	return {"ok": errors.is_empty(), "errors": errors, "evidence": evidence_result.value}

static func parse_strict_text(text: String) -> Dictionary:
	return StrictReader.new(text).parse()

static func _parse_utf8_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"value": null, "errors": ["FILE_MISSING: " + path]}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
		return {"value": null, "errors": ["UTF8_BOM_FORBIDDEN: " + path]}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"value": null, "errors": ["UTF8_INVALID: " + path]}
	return StrictReader.new(text).parse()

static func _validate_schema(value: Variant, schema: Dictionary, path: String, errors: Array[String]) -> void:
	var allowed := ["$schema", "title", "description", "type", "const", "enum", "required", "additionalProperties", "properties", "items", "minItems", "maxItems", "uniqueItems", "minimum", "maximum", "minLength", "pattern"]
	for keyword: Variant in schema.keys():
		if not keyword in allowed: errors.append("SCHEMA_KEYWORD_UNSUPPORTED: %s at %s" % [keyword, path])
	if schema.has("type"):
		var declared_types: Array = schema.type if typeof(schema.type) == TYPE_ARRAY else [schema.type]
		var type_matches := false
		for declared: Variant in declared_types: type_matches = type_matches or _matches_type(value, str(declared))
		if not type_matches:
			errors.append("SCHEMA_TYPE: expected %s at %s" % [schema.type, path])
			return
	if schema.has("const") and value != schema.const: errors.append("SCHEMA_CONST: " + path)
	if schema.has("enum") and not value in schema.enum: errors.append("SCHEMA_ENUM: " + path)
	if typeof(value) == TYPE_DICTIONARY:
		for required: Variant in schema.get("required", []):
			if not value.has(required): errors.append("SCHEMA_REQUIRED: %s.%s" % [path, required])
		var properties: Dictionary = schema.get("properties", {})
		for key: Variant in value.keys():
			if properties.has(key): _validate_schema(value[key], properties[key], path + "." + str(key), errors)
			elif schema.get("additionalProperties", true) == false: errors.append("SCHEMA_UNKNOWN_MEMBER: %s.%s" % [path, key])
	elif typeof(value) == TYPE_ARRAY:
		if value.size() < int(schema.get("minItems", 0)): errors.append("SCHEMA_MIN_ITEMS: " + path)
		if schema.has("maxItems") and value.size() > int(schema.maxItems): errors.append("SCHEMA_MAX_ITEMS: " + path)
		if schema.get("uniqueItems", false):
			var seen := {}
			for item: Variant in value:
				var key := JSON.stringify(item, "", false)
				if seen.has(key): errors.append("SCHEMA_UNIQUE_ITEMS: " + path)
				seen[key] = true
		if schema.has("items"):
			for index in value.size(): _validate_schema(value[index], schema.items, "%s[%d]" % [path, index], errors)
	elif typeof(value) == TYPE_STRING:
		if value.length() < int(schema.get("minLength", 0)): errors.append("SCHEMA_MIN_LENGTH: " + path)
		if schema.has("pattern") and RegEx.create_from_string(str(schema.pattern)).search(value) == null: errors.append("SCHEMA_PATTERN: " + path)
	elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		if schema.has("minimum") and value < schema.minimum: errors.append("SCHEMA_MINIMUM: " + path)
		if schema.has("maximum") and value > schema.maximum: errors.append("SCHEMA_MAXIMUM: " + path)

static func _matches_type(value: Variant, expected: String) -> bool:
	match expected:
		"object": return typeof(value) == TYPE_DICTIONARY
		"array": return typeof(value) == TYPE_ARRAY
		"string": return typeof(value) == TYPE_STRING
		"integer": return typeof(value) == TYPE_INT
		"number": return typeof(value) in [TYPE_INT, TYPE_FLOAT]
		"boolean": return typeof(value) == TYPE_BOOL
		"null": return value == null
		_: return false

static func _validate_cross_fields(evidence: Dictionary, errors: Array[String]) -> void:
	var source_by_path := {}
	for record: Dictionary in evidence.source_archive:
		_validate_archive_record(record, "source_archive", errors)
		if source_by_path.has(record.path): errors.append("SOURCE_DUPLICATE: " + record.path)
		source_by_path[record.path] = record
	for path: String in SOURCE_PATHS:
		if not source_by_path.has(path): errors.append("SOURCE_MISSING: " + path)
	for unexpected: Variant in source_by_path.keys():
		if not unexpected in SOURCE_PATHS: errors.append("SOURCE_UNEXPECTED: " + str(unexpected))
	for record: Dictionary in evidence.preserved_outside_authority:
		_validate_base64_hash(record, "content_base64", "sha256", "byte_length", "preserved:" + str(record.path), errors)
	_validate_commands(evidence, errors)
	_validate_logs(evidence, errors)
	_validate_inventory(evidence, source_by_path, errors)
	if not _primitive_only(evidence): errors.append("EVIDENCE_NONPRIMITIVE")

static func _validate_archive_record(record: Dictionary, label: String, errors: Array[String]) -> void:
	_validate_base64_hash(record, "content_base64", "sha256", "byte_length", label + ":" + str(record.path), errors)
	var content_bytes := Marshalls.base64_to_raw(str(record.content_base64))
	if content_bytes.get_string_from_utf8() != str(record.content_utf8) or str(record.content_utf8).to_utf8_buffer() != content_bytes:
		errors.append("UTF8_BASE64_DISAGREEMENT: " + str(record.path))
	_validate_base64_hash(record, "working_tree_patch_base64", "working_tree_patch_sha256", "", "patch:" + str(record.path), errors)
	var patch_bytes := Marshalls.base64_to_raw(str(record.working_tree_patch_base64))
	if patch_bytes.get_string_from_utf8() != str(record.working_tree_patch_utf8) or str(record.working_tree_patch_utf8).to_utf8_buffer() != patch_bytes:
		errors.append("PATCH_UTF8_BASE64_DISAGREEMENT: " + str(record.path))

static func _validate_base64_hash(record: Dictionary, bytes_key: String, hash_key: String, length_key: String, label: String, errors: Array[String]) -> void:
	var encoded := str(record[bytes_key])
	var bytes := Marshalls.base64_to_raw(encoded)
	if (not encoded.is_empty() and Marshalls.raw_to_base64(bytes) != encoded) or (encoded.is_empty() and not bytes.is_empty()):
		errors.append("BASE64_INVALID: " + label)
	if not length_key.is_empty() and bytes.size() != int(record[length_key]): errors.append("BYTE_LENGTH_MISMATCH: " + label)
	var digest := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" if bytes.is_empty() else _sha256(bytes)
	if RegEx.create_from_string(SHA256_PATTERN).search(str(record[hash_key])) == null or digest != str(record[hash_key]):
		errors.append("SHA256_MISMATCH: " + label)

static func _validate_commands(evidence: Dictionary, errors: Array[String]) -> void:
	for command: Dictionary in evidence.commands:
		var root := str(command.test_root).replace("\\", "/").trim_suffix("/").to_lower()
		var user_dir := str(command.user_dir).replace("\\", "/").to_lower()
		if not user_dir.begins_with(root + "/"): errors.append("COMMAND_USER_DIR_OUTSIDE_ROOT: " + str(command.suite_id))
		if int(command.exit_code) != 0 and not command.suite_id in ["baseline-existing-gut", "baseline-existing-scenes"]:
			errors.append("COMMAND_EXIT_NONZERO: " + str(command.suite_id))
		if int(command.exit_code) != 0:
			var matched := false
			for diagnostic: Dictionary in evidence.diagnostics:
				matched = matched or (diagnostic.get("suite_id") == command.suite_id and int(diagnostic.get("exit_code", -1)) == int(command.exit_code) and diagnostic.has("log_sha256"))
			if not matched: errors.append("COMMAND_DIAGNOSTIC_MISSING: " + str(command.suite_id))

static func _validate_logs(evidence: Dictionary, errors: Array[String]) -> void:
	for record: Dictionary in evidence.archived_logs:
		if not FileAccess.file_exists("res://" + str(record.evidence_log_path)):
			errors.append("ARCHIVED_LOG_MISSING: " + str(record.evidence_log_path))
			continue
		var bytes := FileAccess.get_file_as_bytes("res://" + str(record.evidence_log_path))
		if bytes.size() != int(record.byte_length): errors.append("ARCHIVED_LOG_LENGTH: " + str(record.evidence_log_path))
		var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
		if context.finish().hex_encode() != str(record.sha256): errors.append("ARCHIVED_LOG_SHA256: " + str(record.evidence_log_path))

static func _validate_inventory(evidence: Dictionary, sources: Dictionary, errors: Array[String]) -> void:
	var binding: Dictionary = evidence.legacy_heading_inventory
	var inventory_path := "res://" + str(binding.path)
	var parsed := _parse_utf8_file(inventory_path)
	if not parsed.errors.is_empty(): errors.append_array(parsed.errors); return
	var inventory_bytes := FileAccess.get_file_as_bytes(inventory_path)
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(inventory_bytes)
	if context.finish().hex_encode() != str(binding.sha256): errors.append("INVENTORY_SHA256_MISMATCH")
	var expected: Array[Dictionary] = []
	var zero_paths: Array[String] = []
	for path: String in SOURCE_PATHS:
		var extracted := _extract_atx_headings(Marshalls.base64_to_raw(str(sources[path].content_base64)), path, str(sources[path].sha256))
		expected.append_array(extracted.headings)
		if extracted.headings.is_empty(): zero_paths.append(path)
	if JSON.stringify(expected) != JSON.stringify(parsed.value.headings): errors.append("INVENTORY_HEADING_BIJECTION")
	var expected_zero: Array[Dictionary] = []
	for path: String in zero_paths: expected_zero.append({"path": path, "source_sha256": str(sources[path].sha256)})
	if JSON.stringify(parsed.value.zero_heading_documents) != JSON.stringify(expected_zero): errors.append("INVENTORY_ZERO_HEADING_BIJECTION")
	var expected_documents: Array[Dictionary] = []
	for path: String in SOURCE_PATHS:
		var heading_count := 0
		for heading: Dictionary in expected:
			if heading.source_path == path: heading_count += 1
		expected_documents.append({"path": path, "sha256": str(sources[path].sha256), "byte_length": int(sources[path].byte_length), "heading_count": heading_count})
	if JSON.stringify(parsed.value.source_documents) != JSON.stringify(expected_documents): errors.append("INVENTORY_SOURCE_DOCUMENT_DRIFT")
	if int(binding.heading_count) != expected.size() or int(binding.document_count) != SOURCE_PATHS.size(): errors.append("INVENTORY_COUNT_MISMATCH")

static func _extract_atx_headings(bytes: PackedByteArray, path: String, source_sha: String) -> Dictionary:
	var headings: Array[Dictionary] = []
	var offset := 0
	var line_number := 1
	var fence := ""
	while offset < bytes.size():
		var end := offset
		while end < bytes.size() and bytes[end] != 0x0a: end += 1
		var content_end := end - 1 if end > offset and bytes[end - 1] == 0x0d else end
		var line_bytes := bytes.slice(offset, content_end)
		var line := line_bytes.get_string_from_utf8()
		var fence_match := RegEx.create_from_string("^\\s*(`{3,}|~{3,})").search(line)
		if fence_match != null:
			var marker: String = fence_match.get_string(1)
			if fence.is_empty(): fence = marker[0]
			elif marker[0] == fence: fence = ""
		elif fence.is_empty():
			var heading_match := RegEx.create_from_string("^(#{1,6})[ \\t]+.*$").search(line)
			if heading_match != null:
				var ordinal := headings.size() + 1
				var exact := line_bytes.get_string_from_utf8()
				var identity := PackedByteArray()
				identity.append_array(path.to_utf8_buffer())
				identity.append(0)
				identity.append_array(source_sha.to_utf8_buffer())
				identity.append(0)
				identity.append_array(str(ordinal).to_utf8_buffer())
				identity.append(0)
				identity.append_array(exact.to_utf8_buffer())
				var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(identity)
				headings.append({"heading_id": hash.finish().hex_encode(), "source_path": path, "source_sha256": source_sha, "ordinal_in_document": ordinal, "markdown_level": heading_match.get_string(1).length(), "line_number": line_number, "byte_offset": offset, "exact_heading_utf8": exact, "exact_heading_base64": Marshalls.raw_to_base64(line_bytes)})
		offset = end + 1 if end < bytes.size() else end
		line_number += 1
	return {"headings": headings}

static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _primitive_only(value: Variant) -> bool:
	if value == null or typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]: return true
	if typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if not _primitive_only(item): return false
		return true
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value.keys():
			if typeof(key) != TYPE_STRING or not _primitive_only(value[key]): return false
		return true
	return false
