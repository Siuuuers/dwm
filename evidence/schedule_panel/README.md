# Mounted Schedule draft screen checkpoint

Based on be127b24b, this replaces the obsolete Schedule scene's action/gift/alert
placeholders with the accepted Available paper, packed Docket, inspection folio,
and action dock. The production desktop launcher remains unchanged and does not
yet admit Schedule. Task dwm-eei.8 remains in progress.

## Implemented behavior

- Native 400x328 composition at fixed 2x logical size; independent Available and
  complete-Docket scroll owners, inert scroll witnesses and no nested folio scroll.
- 10px native text baseline (20 logical), 100/125/150% fonts and ordinary/large
  targets in en, zh-CN and zh-HK. Generic command translations are UI working copy;
  public action names must be explicitly supplied by the caller's catalog.
- Seven stable positions on days 1-6, packed filled prefix and inert empty suffix.
  Day 7 has no empty slots/order marks, and only its chosen source has Selected.
- One inspected occurrence with name, order and fixed registered art. Focus and
  Selected are independent. Earlier/Later boundary controls remain visibly disabled.
- Real SchedulePresentationPort binds trusted Contacts snapshots, retained registry,
  view controller and issuer. Read projection issues no identities. Every existing
  date receipt is validated against Contacts; only expected rule refusals become
  visible Unavailable. Technical failures propagate. Public DTOs exclude effects,
  costs, routes, provenance and receipt data.
- Append, insertion move and remove invoke the existing owner. New draft IDs use
  the retained issuer's unique transaction tokens; canonical Schedule-entry IDs
  remain the later commit owner's responsibility. No-op Day 7 selection issues no
  unused identity. Stale source/view requests refresh the public frame and retain
  semantic focus/inspection where still valid.
- Native grip-only drag has no preview/ghost. Its payload binds this panel,
  projection revision and occurrence. One boundary witness maps to one insertion
  edit. Outside release, Back, hiding, focus loss and replacement cancel capture.
  Back during drag does not leave the app. Competing edits/Home refuse during drag.
- Done requires an injected handler and stays disabled without one. Async handlers
  are awaited with local controls inert and Home refused through can_return_home.
  Schedule never overwrites the host's shared Home state after an awaited handoff.

## Verification

Godot 4.6.3 Mono, isolated APPDATA/test roots, serial invocations:

- `schedule-ui-reviewed.log`: eight executed suites, **90/90 tests, 1,893
  assertions**, native/wrapper exit 0; no script error, skipped or ignored suite.
- Tests mount the actual ScheduleApp scene against real registry/controller/Contacts
  transforms and the real issuer over its fake root-store fixture. They exercise
  pointer down/release through an isolated SubViewport, native drag/drop, competing
  edit custody, stale recovery, focus repair, keyboard action neighbors, and async
  Done custody. This is not a full production GameState/Bootstrap session.
- The component metrics matrix covers 18 locale/scale/target tuples, fixed topology,
  measured label height, exact art sizes, inspection states and the bare Day 7 case.
- `schedule-scene-load.log`: **28/28** required scenes load and instantiate.
  This probe does not mount every scene or prove full-game startup.
- `schedule-render-final.log` and three PNGs: actual OpenGL 3.3 rendering on Intel
  Iris Xe, 800x656 SubViewport captures, inspected for English100, Simplified
  Chinese150/large and empty Day7. These are presentation fixtures, not story/save
  screenshots. Compact-ticket pixels were also read directly from the PNGs;
  both populated captures retain 256 dark outline pixels in the first art aperture.
- The render invocation overrides the wrapper's headless display with the Windows
  display driver in an offscreen task window. `-KeepRoot` deliberately preserves
  its isolated test root: the first native-successful render encountered a cleanup
  access error; subsequent preserved-root runs exit 0. No player data is used.
- Environment noise remains: root certificate-store read error, Unicode NUL
  warnings and 24 Dialogic subsystem orphans. No clean full-game startup is claimed.

Independent reviews identified and corrected technical-error-as-Unavailable,
unvalidated retained date receipts, vanished append sources, async Done custody,
stale-frame retry traps and held folio contact. Native input evidence additionally
found and fixed row interception of ancestor drop targets. Shared Home mutation
was removed instead of adding another custody mechanism.

Godot 4.6 supplies internal scroll hint textures; this screen disables them and
the container's extra focus border in favor of its accepted marks. See the
[upstream ScrollContainer implementation](https://github.com/godotengine/godot/blob/4.6-stable/scene/gui/scroll_container.cpp).

## Still required for full Schedule acceptance

Production retained-owner/launcher composition and real public name catalog;
Done warning sheets, exact warning copy, condition/navigation handoff, Day 7 entry
gate and combined save/restore; all required palettes/contrast modes and RTL;
native assistive-tree verification and touch/controller platform checks; full
required rendered state matrix and cache/Load return behavior. The local
Unavailable recovery leaf must connect to the shared recovery host. This checkpoint
is a working draft screen, not a claim that Schedule or all ten UI families are done.

## Subsequent navigation and Standard palette checkpoint

See [navigation and palette evidence](navigation.md) for the changes following
84a56fa49: native Page keys, retained-view focus return, explicit cache reset,
both Standard palettes, and detached focus rails outside the scroll aperture.
That checkpoint supersedes the Standard-palette and same-view focus gaps above;
the production owner/launcher, warning, save/Load, semantic reflow anchors,
High Contrast/CVD, RTL and platform accessibility work remains incomplete.

## Subsequent warning presentation checkpoint

See [warning presentation evidence](warnings.md) for the mounted modal sheet,
retained-owner warning projection, command recovery and multilingual wrapping
correction. Production warning copy/navigation and the listed integration and
accessibility gaps remain open.

See [refused-edit status evidence](status.md) for the pinned dock fact and its
refresh, reflow, announcement-request and departure lifecycle.
