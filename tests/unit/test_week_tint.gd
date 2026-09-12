extends "res://addons/gut/test.gd"

const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const REGISTRY := preload("res://scripts/settings/SettingsPaletteRegistry.gd")


func test_curve_is_zero_on_day_one_and_one_on_day_seven() -> void:
	assert_eq(WEEK_TINT.tint_for_day(1), 0.0)
	assert_eq(WEEK_TINT.tint_for_day(7), 1.0)
	assert_eq(WEEK_TINT.tint_for_day(0), 0.0, "before the week clamps to Day 1")
	assert_eq(WEEK_TINT.tint_for_day(9), 1.0, "after the week clamps to Day 7")
	assert_almost_eq(WEEK_TINT.tint_for_day(2), 0.08, 0.0001)
	assert_almost_eq(WEEK_TINT.tint_for_day(4), 0.38, 0.0001)
	assert_almost_eq(WEEK_TINT.tint_for_day(6), 0.80, 0.0001)
	var previous := -1.0
	for day: int in range(1, 8):
		var tint: float = WEEK_TINT.tint_for_day(day)
		assert_gt(tint, previous, "curve is strictly increasing at day %d" % day)
		previous = tint


func test_tint_zero_returns_identical_colours() -> void:
	var roles: Dictionary = REGISTRY.resolve(&"after_hours", false, "standard")
	var tinted: Dictionary = WEEK_TINT.apply(roles, 0.0)
	assert_eq(tinted.size(), roles.size())
	for role: String in roles:
		assert_eq(tinted[role], roles[role], role)


func test_tint_one_darkens_only_room_roles_and_keeps_hue() -> void:
	var roles: Dictionary = REGISTRY.resolve(&"after_hours", false, "standard")
	var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0)
	for role: String in ["face", "habitat", "paper"]:
		assert_lt(tinted[role].ok_hsl_l, roles[role].ok_hsl_l, role + " lightness drops")
		assert_almost_eq(tinted[role].ok_hsl_h, roles[role].ok_hsl_h, 0.02, role + " hue is kept")
	assert_lt(tinted["structure"].ok_hsl_s, roles["structure"].ok_hsl_s, "structure loses saturation")
	assert_almost_eq(tinted["face"].ok_hsl_l, roles["face"].ok_hsl_l - 0.05, 0.003, "face cold endpoint is L -0.05")
	for role: String in ["ink", "paper_ink", "focus", "paper_focus", "danger", "destructive", "filed", "secondary_dark_ink"]:
		assert_eq(tinted[role], roles[role], role + " is not a room role")


func test_partial_tint_lands_between_the_endpoints() -> void:
	var roles: Dictionary = REGISTRY.resolve(&"midnight", false, "standard")
	var half: Dictionary = WEEK_TINT.apply(roles, 0.5)
	var full: Dictionary = WEEK_TINT.apply(roles, 1.0)
	assert_lt(half["face"].ok_hsl_l, roles["face"].ok_hsl_l)
	assert_gt(half["face"].ok_hsl_l, full["face"].ok_hsl_l)


func test_high_contrast_has_zero_amplitude() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var roles: Dictionary = REGISTRY.resolve(palette, true, "standard")
		var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0, true, "standard")
		for role: String in roles:
			assert_eq(tinted[role], roles[role], "%s %s" % [palette, role])


func test_cvd_presets_change_lightness_only() -> void:
	for preset: String in ["protan", "deutan", "tritan"]:
		var roles: Dictionary = REGISTRY.resolve(&"after_hours", false, preset)
		var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0, false, preset)
		assert_lt(tinted["paper"].ok_hsl_l, roles["paper"].ok_hsl_l, preset + " paper darkens")
		assert_almost_eq(tinted["paper"].ok_hsl_s, roles["paper"].ok_hsl_s, 0.01, preset + " paper keeps saturation")
		assert_eq(tinted["structure"], roles["structure"], preset + " structure has only a saturation delta, so it stays exact")


func test_apply_does_not_mutate_input_and_ignores_foreign_keys() -> void:
	var roles := {"habitat": Color("0b0d13"), "current": Color("789083"), "label": "not a colour"}
	var before: Color = roles["habitat"]
	var tinted: Dictionary = WEEK_TINT.apply(roles, 0.5)
	assert_eq(roles["habitat"], before, "input dictionary is untouched")
	assert_ne(tinted["habitat"], before, "output habitat is tinted")
	assert_eq(tinted["current"], Color("789083"), "non-room colour keys pass through")
	assert_eq(tinted["label"], "not a colour", "non-colour values pass through")
	assert_eq(tinted["habitat"].a, 1.0, "alpha is preserved")


func test_text_contrast_holds_at_the_cold_endpoint() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var roles: Dictionary = REGISTRY.resolve(palette, false, "standard")
		var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0)
		assert_gt(_contrast(tinted["paper_ink"], tinted["paper"]), 4.5, str(palette) + " paper")
		assert_gt(_contrast(tinted["ink"], tinted["face"]), 4.5, str(palette) + " face")


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
