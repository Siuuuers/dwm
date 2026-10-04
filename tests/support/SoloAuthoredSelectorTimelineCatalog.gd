extends "res://scripts/data/DialogicTimelineCatalog.gd"
## Test-only physical locator. The production catalogue still admits the exact
## semantic entries; the reading programme supplies its selected native label.

const PRODUCTION := preload("res://scripts/data/DialogicTimelineCatalog.gd")
const FIXTURE_PATH := "res://tests/fixtures/dialogic/solo_authored_selector.dtl"
const FIXTURE_ENTRIES := [
	"dating.solo.priscilla.day1.pre_challenge",
	"dating.solo.priscilla.day1.post_challenge",
]

static func get_entry(entry_id: String, locale: String = "") -> Dictionary:
	var result: Dictionary = PRODUCTION.get_entry(entry_id, locale)
	if result.get("ok", false) and entry_id in FIXTURE_ENTRIES:
		result.value.path = FIXTURE_PATH
		# This semantic label deliberately has no physical fixture programme.
		# Successful playback therefore proves the Bridge uses its selected label.
		result.value.label = entry_id
	return result
