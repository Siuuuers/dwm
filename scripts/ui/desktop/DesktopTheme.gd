extends RefCounted

const ENGLISH := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")

static func build(locale: String, percent: int) -> Theme:
	var result := Theme.new()
	result.default_font = {"en": ENGLISH, "zh-CN": SIMPLIFIED, "zh-HK": TRADITIONAL}.get(locale, ENGLISH)
	result.default_font_size = int(24 * percent / 100.0)
	var roles := {"habitat": Color("0b0d13"), "face": Color("151b25"),
		"ink": Color("d8cfb7"), "structure": Color("657d89"),
		"focus": Color("a9935f"), "current": Color("789083")}
	for role in roles:
		result.set_color(role, "Desktop", roles[role])
	result.set_color("font_color", "Label", roles.ink)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = roles.current if state == "disabled" else roles.face
		style.border_color = roles.ink if state == "pressed" else roles.structure
		style.set_border_width_all(2 if state in ["pressed", "hover"] else 0)
		result.set_stylebox(state, "Button", style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", roles.ink)
	result.set_color("font_disabled_color", "Button", roles.face)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = roles.focus
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	return result
