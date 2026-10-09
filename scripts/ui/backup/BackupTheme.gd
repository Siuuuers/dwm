extends RefCounted

const DESKTOP := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const ROLES := ["habitat", "face", "paper", "paper_ink", "ink", "structure",
	"filed", "focus", "paper_focus", "danger", "destructive"]

static func build(locale: String, percent: int, palette: StringName = &"after_hours", day: int = 1,
		high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> Theme:
	return _build_context(locale, percent, palette, day, high_contrast, colour_preset, font_style, false)

static func build_scene(locale: String, percent: int, palette: StringName = &"after_hours", high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> Theme:
	return _build_context(locale, percent, palette, null, high_contrast, colour_preset, font_style, true)

static func _build_context(locale: String, percent: int, palette: StringName = &"after_hours", day: Variant = 1, high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel", scene: bool = false) -> Theme:
	if not scene and (day < 1 or day > 7):
		return null
	var authored: Dictionary = PALETTES.resolve(palette, high_contrast, colour_preset)
	if authored.is_empty():
		return null
	var tint: float = (0.0 if scene else WEEK_TINT.tint_for_day(day))
	var result: Theme = DESKTOP.build(locale, percent, palette, tint, high_contrast, colour_preset, font_style)
	if result == null:
		return null
	var roles: Dictionary = WEEK_TINT.apply(authored, tint, high_contrast, colour_preset)
	for role: String in ROLES:
		result.set_color(role, "Backup", roles[role])
	return result
