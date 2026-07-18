extends SceneTree

const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCENE_OUTPUT := "res://evidence/phase_2r/localization/ui_literal_disposition.json"
const SCRIPT_OUTPUT := "res://evidence/phase_2r/localization/script_ui_disposition.json"
const SCENE_PROPERTIES := ["text", "placeholder_text", "tooltip_text", "accessibility_name"]
const SCRIPT_PROPERTIES := ["text", "placeholder_text", "tooltip_text", "accessibility_name", "dialog_text"]
const SCRIPT_CALLS := ["set_text", "add_item", "set_item_text"]


func _init() -> void:
	var scene_records: Array = []
	for path in _files_below("res://scenes", ".tscn"):
		var scanned := _scan_scene(path)
		if not scanned.get("ok", false):
			_fail(scanned)
			return
		scene_records.append_array(scanned["value"])
	var script_records: Array = []
	for root in ["res://autoload", "res://scripts"]:
		for path in _files_below(root, ".gd"):
			if path.ends_with("/UiLiteralAudit.gd"):
				continue
			script_records.append_array(_scan_script(path))
	var scene_result := _validate_and_write(SCENE_OUTPUT, scene_records)
	if not scene_result.get("ok", false):
		_fail(scene_result)
		return
	var script_result := _validate_and_write(SCRIPT_OUTPUT, script_records)
	if not script_result.get("ok", false):
		_fail(script_result)
		return
	quit(0)


func _scan_scene(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	var lines := source.split("\n")
	var binding_targets := _scene_binding_targets(lines)
	var records: Array = []
	var current_node := ""
	for index in range(lines.size()):
		var line: String = lines[index].trim_suffix("\r")
		if line.begins_with("[node "):
			current_node = _scene_node_path(line)
			continue
		for property in SCENE_PROPERTIES:
			var prefix := "%s = " % property
			if not line.begins_with(prefix):
				continue
			var expression := line.substr(prefix.length())
			var decoded: Variant = JSON.parse_string(expression)
			if typeof(decoded) != TYPE_STRING:
				return _failure(&"invalid_scene_literal", path, index + 1)
			var location := "%s:%s" % [current_node, property]
			var disposition := _scene_disposition(path, current_node, property, decoded, binding_targets)
			if disposition["disposition"] == "unclassified":
				return _failure(&"unclassified_scene_literal", path, index + 1)
			records.append(_record(path, index + 1, property, expression, disposition))
	return {"ok": true, "value": records}


func _scene_binding_targets(lines: PackedStringArray) -> Dictionary:
	var output := {}
	var current_is_binding := false
	var target := ""
	var property := "text"
	for line_value in lines:
		var line: String = line_value.trim_suffix("\r")
		if line.begins_with("[node "):
			if current_is_binding and not target.is_empty():
				var location := "%s:%s" % [_normalize_target(target), property]
				if not output.has(location):
					output[location] = ""
			current_is_binding = false
			target = ""
			property = "text"
		elif line.contains("LocalizedBinding.gd"):
			pass
		elif line.begins_with("script = ExtResource("):
			# Binding nodes in Task 5 always carry an L10n name; ext-resource IDs are not semantic.
			pass
		elif line.begins_with("target_path = NodePath("):
			current_is_binding = true
			target = line.get_slice("\"", 1)
		elif current_is_binding and line.begins_with("target_property = "):
			property = line.get_slice("\"", 1)
		elif current_is_binding and line.begins_with("key = "):
			output["%s:%s" % [_normalize_target(target), property]] = line.get_slice("\"", 1)
	if current_is_binding and not target.is_empty():
		output["%s:%s" % [_normalize_target(target), property]] = output.get("%s:%s" % [_normalize_target(target), property], "")
	return output


func _scene_node_path(header: String) -> String:
	var name := header.get_slice("\"", 1)
	var parent := ""
	if header.contains(" parent=\""):
		parent = header.get_slice(" parent=\"", 1).get_slice("\"", 0)
	if parent.is_empty() or parent == ".":
		return name if parent.is_empty() else name
	return "%s/%s" % [parent, name]


func _normalize_target(target: String) -> String:
	while target.begins_with("../"):
		target = target.trim_prefix("../")
	return target


func _scene_disposition(path: String, node_path: String, property: String, text: String, bindings: Dictionary) -> Dictionary:
	var target_key := "%s:%s" % [node_path, property]
	if bindings.has(target_key) and not str(bindings[target_key]).is_empty():
		return {"disposition": "localized_binding", "key": bindings[target_key], "reason": "explicit LocalizedBinding target"}
	if text.is_empty() or text.is_valid_int() or text.is_valid_float():
		return {"disposition": "runtime_data", "key": "", "reason": "empty or numeric runtime placeholder"}
	if text in ["+", "-", "X"]:
		return {"disposition": "decorative", "key": "", "reason": "symbol-only control glyph"}
	if "/shared/DialogueBox.tscn" in path or "/shared/ChatBubble.tscn" in path:
		return {"disposition": "narrative_owned_by_dialogic", "key": "", "reason": "dialogue runtime presentation"}
	if "/shared/" in path:
		return {"disposition": "runtime_data", "key": "", "reason": "shared component placeholder replaced by its presenter"}
	return {"disposition": "unclassified", "key": "", "reason": "stable literal requires localization ownership"}


func _scan_script(path: String) -> Array:
	var records: Array = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for index in range(lines.size()):
		var line: String = lines[index].trim_suffix("\r")
		var sink := ""
		var expression := ""
		for property in SCRIPT_PROPERTIES:
			var marker := ".%s =" % property
			if marker in line:
				sink = property
				expression = line.substr(line.find(marker) + marker.length()).strip_edges()
				break
		if sink.is_empty():
			for call_name in SCRIPT_CALLS:
				var marker := ".%s(" % call_name
				if marker in line:
					sink = call_name
					expression = line.substr(line.find(marker) + marker.length()).strip_edges()
					break
		if sink.is_empty():
			continue
		var localized := ".t(" in expression or "LocalizationManager" in expression
		var disposition := {
			"disposition": "localized_call" if localized else "runtime_data",
			"key": _literal_translation_key(expression) if localized else "",
			"reason": "LocalizationManager lookup" if localized else "runtime presenter value",
		}
		records.append(_record(path, index + 1, sink, expression, disposition))
	return records


func _literal_translation_key(expression: String) -> String:
	var marker := ".t(\""
	var start := expression.find(marker)
	if start < 0:
		return "dynamic"
	return expression.substr(start + marker.length()).get_slice("\"", 0)


func _record(path: String, line_number: int, sink: String, expression: String, disposition: Dictionary) -> Dictionary:
	var line_text := FileAccess.get_file_as_string(path).split("\n")[line_number - 1].trim_suffix("\r")
	return {
		"source_path": path.trim_prefix("res://"),
		"line": line_number,
		"line_sha256": line_text.sha256_text(),
		"sink": sink,
		"source_expression": expression,
		"disposition": disposition["disposition"],
		"key": disposition["key"],
		"reason": disposition["reason"],
	}


func _validate_and_write(path: String, records: Array) -> Dictionary:
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [a["source_path"], a["line"], a["sink"]] < [b["source_path"], b["line"], b["sink"]])
	var seen := {}
	for record in records:
		var id := "%s:%d:%s" % [record["source_path"], record["line"], record["sink"]]
		if seen.has(id):
			return _failure(&"duplicate_literal_location", record["source_path"], record["line"])
		seen[id] = true
		if record["disposition"] not in ["localized_binding", "localized_call", "runtime_data", "decorative", "narrative_owned_by_dialogic"]:
			return _failure(&"invalid_disposition", record["source_path"], record["line"])
	var encoded := WRITER.stringify({"schema_version": 1, "records": records})
	if not encoded.get("ok", false):
		return encoded
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure(&"evidence_write_failed", path, 0)
	file.store_string(encoded["value"])
	file.flush()
	return {"ok": true}


func _files_below(root: String, suffix: String) -> Array[String]:
	var output: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return output
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir():
			output.append_array(_files_below("%s/%s" % [root, name], suffix))
		elif name.ends_with(suffix):
			output.append("%s/%s" % [root, name])
		name = directory.get_next()
	directory.list_dir_end()
	output.sort()
	return output


func _failure(code: StringName, path: String, line_number: int) -> Dictionary:
	return {"ok": false, "code": code, "path": path, "line": line_number}


func _fail(result: Dictionary) -> void:
	push_error("UiLiteralAudit: %s" % JSON.stringify(result))
	quit(1)
