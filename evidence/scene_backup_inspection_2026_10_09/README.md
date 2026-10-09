# Scene-safe Backup inspection — 9 October 2026

Coordinator A follows Director22:49 dispatch5994622489. Observable outcome:
admitted scene saves can be inspected and projected without a fictional day;
inspection and cancelled consent do not change physical saves or live gameplay.
SaveManager remains the admission/revision/consent owner and
BackupPresentationPort projects only its approved display fields.

## Source and ownership

Product4e20c0ae30d07addbf95be2729076e02b7998b52,
treebf9e93ecb780d83dbe3d23c72902ddfcf5afc89c, sole parent63a70e37,
eight paths. Runtime changes only autoload/SaveManager.gd and
scripts/application/backup/BackupPresentationPort.gd. Tests: one new scene
inspection suite, explicit family assertions in existing Quick/host/operations
suites. Two design documents give C's concrete interface and D's finite
Challenge playable proposal. The latter is unactivated and untested proposal
text, not an accepted persisted format.

First fixture correction9ebe1f086c011e5ebbf1433d2a760ded75361745,
treefc3c6aca44fef1c3c167a324fdfcbaee29712055, changes only the standalone
operations fixture's obsolete localization method signature/plan. Production
and the two already-passing GUT lanes remain byte-identical to4e20c0ae.

`family` is scene/legacy_day/null only after strict Save admission; `load_family`
comes from the prepared whole target bundle. Scene day/load_day stay null.
Malformed schema9 is unreadable, not a future schema; schema10 remains future.
No persisted format, admission bypass, revision/consent/Quick policy or C UI
change. Existing supported legacy day/time behavior remains.

## Retained passing cloud GUT evidence

Run37949954744:
- scenebackup/job113885845118: 2 cases,46 XML testcase assertions versus49 GUT
  log assertions (three setup assertions). Actual filesystem/issuer/Profile/
  GameState/SaveManager admission and real BackupPresentationPort. Confirmed
  creation, exact physical revision/time, null day, private-field exclusion,
  title Load prepare/cancel, single-use refusal, unchanged physical save/Profile,
  issuer root, live Run/Profile, stable journal and publication counters.
  Corrupt scene-shaped bytes remain intact, unknown-family and unloadable.
- backuplegacy/job113885844724: 31 cases,847 XML/log assertions. Existing Quick
  save/load, fallback, revision drift, stale source, unsupported bytes, consent
  and host admission remain. Missing family in an injected owner is not inferred
  from its day field.

Retained total33 GUT cases /893 XML assertions /896 log assertions, zero retained
GUT failures/errors/skips or gated import/script errors. These are bounded
regressions, not unique project totals. Successful lanes are not repeated after
the standalone-only test-double correction.

Final standalone run37950848439/job113888917209 succeeded on a991b525,
including strict import/script-error and tracked-source gates. It reports
BACKUP_OPERATIONS_PASS, covering actual legacy fallback/title restore,
whole-bundle family projection, revisions, confirmations and locked actions.
It is a standalone diagnostic, not additional GUT cases or XML assertions.

## Original failure and correction

Run37949954744/job113885845046 failed. The historical standalone
ExternalOwners.prepare_locale accepted one argument, while the current real
LocalizationRestoreParticipant passes locale/font_style/text_size. Script
errors prevented fallback/title restore; five diagnostic checks failed.
The original archive is retained unchanged. Overall run37949954744 remains
failed despite its two separately retained green lanes.

The correction changes only the test double to accept and retain all three
facts, matching the current production signature. Independent review checked
Profile/Audio/Route/Narrative contracts before the failed lane alone was rerun.
No assertion or runtime guard was removed.

Run37950420676/job113887445621 then passed all standalone assertions but
failed the strict script-error gate: _test_restore freed GameState before the
later locked projection reused its Run participant. Its PASS marker is not
acceptance. The unchanged original second failure archive is retained.
Final producta991b5256d88275debae051a61a7ee23494c868e,
treef63f8d0ae2da4999db9609caf23c6566e1c847dc, retains that test owner until
manager disposal after the final check. This is another standalone-test-only
correction, independently reviewed; no assertion weakening or production change.

## Controller and evidence custody

Initial controller09772d0bffb98220e8c0de6648dc91bf151b54d9 and actual
eventc43ece47e61bb57b5bfea9ec8ee449dd73318e28 share exact workflow blob
11897ab46339daeb783d8222edf191683891bb1d. Intermediate controller
172184bacd87e212c722bb4f48d1fbb6377d1a15 has workflow blob
ea68f25ead08ece9858e871a81edd8f972d25409 and runs backupoperations only.
Intermediate actual eventcc160f430997eef4a30d5b8411e7022345f16ba3 shares
ea68f25ead08ece9858e871a81edd8f972d25409. Final controller
89b9e0f1b74ccc569ccd9105fe7bae3dba884b07 has workflow blob
15fe4101e9d888b729b22ccb9c3d8785980b5185 and again runs only backupoperations.
Controllers differ from their exact pinned product only in the workflow.

Final actual event92591397eeec54694af4c57364d0826af03b90a7 shares the exact
15fe4101e9d888b729b22ccb9c3d8785980b5185 workflow blob.

All five original ZIPs and39 manifest members were rehashed. Both failed
archives remain failures. verification.json records archive hashes,
rehashed original manifest members, source/tree/parent/changed path blobs,
engine pins, actual event and XML counts. Source evidence was independently
matched against Git objects. Godot4.6.3 standard and PowerShell executed only
in Actions. Local Python only parses/hashes evidence; it does not run the engine.

## Scope and remaining work

The scene fixture uses diagnostic route/native activation and ancillary
participants. This is not a rendered Backup or production scene desktop/capture
claim. The legacy standalone suite uses in-memory FileOps and injected external
presentation owners. No fresh-process or physical Challenge guarantee is added
by these tests; previously accepted restart/interruption evidence remains intact.
C must consume the published explicit family contract; its exclusive files were
not edited. Production scene capture, adjacent slot-metadata API conversion,
Challenge forward/physical/End, selected absence/source-overwrite and final
rendered/canonical/inventory gates remain separate.

The forward playable proposal is awaiting Director-required finite D review
before activation. It specifies strict result/registration/command joins,
genuine retained source and full Run/Save durability before adoption. No generic
re-review of accepted initial schema3 or Reading5 restore is requested.

Draft PR27/30 remain unmerged. Master44dda794 and PR1a6decec3 were freshly checked
unchanged. No release/protected-ref changes; original prior evidence is retained.
