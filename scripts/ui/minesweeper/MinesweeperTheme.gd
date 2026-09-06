extends RefCounted
## Minesweeper's two accepted Standard palettes and licensed UI fonts.

const FONTS := {
	"en": preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2"),
	"zh-CN": preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf"),
	"zh-HK": preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf"),
}
const SHARED := {
	&"paper":Color("c3baa3"), &"primary_dark_copy":Color("d8cfb7"), &"secondary_dark_copy":Color("9ea8a2"),
	&"dark_registration":Color("657d89"), &"dark_scroll_thumb":Color("d8cfb7"), &"secondary_paper_copy":Color("2f2936"),
	&"paper_scroll_thumb":Color("644000"), &"dark_mark":Color("d8cfb7"), &"selected_plane":Color("789083"),
	&"dark_focus_outer":Color("d8cfb7"), &"dark_focus_inner":Color("a9935f"), &"paper_focus_inner":Color("644000"),
	&"technical_error":Color("dd7a7f"),
}
const PALETTES := {
	&"after_hours":{&"habitat":Color("0b0d13"),&"controlled_face":Color("151b25"),&"primary_paper_copy":Color("151b25")},
	&"midnight":{&"habitat":Color("0d1514"),&"controlled_face":Color("14201d"),&"primary_paper_copy":Color("14201d")},
}

static func build(locale: String, percent: int, palette: StringName) -> Theme:
	locale = locale.replace("_","-")
	if locale not in FONTS or percent not in [100,125,150] or not PALETTES.has(palette): return null
	var theme := Theme.new()
	theme.default_font = FONTS[locale]
	theme.default_font_size = int(20*percent/100.0)
	for role: StringName in SHARED: theme.set_color(role,&"Minesweeper",SHARED[role])
	for role: StringName in PALETTES[palette]: theme.set_color(role,&"Minesweeper",PALETTES[palette][role])
	var contextual: Color = PALETTES[palette].primary_paper_copy
	for role: StringName in [&"paper_structure",&"paper_mark",&"selected_ink"]: theme.set_color(role,&"Minesweeper",contextual)
	theme.set_color(&"dark_separation",&"Minesweeper",PALETTES[palette].habitat)
	theme.set_color(&"paper_focus_outer",&"Minesweeper",PALETTES[palette].habitat)
	theme.set_color(&"filed_focus_outer",&"Minesweeper",PALETTES[palette].habitat)
	theme.set_color(&"filed_focus_inner",&"Minesweeper",PALETTES[palette].controlled_face)
	return theme
