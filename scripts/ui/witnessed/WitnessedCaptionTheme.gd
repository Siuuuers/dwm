extends RefCounted
## Caption materials only; no narrative or transport state.

const PALETTES := preload("res://scripts/ui/witnessed/WitnessedPaletteRegistry.gd")

const FONTS := {
	"en": preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2"),
	"zh-CN": preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
	"zh-HK": preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf"),
}

static func build(locale: String, text_percent: int, palette: String, high_contrast: bool = false, colour_preset: String = "standard") -> Theme:
	locale = locale.replace("_", "-")
	var roles := PALETTES.resolve(palette, high_contrast, colour_preset)
	if locale not in FONTS or text_percent not in [100, 125, 150] \
			or roles.is_empty():
		return null
	var result := Theme.new()
	result.default_font = FONTS[locale]
	result.default_font_size = int(20 * text_percent / 100.0)
	for role: StringName in roles:
		result.set_color(role, &"WitnessedCaption", roles[role])
	for font_name: StringName in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font", &"mono_font"]:
		result.set_font(font_name, &"RichTextLabel", FONTS[locale])
		result.set_font_size(StringName(str(font_name) + "_size"), &"RichTextLabel", result.default_font_size)
	result.set_color(&"default_color", &"RichTextLabel", roles[&"text"])
	result.set_color(&"font_shadow_color", &"RichTextLabel", Color.TRANSPARENT)
	result.set_color(&"font_outline_color", &"RichTextLabel", Color.TRANSPARENT)
	result.set_constant(&"outline_size", &"RichTextLabel", 0)
	var leaf := StyleBoxFlat.new()
	leaf.bg_color = roles[&"current"]
	leaf.border_color = roles[&"rule"]
	leaf.border_width_top = 2
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		leaf.set_content_margin(side, 16)
	result.set_stylebox(&"normal", &"RichTextLabel", leaf)
	result.set_stylebox(&"focus", &"RichTextLabel", StyleBoxEmpty.new())
	for variation: StringName in [&"WitnessedPrevious", &"WitnessedOldest"]:
		result.set_type_variation(variation, &"RichTextLabel")
		var retained_leaf: StyleBoxFlat = leaf.duplicate()
		retained_leaf.bg_color = roles[&"field"] if variation == &"WitnessedPrevious" else roles[&"deep"]
		result.set_stylebox(&"normal", variation, retained_leaf)
	result.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	var track := StyleBoxFlat.new()
	track.bg_color = roles[&"deep"]
	track.border_color = roles[&"rule"]
	track.set_border_width_all(2)
	track.content_margin_left = 6
	track.content_margin_right = 6
	result.set_stylebox(&"scroll", &"VScrollBar", track)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = roles[&"text"]
		thumb.expand_margin_left = -4
		thumb.expand_margin_right = -4
		thumb.expand_margin_top = -4
		thumb.expand_margin_bottom = -4
		thumb.content_margin_top = 8
		thumb.content_margin_bottom = 8
		result.set_stylebox(state, &"VScrollBar", thumb)
	return result
