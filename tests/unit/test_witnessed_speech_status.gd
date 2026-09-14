extends GutTest

const OWNER_PATH := "res://scripts/ui/witnessed/WitnessedSpeechStatus.gd"
const COPY_KEY := "witnessed.speech.failed"
const CATALOG := preload("res://scripts/localization/LocalizationCatalog.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const SETTINGS_THEME := preload("res://scripts/ui/SettingsTheme.gd")
const COPY := {
	"en": "Read Aloud encountered a problem.",
	"zh-CN": "朗读遇到问题。",
	"zh-HK": "朗讀遇到問題。",
}


class FakeLocalization extends Node:
	var locale := "en"
	var messages: Dictionary = COPY.duplicate()

	func get_locale() -> String:
		return locale

	func has_key(key: String) -> bool:
		return key == COPY_KEY and messages.has(locale)

	func t(key: String, _parameters: Dictionary = {}) -> String:
		return str(messages.get(locale, "")) if key == COPY_KEY else ""


func _status() -> Label:
	assert_true(ResourceLoader.exists(OWNER_PATH, "Script"),
		"the nonmodal Witnessed speech status component must exist")
	if not ResourceLoader.exists(OWNER_PATH, "Script"):
		return null
	var status: Label = load(OWNER_PATH).new()
	add_child_autofree(status)
	return status


func _localization(locale: String) -> FakeLocalization:
	var localization := FakeLocalization.new()
	localization.locale = locale
	add_child_autofree(localization)
	return localization


func _theme(locale: String, percent: int) -> Theme:
	return CAPTION_THEME.build(locale, percent, "AfterHours")


func test_strict_catalogs_register_the_exact_failure_fact_in_all_locales() -> void:
	var loaded: Dictionary = CATALOG.load_bundle("res://localization/manifest.json")
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	var catalogs: Dictionary = loaded.value.catalogs
	for locale: String in ["en", "zh_CN", "zh_HK"]:
		var expected_locale := locale.replace("_", "-")
		var matches: Array = (catalogs[locale].messages as Array).filter(
			func(record: Dictionary) -> bool: return record.get("id") == COPY_KEY)
		assert_eq(matches.size(), 1, "%s has one strict key record" % locale)
		if matches.size() == 1:
			assert_eq(str(matches[0].text), COPY[expected_locale], locale)


func test_failure_is_a_polite_noninteractive_fact_in_every_supported_presentation() -> void:
	for row: Array in [["en", 100], ["zh-CN", 125], ["zh-HK", 150]]:
		var locale: String = row[0]
		var percent: int = row[1]
		var status := _status()
		if status == null:
			continue
		var localization := _localization(locale)
		var presentation_theme := _theme(locale, percent)
		assert_true(status.update_presentation(localization, locale,
			presentation_theme, percent), locale)
		assert_false(status.visible, "configuration does not publish a status")
		assert_eq(status.text, "")
		assert_true(status.show_failure(), locale)
		assert_true(status.visible)
		assert_eq(status.text, COPY[locale])
		assert_eq(status.accessibility_name, COPY[locale])
		assert_eq(status.accessibility_live, DisplayServer.LIVE_POLITE)
		assert_eq(status.focus_mode, Control.FOCUS_NONE)
		assert_eq(status.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(status.language, locale)
		assert_same(status.theme, presentation_theme)
		assert_eq(status.theme.default_font_size, int(20 * percent / 100.0))
		assert_eq(status.get_theme_color(&"font_color"), SETTINGS_THEME.ROLES.danger,
			"the factual error uses the registered contrast role")
		assert_eq(status.get_theme_constant(&"outline_size"), 4,
			"a bounded outline keeps the status legible over scene art")
		assert_eq(status.get_theme_color(&"font_outline_color"),
			presentation_theme.get_color(&"deep", &"WitnessedCaption"),
			"the outline uses the supplied dark witnessed role")


func test_available_error_role_is_honoured_and_clear_is_idempotent() -> void:
	var status := _status()
	if status == null:
		return
	var localization := _localization("en")
	var presentation_theme := _theme("en", 100)
	var supplied_danger := Color("f2a38d")
	presentation_theme.set_color(&"danger", &"Settings", supplied_danger)
	assert_true(status.update_presentation(localization, "en", presentation_theme, 100))
	assert_true(status.show_failure())
	assert_eq(status.get_theme_color(&"font_color"), supplied_danger)
	status.clear_status()
	status.clear_status()
	assert_false(status.visible)
	assert_eq(status.text, "")
	assert_eq(status.accessibility_name, "")
	assert_eq(status.accessibility_live, DisplayServer.LIVE_POLITE)
	assert_eq(status.focus_mode, Control.FOCUS_NONE)
	assert_eq(status.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_invalid_or_mismatched_presentation_fails_closed() -> void:
	var status := _status()
	if status == null:
		return
	var localization := _localization("en")
	assert_false(status.show_failure(), "an unconfigured status cannot publish")
	for invalid: Array in [
		[localization, "zh-CN", _theme("zh-CN", 100), 100],
		[localization, "en", null, 100],
		[localization, "en", _theme("en", 100), 200],
	]:
		assert_false(status.update_presentation(invalid[0], invalid[1], invalid[2], invalid[3]))
		assert_false(status.visible)
		assert_eq(status.text, "")
	localization.messages.clear()
	assert_false(status.update_presentation(localization, "en", _theme("en", 100), 100),
		"blank or missing copy cannot become a live-region fact")
	assert_false(status.show_failure())
	assert_false(status.visible)
	assert_eq(status.text, "")
