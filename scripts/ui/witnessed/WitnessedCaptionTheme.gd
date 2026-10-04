extends RefCounted
## Caption materials only; no narrative or transport state.

const PALETTES := preload("res://scripts/ui/witnessed/WitnessedPaletteRegistry.gd")

const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")

static func build(locale: String, text_percent: int, palette: String,
		high_contrast: bool = false, colour_preset: String = "standard",
		large_targets: bool = false, day: int = 1, _dating_overlay: bool = false, font_style: String = "pixel") -> Theme:
	locale = locale.replace("_", "-")
	var roles := PALETTES.resolve_tinted(palette, high_contrast, colour_preset, day)
	if not TYPOGRAPHY.supports(locale) or text_percent not in [100, 125, 150] \
			or roles.is_empty():
		return null
	var result := Theme.new()
	result.default_font = TYPOGRAPHY.font(locale, text_percent, font_style)
	if result.default_font == null: return null
	result.default_font_size = TYPOGRAPHY.font_size(locale, text_percent, 20, font_style)
	for role: StringName in roles:
		result.set_color(role, &"WitnessedCaption", roles[role])
	for font_name: StringName in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font", &"mono_font"]:
		result.set_font(font_name, &"RichTextLabel", result.default_font)
		result.set_font_size(StringName(str(font_name) + "_size"), &"RichTextLabel", result.default_font_size)
	result.set_color(&"default_color", &"RichTextLabel", Color.WHITE)
	result.set_color(&"font_shadow_color", &"RichTextLabel", Color.TRANSPARENT)
	result.set_color(&"font_outline_color", &"RichTextLabel", Color(0.05, 0.05, 0.05, 0.9))
	result.set_constant(&"outline_size", &"RichTextLabel", 2)
	# Captions remain text over artwork in every scene.
	var leaf := StyleBoxEmpty.new()
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		leaf.set_content_margin(side, 16)
	result.set_stylebox(&"normal", &"RichTextLabel", leaf)
	result.set_stylebox(&"focus", &"RichTextLabel", StyleBoxEmpty.new())
	for variation: StringName in [&"WitnessedPrevious", &"WitnessedOldest"]:
		result.set_type_variation(variation, &"RichTextLabel")
		var retained_leaf: StyleBox = leaf.duplicate()
		result.set_stylebox(&"normal", variation, retained_leaf)
	result.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	var track := StyleBoxFlat.new()
	var target_size := 64 if large_targets else 48
	track.bg_color = roles[&"deep"]
	track.border_color = roles[&"rule"]
	track.set_border_width_all(2)
	track.content_margin_left = target_size / 2.0
	track.content_margin_right = target_size / 2.0
	# Keep the visible gutter narrow inside its full native pointer target.
	track.expand_margin_left = -(target_size - 12) / 2.0
	track.expand_margin_right = -(target_size - 12) / 2.0
	result.set_stylebox(&"scroll", &"VScrollBar", track)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = roles[&"text"]
		thumb.expand_margin_left = -(target_size - 4) / 2.0
		thumb.expand_margin_right = -(target_size - 4) / 2.0
		thumb.expand_margin_top = -4
		thumb.expand_margin_bottom = -4
		thumb.content_margin_top = target_size / 2.0
		thumb.content_margin_bottom = target_size / 2.0
		result.set_stylebox(state, &"VScrollBar", thumb)
	return result
