# Desktop shell foundation — 2026-09-05

User direction: visible UI first; historical recovery plans are references.
This milestone implements Shared Shell sections 4, 7–8 and routine clock aspects
of section 10, with the existing typography direction. It is not completion of
the whole Shared Shell dossier or of UI-00R.

1. Build the exact shared strip and seven-target launcher. Verify geometry,
   real locale glyphs, text sizing, independent interaction states, and focus.
2. Fit Contacts below the strip. Verify open/failure, Home and one-layer Back,
   scroll/cache/focus, day eviction and restored active view without replay.
3. Reuse supported owners. Contacts and existing Settings controls are viable;
   the route audit identifies incomplete prerequisites for the other entries.
   Verify that unavailable requests preserve canonical state.
4. Verify the isolated current files in Godot, independently review the change,
   and record exact evidence and remaining limitations.

No speculative architecture or ablation flags are needed: the fixed-grid design
already resolves the layout choice. Retain existing fonts and their licenses.
All new files and edits stay in this worktree; preserve prior Contacts work.
