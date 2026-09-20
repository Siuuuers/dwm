extends RefCounted
## Existing UI faces stay unchanged; draft Japanese and Korean use pixel masters.

const ENGLISH := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")
const PIXEL := preload("res://scripts/ui/gallery/GalleryTypography.gd")


static func supports(locale: String) -> bool:
	return locale.replace("_", "-") in ["en", "zh-CN", "zh-HK", "ja", "ko"]


static func font(locale: String, percent: int) -> Font:
	locale = locale.replace("_", "-")
	if locale in ["ja", "ko"]:
		return PIXEL.font(locale, percent)
	return {"en": ENGLISH, "zh-CN": SIMPLIFIED, "zh-HK": TRADITIONAL}.get(locale, ENGLISH)


static func font_size(locale: String, percent: int, existing_base_size: int = 24) -> int:
	# Each pixel master is displayed at 3x in UI and 2x in the Gallery.
	var base_size := 24 if locale in ["ja", "ko"] else existing_base_size
	return int(base_size * percent / 100.0)
