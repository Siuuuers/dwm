extends RefCounted
## Authored ordinary-DTL ranges. Start labels are passive; only Finish has effects.
## The current bounded contract permits one uninterrupted range per scene entry.

static func valid_id(value: Variant) -> bool:
	if not value is String or not value.begins_with("passage.") or value.length() <= 8: return false
	for character: String in value:
		if not ((character >= "a" and character <= "z") or (character >= "A" and character <= "Z") \
				or (character >= "0" and character <= "9") or character in [".", "_", "-"]): return false
	return true

static func inspect(bundle: Dictionary) -> Dictionary:
	if not bundle.get("scene_programme") is Dictionary or not bundle.scene_programme.get("entries") is Array \
			or not bundle.get("caption_registry") is Dictionary or not bundle.caption_registry.get("entries") is Array:
		return _fail(&"scene_passage_registration_invalid")
	var captions := {}
	for row: Variant in bundle.caption_registry.entries:
		if not row is Dictionary or not row.get("entry_id") is String or not row.get("lines") is Array:
			return _fail(&"scene_passage_registration_invalid")
		captions[row.entry_id] = row.lines
	var records := {}
	for entry: Variant in bundle.scene_programme.entries:
		if not entry is Dictionary or not entry.get("entry_id") is String or not entry.get("markers") is Array:
			return _fail(&"scene_passage_registration_invalid")
		var start := {}
		var finish := {}
		for marker: Variant in entry.markers:
			if not marker is Dictionary: return _fail(&"scene_passage_registration_invalid")
			if marker.get("kind") == "passage.start":
				if not start.is_empty(): return _fail(&"scene_passage_range_ambiguous")
				start = marker
			elif marker.get("kind") == "passage.finish":
				if not finish.is_empty(): return _fail(&"scene_passage_range_ambiguous")
				finish = marker
		if start.is_empty() and finish.is_empty(): continue
		if not _marker(start) or not _marker(finish) or start.payload.passage_id != finish.payload.passage_id \
				or not captions.has(entry.entry_id) or records.has(start.payload.passage_id):
			return _fail(&"scene_passage_pair_invalid")
		var lines: Array = captions[entry.entry_id]
		var indices := {}
		for index: int in lines.size():
			if not lines[index] is Dictionary or not lines[index].get("line_id") is String \
					or not lines[index].get("text") is String or indices.has(lines[index].line_id):
				return _fail(&"scene_passage_registration_invalid")
			indices[lines[index].line_id] = index
		if not indices.has(start.after_line_id) or not indices.has(finish.after_line_id) \
				or indices[start.after_line_id] >= indices[finish.after_line_id]:
			return _fail(&"scene_passage_range_invalid")
		var first: int = indices[start.after_line_id] + 1
		var last: int = indices[finish.after_line_id]
		for marker: Dictionary in entry.markers:
			if marker == start or marker == finish: continue
			if indices.has(marker.get("after_line_id")):
				var index: int = indices[marker.after_line_id]
				if index >= first - 1 and index <= last:
					return _fail(&"scene_passage_control_inside_range")
		var selected: Array = lines.slice(first, last + 1).duplicate(true)
		var line_ids: Array[String] = []
		for line: Dictionary in selected: line_ids.append(line.line_id)
		records[start.payload.passage_id] = {"passage_id": start.payload.passage_id,
			"entry_id": entry.entry_id, "start_label": start.label, "finish_label": finish.label,
			"start_marker_id": start.marker_id, "finish_marker_id": finish.marker_id,
			"line_ids": line_ids, "captions": selected}
	return {"ok": true, "value": {"records": records}}

static func _marker(value: Dictionary) -> bool:
	return value.get("payload") is Dictionary and value.payload.size() == 1 \
		and valid_id(value.payload.get("passage_id")) and value.get("label") is String \
		and not value.label.is_empty() and value.get("after_line_id") is String \
		and value.get("marker_id") is String and not value.marker_id.is_empty()

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
