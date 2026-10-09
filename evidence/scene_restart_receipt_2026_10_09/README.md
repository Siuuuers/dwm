# Committed initial receipt and fresh-process restart — 2026-10-09

Coordinator A replacement continues Director dispatch 5994622489 and D finding 6079395544. Product PR27 remains draft, controller PR30 remains draft, and PR1/master are unchanged.

## Source and ownership
Product: ae82ccd951ca4c6797b5ea18dcbfba6035fd60fb; tree 2c4505f76f30a03fbdba0ef03bc35200253cd785.
Controller: 42b7264978fcb456e71273213e0198892cd1ff19. Its sole difference from product is .github/workflows/windows-tests.yml, blob 8096ec509ce8c2bfca49322d3c1791e3df775557. Actual PR event c45434e30aa941e8df944d10f9ea0fdc1a7629fc has that exact workflow blob.
Pinned Godot 4.6.3 standard: console SHA256 63b3b2208819714c9677fbfdd8217c5b7dee8ecf5f383502e826bc9e2227ff5a; archive SHA256 e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90.
Godot and PowerShell ran only in GitHub Actions. Local work was source review, git operations, and Python artifact verification.

Product ancestry: 109309cc → b7c1a0ab (strict committed receipt and regression) → 93c7aa49 (fixture correction, two-process tests and wrapper) → c3f26fd6 (cold read-only inspection) → ae82ccd9 (explicit validated storage reconciliation before direct Load). Last two commits affect only tests/integration/test_scene_restart_child.gd.

SaveManager now extracts the exact initial receipt from the acknowledged creation operation's retained new_run_materials.autosave outgoing text. SceneEventContract compares the incoming receipt to that immutable authority after existing allocation/Profile validation. It does not compare the whole evolved save or current Autosave against the original creation document.

## Retained successful lanes
- Run 37923940077 / job 113798278107: initialjoint, 3 cases / 70 XML assertions (71 including GUT setup), zero failures/errors/skips/script errors. Rebuilt valid target-A receipt after committed target-B creation passes candidate admission but fails direct committed, Run and Save admission with scene_initial_committed_receipt_mismatch; input, live owners and physical files unchanged. Evolved checkpoint and unrelated later Profile preference remain admissible.
- Run 37923940077 / job 113798278435: full PowerShell isolation helper regression, ISOLATION_HELPER: PASS. Includes sequential shared-root children, unchanged single-child record schema, invalid second args/log names, first/second child failure, timeout, cleanup, containment and pre-second-child reparse traversal.
These retained lanes ran on product 93c7aa497b2c5d8d0d166557247062142bc7a059. Their dependencies are unchanged by the final two test-only corrections, so they were not repeated.

- Final restart run 37925022971 / job 113801774386: **success**, 2 cases / 88 XML assertions (create35 + load53; 90 including GUT setup). Zero failures/errors/skips/script errors. Source ae82ccd9. Creator PID6212 and Load PID3952, same storage root and Autosave SHA256 dda5d74745c3a1b94aea5b4f76729356da3d702d08e5e3b9f1fa52def8f41826, same run/checkpoint and native line/publication; distinct creation/restore operations. Real mounted host and native signals complete acknowledgement, unchanged selected source, new branch/generation, unchanged Profile assignment, no duplicate history publication or readiness.
- Across retained joint and restart lanes: **5 cases / 158 XML assertions**, plus the separate successful tooling regression. This is a bounded aggregate across compatible sources, not one whole-runtime run.

## Original failures retained
- 37923538473 / 113796965595: joint creation passed; new tests failed trying to replace process-static registration in before_each. Corrected to one before_all fixture and genuine additional NewRuns. Original 3-case/51-assertion report has 2 failures.
- 37923940077 / 113798278229: create passed (35 XML assertions); fresh-process Load diagnostic attempted leased read_text before reconciliation. Load report has 7 assertions and 1 failure.
- 37924410904 / 113799796477: create passed (35 XML assertions); cold inspect_revision, exact persisted identity and Save admission succeeded; direct prepare_restore_autosave still refused lease_missing. Load report has 14 assertions and 1 failure.
No original failure is relabeled as a pass; run 37923940077 overall failed despite its retained successful independent lanes.

## Scope and remaining work
Restart uses actual files, issuer root/allocation, physical Profile, GameState/Run, SaveManager selected direct Load, actual DesktopIdentityAllocationRestoreParticipant, SceneRouter-mounted empty test host, installed Dialogic and actual native readiness. Each OS child reinitializes owners and registration; no in-memory state crosses processes. PowerShell retains one isolated GUID tree until both sequential children finish, with separate logs/XML/proofs and distinct PIDs.

Storage recovery before direct Load is explicitly selected by the test and uses real JsonFileStorage.reconcile with SaveManager's strict document validator. This does not prove production startup wiring. Ancillary board/consequence/audio/localization remain diagnostic participants. This is headless connected persistence/mount/native integration, not rendered E2E, desktop usability, full-runtime or release acceptance.

Still open: interruption/source-overwrite/selected-absence scenarios; Challenge/end and Contact enter/return producers; dayless production UI/final retirement; production host/content configuration; rendered/canonical/inventory gates. In particular, Backup inspection still accesses lifecycle.day, so this direct-Load proof does not establish dayless Backup UI loading. No production mapping was invented. C-owned ComputerDesktop.gd and DesktopAppRegistry.gd are untouched; F Schedule deletion fence remains.

All adjacent ZIPs are original Actions downloads. verification.json records SHA256, rehashed original manifest member counts, source/controller receipts and exact XML counts. Prior evidence at 08c56daf94f95c843d260494a728b0c169fb5ad3 is preserved.
