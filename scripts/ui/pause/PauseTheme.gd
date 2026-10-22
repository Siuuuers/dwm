extends RefCounted

const PALETTES := preload("res://scripts/ui/pause/PausePaletteRegistry.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")

static func build(locale: String, percent: int, palette: String = "AfterHours", high_contrast: bool = false, colour_preset: String = "standard", day: int = 1, font_style: String = "pixel") -> Theme:
	if not TYPOGRAPHY.supports(locale) or percent not in [100,125,150] or day < 1 or day > 7: return null
	var palette_id: String = {"AfterHours":"after_hours","Midnight":"midnight"}.get(palette,"")
	var roles: Dictionary = PALETTES.resolve(StringName(palette_id),high_contrast,colour_preset)
	if roles.is_empty(): return null
	roles = WEEK_TINT.apply(roles, WEEK_TINT.tint_for_day(day), high_contrast, colour_preset)
	var result := Theme.new()
	result.default_font = TYPOGRAPHY.font(locale, percent, font_style)
	if result.default_font == null: return null
	result.default_font_size = TYPOGRAPHY.font_size(locale, percent, 24, font_style)
	for role: String in roles: result.set_color(role,&"Pause",roles[role])
	result.set_color(&"warning",&"Pause",roles.focus)
	result.set_color(&"font_color",&"Label",roles.ink)
	result.set_color(&"font_outline_color",&"Label",Color.TRANSPARENT)
	return result
