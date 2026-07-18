class_name ProjectConfigGuard
extends RefCounted

func inspect_file(path: String = "res://project.godot") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["PROJECT_CONFIG_MISSING: " + path], "canonical_count": 0}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 3 and bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
		return {"ok": false, "errors": ["PROJECT_CONFIG_INVALID: UTF-8 BOM"], "canonical_count": 0}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false, "errors": ["PROJECT_CONFIG_INVALID: invalid UTF-8"], "canonical_count": 0}
	return inspect_text(text)

func inspect_text(text: String) -> Dictionary:
	var errors: Array[String] = []
	var canonical_count := 0
	var first_section := -1
	var assignments: Array[Dictionary] = []
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	for index in lines.size():
		var line: String = lines[index]
		if first_section < 0 and line.begins_with("["): first_section = index
		var equals := line.find("=")
		if equals < 0: continue
		var key := line.substr(0, equals).strip_edges()
		if not key.contains("config_version"): continue
		var value := line.substr(equals + 1).strip_edges()
		assignments.append({"index": index, "key": key, "value": value})
		if key == "config_version" and value == "5" and (first_section < 0 or index < first_section):
			canonical_count += 1
		else:
			errors.append("PROJECT_CONFIG_INVALID: noncanonical config_version key %s" % key)
	if assignments.is_empty(): errors.append("PROJECT_CONFIG_INVALID: config_version missing")
	if canonical_count != 1: errors.append("PROJECT_CONFIG_INVALID: canonical config_version count=%d" % canonical_count)
	if assignments.size() != 1: errors.append("PROJECT_CONFIG_INVALID: total config_version count=%d" % assignments.size())
	return {"ok": errors.is_empty(), "errors": errors, "canonical_count": canonical_count}
