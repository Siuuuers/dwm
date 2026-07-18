extends "res://addons/gut/test.gd"

const STOP_HELPER := "res://tools/tooling/stop_repository_codegraph_daemon.cjs"

func test_repository_codegraph_directory_is_absent() -> void:
	assert_false(
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path("res://.codegraph")
		)
	)

func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_string(text)
	file.close()

func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _node_path() -> String:
	var configured := OS.get_environment("NODE_EXE")
	return configured if not configured.is_empty() else "C:\\Program Files\\nodejs\\node.exe"

func test_stop_helper_rejects_hash_drift_and_handles_absent_lock() -> void:
	assert_true(FileAccess.file_exists(STOP_HELPER), "stop helper must exist")
	if not FileAccess.file_exists(STOP_HELPER): return
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("codegraph-helper")
	var module := root.path_join("package/daemon-registry.js")
	var repository := root.path_join("repository")
	_write(module, "module.exports.stopDaemonAt = async () => ({root:'x',pid:null,outcome:'no-daemon'});\n")
	_write(repository.path_join("project.godot"), "config_version=5\n")
	var output: Array = []
	var mismatch_exit := OS.execute(_node_path(), [ProjectSettings.globalize_path(STOP_HELPER), module, "0".repeat(64), repository], output, true)
	assert_ne(mismatch_exit, 0)
	assert_true("\n".join(output).contains("MODULE_SHA256_DRIFT"))
	output.clear()
	var absent_exit := OS.execute(_node_path(), [ProjectSettings.globalize_path(STOP_HELPER), module, _sha256(module), repository], output, true)
	assert_eq(absent_exit, 0, "\n".join(output))
	var lines := "\n".join(output).strip_edges().split("\n", false)
	assert_eq(lines.size(), 1)
	var parsed: Variant = JSON.parse_string(lines[0])
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	if typeof(parsed) == TYPE_DICTIONARY:
		assert_eq(parsed.pid, null)
		assert_eq(parsed.outcome, "absent")
