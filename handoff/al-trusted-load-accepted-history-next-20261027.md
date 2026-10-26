# Trusted Load accepted; measure duplicate History refresh next

Date: 2026-10-27, Hong Kong time.
Status: PR 118 merged. This record adds evidence and a next experiment, not runtime changes.

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
