extends RefCounted
## Licensed UI fonts and exact authored presentation tuples.

const PALETTE_REGISTRY := preload("res://scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd")

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")

static func build(locale: String, percent: int, palette: StringName, high_contrast: bool = false, colour_preset: String = "standard") -> Theme:
	locale = locale.replace("_","-")
	if not TYPOGRAPHY.supports(locale) or percent not in [100,125,150]:
		return null
	var roles := PALETTE_REGISTRY.resolve(palette, high_contrast, colour_preset)
	if roles.is_empty():
		return null
	var theme := Theme.new()
	theme.default_font = TYPOGRAPHY.font(locale, percent)
	theme.default_font_size = TYPOGRAPHY.font_size(locale, percent, 20)
	for role: StringName in roles:
		theme.set_color(role, &"Minesweeper", roles[role])
	return theme
