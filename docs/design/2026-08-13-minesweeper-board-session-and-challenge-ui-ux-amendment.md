---
id: spec.minesweeper_board_session_challenge_ui_ux_amendment
kind: design_amendment
schema_version: 1
amends: spec.desktop_minesweeper_shop_schedule_amendment
amends_path: "docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md"
decision_status: accepted
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
self_reviewed_on: "2026-08-13"
written_spec_approved_on: "2026-08-13"
implementation_authorized: false
created_on: "2026-08-13"
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
language: gdscript
scope: ["shared_minesweeper_board_surface_and_variant_c_composition","desktop_board_catalog_paid_session_and_free_replacement","desktop_assignments_rewards_and_terminal_inspection","solo_pair_and_rehearsal_challenge_board_projection","foresight_no_flag_action_count_and_perfect_classification","special_mine_nonperfect_terminal_choice","minesweeper_pointer_touch_keyboard_controller_and_assistive_input","minesweeper_exact_persistence_recovery_failure_and_verification"]
---

# Minesweeper Board, Desktop Session, and Challenge UI/UX Amendment

## 1. Status and objective

This proposed written amendment records the conversation-approved production
design for the real Minesweeper board surface, desktop Minesweeper session,
canonical solo and Priscilla-Lavinia challenge boards, and Full Date Rehearsal
board projection.

The conversation approved the product decisions and selected visual approach.
The exact written artifact is not accepted authority until the user reviews and
approves these bytes after self-review. Written approval will establish bounded
design authority only. It will not authorize implementation, Beads mutation,
plan execution, schema migration, scene replacement, content production, or a
commit.

The selected experience is **Variant C: classified status, uninterrupted
worksheet, pinned actions**:

- a compact status register owns difficulty and visible board facts;
- the largest flexible region is one two-axis scrollable worksheet; and
- a persistent lower dock owns the three action modes and the host's few legal
  secondary actions.

The design has nine objectives:

- provide real deterministic Minesweeper rather than outcome buttons;
- use one reusable board surface across desktop, canonical challenge, and Full
  Date Rehearsal without mixing their costs or consequences;
- preserve fixed, readable cells at every supported text and target preset;
- make pointer, touch, keyboard, controller, and assistive play semantically
  equivalent;
- let the desktop audience freely replace a touched worksheet inside one
  already-paid session without creating a reward, result, or second cost;
- expose only truthful ordinary board facts while keeping hidden extra-mine,
  explosion-assignment, special-mine, and story-outcome logic concealed;
- make Perfect, Foresight, No-flag, and the non-Perfect special-mine boundary
  exact and non-rerollable;
- save and restore every canonical board phase without saving live Controls,
  scroll animation, or input modes; and
- remain quiet, institutional, accessible, and technically truthful without a
  tutorial, timer, fake failure, or explanatory cost copy.

### 1.1 Conversation-approved closures

The following decisions are closed product law for this amendment:

- Desktop Beginner is `8 x 8` with `10` base mines.
- Desktop Intermediate is `16 x 16` with `40` base mines.
- Desktop Expert is `22 x 22` with `99` base mines.
- Every solo challenge and every visible Priscilla-Lavinia challenge is
  `18 x 18` with `36` base mines.
- The same canonical sizes and ordinary production rules apply inside Full Date
  Rehearsal; Rehearsal changes persistence and consequence capability, not the
  board into a debug toy.
- Cells are fixed at `48 x 48` logical pixels in ordinary target mode and
  `64 x 64` in Large Targets. The board scrolls on both axes. It never shrinks,
  zooms, or changes topology to fit.
- There are exactly three visible action modes in this order:
  `Reveal | Flag | Drag`. There is no Chord mode or Chord button.
- Reveal on an already revealed numbered cell submits the ordinary Minesweeper
  Chord command when its adjacent flags equal that number.
- Right-click and stationary long-press submit a direct Flag or Unflag command
  in every mode without changing the selected mode.
- In Drag mode, primary movement pans. A primary press released without a drag
  does nothing. Direct right-click or stationary long-press Flag remains legal.
- `F` toggles Flag and Reveal. From Drag, the first `F` selects Flag and the
  next selects Reveal. Drag is entered only through its visible action.
- Desktop `Space` invokes New Board only while the safe desktop board surface
  owns input. It never leaks through a sheet, modal, recovery surface, another
  app, or route.
- Every fresh board entry, successful board replacement, successful Load
  commit, or technical reconstruction starts in Reveal mode. Merely opening or
  cancelling Load changes nothing. Mode is presentation state and is never
  serialized. Opening and closing Rules or Assignments preserves the current
  mode and returns exact focus.
- Desktop first Reveal alone starts a paid desktop session. It consumes exactly
  one Motivation and one signed round opportunity once.
- After that paid start, a touched preterminal desktop worksheet may be replaced
  without another Motivation cost or signed-round decrement. Replacement may
  be repeated without a numeric limit until the paid session settles.
- New Board on a worksheet with no accepted Reveal is a true no-op. It allocates
  no candidate, nonce, RNG draw, generator work, receipt, or layout ordinal.
- A paid-session difficulty change is a deliberate replacement. Every admitted
  replacement freezes a new candidate from the then-current pressure, penalty,
  Lucky, Debug, and other gameplay capability inputs. Merely buying or changing
  something while the old board is suspended never mutates that board.
- A replacement emits no result, money, coin, assignment, contact progression,
  completion count, relationship effect, mastery, or forfeit.
- Terminal desktop New Board closes the already-settled inspection surface and
  returns to the next unpaid worksheet shell. It does not silently charge or
  reveal a cell.
- Canonical solo and pair challenges never expose New Board or accept Reset.
- Full Date offers Rehearse Again only after its whole hypothetical date
  completes, under the archive law; it never resets an unfinished board.
- The board shows no timer anywhere.
- The board shows no visible coordinate axes.
- The game shows no `Preparing board`, candidate count, solver progress,
  spinner, animated ellipsis, or comparable preparation copy.
- The game shows no `First Reveal: -1 Motivation`, remaining-cost tutorial, or
  other first-Reveal explanation.
- The visible signed mine estimate is the exact adopted mine count minus the
  number of placed flags. It may become negative. It is not a claim about the
  actual number of unflagged mines.
- Foresight displays the floored integer percentage, but qualification compares
  the exact unrounded ratio. Foresight qualifies at **greater than or equal to
  100 percent**.
- The first accepted Flag command permanently loses No-flag for that generated
  layout. Unflag does not restore it. A genuinely new replacement layout starts
  with its own intact No-flag state.
- A successful Reveal, Flag, Unflag, or Chord command counts as exactly one
  action. Navigation, focus, panning, mode changes, rejected input, duplicate
  delivery, sheets, and New Board do not count.
- Perfect means exact Foresight qualification, intact No-flag, or both.
  Accessibility settings never invalidate Perfect.
- A Perfect solo clear commits Foresight and exits the board automatically.
  It offers no Continue/special-mine choice.
- Perfect and Dark are mutually exclusive. The former Perfect-then-Dark branch
  is retired.
- Only a non-Perfect solo clear exposes Continue and the one preselected special
  mine. Continue commits the ordinary Loved outcome; deliberately activating
  the marked mine commits Dark. Exactly one outcome may commit.
- The special mine is selected atomically from the board's fixed adopted mine
  set before that adopted revision is published. For Default/Lucky this occurs
  inside first-Reveal adoption; it does not require a pre-existing mine layout.
  It counts in the mine total and numbered clues, is ordinarily flaggable, and
  is indistinguishable before the non-Perfect clear. Revealing it before clear
  is an ordinary explosion with its already-frozen H/U/A assignment.
- After a non-Perfect clear, every ordinary cell command locks. The same special
  mine receives a non-colour mark and remains activatable even if flagged.
  Continue receives initial focus. Neither action explains its consequence or
  asks for confirmation.
- Priscilla-Lavinia boards have no special mine and no relationship choice.
  Perfect, Solved, or Exploded commits and returns automatically.
- Desktop Home or Back suspends the exact board and returns to the launcher; no
  desktop pause sheet exists. Canonical narrative Back uses the accepted quiet
  pause surface. Rehearsal uses the accepted archive leave law.
- The nine one-Coin desktop Assignments are visible from the beginning of a run
  and claim atomically at terminal settlement. There are no hidden assignments,
  progress bars, denominators, or manual Claim buttons.

## 2. Authority and precedence

### 2.1 Authority spine

Once accepted, this exact artifact controls intended behavior inside its eight
frontmatter scope topics over conflicting recovered documents, prompt packets,
proposed or hash-bound plans, tests, current runtime scaffolds, and the
disposable HTML visual comparison.

It directly amends the accepted 2026-08-11 Desktop Minesweeper Lifecycle, Shop
Capabilities, and Schedule-Warning amendment. That parent retains authority
for:

- board identity, deterministic generation, first-cell materialization, Debug
  certification, no-guess proof, hidden extra mines, isolated RNG, and version
  ownership;
- Lucky, Debug, and Supportz purchase identity, price, caps, and prospective
  capability law except the newly defined free-replacement candidate boundary;
- first paid Reveal transaction order, signed round floor, Home/app suspension,
  causal-day discard/forfeit, Load, Logout, and condition-driven destination;
- primitive snapshots, stable command checkpoints, stale-input rejection,
  cross-app merge, recovery, and exactly-once completion; and
- the prohibition on explaining hidden extra-mine and safety formulas.

This amendment introduces a paid desktop **session** above individual
replacement layouts. It does not weaken the parent's one-time cost or stable
command law. It changes which later candidate may exist within the already-paid
session and defines the player-facing board.

The accepted 2026-08-07 Seven-Day Flow and Dialogic Structure design retains
authority for invitation/date eligibility, relationship axes, H/U/A meaning,
affection and attitude consequences, promotion valves, pair observation,
profile attempt permanence, branch behavior, and current-run mastery except the
exact Perfect-threshold and post-clear clauses expressly superseded here.

The accepted 2026-08-13 Narrative Scene Host amendment owns challenge entry,
the frozen/dimmed authored scene, narrative-control withdrawal, result handoff,
post-scene reconstruction, canonical quiet pause, and host focus transfer. This
amendment supplies the required production board geometry, controls, capability
handshake, terminal UI, and first playable focus target.

The accepted Gallery and Rehearsal amendment owns Full Date eligibility,
self-contained seeds, sandbox isolation, visited-line-only merge, Rehearse
Again, archive exit, and the prohibition on save records or canonical effects.
This amendment supplies the same production board under a restricted
`rehearsal_full_date` capability mode.

The accepted Main Menu and Desktop Shell amendment owns the 1280-by-720 canvas,
480/800 in-run split, 800-by-656 app body, global Home strip, overlay priority,
inert matte, app routing, and same-day host cache. This amendment owns only the
Minesweeper contents of that app body and the board-specific Back behavior.

The accepted Settings amendment owns text size, Large Targets, language,
contrast, colour vision, Reduced Motion, Screen Shake, controls, audio, TTS, and
quiet suspension. This amendment projects those preferences without storing a
second copy.

The accepted Backup amendment owns Save, Load, shortcuts, confirmations,
atomic restore, fallback, and failure surfaces. This amendment supplies exact
Minesweeper state to that owner and never writes a file itself.

The accepted Shop amendment owns the visible Lucky, Debug, and Supportz catalog
and transactions. This amendment reads only committed capability facts at a
registered candidate-freeze boundary.

Authority resolves by declared scope, not newest filename. An ambiguous owner
blocks implementation until reconciled. Beads owns mutable work status and
dependencies only; neither a ready Bead nor approval of this design authorizes
runtime work.

### 2.2 Current physical and execution state

At the time of writing:

- runtime implementation is not authorized;
- `MinesweeperApp.tscn` is an inherited AppWindowBase scaffold with difficulty
  tabs, empty status/tool rows, an empty ScrollContainer, and debug simulation
  result buttons;
- `MinesweeperApp.gd` only hides placeholder panels and emits no board command;
- `MinesweeperChallengeOverlay.tscn` is a `9 x 9` placeholder with direct
  affection, True Path, and Dark Mine result buttons;
- `MinesweeperChallengeOverlay.gd` emits caller-supplied result dictionaries
  rather than rendering or commanding a board;
- `MinesweeperTaskData` and DataCatalog expose the nine task identities, while
  the final immutable task registry and player-facing sheet do not exist;
- current GameState starts and finishes coarse rounds, applies existing reward
  tables, and stores provisional fields, but has no cell board, paid-session
  replacement identity, exact metrics, or production view;
- accepted persistence and board contracts are ahead of current runtime code;
- prompt requirements and older Phase-2R plans still contain a lifetime save
  lock and simulator-era boundaries already superseded by accepted amendments;
- the August relationship-board plan still encodes `efficiency_gt_100`, every
  clear entering a choice, and Perfect-then-Dark;
- current scenes expose English literals, result buttons, 9-column placeholder
  geometry, and a window X that are not production authority;
- no focused scene test proves a playable grid, two-axis scroll, mode parity,
  48/64 targets, text presets, canonical challenge handoff, or exact restore;
  and
- the HTML layout companion under `.superpowers/` is intentionally disposable,
  ignored visual evidence. It is neither a source file nor a pixel oracle.

The physical scaffold is evidence of drift, not a constraint to preserve.

## 3. Scope boundary

### 3.1 In scope

This amendment defines:

- the closed desktop and canonical board-size catalog;
- the reusable Minesweeper surface and Variant C information architecture;
- top status, board viewport, bottom dock, sheets, terminal projections, focus,
  and host-specific control visibility;
- fixed cell size, two-axis scroll, visible board states, and no-coordinate law;
- Reveal, Flag, Drag, Chord-through-Reveal, right-click, long-press, keyboard,
  controller, assistive action, and New Board input semantics;
- action count, 3BV use, floored Foresight display, exact Foresight threshold,
  No-flag lifetime, Perfect reasons, and truthful mine estimate;
- the desktop paid-session and free-replacement lifecycle;
- candidate input re-freeze, replacement idempotency, reward isolation, and
  terminal inspection;
- the nine desktop Assignment projections and claim boundary;
- the solo non-Perfect special-mine phase, Perfect automatic return, and pair
  automatic return;
- desktop, canonical, and Rehearsal pause/exit capability differences;
- exact snapshot additions, restoration, presentation-cache reset, and failure
  behavior;
- component and command ownership needed by later implementation; and
- localization, accessibility, motion, audio, trust, and verification law.

### 3.2 Out of scope

This amendment does not define:

- final dialogue, narrative prose, route content, character reaction, portrait,
  background, CG, animation, music, ambience, or sound assets;
- new invitations, dates, relationship outcomes, promotion thresholds, pair
  encounter modes, ending gates, or Observer evidence;
- new money reward amounts, pressure reward values, daily caps, Shop prices,
  inventory caps, Supportz limits, or Assignment reward amounts;
- a replacement generator, verifier algorithm, PRNG, hidden extra-mine formula,
  H/U/A distribution, or first-cell safety rule;
- final Godot node paths, script class names, signal names, file decomposition,
  or an implementation plan;
- mobile portrait topology, zoom, variable cell size, custom board themes,
  online scores, leaderboards, or analytics;
- a tutorial, guided first game, hint solver, probability display, automatic
  flagging, undo, rewind, or mine relocation;
- a visible story-result selector, relationship menu, debug completion button,
  or Rehearsal cheat; or
- any runtime, Beads, requirement, plan, schema, localization, scene, test,
  asset, or save migration mutation.

## 4. Chosen design and rejected alternatives

### 4.1 Chosen: Variant C, pinned tool dock

The board surface always has three vertical regions:

1. **status register** — compact, factual, and host-filtered;
2. **worksheet viewport** — the largest flexible region; and
3. **pinned action dock** — stable modes on the left and contextual actions on
   the right.

This structure keeps classification separate from action, gives the worksheet
maximum uninterrupted area, and keeps action positions stable while scrolling.
The selected HTML prototype is a disposable comparison only. The normative
rules in this document, not HTML pixels or text, control production.

### 4.2 Rejected: registrar strip above the board

The earlier horizontal registrar placed difficulty, metrics, modes, and sheets
inside one dense upper band. It was readable but made classification and action
compete and reduced the visual hierarchy selected by the user.

### 4.3 Rejected: vertical margin ledger

A permanent left ledger made actions legible but reduced board width in the
already narrow 800-pixel desktop pane and increased horizontal scrolling.

### 4.4 Rejected: shrinking or zooming the board

Changing cell size by board tier, text preset, window dimensions, or content
would damage motor memory and target truth. The worksheet scrolls instead.

### 4.5 Rejected: Windows Minesweeper imitation

There is no smiley face, seven-segment timer, bevel clone, faux Windows title
bar, generic bomb counter, or nostalgia skin. New Board is a plain labelled
institutional control.

### 4.6 Rejected: result and outcome controls

Perfect, Solved, Exploded, No-flag, Foresight, affection, and Dark are computed
facts, never buttons. The post-clear marked mine is a physical board cell, not a
`Dark` action label.

### 4.7 Rejected: preparation theatre

No spinner, progress bar, loading copy, solver text, candidate count, fake
freeze, or glitch accompanies generation. An old board may remain visibly inert
while bounded preparation proceeds, but technical truth is never fictionalized.

### 4.8 Rejected: visible tutorial and mechanic exposition

There is no first-Reveal cost copy, threshold explanation, hidden-extra label,
special-mine explanation, or mandatory instruction overlay. The visible action
names, optional minimal Rules sheet, ordinary feedback, and exploration carry
the interaction.

## 5. Vocabulary and ownership-facing state

### 5.1 Board host

One closed host capability value:

    desktop_app
    canonical_solo
    canonical_pair
    rehearsal_solo
    rehearsal_pair

The value controls costs, New Board, Assignments, special mine, terminal return,
pause/leave, and persistence. It does not change basic Minesweeper commands.
Unknown values fail closed.

### 5.2 Board specification

One immutable candidate input record containing the registered tier or
challenge kind, dimensions, base and requested mine facts, capability set,
pressure/penalty inputs, versions, RNG identity, and host capability required by
the accepted generator law.

### 5.3 Paid desktop session

The canonical desktop interval beginning with one successfully committed paid
first Reveal and ending with one terminal result or governing forfeit. It owns
one session ID, one app-round ordinal, one Motivation/round cost receipt, and
one or more sequential layout generations.

### 5.4 Board generation envelope

One shell, candidate, or adopted layout inside a desktop session, canonical
attempt, or Rehearsal sandbox. It owns an ordinal, identity, immutable BoardSpec
where already frozen, optional prepared/materialized layout, reveals, flags,
action count, No-flag fact, 3BV, terminal fact, and command receipts. Only the
desktop variant may belong to a paid session; replacing its envelope never
replaces or duplicates that session's cost receipt.

### 5.5 Touched layout

A layout whose first accepted Reveal has committed. Pointer contact, focus,
navigation, panning, mode changes, a rejected action, flagging before Reveal,
or Debug preparation does not make a layout touched.

### 5.6 Unpaid worksheet shell

A lightweight covered worksheet state shown while no Default/Lucky mine layout
exists in any interactive host. It may own host/session-or-attempt identity,
selected tier or fixed challenge profile, dimensions, a shell revision, flags,
ordered pre-Reveal Flag/Unflag receipts, action count, and the resulting No-flag latch.
It owns no mine locations, 3BV, result, RNG draw, generator candidate, payment,
round decrement, completion, or story consequence.

Its first accepted Reveal atomically materializes the real layout without using
flag positions as mine-placement constraints, carries the truthful pre-Reveal
flags/history/count/No-flag fact into that layout, appends the Reveal action,
and performs the one paid-start transaction only for the desktop host.
This narrow state extension prevents a visible pre-Reveal flag from vanishing
or falsely qualifying as No-flag without treating it as a generated board.

### 5.7 Action count

The number of successfully committed Reveal, Flag, Unflag, and Chord commands
for one generation envelope. It begins on the shell, carries unchanged into
that shell's adopted layout, resets only with a genuinely new envelope, and
freezes at terminal state.

### 5.8 Foresight

The exact rational ratio `3BV / action_count`, rendered publicly as
`floor(100 * 3BV / action_count)%`. It is unavailable before both operands are
valid. Qualification uses exact integer/rational comparison, never the rounded
display string.

### 5.9 No-flag

One generation-envelope Boolean initially true and irreversibly false after the
first accepted transition from unflagged to flagged. It begins on the shell,
carries into its adopted layout, and is unaffected by unflag, input mode,
visual assistance, or save/load.

### 5.10 Perfect

One terminal board classification with a nonempty sorted reason set drawn from:

    efficiency_gte_100
    no_flag

The old `efficiency_gt_100` token is not part of the target schema.

### 5.11 Special mine

One solo-only ordinary mine identity selected atomically from the fixed adopted
mine set before that board revision is published. Default/Lucky selection may
therefore occur within the first-Reveal adoption transaction rather than before
the audience submits that Reveal. `special` affects only the legal
post-non-Perfect-clear terminal activation. It never changes clues, explosion
truth, mine count, or pre-clear appearance.

### 5.12 Terminal inspection

A read-only desktop projection of the durably settled final grid, exact visible
marks, frozen mastery facts, current money/coin totals, and New Board action.
The paid session is already closed. The inspection snapshot cannot accept cell
commands or pay consequences again.

## 6. Closed board catalog and host matrix

### 6.1 Base configurations

| Public board | Dimensions | Base mines | Difficulty control |
|---|---:|---:|---|
| Desktop Beginner | `8 x 8` | 10 | Desktop only |
| Desktop Intermediate | `16 x 16` | 40 | Desktop only |
| Desktop Expert | `22 x 22` | 99 | Desktop only |
| Solo challenge | `18 x 18` | 36 | Fixed and hidden as a choice |
| Visible P-L challenge | `18 x 18` | 36 | Fixed and hidden as a choice |

These values are base configuration facts. Accepted hidden-extra capability law
may produce a truthful actual mine count above the base. The UI never calls the
extra amount an extra, explains its source, or implies the base number is the
adopted total.

### 6.2 Host capability matrix

| Capability | Desktop | Canonical solo | Canonical P-L | Full Date Rehearsal |
|---|---|---|---|---|
| Audience selects tier | Yes | No | No | No |
| First Reveal costs desktop Motivation/round | Once per paid session | No | No | No |
| Free preterminal New Board | Yes, after touch | No | No | No |
| Assignments and app rewards | Yes | No | No | No |
| Live Foresight and No-flag | Yes | Yes | Yes | Yes |
| Special mine | No | Non-Perfect clear only | Never | Solo rule only in sandbox |
| H/U/A solo explosion | No story outcome | Yes | No solo payout | Solo rule only in sandbox |
| Terminal inspection | Yes | No | No | No |
| Automatic terminal return | No | Exploded or Perfect | Every terminal | After board into hypothetical post-scene |
| Back/Pause | Home/suspend; no pause | Canonical quiet pause | Canonical quiet pause | Archive Continue/Leave law |
| Save records | Exact run save | Exact run save | Exact run save | Forbidden |

### 6.3 Actual mine total

After a candidate's effective mine count and layout are frozen, every visible
mine total and signed estimate must use that exact actual count. Before that
fact exists, the field displays an em dash. It never guesses from base mines,
current inventory, pressure, or an unfinished Debug search.

The solo special mine is already one member of the actual mine set. It adds no
mine and consumes no separate quota.

## 7. Shared Variant C composition

### 7.1 Desktop rect

Inside the accepted desktop shell, Minesweeper owns exactly the shell-provided
`800 x 656` logical-pixel app body. It adds no AppWindowBase title bar, X,
dragging, resizing, parallel window, or internal clock.

The global 64-pixel Home/title/clock strip remains outside this component.

### 7.2 Challenge rect

Inside the accepted 1280-by-720 narrative host, the foreground board plane uses
the centered logical rect `(160, 32, 960, 656)`. The frozen authored stage
remains dimly visible around it. The plane has no desktop Home, title, clock,
date, friend, route, tier, or result banner.

Full Date Rehearsal uses the same rect and host-safe layering.

### 7.3 Internal bands

At 100% text with ordinary targets:

- the status register has a 92-pixel minimum height;
- the pinned action dock has a 72-pixel minimum height; and
- the worksheet viewport receives every remaining pixel.

With Large Targets:

- the status minimum is 108 pixels; and
- the dock minimum is 84 pixels.

At 125% or 150%, either functional band may grow to fit wrapped text and target
height. The worksheet viewport yields height. The order never changes and the
board never overlaps, clips, or pushes the dock offscreen.

### 7.4 Status register contents

Desktop register order is:

1. Beginner, Intermediate, Expert;
2. signed Rounds over denominator `2`;
3. signed Mine estimate;
4. Foresight percentage; and
5. No flag, `Intact` or `Lost`.

Challenge and Rehearsal remove difficulty and Rounds entirely, leaving Mine
estimate, Foresight, and No flag in the same relative order with honest
negative space. They do not insert a challenge title or story summary.

No field uses a meter, progress bar, pulsing state, tooltip-only label, or colour
alone.

### 7.5 Pinned action dock contents

The left cluster is always:

    Reveal | Flag | Drag

Desktop right cluster is:

    New Board | Assignments | Rules

Canonical solo and pair right cluster is:

    Rules | Pause

`Pause` is the pointer/touch route to the narrative host's accepted quiet pause
and is semantically identical to Back at challenge root.

Full Date Rehearsal right cluster is:

    Rules | Leave

`Leave` invokes the accepted Continue/Leave Rehearsal confirmation. It is not a
save, forfeit, or canonical progress warning.

Buttons wrap within their cluster at 125% and 150% without changing semantic
order. There is no horizontal control scrolling.

### 7.6 Selected mode

Exactly one mode is selected. Selected, focused, disabled, hovered, and pressed
states are visually and semantically distinct. Selection uses a persistent
non-colour underline/tab edge plus text; focus uses a second outer boundary.

Changing mode never commands a cell, changes action count, or plays a board
result sound.

## 8. Worksheet viewport and cell projection

### 8.1 Fixed cell geometry

Each cell is exactly `48 x 48` logical pixels in ordinary target mode and
`64 x 64` in Large Targets. Grid gaps and borders are internal to that rect.

100%, 125%, and 150% text never change cell dimensions. One number, flag mark,
mine mark, or focus outline must fit without clipping at all three presets.

### 8.2 Two-axis scroll

The worksheet viewport owns standard horizontal and vertical scrollbars. A
focused cell is scrolled completely into view with at least one cell-border
inset. Pointer wheel, trackpad, scrollbar drag, Drag mode, keyboard focus, and
controller focus all move the same viewport without changing board state.

Along either axis where the full worksheet fits, the worksheet is centered in
the available viewport. Along an overflowing axis, its logical origin remains
at the start edge and the viewport scrolls. Fresh entry scrolls only as needed
to reveal the initial focus cell; Debug entry therefore reveals its forced cell
without pretending that it occupies a fixed visual position.

There is no zoom, minimap, board scaling, recenter animation, edge wrap, or
automatic camera motion unrelated to focus visibility.

### 8.3 No visible coordinates

The visual board has no row or column headers. Assistive cell names provide
localized one-based row and column coordinates because spatial identity cannot
depend on sight.

### 8.4 Closed visible cell states

The production view may render only:

- covered;
- covered and flagged;
- revealed blank;
- revealed number `1` through `8`;
- disabled/inert covered or revealed state during a bounded owner transition;
- the one Reveal-eligible Debug forced cell after preparation;
- terminal revealed mine;
- terminal exploded mine;
- terminal correct flag;
- terminal incorrect flag; and
- solo post-clear marked mine.

Hidden mine, H/U/A assignment, special identity, safe-cell proof, solver fact,
extra-mine provenance, and route outcome are absent from the preterminal visual
and accessibility trees.

### 8.5 Cell marks

Flags use a shape and outline, not colour alone. Terminal explosion uses a
distinct broken or radiating mark. Incorrect flags use a crossed flag shape.
The post-clear marked mine uses a stable double-frame or tab mark distinct from
focus. Number colour may supplement the visible numeral but never replaces it.

## 9. Board commands and action accounting

### 9.1 Reveal

Reveal on a legal covered unflagged cell submits one revisioned Reveal command.
It counts one action only after commit, regardless of flood-revealed cell count.

On a Default/Lucky unpaid shell it also materializes the exact board, preserves
that shell's flags and accepted action history, and, for desktop, commits the
one paid-session cost. A focused flagged cell is not Reveal-eligible.

### 9.2 Flag and Unflag

Flag on a legal covered unflagged cell submits one Flag command. Unflag on a
legal flagged cell submits one Unflag command. Each successful command counts
one action.

The first successful Flag makes No-flag false for that layout or unpaid shell
before the new revision publishes. Unflag never reverses it. A pre-Reveal Flag
is a canonical lightweight shell command: it counts one action and persists,
but creates no mines, candidate, RNG draw, payment, round decrement, or New
Board eligibility.

Flags are not limited by mine count. The signed estimate may therefore become
negative.

### 9.3 Chord through Reveal

Reveal on an already revealed positive number submits Chord only when the
number of adjacent flags exactly equals the visible number.

One successful Chord counts one action no matter how many neighboring cells it
reveals. An ineligible Chord attempt is rejected and counts zero. If the chord
explodes, the same one command is the terminal action.

### 9.4 Zero-count interactions

The following count zero:

- covered-cell focus and selection;
- arrows, D-pad, sticks, Tab, wheel, trackpad, and scrollbars;
- Drag panning;
- mode change;
- opening or closing Rules, Assignments, pause, or leave confirmation;
- New Board and difficulty selection;
- stale, duplicate, illegal, blocked, cancelled-before-admission, or failed
  commands; and
- terminal Continue or marked-mine outcome selection.

### 9.5 Command identity

Every command binds host, the applicable unpaid-shell/session/attempt identity,
layout/board identity when one exists, expected revision, semantic action, cell
when applicable, and command ID.

An exact duplicate replays its receipt. A changed command under the same ID is a
conflict. A stale different command rejects before action count, cost, visual
announcement, or sound.

## 10. Pointer, touch, keyboard, controller, and assistive input

### 10.1 Primary activation

In Reveal mode, primary click, short tap, Enter on a focused cell, controller
Confirm, and assistive primary activation submit Reveal or eligible Chord.

In Flag mode, those same activations submit Flag or Unflag.

In Drag mode, a primary pointer/touch gesture that crosses movement slop pans.
A stationary release submits no cell command. Keyboard/controller Confirm in
Drag mode is inert; keyboard/controller navigation remains available.

### 10.2 Direct Flag

Right-click submits Flag or Unflag on the targeted covered cell in Reveal,
Flag, or Drag mode. It never opens a context menu and never changes mode.

A touch or pen press held for at least 500 milliseconds with no more than 8
logical pixels of movement submits the same direct command. Crossing the slop
cancels long-press Flag and allows Drag panning where applicable. The release
after a committed long press cannot also activate the cell.

### 10.3 Keyboard

- Arrow keys move one cell without wrapping.
- Enter applies the selected mode to the focused cell.
- `F` follows the exact mode toggle law.
- Desktop `Space` requests New Board only when the board grid owns input and no
  higher owner or focused toolbar control consumes Space.
- Tab exits the composite grid to the next visible dock control; Shift-Tab
  returns through the previous logical control.
- Home, End, Page Up, and Page Down may scroll or move by registered accessible
  conventions but never command a cell accidentally.

### 10.4 Controller

- D-pad and left stick move the roving cell focus without wrapping.
- Confirm applies the current mode.
- the configured secondary face action mirrors `F`;
- right stick pans the worksheet without commanding cells; and
- New Board is invoked through its visible dock control, not Back or an
  undisclosed controller-only chord.

The registered Focus Next/Previous actions, mapped to the platform's ordinary
controller focus navigation, move between the composite grid, mode cluster, and
contextual dock in their section 21.4 order. Directional input then follows
explicit neighbors within the dock. Returning to the grid restores the last
legal cell and scrolls it fully into view. This is also how a controller selects
Drag, Rules, Assignments, New Board, Pause, Leave, or terminal Continue; no dock
action depends on pointer hover or a keyboard-only Tab key.

These are registered semantic input actions whose physical labels come from the
current Settings binding. Controller does not gain an undisclosed direct-Flag
shortcut: selecting Flag through the secondary action and pressing Confirm is
its complete reachable Flag path. This remains semantically equivalent without
pretending that a controller has a right mouse button or touch long press.

Controller repeat moves focus but cannot repeat a cell command until the
Confirm action is released and pressed again.

### 10.5 Composite accessible grid

The board is one grid with one roving Tab stop. It exposes exact row and column
counts. Each cell exposes localized one-based coordinates and only its visible
state.

Where the platform supports custom actions, covered cells expose named Reveal
and Flag/Unflag actions that submit the same command ports. The selected mode
remains primary activation. Custom actions never reveal hidden state.

### 10.6 One event, one command

Pointer, touch, keyboard, controller, and assistive events normalize before
domain admission. Held keys, double-click, pointer-up after long press,
simultaneous devices, and controller repeat cannot submit two actions or make a
newly opened terminal surface consume the triggering event.

## 11. Quiet generation and publication

### 11.1 Default and Lucky

Before first Reveal, the view may show a covered worksheet shell. Mine locations
do not exist canonically. The accepted first Reveal materializes and commits the
exact layout before presentation.

Pre-Reveal Flag/Unflag commands mutate only the shell marks, command history,
action count, and No-flag latch. They do not constrain mine placement, consume
RNG, or create a generator candidate. First Reveal preserves those marks while
materializing safely around its chosen unflagged cell.

### 11.2 Debug

Debug preparation may run in bounded deterministic slices under the accepted
law. While no prepared candidate exists:

- the worksheet and actions are inert;
- no progress, timer, spinner, candidate count, or preparation copy appears;
- no playable cell or hidden mine enters the accessibility tree; and
- if an exact old layout is being replaced, that layout may remain visible but
  inert until the replacement candidate is proven.

When preparation commits, the exact forced cell receives the sole
Reveal-eligible mark and initial cell focus. The UI does not say `Debug`,
`forced`, `safe`, `solvable`, or `no guess` on the board.

### 11.3 Atomic publication

No partially generated grid is visible or focusable. Candidate/layout
publication swaps atomically after the owner commits a stable revision.

Presentation failure after canonical commit reconstructs that committed state;
it never generates another candidate or reverses a cost.

### 11.4 Focus loss and hidden hosts

An admitted bounded generator slice reaches its stable frontier, then parks
under the accepted quiet-suspension law. A hidden desktop app or unfocused game
does not continue unbounded search or nonessential redraw.

## 12. Desktop paid-session lifecycle

### 12.1 Normative phases

The desktop coordinator extends the parent lifecycle with these canonical
progress phases:

    UNPAID_SHELL
      Default/Lucky Flag/Unflag -> UNPAID_SHELL
      different tier -> fresh UNPAID_SHELL
      Default/Lucky paid first Reveal -> PAID_ACTIVE
      Debug -> UNPAID_PREPARING -> UNPAID_PREPARED
            -> paid first Reveal -> PAID_ACTIVE

    any stable preterminal paid envelope
      difficulty change -> REPLACEMENT_ADMITTED
    PAID_ACTIVE
      New Board -> REPLACEMENT_ADMITTED
         Default/Lucky -> PAID_UNSTARTED
         Debug -> PAID_PREPARING -> PAID_PREPARED

    PAID_UNSTARTED
      Flag/Unflag -> PAID_UNSTARTED
      free first Reveal -> PAID_ACTIVE
    PAID_PREPARED -> free forced Reveal -> PAID_ACTIVE

    any touched paid layout -> SETTLING -> TERMINAL_INSPECTION
    TERMINAL_INSPECTION -> New Board -> UNPAID_SHELL

`PAID_UNSTARTED`, `PAID_PREPARING`, and `PAID_PREPARED` remain inside the same
paid session and retain its one cost receipt and app-round ordinal.

`any stable preterminal paid envelope` includes `PAID_ACTIVE`,
`PAID_UNSTARTED`, and `PAID_PREPARED`. A paid preparation in flight first
reaches or rolls back to its stable frontier. Difficulty change is legal from
that set; New Board itself remains legal only after an accepted Reveal.

Host visibility is an orthogonal `visible | suspended` projection fact for
every stable progress phase, including unpaid shell/preparation, paid unstarted/
preparation, active, and terminal inspection. Home or an app switch asks an
in-flight admitted operation to reach its registered stable frontier and then
suspends that phase; reopening republishes the same phase. Visibility never
creates a new canonical candidate, session, result, payment, or action.

### 12.2 Paid first Reveal

Only the transition from an unpaid candidate/shell to the first paid active
layout validates and commits one Motivation cost and one signed-round
decrement. Any accepted pre-Reveal flags, action receipts, and lost No-flag fact
carry into that first layout; they neither pay nor decrement on their own.

The transaction retains the parent's exact order and idempotency. Flag, Unflag,
New Board, difficulty, mode, focus, and panning cannot start a session. Chord is
impossible before an open numbered cell exists.

### 12.3 New Board eligibility

Before terminal settlement, New Board is admitted only when the current layout
has an accepted Reveal. If not, the visible control is disabled and `Space`
returns the same no-op result. Existing unpaid-shell flags and receipts remain
unchanged. The no-op creates no command receipt because no canonical command
was admitted.

Choosing a different desktop difficulty has two exact paths. Before payment, it
atomically replaces the unpaid shell with a fresh shell of the requested
geometry, clearing shell flags, history, action count, and No-flag back to
intact without allocating RNG/candidate/layout/cost/round facts. During a paid
session, it uses section 12.4 even when the current paid envelope has no Reveal.
Reselecting the same tier is a no-op in either path.

### 12.4 Replacement transaction

One replacement request binds paid-session ID, current generation-envelope
identity and revision, current layout identity when materialized, source
(`new_board` or `difficulty_change`), requested tier, current run/branch/day/
app-round identity, and command ID.

The coordinator:

1. verifies the paid session is preterminal and no conflicting operation owns
   it;
2. freezes the then-current pressure, penalty, committed capability, registry,
   generator, verifier, and RNG inputs for a new BoardSpec;
3. allocates the next layout ordinal and isolated board identity only after the
   request is admitted;
4. prepares or records the new candidate under the accepted generation law;
5. atomically replaces the old generation envelope with the new unstarted or
   prepared generation envelope;
6. preserves the session cost, signed-round decrement, and app-round ordinal;
7. records one replacement receipt and stable checkpoint; and
8. publishes the new covered/prepared worksheet in Reveal mode.

The old generation envelope remains canonical until step 5. A failure before
that step leaves it byte-equivalent and, when it contains a materialized layout,
playable after recovery. A failure after a committed replacement reconstructs
the new envelope and never revives the discarded envelope as an alternate
future.

### 12.5 What replacement resets

A committed replacement resets only generation-envelope facts:

- board/layout identity and nonce;
- reveals and flags;
- action count;
- No-flag to intact;
- materialized 3BV and visible Foresight;
- terminal/explosion facts;
- first cell; and
- hidden layout auxiliaries, including H/U/A and special-mine data where the
  host permits them.

It preserves session/day/run/branch identity, cost receipt, signed-round
decrement, app-round ordinal, and the fact that this paid session has not yet
completed.

### 12.6 Prospective purchases and state changes

Shop purchases and other committed gameplay changes never mutate the current
candidate/layout. The next admitted replacement re-reads them because it is a
new candidate. An already admitted replacement freezes its own inputs; a later
purchase applies to a later candidate or session.

This is prospective candidate behavior, not retroactive board mutation.

### 12.7 Completion and forfeit count once

Only the terminal layout may settle the paid session by board result/completion.
Completion increments the accepted desktop-completion count and emits its
result/rewards exactly once. Discarded replacement layouts emit nothing.

A causal-day departure or condition-driven forfeit acts once on the paid
session under the parent law and may close it without a terminal board result,
completion, or reward. It does not forfeit each discarded layout or restore any
cost.

## 13. Visible metrics and Perfect classification

### 13.1 Signed mine estimate

The public value is:

    adopted_actual_mine_count - placed_flag_count

It updates only after a committed Flag, Unflag, materialization, preparation,
replacement, terminal restoration, or Load. It may be negative.

Its visible label is `Mine estimate`. Its accessible description states the
same arithmetic fact and never calls the value actual remaining mines.

### 13.2 Action count

Action count is generation-envelope-local, canonical, and exactly derivable
from the ordered accepted command history. It may begin before materialization
through Flag/Unflag, then carries into the adopted layout. Snapshot validation
rejects disagreement between the aggregate and history.

### 13.3 3BV and live Foresight

3BV freezes after the exact layout is materialized or prepared and uses the
accepted versioned metric owner. Before valid 3BV or before the first counted
action, Foresight displays an em dash.

Afterward:

    display_percent = floor(100 * three_bv / action_count)

The UI displays only the integer percentage. It adds no `Qualifying`, `Perfect`,
threshold, raw 3BV, action-count denominator, or formula copy.

Qualification uses exact integer comparison equivalent to:

    three_bv >= action_count

There is no floating-point boundary error.

### 13.4 No-flag display

The visible value is exactly `Intact` or `Lost`. It changes only after the first
accepted Flag or a genuine new layout. It never flickers optimistically during
an in-flight command.

### 13.5 Perfect reasons

At a valid clear, the metrics owner derives a sorted unique reason set:

- include `efficiency_gte_100` when exact Foresight qualifies;
- include `no_flag` when No-flag is intact; and
- classify Perfect when the set is nonempty, otherwise Solved.

The public board continues to show the factual Foresight percentage and No-flag
state. It does not add a preterminal Perfect badge or forecast.

## 14. Desktop Assignments and rewards

### 14.1 Closed Assignment catalog

Exactly nine run-scoped desktop Assignments exist, each worth one Minesweeper
Coin under the retained reward law:

1. Complete Beginner;
2. Complete Intermediate;
3. Complete Expert;
4. Finish with No flag;
5. Finish with Foresight;
6. Perfect — Beginner;
7. Perfect — Intermediate;
8. Perfect — Expert; and
9. Complete all three tiers.

Stable internal IDs remain registry-owned. UI prose above is localization
intent, not permission to hard-code strings in scene scripts.

### 14.2 Sheet projection

Assignments is available only in the desktop host. It is a focus-trapped local
sheet and lists all nine in fixed registry order with:

- localized requirement; and
- `Claimed` or `Unclaimed`.

There is no unseen entry, progress fraction, percentage, historical timestamp,
route clue, manual Claim, coin animation requirement, or reset hint.

### 14.3 Claim boundary

After one desktop terminal result is validated, the reward owner derives every
newly satisfied Assignment and commits their receipts and coins atomically with
the terminal session transaction. Repeated result delivery cannot reclaim.

Replacement, challenge, Rehearsal, terminal inspection, and opening the sheet
never claim.

### 14.4 Rules sheet

Rules is an optional, focus-trapped local sheet. It may state only ordinary
interaction facts:

- Reveal opens a covered cell;
- Flag marks or unmarks a covered cell;
- Reveal on an open number may chord when adjacent flags match; and
- Drag moves the worksheet without acting on cells.

It does not explain Motivation cost, round capacity, hidden extras, Lucky,
Debug, Foresight threshold, Perfect, special mine, H/U/A, rewards, relationship
outcomes, or route consequences.

Back closes Rules/Assignments and restores the exact source control, mode,
focused cell, and scroll. The sheets are never saved.

## 15. Desktop terminal inspection

### 15.1 Terminal truth

The terminal transaction finishes before inspection becomes interactive. The
grid is read-only and projects the exact settled snapshot.

On explosion it shows every mine, the exploded cell, every correct flag, and
every incorrect flag with non-colour marks. On clear it shows the completed
grid.

### 15.2 Terminal facts

The surface shows only:

- `Cleared` or `Exploded`;
- frozen Foresight percentage;
- frozen No-flag state;
- exact current Money;
- exact current Minesweeper Coins; and
- New Board, Assignments, Rules, and global Home.

It shows no grade, H/U/A class, hidden effect, reward formula, route change,
invitation preview, relationship meaning, or technical receipt.

### 15.3 Focus and lifecycle

New Board receives initial terminal focus. Home may suspend the read-only
inspection under same-day cache law. Explicit save may preserve the exact
terminal inspection snapshot needed for continuation.

New Board clears inspection and returns to `UNPAID_SHELL` with the last selected
difficulty and no flags. It allocates no new board. If capacity or Motivation later forbids a
paid first Reveal, the worksheet remains truthful and inert without a cost
tutorial.

## 16. Solo challenge terminal law

### 16.1 Explosion

Revealing any mine before clear, including the hidden special mine, commits the
ordinary fixed H/U/A explosion classification under retained August law. After
the bounded terminal visual/audio atom and durable consequence receipt, the
pressure layer withdraws automatically. There is no Continue or special choice.

### 16.2 Perfect clear

If `perfect_reasons` is nonempty, the board commits:

- `board_result = perfect`;
- `relationship_outcome = foresight`; and
- the retained affection, attitude, promotion, mastery, and route consequences.

The result is atomic and automatic. The special mine remains unmarked and
unavailable. After the terminal clear atom, the board returns to the narrative
host without a button or second Accept.

### 16.3 Non-Perfect clear

A clear with no Perfect reason commits board truth as `solved` and enters:

    CLEARED_AWAITING_NONPERFECT_CHOICE

No relationship outcome has committed yet.

Every ordinary cell command, mode change, Flag shortcut, and New Board is inert.
The special mine receives the one visible/semantic marked-mine state. The same
cell is activatable even if its pre-clear state was flagged.

Continue is visible and receives initial focus. Activating it commits Loved.
Activating the marked mine commits Dark. Neither action asks for confirmation,
names the outcome, or explains the consequence.

This phase has exactly two focus targets: Continue and the marked mine. Tab and
Shift-Tab, registered controller Focus Next/Previous, and explicit directional
neighbors move between them without entering an ordinary cell or mode control.
Enter, controller Confirm, pointer/touch primary activation, or assistive
primary activation on the marked mine submits the Dark terminal command
independent of the previously selected board mode. Continue submits Loved
through the same modalities. The clearing event is release-gated before either
target can accept input.

### 16.4 Mutual exclusion and idempotency

Continue and marked-mine activation bind the exact board, special cell,
post-clear revision, and one terminal command ID. The first valid command wins.
The other becomes stale. Duplicate delivery replays only the winning receipt.

A save in the choice phase restores the exact grid, special cell, flag state,
two-target graph, and unresolved outcome, then places initial focus on Continue.
It cannot restore both outcomes or reroll the special cell.

### 16.5 Special-mine selection

For Default/Lucky, special identity freezes atomically with first-Reveal
materialization. For Debug, it freezes with the certified adopted layout.

The accepted versioned special-mine recipe selects it from the adopted mine set
under the board's isolated RNG contract. This amendment constrains the output,
not the recipe's unexposed sampling implementation. The selected cell receives
the same independent H/U/A explosion assignment as an ordinary solo mine. No
friend, tier, relationship, affection, dark, day, route, or prior result may
weight it.

## 17. P-L and Rehearsal terminal law

### 17.1 Visible P-L

The pair board is ordinary observation-only Minesweeper at `18 x 18 / 36` base.
It has no special mine, H/U/A relationship choice, Angela relationship payout,
Continue, or result selector.

Perfect, Solved, or Exploded commits the retained pair result exactly once.
After its bounded terminal atom, the board automatically returns the validated
pair post-scene context.

### 17.2 Full Date Rehearsal

Rehearsal uses the same solo or pair board and the same legal terminal behavior
inside detached sandbox state. It may reveal legal hypothetical post-date
dialogue only through actual production play.

It emits no canonical cost, reward, Assignment, Contacts progression, mastery,
attempt, Gallery, relationship, evidence, route, save, or global RNG fact.

After the whole Full Date completes, Rehearse Again creates a fresh sandbox
attempt from the original reached seed. It is not a mid-board New Board.

### 17.3 Replay exclusion

Direct exact Scene replay never recreates a board, accepts board input, or
recomputes a result. Only Full Date Rehearsal owns the sandbox production board.

## 18. Home, Back, pause, sheets, and focus

### 18.1 Desktop Home and Back

At desktop board root, Home and Back request the same safe app suspension and
launcher return. There is no desktop pause plate, pause icon, paused badge,
forfeit warning, or board-loss confirmation.

Rules or Assignments consumes Back first. A trusted modal, recovery owner, or
admitted bounded command follows global precedence and makes Home inert until a
stable result; Home is never queued for surprise execution.

### 18.2 Canonical pause

Canonical challenge Back or visible Pause opens the accepted quiet pause with
Continue, Backup, Settings, and Save & Return to Title. It never resets,
abandons, changes, or reveals the board.

### 18.3 Rehearsal leave

Full Date Back or visible Leave invokes the archive's exact Continue/Leave
Rehearsal confirmation. Save, Load, Backup, and canonical forfeit copy are
absent. Continue receives initial focus and returns to the exact board focus.

### 18.4 Focus entry

Focus priority when a board becomes interactive is:

1. prepared Debug forced cell;
2. restored last canonical command cell when legal and visible;
3. the registered challenge first playable cell; or
4. row 1, column 1.

No cell is activated during transfer. Held input must release first.

### 18.5 Same-day desktop return

Home/app switching may cache the last meaningful cell and scroll offsets for the
same logical day. Reopening reconstructs the exact board, selects Reveal mode,
validates the cached cell, and restores it when legal. Invalid cache falls back
through section 18.4.

Load, New Run, logical-day change, Logout, terminal New Board, and technical
reconstruction clear the view cache. Cache is never serialized.

## 19. Exact persistence and recovery

### 19.1 Shared pre-materialization fields

When no mine layout exists, every saveable canonical host serializes the
pre-materialization envelope identity, host, selected tier or fixed profile,
dimensions, revision, flags, ordered Flag/Unflag commands and receipts, action
count, and No-flag latch. Its separately owned context may be an unpaid desktop
shell, a paid-unstarted desktop envelope retaining the existing session cost/
round receipt, or a canonical attempt retaining its pre-entry frozen BoardSpec/
RNG recipe.

### 19.2 Canonical desktop fields

In addition to section 19.1 and the retained parent snapshot, desktop
Minesweeper must serialize as applicable:

- paid-session ID, phase, revision, app-round ordinal, and one cost receipt;
- current layout ordinal and replacement history/receipts;
- current BoardSpec and frozen candidate inputs;
- current layout identity, preparation/materialization proof, mines, auxiliary
  hidden data, reveals, flags, and first-Reveal fact;
- ordered accepted action history and aggregate action count;
- 3BV version/value, No-flag, Perfect reason set, and terminal result;
- replacement transaction stage when durably admitted;
- pending settlement/reward/Assignment/consequence outbox stages;
- terminal inspection snapshot and dismissal state; and
- every idempotency and continuation-generation fact required by accepted
  recovery law.

### 19.3 Canonical challenge fields

Canonical solo/pair snapshots retain the accepted run/branch/attempt overlay,
BoardSpec, layout, hidden H/U/A, exact special identity where applicable,
reveals, flags, action history, metrics, phase, result, terminal outcome receipt,
and post-scene handoff stage.

The new solo choice phase is saved only for non-Perfect Solved boards.

### 19.4 Presentation-only fields

Do not save:

- selected Reveal/Flag/Drag mode;
- hover, pressed, pointer capture, long-press timer, drag delta, or held input;
- focused Node, physical NodePath, scrollbar tween, live ScrollContainer, or
  animation frame;
- open Rules/Assignments/pause/leave sheet or its focus trap;
- terminal card animation, sound cursor, live TTS, or announcement state; or
- the disposable HTML prototype state.

### 19.5 Restore order

Restore validates the whole selected snapshot before live mutation, restores
canonical owner state, completes or rolls back any admitted transaction under
its journal, and then builds presentation.

Presentation starts in Reveal mode. It derives targets, text, locale, theme,
contrast, and motion from current profile preferences. It never rereads current
inventory or pressure to alter a frozen candidate, regenerates a layout,
charges a paid first Reveal, resets No-flag, recomputes a terminal result, or
duplicates a reward/outcome.

Restoring a pre-materialization envelope restores its visible flags and
truthful command history without generating mines. Its later first Reveal
carries those facts into the adopted layout. Only an unpaid desktop shell reads
then-current gameplay inputs at that materialization boundary. A paid-unstarted
desktop envelope uses the inputs frozen by its replacement, while a canonical
solo/pair envelope uses only the BoardSpec, capabilities, RNG recipe, and
attempt identity frozen at challenge entry. Neither Load nor pre-Reveal flags
rerolls or replaces those frozen facts.

### 19.6 Rehearsal exclusion

Full Date board state is transient sandbox state and never enters Autosave,
Quick, numbered slots, profile attempts, or a recovery journal claiming
canonical continuation. Process loss discards it under the archive law except
an already-admitted visited-line merge.

### 19.7 Target-schema vocabulary

Because no public release contains the superseded design, the target schema
uses only `efficiency_gte_100` and the new non-Perfect choice phase. Development
fixtures and provisional adapters are updated or rejected during later
reconciliation. No runtime may silently treat `efficiency_gt_100` as the new
threshold, preserve Perfect-then-Dark, or accept both vocabularies as alternate
authority.

## 20. Command and transaction ordering

### 20.1 Ordinary board command

One Reveal, Flag, Unflag, or Chord command:

1. validates host capability, unpaid-shell or board identity, expected revision,
   phase, target, mode-independent action legality, and higher input owner;
2. computes one deterministic next board state and terminal fact if any;
3. updates action history, action count, No-flag, and visible metrics in that
   candidate state;
4. writes transaction intent when the command crosses a durable boundary;
5. atomically commits revision and receipt;
6. runs terminal settlement if required;
7. publishes the committed snapshot; and
8. presents and announces only the resulting visible state.

No signal consumer may apply a second reward or story effect directly from a
cell click.

### 20.2 Replacement

Replacement follows section 12.4 and is mutually exclusive with cell commands,
terminal settlement, save/restore mutation, and another replacement. Input
arriving while it owns the board is rejected, not queued.

### 20.3 Terminal result

Terminal truth, desktop rewards/Assignments/contact progression, solo
relationship outcome, pair observation, post-condition destination, and
notification outbox use their accepted typed owners and one recoverable causal
transaction. The board view never performs those mutations.

### 20.4 Non-Perfect solo outcome

Board clear truth commits before the choice, but relationship effects do not.
Continue or marked-mine activation later commits exactly one outcome and
resumes the same terminal transaction graph from its next missing stage.

### 20.5 Save at a bounded slice

Save, Home, app switch, Logout, and focus loss wait only for the admitted
bounded command/replacement/generator slice to reach its stable frontier. They
never wait for board completion. A request defined as ignored is never replayed
automatically later.

## 21. Localization, text size, targets, and accessibility

### 21.1 Localization

Every difficulty, status label, mode, sheet, Assignment, terminal fact,
accessible cell state, pause/leave action, and technical recovery string uses a
registered localization key.

Internal IDs, outcome enums, receipts, hidden assignments, special identity,
and formulas never become fallback copy. Missing essential localization is a
trusted content failure, not an English hard-code.

### 21.2 Text presets

100%, 125%, and 150% apply immediately without changing canonical board state,
mode, focus identity, or scroll target. Text wraps; controls grow vertically;
the worksheet viewport yields. Text never shrinks below the selected preset,
clips, overlaps, ellipsizes essential content, or creates horizontal text
scrolling.

### 21.3 Targets

Every mode, contextual action, sheet row/action, scrollbar control, terminal
Continue, and marked-mine cell meets 48-by-48 ordinary and 64-by-64 Large
Targets. Cell sizes themselves implement the same contract.

### 21.4 Reading order

Semantic reading order is:

1. board status register;
2. composite grid and current focused cell;
3. selected mode and remaining action dock; and
4. terminal action/status content when the board itself owns terminal focus.

When Rules, Assignments, canonical pause, Rehearsal leave confirmation, a
trusted confirmation, or technical recovery is active, that foreground owner
replaces this order as the sole active focus and accessibility subtree. The
status, grid, and dock may remain visually behind it but are inert and excluded
from interactive traversal and live announcements. Safe dismissal restores the
exact semantic source, selected mode, remembered cell, and scroll when still
legal; otherwise it uses the governing deterministic fallback.

The dim narrative scene and retired desktop app controls are absent while the
board owns focus.

### 21.5 Cell names

Accessible cell labels combine localized row/column with only visible state,
for example the semantic equivalent of:

    Row 4, column 7, covered
    Row 4, column 7, flagged
    Row 4, column 7, revealed 3
    Row 4, column 7, marked mine

`Marked mine` is used only in the legal post-clear state. Before then the same
cell is covered, flagged, revealed, or exploded like any other.

### 21.6 Dynamic announcements

One committed cell action announces only its concise visible result and any
essential terminal status. Flood reveal does not enumerate every cell. Mode
change announces the selected mode once. Replacement, Load, app return, resize,
locale change, and focus restoration do not replay prior announcements.

No live announcement says Preparing, first-Reveal cost, Perfect threshold,
special consequence, H/U/A, or hidden mine truth.

### 21.7 Colour, contrast, and motion

All covered/revealed/flagged/exploded/incorrect/marked/focused/selected states
have non-colour evidence. High Contrast and every colour-vision preset remap
functional tokens only.

Reduced Motion uses static board publication, mode selection, terminal marks,
and pressure-layer transition. Screen Shake never moves the grid under input.

## 22. Visual and audio direction

### 22.1 Maintained institutional worksheet

The surface resembles a maintained old university worksheet or aging campus
computer instrument: square paper planes, restrained ink, thin registration
lines, slight authored wear, and deliberate negative space.

Texture never obscures numbers, marks, status, focus, scrollbars, or target
boundaries. It is stable and nonsemantic across runs, saves, results, and
failures.

### 22.2 Quiet classification

The status register resembles a small filing header, not a score spectacle.
The action dock resembles pinned physical tools, not a floating mobile toolbar.
The board remains the visual center.

### 22.3 Sound

Reveal, Flag, Unflag, Chord, explosion, clear, mode change, and trusted failure
may use short dry semantic cues under Audio/SFX preferences. One command emits
at most one primary cue. Flood reveal never plays one sound per opened cell.

Every essential sound has simultaneous visual and semantic text/state evidence.
Muted audio changes no command timing or result.

### 22.4 Prohibited horror in the tool

There is no fake corruption, wrong mine count, phantom flag, shuffled board,
false save, fake crash, changing cell identity, ghost result, impossible timer,
or technical error presented as character action. Horror comes from context and
the honest special-mine boundary, not a lying simulator.

## 23. Failure and trusted recovery

### 23.1 First materialization failure

If an unpaid first Reveal cannot validate, generate, certify, persist, or
commit, no cost, round, action, layout, reveal, sound, or result occurs. The
prior shell/candidate remains exact and a trusted recovery owner presents the
truthful retry/return boundary.

### 23.2 Replacement failure

Before replacement commit, the old generation envelope and paid session remain
exact. After recovery, the old envelope becomes available again unless the
transaction journal proves the new envelope already committed, in which case
only the new envelope reconstructs. A materialized old envelope is playable; an
unstarted/preparing/prepared old envelope resumes only its legal phase.

The UI never claims a new board exists while outcome is indeterminate.

### 23.3 Cell command failure

A failed or stale cell command leaves board revision, flags, reveals, action
count, No-flag, metrics, focus truth, reward, and sound unchanged. Retrying with
the same command ID may only replay an existing receipt or resume its registered
stage.

### 23.4 Terminal failure

If terminal board truth committed but a downstream effect is pending, the grid
remains locked and recovery resumes the exact missing stage. The audience
cannot play, replace, Continue, activate the marked mine twice, or leave through
an unsafe route.

### 23.5 View failure

If the production board view cannot prove active 48/64 target mode, input
parity, accessible grid, or exact snapshot compatibility, canonical challenge
entry fails closed as required by the narrative host. Desktop remains in the
safe app/shell state or trusted recovery; it never falls back to simulation
buttons.

### 23.6 Public error boundary

Public copy is concise, localized, technical, and nonfictional. It never
displays stack traces, paths, seeds, hashes, hidden formulas, internal IDs, or
story voice. Raw diagnostics remain internal.

## 24. Component and semantic-port ownership

### 24.1 Board registry

Owns immutable tier/challenge configurations, Assignment identities, semantic
labels, and compatible generator/metric versions. The view never hard-codes a
second catalog.

### 24.2 Board domain owner

Owns BoardSpec, candidate/layout state, mine layout, reveals, flags, action
history, 3BV, No-flag, Perfect reasons, terminal truth, revisions, and cell
command receipts. It knows no Control nodes.

### 24.3 Generator and verifier

Own deterministic materialization, hidden extras, forced cell, no-guess proof,
H/U/A, and special-mine selection recipes under accepted law. It never draws
UI, consumes costs, or applies relationships.

### 24.4 Desktop session coordinator

Owns paid-session identity, one cost receipt, signed-round ordinal, free
replacement, difficulty replacement, terminal settlement, completion count,
and desktop result transport. It does not draw cells or write save files.

### 24.5 Challenge coordinator

Owns canonical attempt reservation, solo/pair host capability, relationship or
pair consequence ordering, non-Perfect terminal choice, post-scene handoff, and
profile attempt overlays. It consumes board truth; it never fabricates it.

### 24.6 Rehearsal owner

Owns detached Full Date seed/session state and denied canonical capabilities.
It consumes the board component through sandbox ports and may merge only
validated visited lines.

### 24.7 Board view

Receives immutable projections and emits typed semantic commands. It owns
Variant C layout, cells, scroll, mode, sheets, terminal presentation, focus,
accessibility, and visual/audio feedback. It cannot mutate GameState, rewards,
relationships, inventory, saves, or routes directly.

### 24.8 Input adapter

Normalizes pointer, touch, keyboard, controller, and assistive actions into the
same semantic board commands and enforces one-event/one-command release gates.

### 24.9 SaveManager and host owners

SaveManager alone validates, journals, writes, and restores. Desktop shell,
narrative host, and archive host own their outer rects, layers, pause/leave,
route, and focus handoff. They never inspect hidden board state.

### 24.10 Capability handshake

Before an interactive board publishes, the view reports a validated capability
record containing:

- active host mode;
- cell target size `48` or `64`;
- grid row/column counts;
- pointer, touch, keyboard, controller, and assistive command support;
- two-axis scroll support;
- localization and text-preset readiness; and
- semantic first-focus identity.

A missing, unknown, or false mandatory capability blocks publication.

## 25. Exact supersession and retained law

### 25.1 Seven-Day design supersession

This amendment narrowly supersedes the following old clauses in
`docs/design/2026-08-07-seven-day-dialogic-flow-design.md`:

- the scope statement that this design cannot replace Perfect, Foresight, or
  No-flag, only for the exact threshold/reason change approved here;
- `efficiency_gt_100` as a Perfect reason, replaced by
  `efficiency_gte_100`;
- Foresight efficiency strictly greater than 100, replaced by exact greater
  than or equal to 100;
- the outcome table row allowing deliberate special mine after a Perfect clear;
- every clear entering `CLEARED_AWAITING_TERMINAL_CHOICE`;
- Perfect-then-Dark preserving Perfect board truth/mastery; and
- verification requirements that assert Perfect-then-Dark.

The new exact law is:

- Perfect solo clear -> automatic Perfect/Foresight terminal;
- non-Perfect solo clear -> Solved plus Continue/Loved or marked-mine/Dark;
- Perfect and Dark -> mutually exclusive; and
- pair board -> no special choice.

Every surrounding H/U/A, affection, attitude, promotion, attempt, branch,
mastery, and consequence rule remains controlling unless the exact old branch
depended on Perfect-then-Dark.

### 25.2 Desktop amendment supersession

This amendment extends the 2026-08-11 lifecycle by:

- replacing its wholly presentation-only Default/Lucky untouched shell with a
  lightweight saveable unpaid shell solely for truthful pre-Reveal
  Flag/Unflag marks, receipts, action count, and No-flag, while still owning no
  mines, RNG draw, generator candidate, cost, round decrement, or result;
- separating one paid desktop session from its sequential layout generations;
- permitting free preterminal replacement after one paid start;
- allowing paid-session tier changes through that replacement transaction;
- freezing current committed gameplay inputs for each new replacement
  candidate;
- adding replacement/paid-unstarted phases and receipts;
- adding exact action/3BV/No-flag/terminal-inspection snapshot facts; and
- retaining a read-only terminal inspection after the active session settles.

It does not alter initial paid first-Reveal cost, signed-round denominator and
floor, Supportz eligibility/caps, day departure/forfeit, deterministic generator
law, or exactly-once terminal consequence order.

### 25.3 Narrative, Gallery, Shell, Settings, Backup, and Shop

This amendment fills the narrative host's delegated board geometry and input
contract. It retains its stage freeze, challenge entry, pause, result handoff,
and post-scene laws.

It retains Gallery/Rehearsal's no-save/no-canonical-effect sandbox; Shell's
canvas, app body, Home, and layers; Settings' preferences; Backup's storage; and
Shop's transactions.

### 25.4 Scaffold and recovered-doc disposition

The following are not authority and must be replaced or reconciled later:

- simulator result buttons and direct result dictionaries;
- placeholder `9 x 9 / 18` challenge board;
- True Path and direct Dark Mine buttons;
- AppWindowBase X/title-bar composition for Minesweeper;
- global HUD Minesweeper rounds;
- scalar safety display;
- preparation/status tutorials;
- visible timer or coordinate proposals;
- lifetime active-board save lock and route rejection;
- old result tokens that collapse `perfect`, `no_flag`, and `foresight`; and
- recovered per-row layouts or Windows-like styling.

Historical files and commits remain evidence; they do not become runtime
fallbacks.

## 26. Reconciliation path before implementation

No implementation may begin from this document alone. A later explicitly
authorized reconciliation must:

1. register this accepted artifact in the machine authority pipeline once its
   exact written bytes are approved;
2. update `docs/design/README.md` and the resolver so approved
   `design_amendment` files under `docs/design` can be resolved rather than
   leaving this authority human-only;
3. create or amend approved requirement packets for board catalog, paid-session
   replacement, board commands/metrics, challenge terminal law, board UI/access,
   and verification, with explicit retained/replaced/superseded dispositions;
4. regenerate `prompt_docs/INDEX.md` through its owner rather than editing it by
   hand;
5. create one successor authority/reconciliation Bead and make it a prerequisite
   of every affected `dwm-p2r.9` and OYO execution path before either can apply
   the superseded session, presentation, or terminal law;
6. reconcile `dwm-p2r.9` as reusable board/session-domain owner without giving it
   player-facing composition, and reconcile `dwm-oyo.3` as production desktop
   Minesweeper consumer;
7. reconcile `dwm-oyo.4` for the new Perfect/Dark and solo/pair terminal law,
   `dwm-oyo.5` for exact attempt/Rehearsal persistence, and `dwm-oyo.7` for final
   release evidence;
8. amend or replace hash-bound plans rather than silently editing accepted plan
   bytes or their digest chain;
9. replace simulator and challenge result controls only after the production
   board coordinator/ports exist and an explicit runtime implementation issue is
   authorized;
10. update the target save schemas, command vocabularies, registries,
    migrations/dispositions, localization, input map, scenes, and tests through
    their designated owners;
11. preserve unrelated user-owned dirty changes, including Shop work; and
12. keep `implementation_authorized: false` until a separate reviewed plan and
    exact runtime permission exist.

The natural runtime split is:

- reusable board/generator/session contracts -> `dwm-p2r.9` successor scope;
- player-facing desktop board and shell integration -> `dwm-oyo.3`;
- relationship and visible solo/pair coordination -> `dwm-oyo.4`;
- profile attempt/Rehearsal isolation -> `dwm-oyo.5`; and
- integrated accessibility/recovery/release evidence -> `dwm-oyo.7`.

No existing issue is widened or mutated by writing this amendment.

## 27. Verification matrix

### 27.1 Catalog and host capability

Verify exact desktop `8x8/10`, `16x16/40`, `22x22/99` and challenge
`18x18/36` base records. Reject duplicate, missing, reordered, unknown, or
caller-overridden configurations.

Cross every host capability and assert only its legal difficulty, cost, New
Board, Assignment, special-mine, terminal, pause/leave, reward, and persistence
surface exists. Hidden/disabled forbidden controls must not remain as phantom
focus or assistive nodes.

### 27.2 Geometry and text

At desktop `800x656` and challenge `(160,32,960,656)`, cross:

- text `100 | 125 | 150`;
- targets `48 | 64`;
- Primary locale `en | zh_CN | zh_HK`;
- single and Dual Language where a surrounding narrative host is visible;
- Windowed and Borderless;
- both base palettes, High Contrast on/off, and all four colour presets; and
- Reduced Motion on/off.

Assert invariant Variant C order, fixed cell size, two-axis scroll, visible
focus, no overlap/clip/ellipsis/silent shrink/horizontal text scrolling, and
complete reachability. Theme and language cannot change grid identity.

### 27.3 Board state projection

Exhaust every visible cell state, number `1..8`, correct/incorrect flag,
explosion, Debug eligible cell, and marked mine across themes. Assert hidden
mine/H/U/A/special/capability data never enters ordinary visual or accessibility
output.

### 27.4 Input parity

For every legal action, compare pointer, touch, keyboard, controller, and
assistive command envelopes and resulting snapshots. Assert:

- primary mode behavior;
- direct right-click/long-press Flag without mode change;
- movement-slop cancellation and no pointer-up double action;
- Reveal-on-number Chord;
- F sequence from Reveal, Flag, and Drag;
- D-pad/stick navigation with no wrap;
- right-stick/Drag panning with zero action count;
- Tab entry/exit and focus visibility;
- Space scope and blocking-owner rejection; and
- one held/double/simultaneous event yields at most one command.

### 27.5 Metrics boundaries

Use exact layouts and action histories at ratios below, equal to, and above 100
percent. Assert display floor and exact classification separately.

Test large integer products without floating error. Test action count for Reveal
flood, Flag, Unflag, Chord, explosion, rejected Chord, stale command, duplicate,
navigation, mode, Drag, New Board, and terminal choice.

Test No-flag before Flag, after Flag, after Unflag, after Save/Load, after failed
Flag, after free replacement, and under every accessibility setting.

### 27.6 Paid first Reveal

Cross Default, Lucky, Debug, and Lucky+Debug at every desktop tier, corner/edge/
interior first cell, opportunity boundary, Motivation boundary, stale revision,
duplicate command, generator failure, persistence failure, and presentation
failure.

Assert one cost/round decrement/action/reveal/receipt on success and zero partial
effects on failure.

Also cross zero, one, and several pre-Reveal Flag/Unflag commands. Assert that
first Reveal preserves their visible marks, ordered receipts, action count, and
lost No-flag latch while adding exactly one Reveal action and no duplicate cost.

### 27.7 Free replacement

Assert:

- New Board before any accepted Reveal is a byte-equivalent no-op with no RNG or
  candidate work;
- flagging without Reveal does not make New Board eligible;
- one touched board may replace repeatedly without extra cost/decrement;
- before payment, a different-tier selection atomically creates a fresh unpaid
  shell and resets its flags/history/count/No-flag with zero RNG, generator,
  candidate, cost, round, or paid-session receipt;
- within a paid session, a different-tier selection uses the replacement
  transaction from every legal stable preterminal paid envelope; same-tier
  selection is a no-op;
- every committed replacement increments the generation ordinal once, resets
  only generation-envelope facts, and starts Reveal mode;
- latest committed pressure/penalty/Lucky/Debug inputs freeze for the new
  candidate;
- a later purchase does not mutate that candidate;
- replacement produces no completion, reward, Assignment, Contacts, mastery,
  consequence, or forfeit;
- duplicate/stale/concurrent replacement is idempotent or rejects; and
- failures before/after commit reconstruct exactly one old or new future.

### 27.8 Home, day departure, terminal, and next session

Verify Home/Back suspension at every paid/unpaid/preparing/prepared/active/
replacement/terminal phase with no desktop pause.

Verify causal-day forfeit acts once on the paid session after any replacement.
Verify terminal completion counts/rewards once, keeps final inspection exact,
and New Board returns to an unpaid shell without generating or charging.

### 27.9 Assignments and rewards

Test all nine fixed Assignments, each terminal qualifying combination, repeated
results, daily reward caps, Load before/after claim, replacement, challenge,
Rehearsal, and concurrent terminal retry. Assert at most one coin per Assignment
and no manual claim path.

Verify the sheet shows only requirement plus Claimed/Unclaimed in fixed order.

### 27.10 Solo special mine

Across generator kind, every mine position, flagged/unflagged special, H/U/A,
Foresight below/equal/above threshold, No-flag true/false, Save/Load, duplicate,
and stale choice, assert:

- special identity is one fixed adopted mine and affects clues normally;
- it is indistinguishable before legal choice;
- pre-clear reveal explodes ordinarily;
- Perfect auto-commits Foresight and never marks/offers the mine;
- non-Perfect clear alone exposes one marked mine plus Continue;
- Continue has initial focus;
- marked mine remains activatable if flagged;
- exactly one Loved or Dark outcome commits; and
- no Perfect-then-Dark or dual payout exists.

### 27.11 P-L and Rehearsal

Cross Perfect/Solved/Exploded P-L results and assert automatic return, no special
mine, no solo effect, exact pair receipt, and no result button.

Cross Full Date solo/pair boards and assert production rules with zero canonical
cost/reward/Assignment/attempt/mastery/relationship/save output. Rehearse Again
must occur only after date completion and create one fresh sandbox board.

### 27.12 Persistence and recovery

Save/restore desktop from every phase, including:

- unpaid shell with zero and multiple pre-Reveal flags, including after Unflag;
- unpaid Debug preparation slices;
- unpaid prepared;
- paid active visible/suspended;
- replacement intent before/after commit;
- paid unstarted/preparing/prepared;
- mid-command stable frontier;
- exploded/cleared settlement stages;
- terminal inspection; and
- day-forfeit/recovery boundary.

Save/restore canonical solo and pair after entry but before first Reveal with
zero, one, and several Flag/Unflag commands. Assert frozen attempt BoardSpec,
capabilities, RNG recipe, and identity remain exact while shell marks, receipts,
action count, and No-flag restore; the later first Reveal cannot reroll them.

Also restore canonical solo from active, exploded, Perfect terminal,
non-Perfect choice, outcome commit, and post-scene handoff; pair from every
terminal result.

Assert exact layout, flags, reveals, action history/count, No-flag, 3BV, special,
cost, receipts, outbox, and result. Assert mode/sheets/hover/drag/announcement do
not serialize and restore begins Reveal without duplicate sound or live output.

### 27.13 Failure and trust

Inject failure at every validation, generation slice, preparation, journal,
commit, publication, replacement, metric, reward, outcome, checkpoint, restore,
and route stage. Assert one truthful recovery owner, no partial effects, no fake
horror, no raw diagnostics, and exact prior or committed winner.

Static scans must find no production simulation result buttons, True Path,
direct Dark Mine button, timer, visible coordinates, `Preparing board`, first-
Reveal cost copy, smile-face reset, player-facing hidden formula, or second save
owner.

### 27.14 Ownership guards

Static and integration tests prove:

- view scripts do not mutate GameState, rewards, relationship, Shop, save files,
  or routes directly;
- board domain accepts no Node, Resource, Control, physical path, or rendered
  string;
- one registry owns configurations/Assignments;
- one board owner owns state/revision/result;
- one desktop session coordinator owns cost/replacement/completion;
- one challenge coordinator owns relationship/pair handoff;
- one SaveManager owns storage/restore;
- Rehearsal capability denies every canonical output; and
- release evidence uses semantic state, rect, focus, and accessibility
  assertions rather than screenshots as the sole oracle.

### 27.15 Future verification commands

The later authorized plan must bind its exact test files before execution and
run that closed list through the repository-owned isolated Godot runner under a
unique suite ID and log name. It must also run documentation validation,
project configuration validation, localization validation, static ownership
scans, Beads lint/dependency checks, and `git diff --check` against one
identified subject. This document intentionally does not invent future test
paths or authorize execution.

## 28. Acceptance and next work

This written artifact may move from proposed to accepted only after:

- self-review finds no placeholder, unresolved architecture, internal
  contradiction, authority overreach, or accidental implementation permission;
- independent review confirms the paid-session replacement law does not double
  charge, reroll a canonical attempt, or weaken save/recovery truth;
- Variant C, input parity, metrics, Perfect/Dark, assignments, terminal,
  persistence, accessibility, and failure rules are executable and mutually
  consistent;
- exact supersession removes every Perfect-then-Dark and strict-greater-than
  residue inside the scoped target authority; and
- the user approves the exact written artifact.

After written approval, the next permitted work is authority/requirement/plan/
Beads reconciliation when explicitly requested. No production GDScript, scene,
schema, test, asset, migration, or runtime mutation is authorized by this
document.
