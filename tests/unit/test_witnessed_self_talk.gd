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

func test_dual_latest_pair_retains_thought_until_clear_and_restores_single_window() -> void:
	var panel := _panel(440)
	panel.configure(CAPTION_THEME.build("en", 100, "AfterHours"), 440, Callable(), "Thoughts", true)
	var rows := [{"id":"a", "text":"Earlier synthetic thought", "content_locale":"en", "secondary_text":"較早的測試想法", "secondary_locale":"zh_HK"},
		{"id":"b", "text":"Latest synthetic thought", "content_locale":"en", "secondary_text":"最新的測試想法", "secondary_locale":"zh_HK"}]
	panel.project(rows, 0)
	var latest := panel.get_projection()
	assert_eq(latest.history_count, 2)
	assert_true(latest.visible_rows.all(func(row: Dictionary) -> bool: return row.id == "b"))
	assert_true(latest.visible_rows.any(func(row: Dictionary) -> bool: return row.secondary))
	assert_eq(panel.get_child(0).locale, "en")
	assert_eq(panel.get_child(panel.get_child_count() - 1).locale, "zh-HK")
	panel.project(rows, 0)
	assert_eq(panel.get_projection(), latest, "An unrelated caption retains the latest thought pair")
	panel.review_rows(2)
	assert_true(panel.is_reviewing())
	assert_eq(panel.get_projection().visible_rows[0].id, "a")
	panel.return_to_live()
	panel.project(rows, 2)
	assert_true(panel.get_projection().visible_rows.is_empty())
	assert_eq(panel.get_projection().history_count, 2)
	panel.configure(CAPTION_THEME.build("en", 100, "AfterHours"), 440, Callable(), "Thoughts", false)
	panel.project(rows, 0)
	assert_false(panel.get_projection().dual_enabled)
	assert_lte(panel.get_projection().visible_rows.size(), 3)
	assert_false(panel.get_projection().visible_rows.any(func(row: Dictionary) -> bool: return row.secondary))

func test_long_dual_thought_is_scrollable_without_truncating_the_pair() -> void:
	var panel := _panel(240)
	panel.configure(CAPTION_THEME.build("en", 150, "AfterHours"), 240, Callable(), "Thoughts", true, 150)
	panel.project([{"id":"long", "text":"Synthetic primary thought with enough words to fill several lines and require scrolling.",
		"content_locale":"en", "secondary_text":"這是一個很長的測試想法，用來證明翻譯能夠完整保留，而且可以捲動閱讀最後一行。", "secondary_locale":"zh_HK"}], 0)
	assert_gt(panel.get_projection().row_count, panel.get_projection().visible_rows.size())
	assert_eq(panel.get_projection().visible_rows[0].start, 0)
	assert_false(panel.get_projection().visible_rows[0].secondary)
	panel.review_rows(-100)
	var tail: Dictionary = panel.get_projection().visible_rows.back()
	assert_true(tail.secondary)
	assert_eq(tail.end, tail.text.length())
	assert_lte(panel.size.y, 216.0)
	panel.return_to_live()
	assert_false(panel.is_reviewing())
	assert_eq(panel.get_projection().visible_rows[0].start, 0)

func test_dual_generic_choice_keeps_room_for_wrapped_latest_pair_at_150_percent() -> void:
	var panel := _panel(432)
	var presentation := CAPTION_THEME.build("en", 150, "AfterHours")
	panel.configure(presentation, 432, Callable(), "Thoughts", false, 150)
	panel.set_choice_row_visible(true)
	var single_choice_height := panel.get_choice_row_rect().size.y
	panel.configure(presentation, 432, Callable(), "Thoughts", true, 150)
	panel.project([{"id":"synthetic", "text":"Ask for another photograph.", "content_locale":"en",
		"secondary_text":"再要一張照片。", "secondary_locale":"zh_HK"}], 0)
	var shown := panel.get_projection()
	assert_eq(panel.get_choice_row_rect().size.y, single_choice_height, "Generic Yes reserves one UI label, even when thoughts are bilingual")
	assert_gt(shown.row_count, 2, "Primary wraps in the narrow portrait panel at 150%")
	assert_eq(shown.visible_rows.size(), shown.row_count, "The latest wrapped pair fits above the single-label choice")
	assert_true(shown.visible_rows.back().secondary)
	assert_lte(panel.size.y, 240.0)
	panel.set_choice_row_height(single_choice_height + 48)
	assert_eq(panel.get_choice_row_rect().size.y, single_choice_height + 48, "Real bilingual options still receive their measured height")
	panel.set_choice_row_height(0)
	assert_eq(panel.get_projection().visible_rows.size(), shown.row_count)
