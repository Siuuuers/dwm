extends RefCounted
## Shop roles project shared authored accessibility tuples onto Shop materials.
## Room materials and structure age; copy, selection and focus stay authored.

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const PALETTES := preload("res://scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd")
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
	var tint: float = (0.0 if scene else WEEK_TINT.tint_for_day(day))
	var room: Dictionary = WEEK_TINT.apply({
		"habitat": authored.habitat,
		"face": authored.controlled_face,
		"paper": authored.paper,
		"structure": authored.paper_structure,
	}, tint, high_contrast, colour_preset)
	# Laminate is a second paper-like room material. Its Day-1 primitive stays
	# separate from document paper while taking the same cold-week delta.
	var laminate: Dictionary = WEEK_TINT.apply({"paper": authored.secondary_dark_copy},
		tint, high_contrast, colour_preset)
	return {
		"habitat": room.habitat,
		"controlled_face": room.face,
		"paper": room.paper,
		"laminate": laminate.paper,
		"structure": room.structure,
		"scroll_track": room.structure,
		"primary_ink": authored.primary_paper_copy,
		"secondary_ink": authored.secondary_paper_copy,
		"primary_dark_copy": authored.primary_dark_copy,
		"secondary_dark_copy": authored.secondary_dark_copy,
		"dark_registration": authored.dark_registration,
		"scroll_thumb": authored.dark_scroll_thumb,
		"selected_plane": authored.selected_plane,
		"selected_ink": authored.selected_ink,
		"dark_focus_outer": authored.dark_focus_outer,
		"dark_focus_inner": authored.dark_focus_inner,
		"laminate_focus_outer": authored.filed_focus_outer,
		"laminate_focus_inner": authored.filed_focus_inner,
		"paper_focus_outer": authored.paper_focus_outer,
		"paper_focus_inner": authored.paper_focus_inner,
	}


static func build(locale: String, percent: int, palette: StringName, day: int = 1,
		high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> Theme:
	return _build_context(locale, percent, palette, day, high_contrast, colour_preset, font_style, false)

static func build_scene(locale: String, percent: int, palette: StringName, high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> Theme:
	return _build_context(locale, percent, palette, null, high_contrast, colour_preset, font_style, true)

static func _build_context(locale: String, percent: int, palette: StringName, day: Variant = 1, high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel", scene: bool = false) -> Theme:
	var roles: Dictionary = _resolve_context(palette, day, high_contrast, colour_preset, scene)
	if roles.is_empty() or not TYPOGRAPHY.supports(locale) \
			or percent not in [100, 125, 150]:
		return null
	var result := Theme.new()
	var primary: Font = TYPOGRAPHY.font(locale, percent, font_style)
	if primary == null: return null
	var font := FontVariation.new()
	font.base_font = primary
	var fallbacks: Array[Font] = []
	for companion_locale: String in ["en", "zh-CN", "zh-HK", "ja", "ko"]:
		var companion := TYPOGRAPHY.font(companion_locale, percent, font_style)
		if companion != primary:
			fallbacks.append(companion)
	font.fallbacks = fallbacks
	result.default_font = font
	result.default_font_size = TYPOGRAPHY.font_size(locale, percent, 20, font_style)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.set_stylebox(state, "Button", StyleBoxEmpty.new())
	for role: String in roles:
		result.set_color(role, "Shop", roles[role])
	result.set_color("font_color", "Label", roles.primary_ink)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", roles.primary_dark_copy)
	result.set_color("font_disabled_color", "Button", roles.primary_dark_copy)
	return result
