extends GutTest

const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const STANDARD_SHARED := {
	"paper":"c3baa3", "primary_dark_copy":"d8cfb7", "secondary_dark_copy":"9ea8a2",
	"dark_registration":"657d89", "dark_scroll_thumb":"d8cfb7", "secondary_paper_copy":"2f2936",
	"paper_scroll_thumb":"644000", "dark_mark":"d8cfb7", "selected_plane":"789083",
	"dark_focus_outer":"d8cfb7", "dark_focus_inner":"a9935f", "paper_focus_inner":"644000",
	"technical_error":"dd7a7f",
}

func test_original_standard_roles_remain_exact() -> void:
	for palette: StringName in [&"after_hours",&"midnight"]:
		var theme: Theme = MS_THEME.build("en",100,palette)
		for role: String in STANDARD_SHARED:
			assert_eq(theme.get_color(role,"Minesweeper"),Color(STANDARD_SHARED[role]),role)
		var face := Color("151b25" if palette == &"after_hours" else "14201d")
		var habitat := Color("0b0d13" if palette == &"after_hours" else "0d1514")
		for role: String in ["controlled_face","primary_paper_copy","paper_structure","paper_mark","selected_ink","filed_focus_inner"]:
			assert_eq(theme.get_color(role,"Minesweeper"),face,role)
		for role: String in ["habitat","dark_separation","paper_focus_outer","filed_focus_outer"]:
			assert_eq(theme.get_color(role,"Minesweeper"),habitat,role)

func test_all_tuples_have_identical_role_closure_and_independent_theme_instances() -> void:
	var baseline: Theme = MS_THEME.build("en",100,&"after_hours")
	var expected_roles := baseline.get_color_list("Minesweeper")
	expected_roles.sort()
	for palette: StringName in [&"after_hours",&"midnight"]:
		for high: bool in [false,true]:
			for preset: String in ["standard","protan","deutan","tritan"]:
				var theme: Theme = MS_THEME.build("zh_HK",150,palette,high,preset)
				assert_not_null(theme)
				var actual_roles := theme.get_color_list("Minesweeper")
				actual_roles.sort()
				assert_eq(actual_roles,expected_roles,"No number or result-specific colours are introduced.")
				assert_eq(theme.default_font_size,36,"The CJK pixel family keeps its 150% size step.")
				for role: String in actual_roles:
					assert_eq(theme.get_color(role,"Minesweeper").a,1.0,role)
				var face: Color = theme.get_color("controlled_face","Minesweeper")
				theme.set_color("controlled_face","Minesweeper",Color.MAGENTA)
				assert_eq(MS_THEME.build("en",100,palette,high,preset).get_color("controlled_face","Minesweeper"),face)
	assert_eq(baseline.get_color("controlled_face","Minesweeper"),Color("151b25"))

func test_unknown_tuple_locale_or_scale_has_no_fallback() -> void:
	assert_null(MS_THEME.build("en",100,&"unknown",true,"protan"))
	assert_null(MS_THEME.build("en",100,&"after_hours",true,"unknown"))
	assert_null(MS_THEME.build("en",100,&"after_hours",false,"Protan"))
	assert_null(MS_THEME.build("unknown",100,&"after_hours",true,"standard"))
	assert_null(MS_THEME.build("en",110,&"after_hours",true,"standard"))

func test_authored_text_and_state_ink_meet_project_contrast_thresholds() -> void:
	# Numeric sRGB checks supplement actual rendered evidence; they do not establish AT usability.
	for palette: StringName in [&"after_hours",&"midnight"]:
		for high: bool in [false,true]:
			for preset: String in ["standard","protan","deutan","tritan"]:
				for day: int in range(1, 8):
					var theme: Theme = MS_THEME.build("en",100,palette,high,preset,"pixel",day)
					var context := "%s/%s/%s/day%d" % [palette,high,preset,day]
					for pair: Array in [["primary_dark_copy","controlled_face"],["secondary_dark_copy","controlled_face"],
						["primary_paper_copy","paper"],["secondary_paper_copy","paper"],["selected_ink","selected_plane"]]:
						assert_gte(_contrast(theme.get_color(pair[0],"Minesweeper"),theme.get_color(pair[1],"Minesweeper")),7.0 if high else 4.5,context+str(pair))
					for pair: Array in [["dark_registration","controlled_face"],["dark_focus_outer","habitat"],
						["dark_focus_inner","habitat"],["paper_focus_inner","paper"],["paper_focus_outer","paper"],
						["filed_focus_inner","selected_plane"],["filed_focus_outer","selected_plane"],
						["dark_mark","controlled_face"],["paper_mark","paper"],["technical_error","controlled_face"]]:
						assert_gte(_contrast(theme.get_color(pair[0],"Minesweeper"),theme.get_color(pair[1],"Minesweeper")),3.0,context+str(pair))

func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func _luminance(colour: Color) -> float:
	var linear := colour.srgb_to_linear()
	return linear.r*0.2126+linear.g*0.7152+linear.b*0.0722

func test_week_tint_preserves_day1_high_contrast_and_all_semantic_inks() -> void:
	var room_roles := ["habitat", "controlled_face", "paper", "paper_structure", "dark_separation"]
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high: bool in [false, true]:
			for preset: String in ["standard", "protan", "deutan", "tritan"]:
				var original: Theme = MS_THEME.build("en",100,palette,high,preset)
				for day: int in range(1, 8):
					var actual: Theme = MS_THEME.build("en",100,palette,high,preset,"pixel",day)
					for role: String in original.get_color_list("Minesweeper"):
						var source: Color = original.get_color(role,"Minesweeper")
						var colour: Color = actual.get_color(role,"Minesweeper")
						if day == 1 or high or role not in room_roles:
							assert_eq(colour,source,"Day 1, High Contrast and semantic inks remain exact: "+role)
						elif preset != "standard":
							assert_almost_eq(colour.ok_hsl_s,source.ok_hsl_s,0.0001,"CVD tint changes lightness only: "+role)
					if day > 1 and not high:
						assert_lt(actual.get_color("paper","Minesweeper").ok_hsl_l,original.get_color("paper","Minesweeper").ok_hsl_l)
	assert_null(MS_THEME.build("en",100,&"after_hours",false,"standard","pixel",0))
	assert_null(MS_THEME.build("en",100,&"after_hours",false,"standard","pixel",8))
