extends "res://scripts/data/DialogicTimelineCatalog.gd"
const PRODUCTION := preload("res://scripts/data/DialogicTimelineCatalog.gd")
static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var result: Dictionary = PRODUCTION.get_entry(entry_id, locale)
	if result.get("ok", false) and entry_id in ["ending.sylvia.special.full", "ending.sylvia.dark"]:
		result.value.path = "res://tests/fixtures/dialogic/ending_reading.dtl"
		result.value.label = entry_id
	return result
