extends RefCounted
## Explicit test prose only. Real ending owners supply frozen facts and completions.
const PATH := "res://tests/fixtures/dialogic/ending_reading_catalogue.json"
static func catalogue() -> Dictionary:
	return preload("res://scripts/validation/StrictJson.gd").parse_object(FileAccess.get_file_as_string(PATH)).value
