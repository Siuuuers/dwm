extends RefCounted

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const _FONT_SIZE := {100: 16, 125: 20, 150: 24}
const _LINE_HEIGHT := {100: 24, 125: 28, 150: 32}
const _BASELINE := {100: 18, 125: 22, 150: 26}


static func font(locale: String, percent: int, font_style: String = "pixel") -> Font:
	return TYPOGRAPHY.font(locale, percent, font_style)


static func font_size(percent: int) -> int:
	return int(_FONT_SIZE.get(percent, 0))


static func line_height(percent: int) -> int:
	return int(_LINE_HEIGHT.get(percent, 0))


static func baseline(percent: int) -> int:
	return int(_BASELINE.get(percent, 0))
