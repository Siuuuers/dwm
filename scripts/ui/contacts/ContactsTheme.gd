extends RefCounted
## Contacts' material projection of the authored Settings tuples.
## Room planes age; copy, identity, selection, focus, and marks stay authored.

const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")


static func resolve(palette: StringName, day: int = 1, high_contrast: bool = false,
		colour_preset: String = "standard") -> Dictionary:
	return _resolve_context(palette, day, high_contrast, colour_preset, false)

static func resolve_scene(palette: StringName, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary:
	return _resolve_context(palette, null, high_contrast, colour_preset, true)

static func _resolve_context(palette: StringName, day: Variant = 1, high_contrast: bool = false, colour_preset: String = "standard", scene: bool = false) -> Dictionary:
	if not scene and (day < 1 or day > 7):
		return {}
	var authored: Dictionary = PALETTES.resolve(palette, high_contrast, colour_preset)
	if authored.is_empty():
		return {}
	var room: Dictionary = WEEK_TINT.apply({
		"face": authored.face,
		"paper": authored.paper,
		"inward_preview": authored.inward_preview,
	}, (0.0 if scene else WEEK_TINT.tint_for_day(day)), high_contrast, colour_preset)
	return {
		"ink": authored.paper_ink,
		"instrument": room.face,
		"bone": authored.ink,
		"paper": room.paper,
		"plum": room.inward_preview,
		"filed": authored.filed,
		# Identity slits sit on invariant Void, including in Midnight.
		"void": Color("0b0d13"),
		"gold": authored.focus,
		"identity_0": Color("756477"),
		"identity_1": authored.structure,
		"identity_2": Color("4f665c"),
		# A state mark, not the aging document plane.
		"paper_mark": authored.paper,
	}


static func build(font: Font, font_size: int, palette: StringName = &"after_hours",
		day: int = 1, high_contrast: bool = false, colour_preset: String = "standard") -> Theme:
	return _build_context(font, font_size, palette, day, high_contrast, colour_preset, false)

static func build_scene(font: Font, font_size: int, palette: StringName = &"after_hours", high_contrast: bool = false, colour_preset: String = "standard") -> Theme:
	return _build_context(font, font_size, palette, null, high_contrast, colour_preset, true)

static func _build_context(font: Font, font_size: int, palette: StringName = &"after_hours", day: Variant = 1, high_contrast: bool = false, colour_preset: String = "standard", scene: bool = false) -> Theme:
	var roles: Dictionary = _resolve_context(palette, day, high_contrast, colour_preset, scene)
	if font == null or font_size <= 0 or roles.is_empty():
		return null
	var result := Theme.new()
	result.default_font = font
	result.default_font_size = font_size
	for role: String in roles:
		result.set_color(role, "Contacts", roles[role])
	result.set_font("font", "Label", font)
	result.set_font_size("font_size", "Label", font_size)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = roles.ink
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "ScrollContainer", focus)
	return result
