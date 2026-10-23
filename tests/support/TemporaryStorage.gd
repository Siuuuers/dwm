class_name TemporaryStorage
extends RefCounted

static var _counter := 0

static func create(suite_id: String) -> Dictionary:
	var wrapper_root := OS.get_environment("DWM_TEST_ROOT")
	if wrapper_root.strip_edges().is_empty():
		return {"ok": false, "code": &"test_root_missing", "message": "DWM_TEST_ROOT is required"}
	_counter += 1
	var root := wrapper_root.path_join(str(OS.get_process_id())).path_join(str(_counter)).path_join(suite_id)
	var canonical_wrapper := wrapper_root.replace("\\", "/").simplify_path().trim_suffix("/")
	var canonical_root := root.replace("\\", "/").simplify_path().trim_suffix("/")
	if not canonical_root.begins_with(canonical_wrapper + "/"):
		return {"ok": false, "code": &"test_root_escape", "message": canonical_root}
	var production := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	if canonical_root.nocasecmp_to(production) == 0:
		return {"ok": false, "code": &"production_root_forbidden", "message": canonical_root}
	var mkdir_error := DirAccess.make_dir_recursive_absolute(canonical_root)
	if mkdir_error != OK:
		return {"ok": false, "code": &"create_directory_failed", "message": error_string(mkdir_error)}
	return {"ok": true, "value": canonical_root}
