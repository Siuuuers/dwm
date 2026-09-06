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
action-count/Foresight/No-flag registers, real New Board/replacement,
platform pen mapping and configured secondary-controller action,
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

## Viewport and gesture continuation

The worksheet now mounts the grid in a clipped content well, creates rails only
for overflowing axes, keeps fit-axis gutters and the corner empty, and restores
the retained semantic cell into view on focus return. Scrollbar thumb dragging,
track paging, axis keys and wheel input change integer-native presentation scroll
only. A single worksheet contact seam represents panning or custody. No cell fact,
revision, count, identity or transaction changes during scrolling.

Drag mode begins panning only beyond eight logical pixels of displacement. Touch
uses the same radial slop: a short tap performs the current legal primary action;
a hold of at least 500 ms requests the legal direct Flag/Unflag action; crossing
slop pans instead. A held finger remains latched across the synchronous Flag
publication, so release cannot submit a second action. Mouse emulation events are
ignored by the grid, and simultaneous pointer/keyboard/controller gestures share
admission guards. The configured secondary controller binding remains a host
integration requirement. ScreenTouch tests do not establish how a particular
Windows pen driver maps pressure-bearing mouse or touch events.

The implementation follows Godot's Control event routing and logical relative
motion, verified against the [Control documentation](https://docs.godotengine.org/en/stable/classes/class_control.html)
and [ScreenDrag reference](https://docs.godotengine.org/en/stable/classes/class_inputeventscreendrag.html).
Real SubViewport tests cover wheel propagation, mouse/touch panning, scrollbar
dragging through synchronous viewport updates, and long-press through the real
presentation port and coordinator. The latter verifies exactly one revision and
one issuer allocation, and no additional command from release or emulated mouse.

A small allocation simplification preserves existing cell nodes and their Themes
across same-size revisions; only added/removed cells allocate or free nodes. Tests
verify those identities and resize geometry. This removes full-grid reconstruction
from each Flag/publication; no frame-time improvement is claimed without profiling.

Viewport GPU evidence is stored separately under `evidence/minesweeper_viewport`.
It includes ordinary Beginner, Large Beginner with final-cell focus, Expert with
both axes scrolled to final-cell focus, and a canonical 18×18 covered fixture.
The canonical capture verifies presentation geometry only. Pixel checks require
empty fit-axis gutters/corners and no drawing outside the worksheet allocation.
The first GPU run found an outer rail stroke entering the corner; both rail
outlines now remain inside their allocations. This continuation does not remove
the owner, runtime, save and final accessibility gaps listed above.

Final continuation verification: **88 tests / 2,727 assertions pass** across ten
suites, including canceled-touch and double-tap suppression. Independent review
found that F could clear a held touch's activation gate and right-stick input
could pan during a pending touch. Regression tests reproduced both defects before
the fix: these inputs now wait for the active gesture to finish. The real command
path verifies wheel scrolling over the board or blank well followed by F then
Enter cannot issue another command after a long press while the finger remains
down. Four
OpenGL captures pass the gutter, corner and allocation clipping checks; the
scrolled Expert capture was also visually inspected. Both final native/wrapper
exits are zero. The existing 24 Dialogic orphans and environment messages remain.
`evidence/minesweeper_viewport` contains the final logs, four captures and the full
invocation ledger, including earlier failures. This is a viewport checkpoint;
full-screen, production integration and all-ten-family acceptance remain open.

## Rules and Assignments continuation

`MinesweeperInformationSheet` replaces the worksheet band with opaque paper,
pinned heading and Return, and a clipped body. Four Rules rows state only the
accepted Reveal, Flag, Chord and Drag facts. Nine Assignments use the accepted
order and literal Claimed/Unclaimed status. The localized strings implement the
dossier's English, Simplified Chinese and Traditional Chinese copy intent; they
do not add reward, route, cost or metric explanations. Rows are focusable
read-only Controls with no activation API. Return is the only visible action.

Baseline heading/body/footer rectangles match section 4.8. Full-size licensed
fonts wrap within fixed widths; row and footer heights grow on whole native
pixels. Overflow reserves the target-width paper rail and reuses the worksheet's
integer thumb arithmetic. Fit bodies have no rail node or assistive target. All
baseline Rules tuples fit, while all nine Assignment rows require scrolling.

`MinesweeperAssignmentsQuery` reads the real cumulative run receipt map and
validates its nine-row order against `DataCatalog`. It returns only nine booleans.
Opening or reading the sheet cannot claim rewards, change Coins or infer the
all-tier receipt from three other rows. Tests exercise the real owner's automatic
all-tier receipt and compare its complete save dictionary before and after
projection and inspection. Unknown sources or invalid registry order produce a
generic refusal, not default Unclaimed statuses.

The worksheet mounts these ephemeral sheets, suppresses its hidden grid and
rails, and traps focus locally. Return/Back restores the source control, mode,
semantic cell and exact manual scroll; subsequent navigation resumes normal
focus revelation. Outside clicks do not dismiss. These APIs are ready for the
future register/dock host, which must also make its visible surrounding controls
inert. Production launcher/dock wiring and final assistive-technology acceptance
are still outstanding; this is not a complete mounted Minesweeper application.

Verification: **112 tests / 3,624 assertions pass** across thirteen suites,
including the existing board transaction tests. Seven actual OpenGL captures
cover both Standard palettes, all three locales, text scales and target sizes,
Rules, scrolled Assignments and the wider canonical Rules sheet. A rendered
comparison removes only row text and proves every changed pixel stays inside
the visible copy aperture. English Rules and large Traditional Chinese
Assignments were also visually inspected. This sample set does not establish
every final native-platform accessibility tuple.

The first sheet tests found Godot's cached off-tree minimum width retaining a
wider row after scrollbar allocation. Mount now refreshes the minimum cache.
Independent review found focus restoration resetting manual pan; a failing
regression preceded the fix. Final tests and GPU runs exit zero; the existing
24 Dialogic orphans and certificate/Unicode environment messages remain.
`evidence/minesweeper_sheets` retains final logs, seven images and the complete
invocation ledger, including earlier failures. Text shaping and focus routing
follow the [TextParagraph reference](https://docs.godotengine.org/en/stable/classes/class_textparagraph.html)
and [Control reference](https://docs.godotengine.org/en/stable/classes/class_control.html),
with behavior checked in the project's installed Godot 4.6.3.
