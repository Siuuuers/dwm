extends RefCounted

static func project_blocks(bundle: Dictionary, sections: Array, programme: Callable) -> Dictionary:
	var lines := {}
	var targets := {}
	var markers := {}
	for target: Dictionary in bundle.get("targets", []): targets[target.target_id] = target.target.entry_id
	for entry: Dictionary in bundle.scene_programme.entries:
		for marker: Dictionary in entry.markers: markers[marker.marker_id] = marker
	for entry: Dictionary in bundle.caption_registry.entries:
		for line: Dictionary in entry.lines:
			lines[line.line_id] = {"entry_id": entry.entry_id, "line": line}
	var captions: Array[Dictionary] = []
	for section: Dictionary in sections:
		if not lines.has(section.checkpoint_id) or not lines.has(section.last_line_id): continue
		var entry_id: String = lines[section.checkpoint_id].entry_id
		var loaded: Dictionary = programme.call(entry_id)
		if not loaded.ok: return loaded
		var nodes: Array = loaded.value
		var index := -1
		for position: int in nodes.size():
			if nodes[position].get("line_id") == section.checkpoint_id: index = position; break
		var visited := {}
		var reached := false
		while index >= 0 and index < nodes.size():
			var key := entry_id + ":" + str(index)
			if visited.has(key): break
			visited[key] = true
			var node: Dictionary = nodes[index]
			if node.kind == "caption":
				var ids: Array = [node.line_id]
				if node.has("self_talk"): ids.append(node.self_talk.line_id)
				for line_id: String in ids:
					if not lines.has(line_id): continue
					var line: Dictionary = lines[line_id].line
					captions.append({"line_id": line_id, "entry_id": entry_id, "beat_id": line.beat_id,
						"text": line.text, "publication_id": "history:" + line_id})
					if line_id == section.last_line_id: reached = true; break
				if reached: break
				index = node.next
			elif node.kind == "jump": index = node.next
			elif node.kind == "control":
				var marker: Dictionary = markers.get(node.marker_id, {})
				if marker.get("kind") == "scene.transition":
					entry_id = targets.get(marker.payload.target_id, "")
					loaded = programme.call(entry_id)
					if not loaded.ok: return loaded
					nodes = loaded.value
					index = 0
				else: index += 1
			else: break
		if not reached: return {"ok": false, "code": &"history_path_unavailable"}
	return {"ok": true, "value": {"captions": captions}}
