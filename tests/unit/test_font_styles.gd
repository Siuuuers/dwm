extends "res://addons/gut/test.gd"

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const GALLERY_TYPE := preload("res://scripts/ui/gallery/GalleryTypography.gd")
const DESKTOP := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const MINES := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const SHOP := preload("res://scripts/ui/shop/ShopTheme.gd")
const SETTINGS := preload("res://scripts/ui/SettingsTheme.gd")
const PAUSE := preload("res://scripts/ui/pause/PauseTheme.gd")
const GALLERY := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const BACKUP := preload("res://scripts/ui/backup/BackupTheme.gd")
const GALLERY_ROW := preload("res://scripts/ui/gallery/GalleryRecordButton.gd")
const GALLERY_PAPER := preload("res://scripts/ui/gallery/GalleryRecordPaper.gd")
const LOCALES := ["en", "zh_CN", "zh_HK", "ja", "ko"]
const STYLES := ["pixel", "readable"]
const PERCENTS := [100, 125, 150]
const READABLE_NAMES := {"en": "source sans", "zh_CN": "source han sans sc",
	"zh_HK": "source han sans hc", "ja": "source han sans jp", "ko": "source han sans kr"}

func test_explicit_style_resolves_locale_correct_faces_and_size_contracts() -> void:
	var pixel_paths := {}
	var readable_paths := {}
	for locale: String in LOCALES:
		for percent: int in PERCENTS:
			for style: String in STYLES:
				var font: Font = TYPOGRAPHY.font(locale, percent, style)
				assert_true(font is FontFile, "%s/%s/%d uses a registered face" % [locale, style, percent])
				if not font is FontFile: continue
				var base := 24 if style == "pixel" else 20
				assert_eq(TYPOGRAPHY.font_size(locale, percent, 20, style), int(base * percent / 100.0))
				assert_eq(TYPOGRAPHY.font_size(locale, percent, 24, style), int(24 * percent / 100.0))
				assert_same(GALLERY_TYPE.font(locale, percent, style), font)
				assert_eq(GALLERY_TYPE.font_size(percent), int(16 * percent / 100.0))
				assert_true(font.fallbacks.is_empty(), "Primary faces do not acquire another theme's fallback list")
				if style == "pixel":
					pixel_paths[font.resource_path] = true
					assert_string_contains(font.get_font_name().to_lower(), "fusion pixel")
					assert_false(font.allow_system_fallback)
					assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
					assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
					assert_eq(font.hinting, TextServer.HINTING_NONE)
				else:
					readable_paths[font.resource_path] = true
					assert_string_contains(font.get_font_name().to_lower(), READABLE_NAMES[locale])
					assert_ne(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	assert_eq(pixel_paths.size(), 15, "Each locale/percentage selects its native pixel master")
	assert_eq(readable_paths.size(), 5, "Readable faces scale without substituting another region")

func test_registered_faces_own_every_catalog_and_english_fallback_glyph() -> void:
	var english := _catalog_characters("en")
	for locale: String in LOCALES:
		var characters := english.duplicate()
		characters.merge(_catalog_characters(locale))
		for style: String in STYLES:
			for percent: int in PERCENTS:
				var font: Font = TYPOGRAPHY.font(locale, percent, style)
				var missing: Array[int] = []
				for code: int in characters:
					if not font.has_char(code): missing.append(code)
				assert_eq(missing, [], "%s/%s/%d owns catalog glyphs without system fallback" % [locale, style, percent])

func test_every_theme_uses_requested_style_and_all_caption_font_slots() -> void:
	for locale: String in LOCALES:
		for percent: int in PERCENTS:
			for style: String in STYLES:
				var font: Font = TYPOGRAPHY.font(locale, percent, style)
				var themes := [DESKTOP.build(locale, percent, &"after_hours", 0.0, false, "standard", style),
					MINES.build(locale, percent, &"after_hours", false, "standard", style),
					SHOP.build(locale, percent, &"after_hours", 1, false, "standard", style),
					SETTINGS.build(locale, percent, &"after_hours", false, "standard", 1, style),
					PAUSE.build(locale, percent, "AfterHours", false, "standard", 1, style),
					GALLERY.build(locale, percent, &"after_hours", style),
					CAPTION.build(locale, percent, "AfterHours", false, "standard", false, 1, true, style),
					BACKUP.build(locale, percent, &"after_hours", 1, false, "standard", style)]
				for index: int in themes.size():
					var theme: Theme = themes[index]
					assert_not_null(theme)
					if theme == null: continue
					var actual: Font = theme.default_font.base_font if theme.default_font is FontVariation else theme.default_font
					assert_same(actual, font, "Theme %d honors %s/%s/%d" % [index, locale, style, percent])
					var base := 20 if index in [1, 2, 6] else 24
					var expected_size := GALLERY_TYPE.font_size(percent) if index == 5 else TYPOGRAPHY.font_size(locale, percent, base, style)
					assert_eq(theme.default_font_size, expected_size)
				var caption: Theme = themes[6]
				for slot: StringName in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font", &"mono_font"]:
					assert_same(caption.get_font(slot, &"RichTextLabel"), font)

func test_interleaved_styles_do_not_change_another_fixture_or_shared_fallbacks() -> void:
	var pixel := SETTINGS.build("en", 150)
	var readable := SETTINGS.build("ja", 100, &"after_hours", false, "standard", 1, "readable")
	var pixel_font: Font = pixel.default_font.base_font
	var readable_font: Font = readable.default_font.base_font
	var original_pixel_fallbacks := pixel.default_font.fallbacks.duplicate()
	var original_readable_fallbacks := readable.default_font.fallbacks.duplicate()
	for locale: String in LOCALES:
		for style: String in STYLES:
			var other := SETTINGS.build(locale, 125, &"midnight", false, "standard", 1, style)
			other.default_font.fallbacks = []
	assert_same(pixel.default_font.base_font, pixel_font)
	assert_same(readable.default_font.base_font, readable_font)
	assert_eq(pixel.default_font.fallbacks, original_pixel_fallbacks)
	assert_eq(readable.default_font.fallbacks, original_readable_fallbacks)
	assert_same(TYPOGRAPHY.font("en", 150), pixel_font, "Default remains Pixel after interleaved Readable requests")
	assert_same(TYPOGRAPHY.font("ja", 100, "readable"), readable_font)
	assert_true(pixel_font.fallbacks.is_empty())
	assert_true(readable_font.fallbacks.is_empty())

func test_readable_gallery_rows_and_record_paper_measure_real_font_height() -> void:
	var samples := {"en": "A remembered afternoon with familiar voices.", "zh_CN": "与熟悉的声音一起，记住这个下午。",
		"zh_HK": "與熟悉的聲音一起，記住這個下午。", "ja": "なじみのある声とともに、この午後を覚えている。", "ko": "익숙한 목소리와 함께 이 오후를 기억합니다."}
	for locale: String in LOCALES:
		for percent: int in PERCENTS:
			var theme := GALLERY.build(locale, percent, &"after_hours", "readable")
			var row := GALLERY_ROW.new()
			row.theme = theme
			row.text = samples[locale]
			row.language = locale.replace("_", "-")
			add_child_autofree(row)
			var paper := GALLERY_PAPER.new()
			paper.theme = theme
			add_child_autofree(paper)
			paper.set_copy(samples[locale], samples[locale].repeat(5), locale, true)
			await get_tree().process_frame
			row.refresh_caption()
			paper.refresh_layout(true)
			assert_gte(row.caption.size.y, row.caption.get_minimum_size().y)
			assert_lte(row.caption.position.y + row.caption.size.y, row.custom_minimum_size.y)
			for label: Label in [paper.title_label, paper.sentence_label]:
				assert_gte(label.size.y, label.get_minimum_size().y, "Actual ascender/descent fits %s/%d" % [locale, percent])
				assert_false(label.clip_text)
			assert_lte(paper.title_label.position.y + paper.title_label.size.y, paper.sentence_label.position.y)
			assert_gte(paper.content_extent, paper.sentence_label.position.y + paper.sentence_label.size.y)

func test_invalid_font_tuple_is_refused_without_changing_default_selection() -> void:
	var before: Font = TYPOGRAPHY.font("en", 100)
	assert_null(TYPOGRAPHY.font("en", 100, "unknown"))
	assert_null(TYPOGRAPHY.font("en", 110, "pixel"))
	assert_null(TYPOGRAPHY.font("unknown", 100, "readable"))
	assert_eq(TYPOGRAPHY.font_size("en", 100, 20, "unknown"), 0)
	assert_null(DESKTOP.build("en", 100, &"after_hours", 0.0, false, "standard", "unknown"))
	assert_same(TYPOGRAPHY.font("en", 100), before)

func _catalog_characters(locale: String) -> Dictionary:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/%s.json" % locale))
	var characters := {}
	for row: Dictionary in catalog.messages:
		for character: String in str(row.text):
			if not character.strip_edges().is_empty(): characters[character.unicode_at(0)] = true
	return characters
