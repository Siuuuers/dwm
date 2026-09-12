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
complete action-count/Foresight owners, real New Board/replacement,
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

## Status register and action dock continuation

The register presents the seven desktop bays in their accepted horizontal order.
Canonical hosts contain only the three right-hand metrics; their 280-native-pixel
blank capacity has no field node, placeholder or painted field face. Values keep
literal signs and percentages, including negative mine estimates and Foresight
above 100. Tabular font features are applied to value shaping. Only difficulty
and mode controls own Selected; input emits an intent and never changes their
published commitment by itself.

The dock retains the exact target X coordinates, widths, gaps and vacant middle
capacity. All actions use one `MinesweeperActionButton`, including the information
sheet's Return. The former separate Return implementation was removed; its
regression tests now exercise the shared primitive. Disabled actions keep readable
copy and a visible blocked action edge, leave the focus order, and accept no
command. Focus remains detached from the Selected plane and within the hit target.

The requested 10-native-pixel baseline font requires measured vertical adaptation
in narrow English bays. English 100 percent resolves to native bands **58/234/36**
(register/worksheet/dock); English 150 percent with Large Targets resolves to
**92/176/60**. These are font-driven changes to the dossier's smaller-font baseline
heights. Every sample still closes at 328 native pixels, with full cell/rail target
capacity, fixed horizontal bays, and no text shrinking. Long English labels wrap
within words at the largest size; these captures establish legible containment,
while final usability and assistive-technology acceptance remain open.

`MinesweeperRegisterQuery` supplies the real retained desktop facts: current signed
rounds, selected tier for NONE, frozen candidate or paid-receipt tier thereafter,
mine estimate and No-flag. It validates Flag history and reconstructs the current
flag set before deriving Lost, so Unflag cannot restore Intact and malformed
history cannot silently claim it. The query does not mutate gameplay or expose
identities, hidden layouts, raw metric operands or history.

At this historical component checkpoint, Foresight and the connected host layer
were unavailable. The 2026-09-08 integration supersedes the Foresight gap:
`BoardPerformance` derives 3BV and total accepted clicks from the saved board,
counting the implicit first Reveal plus `actions.size()`. The live register shows
the rounded percentage capped at 999; NONE/prepared boards remain unavailable.
Completion uses the exact integer comparison `3BV > clicks`, with No Flag as an
independent Perfect reason. The desktop reward port awards each qualifying task
once without adding metric fields or changing durable receipt shapes. Dating
uses the same helper. The seven performance, eight register-query and sixteen
reward tests pass (31 total); this does not replace the separate UI acceptance.

At this historical checkpoint, difficulty actions remained disabled
(`difficulty_enabled` was empty). The 2026-09-11 amendment supersedes that restriction. New Board
now dismisses an already settled terminal presentation and exposes the next
board through the existing owner; it refuses active-board replacement. It is
not a free replacement of a paid board or a new difficulty-selection command.

Verification: **134 tests / 4,790 assertions pass** across seventeen suites,
including prior cells, gestures, information sheets and durable board transaction
tests. Six final OpenGL composition fixtures cover both Standard palettes, all
three locales, three text scales, ordinary/Large targets and both host widths.
Pixel checks verify the continuous register separator, visibly blocked New Board
edge, and empty canonical capacity. The rendered 125-percent Foresight values and
enabled difficulty examples are explicitly supplied formatting fixtures. At that
checkpoint the real query's unavailable output was independently tested; the
2026-09-08 derived-metric regressions above supersede that Foresight expectation.

The first run caught an off-tree `release_focus` call during disabled-state
publication; it is now tree-guarded. Independent drawing review found metric
backgrounds overpainting the register separator; each metric now restores its
portion after painting. Final tests and GPU runs exit zero with the existing
24 Dialogic orphans and certificate/Unicode environment messages. Logs, six
captures and the full invocation ledger are in `evidence/minesweeper_chrome`.

## Connected desktop panel continuation

`MinesweeperPanel` now composes the register, worksheet and dock in one 400-by-328
native body. Font-driven band heights remain measured, including full Rules and
Assignments row capacity. The panel binds one application port, refreshes after
its own commands, and exposes an explicit `refresh()` for external publications.
There is no speculative per-frame owner polling. Canonical host composition and
production desktop launcher cutover remain separate work.

`MinesweeperPanelPort` publishes only the public board, register, nine assignment
statuses and current action availability. It rejects mixed reads, preserves the
board port's identity/revision admission, and checks unpaid difficulty before
allocating a Reveal command. Changing the selected tier at the same board revision
therefore refuses the old command without spending a round. Active boards retain
their frozen tier even when the preference changes.

Real coordinator integration exposed a retained-data distinction that component
fixtures had missed: its board wrapper stores only the paid checkpoint marker.
The complete paid receipt lives in the first-Reveal command journal. The register
query now resolves that existing receipt with checkpoint, transaction, identity,
revision and first-cell checks. Missing, mismatched or ambiguous evidence remains
unavailable. No persistent schema or gameplay transaction was changed, and private
receipt evidence stays outside UI controls.

Dock mode buttons and the grid's F shortcut share selection. Information sheets
leave the register and dock visible but inactive, then restore the source action,
mode, cell and manual board scroll. Retained sheet focus includes its scrollbar
through language, scale and claim updates. An unchanged assignment publication
does not rebuild the sheet. A failed public read retains the last drawn facts and
blocks input without inventing a custody transition; a valid refresh restores
interaction. Current mode actions follow the port's all-or-none contract.
Hosts connect the panel's first/last focus stops with
`connect_host_focus(previous, next)`. Explicit endpoints avoid Godot's nested
default Tab wrap; both forward and reverse exits survive a public refresh.

Same-size board publications reuse existing cell controls. Grid validation uses
one probe rather than allocating a duplicate grid, and panel refresh avoids
reconfiguring the worksheet when its measured band is unchanged. This preserves
the touch long-press release latch during synchronous Flag publication.

This historical panel checkpoint preceded terminal settlement, canonical challenge
and production host/save integration. Its unavailable New Board/Foresight status
is superseded by the 2026-09-08 behavior described above; difficulty changes remain
disabled. These component results do not by themselves close further input and
accessibility proof, largest-English-label usability, or the full ten-family UI goal.

Verification: **165 tests / 5,757 assertions pass** across nineteen suites,
including real coordinator/issuer/GameState integration, existing durable first
Reveal/completion transactions, all eighteen locale/scale/target combinations,
sheet focus, failed-read lockout/recovery, and synchronous long-press publication.
Four final OpenGL captures show the assembled desktop panel and information sheets
in `evidence/minesweeper_panel`; they use explicitly supplied public fixtures.
Actual-owner behavior is established by the integration tests, not inferred from
those images. The final tests and render runs exit zero with the same pre-existing
24 Dialogic orphans and certificate/Unicode environment messages.

The invocation ledger retains the failed initial compile, the retained receipt
mismatch, and the Tab-wrap regression runs as well as the passing final runs.
Independent review checked the journal linkage, command freshness, publication
boundaries and host focus connection. No merge, runtime cutover or player-save
mutation was performed.

## Desktop app and Home lifecycle continuation

The actual `MinesweeperApp.tscn` now mounts the connected panel. The placeholder
difficulty tabs, simulation outcome buttons and invitation notification nodes are
removed. The inherited local title bar is hidden; the app occupies the desktop's
800-by-656 logical body beneath its single shared 64-pixel strip.

`ComputerDesktop.configure_minesweeper` accepts an explicitly supplied ready
presentation/lifecycle port and the retained desktop host. The launcher remains
unavailable when that service is absent. It does not obtain a private Bootstrap
field or install a fixture. The stable Bootstrap's application coordinator still
lacks base generation/checkpoint configuration and a live-run identity context;
its recorded object IDs are construction evidence, not readiness. Production
startup wiring remains an integration dependency alongside the ongoing external
`dwm-oyo.3` work, whose last inspected state is still uncommitted Step 5 at
`1790785bc`. No files from that dirty worktree were changed or absorbed.

Both presentation ports now provide `set_foreground`. Home suspends an active
board before the host hides its cached app; reopening resumes it before input is
restored. Identity, phase, revision and public projection are rechecked before
issuer allocation. Unpaid/prepared and already-correct visibility transitions are
no-ops. Suspension preserves the board, Flags, action history and frozen tier,
spends nothing and performs no generation. Preparing, unsettled terminal and
settling custody still refuse departure; visibility cannot invent settlement.

The app remembers semantic focus, mode, cell and manual scroll across Home. First
entry uses the grid's repaired legal cell, including an offscreen forced first
cell; an invalid remembered cell falls back to current legal focus. Hidden apps
and application/window focus loss cancel pointer, touch and keyboard latches.
Rules and Assignments disable shared Home and consume Back locally. Missing
lifecycle publications block the old view without rewriting its public facts;
the existing desktop failure route receives recovery requests.

Locale and text/target preferences update the mounted app without resetting its
board or reading position. Canonical `text_size` and `large_targets` keys take
precedence, with the committed lineage's `font_scale` and `large_click_targets`
used only when the newer keys are absent. This is read compatibility, not a save
migration or proof that the separate Settings branch is integrated. The app uses
After Hours until a captured run palette owner is available.

Actual GPU inspection found that shared Home's draw guard rejected an inherited
theme even though the button was clickable. The primitive now checks its resolved
Desktop color instead of requiring a local Theme resource. A failing pixel
regression preceded the fix; final captures prove the Home pictogram and its
blocked-action edge while Rules owns input.

Verification: **205 tests / 6,269 assertions pass** across twenty-three suites,
including seven actual Desktop/App tests over the real host, coordinator, issuer,
GameState and public queries. Generation and checkpoint fixtures remain explicitly
in-memory and test-only. Three OpenGL captures show real Reveal/Flag, Rules, and
Home/reopen in EN100, zh-CN125 and zh-HK150 Large. Evidence and the complete wrapper
invocation ledger are in `evidence/minesweeper_app`. Existing durable transaction
tests also pass. The final runs retain the existing 24 Dialogic orphans and known
certificate/Unicode diagnostics.

The documented `tools/desktop_shell/verify.py` runner also passes the existing
Contacts/Settings/shared-shell regression in its disposable no-autoload project;
its portable evidence and exact source hashes are refreshed. An earlier direct
invocation of that suite in the main project failed because game autoloads
conflicted with the suite's explicitly constructed managers; that invocation is
retained and is not reported as a product regression. Raw disposable-project logs
remain intact; portable copies use LF and one final newline. A separate initial
focus test's zero-scroll assumption was corrected to the actual contract: the
current legal cell must be fully visible and the obsolete manual pan discarded.

This is an implemented and tested injected desktop route, not production gameplay
cutover or Minesweeper completion. Production generation/live identity, New Board,
tier changes, Foresight, settled terminal inspection, canonical hosts, remaining
accessibility/input palettes and combined restore/save integration remain open.

## Accessibility palette continuation

Minesweeper now supplies all sixteen After-Hours/Midnight, Standard/High Contrast,
and Standard/Protan/Deutan/Tritan combinations. The literal role tables reuse the
authored Settings values through the documented semantic mapping in
[presentation tuples](minesweeper-presentation-tuples.md). Both original Standard
appearances are unchanged. Domain marks, single-ink numbers, labels, selected seams
and detached focus rails retain their meaning and geometry.

The tuple reaches existing and newly created cells, register metrics, dock actions,
worksheet rails, and open or newly opened Rules/Assignments sheets. Invalid tuple
requests retain the previous valid presentation. Colour-only reconfiguration keeps
manual pan, sheet scroll, semantic focus, mode, public board facts and held input.
An independent review found that the App's unconditional scroll restoration cancelled
held touches even when the scroll was unchanged. An App-level failing regression
preceded the conditional restoration fix; both preference publications now retain
that touch without issuing an action.

The App observes `high_contrast` and `colour_differentiation` under
`preferences.accessibility`. When the latter is absent, the existing profile's
`colorblind_mode` values map read-only from none/protanopia/deuteranopia/tritanopia
to standard/protan/deutan/tritan. A present canonical value takes precedence.
This changes neither profile storage nor migration. The App still uses After-Hours
until a real captured-run palette owner is available; pending next-run Dark intent
is not used as current-run evidence.

Verification: **218 tests / 7,800 assertions pass** across twenty-five suites,
including retained transaction and actual desktop-host integration regressions.
Numeric sRGB tests check the authored text and state-ink pairs against project
thresholds; they are not a claim of full assistive-technology acceptance. Eighteen
OpenGL captures cover all sixteen tuples plus Rules and scrolled Assignments,
distributed across EN100, zh-CN125 and zh-HK150 Large. Pixel assertions check actual
cell/mark, register, selected seam, disabled bar, scrollbar, focus and sheet colours.
The renderer uses explicitly labelled public reducer fixtures, not production
generation. Evidence is in `evidence/minesweeper_accessibility`; its invocation
ledger includes initial preference failures and the held-touch regression.
Final runs exit zero with the pre-existing 24 Dialogic orphans and known environment
diagnostics. Portable logs use LF and one final newline; raw logs remain intact.

This completes the palette implementation checkpoint. Final AT/readability and
largest-English-label usability, remaining input support, captured-run palette,
production gameplay owners, canonical hosts and combined save/restore integration
remain open. Minesweeper and the ten-family goal remain in progress.

## English wrapping and contact clearance continuation

Five exact English chrome labels now receive discretionary break hints during
shaping: Intermediate, Expert, Reveal, Assignments and Foresight. Source copy,
accessibility names, sentences, Chinese text, fonts and fixed bay widths remain
unchanged. The hints follow [Unicode soft-hyphen semantics](https://www.unicode.org/reports/tr14/#SoftHyphen):
they display a hyphen only at a taken line break. A fitting single-line label has
the same measured width as its plain source.

The native comparison kept full 20/25/30-logical-pixel fonts and both target sizes.
It rejected a Beginner candidate that added a third line at 150%, and rejected a
coarser Intermediate pattern whose `medi-` line measured 73 pixels against the
Large target's 72-pixel aperture. No aperture relaxation or bay redistribution was
adopted. The selected Intermediate pattern uses three lines at 125%; the register
grows under the existing vertical-measurement law and the worksheet yields.
When an optional hinted paragraph exceeds a narrower supported aperture, shaping
retries the original adaptive text with the same font, width and validation.
The existing 80-pixel/125% component case established this fallback requirement.

Real pointer-state captures then found five cases where the old Hover edge
intersected antialiased glyph pixels, including the unchanged Beginner label.
The edge moves one native pixel toward the inner face border, retaining its
thickness and height. It stays outside detached Focus rails; Press still replaces
Hover and Disabled suppresses both. A failing GPU run preceded the correction.

Verification: **222 tests / 7,904 assertions pass** across twenty-five suites.
The final OpenGL run covers eighteen assembled panels and eighteen contact atlases:
all three locales, three text sizes, and both target sizes. All 360 resting,
pointer-Hover, held-Press and Selected-plus-Focus samples have zero changed glyph
pixels against a separately rendered text reference, including antialiased edges.
This proves the sampled ink clearance, not full assistive-technology acceptance.
Evidence, measurements, the initial comparison and the complete invocation ledger
are in `evidence/minesweeper_typography`; raw isolated logs remain intact. Final
native runs exit zero with the existing 24 Dialogic orphans and environment messages.

Large English labels remain constrained by the accepted fixed-width design;
Beginner and Drag still wrap, and final readability acceptance remains open.
The latest external `dwm-oyo.3` E9 work is still uncommitted at `1790785bc`.
Inspection found no public ready Schedule or Minesweeper owner seam: Schedule
services are private, Minesweeper base configuration is absent and its board port
retains a boot identity. No dirty owner work was copied or integrated.
The next independent family task is `dwm-eei.10`, a live witnessed-scene caption
field on actual Dialogic/Hospital playback. The full ten-family goal stays active.

## 2026-09-11 -- Full-board fitting and completed-round controls

The user's confirmed requirement to show the whole board supersedes the fixed-size,
scrolling-only presentation rule in the August 13 amendment sections 8.1-8.2. Desktop and
canonical worksheets now uniformly scale the rendered grid down as needed to fit
the available well, center it, and expose no board scrollbars. Saved dimensions,
cell indices, mine placement, and grid-local hit targets are unchanged. Godot's
Control transform maps pointer and touch positions back to those local targets.
Text-size preferences remain separate from board geometry; the desktop body also
scales to fit a smaller host. Cell borders remain inside their own cell and at
least one rendered pixel wide, including window stretch, so fitted rules do not
disappear or get overpainted by adjacent faces. Information-sheet scrolling is unchanged.

Flag mode accepts a cell's published Chord action, as Reveal mode does. It continues
to flag or unflag covered cells and never invents Chord permission from appearance.
Drag remains a gesture-only mode and cannot command a cell.

After durable settlement, a different difficulty can dismiss the retained result
and expose the next legal board at that tier. The existing configuration transaction
commits the dismissal and selected tier together, preserves completion receipts,
and retains the exact failed request for retry. Selecting a tier does not pay for
the next first Reveal; ordinary entry eligibility and payment still apply. Unsettled
results, stale revisions, pending configuration retries and shared custody gates
remain authoritative. Space invokes the published New Board action even though a
settled board intentionally has no cell focus. Untouched boards still reject New
Board when the owner has not published that capability.

Regression coverage includes flag-mode Chord, terminal Space without grid focus,
connected terminal tier selection, failed checkpoint retry, and full containment
across desktop/canonical hosts, tiers, text presets, target sizes and smaller wells.
Native acceptance uses `tests/manual/verify_minesweeper_ui_controls.gd` with isolated
copied player data and actual pointer/key routing. All 176 focused tests passed
across the UI, port, transaction and cell suites, including the affected fixture
reruns. The final native run passed every internal grid-rule pixel check for all
three tiers at 150% text, actual 960x540 and 640x360 window resizes, flag-mode Chord,
terminal difficulty selection, Space and ordinary round payment. The Expert grid,
small-window grid and active numbers/flags captures were visually inspected.

Evidence: `.godot/phase2r_logs/ms-ui-full.log`, `ms-ui-recheck.log`,
`ms-port-recheck.log`, `ms-cell-final.log` and `ms-ui-pixels.log`. Final images are
in `.godot/phase2r_tests/8c017f68-1fd1-423f-846b-5f48ba1031b5/appdata/Godot/app_userdata/DWM/evidence/playable/`.

## 2026-09-13: permanent board view controls (`dwm-vky.5`)

The September 12 amendment, Section 4.1, replaces unconditional fitting with a
36-logical-pixel manual default. The shared worksheet offers **− / size / +** and
**Fit entire board**. Manual sizes are 10–60 in steps of 2; Fit may use smaller,
fractional cells and restores the remembered manual size when switched off.
Text size and Large Targets change surrounding controls independently of cell size.

| Input | View action |
| --- | --- |
| Ctrl + wheel over the board or empty well | One size step per wheel event |
| Two-finger pinch | Quantized zoom around the midpoint; neither release plays a cell |
| LT / RT with board focus | One size step per fresh trigger press; both held do nothing |
| Wheel, Drag mode, touch drag, right stick, rails | Pan the manual board |
| Board navigation | Bring the focused cell into view; vertical edge can enter the zoom controls |

Beginner, Intermediate and Expert have independent preferences. All canonical
challenges and Gallery Practice share the fourth preference pair. Debug uses its
current app difficulty. These eight values belong to ProfileManager, survive
New Account and save restoration, and are absent from gameplay snapshots.
Old profiles receive the defaults only when all eight fields are absent; partial
or invalid new shapes remain invalid.

Wheel changes coalesce and a pinch commits once when finished. View changes use
the existing atomic preference transaction, never a gameplay checkpoint. A failed
write restores the saved view and displays its size and error; difficulty changes
and Practice exit flush before changing their host. Held gestures, Pause and input
custody suppress zoom. Triggers must be observed neutral after returning.

Automated coverage is in `test_minesweeper_view_preferences.gd`,
`test_minesweeper_worksheet_view_layout.gd`, `test_minesweeper_view_controls.gd`,
`test_minesweeper_zoom_input.gd` and the real SubViewport routing suite
`tests/scene/test_minesweeper_view_gestures.gd`. The render fixture
`tests/ui/render_minesweeper_view_controls.gd` covers manual Expert, Fit Expert,
150% Traditional Chinese with Large Targets, and Beginner at 60 pixels.
Physical touchscreen/gamepad hardware remains a manual device check; synthetic
events exercise Godot's actual GUI routing and focus paths.

After merging clicking-lag changes through `c8aedfe78`, all 446 tests in 31 focused
suites passed. The final native run also passed explicit Fit, all tiers/text sizes,
small-window grid pixels, flag-mode Chord, terminal tier changes, Space and costs.
Durable logs, invocation records and selected captures are in
`evidence/minesweeper_view_controls`. The latency benchmark still shows slow result
processing; `dwm-634.1` remains a separate open performance task.
