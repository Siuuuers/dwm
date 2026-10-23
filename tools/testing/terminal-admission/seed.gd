extends SceneTree

func _initialize() -> void:
	# Match GUT discovery without instantiating a journey or its services.
	var expected := {"pair-next.gd": "test_genuine_ending_load_save",
		"replay.gd": "test_fresh_saved_ending_replay_and_new_game"}
	for filename: String in expected:
		var script: Script = load("res://.godot/ci/" + filename)
		var tests: Array[String] = []
		if script != null:
			for method: Dictionary in script.get_script_method_list():
				if str(method.name).begins_with("test_"): tests.append(str(method.name))
		if tests != [expected[filename]]:
			printerr("TERMINAL_DISCOVERY_FAILED ", filename, " ", tests)
			quit(1)
			return
	print("TERMINAL_DISCOVERY_COMPLETE one test per helper")
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
