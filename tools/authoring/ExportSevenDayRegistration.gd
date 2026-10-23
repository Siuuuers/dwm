extends SceneTree
## Run on the cloud Godot runner before focused tests/export. Native compiler owns hashes.
const TEMPLATES := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const REGISTRATION_PATH := "res://data/manifests/scene_story_registration.json"
const ENDING_CATALOGUE_PATH := "res://data/manifests/scene_ending_reading_catalogue.json"

func _initialize() -> void:
	# Registry selection is immutable. Validate in a fresh normal-story process,
	# after the generation process has written the previously absent registration.
	if OS.get_cmdline_user_args().has("--validate-seven-day-export"):
		_validate_export()
		return
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
	if not _write(REGISTRATION_PATH, registration) or not _write(ENDING_CATALOGUE_PATH, catalogue):
		quit(1)
		return
	print("SEVEN_DAY_REGISTRATION_EXPORTED first_target_id=" + prepared.value.first_target_id)
	quit(0)

func _validate_export() -> void:
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var installed: Dictionary = manifest.scene_registration()
	var parsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string(ENDING_CATALOGUE_PATH))
	if not installed.ok or not parsed.ok:
		push_error(str(installed) + " " + str(parsed))
		quit(1)
		return
	var reading := preload("res://scripts/narrative/SoloReadingSession.gd").new()
	var admitted: Dictionary = reading.configure(parsed.value)
	if not admitted.ok:
		push_error(str(admitted))
		quit(1)
		return
	print("SEVEN_DAY_EXPORT_VALIDATED first_target_id=" + manifest.first_target_id())
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
