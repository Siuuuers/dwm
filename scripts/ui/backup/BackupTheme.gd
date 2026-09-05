extends RefCounted

const DESKTOP := preload("res://scripts/ui/desktop/DesktopTheme.gd")

static func build(locale: String, percent: int) -> Theme:
	var result := DESKTOP.build(locale, percent)
	var roles := {"habitat": Color("0b0d13"), "face": Color("151b25"),
		"paper": Color("c3baa3"), "paper_ink": Color("151b25"),
		"ink": Color("d8cfb7"), "structure": Color("657d89"),
		"filed": Color("789083"), "focus": Color("a9935f"),
		"paper_focus": Color("644000"), "danger": Color("c9846e"),
		"destructive": Color("dd7a7f")}
	for role in roles:
		result.set_color(role, "Backup", roles[role])
	return result
