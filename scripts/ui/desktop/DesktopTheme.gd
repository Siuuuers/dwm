extends RefCounted

const ENGLISH := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")

static func build(locale: String, percent: int, palette: StringName = &"after_hours", week_tint: float = 0.0,
		high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> Theme:
	if palette not in [&"after_hours", &"midnight"]: return null
	var tuple: Dictionary = PALETTES.resolve(palette, high_contrast, colour_preset)
	if tuple.is_empty(): return null
	var result := Theme.new()
	result.default_font = TYPOGRAPHY.font(locale, percent, font_style)
	if result.default_font == null: return null
	result.default_font_size = TYPOGRAPHY.font_size(locale, percent, 24, font_style)
	var roles := {"habitat": tuple.habitat, "face": tuple.face, "ink": tuple.ink,
		"structure": tuple.structure, "focus": tuple.focus, "current": tuple.filed}
	roles = WEEK_TINT.apply(roles, week_tint, high_contrast, colour_preset)
	for role in roles:
		result.set_color(role, "Desktop", roles[role])
	result.set_color("font_color", "Label", roles.ink)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = roles.current if state == "disabled" else roles.face
		style.border_color = roles.ink if state == "pressed" else roles.structure
		style.set_border_width_all(2 if state in ["pressed", "hover"] else 0)
		result.set_stylebox(state, "Button", style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", roles.ink)
	result.set_color("font_disabled_color", "Button", roles.face)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = roles.focus
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	return result
