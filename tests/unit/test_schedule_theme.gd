extends "res://addons/gut/test.gd"

const SCHEDULE_THEME := preload("res://scripts/ui/schedule/ScheduleTheme.gd")
const TYPE := &"Schedule"

func test_after_hours_has_exact_accepted_roles() -> void:
	var theme := SCHEDULE_THEME.build(&"after_hours")
	var expected := {&"habitat":Color("0b0d13"),&"face":Color("151b25"),&"paper":Color("c3baa3"),&"paper_ink":Color("151b25"),&"secondary_ink":Color("2f2936"),&"ink":Color("d8cfb7"),&"structure":Color("657d89"),&"filed":Color("789083"),&"focus":Color("a9935f"),&"paper_focus":Color("644000")}
	for role: StringName in expected: assert_eq(theme.get_color(role,TYPE),expected[role],role)

func test_midnight_changes_only_contextual_dark_roles() -> void:
	var after_hours := SCHEDULE_THEME.build(&"after_hours")
	var midnight := SCHEDULE_THEME.build(&"midnight")
	assert_eq(midnight.get_color(&"habitat",TYPE),Color("0d1514"))
	assert_eq(midnight.get_color(&"face",TYPE),Color("14201d"))
	assert_eq(midnight.get_color(&"paper_ink",TYPE),Color("14201d"))
	for role: StringName in [&"paper",&"secondary_ink",&"ink",&"structure",&"filed",&"focus",&"paper_focus"]: assert_eq(midnight.get_color(role,TYPE),after_hours.get_color(role,TYPE),role)

func test_rejects_unsupported_palette_and_builds_isolated_themes() -> void:
	assert_null(SCHEDULE_THEME.build(&"unknown"))
	var first := SCHEDULE_THEME.build(&"after_hours")
	var second := SCHEDULE_THEME.build(&"after_hours")
	first.set_color(&"paper",TYPE,Color.BLACK)
	assert_eq(second.get_color(&"paper",TYPE),Color("c3baa3"))

func test_primary_pairs_meet_standard_text_contrast() -> void:
	for palette: StringName in [&"after_hours",&"midnight"]:
		var theme := SCHEDULE_THEME.build(palette)
		assert_gt(_contrast(theme.get_color(&"paper_ink",TYPE),theme.get_color(&"paper",TYPE)),4.5)
		assert_gt(_contrast(theme.get_color(&"ink",TYPE),theme.get_color(&"face",TYPE)),4.5)

func _contrast(a: Color, b: Color) -> float:
	var light := maxf(a.srgb_to_linear().get_luminance(),b.srgb_to_linear().get_luminance())
	var dark := minf(a.srgb_to_linear().get_luminance(),b.srgb_to_linear().get_luminance())
	return (light+0.05)/(dark+0.05)
