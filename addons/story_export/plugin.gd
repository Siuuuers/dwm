@tool
extends EditorPlugin
## Package only the seven active template DTLs and their explicit order.
## The broad tests/* exclusion continues to remove unrelated fixtures and test code.

class StoryExport extends EditorExportPlugin:
	const RESOURCES := [
		# Scene admission authenticates the original OGG bytes in exported builds.
		"res://audio/bgm/story_theme.ogg",
		"res://tests/fixtures/dialogic/Day1.dtl",
		"res://tests/fixtures/dialogic/Day2.dtl",
		"res://tests/fixtures/dialogic/Day3.dtl",
		"res://tests/fixtures/dialogic/Day4.dtl",
		"res://tests/fixtures/dialogic/Day5.dtl",
		"res://tests/fixtures/dialogic/Day6.dtl",
		"res://tests/fixtures/dialogic/Day7.dtl",
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
