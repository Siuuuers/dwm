extends "res://addons/gut/test.gd"
## Draft UI languages use real catalog/profile transactions; narrative stays English.
const MANAGER := preload("res://autoload/LocalizationManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CATALOG := preload("res://scripts/localization/LocalizationCatalog.gd")
const SCHEMA := preload("res://scripts/localization/LocalizationSchema.gd")
const ROOT := preload("res://scripts/ui/LocalePresentationRoot.gd")
const FIXTURES := preload("res://tests/unit/test_localization.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const GALLERY := preload("res://scripts/ui/gallery/GalleryTypography.gd")
const TIMELINES := preload("res://scripts/data/DialogicTimelineCatalog.gd")
const REPLIES := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const CORRESPONDENCE := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")
const WARNING_SHEET := preload("res://scripts/ui/schedule/ScheduleWarningSheet.gd")
const SCHEDULE_COPY := preload("res://scripts/ui/schedule/ScheduleCopy.gd")
const LOCALES := ["en", "zh_CN", "zh_HK", "ja", "ko"]
const MEMORY_ROOT := "japanese-korean-ui.memory"

var profile: Node
var manager: Node
var files: RefCounted

func before_each() -> void:
	files = FILES.new()
	profile = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new(MEMORY_ROOT, files)).get("ok", false))
	manager = autofree(MANAGER.new())
	assert_true(manager.initialize(profile).get("ok", false))

func test_real_registry_exposes_five_languages_with_two_selectable_drafts() -> void:
	var records: Array[Dictionary] = manager.get_selectable_locales()
	assert_eq(records.map(func(record): return record.id), LOCALES)
	for language: String in ["ja", "ko"]:
		var record: Dictionary = records.filter(func(row): return row.id == language)[0]
		assert_eq(record.release_status, "draft")
		assert_eq(record.native_name, "日本語" if language == "ja" else "한국어")
		assert_true(manager.set_locale(language).get("ok", false))
		assert_eq(manager.get_presentation_profile().font_profile, language + "_pixel")
	assert_eq(manager.prepare_locale("xx-QA-unregistered").get("code"), &"unknown_locale")

func test_both_catalogs_cover_all_300_source_ids_and_exact_placeholders() -> void:
	var loaded: Dictionary = CATALOG.load_bundle("res://localization/manifest.json")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	var source: Dictionary = SCHEMA._message_map(loaded.value.catalogs.en)
	assert_eq(source.size(), 300)
	for language: String in ["ja", "ko"]:
		var translated: Dictionary = SCHEMA._message_map(loaded.value.catalogs[language])
		assert_eq(translated.size(), source.size())
		assert_true(manager.set_locale(language).get("ok", false))
		for id: String in source:
			assert_true(translated.has(id), language + ": " + id)
			if not translated.has(id): continue
			assert_false(str(translated[id]).strip_edges().is_empty(), language + ": " + id)
			assert_eq(SCHEMA.extract_named_placeholders(translated[id]), SCHEMA.extract_named_placeholders(source[id]), id)
			var parameters := {}
			for key: String in SCHEMA.extract_named_placeholders(source[id]): parameters[key] = "7"
			var rendered: String = manager.t(id, parameters)
			assert_false(rendered.begins_with("[missing:") or rendered.begins_with("[format_error:"), id)

func test_locale_commit_signals_and_reloaded_profile_agree_for_both_drafts() -> void:
	var observations: Array = []
	manager.locale_changed.connect(func(language): observations.append([language, profile.get_preference(&"preferences.language.primary_locale_id")]))
	for language: String in ["ja", "ko"]:
		assert_true(manager.set_locale(language).get("ok", false))
		assert_eq(observations.back(), [language, language])
		var reloaded: Node = autofree(PROFILE.new())
		assert_true(reloaded.initialize(STORAGE.new(MEMORY_ROOT, files)).get("ok", false))
		var restored: Node = autofree(MANAGER.new())
		assert_true(restored.initialize(reloaded).get("ok", false))
		assert_eq(restored.get_locale(), language, "locale survives a fresh Profile/Localization lifetime")
	assert_eq(observations.size(), 2)

func test_refused_draft_presentation_rolls_back_ui_profile_and_publication() -> void:
	var first: Node = autofree(FIXTURES.FakePresentationRoot.new())
	var second: Node = autofree(FIXTURES.FakePresentationRoot.new())
	assert_true(manager.register_presentation_root(first).get("ok", false))
	assert_true(manager.register_presentation_root(second).get("ok", false))
	second.fail_apply = true
	var before: Dictionary = profile.get_profile_snapshot()
	var persisted: Dictionary = files.snapshot_persisted()
	var published: Array = []
	manager.locale_changed.connect(func(language): published.append(language))
	for language: String in ["ja", "ko"]:
		assert_eq(manager.set_locale(language).get("code"), &"root_apply_failed")
		assert_eq(first.applied_profile.locale_id, "en")
		assert_eq(profile.get_profile_snapshot(), before)
		assert_eq(files.snapshot_persisted(), persisted)
		assert_eq(manager.get_locale(), "en")
	assert_eq(published, [])

func test_five_language_round_trip_updates_real_presentation_without_losing_preferences() -> void:
	var target: Control = autofree(Control.new())
	var presentation: Node = autofree(ROOT.new())
	presentation._target = target
	presentation._localization = manager
	assert_true(manager.register_presentation_root(presentation).get("ok", false))
	var explicit_target: Control = autofree(Control.new())
	explicit_target.theme = Theme.new()
	var original_font := FontVariation.new()
	original_font.base_font = TYPOGRAPHY.ENGLISH
	original_font.variation_embolden = 0.5
	explicit_target.theme.default_font = original_font
	explicit_target.theme.default_font_size = 27
	var explicit_root: Node = autofree(ROOT.new())
	explicit_root._target = explicit_target
	explicit_root._localization = manager
	assert_true(manager.register_presentation_root(explicit_root).get("ok", false))
	assert_true(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	var sequence: Array = LOCALES + ["en", "ja", "zh_CN", "ko", "zh_HK", "en"]
	for font_style: String in ["pixel", "readable"]:
		assert_true(manager.set_font_style(font_style).get("ok", false))
		for language: String in sequence:
			assert_true(manager.set_locale(language).get("ok", false), language)
			assert_eq(manager.get_locale(), language)
			assert_eq(profile.get_preference(&"preferences.accessibility.text_size"), 150)
			assert_eq(profile.get_preference(&"preferences.accessibility.font_style"), font_style)
			assert_eq(target.layout_direction, Control.LAYOUT_DIRECTION_LTR)
			assert_false(manager.t("menu.setting").begins_with("[missing:"))
			var selected := TYPOGRAPHY.font(language, 150, font_style)
			assert_not_null(target.theme.default_font)
			assert_eq(target.theme.default_font.get_font_name(), selected.get_font_name())
			assert_true((target.theme.default_font as FontFile).data == (selected as FontFile).data,
				"The selected style and size choose the exact face, including EN and Chinese")
			assert_eq(explicit_target.theme.default_font.get_font_name(), selected.get_font_name())
			assert_eq(explicit_target.theme.default_font_size, 27, "Root typography preserves host font size")
	assert_true(manager.set_locale("ja").get("ok", false))
	var before: Dictionary = profile.get_profile_snapshot()
	var before_face: String = target.theme.default_font.get_font_name()
	var failing: Node = autofree(FIXTURES.FakePresentationRoot.new())
	assert_true(manager.register_presentation_root(failing).get("ok", false))
	failing.fail_apply = true
	assert_eq(manager.set_locale("ko").get("code"), &"root_apply_failed")
	assert_eq(profile.get_profile_snapshot(), before)
	assert_eq(manager.get_locale(), "ja")
	assert_eq(target.theme.default_font.get_font_name(), before_face, "real root rolls back its font when another root refuses")

func test_draft_story_resolution_retains_exact_english_locators_and_correspondence() -> void:
	var entries: Array[String] = TIMELINES.get_required_entry_ids()
	assert_false(entries.is_empty())
	for entry: String in entries:
		var english: Dictionary = TIMELINES.get_entry(entry, "en")
		for language: String in ["ja", "ko"]:
			var resolved: Dictionary = TIMELINES.get_entry(entry, language)
			assert_true(resolved.get("ok", false), entry)
			if not resolved.get("ok", false): continue
			assert_eq([resolved.value.path, resolved.value.label], [english.value.path, english.value.label])
			assert_eq([resolved.value.locale, resolved.value.requested_locale, resolved.value.used_fallback], ["en", language, true])
	for language: String in ["ja", "ko"]:
		for choice: String in ["a", "b", "c"]:
			var id := "reply.ordinary.lavinia.day1." + choice
			var english: Dictionary = REPLIES.reply_definition(id, "en")
			var draft: Dictionary = REPLIES.reply_definition(id, language)
			assert_true(draft.get("ok", false))
			if not draft.get("ok", false): continue
			assert_eq(draft.value.locale, language)
			for key: String in ["text", "incoming_text", "response_text"]:
				assert_eq(draft.value[key], english.value[key])
		for message: Dictionary in CORRESPONDENCE.build().values():
			assert_eq(message.texts[language], message.texts.en)
			for followup: Dictionary in message.get("hospital_followup", {}).values():
				assert_eq(followup.texts[language], followup.texts.en)

func test_fusion_fonts_contain_every_catalog_glyph_without_system_or_font_fallback() -> void:
	var loaded: Dictionary = CATALOG.load_bundle("res://localization/manifest.json")
	assert_true(loaded.get("ok", false))
	if not loaded.get("ok", false): return
	for language: String in ["ja", "ko"]:
		var characters := {}
		for message: Dictionary in loaded.value.catalogs[language].messages:
			for character: String in str(message.text):
				if not character.strip_edges().is_empty(): characters[character.unicode_at(0)] = true
		for percent: int in [100, 125, 150]:
			var font := TYPOGRAPHY.font(language, percent) as FontFile
			assert_not_null(font)
			if font == null: continue
			assert_false(font.allow_system_fallback)
			assert_true(font.fallbacks.is_empty())
			var missing: Array[String] = []
			for code: int in characters:
				if not font.has_char(code): missing.append("U+%04X" % code)
			assert_eq(missing, [], "%s %d missing catalog glyphs" % [language, percent])

func test_ui_and_gallery_use_native_pixel_masters_at_their_intended_sizes() -> void:
	for language: String in ["ja", "ko"]:
		for percent: int in [100, 125, 150]:
			var font := TYPOGRAPHY.font(language, percent) as FontFile
			assert_not_null(font)
			if font == null: continue
			assert_eq(font, GALLERY.font(language, percent))
			assert_eq(TYPOGRAPHY.font_size(language, percent, 20), int(24 * percent / 100.0))
			assert_eq(GALLERY.font_size(percent), int(16 * percent / 100.0))
			assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
			assert_eq(font.hinting, TextServer.HINTING_NONE)
			assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
			assert_eq(font.oversampling, 1.0)
			assert_true(font.resource_path.contains("fusion-pixel-%dpx-proportional-%s" % [int(8 * percent / 100.0), language]))

func test_schedule_warning_copy_and_error_body_fit_all_draft_sizes_and_target_preferences() -> void:
	var cases := 0
	var catalog: Dictionary = SCHEDULE_COPY.warning_catalog()
	for language: String in ["ja", "ko"]:
		for percent: int in [100, 125, 150]:
			for large: bool in [false, true]:
				for kind: String in catalog:
					var sheet: Control = WARNING_SHEET.new()
					add_child(sheet)
					var identity := "%s:%d:%s:%s" % [language, percent, large, kind]
					assert_true(sheet.configure(language, percent, large), identity)
					var copy: Dictionary = catalog[kind][language]
					assert_true(sheet.present(identity, copy, copy.failed_go), identity)
					await get_tree().process_frame
					for label: Label in sheet.find_children("*", "Label", true, false):
						assert_lte(label.get_minimum_size().y, label.size.y + 1, identity + ": " + label.text)
					cases += 1
					sheet.free()
	assert_eq(cases, 36)

func test_legacy_manifest_only_root_restores_original_explicit_font() -> void:
	var target: Control = autofree(Control.new())
	target.theme = Theme.new()
	var original := FontVariation.new()
	original.base_font = TYPOGRAPHY.ENGLISH
	original.variation_embolden = 0.5
	target.theme.default_font = original
	var presentation: Node = autofree(ROOT.new())
	presentation._target = target
	presentation._localization = manager
	for font_profile: String in ["ja_pixel", "ko_pixel", "project_default"]:
		var plan: Dictionary = presentation.prepare_presentation({"locale_id": "en", "font_profile": font_profile, "layout_direction": "ltr"})
		assert_true(plan.get("ok", false), str(plan))
		if not plan.get("ok", false): continue
		assert_true(presentation.apply_presentation_silent(plan.value).get("ok", false))
	var restored := target.theme.default_font as FontVariation
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.get_font_name(), original.get_font_name())
		assert_eq(restored.variation_embolden, 0.5)
