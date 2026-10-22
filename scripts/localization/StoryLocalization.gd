extends RefCounted
## Display-only translations. English DTL and registered save identities stay canonical.

const LOCALES := ["en", "zh_HK", "zh_CN", "ja", "ko"]
const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
static var _catalogs: Dictionary = {}

static func catalog(locale: String) -> Dictionary:
	if locale not in LOCALES: return {}
	if not _catalogs.has(locale):
		var path := "res://localization/story/%s.json" % locale
		var parsed: Dictionary = JSON_READER.parse_object(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		_catalogs[locale] = parsed.value if parsed.get("ok", false) else {}
	return _catalogs[locale]

static func has_translation(locale: String, line_id: String, source: String) -> bool:
	return locale != "en" and catalog("en").get(line_id) == source \
		and catalog(locale).get(line_id) is String and not str(catalog(locale)[line_id]).is_empty()

static func text(locale: String, line_id: String, source: String) -> String:
	return str(catalog(locale)[line_id]) if has_translation(locale, line_id, source) else source

static func project(result: Dictionary, locale: String) -> Dictionary:
	if not result.get("ok", false): return result
	var copy := result.duplicate(true)
	for row: Dictionary in copy.get("value", {}).get("captions", []):
		row.text = text(locale, str(row.get("line_id", "")), str(row.text))
	return copy

## Keep the combining marks in parsed text (and save comparisons), but draw the
## strike explicitly: cross-font shaping cannot reliably position U+0336 in CJK.
static func display_markup(source: String) -> String:
	var rendered := ""
	var striking := false
	for index in source.length():
		var character := source[index]
		var marked := character == "̶" or (index + 1 < source.length() and source[index + 1] == "̶")
		if marked != striking:
			rendered += "[s]" if marked else "[/s]"
			striking = marked
		rendered += "[lb]" if character == "[" else character
	if striking: rendered += "[/s]"
	return rendered
