# Schedule navigation and Standard palettes

Continuation of 84a56fa49 on codex/schedule-ui-build; dwm-eei.8 remains in progress.

## Changes

- Page Up/Down addresses only the paper containing the focused control. It clamps
  at the owner's bounds without editing the draft, changing inspection, moving
  focus or redirecting a fitting Available list to the Docket. Drag and awaited
  Done custody prevent the new keyboard scrolling.
- The actual ScheduleApp remembers semantic local focus across hide/show, refreshes
  from its retained owner on return, and preserves the existing same-view offsets.
  External fingerprint changes clear inspection, focus and offsets. The explicit
  `clear_presentation_cache()` hook also supports a host clearing cache after Load
  when the restored fingerprint happens to match. No production Load hook is wired
  here, and raw offsets have not yet become semantic anchors for locale reflow.
- Direct hide now observes the existing Home custody gate. Reopening cannot complete
  a previously held pointer contact. Rejected configuration retains the valid locale
  for a subsequent recovery refresh.
- ScheduleTheme supplies the exact accepted After-Hours and Midnight Standard
  roles to papers, text, controls, scroll witnesses and insertion. Paper focus uses
  Deep Brass; Done uses Tarnished Gold. Registered art remains untinted. Only the
  two Standard tuples are admitted; no High Contrast/CVD tuple is implied.
- Two inert focus overlays preserve the detached four-native-pixel rails when a
  focused paper control meets the scroll aperture edge. They use canvas transforms,
  clip to the aperture's reserved clearance, and add no scroll extent or input target.
  Entirely scrolled-away controls draw no orphan rail. Done retains its local rails.

## Evidence

Godot 4.6.3 Mono, isolated APPDATA/test roots:

- Initial `schedule-keyboard-red.log`: 9/11 passed; Page scrolling and cached focus
  failed before their fixes. This was an executed behavioral failure, not a parser
  or missing-suite result.
- [Final regression](navigation/schedule-navigation-final.log): **9 suites,
  103/103 tests, 2,026 assertions**, native/wrapper exit 0. Actual scene tests inject
  native pointer and keyboard events into an isolated SubViewport. The added tests
  cover cache reset, external replacement, held contact, custody, two-palette child
  inheritance and untinted art. Primary contrast tests linearize sRGB values.
- [Final render log](navigation/schedule-navigation-render-final.log): seven real
  OpenGL captures, native/wrapper exit 0. Standard English, Simplified Chinese 150%
  Large, Traditional Chinese 150% Large, empty Day 7, Unavailable, disabled Earlier,
  source focus, selected occurrence focus and Remove focus are represented. This is
  a focused rendered subset, not the dossier's full release matrix.
- Actual PNG inspection found the bottom Remove rail clipped before the overlay fix.
  Pixel (500,554) changed from paper RGB(195,186,163) to Midnight habitat RGB(13,21,20).
  The final render probe checks both bottom-rail pixels (500,554)/(766,554) and the
  first occurrence's top-rail pixels (296,24)/(480,24), outside the scroll apertures.
- Final render uses an offscreen task window, Compatibility/OpenGL 3.3 on Intel Iris
  Xe, and `-KeepRoot` to preserve its isolated root. Player saves were not used.
- Existing certificate-store and Unicode NUL environment messages remain; regression
  ends with the same 24 Dialogic orphans. No script error or ignored suite was found.
  No fresh full-game startup, production navigation or combined-save claim is made.

The retained gameplay integration task dwm-oyo.3 was still in progress when checked.
No destination merge, push, destination edit or task closure is part of this work.
