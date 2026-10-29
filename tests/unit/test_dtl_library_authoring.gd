extends GutTest
const SOURCE := preload("res://tools/authoring/DtlStorySource.gd")
const WEEK := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const DTL := 'label opening\n# story entry day=1 start\n# story passage {"id":"arrival","title_key":"opening"}\n# checkpoint arrival\nFirst caption. #id:first\n# self-talk\nPrivate thought. #id:thought\nreturn\nlabel branch\n# story entry day=1\n# story passage {"id":"arrival","requirements":{"all":[{"label":"choice"},{"any":[{"label":"won"},{"label":"perfect"}]}]}}\nBranch caption. #id:branch\nreturn\n'

func _prepare(text: String = DTL) -> Dictionary:
	var discovered: Dictionary = SOURCE.prepare_texts({"library_titles": {"opening": {"en": "Opening"}},
		"condition_labels": {"choice": {"en": "Choose"}, "won": {"en": "Win"}, "perfect": {"en": "Perfect"}}},
		{"res://replacement.dtl": text})
	assert_true(discovered.ok, str(discovered))
	if not discovered.ok: return discovered
	var compiled := {}
	var registration := {"caption_registry": {"entries": []}}
	for entry: Dictionary in discovered.value.entries:
		var native: Dictionary = ADAPTER._compile_scene_programme_source(text, entry.entry_id, ["opening", "branch"], entry.markers)
		assert_true(native.ok, str(native))
		if not native.ok: return native
		compiled[entry.entry_id] = native.value
		registration.caption_registry.entries.append({"entry_id": entry.entry_id, "lines": WEEK.caption_lines(native.value.events, {})})
	return WEEK.prepare_dtl_library(discovered.value, registration, compiled)

func test_dtl_membership_expands_pairs_without_another_checkpoint_arrival() -> void:
	var result := _prepare()
	assert_true(result.ok, str(result))
	if not result.ok: return
	var passage: Dictionary = result.value.passages[0]
	assert_eq(passage.id, "arrival")
	assert_eq(passage.title.en, "Opening")
	assert_eq(passage.entries.size(), 3)
	assert_eq(passage.entries[1].kind, "thought")
	assert_eq(passage.entries[2].requirements.all[1].any.size(), 2)
	assert_eq(_prepare(), result, "the same DTL generates the same library")

func test_library_membership_does_not_invent_a_checkpoint() -> void:
	var result := _prepare(DTL.replace("# checkpoint arrival\n", ""))
	assert_false(result.ok)
	assert_eq(result.code, &"library_dtl_membership_invalid")
	assert_eq(result.path, "res://replacement.dtl")
	assert_gt(result.line, 1)

func test_manual_title_and_condition_references_are_checked() -> void:
	assert_false(_prepare(DTL.replace('"title_key":"opening"', '"title_key":"missing"')).ok)
	assert_false(_prepare(DTL.replace('"label":"won"', '"label":"missing"')).ok)

func test_replacing_prose_keeps_structure_and_rebuilds_current_text() -> void:
	var result := _prepare(DTL.replace("First caption.", "Replacement caption."))
	assert_true(result.ok, str(result))
	if result.ok:
		assert_eq(result.value.passages[0].entries[0].text.en, "Replacement caption.")
		assert_eq(result.value.passages[0].entries[0].beat.line_id, "first")
