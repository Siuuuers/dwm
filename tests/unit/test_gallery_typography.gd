extends GutTest

const GALLERY_THEME := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const GALLERY_TYPOGRAPHY := preload("res://scripts/ui/gallery/GalleryTypography.gd")
const RECORD_CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")

const LOCALES := ["en", "zh_CN", "zh_HK"]
const PERCENTS := [100, 125, 150]
const FONT_SIZES := {100: 16, 125: 20, 150: 24}
const ASCENTS := {100: 18, 125: 22, 150: 26}
const DESCENTS := {100: 6, 125: 6, 150: 6}
const LINE_HEIGHTS := {100: 24, 125: 28, 150: 32}
const FONT_PATHS := {
	"en": {
		100: "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-latin.otf.woff2",
		125: "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-latin.otf.woff2",
		150: "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-latin.otf.woff2",
	},
	"zh_CN": {
		100: "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-zh_hans.otf.woff2",
		125: "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-zh_hans.otf.woff2",
		150: "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2",
	},
	"zh_HK": {
		100: "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-zh_hant.otf.woff2",
		125: "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-zh_hant.otf.woff2",
		150: "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-zh_hant.otf.woff2",
	},
}

func test_gallery_theme_uses_the_exact_regular_proportional_face_and_metrics_for_all_nine_tuples() -> void:
	var identities := {}
	for locale: String in LOCALES:
		for percent: int in PERCENTS:
			var theme: Theme = GALLERY_THEME.build(locale, percent, &"after_hours")
			var registered: Font = GALLERY_TYPOGRAPHY.font(locale, percent)
			assert_not_null(theme)
			assert_not_null(registered)
			if theme == null or registered == null: continue
			var font: Font = theme.default_font
			var size: int = theme.default_font_size
			var expected_path := str(FONT_PATHS[locale][percent])
			assert_same(font, registered, "%s/%d uses its registered Gallery face" % [locale, percent])
			assert_eq(font.resource_path, expected_path)
			assert_eq(size, FONT_SIZES[percent], "%s/%d uses the exact logical glyph master" % [locale, percent])
			assert_eq(GALLERY_TYPOGRAPHY.font_size(percent), FONT_SIZES[percent])
			assert_eq(GALLERY_TYPOGRAPHY.line_height(percent), LINE_HEIGHTS[percent])
			assert_eq(GALLERY_TYPOGRAPHY.baseline(percent), ASCENTS[percent])
			assert_true(font is FontFile, "%s/%d uses one registered face directly" % [locale, percent])
			assert_false(font is FontVariation, "Gallery has no fallback or synthetic variation chain")
			if not font is FontFile: continue
			var face := font as FontFile
			assert_true(face.fallbacks.is_empty())
			assert_false(face.allow_system_fallback)
			assert_eq(face.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
			assert_eq(face.hinting, TextServer.HINTING_NONE)
			assert_eq(face.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
			assert_almost_eq(face.oversampling, 1.0, 0.001)
			assert_string_contains(font.get_font_name().to_lower(), "fusion pixel")
			assert_eq(int(font.get_font_style()), 0, "regular face has no bold or italic style bits")
			assert_eq(font.get_font_weight(), 400)
			assert_ne(font.get_string_size("iiii", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
				font.get_string_size("WWWW", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
				"Gallery face remains proportional")
			assert_eq(roundi(font.get_ascent(size)), ASCENTS[percent])
			assert_eq(roundi(font.get_descent(size)), DESCENTS[percent])
			assert_eq(roundi(font.get_height(size)), LINE_HEIGHTS[percent])
			identities[font.resource_path] = true
	assert_eq(identities.size(), 9, "each locale and native pixel master has one exact face")
	assert_null(GALLERY_TYPOGRAPHY.font("fr", 100))
	assert_null(GALLERY_TYPOGRAPHY.font("en", 110))
	assert_eq(GALLERY_TYPOGRAPHY.font_size(110), 0)
	assert_eq(GALLERY_TYPOGRAPHY.line_height(110), 0)
	assert_eq(GALLERY_TYPOGRAPHY.baseline(110), 0)

func test_actual_localized_record_captions_wrap_without_hidden_lines_or_missing_glyphs() -> void:
	for locale: String in LOCALES:
		var copies := _public_gallery_copies(locale)
		assert_gte(copies.size(), RECORD_CATALOG.TITLES.size())
		for percent: int in PERCENTS:
			var theme: Theme = GALLERY_THEME.build(locale, percent, &"after_hours")
			var label := Label.new()
			label.theme = theme
			label.language = locale.replace("_", "-")
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.max_lines_visible = -1
			label.clip_text = false
			label.size = Vector2(264, 0)
			add_child_autofree(label)
			for copy: String in copies:
				label.text = copy
				await get_tree().process_frame
				var required_height: float = ceilf(label.get_minimum_size().y / 2.0) * 2.0
				label.size.y = required_height
				assert_eq(label.get_theme_default_font_size(), FONT_SIZES[percent])
				assert_eq(label.max_lines_visible, -1)
				assert_false(label.clip_text)
				assert_eq(fmod(label.size.y, 2.0), 0.0)
				assert_lte(label.get_minimum_size().y, label.size.y)
				assert_gte(label.get_line_count(), 1)
				for character: String in copy:
					if not character.strip_edges().is_empty():
						assert_true(theme.default_font.has_char(character.unicode_at(0)),
							"%s/%d owns glyph U+%04X" % [locale, percent, character.unicode_at(0)])

func test_real_locale_transaction_reprojects_mounted_gallery_face_and_language_copy() -> void:
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("gallery-typography.memory", FILES.new())).get("ok", false))
	assert_true(profile.unlock_ending("ending.alone", "gallery-typography:fixture").get("ok", false))
	var localization := LOCALIZATION.new()
	add_child_autofree(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	var home := Button.new()
	add_child_autofree(home)
	var gallery: Control = GALLERY.instantiate()
	assert_true(gallery.configure_title_host(home, localization, profile).get("ok", false))
	add_child_autofree(gallery)
	gallery.open_in_title_host()
	for locale: String in LOCALES:
		assert_true(localization.set_locale(locale).get("ok", false))
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(localization.get_locale(), locale)
		assert_eq(profile.get_preference(&"preferences.language.primary_locale_id"), locale)
		var expected: Theme = GALLERY_THEME.build(locale, 100, &"after_hours")
		assert_eq(gallery.theme.default_font_size, FONT_SIZES[100])
		assert_eq(gallery.theme.default_font.resource_path, expected.default_font.resource_path)
		assert_eq(gallery.get_node("%ReplayStatus").language, locale.replace("_", "-"))
		assert_eq(gallery.get_node("%ReplayButton").language, locale.replace("_", "-"))
		var row: Button = gallery.get_node("%EndingTileGrid").get_child(0)
		assert_eq(row.text, localization.t("gallery.record.unavailable"))
		assert_eq(row.language, locale.replace("_", "-"))
		assert_eq(row.caption.text, row.text)
		assert_eq(row.caption.language, row.language)
		assert_eq(row.caption.get_theme_default_font().resource_path, expected.default_font.resource_path)
		assert_eq(row.caption.get_theme_default_font_size(), FONT_SIZES[100])
		assert_false(row.caption.clip_text)
		assert_eq(row.caption.max_lines_visible, -1)

func _public_gallery_copies(locale: String) -> Array[String]:
	var copies: Array[String] = []
	for record_id: String in RECORD_CATALOG.TITLES:
		var title: String = RECORD_CATALOG.title(record_id, locale)
		if not title.is_empty() and title not in copies: copies.append(title)
	assert_eq(copies.size(), RECORD_CATALOG.TITLES.size(), "%s owns all 13 public record titles" % locale)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/%s.json" % locale))
	assert_true(parsed is Dictionary)
	if not parsed is Dictionary: return copies
	for row: Variant in parsed.get("messages", []):
		if row is Dictionary and str(row.get("id", "")).begins_with("gallery."):
			var copy := str(row.get("text", ""))
			if not copy.is_empty() and copy not in copies: copies.append(copy)
	var native_copies: Array[String]
	match locale:
		"zh_CN": native_copies = ["练习", "版本 13", "开始前", "结束后"]
		"zh_HK": native_copies = ["練習", "版本 13", "開始前", "結束後"]
		_: native_copies = ["Practice", "Version 13", "Before", "After"]
	for copy: String in native_copies:
		if copy not in copies: copies.append(copy)
	return copies
