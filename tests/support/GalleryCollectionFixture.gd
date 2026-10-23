extends "res://scripts/data/DialogicTimelineCatalog.gd"
## Isolated rendered TEST fixture. Shared historical ending fixtures are untouched.
const PRODUCTION := preload("res://scripts/data/DialogicTimelineCatalog.gd")
const PATH := "res://tests/fixtures/dialogic/gallery_collection_catalogue.json"

static func catalogue() -> Dictionary:
	return preload("res://scripts/validation/StrictJson.gd").parse_object(FileAccess.get_file_as_string(PATH)).value

static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var result: Dictionary = PRODUCTION.get_entry(entry_id, locale)
	if result.get("ok", false) and entry_id == "ending.alone.normal":
		result = result.duplicate(true)
		result.value.path = "res://tests/fixtures/dialogic/gallery_collection.dtl"
		result.value.label = entry_id
	return result
