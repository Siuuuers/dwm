extends RefCounted
## Licensed UI fonts and exact authored presentation tuples.

const PALETTE_REGISTRY := preload("res://scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd")

const FONTS := {
	"en": preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2"),
	"zh-CN": preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
	"zh-HK": preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf"),
}

static func build(locale: String, percent: int, palette: StringName, high_contrast: bool = false, colour_preset: String = "standard") -> Theme:
	locale = locale.replace("_","-")
	if locale not in FONTS or percent not in [100,125,150]:
		return null
	var roles := PALETTE_REGISTRY.resolve(palette, high_contrast, colour_preset)
	if roles.is_empty():
		return null
	var theme := Theme.new()
	theme.default_font = FONTS[locale]
	theme.default_font_size = int(20*percent/100.0)
	for role: StringName in roles:
		theme.set_color(role, &"Minesweeper", roles[role])
	return theme
