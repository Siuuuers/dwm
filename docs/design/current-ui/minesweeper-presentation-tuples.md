# Minesweeper presentation tuples

Authored 2026-09-06 as a bounded accessibility extension to the historical
Minesweeper dossier, `docs/design/current-ui/minesweeper.md` §5 at commit
`e663044b` (read from the `ui00-authority-readiness` worktree). That dossier
is not present on this implementation lineage. The two Standard contrast / Standard colour
appearances retain all 23 existing semantic role values. The fourteen additional
combinations are authored extensions; they do not amend the accepted dossier or
demonstrate perceptual or assistive-technology acceptance.

The colour provenance is the authored Settings tuple registry and its companion
document at commit `26de279be5f6490ff453db359b1964ec10596962`, read from
the sibling `settings-save-guard` worktree:
`scripts/settings/SettingsPaletteRegistry.gd` and
`docs/design/current-ui/settings-presentation-tuples.md`.
Only those literal colour values and their semantic correspondence are reused.
Minesweeper has its own registry and no runtime dependency on Settings systems.

## Exact tuple contract

`MinesweeperTheme.build(locale, percent, palette, high_contrast=false,
colour_preset="standard")` preserves the existing three-argument call.
Locales are `en`, `zh-CN`, and `zh-HK` (underscore separators are normalized);
text sizes are 100, 125, and 150 percent. Fonts and size calculation are unchanged.

The complete 16-key registry is the Cartesian product of:

- Palette: `after_hours`, `midnight`.
- Contrast: `standard` (false), `high` (true).
- Colour preset: `standard`, `protan`, `deutan`, `tritan`.

[MinesweeperPaletteRegistry.gd](../../../scripts/ui/minesweeper/MinesweeperPaletteRegistry.gd)
stores every complete 23-role table as literal opaque sRGB colours. Resolution
uses the exact palette/contrast/preset key and returns an independent dictionary.
An unknown key returns an empty dictionary; Theme construction returns null for
an unsupported locale, size, palette, or preset before allocating a Theme.
There is no fallback, computed colour transform, shader, or inferred tuple.
Retaining a previously applied presentation is the caller's responsibility.

## Semantic correspondence

Every tuple uses this same mapping from the Settings reference values:

| Minesweeper roles | Reference role |
| --- | --- |
| habitat, dark_separation, paper_focus_outer, filed_focus_outer | habitat |
| controlled_face, filed_focus_inner | face |
| paper | paper |
| primary_paper_copy, paper_structure, paper_mark, selected_ink | paper_ink |
| secondary_paper_copy | secondary_ink |
| primary_dark_copy, dark_scroll_thumb, dark_mark, dark_focus_outer | ink |
| secondary_dark_copy | secondary_dark_ink |
| dark_registration | structure |
| selected_plane | filed |
| dark_focus_inner | focus |
| paper_scroll_thumb, paper_focus_inner | paper_focus |
| technical_error | destructive |

The final mapping is colour provenance only: `technical_error` remains reserved
for real technical errors. Settings' danger and inward-preview roles are omitted.
No gameplay, win/loss, difficulty, route, assignment, or number-specific colours
are introduced. Numbers and domain glyphs continue to use their shared mark roles.

## Scope and acceptance limits

The reference choices preserve a cream worksheet against blue-black After-Hours
or green-black Midnight. High Contrast supplies brighter ink and registration;
Protan uses blue/sand accents, Deutan slate/ochre, and Tritan rose/brown.
These are authored alternatives, not clinical colour correction or a guarantee
for every person with a named condition.

Existing labels, glyphs, selection seams, and detached two-rail focus geometry
remain necessary state cues. The tuple lookup changes no geometry, input behavior,
gameplay owner, hidden board data, or entitlement. Registry completeness and
Standard-value parity alone do not establish contrast compliance in every actual
rendered pairing, perceived readability, screen-reader behavior, or full-game
accessibility. Rendered scene review and assistive-technology verification remain
separate acceptance work.
