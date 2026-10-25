extends RefCounted
## Display-only reconstruction of the current authored day. This never dispatches
## controls, creates admissions, publishes captions, or changes gameplay facts.
const EVENTS := preload("res://scripts/domain/narrative/SceneEventContract.gd")

static func project(bundle: Dictionary, nodes: Dictionary, entry_id: String, program_index: int,
		choices: Dictionary, outcomes: Dictionary, first_target_id: String = "") -> Dictionary:
	var checked := EVENTS.validate_story_days(bundle.get("scene_programme", {}))
	if not checked.ok or checked.value.is_empty() or not checked.value.has(entry_id):
		return _fail(&"reading_history_day_unavailable")
	var days: Dictionary = checked.value
	if not nodes.has(entry_id) or program_index < 0 or program_index >= nodes[entry_id].size():
		return _fail(&"reading_history_position_invalid")
	var targets := {}
	for row: Dictionary in bundle.targets: targets[row.target_id] = row.target
	var challenges := {}
	for row: Dictionary in bundle.challenges: challenges[row.challenge_id] = row
	var markers := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		for marker: Dictionary in programme.markers: markers[marker.marker_id] = marker
	var lines := {}
	for entry: Dictionary in bundle.caption_registry.entries:
		for line: Dictionary in entry.lines:
			lines[line.line_id] = {"entry_id": entry.entry_id, "line": line}
	var start := _day_start(bundle, days, int(days[entry_id]), targets, challenges, first_target_id)
	if not start.ok: return start
	var current: String = start.value
	var index := 0
	var visited := {}
	var captions: Array[Dictionary] = []
	while true:
		if not nodes.has(current) or days.get(current) != days[entry_id] \
				or index < 0 or index >= nodes[current].size():
			return _fail(&"reading_history_position_unreachable")
		var key := "%s:%d" % [current, index]
		if visited.has(key): return _fail(&"reading_history_cycle")
		visited[key] = true
		var node: Dictionary = nodes[current][index]
		if node.kind == "caption":
			if not lines.has(node.line_id) or lines[node.line_id].entry_id != current:
				return _fail(&"reading_history_line_invalid")
			var line: Dictionary = lines[node.line_id].line
			captions.append({"line_id": line.line_id, "entry_id": current, "beat_id": line.beat_id,
				"text": line.text, "publication_id": "history:" + line.line_id})
		if current == entry_id and index == program_index:
			if node.kind not in ["caption", "control", "completion"] or captions.is_empty():
				return _fail(&"reading_history_position_invalid")
			return {"ok": true, "value": {"captions": captions, "day": days[entry_id]}}
		if node.kind in ["caption", "jump"]:
			index = int(node.next)
			continue
		if node.kind != "control" or not markers.has(node.marker_id):
			return _fail(&"reading_history_position_unreachable")
		var marker: Dictionary = markers[node.marker_id]
		if marker.kind == "challenge.playable":
			index += 1
			continue
		var selected := _select_target(marker, choices, outcomes, challenges)
		if not selected.ok: return selected
		if not targets.has(selected.value): return _fail(&"reading_history_target_invalid")
		var target: Dictionary = targets[selected.value]
		if target.kind != "scene" or target.label != target.entry_id:
			return _fail(&"reading_history_target_unsupported")
		current = target.entry_id
		index = 0
	return _fail(&"reading_history_position_unreachable")

static func _select_target(marker: Dictionary, choices: Dictionary, outcomes: Dictionary,
		challenges: Dictionary) -> Dictionary:
	var payload: Dictionary = marker.payload
	match marker.kind:
		"scene.transition": return {"ok": true, "value": payload.target_id}
		"thought.pass", "thought.options":
			if not choices.has(payload.opportunity_id): return _fail(&"reading_history_choice_missing")
			var choice: Variant = choices[payload.opportunity_id]
			if choice == "pass": return {"ok": true, "value": payload.pass_target_id}
			if marker.kind == "thought.pass":
				return {"ok": true, "value": payload.yes_target_id} if choice == "yes" else _fail(&"reading_history_choice_invalid")
			for option: Dictionary in payload.options:
				if choice == option.choice_id: return {"ok": true, "value": option.target_id}
			return _fail(&"reading_history_choice_invalid")
		"challenge.end", "challenge.recall":
			var found := ""
			for row: Variant in outcomes.values():
				if not row is Dictionary or row.get("challenge_id") != payload.challenge_id: continue
				if not found.is_empty(): return _fail(&"reading_history_outcome_ambiguous")
				if row.get("outcome") not in ["never_started", "unfinished", "won", "lost", "perfect"]:
					return _fail(&"reading_history_outcome_invalid")
				found = row.outcome
			if found.is_empty(): return _fail(&"reading_history_outcome_missing")
			if marker.kind == "challenge.recall":
				return {"ok": true, "value": payload[found + "_target_id"]}
			if not challenges.has(payload.challenge_id): return _fail(&"reading_history_challenge_invalid")
			return {"ok": true, "value": challenges[payload.challenge_id].targets[found]}
	return _fail(&"reading_history_control_unsupported")

static func _day_start(bundle: Dictionary, days: Dictionary, day: int, targets: Dictionary,
		challenges: Dictionary, first_target_id: String) -> Dictionary:
	var incoming := {}
	var cross_day := {}
	for programme: Dictionary in bundle.scene_programme.entries:
		for marker: Dictionary in programme.markers:
			var ids: Array = []
			for key: String in marker.payload:
				if key.ends_with("target_id"): ids.append(marker.payload[key])
			for option: Dictionary in marker.payload.get("options", []): ids.append(option.target_id)
			if marker.kind == "challenge.end" and challenges.has(marker.payload.challenge_id):
				ids.append_array(challenges[marker.payload.challenge_id].targets.values())
			for id: String in ids:
				if not targets.has(id): return _fail(&"reading_history_target_invalid")
				var target: Dictionary = targets[id]
				if target.kind != "scene" or days.get(target.entry_id) != day: continue
				if days[programme.entry_id] == day: incoming[target.entry_id] = true
				else: cross_day[target.entry_id] = true
	if cross_day.size() == 1: return {"ok": true, "value": cross_day.keys()[0]}
	if cross_day.size() > 1: return _fail(&"reading_history_day_ambiguous")
	if not first_target_id.is_empty() and targets.has(first_target_id):
		var first: Dictionary = targets[first_target_id]
		if first.kind == "scene" and days.get(first.entry_id) == day:
			return {"ok": true, "value": first.entry_id}
	var roots: Array[String] = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		if entry.role == "scene" and days.get(entry.entry_id) == day and not incoming.has(entry.entry_id):
			roots.append(entry.entry_id)
	return {"ok": true, "value": roots[0]} if roots.size() == 1 else _fail(&"reading_history_day_ambiguous")

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
