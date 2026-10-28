extends GutTest
## Replaceable draft DTL exercises the real native compiler, not copied library prose.
const WEEK := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const LIBRARY := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const WITNESS := preload("res://scripts/profile/CaptionWitnessLedger.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const STORY_TEXT := preload("res://scripts/localization/StoryLocalization.gd")
const FIRST := "draft.first"
const SECOND := "draft.second"
const CHECKPOINT := "draft.checkpoint"
const PLACEMENTS_PATH := "user://dialogue-library-authoring.json"
const DTL := "label draft.first\nDraft caption. #id:draft.caption\n# self-talk\nDraft thought. #id:draft.thought\nRetained caption. #id:draft.retained\nreturn\nlabel draft.second\nLater draft. #id:draft.later\nreturn\n"

func after_each() -> void:
	assert_true(LIBRARY.configure([], [], {}).ok)
	ART.reload_placements()
	if FileAccess.file_exists(PLACEMENTS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PLACEMENTS_PATH))

func _compile(source: String = DTL, previous: Dictionary = {}) -> Dictionary:
	var bundle := {"caption_registry": {"entries": []}}
	var compiled := {}
	for id: String in [FIRST, SECOND]:
		var result: Dictionary = ADAPTER._compile_scene_programme_source(source, id, [FIRST, SECOND], [])
		assert_true(result.ok, str(result))
		if not result.ok: return {}
		compiled[id] = result.value
		bundle.caption_registry.entries.append({"entry_id": id,
			"lines": WEEK.caption_lines(result.value.events, previous)})
	return {"bundle": bundle, "compiled": compiled}

func _placements() -> Dictionary:
	return {"schema_version": 1, "assets": {}, "scenes": {"draft.art": {}},
		"presentation_checkpoints": {CHECKPOINT: {"scene_entry_id": "draft.art", "audio_plan_id": ""}},
		"presentation_entries": {FIRST: [{"kind": "checkpoint", "id": CHECKPOINT}]},
		"dialogue_library": {"condition_labels": {"choice": {"en": "Choose to stay"},
			"won": {"en": "Win the Challenge"}, "clean": {"en": "Finish without a mistake"}},
			"passages": [{"id": CHECKPOINT, "title": {"en": "Replaceable draft"}, "entries": [
				{"entry_id": FIRST, "requirements": {"all": [{"label": "choice"},
					{"any": [{"label": "won"}, {"label": "clean"}]}]}},
				{"entry_id": SECOND}]}]}}

func _load_placements(value: Dictionary) -> void:
	var file := FileAccess.open(PLACEMENTS_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_string(JSON.stringify(value))
	file.close()
	assert_true(ART.reload_placements(PLACEMENTS_PATH))

func test_native_draft_expands_pairs_and_conditions_without_authoring_prose() -> void:
	var native := _compile()
	if native.is_empty(): return
	var placements := _placements()
	var before := placements.duplicate(true)
	var generated: Dictionary = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_true(generated.ok, str(generated))
	if not generated.ok: return
	assert_eq(placements, before, "export does not write text or identities into the author's grouping")
	var rows: Array = generated.value.passages[0].entries
	assert_eq(rows.map(func(row: Dictionary) -> String: return row.beat.line_id),
		["draft.caption", "draft.thought", "draft.retained", "draft.later"])
	assert_eq(rows.map(func(row: Dictionary) -> String: return row.kind),
		["caption", "thought", "caption", "caption"])
	assert_eq(rows[1].text.en, "Draft thought.")
	assert_eq(rows[0].requirements, rows[1].requirements)
	assert_eq(rows[3].requirements, {})
	assert_true(LIBRARY.configure_generated(generated.value, native.bundle).ok)
	var caption_key: String = WITNESS.describe(rows[0].beat).value.witness_id
	var projected: Array = LIBRARY.reached_passages({"checkpoints": [CHECKPOINT], "witnesses": {caption_key: true}})
	assert_eq(projected[0].entries[0].text, "Draft caption.")
	assert_eq(projected[0].entries[1].text, "", "a paired thought still needs its own actual read")
	assert_eq(projected[0].entries[1].requirements,
		"(Choose to stay AND (Win the Challenge OR Finish without a mistake))")

func test_replacing_dtl_rebuilds_prose_and_exact_identity_without_changing_grouping() -> void:
	var first := _compile()
	if first.is_empty(): return
	var placements := _placements()
	var old: Dictionary = WEEK.prepare_dialogue_library(placements, first.bundle, first.compiled)
	assert_true(old.ok, str(old))
	if not old.ok: return
	var previous := {}
	for entry: Dictionary in first.bundle.caption_registry.entries:
		for line: Dictionary in entry.lines: previous[line.line_id] = line
	var edited := DTL.replace("Draft caption.", "Rewritten draft.").replace(
		"# self-talk\nDraft thought. #id:draft.thought\n", "Inserted draft. #id:draft.inserted\n")
	var replacement := _compile(edited, previous)
	if replacement.is_empty(): return
	var generated: Dictionary = WEEK.prepare_dialogue_library(placements, replacement.bundle, replacement.compiled)
	assert_true(generated.ok, str(generated))
	if not generated.ok: return
	var old_rows: Array = old.value.passages[0].entries
	var rows: Array = generated.value.passages[0].entries
	assert_eq(rows.map(func(row: Dictionary) -> String: return row.beat.line_id),
		["draft.caption", "draft.inserted", "draft.retained", "draft.later"])
	assert_eq(rows[0].text.en, "Rewritten draft.")
	assert_eq(rows[1].kind, "caption", "classification follows current native DTL annotations")
	assert_eq(rows[0].beat.line_id, old_rows[0].beat.line_id)
	assert_ne(WITNESS.describe(rows[0].beat).value.witness_id, WITNESS.describe(old_rows[0].beat).value.witness_id)
	assert_eq(rows[2].beat, old_rows[2].beat, "unchanged wording retains exact read identity")
	assert_true(LIBRARY.configure_generated(generated.value, replacement.bundle).ok)
	var old_key: String = WITNESS.describe(old_rows[0].beat).value.witness_id
	assert_false(LIBRARY.reached_passages({"checkpoints": [CHECKPOINT], "witnesses": {old_key: true}})[0].entries[0].read)
	var repeated: Dictionary = WEEK.prepare_dialogue_library(placements, replacement.bundle, replacement.compiled)
	assert_eq(repeated, generated, "repeat export is deterministic")

func test_checkpoint_location_title_and_group_can_be_moved_then_removed_as_data() -> void:
	var native := _compile()
	if native.is_empty(): return
	var placements := _placements()
	_load_placements(placements)
	assert_true(ART.apply_entry_presentation(FIRST, {}).value.autosave)
	assert_false(ART.apply_entry_presentation(SECOND, {}).value.autosave)
	placements.presentation_entries.erase(FIRST)
	placements.presentation_entries[SECOND] = [{"kind": "checkpoint", "id": CHECKPOINT}]
	placements.dialogue_library.passages[0].title.en = "Later draft section"
	placements.dialogue_library.passages[0].entries = [{"entry_id": SECOND}]
	_load_placements(placements)
	assert_false(ART.apply_entry_presentation(FIRST, {}).value.autosave)
	assert_true(ART.apply_entry_presentation(SECOND, {}).value.autosave)
	var generated: Dictionary = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_true(generated.ok, str(generated))
	if not generated.ok: return
	assert_eq(generated.value.passages[0].title.en, "Later draft section")
	assert_eq(generated.value.passages[0].entries.size(), 1)
	assert_eq(generated.value.passages[0].entries[0].beat.line_id, "draft.later")
	placements.presentation_entries.clear()
	placements.presentation_checkpoints.clear()
	placements.erase("dialogue_library")
	_load_placements(placements)
	assert_false(ART.apply_entry_presentation(SECOND, {}).value.autosave)
	generated = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_eq(generated, {"ok": true, "value": {"passages": [], "condition_labels": {}}})
	assert_true(LIBRARY.configure_generated(generated.value, native.bundle).ok)
	assert_eq(LIBRARY.reached_passages({"checkpoints": [CHECKPOINT], "witnesses": {}}), [])

func test_manual_reference_edits_report_missing_entry_checkpoint_and_condition() -> void:
	var native := _compile()
	if native.is_empty(): return
	var placements := _placements()
	placements.dialogue_library.passages[0].entries[0].entry_id = "draft.renamed"
	var result: Dictionary = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_false(result.ok)
	assert_eq(result.code, &"library_authoring_entry_unknown")
	placements = _placements()
	placements.presentation_checkpoints.clear()
	result = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_false(result.ok)
	assert_eq(result.code, &"library_checkpoint_invalid")
	placements = _placements()
	placements.dialogue_library.condition_labels.erase("choice")
	result = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_false(result.ok)
	assert_eq(result.code, &"library_entry_invalid")
	placements = _placements()
	placements.presentation_entries.clear()
	result = WEEK.prepare_dialogue_library(placements, native.bundle, native.compiled)
	assert_false(result.ok)
	assert_eq(result.code, &"library_checkpoint_unbound")

func test_generated_rows_use_current_story_translations_and_mask_unread_text() -> void:
	var native := _compile()
	if native.is_empty(): return
	var generated: Dictionary = WEEK.prepare_dialogue_library(_placements(), native.bundle, native.compiled)
	assert_true(generated.ok, str(generated))
	if not generated.ok: return
	assert_true(LIBRARY.configure_generated(generated.value, native.bundle).ok)
	var saved_catalogs: Dictionary = STORY_TEXT._catalogs.duplicate(true)
	STORY_TEXT._catalogs = {"en": {"draft.caption": "Draft caption.", "draft.thought": "Draft thought."},
		"zh_HK": {"draft.caption": "目前的草稿。", "draft.thought": "未讀的想法。"}}
	var beat: Dictionary = generated.value.passages[0].entries[0].beat
	var key: String = WITNESS.describe(beat).value.witness_id
	var rows: Array = LIBRARY.reached_passages({"checkpoints": [CHECKPOINT], "witnesses": {key: true}}, "zh_HK")
	assert_eq(rows[0].entries[0].text, "目前的草稿。")
	assert_eq(rows[0].entries[1].text, "", "an available thought translation is still hidden until witnessed")
	var replacement := _compile(DTL.replace("Draft caption.", "New current draft."))
	if not replacement.is_empty():
		generated = WEEK.prepare_dialogue_library(_placements(), replacement.bundle, replacement.compiled)
		assert_true(generated.ok, str(generated))
		if generated.ok:
			assert_true(LIBRARY.configure_generated(generated.value, replacement.bundle).ok)
			beat = generated.value.passages[0].entries[0].beat
			key = WITNESS.describe(beat).value.witness_id
			rows = LIBRARY.reached_passages({"checkpoints": [CHECKPOINT], "witnesses": {key: true}}, "zh_HK")
			assert_eq(rows[0].entries[0].text, "New current draft.", "stale translation never replaces revised draft wording")
	STORY_TEXT._catalogs = saved_catalogs
