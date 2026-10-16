@tool
extends EditorPlugin
## These three files became normal-story dependencies before export qualification.
## Keep their logical paths: changing the registration would invalidate saved readers.
## The broad tests/* exclusion still removes all test code and unrelated fixtures.

class StoryExport extends EditorExportPlugin:
	const RESOURCES := [
		"res://tests/fixtures/dialogic/scene_seven_day_linear.dtl",
		"res://tests/fixtures/dialogic/scene_seven_day_ending.dtl",
		"res://tests/templates/scene_sequence/seven_day_order.json",
	]

	func _get_name() -> String:
		return "DwmRegisteredStory"

	func _export_begin(_features: PackedStringArray, _is_debug: bool,
			_path: String, _flags: int) -> void:
		for path: String in RESOURCES:
			var bytes := FileAccess.get_file_as_bytes(path)
			if bytes.is_empty():
				push_error("Registered story export resource missing: " + path)
				return
			add_file(path, bytes, false)

var _story_export: StoryExport

func _enter_tree() -> void:
	_story_export = StoryExport.new()
	add_export_plugin(_story_export)

func _exit_tree() -> void:
	remove_export_plugin(_story_export)
	_story_export = null
