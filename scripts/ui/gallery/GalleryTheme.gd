extends RefCounted

const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const FONTS := preload("res://scripts/ui/desktop/DesktopTheme.gd")

static func build(locale: String, percent: int, palette: StringName) -> Theme:
	var roles: Dictionary = PALETTES.resolve(palette, false, "standard")
	var result := Theme.new()
	var primary: Font = {"en": FONTS.ENGLISH, "zh_CN": FONTS.SIMPLIFIED, "zh_HK": FONTS.TRADITIONAL}.get(locale.replace("-", "_"), FONTS.ENGLISH)
	var font := FontVariation.new()
	font.base_font = primary
	var fallbacks: Array[Font] = []
	for companion: Font in [FONTS.ENGLISH, FONTS.SIMPLIFIED, FONTS.TRADITIONAL]:
		if companion != primary: fallbacks.append(companion)
	font.fallbacks = fallbacks
	result.default_font = font
	result.default_font_size = int(24 * percent / 100.0)
	for role: String in roles: result.set_color(role, "Gallery", roles[role])
	result.set_color("error_rule", "Gallery", roles.danger)
	result.set_color("error_ink", "Gallery", roles.ink)
	result.set_color("information_rule", "Gallery", roles.structure)
	result.set_color("font_color", "Label", roles.paper_ink)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.set_stylebox(state, "Button", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		result.set_color(state, "Button", roles.ink)
	return result
