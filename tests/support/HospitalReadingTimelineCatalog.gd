extends "res://scripts/data/DialogicTimelineCatalog.gd"
## Explicit test-only locator. All commands/frozen facts remain production-owned.
const PRODUCTION := preload("res://scripts/data/DialogicTimelineCatalog.gd")
const PRIOR := preload("res://tests/support/SoloReadingRailTimelineCatalog.gd")
const PATH := "res://tests/fixtures/dialogic/hospital_reading.dtl"
const ENTRIES := ["hospital.faint.day3", "dating.solo.priscilla.day4.pre_challenge",
	"dating.solo.priscilla.day4.post_challenge"]

static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var result: Dictionary = PRIOR.get_entry(entry_id, locale)
	if result.get("ok", false) and entry_id in ENTRIES:
		result.value.path = PATH
		result.value.label = entry_id
	return result
