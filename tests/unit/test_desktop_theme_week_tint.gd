extends "res://addons/gut/test.gd"

const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")


func test_default_tint_keeps_shipped_day_one_colours() -> void:
	var implicit := DESKTOP_THEME.build("en", 100, &"after_hours")
	assert_eq(implicit.get_color("face", "Desktop"), Color("151b25"))
	assert_eq(implicit.get_color("habitat", "Desktop"), Color("0b0d13"))
	var explicit := DESKTOP_THEME.build("en", 100, &"after_hours", WEEK_TINT.tint_for_day(1))
	assert_eq(explicit.get_color("face", "Desktop"), Color("151b25"))
	var midnight := DESKTOP_THEME.build("en", 100, &"midnight", 0.0)
	assert_eq(midnight.get_color("face", "Desktop"), Color("14201d"))
	assert_eq(midnight.get_color("habitat", "Desktop"), Color("0d1514"))


func test_day_seven_tint_darkens_room_roles_only() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var day_one := DESKTOP_THEME.build("en", 100, palette, WEEK_TINT.tint_for_day(1))
		var day_seven := DESKTOP_THEME.build("en", 100, palette, WEEK_TINT.tint_for_day(7))
		for role: String in ["face", "habitat"]:
			assert_lt(day_seven.get_color(role, "Desktop").ok_hsl_l, day_one.get_color(role, "Desktop").ok_hsl_l, "%s %s" % [palette, role])
		assert_lt(day_seven.get_color("structure", "Desktop").ok_hsl_s, day_one.get_color("structure", "Desktop").ok_hsl_s, "%s structure" % palette)
		for role: String in ["ink", "focus", "current"]:
			assert_eq(day_seven.get_color(role, "Desktop"), day_one.get_color(role, "Desktop"), "%s %s" % [palette, role])
		assert_eq(day_seven.get_color("font_color", "Label"), day_one.get_color("font_color", "Label"))
		assert_eq(day_seven.default_font_size, day_one.default_font_size)


func test_button_styleboxes_follow_the_tinted_face() -> void:
	var day_seven := DESKTOP_THEME.build("en", 100, &"after_hours", 1.0)
	var normal: StyleBoxFlat = day_seven.get_stylebox("normal", "Button")
	assert_eq(normal.bg_color, day_seven.get_color("face", "Desktop"))
	assert_ne(normal.bg_color, Color("151b25"))
	var focus: StyleBoxFlat = day_seven.get_stylebox("focus", "Button")
	assert_eq(focus.border_color, Color("a9935f"), "focus outline never tints")


func test_unknown_palette_still_returns_null() -> void:
	assert_null(DESKTOP_THEME.build("en", 100, &"unknown", 1.0))
	assert_null(DESKTOP_THEME.build("en", 100, &"midnight", 1.0, false, "unknown"))


func test_authored_accessibility_tuples_keep_identity_and_contrast_through_the_week() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high: bool in [false, true]:
			for preset: String in ["standard", "protan", "deutan", "tritan"]:
				var base: Dictionary = PALETTES.resolve(palette, high, preset)
				for day: int in range(1, 8):
					var built: Theme = DESKTOP_THEME.build("en", 100, palette, WEEK_TINT.tint_for_day(day), high, preset)
					assert_not_null(built)
					if built == null: continue
					var face: Color = built.get_color("face", "Desktop")
					for role: String in ["face", "habitat", "structure"]:
						var color: Color = built.get_color(role, "Desktop")
						if high or day == 1:
							assert_eq(color, base[role], "%s %s %s day %d" % [palette, high, preset, day])
						elif preset != "standard":
							assert_almost_eq(color.ok_hsl_s, base[role].ok_hsl_s, 0.01)
							assert_almost_eq(color.ok_hsl_h, base[role].ok_hsl_h, 0.02)
							if role == "structure": assert_eq(color, base[role])
					for role: String in ["ink", "focus"]:
						assert_eq(built.get_color(role, "Desktop"), base[role])
					assert_eq(built.get_color("current", "Desktop"), base.filed)
					var ink_l: float = base.ink.srgb_to_linear().get_luminance()
					var face_l: float = face.srgb_to_linear().get_luminance()
					assert_gt((ink_l + 0.05) / (face_l + 0.05), 4.5)
