extends "res://addons/gut/test.gd"
const TEMPLATES := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

func test_seven_replaceable_days_compile_with_six_ordinary_links() -> void:
	var result: Dictionary = TEMPLATES.prepare()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	var bundle: Dictionary = result.value.registration
	assert_true(MANIFEST.validate_scene_registration(bundle).get("ok", false))
	assert_true(CONTRACT.validate_bundle_structure(bundle).get("ok", false))
	assert_eq(result.value.first_target_id, "target.Day1")
	var ids: Array = []
	for row: Dictionary in bundle.entry_manifest.entries: ids.append(row.entry_id)
	assert_eq(ids, ["Day1", "Day2", "Day3", "Day4", "Day5", "Day6", "Day7"])
	for index in range(7):
		var caption: Dictionary = bundle.caption_registry.entries[index].lines[0]
		assert_eq(caption.text, "TEST Day%d placeholder." % (index + 1))
		assert_eq(caption.line_id, "line.Day%d.one" % (index + 1))
		var programme: Dictionary = bundle.scene_programme.entries[index]
		if index < 6:
			assert_eq(programme.markers.size(), 1)
			assert_eq(programme.markers[0].kind, "scene.transition")
			assert_eq(programme.markers[0].payload, {"target_id": "target.Day%d" % (index + 2)})
		else:
			assert_eq(programme.markers, [], "Day7 has no fabricated terminal action")
	assert_eq(bundle.challenges, [], "no mandatory Minesweeper")
	assert_eq(bundle.board_profiles, [])
	assert_eq(bundle.contacts, [])
	assert_eq(result.value.terminal_dependency, {
		"status": "pending", "source_entry_id": "Day7", "after_line_id": "line.Day7.one",
		"required": "authenticated_registered_ending_connection"})

func test_preparation_is_deterministic_and_detached() -> void:
	var first: Dictionary = TEMPLATES.prepare()
	var second: Dictionary = TEMPLATES.prepare()
	assert_true(first.get("ok", false), str(first))
	assert_true(second.get("ok", false), str(second))
	if not first.get("ok", false) or not second.get("ok", false): return
	assert_eq(first, second)
	first.value.registration.caption_registry.entries[0].lines[0].text = "changed"
	first.value.terminal_dependency.status = "changed"
	assert_eq(second.value.registration.caption_registry.entries[0].lines[0].text, "TEST Day1 placeholder.")
	assert_eq(second.value.terminal_dependency.status, "pending")
