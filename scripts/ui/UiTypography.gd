extends RefCounted
## Explicit font selection shared by UI and Gallery; only resource faces are cached.

const ENGLISH := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")
const _READABLE_FONTS := {
	"en": "res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2",
	"zh-CN": "res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf",
	"zh-HK": "res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf",
	"ja": "res://assets/ui/contacts/fonts/source-han-sans-jp-regular.otf",
	"ko": "res://assets/ui/contacts/fonts/source-han-sans-kr-regular.otf",
}

const _PIXEL_FONTS := {
	100: {
		"en": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-latin.otf.woff2",
		"zh-CN": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-zh_hans.otf.woff2",
		"zh-HK": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-zh_hant.otf.woff2",
		"ja": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-ja.otf.woff2",
		"ko": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-ko.otf.woff2",
	},
	125: {
		"en": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-latin.otf.woff2",
		"zh-CN": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-zh_hans.otf.woff2",
		"zh-HK": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-zh_hant.otf.woff2",
		"ja": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-ja.otf.woff2",
		"ko": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-ko.otf.woff2",
	},
	150: {
		"en": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-latin.otf.woff2",
		"zh-CN": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2",
		"zh-HK": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-zh_hant.otf.woff2",
		"ja": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-ja.otf.woff2",
		"ko": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-ko.otf.woff2",
	},
}

static var _loaded: Dictionary = {}


static func supports(locale: String) -> bool:
	return not _locale_key(locale).is_empty()


static func font(locale: String, percent: int, font_style: String = "pixel") -> Font:
	var locale_key := _locale_key(locale)
	if locale_key.is_empty() or not _PIXEL_FONTS.has(percent) or font_style not in ["pixel", "readable"]:
		return null
	var path: String = _PIXEL_FONTS[percent][locale_key] if font_style == "pixel" else _READABLE_FONTS[locale_key]
	if not _loaded.has(path):
		var face := load(path) as FontFile
		if face == null: return null
		if font_style == "pixel":
			face.allow_system_fallback = false
			face.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			face.hinting = TextServer.HINTING_NONE
			face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			face.oversampling = 1.0
		_loaded[path] = face
	return _loaded[path] as Font


static func font_size(locale: String, percent: int, existing_base_size: int = 24, font_style: String = "pixel") -> int:
	if not supports(locale) or not _PIXEL_FONTS.has(percent) or font_style not in ["pixel", "readable"]:
		return 0
	# Each pixel master is displayed at 3x in UI and 2x in the Gallery.
	var base_size := 24 if font_style == "pixel" else existing_base_size
	return int(base_size * percent / 100.0)


static func _locale_key(locale: String) -> String:
	match locale.strip_edges().replace("_", "-").to_lower():
		"en": return "en"
		"zh-cn": return "zh-CN"
		"zh-hk": return "zh-HK"
		"ja": return "ja"
		"ko": return "ko"
		_: return ""
