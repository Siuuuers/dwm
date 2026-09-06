# Minesweeper worksheet implementation checkpoint — 2026-09-06

This is an implementation record, not final screen acceptance. It follows the accepted
Minesweeper dossier in the preserved `ui00-authority-readiness` worktree and the user's
later authorization to build the UI efficiently. The implementation starts on the
committed Schedule/gameplay lineage `bda19039a30b6ea65fcafdb21d10dad3707d8aea` in the
isolated `codex/minesweeper-ui-build` branch. No destination merge or runtime cutover
is part of this checkpoint.

## Implemented boundary

- `MinesweeperBoardCatalog` supplies the accepted desktop 8×8/10, 16×16/40,
  22×22/99 and fixed canonical 18×18/36 board configurations. The production
  desktop spec port now uses it instead of its placeholder table. Existing saved
  boards keep their actual dimensions; presentation never resizes their contents.
- `MinesweeperBoardPresentationQuery` validates the retained desktop snapshot and
  its nested board/candidate, then emits only dimensions, top-level revision,
  signed mine estimate, terminal/custody facts and public cells. Mine estimate is
  null until layout freezes, then actual mines minus placed flags. Covered
  adjacency, mine arrays, nonces, proofs, identities, receipts and action history
  never enter a Control. Invalid sources produce a generic failure, without echoing
  private schema diagnostics.
- Each cell has a closed public action set. This is necessary because a flagged
  cell can accept Unflag while Reveal remains illegal, and a readable number can
  be inspected while Chord remains illegal. The UI does not infer permissions from
  appearance alone. A prepared locus is described as visible brackets, never as
  a safe/forced/Debug label in the public cell data.
- `MinesweeperPresentationPort` keeps identity and issuer receipts private,
  revalidates identity, revision and current eligibility before allocating a
  command, calls the real round coordinator and returns a fresh public projection.
  Its interface is pull plus dispatch; it does not claim a reactive owner signal.
- `MinesweeperCell` uses the two Standard palettes and existing licensed Source
  Sans/Source Han fonts at the full 20/25/30 logical sizes. Targets remain 48/64
  logical pixels with 24/32-pixel mark apertures. Source Han numerals receive a
  one-native-pixel upward bearing correction established by the GPU atlas. Glyph
  microgeometry is a tested calibration choice, not a claim of new exact art approval.
- `MinesweeperGrid` composes inert cell renderers into one roving focus target.
  `MinesweeperWorksheetLayout` implements the dossier's integer-native mount,
  reserved gutters, conditional rails, thumb arithmetic and focus correction.

## Important owner gaps

The current desktop owner has no persistent pre-Reveal shell flag/history state.
The unpaid projection therefore offers only eligible Reveal; it does not pretend
that local Control flags would satisfy persistence, counting, No-flag or payment
semantics. A canonical shell owner is still required.

A terminal board command makes mine/explosion/flag classification public. It does
**not** prove durable round settlement. The accepted dossier §10.5 requires
settlement before inspection input. The current coordinator clears the board to
`NONE` on `complete_round`, skipping `SETTLING`; it cannot supply the later retained
terminal inspection. This checkpoint displays terminal facts under custody and
does not enable inspection prematurely. A durable retained terminal view must be
integrated with the existing save/restore owners.

Canonical solo/pair owners, the specially marked solo mine, pre-Reveal history,
action-count/Foresight/No-flag registers, real New Board/replacement, Rules and
Assignments sheets, viewport scrolling/panning and touch/pen long-press behavior,
desktop/challenge mounts, audio, launcher/Pause/recovery/save connections, other
accessibility palettes and native assistive-technology acceptance remain unfinished.
The full ten-family UI goal and Bead `dwm-eei.9` remain in progress.

## Verification

Focused tests exercise the real schema/reducer, coordinator and identity issuer,
with isolated fixtures for dependencies. Existing durable first-Reveal and desktop
completion tests retain their assertions and now use the accepted 8×8 beginner
layout. The public-query suite proves that changing hidden mine positions without
changing public facts cannot change the projection.

The actual OpenGL renderer produces six cell atlases: three locales and two
palettes, each containing 100/125/150 percent and ordinary/Large rows. Across all
288 rendered numeral cases it compares the numbered cell against a blank reference
over the entire cell allocation; any ink outside its fixed aperture fails. The
renderer saves failure images as well as successful ones. Headless GUT tests alone
do not establish drawing correctness: the first GPU run caught a flag-array type
error and the Chinese 150-percent baseline overflow, both corrected before the
successful capture. No font shrinking or clipping was used.

Checked-in evidence and the exact test invocation ledger accompany the checkpoint
under `evidence/minesweeper_cells`. These are component and integration proofs;
they do not establish final screen, save-compatibility or shipped-runtime acceptance.

Final focused result: **57 tests / 2,460 assertions pass** across eight suites,
including a real SubViewport keyboard-then-pointer route through Grid, presentation
port, coordinator and back to Grid. Six atlas captures pass all 288 numeral bounds
checks. One additional composite image was visually inspected for contiguous
ordinary/Large mounts; it is visual evidence, not an automated pixel oracle.
Native/wrapper exits are zero for the final suites and both successful GPU runs.
The existing 24 Dialogic orphans and certificate/Unicode environment messages also
occurred in the initial owner baseline; no new runtime script errors remain in
these final logs. Earlier failed runs remain in the invocation ledger.
