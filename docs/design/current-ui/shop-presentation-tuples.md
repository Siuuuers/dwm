# Shop presentation tuple implementation

`ShopTheme` resolves the same sixteen authored palette, contrast, and colour-preset
tuples as [MinesweeperPaletteRegistry](../../../scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd).
This is an implementation mapping, not a new Shop design authority or a second
literal palette table. The two palettes are `after_hours` and `midnight`; contrast
is Standard or High; colour preset is Standard, Protan, Deutan, or Tritan. Unknown
combinations and days outside 1–7 fail resolution rather than falling back.

| Shop material or mark | Authored role | WeekTint treatment |
| --- | --- | --- |
| habitat, controlled face, paper | habitat, controlled_face, paper | habitat, face, paper room deltas |
| laminate | secondary_dark_copy | separate paper room delta |
| structure and scroll track | paper_structure | structure room delta |
| card and document copy | primary_paper_copy, secondary_paper_copy | fixed |
| button and page copy | primary_dark_copy, secondary_dark_copy | fixed |
| selection, registration, scroll thumb | selected_plane, selected_ink, dark_registration, dark_scroll_thumb | fixed |
| dark, laminate, and paper focus rings | dark_focus_*, filed_focus_*, paper_focus_* | fixed |

Day 1 Standard retains every shipped Shop colour. Only the room materials age
through Day 7; High Contrast has zero week amplitude, and CVD presets receive
lightness-only aging. Copy, focus rings, selection and registration keep their
authored colours; structural strokes receive the structure delta. Laminate is a Shop material distinct from document paper, so
it starts at the former `secondary_dark_copy` literal and takes the paper delta.
The Shop theme test checks contrast for the pairings drawn by `ShopApp` and
`ShopItemBox` across all sixteen tuples and seven days. Rendered and assistive
technology review remain separate acceptance work.
