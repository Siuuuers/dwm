extends SceneTree
## Test-only short registration. The caller restores both installed files after use.
const TEMPLATES := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _initialize() -> void:
	var prepared: Dictionary = TEMPLATES.prepare()
	if not prepared.get("ok", false):
		push_error(str(prepared))
		quit(1)
		return
	var registration: Dictionary = prepared.value.registration
	var lines: Array = []
	for row: Dictionary in registration.caption_registry.entries:
		if row.entry_id == TEMPLATES.ENDING_ID: lines = row.lines.duplicate(true)
	var catalogue := {"kind": "ending_reading_catalogue", "schema_version": 1,
		"entries": [{"entry_id": TEMPLATES.ENDING_ID, "content_version": 1, "lines": lines}]}
	for item: Array in [["scene_story_registration.json", registration], ["scene_ending_reading_catalogue.json", catalogue]]:
		var encoded: Dictionary = WRITER.stringify(item[1])
		if not encoded.ok:
			push_error(str(encoded))
			quit(1)
			return
		var file := FileAccess.open("res://data/manifests/" + item[0], FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(str(encoded.value) + "\n")
		file.close()
	print("SHORT_TERMINAL_FIXTURE_EXPORTED")
	quit(0)
