extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
const ROOT_ENV := "DWM_TEST_ROOT"


func _create_with_root(wrapper: String, suite_id: String) -> Dictionary:
	var original: String = OS.get_environment(ROOT_ENV)
	OS.set_environment(ROOT_ENV, wrapper)
	var result: Dictionary = TEMPORARY_STORAGE.create(suite_id)
	OS.set_environment(ROOT_ENV, original)
	return result


func _runner_root() -> String:
	var wrapper: String = OS.get_environment(ROOT_ENV)
	assert_false(wrapper.strip_edges().is_empty(), "The isolated runner must supply DWM_TEST_ROOT")
	return wrapper


func test_native_windows_wrapper_is_normalized_and_contained() -> void:
	var wrapper: String = _runner_root()
	if wrapper.is_empty():
		return
	if OS.get_name() != "Windows":
		return
	var native_wrapper: String = wrapper.replace("/", "\\")
	var result: Dictionary = _create_with_root(native_wrapper, "temporary-storage-native")
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return
	var canonical_wrapper: String = native_wrapper.replace("\\", "/").simplify_path().trim_suffix("/")
	var created: String = result["value"]
	assert_true(created.begins_with(canonical_wrapper + "/"), created)
	assert_false(created.contains("\\"), "Returned paths use one separator style")
	assert_true(DirAccess.dir_exists_absolute(created))


func test_forward_slash_wrapper_is_equivalently_contained() -> void:
	var wrapper: String = _runner_root()
	if wrapper.is_empty():
		return
	var forward_wrapper: String = wrapper.replace("\\", "/")
	var result: Dictionary = _create_with_root(forward_wrapper, "temporary-storage-forward")
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return
	var canonical_wrapper: String = forward_wrapper.simplify_path().trim_suffix("/")
	var created: String = result["value"]
	assert_true(created.begins_with(canonical_wrapper + "/"), created)
	assert_false(created.contains("\\"), "Returned paths use one separator style")
	assert_true(DirAccess.dir_exists_absolute(created))


func test_missing_root_is_rejected_and_environment_restored() -> void:
	var original: String = _runner_root()
	if original.is_empty():
		return
	var result: Dictionary = _create_with_root("", "temporary-storage-missing")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"test_root_missing")
	assert_eq(OS.get_environment(ROOT_ENV), original)


func test_parent_traversal_to_wrapper_is_rejected_without_creating_outside_it() -> void:
	var wrapper: String = _runner_root()
	if wrapper.is_empty():
		return
	# From wrapper / pid / ordinal, ../.. resolves to the wrapper itself.
	var result: Dictionary = _create_with_root(wrapper.replace("/", "\\") if OS.get_name() == "Windows" else wrapper, "../..")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"test_root_escape")
	assert_eq(OS.get_environment(ROOT_ENV), wrapper)
