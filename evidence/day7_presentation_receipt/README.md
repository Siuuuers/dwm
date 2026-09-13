# Day 7 presentation receipt boundary

2026-09-13, source base `d6ffa6525`, installed Godot 4.6.3 mono. This
increment separates the durable Day 7 presentation receipt from the player's
later request to navigate to the next card. It does not close the complete
ordinary-message echo requirement.

The approved seven-day design says that an echo is consumed only by a semantic
`presentation_atom_presented` receipt. A dialogue atom qualifies when the
renderer accepts it into the visible dialogue/history stream; another atom
qualifies when its registered staging state is applied and entered in
presentation history. Skip, Auto, TTS, instant text and accessibility input
remain valid, while dwell time is never required
(`docs/design/2026-08-07-seven-day-dialogic-flow-design.md`, lines 648–656).
The accepted Contacts amendment adds the physical boundary: the leading content
edge must enter the visible transcript viewport after layout and the complete
semantic entry must be available in the scroll stream, or assistive traversal or
TTS must explicitly reach it. Long entries qualify at their visible beginning
and must remain fully scrollable
(`docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md`
§7.4, lines 336–356).

`Day7PreludeOwner` opts its surface into presentation-receipt mode. Once the
current body has really drawn with its leading edge in the scroll aperture, the
surface records the complete detached card in presentation history and defers
the existing exact acknowledgment callback outside the draw callback. A stale
queued callback, replaced token, retired surface, repeated draw or passive frame
cannot acknowledge again. A failed durable save leaves the same card visible and
turns its button into Retry; successful retry records the same receipt and still
does not navigate.

After the receipt succeeds, the card remains visible and scrollable. Next then
emits a separate, one-shot navigation request; the owner validates the exact
acknowledged receipt before deriving the following pending card. Next before the
physical witness does nothing, and repeated Next cannot save or advance twice.
This preserves the existing follow-up-before-echo order and the state owner's
sole authority over `commit_day7_followup` and `commit_ordinary_echo`.

The mode is explicit and opt-in. `DialogicBridge` continues to construct Gallery
date replay cards with the surface's default completion-on-Next behavior and does
not call `use_presentation_receipts()`. Gallery therefore neither writes a Day 7
Run receipt on draw nor finishes a replay before the player selects Next.

## Aperture correction

The first native long-card test reproduced a real false witness. The new body had
drawn while its leading edge was clipped. The same run showed the title at y=500
instead of the aperture's top at y=352. The test failed **1/1 tests, 11/13 assertions** in
`day7-presentation-aperture-red-case-20260913.log`.

The correction anchors each newly presented card at the top of the history
scroll instead of using `ensure_control_visible()`, whose tall-control behavior
aligns the bottom. Receipt admission now checks the body and viewport rectangles.
Scroll changes, scroll resizing and body layout changes request another draw
until the leading edge is actually visible. Production uses layout and scroll
signals; the native fixture observes real draws without emitting a fake draw.

The first full production-layout diagnostic found a second concrete form of the
same risk at 100%: an empty status Label still occupied 35 pixels plus the
16-pixel container gap, leaving a 53-pixel aperture whose end was y=525 while
the body began at y=531. The new aperture check correctly withheld the receipt;
the former draw-only rule would have accepted the clipped body. Empty status is
now hidden and occupies space only for an actual error or Retry message. The
mandated `SceneArtView` height remains unchanged.

## Verification recorded so far

| Evidence | Result and scope |
| --- | --- |
| `day7-presentation-red-20260913.log` | Expected RED: **7/10 tests, 77/80 assertions**, exit 1. The three new receipt/navigation tests could not select presentation-receipt mode. |
| `day7-presentation-green-20260913.log` | First GREEN: **10/10 tests, 105 assertions**, exit 0. Draw-time durability, separate Next navigation, exact retry and retired deferred work pass. |
| `day7-presentation-aperture-red-20260913.log` | Invalid diagnostic only: the `native_long` filter selected zero tests and exited 0. This run is not evidence. |
| `day7-presentation-aperture-red-case-20260913.log` | Valid native RED: **0/1 tests, 11/13 assertions**, exit 1. It reproduced clipped leading-edge acknowledgment and wrong top anchoring. |
| `day7-presentation-aperture-green-20260913.log` | Integrated native surface GREEN: **11/11 tests, 118 assertions**, exit 0, including native long-card aperture geometry with the 36-pixel fixture theme. |
| `day7-presentation-surrounding-20260913.log` | On the initial implementation base, Gallery replay owner, ordinary echo state/runtime and Witnessed run presentation passed **36/36 tests, 823 assertions**, exit 0. This is surrounding regression evidence, not a rerun after every later aperture edit. |
| `day7-presentation-native-layout-20260913.log` | Full production journey, exit 0 in about 19.7 seconds: real New Account and first Reveal, deferred round loss, Lavinia A, every public Schedule Done through Day 7, automatically durable Priscilla follow-up held for Next, injected echo-save failure and exact Retry, physical Autosave prepare and commit, fresh session/owner/token, automatically durable restored echo held for Next, then retirement on fresh Next. |
| `day7-presentation-native-sizes-20260913.log` | Final native surface suite: **11/11 tests, 156 assertions**, exit 0. Real production Gallery themes at 100%, 125% and 150% present both a complete short first card and the start of an 80-line following card. |
| `day7-presentation-surrounding-integrated-20260913.log` | Final integrated surrounding suites: **36/36 tests, 823 assertions**, exit 0. |
| `day7-presentation-repository-final-20260913.log` | Final public-inventory and documentation tooling suites: **14/14 tests, 410 assertions**, exit 0. |

The first native seven-day journey failed an obsolete fixture assumption that a
round result was available immediately after request. The corrected fixture
waits for the actual app terminal state, settled result and round increment; it
does not pump production state. Later diagnostic runs reached Day 7 and exposed
the production-layout aperture problem above. The final full journey passed as
recorded in the table. Its inspected captures show the first follow-up body and
the restored echo beginning with `Earlier, you said:`; the complete reply remains
available through scrolling. The unmodified viewport captures are retained as
`12-day7-followup.png` and
`13-day7-restored-echo.png`.

The native journey uses UI signals and public commands. Its checkpoint writer
fails exactly one attempt before the real writer is restored; game state,
messages, replies, clocks and save owners are not seeded or replaced. This is
not a claim of physical keyboard, touch or controller coverage.

Final targeted verification totals **61 tests and 1,389 assertions**, plus the
full native journey. Both public inventories were regenerated after source
freeze; all 239 GameState and 74 SaveManager contract records remain unchanged
apart from call-site locations. Independent final review found no production
blocker. Its optional-body guard for preparation-failure timeout diagnostics is
included; the successful native journey does not enter that diagnostic path.
Existing NUL diagnostics and Dialogic/GUT orphan reports remain in the raw logs.

The first repository-gate command used incorrect paths without `tooling/`.
The wrapper refused that zero-suite run (recorded exit 126); the corrected final
command ran both suites and passed. The command/exit ledger retains unsuccessful
setup attempts as well as the passing runs. No player save or sealed plan is
modified, and no requirement evidence array is filled prematurely.

## Remaining work

- The accepted Contacts amendment still requires the invisible ignored-message
  expiry/sequence tombstone. Visible midnight disappearance and restore evidence
  do not dispose of that persisted requirement.
- Day 7 Auto, Skip, production TTS and assistive-technology traversal have no
  end-to-end transport into this receipt boundary. Instant rendering is admitted
  by the physical draw rule without a dwell requirement, but this does not prove
  the other input modes.
- Native keyboard, controller, pointer and touch custody is not certified for
  this surface. Held contacts, cancellation, focus loss and same-frame release
  quarantine remain open.
- Universal Pause coverage remains open, including cover/restore, focus return,
  held-input retirement and pending-card preservation across Pause Backup/Load.

The parent work and its Beads remain open. This evidence claims only the scoped
Day 7 presentation receipt, separate navigation, Gallery compatibility and the
tested aperture correction. Save validation work owned by `dwm-634.2` is outside
this increment.
