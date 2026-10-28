extends SceneTree
## Run on the cloud Godot runner before focused tests/export. Native compiler owns hashes.
const TEMPLATES := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const REGISTRATION_PATH := "res://data/manifests/scene_story_registration.json"
const LIBRARY_PATH := "res://data/manifests/dialogue_library_registration.json"

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
	if not _write(REGISTRATION_PATH, registration):
		quit(1)
		return
	if not _write(LIBRARY_PATH, prepared.value.dialogue_library):
		quit(1)
		return
	print("SEVEN_DAY_REGISTRATION_EXPORTED first_target_id=" + prepared.value.first_target_id)
	quit(0)

func _validate_export() -> void:
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var installed: Dictionary = manifest.scene_registration()
	if not installed.ok:
		push_error(str(installed))
		quit(1)
		return
	var library: Dictionary = preload("res://scripts/narrative/DialogueLibraryCatalogue.gd").ensure_loaded()
	if not library.ok:
		push_error(str(library))
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
