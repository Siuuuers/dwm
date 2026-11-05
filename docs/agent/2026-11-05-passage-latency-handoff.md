# Passage transition performance handoff

## Implementation draft: live Challenge anchor validation

The candidate changes only live Challenge Start to validate its exact current boundary against the existing reading session. It removes temporary session construction/restoration from that path. The detached saved-checkpoint validators remain unchanged. The preparation fake follows the new method, and a real-owner regression covers live validation plus independent validation of the original saved checkpoint after a normal transition.

Baseline runtime: master `be487bb62333dd57ef41b55258a76af59d07bbb4`, tree `fa9eadb5a9ef5ccaff251939f9d9e5c952a8b768`. Two uninstrumented, fresh-process Linux headless journeys each passed 5,052 assertions over 830 caption positions. Day6 result input-ready: 452.108 / 485.033 ms; Day7: 260.065 / 521.895 ms. These are repeated baseline samples, not before/after. The route leaves optional boards unplayed, so a result advance can admit both Start and Finish.

Two separate instrumented journeys also passed 5,052 assertions each. Temporary anchor reconstruction cost 36–82 ms across seven Challenge Starts; Day6 59.235 ms within 88.388 ms preparation, Day7 36.803 ms within 55.774 ms preparation. Inclusive spans must not be added. Shared-host outliers and headless timing do not qualify Windows display or audio latency.

**Execution recovered; focused behavioral results available.** On the runtime candidate from PR head `9f1d9fef3d6b358da78df14f65d0f784c88d0f9a`, the repaired preparation suite passes 11/11 and real-owner composition passes 9/9, including live anchor reuse and detached saved-anchor validation after transition. Native playable control passes 10/10 (269 assertions) in a separate process. Live-transition lint reports zero violations; History lint and diff whitespace checks pass. Matched candidate performance has NOT been measured; keep the PR draft and unmerged.

Baseline diagnostic: the original preparation/composition suites had 13 failures across 19 tests; the candidate had the same categories plus the new test's History expectation, 14/20. Corrections are test-only: supply the current Challenge outcome map, assert the active Challenge change, check complete receipt-map validity at its actual contract boundary, capture the first B caption before compact-ledger advancement, and explicitly establish checkpoint boundaries for synthetic fixture jumps. Original History expectations remain intact. No extra runtime validation was added.

Run preparation plus owner composition in one fresh Godot process; run native control separately because it installs a different immutable scene registration. Combining all three produces `registration_already_selected` and is not a product failure. The combined diagnostic showed 20/20 passing in the first two suites; native's independent log reports all 10 tests passed. Local raw logs: `passage-evidence/live-anchor-baseline.log`, `live-anchor-focused2.log`, `live-anchor-final.log`, `native-alone.log` beside the measurement checkout. These scratch logs are not durable repository artifacts.

Next: alternating uninstrumented baseline/candidate authored journeys using the exact probe in the existing [measurement report](https://chatgpt.com/library?file_id=libfile_1af520d710a48191b0231399e6d79295&account_id=personal). Run serially with fresh data roots, compare full operations on the same host, verify 829 samples and 5,052 assertions per journey, and report measurements before further surgery. Baseline tree is recorded above. Recheck current master and candidate SHA before starting. No speedup or Windows display/audio qualification is established.

The CI selector correction is planned, not implemented: recognize only the live Start/anchor method scope and relevant tests; share classification with DTL preflight; permit accompanying handoff docs; retain full fallback for unmatched runtime changes and print why. Test the selector's actual PR scope and saved-validator counterexample. Do not launch the broad matrix merely to validate this small optimization. Fixture/handoff publication uses `[skip ci]`; this is not evidence of a CI pass.

## Assignment

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

Older caption-presentation tests have a known fake `MemoryLocale` missing `t/get_readiness`; baseline failures are documented and excluded from passes. GitHub's combined-status endpoint returned no statuses for the final head; this is not evidence of green Actions. Windows rendering, other routes and audio-gap qualification remain separate work.

## Investigation sequence

1. Read `AGENTS.md`/`CLAUDE.md`; inspect current master, pending changes and concurrent work. Confirm the original slowdown still reproduces before editing.
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
