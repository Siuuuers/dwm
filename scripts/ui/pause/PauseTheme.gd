extends RefCounted

const PALETTES := preload("res://scripts/ui/pause/PausePaletteRegistry.gd")
const FONTS := {
	"en":preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2"),
	"zh-CN":preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
	"zh-HK":preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf"),
}

static func build(locale: String, percent: int, palette: String = "AfterHours", high_contrast: bool = false, colour_preset: String = "standard") -> Theme:
	if not FONTS.has(locale) or percent not in [100,125,150]: return null
	var palette_id: String = {"AfterHours":"after_hours","Midnight":"midnight"}.get(palette,"")
	var roles: Dictionary = PALETTES.resolve(StringName(palette_id),high_contrast,colour_preset)
	if roles.is_empty(): return null
	var result := Theme.new()
	result.default_font = FONTS[locale]
	result.default_font_size = int(24*percent/100.0)
	for role: String in roles: result.set_color(role,&"Pause",roles[role])
	result.set_color(&"warning",&"Pause",roles.focus)
	result.set_color(&"font_color",&"Label",roles.ink)
	result.set_color(&"font_outline_color",&"Label",Color.TRANSPARENT)
	return result
