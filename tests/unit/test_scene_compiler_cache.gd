extends "res://addons/gut/test.gd"
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PATH := "res://tests/fixtures/dialogic/_scene_compiler_cache_probe.dtl"

func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

func after_each() -> void:
	DirAccess.remove_absolute(PATH)
	ADAPTER._scene_compile_cache.erase(PATH)

func test_compiled_values_are_detached_and_follow_physical_source_and_arguments() -> void:
	var original := "label cache\n\\TEST first. #id:line.cache.one\nreturn\n"
	_write(original)
	var first: Dictionary = ADAPTER.compile_scene_programme(PATH, "cache", ["cache"])
	assert_true(first.ok)
	if not first.ok: return
	var pristine: Dictionary = first.duplicate(true)
	first.value.nodes.clear()
	assert_eq(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]), pristine,
		"caller mutation cannot poison a later proof")
	var changed_markers: Dictionary = ADAPTER.compile_scene_programme(PATH, "cache", ["cache"],
		[{"label": "missing", "marker_id": "missing"}])
	assert_false(changed_markers.ok, "marker arguments are not interchangeable")
	assert_false(ADAPTER.compile_scene_programme(PATH, "cache", []).ok,
		"callable labels still authorize the selected entry")
	_write(original.replace("TEST first.", "TEST changed."))
	var changed: Dictionary = ADAPTER.compile_scene_programme(PATH, "cache", ["cache"])
	assert_true(changed.ok)
	if not changed.ok: return
	assert_ne(changed.value.content_sha256, pristine.value.content_sha256)
	assert_ne(changed.value.program_sha256, pristine.value.program_sha256,
		"changed bytes compile fresh even while ResourceLoader retains the old resource")
	_write("label cache\n\\TEST missing stable id.\nreturn\n")
	assert_false(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]).ok,
		"malformed replacement cannot reuse previously valid output")
	_write(original)
	assert_eq(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]), pristine)
	DirAccess.remove_absolute(PATH)
	assert_false(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]).ok,
		"deleted source cannot reuse a valid cache")
