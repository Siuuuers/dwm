extends RefCounted
## Encounter-only History display and route admission for current-content saves.
## Neither operation dispatches controls or publishes read/gameplay facts.
const EVENTS := preload("res://scripts/domain/narrative/SceneEventContract.gd")

## Only recorded encounters appear. Current wording is a display projection,
## never a publication or a global read witness.
static func project_encountered(bundle: Dictionary, sections: Array) -> Dictionary:
	var lines := {}
	for entry: Dictionary in bundle.caption_registry.entries:
		for line: Dictionary in entry.lines:
			lines[line.line_id] = {"entry_id": entry.entry_id, "line": line}
	var captions: Array[Dictionary] = []
	var seen := {}
	for section: Array in sections:
		for line_id: String in section:
			if not lines.has(line_id) or seen.has(line_id): continue
			seen[line_id] = true
			var row: Dictionary = lines[line_id]
			captions.append({"line_id": line_id, "entry_id": row.entry_id, "beat_id": row.line.beat_id,
				"text": row.line.text, "publication_id": "history:" + line_id})
	return {"ok": true, "value": {"captions": captions}}

## Route admission for content migration. Known decisions restrict reachable
## entries; an absent newly-authored decision is not a retroactive prerequisite.
static func current_day_route(bundle: Dictionary, day: int, choices: Dictionary, outcomes: Dictionary) -> Dictionary:
	var checked := EVENTS.validate_story_days(bundle.get("scene_programme", {}))
	if not checked.ok or checked.value.is_empty(): return _fail(&"reading_history_day_unavailable")
	var days: Dictionary = checked.value
	var targets := {}
	for row: Dictionary in bundle.targets: targets[row.target_id] = row.target
	var challenges := {}
	for row: Dictionary in bundle.challenges: challenges[row.challenge_id] = row
	var start := _day_start(bundle, days, day, targets, challenges, "")
	if not start.ok: return start
	var entries := {}
	var pending: Array = [start.value]
	while not pending.is_empty():
		var entry_id: String = pending.pop_back()
		if entries.has(entry_id): continue
		entries[entry_id] = true
		for programme: Dictionary in bundle.scene_programme.entries:
			if programme.entry_id != entry_id: continue
			for marker: Dictionary in programme.markers:
				if marker.kind not in ["scene.transition", "thought.pass", "thought.options", "challenge.end", "challenge.recall"]: continue
				var selected := _select_target(marker, choices, outcomes, challenges)
				var ids: Array = []
				if selected.ok: ids.append(selected.value)
				elif selected.code in [&"reading_history_choice_missing", &"reading_history_outcome_missing"]:
					for key: String in marker.payload:
						if key.ends_with("target_id"): ids.append(marker.payload[key])
					for option: Dictionary in marker.payload.get("options", []): ids.append(option.target_id)
					if marker.kind == "challenge.end" and challenges.has(marker.payload.challenge_id):
						ids.append_array(challenges[marker.payload.challenge_id].targets.values())
				else: continue
				for target_id: String in ids:
					if targets.has(target_id) and targets[target_id].kind == "scene" \
							and days.get(targets[target_id].entry_id) == day:
						pending.append(targets[target_id].entry_id)
	return {"ok": true, "value": {"start_entry": start.value, "entries": entries}}

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
