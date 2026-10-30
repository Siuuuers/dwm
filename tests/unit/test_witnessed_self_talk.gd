extends GutTest

const PANEL := preload("res://scripts/ui/witnessed/WitnessedSelfTalk.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")

func _panel(width: float = 400.0) -> PANEL:
	var panel := PANEL.new()
	add_child_autofree(panel)
	panel.configure(CAPTION_THEME.build("en", 100, "AfterHours"), width, func() -> bool: return true)
	return panel

func test_current_thought_starts_at_top_and_long_text_remains_scrollable() -> void:
	var panel := _panel()
	panel.project([{"id":"a", "text":"First row\nSecond row\nThird row\nFourth row"}], 0)
	var full := panel.get_projection()
	assert_eq(full.visible_rows.size(), 3)
	assert_eq(full.visible_rows[0].line, 0)
	var frame_size := panel.size
	panel.review_rows(-1)
	assert_true(panel.is_reviewing())
	assert_eq(panel.get_projection().visible_rows.back().line, 3)
	assert_eq(panel.size, frame_size)
	panel.return_to_live()
	assert_eq(panel.get_projection().visible_rows[0].line, 0)

func test_advance_replaces_or_clears_thought_without_panel_scrollback() -> void:
	var panel := _panel()
	panel.project([{"id":"a", "text":"Earlier"}], 0)
	var frame_size := panel.size
	panel.project([{"id":"b", "text":"Current"}], 0)
	panel.review_rows(100)
	assert_false(panel.is_reviewing())
	assert_eq(panel.get_projection().history_count, 1)
	assert_eq(panel.get_projection().visible_rows[0].id, "b")
	panel.project([], 0)
	panel.review_rows(100)
	assert_true(panel.visible)
	assert_eq(panel.get_projection().visible_rows.size(), 0)
	assert_eq(panel.get_projection().history_count, 0)
	assert_eq(panel.size, frame_size)
	assert_false(panel.is_reviewing())

func test_reflow_preserves_current_thought_scroll_anchor_and_three_row_limit() -> void:
	var panel := _panel(160)
	var rows := [{"id":"a", "text":"A long synthetic thought with several words that wraps across lines and keeps its current reading position."}]
	panel.project(rows, 0)
	assert_gt(panel.get_projection().row_count, 3)
	panel.review_rows(-3)
	var anchor: Dictionary = panel.get_projection().visible_rows[0]
	panel.project(rows, 0)
	assert_true(panel.is_reviewing(), "Refreshing the same caption preserves current-thought scrolling")
	panel.configure(CAPTION_THEME.build("en", 150, "AfterHours"), 200, func() -> bool: return true)
	var after := panel.get_projection()
	assert_true(after.reviewing)
	assert_lte(after.visible_rows.size(), 3)
	assert_eq(after.visible_rows[0].id, anchor.id)
	assert_lte(after.visible_rows[0].start, anchor.start)
	assert_gte(after.visible_rows[0].end, anchor.start)

func test_empty_frame_keeps_localized_accessible_name_and_stable_height() -> void:
	var panel := _panel()
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/" + locale + ".json"))
		var pane_name := ""
		for entry: Dictionary in catalogue.messages:
			if entry.id == "witnessed.self_talk.name": pane_name = entry.text
		assert_false(pane_name.is_empty())
		for percent: int in [125, 150]:
			for dual: bool in [false, true]:
				panel.configure(CAPTION_THEME.build(locale.replace("_", "-"), percent, "AfterHours"), 400, Callable(), pane_name, dual, percent)
				panel.project([{"id":"a", "text":"Synthetic thought", "content_locale":"en", "secondary_text":"測試想法", "secondary_locale":"zh_HK"}], 0)
				var populated_size := panel.size
				panel.project([], 0)
				assert_true(panel.visible)
				assert_eq(panel.get_projection().visible_rows.size(), 0)
				assert_eq(panel.accessibility_name, pane_name)
				assert_eq(panel.size, populated_size)

func test_dual_current_pair_refresh_clear_and_single_language_reflow() -> void:
	var panel := _panel(440)
	panel.configure(CAPTION_THEME.build("en", 100, "AfterHours"), 440, Callable(), "Thoughts", true)
	var rows := [{"id":"b", "text":"Current synthetic thought", "content_locale":"en", "secondary_text":"目前的測試想法", "secondary_locale":"zh_HK"}]
	panel.project(rows, 0)
	var current := panel.get_projection()
	assert_eq(current.history_count, 1)
	assert_true(current.visible_rows.all(func(row: Dictionary) -> bool: return row.id == "b"))
	assert_true(current.visible_rows.any(func(row: Dictionary) -> bool: return row.secondary))
	assert_eq(panel.get_child(0).locale, "en")
	assert_eq(panel.get_child(panel.get_child_count() - 1).locale, "zh-HK")
	panel.project(rows, 0)
	assert_eq(panel.get_projection(), current, "Refreshing the same caption preserves its thought pair")
	panel.project([], 0)
	assert_true(panel.get_projection().visible_rows.is_empty())
	assert_eq(panel.get_projection().history_count, 0)
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
