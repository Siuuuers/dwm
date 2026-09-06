extends RefCounted
## Pause role literals copied from SettingsPaletteRegistry.gd at pinned commit
## 26de279be5f6490ff453db359b1964ec10596962; no runtime dependency on that worktree.
## Source bytes SHA-256: ca8e8d6950e567a451349598a985ba35bac893f6c57568c8860b6490f5358815
## Exact lookup only: no runtime colour transform or substitute tuple.

const ROLE_NAMES := ["habitat","face","paper","paper_ink","secondary_ink","ink","structure","filed","focus","paper_focus","danger","destructive","secondary_dark_ink","inward_preview"]

const TUPLES := {
	"after_hours/standard/standard": {
		"habitat": Color("0b0d13"), "face": Color("151b25"),
		"paper": Color("c3baa3"), "paper_ink": Color("151b25"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("789083"),
		"focus": Color("a9935f"), "paper_focus": Color("644000"),
		"danger": Color("c9846e"), "destructive": Color("dd7a7f"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"after_hours/standard/protan": {
		"habitat": Color("0b0d13"), "face": Color("151b25"),
		"paper": Color("c3baa3"), "paper_ink": Color("151b25"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("7d94ae"),
		"focus": Color("c0a06a"), "paper_focus": Color("5d3d00"),
		"danger": Color("d5ac7b"), "destructive": Color("b8a4d8"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"after_hours/standard/deutan": {
		"habitat": Color("0b0d13"), "face": Color("151b25"),
		"paper": Color("c3baa3"), "paper_ink": Color("151b25"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("869aaa"),
		"focus": Color("bea86a"), "paper_focus": Color("4f3d00"),
		"danger": Color("cca875"), "destructive": Color("c1a5c5"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"after_hours/standard/tritan": {
		"habitat": Color("0b0d13"), "face": Color("151b25"),
		"paper": Color("c3baa3"), "paper_ink": Color("151b25"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("a59289"),
		"focus": Color("d0a099"), "paper_focus": Color("653936"),
		"danger": Color("d9a37f"), "destructive": Color("c7a5b9"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"after_hours/high/standard": {
		"habitat": Color("080b10"), "face": Color("0b1018"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0b1018"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("9fab9f"),
		"focus": Color("d0b977"), "paper_focus": Color("5b3900"),
		"danger": Color("e9ab8d"), "destructive": Color("f2a5ad"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"after_hours/high/protan": {
		"habitat": Color("080b10"), "face": Color("0b1018"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0b1018"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("a7b7cd"),
		"focus": Color("e0c187"), "paper_focus": Color("503500"),
		"danger": Color("edd09a"), "destructive": Color("d3bceb"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"after_hours/high/deutan": {
		"habitat": Color("080b10"), "face": Color("0b1018"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0b1018"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("acbecd"),
		"focus": Color("d9c585"), "paper_focus": Color("4f3d00"),
		"danger": Color("e4c28d"), "destructive": Color("ddc1df"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"after_hours/high/tritan": {
		"habitat": Color("080b10"), "face": Color("0b1018"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0b1018"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("c4aba2"),
		"focus": Color("e3b6ac"), "paper_focus": Color("5b302e"),
		"danger": Color("f0c49d"), "destructive": Color("dfc0d1"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"midnight/standard/standard": {
		"habitat": Color("0d1514"), "face": Color("14201d"),
		"paper": Color("c3baa3"), "paper_ink": Color("14201d"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("789083"),
		"focus": Color("a9935f"), "paper_focus": Color("644000"),
		"danger": Color("c9846e"), "destructive": Color("dd7a7f"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"midnight/standard/protan": {
		"habitat": Color("0d1514"), "face": Color("14201d"),
		"paper": Color("c3baa3"), "paper_ink": Color("14201d"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("7d94ae"),
		"focus": Color("c0a06a"), "paper_focus": Color("5d3d00"),
		"danger": Color("d5ac7b"), "destructive": Color("b8a4d8"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"midnight/standard/deutan": {
		"habitat": Color("0d1514"), "face": Color("14201d"),
		"paper": Color("c3baa3"), "paper_ink": Color("14201d"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("869aaa"),
		"focus": Color("bea86a"), "paper_focus": Color("4f3d00"),
		"danger": Color("cca875"), "destructive": Color("c1a5c5"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"midnight/standard/tritan": {
		"habitat": Color("0d1514"), "face": Color("14201d"),
		"paper": Color("c3baa3"), "paper_ink": Color("14201d"),
		"secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
		"structure": Color("657d89"), "filed": Color("a59289"),
		"focus": Color("d0a099"), "paper_focus": Color("653936"),
		"danger": Color("d9a37f"), "destructive": Color("c7a5b9"),
		"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
	},
	"midnight/high/standard": {
		"habitat": Color("07100c"), "face": Color("0c1811"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0c1811"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("9fab9f"),
		"focus": Color("d0b977"), "paper_focus": Color("5b3900"),
		"danger": Color("e9ab8d"), "destructive": Color("f2a5ad"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"midnight/high/protan": {
		"habitat": Color("07100c"), "face": Color("0c1811"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0c1811"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("a7b7cd"),
		"focus": Color("e0c187"), "paper_focus": Color("503500"),
		"danger": Color("edd09a"), "destructive": Color("d3bceb"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"midnight/high/deutan": {
		"habitat": Color("07100c"), "face": Color("0c1811"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0c1811"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("acbecd"),
		"focus": Color("d9c585"), "paper_focus": Color("4f3d00"),
		"danger": Color("e4c28d"), "destructive": Color("ddc1df"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
	"midnight/high/tritan": {
		"habitat": Color("07100c"), "face": Color("0c1811"),
		"paper": Color("e9e2d0"), "paper_ink": Color("0c1811"),
		"secondary_ink": Color("24212d"), "ink": Color("f6efdc"),
		"structure": Color("98a7ae"), "filed": Color("c4aba2"),
		"focus": Color("e3b6ac"), "paper_focus": Color("5b302e"),
		"danger": Color("f0c49d"), "destructive": Color("dfc0d1"),
		"secondary_dark_ink": Color("c1c9c1"), "inward_preview": Color("24212d"),
	},
}


static func resolve(palette_id: StringName, high_contrast: bool, colour_preset: String) -> Dictionary:
	var contrast := "high" if high_contrast else "standard"
	var key := "%s/%s/%s" % [String(palette_id), contrast, colour_preset]
	if not TUPLES.has(key):
		return {}
	return TUPLES[key].duplicate()
