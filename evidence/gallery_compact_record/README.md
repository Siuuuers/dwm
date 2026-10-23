# Compact Gallery record projection

Base: `fa1b0642efc8549797a32e82340eed21242c6b92`. The user explicitly chose
the written compact archive layout on 2026-09-14. This is an independent
`dwm-7wj` increment, not the full record-desk cutover.

Gallery no longer loads or rescales narrative CGs/backgrounds into a large
preview. No exact compact Gallery exports are registered, so media contributes
no node, aperture, border or spacer. The existing provisional localized title
appears at logical (392,32), width 504, in the active proportional font and paper
ink. It wraps at full size, has no input/focus target, and disappears for empty
or unavailable records. Replay statuses use the bottom dock so they do not
cover the title. Scene playback artwork remains unchanged. The artist guide
now explains the separate 258-by-78 archive export requirement.

## Verification

- Initial RED: all three revised record tests failed against the large-art
  implementation, which had no RecordTitle. The first focused run then passed
  12/15 cases; three failures came from a test scanning all descendant
  TextureRects, including controls outside the direct record-media surface.
  A diagnostic run retained their identities. The assertion now checks the
  Gallery-owned surface, paired with actual native blank-paper pixel proof.
- Final Windows OpenGL probe: **18 locale/size/palette tuples, 59 images,
  740 checks, exit 0**. It proves the title begins without a media gap, fits its
  full line height, has native ink pixels, and leaves the remaining paper blank.
  Replay/Error/Retry exact targets, focus outlines, canceled pointer activation
  and existing Practice focus remain covered by the inherited action probe.
- Final regression: **85/85 tests in 12 suites, 6,936 assertions, exit 0**.
  The same 24 existing Dialogic orphans remain. Three native font NUL-decoding
  diagnostics remain in the log; all rendered checks pass.
- Both public inventories regenerated. GameState changes one lexical dynamic
  reference line number in GalleryScene. SaveManager's record 38 reflects moved
  and added isolated Profile/localization fixture initialization references.
  Neither change claims new semantic coverage or changes protected owners.
- Independent source review found no actionable defect. Owned source and
  staged evidence pass whitespace checks and source/artifact hash verification.

`runs.jsonl` and `logs/` retain all seven terminal engine attempts, including
failures. Native images and machine receipts are under `native/`. Text uses
UTF-8 LF; log trailing whitespace is normalized. Source hashes describe the
final implementation and proof, not intermediate RED/test-diagnostic sources.
Existing action/typography evidence remains bound to its original checkpoint.

## Remaining scope

Authored descriptions and meaningful version cues are still absent. No copy is
invented or claimed final here. No compact image is registered or rendered yet;
only truthful media absence is implemented. The existing plural selector,
reached-date playback and Practice remain usable. Replacing the selector with
the designed newest-first register requires chronology from the excluded
persistence owner. Full scrolling record-paper, complete input-modality and
accessibility conformance, authored media, and release acceptance remain open.
No `dwm-634*` or `dwm-6fl` implementation, tests, branches or worktrees changed.
