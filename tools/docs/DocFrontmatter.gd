class_name DocFrontmatter
extends RefCounted

const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")
const KEY_PATTERN := "^[a-z][a-z0-9_]*$"
const BARE_SCALAR_PATTERN := "^[A-Za-z0-9_.-]+$"

static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(false, {}, "", ["DOC_FRONTMATTER_MISSING: " + path])
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _result(false, {}, "", ["DOC_FRONTMATTER_INVALID: invalid UTF-8 in " + path])
	return parse_text(text, path)

static func parse_text(text: String, source_path: String = "<memory>") -> Dictionary:
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	var lines := normalized.split("\n", true)
	if lines.is_empty() or lines[0] != "---":
		return _result(false, {}, normalized, ["DOC_FRONTMATTER_MISSING: " + source_path])
	var closing := -1
	for index in range(1, lines.size()):
		if lines[index] == "---": closing = index; break
	if closing < 0:
		return _result(false, {}, normalized, ["DOC_FRONTMATTER_INVALID: unterminated frontmatter in " + source_path])
	var frontmatter := {}
	var errors: Array[String] = []
	var line_index := 1
	while line_index < closing:
		var line: String = lines[line_index]
		if line.is_empty(): line_index += 1; continue
		if line.contains("\t") or line.begins_with(" "):
			errors.append("DOC_FRONTMATTER_INVALID: illegal indentation/tab at %s:%d" % [source_path, line_index + 1])
			line_index += 1; continue
		var colon := line.find(":")
		if colon <= 0:
			errors.append("DOC_FRONTMATTER_INVALID: expected key:value at %s:%d" % [source_path, line_index + 1])
			line_index += 1; continue
		var key := line.substr(0, colon)
		var raw := line.substr(colon + 1).strip_edges()
		if RegEx.create_from_string(KEY_PATTERN).search(key) == null:
			errors.append("DOC_FRONTMATTER_INVALID: invalid key %s" % key)
		elif frontmatter.has(key):
			errors.append("DOC_FRONTMATTER_INVALID: duplicate key %s" % key)
		if key == "requirements":
			if raw == "[]":
				frontmatter[key] = []
				line_index += 1
				continue
			if not raw.is_empty(): errors.append("DOC_FRONTMATTER_INVALID: requirements must use block JSON objects")
			var requirements: Array[Dictionary] = []
			line_index += 1
			while line_index < closing and lines[line_index].begins_with("  - "):
				var item_text := lines[line_index].substr(4)
				var parsed := STRICT_JSON.parse_strict_text(item_text)
				if not parsed.ok or typeof(parsed.value) != TYPE_DICTIONARY:
					errors.append("DOC_FRONTMATTER_INVALID: requirement JSON at %s:%d %s" % [source_path, line_index + 1, JSON.stringify(parsed.errors)])
				else: requirements.append(parsed.value)
				line_index += 1
			frontmatter[key] = requirements
			continue
		if raw.is_empty() or raw.begins_with("&") or raw.begins_with("*") or raw.begins_with("!") or raw in ["|", ">", "|-", ">-"]:
			errors.append("DOC_FRONTMATTER_INVALID: forbidden YAML feature for %s" % key)
		else:
			var parsed_value := _parse_scalar(raw)
			if not parsed_value.ok: errors.append("DOC_FRONTMATTER_INVALID: %s at %s:%d" % [parsed_value.error, source_path, line_index + 1])
			else: frontmatter[key] = parsed_value.value
		line_index += 1
	var body := "\n".join(lines.slice(closing + 1))
	return _result(errors.is_empty(), frontmatter, body, errors)

static func _parse_scalar(raw: String) -> Dictionary:
	if RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}(?:[T ].*)?$").search(raw) != null:
		return {"ok": false, "error": "implicit date forbidden", "value": null}
	if raw.begins_with("[") or raw.begins_with("{") or raw.begins_with("\"") or raw in ["true", "false", "null"] or RegEx.create_from_string("^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?$").search(raw) != null:
		var parsed := STRICT_JSON.parse_strict_text(raw)
		return {"ok": parsed.ok, "error": JSON.stringify(parsed.errors), "value": parsed.value}
	if RegEx.create_from_string(BARE_SCALAR_PATTERN).search(raw) != null:
		return {"ok": true, "error": "", "value": raw}
	return {"ok": false, "error": "scalar is outside strict subset", "value": null}

static func _result(ok: bool, frontmatter: Dictionary, body: String, errors: Array[String]) -> Dictionary:
	return {"ok": ok, "frontmatter": frontmatter, "body": body, "errors": errors}
