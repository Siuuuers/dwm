# History admission without transcript reconstruction

Outcome: opening History builds the same rows once; browsing and closing validate current session/frontier without rebuilding or translating the transcript. DialogicBridge remains the owner of capture admission. No cache, save migration, or new manager.

Base: master `16bc9957fdf6166bb0394147a0851edb8e573ef8` (PR285). Runtime change: extract the existing capture checks into `get_reading_history_source`; use that source for full projection and overlay admission. Preserve held-control validation, pause admission, session/frontier equality and initial full projection.

## Measured result

Godot 4.6.3 headless Linux. Two fresh processes per revision, identical copied Day7 save from the PR285 authored journey, five History openings per process. Initial load/setup excluded; opens include the existing click helper's frame waits. Twenty admission calls per opening. Baseline processes ran before candidate processes; this is a small sequential sample, not a statistical claim about Windows rendering.

| Operation | Baseline median | Candidate median |
| --- | ---: | ---: |
| History open | 73.823 ms | 65.536 ms |
| Admission check | 3.8018 ms | 0.2654 ms |

Admission avoids about 3.54 ms per callback in this sample. Full opening improved about 8.3 ms (11%). Row construction remains. All four matched runs produced the same 47-row transcript hash: `9dc153919928ed853eae68bdacbf37603c6cdf1f0dddd84e4d51c1d50691d20f`.

## Validation

- Native activation: 7 tests, 359 assertions, including source/history parity, no extra projection, pause, stale position and held-control validation.
- Reading rail: 11 tests, 187 assertions, including revoked custody and stale accessibility callbacks.
- Two final real Day7 save probes: 159 assertions each; open, repeated admission, forward/backward accessibility scrolling, accessibility close, input restoration, unchanged full transcript. Total final acceptance: 864 assertions.
- Earlier matched measurement processes: 139 assertions each, all pass.
- `git diff --check` passes.

An existing `test_scene_log_readonly.gd` fails identically on base and candidate (169 assertions, same 14 assertion failures including unexpected engine-error assertion). It expects >40 rows from repeated loop publications but compact history reconstructs two rows. Profile-attempt and detached-tree errors also reproduce on base; they are not silently waived as successful checks. Raw logs retained. This unrelated fixture was not rewritten.

The first expanded scratch probe reopened after only one frame following accessibility close. It failed on alternating opens; waiting four frames for deferred input restoration made both final runs pass. This changed the probe, not runtime. Expanded probe timings are separate from the matched comparison.

Evidence: `tools/player_latency/evidence/2026-11-12-history-admission/`. To reproduce, restore the PR285 journey's Day7 seed directory, copy `measure.gd.txt` or `acceptance.gd.txt` to `.godot/ci/history-admission/probe.gd`, and run the archived runner with a fresh label. Seeds are disposable user data and are not committed.

Skipped: broad language/font matrix, Windows/rendered smoothness, full-week rerun, unrelated Save/Load suites, new lint rules. A positive behavioral regression is more precise than a source-pattern ban here. Existing save format and deliberate advance delay are unchanged.

## Next bounded investigations

- Settings first mount: hidden `_ready → bind → refresh`, then visible `refresh`. Measure both and nested text-size application before deleting either.
- Computer opening: repeated `set_computer_open(true)` refreshes; measure before applying an unchanged-state guard.
- First Settings includes first Computer shell construction. Separate those costs.
- Do not repeat already merged PR258/259 palette/theme improvements.
