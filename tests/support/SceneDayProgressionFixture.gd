extends RefCounted
## Synthetic descriptors only; no production registration or authority.

static func document() -> Dictionary:
	var days := []
	for day in range(1, 8):
		var event_id := "TEST.day%d.complete" % day
		days.append({"day": day, "entry_id": "TEST.day%d" % day, "content_version": 1,
			"content_sha256": ("TEST.day%d.bytes" % day).sha256_text(), "terminal": {
				"event_id": event_id, "ordinal": 0, "predecessor": "", "label": "scene.marker." + event_id,
				"after_line_id": "TEST.day%d.last" % day,
				"successor_id": "TEST.day%d" % (day + 1) if day < 7 else "eligible_ending"}})
	return {"schema_version": 1, "days": days, "endings": [
		{"ending_id": "TEST.ending.a", "entry_id": "TEST.ending.a.entry", "content_version": 2,
			"content_sha256": "TEST.ending.a.bytes".sha256_text()},
		{"ending_id": "TEST.ending.b", "entry_id": "TEST.ending.b.entry", "content_version": 3,
			"content_sha256": "TEST.ending.b.bytes".sha256_text()}]}

static func envelope(document_value: Dictionary, day: int) -> Dictionary:
	var row: Dictionary = document_value.days[day - 1]
	var marker: Dictionary = row.terminal
	return {"schema_version": 1, "source": {"run_id": "TEST.run", "branch_id": "TEST.branch",
		"causal_day_instance": "TEST.causal.day%d" % day, "scene_occurrence": "TEST.scene.day%d" % day,
		"entry_id": row.entry_id, "content_version": row.content_version},
		"event_id": marker.event_id, "ordinal": marker.ordinal, "predecessor": marker.predecessor,
		"kind": "day.complete", "payload": {"source_day": day, "successor_id": marker.successor_id},
		"command_id": "TEST.command.day%d" % day, "issuer_receipt": {}, "playback_token": "TEST.playback"}

static func position(document_value: Dictionary, day: int) -> Dictionary:
	var row: Dictionary = document_value.days[day - 1]
	return {"content_sha256": row.content_sha256, "label": row.terminal.label,
		"after_line_id": row.terminal.after_line_id}
