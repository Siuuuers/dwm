extends RefCounted
## Literal witnessed-role projection of SettingsPaletteRegistry at
## 26de279be5f6490ff453db359b1964ec10596962 (blob 5954ae68db2c36794506f242dac5bbad0c2a93b1).
## field=face, deep=habitat, current=inward_preview, text/focus_outer=ink,
## rule=structure, focus_inner=focus. No runtime sibling dependency or transform.

const TUPLES := {
	"AfterHours/standard/standard": {
		&"field": Color("151b25"), &"deep": Color("0b0d13"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("a9935f"),
	},
	"AfterHours/standard/protan": {
		&"field": Color("151b25"), &"deep": Color("0b0d13"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("c0a06a"),
	},
	"AfterHours/standard/deutan": {
		&"field": Color("151b25"), &"deep": Color("0b0d13"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("bea86a"),
	},
	"AfterHours/standard/tritan": {
		&"field": Color("151b25"), &"deep": Color("0b0d13"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("d0a099"),
	},
	"AfterHours/high/standard": {
		&"field": Color("0b1018"), &"deep": Color("080b10"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("d0b977"),
	},
	"AfterHours/high/protan": {
		&"field": Color("0b1018"), &"deep": Color("080b10"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("e0c187"),
	},
	"AfterHours/high/deutan": {
		&"field": Color("0b1018"), &"deep": Color("080b10"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("d9c585"),
	},
	"AfterHours/high/tritan": {
		&"field": Color("0b1018"), &"deep": Color("080b10"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("e3b6ac"),
	},
	"Midnight/standard/standard": {
		&"field": Color("14201d"), &"deep": Color("0d1514"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("a9935f"),
	},
	"Midnight/standard/protan": {
		&"field": Color("14201d"), &"deep": Color("0d1514"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("c0a06a"),
	},
	"Midnight/standard/deutan": {
		&"field": Color("14201d"), &"deep": Color("0d1514"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("bea86a"),
	},
	"Midnight/standard/tritan": {
		&"field": Color("14201d"), &"deep": Color("0d1514"), &"current": Color("2f2936"),
		&"text": Color("d8cfb7"), &"focus_outer": Color("d8cfb7"), &"rule": Color("657d89"), &"focus_inner": Color("d0a099"),
	},
	"Midnight/high/standard": {
		&"field": Color("0c1811"), &"deep": Color("07100c"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("d0b977"),
	},
	"Midnight/high/protan": {
		&"field": Color("0c1811"), &"deep": Color("07100c"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("e0c187"),
	},
	"Midnight/high/deutan": {
		&"field": Color("0c1811"), &"deep": Color("07100c"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("d9c585"),
	},
	"Midnight/high/tritan": {
		&"field": Color("0c1811"), &"deep": Color("07100c"), &"current": Color("24212d"),
		&"text": Color("f6efdc"), &"focus_outer": Color("f6efdc"), &"rule": Color("98a7ae"), &"focus_inner": Color("e3b6ac"),
	},
}

static func resolve(palette: String, high_contrast: bool, colour_preset: String) -> Dictionary:
	var key := "%s/%s/%s" % [palette, "high" if high_contrast else "standard", colour_preset]
	return TUPLES[key].duplicate() if TUPLES.has(key) else {}
