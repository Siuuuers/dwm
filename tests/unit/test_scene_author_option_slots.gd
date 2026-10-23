extends "res://addons/gut/test.gd"
## Offline compilation/registration only; no new gameplay or persistence claim.
const TEMPLATE := preload("res://tests/templates/scene_sequence/OptionSlotTemplates.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

func test_two_used_slots_compile_and_validate_with_one_explicit_transition() -> void:
	var built: Dictionary = TEMPLATE.bundle()
	assert_true(built.ok, str(built.get("details", "")))
	if not built.ok: return
	var checked: Dictionary = TEMPLATE.MANIFEST.validate_scene_registration(built.value)
	assert_true(checked.ok, str(checked))
	assert_true(CONTRACT.validate_bundle_structure(built.value).ok)
	assert_eq(built.value.entry_manifest.entry_count, 2)
	assert_eq(built.value.targets.map(func(row: Dictionary) -> String: return row.target_id), ["option_a_day1", "option_b_day1"])
	assert_true(built.value.challenges.is_empty())
	assert_true(built.value.board_profiles.is_empty())
	for index: int in TEMPLATE.ENTRIES.size():
		var id: String = TEMPLATE.ENTRIES[index]
		var programme: Dictionary = built.value.scene_programme.entries[index]
		var compiled: Dictionary = TEMPLATE.ADAPTER.compile_scene_programme(TEMPLATE.STORY, id, TEMPLATE.ENTRIES, programme.markers)
		assert_true(compiled.ok)
		if not compiled.ok: continue
		var lines: Array = []
		for event: Dictionary in compiled.value.events:
			if event.kind == "text": lines.append(event.line_id)
		assert_eq(lines, ["line." + id + ".one"], "slots have isolated replaceable captions")
		assert_eq(compiled.value.program_sha256, programme.program_sha256)
		assert_eq(programme.markers.size(), 1 if index == 0 else 0)
		if index == 0:
			assert_eq(programme.markers[0].kind, "scene.transition")
			assert_eq(programme.markers[0].payload, {"target_id": "option_b_day1"})

func test_referenced_missing_slot_is_rejected_without_mutating_the_source() -> void:
	var built: Dictionary = TEMPLATE.bundle()
	assert_true(built.ok)
	if not built.ok: return
	var broken: Dictionary = built.value.duplicate(true)
	broken.targets.pop_back()
	var before: Dictionary = broken.duplicate(true)
	assert_false(TEMPLATE.MANIFEST.validate_scene_registration(broken).ok)
	assert_false(CONTRACT.validate_bundle_structure(broken).ok)
	assert_eq(broken, before)
	assert_eq(built.value.targets.size(), 2)
