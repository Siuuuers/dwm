extends "res://tests/support/ScenePlayableFixture.gd"
## TEST-only two-day registration; production owners and normal scene.transition.
func _registration_bundle() -> Dictionary:
	var built: Dictionary = super._registration_bundle()
	if not built.ok: return built
	var original: Dictionary = BASE_READING.JSON_READER.parse_object(FileAccess.get_file_as_string(BASE_READING.REGISTRATION))
	if not original.ok: return original
	for key: String in ["entry_manifest", "ids_registry", "scene_programme", "targets"]:
		built.value[key] = original.value[key].duplicate(true)
	built.value.challenges = []
	built.value.scene_programme["story_days"] = {"scene.test.b": 1, "scene.test.a": 2, "contact.test.a": 2}
	return built
