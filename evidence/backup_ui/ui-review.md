# Backup UI review — 2026-09-05

Source review and final Backup UI receipt readback find no remaining material blocker in the bounded in-run Backup implementation. The headless Backup UI suite passed 2,216 checks, and all 55 recorded source hashes match current files.

## Scope and independence

Reviewed `scripts/ui/BackupApp.gd`, `scripts/ui/backup/*`, the Backup route in `scripts/ui/ComputerDesktop.gd`, and `scripts/ui/desktop/DesktopConfirmation.gd` against the current Backup dossier, Shared Shell custody and `working-design.md`. BackupApp, drawer presentation, theme and desktop route were authored by other agents. After the independent review, this reviewer implemented the bounded risk polish in BackupKey and DesktopConfirmation; those portions were separately source-reviewed by the orchestrator, including reserved glyph geometry, and exercised by the separate test agent's final checks. This reviewer also authored the storage extension, which the data agent independently reviewed.

## Findings resolved in source

- Desktop day/restore eviction cancels the host confirmation before freeing cached views, restoring suspended controls and cancelling the pending token (`ComputerDesktop.gd:278`).
- Failed or rejected projection refresh retains the last trustworthy record evidence, exposes Unavailable and inhibits actions. Cached Backup opening rereads the owner before publishing the route (`BackupApp.gd:159`, `ComputerDesktop.gd:186`).
- Recovery re-entry is recomputed from fresh owner capability, including later projection changes. Without a lawful operation only Cancel remains; new preparation clears the old confirmation kind (`BackupApp.gd:240`, `BackupApp.gd:302`, `BackupApp.gd:387`).
- Local recovery confines activation to Cancel and fresh re-entry, removes mode/drawer/Home from active focus, retains information scrolling, and restores the lawful source when cancelled. Home and direct desktop opening respect foreground custody (`BackupApp.gd:419`, `ComputerDesktop.gd:186`).
- Deferred information measurement cannot restore background focus while a confirmation is active. Dismissal schedules fresh measurement (`BackupApp.gd:409`).
- Hidden cached Backup refreshes cannot rewrite the shared Home focus mode or route; only the visible Backup view owns those mutations (`BackupApp.gd:419`).
- Disabled keys retain nonfocusable state during ready. Neutral keys have a perimeter. Danger keys retain paired leading/trailing rails plus a distinct protected glyph; the sheet owns its separate Warning glyph and governing edge. These operational rasters are working geometry, not asserted recovered art assets.

## Design assessment

The nine fixed record identities and cabinet positions remain stable. Only the inspector information region scrolls, with status and actions pinned. Selection performs no save operation; prepared owner tokens carry confirmation, stale rejection, commit and cancellation. The UI does not infer saved time from filesystem or current time, and does not fabricate missing fingerprint or Transfer Bloom art.

The compact 20/25/30 drawer and action-dock roles are explicit measured working-design changes. Inspector, modes and wider confirmation keys retain 24/30/36. Danger glyph space is reserved independently of labels; no font shrinking, abbreviation or native Button text duplicates the caption layout owner. The confirmation body's reduced capacity may produce genuine vertical overflow while its action rail remains pinned.

## Evidence and limits

Final UI receipt: `tools/backup_ui/evidence/ui/result.json`, originating from `.godot/backup-ui-wxmpcpqy/result.json`. Independently read back `passed: true`, the 2,216-check BackupUI summary, the `BACKUP_UI_PASS` log marker, and all 55 source hashes with zero differences against current files. This includes the custody, capability and hidden-cache Home regressions as well as full-label layout. The earlier failure that exposed recovery capability recomputation was superseded by this run. Broader Desktop/Contacts regressions and the refreshed standalone font probe are recorded separately by the orchestrator; they are not silently counted as part of these 2,216 checks.

Storage evidence is separate: `.godot/backup-storage-b4yvlnka/result.json` passed 1,644 assertions, 578 injected I/O positions, 703 restart snapshots and the original eight GUT storage tests. Its 181 source hashes matched at storage handoff. See `tests/backup_storage/README.md` for the transaction model and disclosed diagnostics.

Headless UI fixtures do not prove real GPU raster quality, physical input hold/release behavior, assistive-technology traversal on hardware, every host, full game startup, or real disk power-loss durability. Title/Pause wrappers, authored drawer fingerprints and Transfer Blooms remain outside this in-run milestone. Source review and fake-owner UI tests are not represented as a complete end-to-end save/restore test; the real owner and storage suites provide separate evidence.
