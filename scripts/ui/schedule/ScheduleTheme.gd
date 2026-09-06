extends RefCounted

const TYPE := &"Schedule"
const SHARED := {&"paper":Color("c3baa3"),&"secondary_ink":Color("2f2936"),&"ink":Color("d8cfb7"),&"structure":Color("657d89"),&"filed":Color("789083"),&"focus":Color("a9935f"),&"paper_focus":Color("644000")}
const PALETTES := {
	&"after_hours":{&"habitat":Color("0b0d13"),&"face":Color("151b25"),&"paper_ink":Color("151b25")},
	&"midnight":{&"habitat":Color("0d1514"),&"face":Color("14201d"),&"paper_ink":Color("14201d")},
}

static func build(palette: StringName) -> Theme:
	if not PALETTES.has(palette): return null
	var result := Theme.new()
	for role: StringName in SHARED: result.set_color(role,TYPE,SHARED[role])
	for role: StringName in PALETTES[palette]: result.set_color(role,TYPE,PALETTES[palette][role])
	return result
