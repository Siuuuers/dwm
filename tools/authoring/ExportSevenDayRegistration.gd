extends SceneTree
## Run on the cloud Godot runner before focused tests/export. Native compiler owns hashes.
const TEMPLATES := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const REGISTRATION_PATH := "res://data/manifests/scene_story_registration.json"
const ENDING_CATALOGUE_PATH := "res://data/manifests/scene_ending_reading_catalogue.json"

func _initialize() -> void:
	var prepared: Dictionary = TEMPLATES.prepare()
	if not prepared.get("ok", false):
		push_error(str(prepared))
		quit(1)
		return
	var registration: Dictionary = prepared.value.registration
	var ending_lines: Array = []
	for row: Dictionary in registration.caption_registry.entries:
		if row.entry_id == TEMPLATES.ENDING_ID: ending_lines = row.lines.duplicate(true)
	var catalogue := {"kind": "ending_reading_catalogue", "schema_version": 1,
		"entries": [{"entry_id": TEMPLATES.ENDING_ID, "content_version": 1, "lines": ending_lines}]}
	var reading := preload("res://scripts/narrative/SoloReadingSession.gd").new()
	var admitted: Dictionary = reading.configure(catalogue)
	if not admitted.ok:
		push_error(str(admitted))
		quit(1)
		return
	if not _write(REGISTRATION_PATH, registration) or not _write(ENDING_CATALOGUE_PATH, catalogue):
		quit(1)
		return
	print("SEVEN_DAY_REGISTRATION_EXPORTED first_target_id=" + prepared.value.first_target_id)
	quit(0)

func _write(path: String, value: Dictionary) -> bool:
	var encoded: Dictionary = WRITER.stringify(value)
	if not encoded.ok:
		push_error(str(encoded))
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		return false
	file.store_string(str(encoded.value) + "\n")
	file.close()
	return true
