extends "res://scripts/data/DialogicTimelineCatalog.gd"
## Test-only physical locator substitution. All vocabulary/version admission is
## still delegated to the production catalogue; only this exact pair has prose.

const PRODUCTION := preload("res://scripts/data/DialogicTimelineCatalog.gd")
const FIXTURE_PATH := "res://tests/fixtures/dialogic/solo_reading_rail.dtl"
const FIXTURE_ENTRIES := [
	"dating.solo.priscilla.day1.pre_challenge",
	"dating.solo.priscilla.day1.post_challenge",
]

static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var result: Dictionary = PRODUCTION.get_entry(entry_id, locale)
	if result.get("ok", false) and entry_id in FIXTURE_ENTRIES:
		result.value.path = FIXTURE_PATH
		result.value.label = entry_id
	return result
