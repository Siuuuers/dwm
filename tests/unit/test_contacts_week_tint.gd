extends GutTest

const CONTACTS := preload("res://scripts/ui/contacts/ContactsTheme.gd")
const AUTHORED := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
const PRESETS := ["standard", "protan", "deutan", "tritan"]
const FIXED := ["ink", "bone", "filed", "void", "gold", "identity_0",
	"identity_1", "identity_2", "paper_mark"]


func test_day_one_standard_retains_every_old_contacts_literal() -> void:
	var shared := {"bone": "d8cfb7", "paper": "c3baa3", "plum": "2f2936",
		"filed": "789083", "void": "0b0d13", "gold": "a9935f",
		"identity_0": "756477", "identity_1": "657d89", "identity_2": "4f665c"}
	for palette: StringName in [&"after_hours", &"midnight"]:
		var roles: Dictionary = CONTACTS.resolve(palette)
		assert_eq(roles.size(), 12)
		for role: String in shared:
			assert_eq(roles[role], Color(shared[role]), "%s/%s" % [palette, role])
		var face := Color("151b25" if palette == &"after_hours" else "14201d")
		assert_eq(roles.ink, face, "contextual paper ink")
		assert_eq(roles.instrument, face, "registrar instrument")
		assert_eq(roles.paper_mark, Color("c3baa3"), "fixed unread/notch mark")


func test_every_tuple_and_day_keeps_drawn_text_focus_state_and_identity_contrast() -> void:
	# ContactsRow: names on instrument or Filed, identity/unread on Void,
	# Focus/Hover/Press against row planes. ContactsPanel: thread/header labels,
	# outgoing and incoming messages, continuation, scroll Focus, and notch.
	var text := [["bone", "instrument"], ["ink", "filed"], ["ink", "paper"],
		["bone", "plum"]]
	var focus := [["bone", "instrument"], ["ink", "filed"],
		["gold", "instrument"], ["filed", "instrument"], ["ink", "paper"]]
	var nontext := [["identity_0", "void"], ["identity_1", "void"],
		["identity_2", "void"], ["paper_mark", "void"],
		["paper_mark", "plum"], ["filed", "instrument"],
		["ink", "paper"]]
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in PRESETS:
				var authored: Dictionary = AUTHORED.resolve(palette, high_contrast, preset)
				assert_false(authored.is_empty())
				var first: Dictionary = CONTACTS.resolve(palette, 1, high_contrast, preset)
				for day: int in range(1, 8):
					var context := "%s/%s/%s/day%d" % [palette, high_contrast, preset, day]
					var roles: Dictionary = CONTACTS.resolve(palette, day, high_contrast, preset)
					assert_eq(roles.size(), 12, context)
					for role: String in roles:
						var colour: Color = roles[role]
						assert_eq(colour.a, 1.0, context + "/" + role)
					for role: String in FIXED:
						assert_eq(roles[role], first[role], context + "/" + role + " remains authored")
					for pair: Array in text:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]),
							7.0 if high_contrast else 4.5, context + "/text " + str(pair))
					for pair: Array in focus:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]),
							4.5, context + "/primary Focus " + str(pair))
					for pair: Array in nontext:
						assert_gte(_contrast(roles[pair[0]], roles[pair[1]]),
							3.0, context + "/nontext " + str(pair))
					if high_contrast:
						assert_eq(roles, first, context + " high contrast has zero week amplitude")
					elif day == 7:
						for room_role: String in ["instrument", "paper", "plum"]:
							assert_lt(roles[room_role].ok_hsl_l, first[room_role].ok_hsl_l,
								context + "/" + room_role + " ages")
						if preset != "standard":
							for cvd_role: String in ["instrument", "paper", "plum"]:
								assert_almost_eq(roles[cvd_role].ok_hsl_s, first[cvd_role].ok_hsl_s,
									0.01, context + "/" + cvd_role + " CVD lightness only")
					assert_eq(roles.ink, authored.paper_ink, context + " paper copy")
					assert_eq(roles.bone, authored.ink, context + " dark copy")
					assert_eq(roles.filed, authored.filed, context + " selected plane")
					assert_eq(roles.gold, authored.focus, context + " focus accent")
					assert_eq(roles.identity_1, authored.structure, context + " Fog Blue")
					assert_eq(roles.paper_mark, authored.paper, context + " state mark")


func test_build_uses_fonts_and_focus_and_invalid_inputs_fail_without_fallback() -> void:
	var font := FontFile.new()
	for palette: StringName in [&"after_hours", &"midnight"]:
		for high_contrast: bool in [false, true]:
			for preset: String in PRESETS:
				for day: int in range(1, 8):
					var roles: Dictionary = CONTACTS.resolve(palette, day, high_contrast, preset)
					var theme: Theme = CONTACTS.build(font, 24, palette, day, high_contrast, preset)
					assert_not_null(theme)
					assert_eq(theme.default_font, font)
					assert_eq(theme.default_font_size, 24)
					assert_eq(theme.get_color_list("Contacts").size(), 12)
					for role: String in roles:
						assert_eq(theme.get_color(role, "Contacts"), roles[role], role)
					var scroll_focus: StyleBoxFlat = theme.get_stylebox("focus", "ScrollContainer")
					assert_eq(scroll_focus.border_color, roles.ink, "scroll Focus on paper")
	assert_eq(CONTACTS.resolve(&"unknown"), {})
	assert_eq(CONTACTS.resolve(&"after_hours", 0), {})
	assert_eq(CONTACTS.resolve(&"after_hours", 8), {})
	assert_eq(CONTACTS.resolve(&"after_hours", 3, false, "unknown"), {})
	assert_null(CONTACTS.build(font, 24, &"unknown"))
	assert_null(CONTACTS.build(font, 24, &"after_hours", 0))
	assert_null(CONTACTS.build(font, 24, &"after_hours", 8))
	assert_null(CONTACTS.build(font, 24, &"after_hours", 3, false, "unknown"))
	assert_null(CONTACTS.build(null, 24))
	assert_null(CONTACTS.build(font, 0))


func _contrast(first: Color, second: Color) -> float:
	var a: float = first.srgb_to_linear().get_luminance()
	var b: float = second.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
