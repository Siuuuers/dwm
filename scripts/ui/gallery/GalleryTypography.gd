extends RefCounted

const _FONTS := {
	100: {
		"en": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-latin.otf.woff2",
		"zh-CN": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-zh_hans.otf.woff2",
		"zh-HK": "res://assets/ui/gallery/fonts/fusion-pixel-8px-proportional-zh_hant.otf.woff2",
	},
	125: {
		"en": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-latin.otf.woff2",
		"zh-CN": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-zh_hans.otf.woff2",
		"zh-HK": "res://assets/ui/gallery/fonts/fusion-pixel-10px-proportional-zh_hant.otf.woff2",
	},
	150: {
		"en": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-latin.otf.woff2",
		"zh-CN": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2",
		"zh-HK": "res://assets/ui/gallery/fonts/fusion-pixel-12px-proportional-zh_hant.otf.woff2",
	},
}

const _FONT_SIZE := {100: 16, 125: 20, 150: 24}
const _LINE_HEIGHT := {100: 24, 125: 28, 150: 32}
const _BASELINE := {100: 18, 125: 22, 150: 26}
static var _loaded: Dictionary = {}


static func font(locale: String, percent: int) -> Font:
	var locale_key := _locale_key(locale)
	if locale_key.is_empty() or not _FONTS.has(percent):
		return null
	var path: String = _FONTS[percent][locale_key]
	if not _loaded.has(path):
		# Load only the selected face. Other locale/size masters need no startup work.
		var face := load(path) as FontFile
		if face == null: return null
		face.allow_system_fallback = false
		face.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		face.hinting = TextServer.HINTING_NONE
		face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		face.oversampling = 1.0
		_loaded[path] = face
	return _loaded[path] as Font


static func font_size(percent: int) -> int:
	return int(_FONT_SIZE.get(percent, 0))


static func line_height(percent: int) -> int:
	return int(_LINE_HEIGHT.get(percent, 0))


static func baseline(percent: int) -> int:
	return int(_BASELINE.get(percent, 0))


static func _locale_key(locale: String) -> String:
	match locale.strip_edges().replace("_", "-").to_lower():
		"en": return "en"
		"zh-cn": return "zh-CN"
		"zh-hk": return "zh-HK"
		_: return ""
