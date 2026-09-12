extends GutTest

const PALETTES := preload("res://scripts/ui/witnessed/WitnessedPaletteRegistry.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const PRESETS := ["standard", "protan", "deutan", "tritan"]
const PROTECTED := [&"text", &"focus_outer", &"focus_inner"]
const ROOM := [&"field", &"deep", &"current", &"rule"]


func test_day_one_standard_retains_every_shipped_caption_literal() -> void:
	var shared := {&"current": "2f2936", &"text": "d8cfb7",
		&"focus_outer": "d8cfb7", &"rule": "657d89", &"focus_inner": "a9935f"}
	for palette: String in ["AfterHours", "Midnight"]:
		var expected: Dictionary = PALETTES.resolve(palette, false, "standard")
		var day_one: Dictionary = PALETTES.resolve_tinted(palette, false, "standard")
		assert_eq(day_one, expected, palette + " original literal resolver")
		assert_eq(day_one.size(), 7)
		for role: StringName in shared:
			assert_eq(day_one[role], Color(shared[role]), palette + "/" + str(role))
		assert_eq(day_one[&"field"], Color("151b25" if palette == "AfterHours" else "14201d"))
		assert_eq(day_one[&"deep"], Color("0b0d13" if palette == "AfterHours" else "0d1514"))
		assert_eq(CAPTION_THEME.build("en", 100, palette).get_color(&"field", &"WitnessedCaption"),
			day_one[&"field"], "old six-argument construction remains Day 1")


func test_all_sixteen_tuples_and_seven_days_keep_actual_caption_pairs_legible() -> void:
	# Current text sits on current; retained leaves sit on field/deep. Rules
	# border each leaf and the field seam; focus rails frame the current leaf.
	# The shared scrollbar uses text on deep and a rule-bordered deep track.
	var text_pairs := [[&"text", &"current"], [&"text", &"field"], [&"text", &"deep"]]
	var mark_pairs := [[&"rule", &"current"], [&"rule", &"field"], [&"rule", &"deep"]]
	var focus_pairs := [[&"focus_outer", &"current"], [&"focus_inner", &"current"]]
	for palette: String in ["AfterHours", "Midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in PRESETS:
				var authored: Dictionary = PALETTES.resolve(palette, high_contrast, preset)
				assert_eq(authored.size(), 7)
				for day: int in range(1, 8):
					var context := "%s/%s/%s/day%d" % [palette, high_contrast, preset, day]
					var roles: Dictionary = PALETTES.resolve_tinted(palette, high_contrast, preset, day)
					assert_eq(roles.size(), 7, context)
					if day == 1:
						assert_eq(roles, authored, context + " keeps every literal tuple colour")
					for role: StringName in roles:
						var colour: Color = roles[role]
						assert_eq(colour.a, 1.0, context + "/" + str(role))
					for protected_role: StringName in PROTECTED:
						assert_eq(roles[protected_role], authored[protected_role],
							context + "/" + str(protected_role) + " remains authored")
					for pair: Array in text_pairs:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]),
							7.0 if high_contrast else 4.5, context + "/text " + str(pair))
					for pair: Array in mark_pairs:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]), 3.0,
							context + "/rule " + str(pair))
					for pair: Array in focus_pairs:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]), 4.5,
							context + "/focus " + str(pair))
					if high_contrast:
						assert_eq(roles, authored, context + " high contrast has zero week amplitude")
					elif day == 7:
						for room_role: StringName in [&"field", &"deep", &"current"]:
							assert_lt(roles[room_role].ok_hsl_l, authored[room_role].ok_hsl_l,
								context + "/" + str(room_role) + " ages")
						if preset != "standard":
							for cvd_role: StringName in ROOM:
								assert_almost_eq(roles[cvd_role].ok_hsl_s, authored[cvd_role].ok_hsl_s,
									0.01, context + "/" + str(cvd_role) + " CVD lightness only")
							assert_eq(roles[&"rule"], authored[&"rule"],
								context + " structure has no lightness delta")


func test_theme_projects_tinted_roles_without_changing_metrics_or_state_geometry() -> void:
	for palette: String in ["AfterHours", "Midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in PRESETS:
				for day: int in range(1, 8):
					var roles: Dictionary = PALETTES.resolve_tinted(palette, high_contrast, preset, day)
					var theme: Theme = CAPTION_THEME.build("zh-HK", 150, palette,
						high_contrast, preset, false, day)
					assert_not_null(theme)
					assert_eq(theme.default_font_size, 30)
					assert_eq(theme.get_color_list(&"WitnessedCaption").size(), 7)
					for role: StringName in roles:
						assert_eq(theme.get_color(role, &"WitnessedCaption"), roles[role], str(role))
					assert_eq(theme.get_color(&"default_color", &"RichTextLabel"), roles[&"text"])
					var current := theme.get_stylebox(&"normal", &"RichTextLabel") as StyleBoxFlat
					var previous := theme.get_stylebox(&"normal", &"WitnessedPrevious") as StyleBoxFlat
					var oldest := theme.get_stylebox(&"normal", &"WitnessedOldest") as StyleBoxFlat
					assert_eq(current.bg_color, roles[&"current"])
					assert_eq(previous.bg_color, roles[&"field"])
					assert_eq(oldest.bg_color, roles[&"deep"])
					assert_eq(current.border_color, roles[&"rule"])
					var track := theme.get_stylebox(&"scroll", &"VScrollBar") as StyleBoxFlat
					assert_eq(track.bg_color, roles[&"deep"])
					assert_eq(track.border_color, roles[&"rule"])
	assert_eq(PALETTES.resolve_tinted("unknown", false, "standard"), {})
	assert_eq(PALETTES.resolve_tinted("AfterHours", false, "unknown"), {})
	assert_eq(PALETTES.resolve_tinted("AfterHours", false, "standard", 0), {})
	assert_eq(PALETTES.resolve_tinted("AfterHours", false, "standard", 8), {})
	assert_null(CAPTION_THEME.build("en", 100, "AfterHours", false, "standard", false, 0))
	assert_null(CAPTION_THEME.build("en", 100, "AfterHours", false, "standard", false, 8))
	assert_null(CAPTION_THEME.build("en", 100, "unknown"))
	assert_null(CAPTION_THEME.build("en", 100, "AfterHours", false, "unknown"))
	assert_null(CAPTION_THEME.build("unknown", 100, "AfterHours"))
	assert_null(CAPTION_THEME.build("en", 110, "AfterHours"))


func _contrast(first: Color, second: Color) -> float:
	var a: float = first.srgb_to_linear().get_luminance()
	var b: float = second.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
