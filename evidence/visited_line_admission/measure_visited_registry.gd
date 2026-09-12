extends SceneTree
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for sample: int in range(3):
		var began := Time.get_ticks_usec()
		var entries: Dictionary = MANIFEST.load_default()
		var entry_validation: Dictionary = MANIFEST.validate_document(entries.value)
		var entries_done := Time.get_ticks_usec()
		var ids: Dictionary = MANIFEST.load_ids_default()
		var id_validation: Dictionary = MANIFEST.validate_ids_document(ids.value)
		var ids_done := Time.get_ticks_usec()
		var profile: Node = PROFILE.new()
		var configured: Dictionary = profile.configure_line_registry(ids.value)
		var finished := Time.get_ticks_usec()
		profile.free()
		if not entry_validation.get("ok", false) or not id_validation.get("ok", false) or not configured.get("ok", false):
			push_error("VISITED_REGISTRY_TIMING_INVALID")
			quit(1)
			return
		print("VISITED_REGISTRY_TIMING ", JSON.stringify({"sample":sample+1,
			"entries_load_validate_ms":(entries_done-began)/1000.0,
			"ids_load_validate_ms":(ids_done-entries_done)/1000.0,
			"configure_ms":(finished-ids_done)/1000.0,
			"total_ms":(finished-began)/1000.0}))
	quit(0)
