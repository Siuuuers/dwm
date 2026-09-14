# Witnessed recovery keeps input above Pause

2026-09-14; partial `dwm-vky.14` checkpoint based on
`524409049977b593bc957275d56736e5230c3b88`.

Visible Witnessed reading recovery now consumes mapped Back packets before
Universal Pause can handle them. Back does not imply Retry or Cancel and retires
pending recovery-button input. Hidden or dismissed recovery returns Back to the
normal owner. Existing Tab navigation is unchanged.

Caption view capture and direct Pause/Backup commands also refuse while recovery
owns the current viewport. The command boundary checks all visible Witnessed
captions before gate, session or frontier capture; an earlier normal caption
cannot mask a later recovery. Foreign viewports do not claim this custody.
The per-frame Load projection stays cheap and does not traverse the tree or
capture session state. No profile, story, recovery record or save format changes.

Authority: [Witnessed scene](../../docs/design/current-ui/witnessed-scene.md)
retains the accepted [Ordered Ending/Universal Pause amendment](../../docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md),
lines 713-715 and 877-889: technical recovery owns only its registered actions
and precedes ordinary Back/Pause. [Shared shell](../../docs/design/current-ui/shared-shell.md)
lines 413-419 and 956-969 corroborate that priority.

## Verification

- Final surrounding and tooling run: **12 suites, 192/192 tests, 8,065 assertions,
  exit 0**. This includes real installed Dialogic, mounted Pause/Backup, fresh
  transport input, exact caption retention, recovery, and both inventory/docs
  tooling suites.
- Focused final recovery run: **8/8 tests, 193 assertions, exit 0**. A genuine
  failed Profile write retains the same beat and offers explicit Retry; Retry
  succeeds once. Direct admission tests separately inject the logical recovery
  owner and prove refusal before session capture, normal admission after release,
  later-caption priority, and foreign-viewport noninterference.
- Windows main-viewport probe: **exit 0**. Real recovery controls receive injected
  Escape and controller-B packets; neither reaches a lower unhandled-input
  observer, fires Retry/Cancel, nor changes composed Pause state. Contacts drain.
  Tab/Tab/Shift-Tab yields Retry, Cancel, Retry, Cancel. Fatal recovery exposes no
  action. The controller mapping is temporary.
- Generated public inventories change source references only. Required contracts
  and protected implementation remain unchanged; see `scope-verification.json`.

## Attempts and limits

`runs.jsonl` preserves all **14 terminal engine runs** and `logs/` their output.
The original RED exposed four expected failing tests, including Back leakage and
direct capture during recovery. The later-caption test first mounted its extra
caption in the wrong traversal order; the corrected RED showed six unwanted
session captures before a late refusal. The filtered traversal passes that case.

Five native receipts include the failed setup attempts. The initial probe assumed
automatic production composition under an isolated test root; the wrapper instead
selects manual-test startup unless `-- --phase2r-bootstrap-mode=final` is supplied.
The next correction allowed the component's deferred initial focus to settle;
the final helper also compares equally typed String arrays, avoiding a false
failure when the observed focus sequence already matched. No production change
was made for those helper defects.

The native probe mounts the recovery component over the composed Menu, not a
playable narrative failure. Actual narrative admission is covered by the mounted
integration tests. Input uses `Viewport.push_input`; there is no physical-device,
UIA, screen-reader, or other-platform claim. Existing Unicode NUL diagnostics and
Dialogic orphan reports remain; the final suite reports 2,664 orphans. No
warning-free, leak-free, or whole-game completion claim is made.

Archived logs normalize line endings to LF, trailing whitespace and final newlines.
`source-sha256.json` records nine verified source/generated files;
`sha256.json` seals this evidence. `dwm-vky.14` remains in progress: History,
Witnessed Save, exact-variant Next, and broader reading recovery remain separate
work. No `dwm-634*` Bead, owned branch/worktree, or protected persistence,
checkpoint, schema, GameState, SaveManager, or DatingScene implementation changed.
