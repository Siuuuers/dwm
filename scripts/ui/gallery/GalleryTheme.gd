extends RefCounted

const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const TYPOGRAPHY := preload("res://scripts/ui/gallery/GalleryTypography.gd")

static func build(locale: String, percent: int, palette: StringName) -> Theme:
	var roles: Dictionary = PALETTES.resolve(palette, false, "standard")
	var result := Theme.new()
	result.default_font = TYPOGRAPHY.font(locale, percent)
	result.default_font_size = TYPOGRAPHY.font_size(percent)
	result.set_constant("line_spacing", "Label", 0)
	result.set_constant("paragraph_spacing", "Label", 0)
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
