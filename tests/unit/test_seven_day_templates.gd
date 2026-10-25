extends "res://addons/gut/test.gd"
const TEMPLATES := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

func test_seven_days_and_registered_ending_compile_with_explicit_links() -> void:
	var result: Dictionary = TEMPLATES.prepare()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var bundle: Dictionary = result.value.registration
	assert_true(MANIFEST.validate_scene_registration(bundle).get("ok", false))
	assert_true(CONTRACT.validate_bundle_structure(bundle).get("ok", false))
	assert_eq(bundle.schema_version, 3)
	assert_eq(bundle.scene_programme.story_days, {"Day1": 1, "Day2": 2, "Day3": 3, "Day4": 4, "Day5": 5, "Day6": 6, "Day7": 7, "ending.alone.normal": 7})
	assert_eq(result.value.first_target_id, "target.Day1")
	var ids: Array = []
	for row: Dictionary in bundle.entry_manifest.entries: ids.append(row.entry_id)
	assert_eq(ids, ["Day1", "Day2", "Day3", "Day4", "Day5", "Day6", "Day7", "ending.alone.normal"])
	for index in range(7):
		var lines: Array = bundle.caption_registry.entries[index].lines
		assert_eq(lines.size(), 2)
		assert_eq(lines[0].text, "TEST Day%d opening." % (index + 1))
		assert_eq(lines[1].text, "TEST Day%d closing." % (index + 1))
		var entry: Dictionary = bundle.entry_manifest.entries[index]
		assert_eq(entry.locators.en.path, "res://tests/fixtures/dialogic/Day%d.dtl" % (index + 1))
		assert_eq(entry.content_version, 1, "matches the Run9 narrative content contract")
		var programme: Dictionary = bundle.scene_programme.entries[index]
		assert_eq(programme.markers.size(), 1)
		assert_eq(programme.markers[0].kind, "scene.transition")
		assert_eq(programme.markers[0].after_line_id, "line.Day%d.two" % (index + 1))
		var target: String = "target.Day%d" % (index + 2) if index < 6 else "target.ending.alone.normal"
		assert_eq(programme.markers[0].payload, {"target_id": target})
	assert_eq(bundle.entry_manifest.entries[7].role, "alone_step")
	assert_eq(bundle.entry_manifest.entries[7].locators.en.path, "res://tests/fixtures/dialogic/Day7.dtl")
	assert_eq(bundle.entry_manifest.entries[7].content_version, 1)
	assert_eq(bundle.targets[7].target.kind, "ending")
	assert_eq(bundle.challenges, [], "no mandatory Minesweeper")
	assert_eq(bundle.board_profiles, [])
	assert_eq(bundle.contacts, [])

func test_preparation_is_deterministic_and_detached() -> void:
	var first: Dictionary = TEMPLATES.prepare()
	var second: Dictionary = TEMPLATES.prepare()
	assert_true(first.get("ok", false), str(first))
	assert_true(second.get("ok", false), str(second))
	if not first.get("ok", false) or not second.get("ok", false): return
	assert_eq(first, second)
	first.value.registration.caption_registry.entries[0].lines[0].text = "changed"
	assert_eq(second.value.registration.caption_registry.entries[0].lines[0].text, "TEST Day1 opening.")

func test_ending_role_cannot_be_used_as_an_ordinary_scene_or_change_context() -> void:
	var result: Dictionary = TEMPLATES.prepare()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var bundle: Dictionary = result.value.registration.duplicate(true)
	bundle.targets[7].target.kind = "scene"
	assert_false(MANIFEST.validate_scene_registration(bundle).get("ok", false))
	bundle = result.value.registration.duplicate(true)
	bundle.context_registry.schemas[7].fields.entry_role = {"const": "scene"}
	assert_false(MANIFEST.validate_scene_registration(bundle).get("ok", false))
