extends "res://addons/gut/test.gd"
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PATH := "res://tests/fixtures/dialogic/_scene_compiler_cache_probe.dtl"
const COUNTED_PATH := "res://tests/fixtures/dialogic/_scene_compiler_cache_probe.counted_timeline"

class CountingTimelineLoader extends ResourceFormatLoader:
	var loads := 0

	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["counted_timeline"])

	func _get_resource_type(_path: String) -> String:
		return "Resource"

	func _handles_type(type: StringName) -> bool:
		return ClassDB.is_parent_class(type, "Resource")

	func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		loads += 1
		var text := FileAccess.get_file_as_string(path)
		if text.begins_with("not a timeline"): return Resource.new()
		var timeline := DialogicTimeline.new()
		timeline.from_text(text)
		return timeline

var _counting_loader: CountingTimelineLoader

func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

func after_each() -> void:
	DirAccess.remove_absolute(PATH)
	ADAPTER._scene_compile_cache.erase(PATH)
	DirAccess.remove_absolute(COUNTED_PATH)
	ADAPTER._scene_compile_cache.erase(COUNTED_PATH)
	if _counting_loader != null:
		ResourceLoader.remove_resource_format_loader(_counting_loader)
		_counting_loader = null

func _write_counted(text: String) -> void:
	var file := FileAccess.open(COUNTED_PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

func test_resource_type_is_checked_once_per_physical_revision_across_entries() -> void:
	_counting_loader = CountingTimelineLoader.new()
	ResourceLoader.add_resource_format_loader(_counting_loader, true)
	var original := "label first\n\\TEST first. #id:line.cache.one\nreturn\nlabel second\n\\TEST second. #id:line.cache.two\nreturn\n"
	_write_counted(original)
	var first: Dictionary = ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"])
	assert_true(first.ok, "supported timeline loaders are not restricted to the dtl extension")
	assert_true(ADAPTER.compile_scene_programme(COUNTED_PATH, "second", ["first", "second"]).ok)
	assert_eq(ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"]), first)
	assert_eq(_counting_loader.loads, 1, "separate entries and repeat calls share the physical type check")
	_write_counted(original.replace("TEST first.", "TEST changed."))
	var changed: Dictionary = ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"])
	assert_true(changed.ok)
	assert_eq(_counting_loader.loads, 2, "changed physical bytes require a new loader check")
	if first.ok and changed.ok: assert_ne(first.value.content_sha256, changed.value.content_sha256)
	_write_counted("not a timeline")
	var refused: Dictionary = ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"])
	assert_false(refused.ok)
	assert_eq(refused.code, &"scene_programme_unavailable")
	assert_eq(_counting_loader.loads, 3, "a replacement of the wrong resource type is rejected")

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
