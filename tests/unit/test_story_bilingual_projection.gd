extends "res://addons/gut/test.gd"
## Synthetic writing-system samples exercise presentation, not approved story prose.
const STORY := preload("res://scripts/localization/StoryLocalization.gd")
var _saved_catalogs: Dictionary

func before_each() -> void:
	_saved_catalogs = STORY._catalogs
	STORY._catalogs = {
		"en": {"line.sample.a": "A sample.", "line.sample.b": "A sample.",
			"line.sample.thought": "A thought.", "choice.sample.left": "Choose left."},
		"zh_HK": {"line.sample.a": "範例甲。", "line.sample.b": "範例乙。"},
		"zh_CN": {"line.sample.a": "示例。"},
		"ja": {"line.sample.a": "例です。", "line.sample.thought": "考え。"},
		"ko": {"line.sample.a": "예시입니다.", "choice.sample.left": "왼쪽 선택."}}

func after_each() -> void:
	STORY._catalogs = _saved_catalogs

func test_every_registered_locale_pairs_and_swaps_without_changing_identity() -> void:
	for locale: String in STORY.LOCALES:
		var paired := STORY.pair("en", locale, "line.sample.a", "A sample.")
		assert_eq(paired.text, "A sample.")
		assert_eq(paired.content_locale, "en")
		assert_eq(paired.secondary_text, "" if locale == "en" else STORY.catalog(locale)["line.sample.a"])
		var swapped := STORY.pair(locale, "en", "line.sample.a", "A sample.")
		assert_eq(swapped.text, STORY.catalog(locale)["line.sample.a"])
		assert_eq(swapped.content_locale, locale)
		assert_eq(swapped.secondary_text, "" if locale == "en" else "A sample.")

func test_missing_secondary_and_source_fallback_have_no_duplicate_row() -> void:
	assert_eq(STORY.pair("ja", "ko", "line.sample.thought", "A thought."), {
		"text": "考え。", "content_locale": "ja", "secondary_text": "", "secondary_locale": ""})
	assert_eq(STORY.pair("ko", "en", "line.sample.thought", "A thought."), {
		"text": "A thought.", "content_locale": "en", "secondary_text": "", "secondary_locale": ""})
	assert_eq(STORY.pair("ko", "ja", "line.sample.thought", "A thought."), {
		"text": "A thought.", "content_locale": "en", "secondary_text": "考え。", "secondary_locale": "ja"})
	assert_eq(STORY.pair("ja", "", "line.sample.a", "A sample.").secondary_text, "")

func test_source_edits_do_not_select_stale_variant_translation() -> void:
	var projected := STORY.pair("ja", "zh_HK", "line.sample.a", "Edited draft.")
	assert_eq(projected.text, "Edited draft.")
	assert_eq(projected.content_locale, "en")
	assert_eq(projected.secondary_text, "")
	assert_eq(STORY.pair("en", "zh_HK", "line.sample.a", "A sample.").secondary_text, "範例甲。")
	assert_eq(STORY.pair("en", "zh_HK", "line.sample.b", "A sample.").secondary_text, "範例乙。")

func test_history_projection_keeps_one_row_and_original_semantic_data() -> void:
	var source := {"ok": true, "value": {"captions": [
		{"line_id": "line.sample.a", "text": "A sample.", "publication_id": "publication-a"},
		{"line_id": "line.sample.b", "text": "A sample.", "publication_id": "publication-b"}]}}
	var before := source.duplicate(true)
	var projected := STORY.project(source, "zh_HK", "ja")
	assert_eq(projected.value.captions.size(), 2)
	assert_eq(projected.value.captions[0].text, "範例甲。")
	assert_eq(projected.value.captions[0].secondary_text, "例です。")
	assert_eq(projected.value.captions[1].text, "範例乙。")
	assert_eq(projected.value.captions[1].secondary_text, "")
	assert_eq(projected.value.captions[1].publication_id, "publication-b")
	assert_eq(source, before, "Projection never modifies the admitted ledger")

func test_choices_use_the_same_projection_and_actual_content_locale() -> void:
	assert_eq(STORY.pair("ko", "en", "choice.sample.left", "Choose left."), {
		"text": "왼쪽 선택.", "content_locale": "ko", "secondary_text": "Choose left.", "secondary_locale": "en"})
	assert_eq(STORY.resolve("zh_CN", "choice.sample.left", "Choose left."), {
		"text": "Choose left.", "content_locale": "en"})
