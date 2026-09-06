# Schedule warning presentation checkpoint

Following 92ae06dc5, the real ScheduleApp can mount a retained warning over its
undimmed, inert Docket. A read-only warning port projects caller-supplied copy and
only public Error text; injected command owners retain all transaction/navigation
responsibility. Unread invitations request Contacts, accepted dates dismiss, and
base opportunities request Minesweeper. Only an owner-recorded navigation failure
produces failed-Go Error. Technical command refusal requests recovery without
changing pending activation, entries, or receipts.

The fixed warning sheet implements Close/Go, native modal Back/Tab/Page, busy
input exclusion, ordinary/Large Targets, both Standard palettes, and the three
supported locales at 100/125/150%. Duplicate delivery retains nodes, scroll and
focus. The invariant `!` remains fixed-size. A new Error reveals its end and
returns focus to Close. The primary-paper-ink perimeter is one native pixel drawn
inward: an implementation choice where the accepted dossier specifies its color
role but leaves thickness unstated. It changes no hit or layout extent.

Actual rendering exposed a long-text bug in both warning and Schedule labels:
setting text before word-wrap allowed a 4,032px label to escape a 480px column.
Labels now establish wrapping before text, and measurement matches Godot's
WORD_SMART break flags and zero additional line spacing. The long Chinese warning
now renders at width 480, 16 lines and height 704; Error wraps at width 464.
See the [Godot Label implementation](https://github.com/godotengine/godot/blob/4.6-stable/scene/gui/label.cpp).

## Verification

- `warnings/schedule-warning-final-review.log`: ten suites, **120/120 tests,
  2,375 assertions**, native/wrapper exit 0, no script error or ignored suite.
  Mounted tests use the real registry, controller and issuer over a fixture root;
  injected command fixtures record real retained dismiss/failed-attempt facts.
- `warnings/schedule-warning-render-review.log`: three 800x656 actual GPU captures,
  inspected for English100, Simplified Chinese150/Large/failed-Go, and Traditional
  Chinese125. All prose in these captures is explicitly fixture copy.
- `warnings/schedule-panel-wrap-render.log`: seven existing Schedule GPU samples
  rerendered successfully, including direct detached-focus pixel assertions.
  Chinese150/Large was visually reinspected and retained here.
- Serial Godot 4.6.3 Mono jobs used isolated APPDATA and test roots. GPU jobs use
  an offscreen Windows/OpenGL task window and deliberately retain their isolated
  roots. No player save was opened. Existing certificate-store, Unicode NUL and
  24 Dialogic-orphan noise remains; full-game startup is not claimed.

Independent review corrected missing perimeter and silently ignored command
failure. Earlier behavior regressions also caught scaled warning glyphs and
inconsistent measured/rendered wrapping; the final suite includes those cases.

## Remaining

Production Done/navigation composition, exact public warning copy, foreground
timer custody, recovery-host routing, launcher admission and combined save/Load
remain open. High Contrast/CVD, RTL, semantic reflow anchors and native assistive
technology/platform evidence also remain. This checkpoint does not complete
Schedule or the overall ten-family UI goal; dwm-eei.8 stays in progress.
