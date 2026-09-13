extends GutTest

const SHOP := preload("res://scripts/ui/shop/ShopTheme.gd")
const AUTHORED := preload("res://scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd")
const TYPE := &"Shop"
const PRESETS := ["standard", "protan", "deutan", "tritan"]
const FIXED_ROLES := ["primary_ink", "secondary_ink", "primary_dark_copy",
	"secondary_dark_copy", "dark_registration", "scroll_thumb", "selected_plane",
	"selected_ink", "dark_focus_outer", "dark_focus_inner", "laminate_focus_outer",
	"laminate_focus_inner", "paper_focus_outer", "paper_focus_inner"]


func test_day_one_standard_preserves_every_shipped_shop_literal() -> void:
	var shared := {
		"laminate": "9ea8a2", "paper": "c3baa3", "primary_dark_copy": "d8cfb7",
		"secondary_dark_copy": "9ea8a2", "dark_registration": "657d89",
		"secondary_ink": "2f2936", "selected_plane": "789083",
		"dark_focus_outer": "d8cfb7", "dark_focus_inner": "a9935f",
		"paper_focus_inner": "644000", "scroll_thumb": "d8cfb7",
	}
	for palette: StringName in [&"after_hours", &"midnight"]:
		var roles: Dictionary = SHOP.resolve(palette)
		assert_eq(roles.size(), 20)
		for role: String in shared:
			assert_eq(roles[role], Color(shared[role]), "%s/%s" % [palette, role])
		var habitat := Color("0b0d13" if palette == &"after_hours" else "0d1514")
		var face := Color("151b25" if palette == &"after_hours" else "14201d")
		for role: String in ["habitat", "laminate_focus_outer", "paper_focus_outer"]:
			assert_eq(roles[role], habitat, "%s/%s" % [palette, role])
		for role: String in ["controlled_face", "primary_ink", "structure", "scroll_track",
				"selected_ink", "laminate_focus_inner"]:
			assert_eq(roles[role], face, "%s/%s" % [palette, role])


func test_all_authored_shop_tuples_keep_drawn_copy_focus_and_state_legible_for_seven_days() -> void:
	# These pairs follow ShopApp._draw_plate/_draw_information and ShopItemBox._draw:
	# labels on laminate or paper, button/page copy on face, selected strips, focus
	# rings, card structure and the information scrollbar's thumb against its track.
	var text_pairs := [["primary_ink", "laminate"], ["primary_ink", "paper"],
		["secondary_ink", "paper"], ["primary_dark_copy", "controlled_face"],
		["secondary_dark_copy", "controlled_face"], ["selected_ink", "selected_plane"]]
	var marks := [["structure", "laminate"], ["structure", "paper"],
		["scroll_track", "laminate"], ["dark_focus_outer", "controlled_face"],
		["dark_focus_inner", "controlled_face"], ["laminate_focus_outer", "laminate"],
		["laminate_focus_inner", "laminate"], ["paper_focus_outer", "paper"],
		["paper_focus_inner", "paper"], ["scroll_thumb", "scroll_track"]]
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in PRESETS:
				var authored: Dictionary = AUTHORED.resolve(palette, high_contrast, preset)
				assert_false(authored.is_empty())
				var baseline: Dictionary = SHOP.resolve(palette, 1, high_contrast, preset)
				for day: int in range(1, 8):
					var context := "%s/%s/%s/day%d" % [palette, high_contrast, preset, day]
					var roles: Dictionary = SHOP.resolve(palette, day, high_contrast, preset)
					assert_eq(roles.size(), 20, context)
					for role: String in roles:
						var colour: Color = roles[role]
						assert_eq(colour.a, 1.0, context + "/" + role)
					for role: String in FIXED_ROLES:
						assert_eq(roles[role], baseline[role], context + "/" + role + " stays authored")
					for pair: Array in text_pairs:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]), 7.0 if high_contrast else 4.5,
							context + "/text " + str(pair))
					for pair: Array in marks:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]), 3.0,
							context + "/mark " + str(pair))
					if high_contrast:
						assert_eq(roles, baseline, context + " high contrast has zero week amplitude")
					elif day == 7:
						for room_role: String in ["habitat", "controlled_face", "paper", "laminate"]:
							assert_lt(roles[room_role].ok_hsl_l, baseline[room_role].ok_hsl_l,
								context + "/" + room_role + " ages")
						if preset != "standard":
							for cvd_role: String in ["habitat", "controlled_face", "paper", "laminate", "structure"]:
								assert_almost_eq(roles[cvd_role].ok_hsl_s, baseline[cvd_role].ok_hsl_s,
									0.01, context + "/" + cvd_role + " CVD lightness only")
							assert_eq(roles.structure, baseline.structure,
								context + " structure has only a saturation delta and stays exact")
					# Source tuples, rather than a second Shop table, own the protected colours.
					assert_eq(roles.primary_ink, authored.primary_paper_copy, context + " card ink")
					assert_eq(roles.secondary_ink, authored.secondary_paper_copy, context + " document ink")
					assert_eq(roles.selected_plane, authored.selected_plane, context + " selection")
					assert_eq(roles.dark_focus_inner, authored.dark_focus_inner, context + " focus")


func test_theme_builds_isolated_valid_tuples_and_rejects_invalid_inputs() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in PRESETS:
				for day: int in range(1, 8):
					var roles: Dictionary = SHOP.resolve(palette, day, high_contrast, preset)
					var theme: Theme = SHOP.build("zh-HK", 150, palette, day, high_contrast, preset)
					assert_not_null(theme)
					assert_eq(theme.default_font_size, 30)
					assert_eq(theme.get_color_list(TYPE).size(), roles.size())
					for role: String in roles:
						assert_eq(theme.get_color(role, TYPE), roles[role], role)
					assert_eq(theme.get_color("font_color", "Label"), roles.primary_ink)
					assert_eq(theme.get_color("font_color", "Button"), roles.primary_dark_copy)
	var first: Theme = SHOP.build("en", 100, &"after_hours")
	first.set_color("laminate", TYPE, Color.MAGENTA)
	assert_eq(SHOP.build("en", 100, &"after_hours").get_color("laminate", TYPE), Color("9ea8a2"))
	assert_eq(SHOP.resolve(&"unknown"), {})
	assert_eq(SHOP.resolve(&"after_hours", 0), {})
	assert_eq(SHOP.resolve(&"after_hours", 8), {})
	assert_eq(SHOP.resolve(&"after_hours", 3, false, "unknown"), {})
	assert_null(SHOP.build("en", 100, &"unknown"))
	assert_null(SHOP.build("en", 100, &"after_hours", 0))
	assert_null(SHOP.build("en", 100, &"after_hours", 8))
	assert_null(SHOP.build("en", 100, &"after_hours", 3, false, "unknown"))
	assert_null(SHOP.build("unknown", 100, &"after_hours"))
	assert_null(SHOP.build("en", 110, &"after_hours"))


func _contrast(first: Color, second: Color) -> float:
	var a: float = first.srgb_to_linear().get_luminance()
	var b: float = second.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
