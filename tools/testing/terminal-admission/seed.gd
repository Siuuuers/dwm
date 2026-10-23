extends SceneTree

func _initialize() -> void:
	var files: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/ci/terminal-root-hashes.json"))
	if files.size() != 40 or OS.get_environment("DWM_TEST_ROOT").is_empty():
		quit(1)
		return
	for relative: String in files:
		var destination := ProjectSettings.globalize_path("user://" + relative)
		var err := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if err != OK or DirAccess.copy_absolute(ProjectSettings.globalize_path("res://.godot/ci/terminal-root/" + relative), destination) != OK or FileAccess.get_sha256(destination) != files[relative]:
			printerr("TERMINAL_SEED_FAILED " + relative)
			quit(1)
			return
	print("TERMINAL_SEED_COMPLETE process_id=", OS.get_process_id(), " files=", files.size())
	quit(0)
