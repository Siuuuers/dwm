extends RefCounted
## Export-only metadata discovery. Dialogic owns parsing, labels and text IDs.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const EVENTS := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const PASSAGE := preload("res://scripts/narrative/ScenePassageCatalog.gd")
const MARKER_KINDS := ["thought.pass", "thought.options", "scene.transition", "challenge.playable",
	"challenge.end", "challenge.recall", "passage.start", "passage.finish"]

static func prepare(source: Dictionary) -> Dictionary:
	if not source.get("timeline_root") is String or not DirAccess.dir_exists_absolute(source.timeline_root):
		return _error("story_source_root_missing", str(source.get("timeline_root", "")), 1)
	for obsolete: String in ["entries", "challenges", "first_entry_id"]:
		if source.has(obsolete): return _error("story_duplicate_source", source.timeline_root, 1, obsolete)
	var paths: Array[String] = []
	_collect_paths(source.timeline_root, paths)
	paths.sort()
	var texts := {}
	for path: String in paths: texts[path] = FileAccess.get_file_as_string(path)
	return prepare_texts(source, texts)

static func _collect_paths(root: String, paths: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(root):
		if file.ends_with(".dtl"): paths.append(root.path_join(file))
	for folder: String in DirAccess.get_directories_at(root):
		_collect_paths(root.path_join(folder), paths)

static func prepare_texts(source: Dictionary, texts: Dictionary) -> Dictionary:
	for key: String in ["library_titles", "condition_labels"]:
		if not source.get(key, {}) is Dictionary:
			return _error("story_catalogue_invalid", str(source.get("timeline_root", "")), 1, key)
	var entries: Array = []
	var challenges: Array = []
	var memberships: Array = []
	var locations := {}
	var marker_locations := {}
	var challenge_locations := {}
	var first := ""
	var paths: Array = texts.keys()
	paths.sort()
	for path: String in paths:
		var text: String = texts[path]
		var timeline: DialogicTimeline = ADAPTER._parse_scene_programme_source(text)
		var source_lines := text.split("\n")
		var event_lines := {}
		for source_index: int in timeline.text_lines_indexed:
			if not source_lines[source_index].strip_edges().is_empty():
				var event_index: int = timeline.text_lines_indexed[source_index]
				if not event_lines.has(event_index): event_lines[event_index] = source_index + 1
		var label := ""
		var at_label := false
		var entry: Dictionary = {}
		var last_caption := ""
		var thought_pending := false
		for index: int in timeline.events.size():
			var event: DialogicEvent = timeline.events[index]
			var line: int = event_lines.get(index, 1)
			if event is DialogicLabelEvent:
				label = event.name
				at_label = true
				continue
			if event is DialogicCommentEvent:
				var comment: String = event.text.strip_edges()
				if comment == "self-talk": thought_pending = true
				var words := comment.replace("\t", " ").split(" ", false)
				if words.is_empty() or words[0] != "story": continue
				if words.size() < 3: return _error("story_directive_invalid", path, line)
				var operation: String = words[1]
				if operation == "entry":
					if not at_label or not EVENTS._id(label): return _error("story_entry_requires_label", path, line)
					if locations.has(label): return _error("story_entry_duplicate", path, line, label)
					if words.size() not in [3, 4] or not words[2].begins_with("day=") \
							or (words.size() == 4 and words[3] != "start"):
						return _error("story_entry_invalid", path, line)
					var day_text: String = words[2].trim_prefix("day=")
					if day_text not in ["1", "2", "3", "4", "5", "6", "7"]:
						return _error("story_day_invalid", path, line, day_text)
					if words.size() == 4:
						if not first.is_empty(): return _error("story_start_duplicate", path, line)
						first = label
					entry = {"entry_id": label, "path": path, "role": "scene", "story_day": day_text.to_int(), "markers": []}
					entries.append(entry)
					locations[label] = {"path": path, "line": line}
					last_caption = ""
					thought_pending = false
					continue
				if operation not in ["marker", "challenge", "passage"]:
					return _error("story_directive_unknown", path, line, operation)
				if entry.is_empty(): return _error("story_directive_without_entry", path, line)
				var payload_text: String = comment.substr(comment.find(operation) + operation.length()).strip_edges()
				var parsed := STRICT.parse_object(payload_text)
				if not parsed.ok: return _error("story_directive_json_invalid", path, line, str(parsed))
				var value: Dictionary = parsed.value
				match operation:
					"marker":
						if not at_label or marker_locations.has(label): return _error("story_marker_requires_unique_label", path, line, label)
						if value.size() != 2 or value.get("kind") not in MARKER_KINDS \
								or not EVENTS._scene_payload(value.kind, value.get("payload")):
							return _error("story_marker_invalid", path, line)
						if value.kind in ["passage.start", "passage.finish"] and not PASSAGE.valid_id(value.payload.passage_id):
							return _error("story_passage_id_invalid", path, line, value.payload.passage_id)
						if last_caption.is_empty() and value.kind != "passage.start":
							return _error("story_marker_without_caption", path, line, label)
						entry.markers.append({"marker_id": label, "label": label, "after_line_id": last_caption,
							"kind": value.kind, "payload": value.payload})
						marker_locations[label] = {"path": path, "line": line}
					"challenge":
						var required := ["challenge_id", "playable_marker_id", "end_marker_id", "board_profile_id", "targets"]
						if not EVENTS._keys(value, required): return _error("story_challenge_invalid", path, line)
						for key: String in required:
							if key != "targets" and not EVENTS._id(value[key]): return _error("story_challenge_invalid", path, line, key)
						if challenge_locations.has(value.challenge_id): return _error("story_challenge_duplicate", path, line, value.challenge_id)
						if not EVENTS._keys(value.targets, ["never_started", "unfinished", "won", "lost", "perfect"]):
							return _error("story_challenge_invalid", path, line, "targets")
						value["entry_id"] = entry.entry_id
						challenges.append(value)
						challenge_locations[value.challenge_id] = {"path": path, "line": line}
					"passage":
						memberships.append({"entry_id": entry.entry_id, "data": value, "path": path, "line": line})
				continue
			at_label = false
			if event is DialogicTextEvent:
				if not thought_pending:
					var parts := event.get_property_translation_key("text").split("/")
					last_caption = parts[1] if parts.size() == 3 else ""
				thought_pending = false
	if first.is_empty(): return _error("story_start_missing", str(source.get("timeline_root", "")), 1)
	var targets := {}
	for id: String in locations: targets["target." + id] = true
	for entry: Dictionary in entries:
		for marker: Dictionary in entry.markers:
			var referenced: Array = []
			for key: String in marker.payload:
				if key == "target_id" or key.ends_with("_target_id"): referenced.append(marker.payload[key])
			for option: Dictionary in marker.payload.get("options", []): referenced.append(option.target_id)
			for target: Variant in referenced:
				if not targets.has(target):
					var location: Dictionary = marker_locations[marker.marker_id]
					return _error("story_target_missing", location.path, location.line, str(target))
	for challenge: Dictionary in challenges:
		var location: Dictionary = challenge_locations[challenge.challenge_id]
		for target: Variant in challenge.targets.values():
			if not targets.has(target): return _error("story_target_missing", location.path, location.line, str(target))
		for marker_key: String in ["playable_marker_id", "end_marker_id"]:
			if not marker_locations.has(challenge[marker_key]):
				return _error("story_challenge_marker_missing", location.path, location.line, challenge[marker_key])
	var result := source.duplicate(true)
	result.merge({"entries": entries, "challenges": challenges, "first_entry_id": first, "library_memberships": memberships}, true)
	return {"ok": true, "value": result, "locations": locations}

static func _error(code: String, path: String, line: int, reference: String = "") -> Dictionary:
	return {"ok": false, "code": code, "path": path, "line": line, "reference": reference}
