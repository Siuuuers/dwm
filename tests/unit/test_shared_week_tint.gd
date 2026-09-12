extends GutTest
## Both shared hosts consume the same registered room tint without changing the
## authored Day 1 tuples or the semantic marks carried across the week.

const SETTINGS := preload("res://scripts/ui/SettingsTheme.gd")
const PAUSE := preload("res://scripts/ui/pause/PauseTheme.gd")
const REGISTRY := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const ROOM := ["habitat", "face", "paper", "structure", "secondary_ink", "inward_preview"]
const TEXT_PAIRS := [["paper", "paper_ink"], ["face", "ink"], ["paper", "secondary_ink"]]
const MARK_PAIRS := [["face", "structure"], ["face", "focus"], ["paper", "paper_focus"], ["face", "filed"]]


func test_all_sixteen_tuples_share_seven_day_room_projection_and_keep_required_contrast() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in ["standard", "protan", "deutan", "tritan"]:
				var authored: Dictionary = REGISTRY.resolve(palette, high_contrast, preset)
				assert_eq(authored.size(), 14)
				for day: int in range(1, 8):
					var context := "%s %s %s Day %d" % [palette, "high" if high_contrast else "standard", preset, day]
					var settings: Theme = SETTINGS.build("en", 100, palette, high_contrast, preset, day)
					var pause: Theme = PAUSE.build("en", 100, "Midnight" if palette == &"midnight" else "AfterHours", high_contrast, preset, day)
					assert_not_null(settings, context)
					assert_not_null(pause, context)
					if settings == null or pause == null: continue
					for role: String in authored:
						var actual: Color = settings.get_color(role, "Settings")
						assert_eq(actual, pause.get_color(role, "Pause"), context + " shared " + role)
						if day == 1 or high_contrast or role not in ROOM:
							assert_eq(actual, authored[role], context + " protected " + role)
						elif preset != "standard":
							var source: Color = authored[role]
							assert_almost_eq(actual.ok_hsl_h, source.ok_hsl_h, 0.02, context + " hue " + role)
							assert_almost_eq(actual.ok_hsl_s, source.ok_hsl_s, 0.01, context + " saturation " + role)
					for pair: Array in TEXT_PAIRS:
						assert_gte(_contrast(settings.get_color(pair[0], "Settings"), settings.get_color(pair[1], "Settings")),
							7.0 if high_contrast else 4.5, context + " text contrast " + pair[0] + "/" + pair[1])
					for pair: Array in MARK_PAIRS:
						assert_gte(_contrast(settings.get_color(pair[0], "Settings"), settings.get_color(pair[1], "Settings")),
							3.0, context + " state contrast " + pair[0] + "/" + pair[1])


func test_week_curve_is_monotone_and_shipped_day_one_is_exact_zero() -> void:
	assert_eq(TINT.tint_for_day(1), 0.0)
	assert_eq(TINT.tint_for_day(7), 1.0)
	for day: int in range(2, 8):
		assert_gt(TINT.tint_for_day(day), TINT.tint_for_day(day - 1))
	assert_null(SETTINGS.build("en", 100, &"after_hours", false, "standard", 0))
	assert_null(PAUSE.build("en", 100, "AfterHours", false, "standard", 0))


func _contrast(first: Color, second: Color) -> float:
	var light := _luminance(first)
	var dark := _luminance(second)
	return (maxf(light, dark) + 0.05) / (minf(light, dark) + 0.05)


func _luminance(colour: Color) -> float:
	var channels := [colour.r, colour.g, colour.b]
	for index: int in range(channels.size()):
		var value: float = channels[index]
		channels[index] = value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
