# Day 7 Prelude Pause custody

This 2026-09-13 increment, based on `613ca131c` and tested with Godot 4.6.3 mono,
applies the accepted Contacts witnessed-presentation
law and universal Pause custody to the installed Day 7 followup and ordinary
echo cards. The governing Pause rules are the August 13 Universal Pause
amendment §§12.2, 13.2–13.4, and 14.1–14.4: freeze and cover the exact source,
host the real Backup component, restore exact focus on Continue, and let Load
reconstruct the canonical destination with Pause closed. Contacts amendment
§7.4 remains the authority for a witnessed receipt tied to actual presentation.

`Day7PreludeSurface` now opts the installed prelude into production
`InputManager` custody and exposes an exact Pause projection for the current
view, receipt, and acknowledgment. Its capture anchor preserves the card,
history, scroll, and focus. Pause covers the surface instead of leaving it
visible beneath the glass. Continue restores the same surface and card without
publishing another witness or advancing it.
`Day7PreludeOwner` binds that production input owner. The production Pause
controller admits the Day 7 projection only on its exact live main-route source
and delegates capture, cover, and restore to the retained surface.

Presentation completion and navigation remain separate. The current card's
drawn leading edge in the scroll aperture commits its exact receipt once and
stays visible, with the complete entry available through scrolling. A later fresh Next moves
to the next obligation. A failed receipt save exposes Retry for that same
receipt; it neither navigates nor consumes pending work. Held, stale, canceled,
foreign-view, and replacement-card input stays closed.

Day 7 Load now uses the existing restore handoff even though this surface has
no Dialogic frontier. Its old view, input and tree remain held until the new
session is published. A failed Load retains the same suspension for Continue
or retry. No save schema, public GameState/SaveManager contract or second
physical-contact ledger was added.

## Recorded verification

Exact isolated commands, roots, timestamps, log paths, and exit codes are in
the retained [command and exit ledger](runs.jsonl). Earlier attempts below are
historical evidence; the three final suites and final journey used frozen source.

- `day7-input-native-20260913.log`: **22/22 tests, 309 assertions**, exit 0,
  across the Day 7 input and surface suites using the Windows/OpenGL renderer.
  It covers keyboard, controller, mouse, touch, fresh-contact admission,
  cancellation, Pause quarantine, receipt Retry/Next separation, and native
  short/long-card draw-aperture behavior at production text sizes.
- `day7-pause-surrounding-20260913.log`: **54/54 tests, 970 assertions** across
  five suites, exit 0. This includes all **19** production Pause-controller
  tests plus lifecycle coordination, input custody, hosted Backup, and retained
  scene-art behavior.
- `day7-pause-load-custody-20260913.log`: the focused failed-Load case passes
  **1/1 test, 28 assertions**, retaining the covered Day 7 view, suspended input,
  exact source, and zero preparation/acknowledgment calls through failure.
- `day7-pause-native-journey-20260913.log`: the full production-bootstrap
  journey exits 0 in **23.24 seconds**. It selects the Day 1 ordinary reply,
  reaches Day 7 through public Schedule actions, pauses and continues the
  accepted followup without implicit Next, injects one echo-checkpoint failure,
  and loads the real Autosave through Pause > Backup. The
  `live_session_ready` observation records the fresh session with exact saved
  Contacts, no followups, and the pending echo before its replacement redraw.
  The old command is rejected, the new view token witnesses the echo once, and
  a fresh Next drains the final presentation.
- `day7-pause-final-native-20260913.log`: **43/43 tests, 738 assertions**, exit 0,
  after final review fixes: 12 input, 11 surface and 20 production controller
  tests. Exact repeated cover is idempotent; foreign anchors fail. Captured
  absence of focus stays absent, and losing the retained view anchor keeps the
  desktop hidden in Recovery. Losing the bound InputManager never reverts to
  unbound button admission.
- `day7-pause-final-surrounding-20260913.log`: **35/35 tests, 580 assertions**,
  exit 0, covering lifecycle, input custody, hosted Backup and scene-art holds.
- `day7-pause-repository-final-20260913.log`: **14/14 tests, 410 assertions**,
  exit 0. After source freeze both inventories were regenerated; all **239
  GameState and 74 SaveManager** records compare equal to the base after
  excluding call-site locations.
- `day7-pause-final-journey-20260913.log`: the full native journey above passed
  again after the recovery/focus fixes, exit 0 in **23.57 seconds**. Its final
  captures were inspected and copied unchanged into this directory.

Final targeted verification totals **92 tests and 1,728 assertions**, plus the
full native journey. The existing Unicode NUL diagnostics and 24 outside-test
Dialogic/GUT orphans remain in the raw logs; this is not a full-suite claim.

The inspected native captures `14-day7-paused-followup.png` and
`15-day7-pause-autosave-confirmation.png` show the Day 7 card fully covered by
Pause and by the real Autosave confirmation. `13-day7-restored-echo.png` shows
the restored echo with its leading body and scroll aperture intact. Capture
files are retained here, with original paths in the run ledger.

The initial red run (`day7-pause-red-20260913.log`) failed the intended boundary
at **18/20 assertions**: Pause did not cover the Day 7 layer and Continue did
not restore its focus. The passing runs above exercise the repaired behavior.
Review then found that a late Day 7 restore failure could expose the base scene
before recovery re-covered it. `day7-pause-recovery-red-20260913.log` reproduced
that failure (**0/1 test, 17/18 assertions**, exit 1). The controller now restores
the prelude before publishing the desktop. Review also caught pending initial
focus surviving a capture whose actual focus was empty. Cover clears that
pending focus, and restore uses only the captured target. The final native
regressions pass, and independent final review found no remaining blocker.

## Evidence boundary

Native input here means Godot `InputEvent` objects injected through the real
viewport/input path; it is not physical keyboard, controller, mouse, or touch
hardware acceptance. The native journey opens Pause and activates Continue and
Day 7 Next through that input path; the native input suite also exercises Retry.
Backup selection, Load, and confirmation use
the real hosted controls and their UI signals. Rendering claims come from actual
Windows/OpenGL draws and inspected viewport captures.

This evidence makes no claim for Day 7 Auto, Skip, instant-text policy, TTS,
assistive-technology traversal, unrelated global shortcuts, or general idle
Load behavior. It does not close broader narrative transport or accessibility
work, and it does not treat Pause presentation state as saved run state.
The accepted invisible ordinary-message expiry tombstone remains outstanding,
as do the broader echo/drain requirement evidence and parent Beads. This
increment does not change Minesweeper latency code or retire those tasks.
