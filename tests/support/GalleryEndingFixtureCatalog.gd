extends RefCounted

## Synthetic historical availability for Gallery layout tests only.
## Same closed mapping as render_gallery_version_register.FixtureEntryCatalog;
## never configures production registration or makes an unreached record reachable.
static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	if locale != "en" or entry_id not in ["ending.alone.normal", "ending.alone.dark_mode"]:
		return {"ok": false, "code": &"fixture_entry_unavailable"}
	return {"ok": true, "value": {"path": "res://dialogic/timelines/en/ending/alone.dtl",
		"label": entry_id}}
