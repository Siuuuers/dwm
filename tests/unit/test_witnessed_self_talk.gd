extends GutTest

const PANEL := preload("res://scripts/ui/witnessed/WitnessedSelfTalk.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")

func _panel(width: float = 400.0) -> PANEL:
	var panel := PANEL.new()
	add_child_autofree(panel)
	panel.configure(CAPTION_THEME.build("en", 100, "AfterHours"), width, func() -> bool: return true)
	return panel

func test_wrapped_rows_evicted_without_losing_source_identity() -> void:
	var panel := _panel()
	panel.project([{"id":"a", "text":"First row\nSecond row"}, {"id":"b", "text":"Third row"}], 0)
	var full := panel.get_projection()
	assert_eq(full.visible_rows.size(), 3)
	assert_eq(full.visible_rows[0].id, "a")
	assert_eq(full.visible_rows[0].line, 0)
	panel.project([{"id":"a", "text":"First row\nSecond row"}, {"id":"b", "text":"Third row"}, {"id":"c", "text":"Fourth row"}], 0)
	var shifted := panel.get_projection()
	assert_eq(shifted.visible_rows.size(), 3)
	assert_eq(shifted.visible_rows[0].id, "a")
	assert_eq(shifted.visible_rows[0].line, 1)
	assert_eq(shifted.history_count, 3)
	panel.review_rows(1)
	assert_eq(panel.get_projection().visible_rows[0].line, 0)
	assert_true(panel.is_reviewing())
	panel.return_to_live()
	assert_eq(panel.get_projection().visible_rows[0].line, 1)

func test_clear_keeps_scrollback_and_unchanged_publication_keeps_review() -> void:
	var panel := _panel()
	var rows := [{"id":"a", "text":"Earlier"}, {"id":"b", "text":"Later"}]
	panel.project(rows, 2)
	assert_eq(panel.get_projection().visible_rows.size(), 0)
	assert_eq(panel.get_projection().history_count, 2)
	panel.review_rows(1)
	assert_true(panel.is_reviewing())
	assert_eq(panel.get_projection().visible_rows[0].id, "b")
	panel.project(rows, 2)
	assert_true(panel.is_reviewing())
	panel.review_rows(-1)
	assert_false(panel.is_reviewing())
	assert_eq(panel.get_projection().visible_rows.size(), 0)

func test_reflow_preserves_review_identity_and_three_row_limit() -> void:
	var panel := _panel(160)
	var rows := [{"id":"a", "text":"A long synthetic thought with several words that wraps across lines."}, {"id":"b", "text":"Another synthetic thought with several words for wrapping."}]
	panel.project(rows, 0)
	assert_gt(panel.get_projection().row_count, 3)
	panel.review_rows(3)
	var anchor: Dictionary = panel.get_projection().visible_rows[0]
	panel.configure(CAPTION_THEME.build("en", 150, "AfterHours"), 200, func() -> bool: return true)
	var after := panel.get_projection()
	assert_true(after.reviewing)
	assert_lte(after.visible_rows.size(), 3)
	assert_eq(after.visible_rows[0].id, anchor.id)
	assert_lte(after.visible_rows[0].start, anchor.start)
	assert_gte(after.visible_rows[0].end, anchor.start)

func test_cleared_panel_keeps_localized_accessible_name() -> void:
	var panel := _panel()
	var rows := [{"id":"a", "text":"Synthetic thought"}]
	panel.project(rows, 1)
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/" + locale + ".json"))
		var pane_name := ""
		for entry: Dictionary in catalogue.messages:
			if entry.id == "witnessed.self_talk.name": pane_name = entry.text
		assert_false(pane_name.is_empty())
		panel.configure(CAPTION_THEME.build(locale.replace("_", "-"), 100, "AfterHours"), 400, Callable(), pane_name)
		assert_eq(panel.get_projection().visible_rows.size(), 0)
		assert_eq(panel.accessibility_name, pane_name)
		panel.review_rows(1)
		assert_eq(panel.accessibility_name, "Synthetic thought")
		panel.return_to_live()
