# Passage transition performance handoff

## Implementation and measured result — 10 November 2026

PR #246 reuses the current reading session for live Challenge Start anchor validation. Saved-checkpoint validation remains separate. It also removes duplicate publication validation, redundant detached-snapshot copies, and an immediate reading-state recapture after native retained-source validation. Retained Challenge command lookup returns only command/bundle identity; actual checkpoint and End boundaries still capture current context. End compares admission with commit context before recording the result.

Baseline master: `be487bb62333dd57ef41b55258a76af59d07bbb4`, tree `fa9eadb5a9ef5ccaff251939f9d9e5c952a8b768`. Matched runtime candidate: `a94f3a58c3c8161aa9c82245c51c31c025353245`. Four serial fresh-profile Linux headless journeys in B/C/C/B order each passed 5,052 assertions with 829 samples across 830 captions. Across seven Challenge-result transitions, pooled median input-ready time was 293.541 ms baseline versus 202.242 ms candidate (about 31% lower). This mixes distinct transitions and is descriptive, not a universal speedup. Day6 ranges were 288.7–391.0 ms versus 192.7–193.7 ms. Ordinary within-entry medians remain approximately 111 ms.

[Matched report, raw logs, probe and receipts](https://chatgpt.com/library?file_id=libfile_7a5fdeba2e608191a9d5dc0dffee9832&account_id=personal). Optional boards were unplayed; no Windows display, audio-gap or played-board latency qualification. The later small cuts have focused behavioral evidence, but no reliable incremental speedup claim. One additional pair varied in both directions across individual transitions.

Preparation and real-owner fixtures were repaired for current outcome ownership and explicit synthetic History checkpoints. Native control needs its own process because it installs a different immutable registration. Command lookup has a behavioral regression proving zero runtime-context captures; publication acknowledgement checks one commit validation. A scoped lint rule prevents context capture returning to retained command lookup while allowing capture at checkpoint and End boundaries.

Final revision, focused acceptance results and merge status are recorded in [PR #246](https://github.com/Siuuuers/dwm/pull/246). Earlier scratch logs may no longer exist; use the durable report for measurement reproduction. Recheck current master before further changes.

The CI selector correction is complete in merged [PR #247](https://github.com/Siuuuers/dwm/pull/247): main validation and DTL preflight share the bounded Challenge classification, companion docs are supported, and unmatched runtime changes retain broader coverage with a fallback diagnostic. Merged [PR #248](https://github.com/Siuuuers/dwm/pull/248) narrowed the focused Challenge checkout; merged [PR #249](https://github.com/Siuuuers/dwm/pull/249) limited the authored Day1 probe preparation to its four visited entries. Their PRs record candidate-specific checks and Actions evidence. The earlier `[skip ci]` publication remains historical, not a passing run. Do not repeat these implementations or add file-wide GameState exemptions or host-sensitive timing gates. See the [current CI handoff](2026-11-10-challenge-ci-coverage-handoff.md).

## Deferred performance assignment

Windows packaged player-experience, visible-latency and audio-continuity qualification is deferred until planned features settle, per [the current cleanup handoff](https://github.com/Siuuuers/dwm/pull/250). The sequence below preserves the performance follow-up; it is not the active cleanup assignment.

- **Goal:** identify and reduce the largest remaining player-visible passage-transition stall, starting with Challenge-result handoffs after natural play.
- **Owner:** next performance implementation session; one coordinator owns overlapping runtime files and publication.
- **Scope:** native Accept through the expected fully revealed, acknowledged, input-ready caption; record the rendered frame when a renderer is available. Attribute first, then change one demonstrated redundant operation.
- **Depends on:** [PR #245](https://github.com/Siuuuers/dwm/pull/245). Its final runtime head is `cb24fccb1dab5bbd71747a21a2fbbee1ae557661`, tree `fa9eadb5a9ef5ccaff251939f9d9e5c952a8b768`. This PR now includes the live-anchor implementation described above. Verify merge metadata and current master before implementation; do not treat this SHA as a permanent baseline.
- **Acceptance:** preserve exact visible caption, choices/outcomes, board state, encountered history, current global preferences/discoveries, authored audio/effects/input holds, Save/Load and retry behavior. Demonstrate a matched uninstrumented improvement on the target workload with focused behavioral checks on the candidate revision.
- **Sources:** [current scene contract](../design/2026-10-25-current-scene-state.md), [completed audit](2026-11-05-player-latency-audit.md), [prior long-session investigation](2026-11-04-performance-handoff.md), [latest Load evidence](../../tools/player_latency/evidence/2026-11-05-load-texture-recovery.json).

## Completed work: keep it

PR #245 reuses immutable Contacts registration and an already validated Save candidate, avoids unrelated Settings construction on first History, removes temporary/duplicate Settings and caption themes, and reuses unchanged run presentation. Profile/Localization already remain current across Load. It retains only the five gallery pictures on demand across scene replacement and styles caption recovery only when requested.

Texture retention is bounded to five assets; manifest reload clears it and preview override invalidates its entry. All five current images total 39.55 MiB of raw RGBA pixels, not a measurement of actual CPU/GPU memory. Optional-art existence/dimension checks remain. Recovery's first requested presentation still pays its styling cost; active recovery continues to receive current presentation updates.

Existing structural lint covers repeated Save validation, registration copying/hashing, eager unrelated Settings, duplicate binding styling, initial caption defaults, and eager hidden recovery styling. Six current lint tests passed. Texture lifetime, bounds and invalidation are behavioral tests; do not replace them with a brittle source-text rule. Do not add a timing gate based on these noisy host samples.

## Evidence and limits

Latest Load comparison (same early compact-history checkpoint, Godot 4.6.3 standard, Linux headless): first Load median 1116.457 → 824.022 ms, two fresh processes per variant; subsequent in-game Load median 664.171 → 453.035 ms, six correlated samples per variant. Expected-checkpoint expansion was moved outside the timer; native click-helper frame waits remain. Baseline ran before candidate. No reliable percentage or Windows input-to-photon claim follows.

Final texture/recovery revision passed: four Load comparison processes × 172 assertions; texture lifetime/bounds/override/reload 21; deferred recovery/current high contrast/focus 90; older-save/newer-global-preference Load 119; existing three-locale × three-size recovery 119; six lint tests and structural/comment/whitespace checks. The earlier 4,312-assertion seven-day journey predates the final texture/recovery change: do not label it a full journey on the final head.

The prior passage audit measured 27 passage entries at median 180.348 ms, maximum 500.877 ms; a separate instrumented run identified `line.Day6.A.001` as its slowest entry. These are historical observations, not a current baseline. The older naturally aged Day7 handoff also differs materially from loading the same compact checkpoint in a fresh process. Never use fresh Load as a substitute for long-session measurement.

The earlier audit reported caption-presentation failures from a fake `MemoryLocale` missing `t/get_readiness`; those historical failures were excluded from its passes. The [current cleanup record](2026-11-10-current-cleanup-handoff.md) now records reproduction and focused fixture repair; do not reopen this resolved lead. GitHub's combined-status endpoint returned no statuses for the final head; this is not evidence of green Actions. Windows rendering, other routes and audio-gap qualification remain separate work.

## Investigation sequence

1. Read `AGENTS.md`; inspect current master, pending changes and concurrent work. Confirm the original slowdown still reproduces before editing.
2. Reuse `tests/manual/benchmark_player_latency.gd` and the authored journey infrastructure. Reach the candidate boundary naturally. Start with Day6 Challenge result and the established late Day7 source `line.Day7.untouched.impulse.004` → `line.Day7.A.001`, with `.002` as the ordinary-caption control. Reconfirm IDs against current authored content.
3. Exclude expected-text/checkpoint construction, screenshots and assertions from the timed operation. Keep native input/frame waits explicitly identified. Separate naturally aged, fresh-process and warm-cache populations; match starting Profile, discoveries, content and checkpoint.
4. Split retained-source validation, target preparation, control commit/acknowledgement, native installation, artwork, caption layout and frame waits. Trace the dominant inclusive span to its leaves; never sum nested spans. Keep synchronous wrappers off asynchronous functions and remove instrumentation before performance comparison.
5. Inspect existing owners before designing replacements. Likely entry points: `GameState._prepare_scene_playable_event`, `_accept_scene_playable_event`, `accept_scene_event`; `DialogicBridge._commit_scene_playable_owned`, `_scene_playable_current`; `SoloReadingSession.prepare_scene_next`; narrative checkpoint control retention and acknowledgement. Use the actual current call graph to narrow scope.
6. Make one bounded change with preserved semantics. Do not delete live receipts, history, freshness checks or callback-boundary checks merely because they repeat. Do not skip or collapse authored Challenge Start/Finish markers.
7. Alternate matched baseline/candidate runs when possible; report sample counts, medians/ranges, revision, reproduction, commands/exit codes, proof and limits. Run the relevant positive checks plus an authentic affected journey. No new fault-injection campaign or broad CI matrix.
8. Update this PR around the actual measured result if it becomes the implementation PR, or link a focused successor PR. Keep source/evidence links and final tested revision current. Stop for a user decision only if observable behavior or an unresolved product policy must change.

## Runner notes

`DWM_TEST_ROOT` must be below `.godot/phase2r_tests/`; isolate user-data directories and restore identical seed bytes for matched Load samples. Import once before tests, not concurrently with them. Inspect actual selected tests and assertion counts: GUT can exit zero when no tests ran, and `-gunit_test_name` is a substring selector. Use separate processes for creator/loader, but numeric PID inequality alone is unreliable in recovered containers.

Scratch diagnostics from this session are disposable. Reusable probes and evidence are in the repository; the latest Load JSON includes the exact comparison probe and runner. Regenerate seeds through the authored creator if the workspace is lost. Keep runtime observers out of production. Cloud Linux is the approved development environment; label headless evidence accurately and use a renderer before claiming visible frame or target-device behavior.
