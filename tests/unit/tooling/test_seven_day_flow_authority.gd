extends "res://addons/gut/test.gd"

const SPEC_PATH := "res://docs/design/2026-08-07-seven-day-dialogic-flow-design.md"
const PRODUCTION_MAP_PATH := "res://story/03-seven-day-production-map.md"
const LIBRARY_PATH := "res://story/library/03-seven-day-plot-material-library.md"
const STORY_BIBLE_PATH := "res://story/01-core-story-bible.md"
const CANON_AMENDMENTS_PATH := "res://story/05-canon-amendments-2026-07-19.md"
const DESIGN_README_PATH := "res://docs/design/README.md"
const SPEC_FILE_NAME := "2026-08-07-seven-day-dialogic-flow-design.md"

const RETIRED_HEADINGS: Array[String] = [
	"The Programme Table",
	"The Borrowed Book",
	"The Public Question",
	"Borrowed Gravity",
	"Exactly on Time",
	"Three Versions of the Sky",
]

const AUTHORITY_LADDER: Array[String] = [
	"approved seven-day specification",
	"nonconflicting story canon",
	"derived plot-neutral production map",
	"noncanonical idea library",
	"recovered historical reference",
]


const SPEC_REGISTRY_PATH := "docs/design/2026-08-07-seven-day-dialogic-flow-design.md"


func test_written_spec_is_approved_and_implementation_is_authorized() -> void:
	var registry_result := DesignAuthorityRegistry.new().validate()
	assert_true(bool(registry_result.get("ok", false)), "the design authority registry must validate: " + JSON.stringify(registry_result.get("errors", [])))
	var spec_fields := {}
	var matches := 0
	for record: Dictionary in registry_result.get("records", []):
		if record.get("path") == SPEC_REGISTRY_PATH:
			matches += 1
			spec_fields = record.get("fields", {})
	assert_eq(matches, 1, "the approved specification must be registered exactly once")
	assert_eq(spec_fields.get("written_spec_status"), "approved", "written_spec_status must stay approved")
	assert_eq(spec_fields.get("implementation_authorized"), true, "implementation_authorized must be true after the separate explicit maintainer authorization")
	assert_eq(spec_fields.get("implementation_plan_status"), "approved", "implementation_plan_status must be approved, which the registry requires whenever implementation is authorized")
	var raw_text := FileAccess.get_file_as_string(SPEC_PATH).replace("\r\n", "\n").replace("\r", "\n")
	assert_true(raw_text.contains("\nself_review_status: passed\n"), "self_review_status must stay passed")


func test_production_map_contains_no_named_plot_cards() -> void:
	var text := FileAccess.get_file_as_string(PRODUCTION_MAP_PATH)
	assert_false(text.is_empty(), "story/03 must exist and be readable")
	for retired_heading: String in RETIRED_HEADINGS:
		assert_false(text.contains(retired_heading), "story/03 must not name the retired plot card: " + retired_heading)


func test_plot_library_is_explicitly_noncanonical() -> void:
	assert_true(FileAccess.file_exists(LIBRARY_PATH), "the plot material library must exist at " + LIBRARY_PATH)
	var text := FileAccess.get_file_as_string(LIBRARY_PATH)
	assert_true(text.contains("noncanonical"), "the library must declare itself noncanonical")
	for retired_heading: String in RETIRED_HEADINGS:
		assert_true(text.contains(retired_heading), "the library must preserve the retired plot card verbatim: " + retired_heading)


func test_story_bible_links_the_approved_spec_in_a_supersession_notice() -> void:
	var text := FileAccess.get_file_as_string(STORY_BIBLE_PATH)
	assert_false(text.is_empty(), "story/01 must exist and be readable")
	assert_true(text.contains(SPEC_FILE_NAME), "story/01 must link the approved specification by file name")
	assert_true(text.to_lower().contains("supersession"), "story/01 must carry a bounded mechanical supersession notice")


func test_canon_amendments_link_the_approved_spec_in_a_supersession_notice() -> void:
	var text := FileAccess.get_file_as_string(CANON_AMENDMENTS_PATH)
	assert_false(text.is_empty(), "story/05 must exist and be readable")
	assert_true(text.contains(SPEC_FILE_NAME), "story/05 must link the approved specification by file name")
	assert_true(text.to_lower().contains("supersession"), "story/05 must carry a bounded mechanical supersession notice")


func test_design_readme_lists_the_authority_ladder() -> void:
	var text := FileAccess.get_file_as_string(DESIGN_README_PATH)
	assert_false(text.is_empty(), "docs/design/README.md must exist and be readable")
	var cursor := -1
	for rung: String in AUTHORITY_LADDER:
		var found := text.find(rung)
		assert_true(found >= 0, "docs/design/README.md must list the authority rung: " + rung)
		if found >= 0:
			assert_true(found > cursor, "the authority ladder must keep its approved order at rung: " + rung)
			cursor = found
