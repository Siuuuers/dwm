extends RefCounted
## The two accepted Shop Standard palettes, exposed through Shop semantic roles.

const FONTS := preload("res://scripts/ui/desktop/DesktopTheme.gd")

const SHARED := {
	"laminate": Color("9ea8a2"),
	"paper": Color("c3baa3"),
	"primary_dark_copy": Color("d8cfb7"),
	"secondary_dark_copy": Color("9ea8a2"),
	"dark_registration": Color("657d89"),
	"secondary_ink": Color("2f2936"),
	"selected_plane": Color("789083"),
	"dark_focus_outer": Color("d8cfb7"),
	"dark_focus_inner": Color("a9935f"),
	"paper_focus_inner": Color("644000"),
}
const PALETTES := {
	&"after_hours": {
		"habitat": Color("0b0d13"),
		"controlled_face": Color("151b25"),
		"primary_ink": Color("151b25"),
	},
	&"midnight": {
		"habitat": Color("0d1514"),
		"controlled_face": Color("14201d"),
		"primary_ink": Color("14201d"),
	},
}


static func resolve(palette: StringName) -> Dictionary:
	if not PALETTES.has(palette):
		return {}
	var roles: Dictionary = SHARED.duplicate()
	roles.merge(PALETTES[palette], true)
	# These distinct semantic names currently share accepted primitives.
	roles["structure"] = roles.primary_ink
	roles["scroll_track"] = roles.primary_ink
	roles["scroll_thumb"] = roles.primary_dark_copy
	roles["selected_ink"] = roles.primary_ink
	roles["laminate_focus_outer"] = roles.habitat
	roles["laminate_focus_inner"] = roles.controlled_face
	roles["paper_focus_outer"] = roles.habitat
	return roles


static func build(locale: String, percent: int, palette: StringName) -> Theme:
	var roles := resolve(palette)
	if roles.is_empty():
		return null
	var result := Theme.new()
	var primary: Font = {"en":FONTS.ENGLISH,"zh_CN":FONTS.SIMPLIFIED,"zh_HK":FONTS.TRADITIONAL}.get(locale.replace("-","_"),FONTS.ENGLISH)
	var font := FontVariation.new()
	font.base_font = primary
	var fallbacks: Array[Font] = []
	for companion: Font in [FONTS.ENGLISH,FONTS.SIMPLIFIED,FONTS.TRADITIONAL]:
		if companion != primary: fallbacks.append(companion)
	font.fallbacks = fallbacks
	result.default_font = font
	result.default_font_size = int(20 * percent / 100.0)
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		result.set_stylebox(state,"Button",StyleBoxEmpty.new())
	for role: String in roles:
		result.set_color(role, "Shop", roles[role])
	result.set_color("font_color", "Label", roles.primary_ink)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", roles.primary_dark_copy)
	result.set_color("font_disabled_color", "Button", roles.primary_dark_copy)
	return result
