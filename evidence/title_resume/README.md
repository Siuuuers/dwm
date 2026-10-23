# Title Log in and resume after restart

Log in mounts the existing Backup cabinet in its title context. Normal Load
prepares and commits through the existing SaveManager; there is no active-run
replacement dialog on the title screen. An earlier compatible checkpoint uses
a fallback-only confirmation. Delete retains its Cancel-first confirmation.
Title Save is absent from the UI and rejected by the presentation port.

Every opening selects loadable Autosave first, then the first loadable drawer
in cabinet order, otherwise disabled Autosave. Selection never loads a record.
Return and Escape restore focus to Log in. Confirmation and failure recovery
retain input custody without relabeling the underlying title commands Disabled.
The title shares the existing fonts and scale settings. Its logical canvas is
1280×720, with a 320-pixel command ledger and 960-pixel workfield; the title
cabinet has no mode controls and keeps its lower 96 pixels quiet.

The implementation reuses BackupApp, BackupPresentationPort, DesktopConfirmation,
the shared theme and the existing save/restore transaction. It introduces no
new save manager or persistence format. Menu owns title presentation only.

Run `python tools/title_resume/verify.py` to import one disposable project and
launch two separate production processes sharing one isolated user directory.
The first visits empty title Backup, creates a run, applies the registered
`money:+5` effect as a test probe, saves through the real in-run Backup UI, and
exits. The second starts cold, checks empty/corrupt drawer behavior and Delete
cancellation, then resumes the untouched saved slot through Log in. The observer
checks a ready Main scene, saved progress, one restore notification, and a usable
Backup app. The exact `user://` path is proved before production owners initialize.

[Final receipts](result.json) record 74 passing restart-flow checks, 3,870 passing
Backup/title UI checks, 41 passing in-run regression checks, and 45 passing owner
GUT tests. The restart and UI source bindings are fully current; collateral
changes in the earlier regression receipts are listed explicitly. [Independent
review](review.md) found no remaining material finding in this integration.

This is headless behavior and layout evidence, not GPU raster or physical-input
certification. The existing opening timeline is still draft content. Proportional
Canvas Items/Keep scaling follows the [Godot 4.6 resolution settings](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html); engine bars
are black, and this does not claim complete palette-matte presentation at every
aspect ratio. Inherited shutdown diagnostics remain visible and are accepted
only when they exactly match the retained observer-free baseline. General late
finalizer journal rollback remains outside this milestone, as documented in the
preceding save/load result.

Changes remain uncommitted in `contacts-ui-build`. Actual player saves, unrelated
worktrees, Git refs, Beads and historical UI-00/UI-00R recovery are unchanged by
this task. This is not a formal authority cutover or whole-game completion.
