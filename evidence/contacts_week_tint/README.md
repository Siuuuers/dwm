# Contacts run-presentation evidence

Contacts now receives the installed run palette and day from Desktop. Its room
materials age with the shared WeekTint rules, using the existing sixteen Settings
palette/contrast/colour-preset tuples. Copy, identities, selection, focus and state
marks remain fixed. High Contrast has zero week amplitude; CVD room changes affect
lightness only. The mapping is in
[contacts-presentation-tuples.md](../../docs/design/current-ui/contacts-presentation-tuples.md).

The eleven former component material literals remain exact in Day 1 Standard.
Full-app pixel identity is not claimed: the installed Midnight palette was
previously absent, and this increment corrects the expanded transcript-button
focus ring from Gold on paper (1.55:1) to paper Ink. Disabled reply/retry captions
also use authored Bone instead of engine fallback. The hidden top-bar focus keeps
Gold on its dark surface. These are presentation corrections, not reply-rule changes.

Live colour changes repaint existing controls without correspondence queries or
ordinary reply commands. Friend selection, text, timestamps, node identities,
scroll, focus, pending command and draw receipt, busy state, failure feedback and
Retry survive. Desktop keeps its displayed unread fact on colour-only changes;
normal owner events still refresh it. Day changes evict the old view and install
the next day's context. Invalid or mismatched supplied contexts are rejected before
replacing the live presentation. No save schema or persistence owner changed.

The reviewed six-suite run passes **26/26 tests and 7,481 assertions** in **6.595 s**:
`contacts-presentation-reviewed-20260913.log`. It covers all **16 tuples × 7 days**
for material, text, state, identity and focus contrast; exact Day 1 component
literals; installed palette versus next-run preference; real Desktop day eviction;
live node/scroll/focus retention; and pending failure plus awaited acknowledgment.
The standalone component and desktop-shell suites also pass
(`contacts-component-20260913.log`, `contacts-desktop-shell-20260913.log`).

Both current public inventories were regenerated after the final source/test edit.
The live byte-reproduction and documentation suites pass **14/14 tests, 410
assertions** (`contacts-inventory-and-docs-final-20260913.log`). Historical evidence
gates remain untouched; the parent UI epic still requires its final reseal.

Six inspected native Windows/OpenGL3 captures pass **187 checks**
(`contacts-week-tint-native-reviewed-20260913.log`, `measurements.json`). They mount
real Contacts controls at 1280 × 720 logical / 640 × 360 capture, English at 100%,
with short synthetic correspondence and a memory-only owner. One row portrait is
replaced with a known fixture colour: its exact `e34db1` pixel survives every
appearance change. Focus uses an exact Ink pixel outside the button; clear room
interiors allow at most one RGB8 level of rounding for computed tint. Day 1,
High Contrast, focus and the synthetic art sample remain exact.

The pending screenshot deliberately returns `memory_fixture_pending` from the
fake owner, so its visible save-failure notice is expected. This exercises retained
presentation and Retry; it neither reproduces nor resolves the user's intermittent
ordinary-reply persistence report (`dwm-hsi`). The native harness mounts each day
directly; real Desktop lifecycle coverage is in the integration suite. These
captures do not prove physical-input or assistive-technology acceptance, nor all
locales and text scales. No player storage was used.

The first focused attempt exposed a test indentation error and unnecessary Desktop
notice queries on colour changes. The corrected runs execute every requested
suite. The first native attempt expected the old Gold focus role and sampled the
right scroll border instead of paper. Its failed log and measurements are retained;
the corrected harness samples a clear paper interior and the actual Ink focus
strip. The final logs retain 24 existing GUT fixture orphans and Unicode/NUL
diagnostics; no script/load errors remain. Log copies trim trailing whitespace
only. `runs.jsonl` retains exact isolated invocations and outcomes. Source base:
`f1b3ace7ad9adb4798c5bcca626f52c8220f1b13`.

This increment closes `dwm-vky.10`, not the parent UI epic or the expanded goal.
Witnessed and Minesweeper presentation, Steady Interface, Drift Deck, remaining
all-input work and the final evidence reseal remain separate. The concurrent
Minesweeper latency work in `dwm-634.2` is untouched.
