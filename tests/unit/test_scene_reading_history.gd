extends "res://addons/gut/test.gd"
## Encountered History stays detached from shipped content and read facts.
const HISTORY := preload("res://scripts/narrative/SceneReadingHistory.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
var _bundle: Dictionary
var _lines := {}

func before_all() -> void:
	_bundle = STRICT.parse_object(FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json")).value
	for entry: Dictionary in _bundle.caption_registry.entries: _lines[entry.entry_id] = entry.lines

func test_encounter_projection_is_detached_and_never_backfills_or_duplicates() -> void:
	var before: Dictionary = _bundle.duplicate(true)
	var first: String = _lines.Day1[0].line_id
	var third: String = _lines.Day1[2].line_id
	var result := HISTORY.project_encountered(_bundle, [[first], ["deleted.line", third, third]])
	assert_eq(result.value.captions.map(func(row: Dictionary) -> String: return row.line_id), [first, third])
	assert_eq(result.value.captions[1].text, _lines.Day1[2].text)
	assert_true(result.value.captions.all(func(row: Dictionary) -> bool:
		return row.publication_id == "history:" + row.line_id))
	result.value.captions[0].text = "caller mutation"
	assert_eq(_bundle, before)
