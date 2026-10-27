extends RefCounted
## Encounter-only History display. This does not dispatch controls or publish facts.

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
