# Real startup and save/load loop

This milestone connects the existing Backup UI to actual production startup,
filesystem storage, state owners and SceneTree restoration. [Final results](result.json)
record 41 passing full-loop checks, 2,216 passing Backup UI checks, and 45 passing
targeted GUT regression tests (478 assertions), plus the focused owner suite.
The loop, UI and owner receipts match all current source bindings. The retained
136-check capture receipt has one explicitly documented, unexercised GameState
dependency change. [Independent review](review.md) found no remaining material
issue in the reviewed scope.

The disposable runner copies the real project and inserts only a first test
observer autoload. The original main scene and production autoloads remain.
Before any subsequent autoload enters the tree, the observer checks the exact
engine `user://` path against the wrapper-owned disposable directory. Startup
explicitly requests `final`, never a development subset. Original, temporary and
post-import project settings are retained with exact diffs.

The observer drives New Acc, the existing Opening Continue button, the desktop
launcher and actual Backup actions. It validates the real slot document, applies
the registered `money:+5` effect through the real transaction and identity
owners, visits Settings, then tests Load cancellation, stale disk-revision
rejection and a freshly confirmed successful Load. It waits for a different,
ready MainGameScene instance and verifies saved progress, the saved Backup host
route, reset transient UI and usable Home. The effect is a test probe, not a new
gameplay reward or authored story event. The existing opening timeline currently
contains only draft comments and `return`; this is wiring evidence.

Necessary corrections are deliberately narrow:

- Desktop restore preparation produces a detached candidate. The route plan
  carries saved app/day, transaction apply installs them and rollback restores
  the exact prior host/cache state.
- Registered route resources are validated before restore mutation; rejected
  engine scene-change requests propagate failure. Physical routing finalizes
  after the other fallible participants. The semantic route token alone never
  proves target-scene readiness; the observer checks the actual scene.
- Manual Backup Save captures a fresh safe desktop checkpoint through a
  Bootstrap-owned provider. The explicit `manual_save` boundary records actual
  live run, board, consequence and presentation state. Preparation changes no
  journal or file. Confirmation binds capture and journal revisions; successful
  durable writing precedes journal advancement. The manual-save history retains
  the latest 32 prior entries, preserving existing narrative anchors.
- Loading the current checkpoint may replace the journal at the same sequence;
  this is a validated restore, while duplicate New Run commits and reused UI
  confirmation tokens still reject.
- GameState restores the saved command receipts, applied transaction IDs and
  narrative-variable state. Its silent rollback captures those same fields, so
  unsaved transaction bookkeeping cannot survive a successful Load.

This does not implement title Log in, additional apps, full authored narrative,
physical input/accessibility certification, GPU appearance or every restore
failure mode. An observer-free startup baseline reproduces the inherited engine
shutdown resource diagnostic; original logs and any narrowly allowed diagnostic
comparison remain visible. No claim of leak-free shutdown is made.
In particular, the existing transaction commits its journal before participant
finalizers; these checks do not establish journal rollback after every possible
late-finalizer failure. Routing now finalizes last, and a focused injected
narrative-finalizer failure verifies that it does not dispatch a scene change.

All work remains uncommitted in `contacts-ui-build`. Player storage, unrelated
root/destination work, historical recovery proposals, refs and Bead records are
outside this change. The runner checks available space and removes its verified
copied project/import directory even on exceptional exits, preserving receipts,
logs and isolated user data.
