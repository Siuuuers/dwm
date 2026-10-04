extends RefCounted
## Licensed UI fonts and exact authored presentation tuples.

const PALETTE_REGISTRY := preload("res://scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd")

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")

static func build(locale: String, percent: int, palette: StringName, high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel", day: int = 1) -> Theme:
	locale = locale.replace("_","-")
	if day not in range(1, 8) or not TYPOGRAPHY.supports(locale) or percent not in [100,125,150]:
		return null
	var roles := PALETTE_REGISTRY.resolve_tinted(palette, high_contrast, colour_preset, day)
	if roles.is_empty():
		return null
	var theme := Theme.new()
	theme.default_font = TYPOGRAPHY.font(locale, percent, font_style)
	if theme.default_font == null: return null
	theme.default_font_size = TYPOGRAPHY.font_size(locale, percent, 20, font_style)
	for role: StringName in roles:
		theme.set_color(role, &"Minesweeper", roles[role])
	return theme
