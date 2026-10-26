# Trusted Load accepted; measure duplicate History refresh next

Date: 2026-10-27, Hong Kong time.
Status: PR 118 merged. This record adds evidence and a next experiment, not runtime changes.

## First priority: measure the remaining reading pauses

The user confirmed this priority after PR 118. Keep it ahead of the older tasks below.

1. Measure Load and the next few reading actions. Include a longer encountered History.
2. Count refresh requests, executed refreshes and History projections. Measure their durations.
3. Separate test state capture and file hashing from ordinary gameplay work.
4. Measure History reconstruction, caption lookup, localization and copies separately.
5. Measure the first transition to an uncompiled passage. The shared day parse does not prove that this transition is fast.
6. Change one measured cause. Compare the complete action with the same observer on both builds.

The 64.649 ms result is the largest observed candidate frame gap after the complete caption.
It is not a measurement of History alone. The scope includes test work and the next input.
Rendering and runner scheduling can also contribute. Their separate costs are not yet known.
At 60 frames per second, one frame has about 16.7 ms. Use this as a reference, not an accepted guarantee.
Duplicate refreshes are one candidate. They are not the only possible cause or a proven large saving.

## Accepted source

[PR 118](https://github.com/Siuuuers/dwm/pull/118) merged at
`5a904bb157217f0489270020805b338c1df35fb6`.
The merge tree exactly matches the tested candidate:
`8ad7470a5d7932bc6a61f56b368beb9e9d0f8a7d`.
Tested candidate: `dc4bda7f2536a3543f84e1ddcf681c8204dec35a`.
Baseline: `80ff6827d0137dbc1631425149bb3714499a5447`.

This implements the [approved trusted-save policy](ak-trusted-save-visible-scene-first-20261027.md).
Read current master and root AGENTS.md before editing. Do not repeat the removed-validation work.

## What changed

- Ordinary Save9 Load uses the file/JSON/version boundary. It does not run full gameplay consistency validation.
- Authored-content compatibility remains: current wording for a retained line; latest saved major checkpoint on the actual route when the line is deleted; day start when that checkpoint is deleted. Saved gameplay and consequences remain unchanged.
- One private selected plan owns preparation. Load installs owners and activates the restored live session before mounting the destination. Previous session handles become stale.
- Ordinary Load does not acquire a save lock or mutation lease. Native publication still requires correct caption, art, active board and input ownership.
- Run identity, current Profile settings and persistent files remain unchanged by restoration.
- SoloReadingSession configuration holds metadata. It compiles a passage when needed. Runtime compilation shares parse-only day sources. Registration replacement invalidates both caches; translation-enabled compilation bypasses them.
- New Account, save-writing and legacy paths retain their own contracts. Retired edited-save refusal tests were updated, not treated as current requirements.

## Cloud acceptance

No Godot process ran locally.

- [Regression run 40381638444](https://github.com/Siuuuers/dwm/actions/runs/40381638444): success, 61 successful jobs. The older matched startup/Load job is skipped because the dedicated comparison replaces it.
- [Exported comparison 40381638502](https://github.com/Siuuuers/dwm/actions/runs/40381638502): success, 24 journeys, four repetitions per variant/case, AB/BA/AB/BA.
- Cases: fresh New Account, retained-profile New Account, and Load. All retained/Load cases use the same baseline-produced profile after real manual Save and Autosave.
- Each journey uses a new process. Both variants use the same observation overlay and runner. OS caches are not cleared.
- Load checks the first visible saved caption independently of complete-caption readiness. At first drawing, candidate Run identity is already active and correct.
- One real Enter press/release advances to line.Day1.002 on the restored Run. Saved gameplay, scene, reading and source bytes are preserved. Later Save and Autosave succeed.
- Observe at least one elapsed second after the next caption drawing. Logs have clean exit, no script errors or ObjectDB leak reports.
- Independent static review found no blocker in owner ordering, paused handoff, cache lifetime, translation or registration invalidation.
- Visual review covered all eight Load next-caption images and representative title, backup, New Account and consent images. Art/caption layout has no observed regression. Next text remains mid-reveal in the one-second capture by design.

Evidence artifact: `12678089707`, `trusted-runtime-evidence-40381638502-1`.
ZIP SHA256: `a245fa69f601f7586beb2fef3649ab3c8ff2ef2b03f0a3a8433e7c427a58b637`.
GitHub artifact retention is seven days; primary figures are retained below.

The first candidate run is superseded. It found four test/inventory issues and a timer assertion that could finish under one wall-clock second. The final candidate uses a monotonic elapsed deadline. Do not report the earlier figures as final acceptance.

## Matched results

Milliseconds; medians across four samples per variant/case.

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| Load: first correct caption drawing | 1267.825 | 622.376 |
| Load: complete caption | 1299.362 | 653.937 |
| Load: first input ready | 1316.486 | 670.824 |
| Load action to next caption drawing | 1360.398 | 713.668 |
| First Accept to next caption drawing | 43.904 | 42.993 |
| Maximum post-caption frame gap per sample | 58.954 | 57.839 |
| Fresh New Account | 1272.136 | 1016.295 |
| Retained-profile New Account, excluding consent dwell | 1244.483 | 1015.256 |

Load complete-caption samples, repetition order:

| Variant | r1 | r2 | r3 | r4 |
| --- | ---: | ---: | ---: | ---: |
| Baseline | 1230.913 | 1337.099 | 1261.625 | 1538.809 |
| Candidate | 646.952 | 652.497 | 655.377 | 693.641 |

Candidate improves complete-caption latency in every matched pair. Median waiting falls about 49.7%.
Every Load sample reduces full snapshot validations from 3 to 0, programme compilations from 92 to 1, and reading configurations from 16 to 2.

Observer Run/checkpoint capture and persistent-file hashing occur before the next input and count toward first-input readiness. Equality checks, History expansion and PNG encoding happen afterwards. Inclusive phase costs overlap; do not add them.
Worst candidate post-caption gap is 64.649 ms, versus 76.953 ms baseline. This is not stutter-free play.
Four samples on one runner are descriptive evidence, not a guarantee for every device.
Unseen-entry transitions are covered functionally but have no matched timing result yet.

## Next observable outcome

Measure whether duplicate caption refresh requests do repeated work during Load and the next input. If material, ensure several notifications before a deferred callback perform one projection, while every custody change still retires input immediately.

No new design decision is currently needed. The user authorized cloud-only tests, focused parallel audits, direct PR merges after evidence, and minimal changes. Ask only when an answer changes behavior or architecture. Keep named art checkpoints/overlay work separate.

### Smallest candidate

WitnessedCaptionLayer has two deferred callers:
`_on_reading_session_changed()` and `_on_reading_input_custody_changed()`.
Both independently queue `_refresh_reading_session()`, which projects caption memory.
The equality check in `_project_scene_caption_memory()` happens after the costly work.

Instrument request count, executed refresh count, projection count/time and worst frame during matched complete actions. If duplication is meaningful, use one UI-owned pending flag. Both callers request the same refresh. Clear the flag at refresh entry. Preserve each synchronous `_retire_transport()` call.

Do not claim a gain from this static audit. If duplicates are negligible, stop this intervention and measure the temporary-ledger reconstruction separately.

### Important ownership finding

`DialogicBridge.get_scene_caption_memory()` authenticates presentation, then
`SoloReadingSession.project_scene_day_history()` calls `_capture_scene()`.
That copies progress/ledger and validates through a temporary restored ledger.
`SceneReadingHistory.project_encountered()` rebuilds the caption-registry lookup.
Localization copies the projection; UI compares and copies again.

Crucially, `_capture_scene()` also advances player_progress from new ledger publications.
It is not simply removable display validation.

There is no dedicated History revision. Existing exact presentation proof includes playback token, session/publication/line IDs, variant/content revision, native frontier and profile identity. It excludes locale and complete encountered-history state. StoryLocalization has no translation revision. Presentation-only memoization is not yet a proven general cache key. Coalescing avoids that problem.

### Failure cases and checks

1. Several notifications before the callback produce one projection; input retires immediately.
2. A later custody release schedules another refresh after temporary refusal.
3. A publication during refresh can schedule subsequent work.
4. Load, same-text replacement, locale/day changes and reset retain correct three-caption memory and full scrollback.
5. Native Next/Accept uses the restored Run; review gestures do not advance narrative.

Relevant tests:
- tests/unit/test_scene_day_history_session.gd
- tests/unit/test_scene_content_recovery.gd
- tests/integration/test_scene_native_activation_runtime.gd
- tests/integration/test_scene_log_readonly.gd
- tests/integration/test_witnessed_caption_runtime.gd

Review callers and the test bodies before final acceptance. Keep measurement-only overlays identical between baseline and candidate. Preserve the cloud-only execution rule.

## Brief review of aa through ak

Review date: 2026-10-27. Source: master at `28182754e2a0cd2e1990a51bafda5de17f07bdf2`.
This is a document and implementation-status review. It is not a new runtime acceptance test.
The repository has aa, ab, ac, ai, aj and ak. It has no handoff files with prefixes ad through ah at this revision.
Merged PR records 108 and 110 through 118 supply the intervening implementation status.
PR 113 is diagnostic work. PR 115 was superseded by PR 116.

| Source | Current status | Required action |
| --- | --- | --- |
| [aa](aa-reading-startup-simplification-20261026.md): stable IDs, shared configuration, revision-aware read marks and Replay | Implemented in PR 104 and later work. | Preserve these contracts. Do not repeat this batch. |
| [aa](aa-reading-startup-simplification-20261026.md), [ab](ab-current-content-save-migration-20261026.md): content fallback, bounded encountered History and exact board transfer | Implemented in PR 107. Current reading-format cleanup passed in PR 108. | Preserve the previous two checkpoint sections and the current section. Show only encountered current text. Do not add read marks through History. |
| ab: newly authored optional Contacts after a content update | Existing Contacts contracts have tests. The migration batch did not establish this rendered journey. | Add a connected case when production content includes Contacts. Do not call this a demonstrated defect. |
| ab: automatic allocation of missing dialogue IDs | The handoff did not implement a separate authoring command. Dialogic already supplies an ID allocator. | Keep this optional. Preserve existing IDs. Inspect current authoring tools before adding anything. |
| [ac](ac-trusted-story-runtime-20261026.md): reuse trusted shipped story tables | Implemented in PR 110. PR 118 adds lazy passage compilation and shared day parsing. | Keep exact-pack cloud validation. Do not restore repeated whole-story runtime checks. |
| ac: nonblocking error and skip for audience-edited DTL | Explicitly deferred by PR 110. Later reviewed PRs do not record acceptance of this feature. | Keep pending after reading performance. Trace missing IDs and unsupported commands. Release the skipped event's wait. Continue if a next event exists; otherwise end dialogue cleanly. Keep other UI usable. |
| [ai](ai-direct-load-and-settings-back-20261026.md): direct Load and Settings Back | Accepted in PR 116; confirmed by aj and later cloud runs. | Do not repeat its old pending-inventory work. |
| [aj](aj-new-account-snapshot-validation-20261027.md): duplicate snapshot admission | Accepted in PR 117. PR 118 removes the remaining three full passes from ordinary Load. | Do not remove New Account or write-path checks by name alone. |
| [ak](ak-trusted-save-visible-scene-first-20261027.md): trusted current saves and current scene first | Accepted in PR 118. History cost and later passage timing still need measurement. | Follow the first-priority investigation above. |
| ai, aj, ak: named presentation checkpoints and overlays | Separate pending feature. | Use the existing art manifest. Save the checkpoint ID and ordered overlay labels. Restore directly. Clear overlays at a new checkpoint. Showing an active label or removing an absent label does nothing. |

### Instructions that no longer apply

- aa proposed run-level Sweet/Dark alternation and an initial Autosave. PR 111 retired both for current scene New Account. Start in memory. Preserve existing saves. Keep normal later Save behavior.
- aa proposed a durable creation operation. PR 111 removed it from current scene New Account. Do not restore it from the old handoff. Existing identity consumers and legacy operations keep their own owners.
- aa and ab required strict external gameplay admission. ak supersedes that rule for ordinary current-save Load. Keep the small file/JSON/version boundary and supported authored-content fallback.
- aj described public/private plan comparison and a Load lock. ak rejected that policy; PR 118 removed those requirements from ordinary Load.
- Title prewarming was a proposal, not an unfinished required feature. Do not add it without measured need.
- Old diagnostic branches are not product candidates. Do not merge PR 109 or PR 113 merely to recover their measurements.

### Other retained investigation limits

The early launch interval still needs a fresh, separately attributed measurement before further startup changes.
Do not reuse old unmatched launch timings as current results or attribute them wholly to fonts, disk or GPU work.
PR 110 recorded intermittent shutdown resources. PR 111 improved diagnostic audio teardown; it did not claim a production shutdown fix.
PR 118's accepted runs exited cleanly. Keep strict shutdown checks and investigate if the signature returns.
These items do not replace the first-priority reading investigation.

Use short sentences and direct instructions in future handoff updates. Keep measured results separate from hypotheses.
This update follows ASD-STE100-style writing. No formal language-compliance certification is claimed.
