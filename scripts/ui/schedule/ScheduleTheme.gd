extends RefCounted

const TYPE := &"Schedule"
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const ROLES: Array[StringName] = [&"habitat", &"face", &"paper", &"paper_ink",
	&"secondary_ink", &"ink", &"structure", &"filed", &"focus", &"paper_focus"]

static func build(palette: StringName, day: int = 1, high_contrast: bool = false,
		colour_preset: String = "standard") -> Theme:
	var authored: Dictionary = PALETTES.resolve(palette, high_contrast, colour_preset)
	if authored.is_empty() or day < 1: return null
	var tinted: Dictionary = WEEK_TINT.apply(authored, WEEK_TINT.tint_for_day(day),
		high_contrast, colour_preset)
	var result := Theme.new()
	for role: StringName in ROLES:
		result.set_color(role,TYPE,tinted[String(role)])
	return result
